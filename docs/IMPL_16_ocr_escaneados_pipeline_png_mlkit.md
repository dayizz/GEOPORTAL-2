# IMPL_16: OCR robusto para documentos escaneados (pipeline PNG + ML Kit)

**Estado**: Implementado
**Fecha**: 13 de mayo de 2026
**Rama**: desktop/fase-1

## Objetivo
Asegurar lectura OCR confiable de documentos PDF escaneados para auto-relleno de campos de gestion (km inicio, km fin, m2 y fecha).

## Diagnostico / contexto actual
El flujo previo enviaba la imagen renderizada del PDF a ML Kit mediante InputImage.fromBytes con metadata de formato BGRA. En PDFs escaneados esto puede fallar porque la imagen renderizada estaba en PNG, no en buffer de pixeles crudos BGRA.

## Fases
### Fase 1: Correccion del pipeline de imagen para OCR
- Descripcion: cambiar el origen de InputImage para usar archivo PNG temporal y InputImage.fromFilePath.
- Archivos afectados: lib/features/tabla/services/pdf_ocr_service.dart
- Codigo clave:
  - Render de pagina PDF a PNG de alta resolucion.
  - Escritura temporal en systemTemp.
  - OCR con InputImage.fromFilePath.
  - Limpieza garantizada de archivo temporal en bloque finally.
- Tiempo estimado: 35 min
- Riesgo: Bajo

### Fase 2: Mejoras para legibilidad de escaneados
- Descripcion: incremento de resolucion de render para mejorar deteccion en texto tenue o borroso.
- Archivos afectados: lib/features/tabla/services/pdf_ocr_service.dart
- Codigo clave:
  - width: 2200
  - height: 3000
- Tiempo estimado: 10 min
- Riesgo: Bajo

## Resumen de esfuerzo
| Fase | Esfuerzo | Riesgo |
|------|----------|--------|
| Correccion de pipeline OCR | 35 min | Bajo |
| Ajuste de resolucion | 10 min | Bajo |
| Validacion tecnica | 10 min | Bajo |

## Criterio de exito
- OCR detecta texto en PDFs escaneados donde antes no detectaba.
- Se mantiene compatibilidad con extraccion actual de km, m2 y fecha.
- No se introducen errores de compilacion en el servicio OCR.

## Resultado / evidencia
- Se sustituyo InputImage.fromBytes por InputImage.fromFilePath sobre PNG temporal.
- Se implemento limpieza de temporales para evitar archivos residuales.
- Se incremento la resolucion de render para mejorar reconocimiento en escaneados.

## Proximo paso
Validar con al menos 3 PDFs escaneados reales en flujo de Gestion y revisar texto OCR crudo para ajustar regex si aparece variacion de formato en km.
