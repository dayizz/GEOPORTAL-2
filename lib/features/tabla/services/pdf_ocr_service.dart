import 'package:pdfx/pdfx.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:io' show Directory, File;

/// Datos extraídos del PDF mediante OCR
class PdfOcrData {
  final double? kmInicio;
  final double? kmFin;
  final double? superficie;
  final DateTime? fechaFirma;
  final String rawText;
  final List<String> extractedLines;

  PdfOcrData({
    this.kmInicio,
    this.kmFin,
    this.superficie,
    this.fechaFirma,
    required this.rawText,
    required this.extractedLines,
  });

  bool get hasAnyData =>
      kmInicio != null || kmFin != null || superficie != null || fechaFirma != null;
}

class PdfOcrService {
  /// Extrae datos del PDF desde una URL de Google Drive
  Future<PdfOcrData> extractFromGoogleDriveUrl(String url) async {
    try {
      // Convertir URL de Google Drive a URL de descarga directa
      final downloadUrl = _convertGoogleDriveUrlToDownload(url);
      final pdfBytes = await _downloadPdfBytes(downloadUrl);
      return await extractFromBytes(pdfBytes);
    } catch (e) {
      return PdfOcrData(
        rawText: 'Error descargando PDF: $e',
        extractedLines: [],
      );
    }
  }

  /// Extrae datos del PDF desde bytes
  Future<PdfOcrData> extractFromBytes(Uint8List pdfBytes) async {
    try {
      final document = await PdfDocument.openData(pdfBytes);
      final pageCount = document.pagesCount;
      
      String allText = '';
      final allLines = <String>[];

      // Procesar primeras 3 páginas (OCR es costoso)
      final pagesToRead = pageCount > 3 ? 3 : pageCount;
      final textRecognizer = TextRecognizer();

      for (int i = 0; i < pagesToRead; i++) {
        try {
          final page = await document.getPage(i + 1);
          // Obtener imagen de la página
          final image = await page.render(
            width: 2200,
            height: 3000,
            format: PdfPageImageFormat.png,
          );

          if (image != null) {
            final imageBytes = image.bytes;
            if (imageBytes != null) {
              final tempPath =
                  '${Directory.systemTemp.path}/geoportal_ocr_page_${DateTime.now().microsecondsSinceEpoch}_$i.png';
              final tempFile = File(tempPath);
              try {
                await tempFile.writeAsBytes(imageBytes, flush: true);

                final inputImage = InputImage.fromFilePath(tempFile.path);

                final RecognizedText recognizedText =
                    await textRecognizer.processImage(inputImage);

                for (TextBlock block in recognizedText.blocks) {
                  allText += '${block.text}\n';
                  for (TextLine line in block.lines) {
                    allLines.add(line.text);
                  }
                }
              } finally {
                if (await tempFile.exists()) {
                  await tempFile.delete();
                }
              }
            }
          }

          await page.close();
        } catch (e) {
          // Continuar con la siguiente página
        }
      }

      await textRecognizer.close();
      await document.close();

      // --- Nueva lógica para extraer ambos km en frases como 'va del km 7+582.67 al 7+978.00 km' ---
      final kmPair = _extractKmPair(allText);
      double? kmInicio;
      double? kmFin;
      if (kmPair != null) {
        kmInicio = kmPair[0];
        kmFin = kmPair[1];
      } else {
        kmInicio = _extractKmInicio(allText);
        kmFin = _extractKmFin(allText);
      }
      final superficie = _extractSuperficie(allText);
      final fechaFirma = _extractFechaFirma(allText);

      return PdfOcrData(
        kmInicio: kmInicio,
        kmFin: kmFin,
        superficie: superficie,
        fechaFirma: fechaFirma,
        rawText: allText,
        extractedLines: allLines,
      );
    } catch (e) {
      return PdfOcrData(
        rawText: 'Error procesando PDF: $e',
        extractedLines: [],
      );
    }
  }

  /// Extrae ambos km de frases como 'va del km 7+582.67 al 7+978.00 km'. Devuelve [menor, mayor] o null si no se encuentra.
  List<double>? _extractKmPair(String text) {
    // Busca patrones tipo 'km 7+582.67 al 7+978.00 km' o variantes
    final regex = RegExp(r'km\s*(\d+)\+(\d+\.?\d*)\s*(?:al|a|–|-)\s*(\d+)\+(\d+\.?\d*)', caseSensitive: false);
    final match = regex.firstMatch(text);
    if (match != null) {
      try {
        final km1 = int.parse(match.group(1) ?? '0');
        final metros1 = double.parse(match.group(2) ?? '0');
        final km2 = int.parse(match.group(3) ?? '0');
        final metros2 = double.parse(match.group(4) ?? '0');
        final value1 = km1 + (metros1 / 1000);
        final value2 = km2 + (metros2 / 1000);
        if (value1 < value2) {
          return [value1, value2];
        } else {
          return [value2, value1];
        }
      } catch (_) {}
    }
    // Fallback: buscar todos los patrones sueltos (por si aparecen separados)
    final looseRegex = RegExp(r'(\d+)\+(\d+\.?\d*)', caseSensitive: false);
    final matches = looseRegex.allMatches(text);
    final values = <double>[];
    for (final m in matches) {
      try {
        final km = int.parse(m.group(1) ?? '0');
        final metros = double.parse(m.group(2) ?? '0');
        final value = km + (metros / 1000);
        values.add(value);
      } catch (_) {}
    }
    if (values.length >= 2) {
      values.sort();
      return [values.first, values.last];
    }
    return null;
  }

