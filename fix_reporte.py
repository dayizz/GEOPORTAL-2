#!/usr/bin/env python3
import re

# Read the file
with open('lib/features/reportes/presentation/generar_reporte_screen.dart', 'r') as f:
    content = f.read()

# Replace courier with notoSans
content = content.replace('pw.Font.courier()', 'await PdfGoogleFonts.notoSansRegular()')
content = content.replace('pw.Font.courierBold()', 'await PdfGoogleFonts.notoSansBold()')

# The header section - make the 3 lines bold
old_header = """                      pw.Text(
                        'Agencia de Trenes y Transporte Público Integrado',
                        style: pw.TextStyle(fontSize: 10, font: await PdfGoogleFonts.notoSansBold()),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Unidad de Verificación, Seguridad y Registro',
                        style: pw.TextStyle(fontSize: 10, font: await PdfGoogleFonts.notoSansRegular()),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Dirección de Verificación Ferroviaria "A"',
                        style: pw.TextStyle(fontSize: 10, font: await PdfGoogleFonts.notoSansRegular()),
                      ),"""

new_header = """                      pw.Text(
                        'Agencia de Trenes y Transporte Público Integrado',
                        style: pw.TextStyle(fontSize: 10, font: await PdfGoogleFonts.notoSansBold()),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Unidad de Verificación, Seguridad y Registro',
                        style: pw.TextStyle(fontSize: 10, font: await PdfGoogleFonts.notoSansBold()),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Dirección de Verificación Ferroviaria "A"',
                        style: pw.TextStyle(fontSize: 10, font: await PdfGoogleFonts.notoSansBold()),
                      ),"""

if old_header in content:
    content = content.replace(old_header, new_header)
    print("1. Header bold replaced")

# Asunto: bold followed by normal text
old_asunto = """                      pw.Text(
                        'Asunto: ${_asuntoCtrl.text.isNotEmpty ? _asuntoCtrl.text : 'Informe del balance actual del proyecto $proyectoNombre'}',
                        style: pw.TextStyle(fontSize: 10, font: await PdfGoogleFonts.notoSansRegular()),
                      ),"""

new_asunto = """                      pw.Row(
                        children: [
                          pw.Text(
                            'Asunto: ',
                            style: pw.TextStyle(fontSize: 10, font: await PdfGoogleFonts.notoSansBold()),
                          ),
                          pw.Text(
                            _asuntoCtrl.text.isNotEmpty ? _asuntoCtrl.text : 'Informe del balance actual del proyecto $proyectoNombre',
                            style: pw.TextStyle(fontSize: 10, font: await PdfGoogleFonts.notoSansRegular()),
                          ),
                        ],
                      ),"""

if old_asunto in content:
    content = content.replace(old_asunto, new_asunto)
    print("2. Asunto replaced")
else:
    print("2. Asunto not found")

# PARA / DE section - put DE below PARA
old_para_de = """                // PARA / DE - en negritas
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'PARA:',
                            style: pw.TextStyle(
                              fontSize: 11,
                              font: await PdfGoogleFonts.notoSansBold(),
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            _paraNombreCtrl.text.isNotEmpty ? _paraNombreCtrl.text : '(Nombre)',
                            style: pw.TextStyle(fontSize: 10, font: await PdfGoogleFonts.notoSansRegular()),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            _paraCargoCtrl.text.isNotEmpty ? _paraCargoCtrl.text : '(Cargo)',
                            style: pw.TextStyle(fontSize: 10, font: await PdfGoogleFonts.notoSansRegular()),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'DE:',
                            style: pw.TextStyle(
                              fontSize: 11,
                              font: await PdfGoogleFonts.notoSansBold(),
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            _deNombreCtrl.text.isNotEmpty ? _deNombreCtrl.text : '(Nombre)',
                            style: pw.TextStyle(fontSize: 10, font: await PdfGoogleFonts.notoSansRegular()),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            _deCargoCtrl.text.isNotEmpty ? _deCargoCtrl.text : '(Cargo)',
                            style: pw.TextStyle(fontSize: 10, font: await PdfGoogleFonts.notoSansRegular()),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),"""

new_para_de = """                // PARA - en negritas
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'PARA:',
                            style: pw.TextStyle(
                              fontSize: 11,
                              font: await PdfGoogleFonts.notoSansBold(),
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            _paraNombreCtrl.text.isNotEmpty ? _paraNombreCtrl.text : '(Nombre)',
                            style: pw.TextStyle(fontSize: 10, font: await PdfGoogleFonts.notoSansRegular()),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            _paraCargoCtrl.text.isNotEmpty ? _paraCargoCtrl.text : '(Cargo)',
                            style: pw.TextStyle(fontSize: 10, font: await PdfGoogleFonts.notoSansRegular()),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                // DE - debajo de PARA, en negritas
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'DE:',
                            style: pw.TextStyle(
                              fontSize: 11,
                              font: await PdfGoogleFonts.notoSansBold(),
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            _deNombreCtrl.text.isNotEmpty ? _deNombreCtrl.text : '(Nombre)',
                            style: pw.TextStyle(fontSize: 10, font: await PdfGoogleFonts.notoSansRegular()),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            _deCargoCtrl.text.isNotEmpty ? _deCargoCtrl.text : '(Cargo)',
                            style: pw.TextStyle(fontSize: 10, font: await PdfGoogleFonts.notoSansRegular()),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),"""

if old_para_de in content:
    content = content.replace(old_para_de, new_para_de)
    print("3. PARA/DE replaced")
else:
    print("3. PARA/DE not found")

# Remove the border from the summary section
old_summary = """                // Resumen de información del proyecto
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  child: pw.Column("""

new_summary = """                // Resumen de información del proyecto (sin cuadro)
                pw.Column("""

if old_summary in content:
    content = content.replace(old_summary, new_summary)
    print("4. Summary section replaced")
else:
    print("4. Summary pattern not found")

# Find the closing of the summary container and remove it
# We need to find the end of the summary column, which is after "No liberados"
# and then close the Container
old_summary_end = """                      pw.Text(
                        '  - No liberados: $sinCop',
                        style: pw.TextStyle(fontSize: 10, font: await PdfGoogleFonts.notoSansRegular()),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );"""

new_summary_end = """                      pw.Text(
                        '  - No liberados: $sinCop',
                        style: pw.TextStyle(fontSize: 10, font: await PdfGoogleFonts.notoSansRegular()),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      );"""

if old_summary_end in content:
    content = content.replace(old_summary_end, new_summary_end)
    print("5. Summary end replaced")
else:
    print("5. Summary end not found")

# Write the file
with open('lib/features/reportes/presentation/generar_reporte_screen.dart', 'w') as f:
    f.write(content)
    
print("Done!")