import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../../core/config/backend_config.dart';

class BackendService {
  static String get _baseUrl => BackendConfig.baseUrl;

  static Future<int?> procesarValor(int valor) async {
    final url = Uri.parse('$_baseUrl/procesar');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'valor': valor}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['resultado'] as int?;
    }
    return null;
  }

  static Future<ReportePdfResponse?> generarReporte(Map<String, dynamic> payload) async {
    final url = Uri.parse('$_baseUrl/reportes/generar');
    http.Response response = http.Response('', 500); // Valor por defecto para evitar LateInitializationError
    try {
      response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/pdf, application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw Exception('Tiempo de espera agotado al generar el reporte. Verifica que el backend este activo en $_baseUrl.');
    } on SocketException {
      throw Exception('No se pudo conectar al backend ($_baseUrl). Inicia el servicio API e intenta nuevamente.');
    }

    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      final disposition = response.headers['content-disposition'] ?? '';
      final match = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
      return ReportePdfResponse(
        bytes: response.bodyBytes,
        fileName: match?.group(1) ?? 'reporte.pdf',
      );
    }

    final rawBody = response.body.trim();
    String serverMessage = rawBody;
    if (rawBody.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawBody);
        if (decoded is Map<String, dynamic>) {
          serverMessage = (decoded['detail'] ?? decoded['message'] ?? rawBody).toString();
        }
      } catch (_) {
        // Keep rawBody when response is not JSON.
      }
    }

    throw Exception(
      'Error del backend (${response.statusCode}) al generar reporte${serverMessage.isEmpty ? '' : ': $serverMessage'}',
    );

  }
}

class ReportePdfResponse {
  final Uint8List bytes;
  final String fileName;

  const ReportePdfResponse({
    required this.bytes,
    required this.fileName,
  });
}