  /// Extrae KM Inicio del texto
  double? _extractKmInicio(String text) {
    final patterns = [
      RegExp(r'km\s*inicio[:\s]+([0-9]+[.,][0-9]{1,4})', caseSensitive: false),
      RegExp(r'km\s*inicial[:\s]+([0-9]+[.,][0-9]{1,4})', caseSensitive: false),
      RegExp(r'cadenamiento\s*inicio[:\s]+([0-9]+[.,][0-9]{1,4})', caseSensitive: false),
      RegExp(r'^km\s*(\d+[.,]\d{1,4})', caseSensitive: false, multiLine: true),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          final numStr = match.group(1)?.replaceAll(',', '.') ?? '';
          return double.tryParse(numStr);
        } catch (_) {}
      }
    }
    return null;
  }

  /// Extrae KM Fin del texto
  double? _extractKmFin(String text) {
    final patterns = [
      RegExp(r'km\s*fin[:\s]+([0-9]+[.,][0-9]{1,4})', caseSensitive: false),
      RegExp(r'km\s*final[:\s]+([0-9]+[.,][0-9]{1,4})', caseSensitive: false),
      RegExp(r'cadenamiento\s*fin[:\s]+([0-9]+[.,][0-9]{1,4})', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          final numStr = match.group(1)?.replaceAll(',', '.') ?? '';
          return double.tryParse(numStr);
        } catch (_) {}
      }
    }
    return null;
  }

  /// Extrae Superficie (m2) del texto
  double? _extractSuperficie(String text) {
    final patterns = [
      RegExp(r'superficie[:\s]+([0-9]+[.,][0-9]{1,4})\s*m[²2]', caseSensitive: false),
      RegExp(r'area[:\s]+([0-9]+[.,][0-9]{1,4})\s*m[²2]', caseSensitive: false),
      RegExp(r'([0-9]+[.,][0-9]{1,4})\s*m[²2]\s*de\s*superficie', caseSensitive: false),
      RegExp(r'total\s+([0-9]+[.,][0-9]{1,4})\s*m[²2]', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          final numStr = match.group(1)?.replaceAll(',', '.') ?? '';
          return double.tryParse(numStr);
        } catch (_) {}
      }
    }
    return null;
  }

  /// Extrae Fecha de Firma del texto
  DateTime? _extractFechaFirma(String text) {
    final datePatterns = [
      // DD/MM/YYYY o DD-MM-YYYY
      RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{4})'),
      // YYYY-MM-DD
      RegExp(r'(\d{4})[/-](\d{1,2})[/-](\d{1,2})'),
      // Texto como "15 de marzo de 2023" o similar
      RegExp(r'(\d{1,2})\s+de\s+(\w+)\s+de\s+(\d{4})', caseSensitive: false),
    ];

    // Buscar líneas con palabras como "fecha", "firma", "rúbrica"
    final lines = text.split('\n');
    for (final line in lines) {
      if (line.toLowerCase().contains('firma') ||
          line.toLowerCase().contains('fecha') ||
          line.toLowerCase().contains('rúbrica')) {
        for (final pattern in datePatterns) {
          final match = pattern.firstMatch(line);
          if (match != null) {
            try {
              final groups = match.groups([1, 2, 3]);
              final num1 = int.parse(groups[0] ?? '0');
              final num2 = int.parse(groups[1] ?? '0');
              final num3 = int.parse(groups[2] ?? '0');

              // Detectar formato
              if (num3 > 31) {
                // Formato YYYY-MM-DD o YYYY/MM/DD
                if (num2 >= 1 && num2 <= 12 && num1 >= 1 && num1 <= 31) {
                  return DateTime(num3, num2, num1);
                }
              } else {
                // Formato DD/MM/YYYY o DD-MM-YYYY
                if (num2 >= 1 && num2 <= 12) {
                  return DateTime(num3, num2, num1);
                }
              }
            } catch (_) {}
          }
        }
      }
    }

    return null;
  }

  /// Convierte URL de Google Drive compartida a URL de descarga directa
  String _convertGoogleDriveUrlToDownload(String url) {
    // Extraer file ID de diferentes formatos de Google Drive
    final fileIdPattern = RegExp(r'/file/d/([a-zA-Z0-9-_]+)');
    final match = fileIdPattern.firstMatch(url);
    
    if (match != null) {
      final fileId = match.group(1);
      return 'https://drive.google.com/uc?export=download&id=$fileId';
    }

    // Si ya tiene parámetro id=
    if (url.contains('id=')) {
      final idPattern = RegExp(r'id=([a-zA-Z0-9-_]+)');
      final idMatch = idPattern.firstMatch(url);
      if (idMatch != null) {
        return 'https://drive.google.com/uc?export=download&id=${idMatch.group(1)}';
      }
    }

    return url;
  }

  /// Descarga bytes del PDF desde una URL
  Future<Uint8List> _downloadPdfBytes(String url) async {
    final response = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 30),
    );

    if (response.statusCode != 200) {
      throw Exception('Error descargando PDF: ${response.statusCode}');
    }

    return response.bodyBytes;
  }
}
