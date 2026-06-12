# IMPL_58 - Fix descarga de reporte en web

Estado: Completado  
Fecha: 2026-06-04  
Rama: desktop/fase-1

## 1. Objetivo
Corregir la descarga de PDF en la pagina web de reportes, que no iniciaba al presionar "Descargar".

## 2. Diagnostico / contexto actual
El flujo de descarga en `ReporteFormScreen` estaba orientado a escritorio (`FilePicker.saveFile` + escritura con `File`), pero en web no iniciaba correctamente la descarga desde el navegador.

## 3. Fases

### Fase 1 - Diagnostico de flujo por plataforma
- Descripcion: Revisar el metodo `_downloadPdf` y determinar incompatibilidad en web.
- Archivos afectados: `lib/features/reportes/presentation/reporte_form_screen.dart`
- Codigo clave: uso de `FilePicker.platform.saveFile` y `File(outputPath).writeAsBytes`.
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2 - Implementacion de descarga web
- Descripcion: Agregar helper con import condicional para navegador que dispare descarga directa de bytes.
- Archivos afectados:
  - `lib/core/utils/download_bytes.dart`
  - `lib/core/utils/download_bytes_stub.dart`
  - `lib/core/utils/download_bytes_web.dart`
- Codigo clave: `triggerBrowserDownload(Uint8List bytes, String fileName)` con `Blob + AnchorElement` en web.
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 3 - Integracion en formulario de reporte
- Descripcion: En `_downloadPdf`, usar descarga web cuando `kIsWeb` y mantener flujo actual para escritorio.
- Archivos afectados: `lib/features/reportes/presentation/reporte_form_screen.dart`
- Codigo clave: rama `if (kIsWeb)` + manejo de errores con `SnackBar`.
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 4 - Validacion tecnica
- Descripcion: Formatear y verificar analisis de los archivos tocados.
- Archivos afectados: los 4 archivos modificados.
- Codigo clave: `dart format` y `get_errors`.
- Tiempo estimado: 5 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 20 min | Bajo |
| Fase 3 | 10 min | Bajo |
| Fase 4 | 5 min | Bajo |
| **Total** | **45 min** | **Bajo** |

## 5. Criterio de exito
- En web, al presionar "Descargar", inicia la descarga del PDF en el navegador.
- En escritorio, se conserva la seleccion de ruta de guardado.
- No aparecen errores de analisis por imports de plataforma.

## 6. Resultado / evidencia
- Se implemento helper condicional para descarga web.
- Se ajusto `_downloadPdf` para usar rama web y notificar al usuario con `SnackBar`.
- Se conservaron las rutas existentes de escritorio.

## 7. Proximo paso
Validar manualmente en `#/reportes/reporte`:
1. Generar reporte.
2. Presionar `Descargar` desde el dialogo.
3. Confirmar archivo PDF descargado en el navegador.
