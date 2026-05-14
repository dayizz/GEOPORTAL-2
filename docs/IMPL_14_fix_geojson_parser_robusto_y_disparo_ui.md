# IMPL_14 Fix GeoJSON Parser Robusto y Disparo UI

Estado: Implementado
Fecha: 2026-05-14
Rama: desktop/fase-1

## Objetivo
Corregir casos donde la importacion GeoJSON no iniciaba o no avanzaba por problemas de codificacion del archivo o por una condicion de interfaz que ocultaba la accion de guardado.

## Diagnostico / contexto actual
- Algunos GeoJSON pueden incluir BOM o bytes no UTF-8 estrictos.
- Si el parseo devolvia estructuras no utilizables, la UI podia quedar sin accion clara.
- La seccion de accion dependia de preview, lo que podia impedir disparar importacion en casos limite.

## Fases con alcance tecnico

### Fase 1: Parser tolerante a codificacion real
Descripcion:
- Se reforzo la lectura del contenido para tolerar bytes malformados y eliminar BOM inicial.
- Se agrega error explicito cuando no hay features con estructura valida para importar.

Archivos afectados:
- lib/features/carga/services/geojson_background_parser.dart

Codigo clave:
- fallback `utf8.decode(bytes, allowMalformed: true)`
- remocion de BOM (`\uFEFF`)
- validacion `enrichedFeatures.isEmpty`

Tiempo estimado: 30 min
Riesgo: Bajo

### Fase 2: Disparo de accion de guardado en UI
Descripcion:
- Se amplio la condicion de visualizacion de accion para permitir guardado si ya existe `_geoJsonData`, incluso cuando preview no este poblado.
- Se agrego reintento de parseo al presionar Guardar cuando el estado en memoria llega vacio o inconsistente, para no abortar silenciosamente la importacion.

Archivos afectados:
- lib/features/carga/presentation/carga_archivo_screen.dart

Codigo clave:
- condicion de render con `|| _geoJsonData != null`
- `_leerBytesArchivoSeleccionado()`
- bloque de reparse en `_guardarYVerEnMapa()`

Tiempo estimado: 15 min
Riesgo: Bajo

## Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 30 min | Bajo |
| Fase 2 | 15 min | Bajo |
| Total | 45 min | Bajo |

## Criterio de exito
- El archivo GeoJSON se parsea en mas escenarios de codificacion.
- La accion de importacion/guardado permanece disponible cuando hay datos parseados.
- Si el estado temporal se pierde, Guardar vuelve a parsear y ejecuta la importacion en vez de terminar sin accion.
- El usuario puede completar importacion sin quedarse en estado inactivo por UI.

## Resultado / evidencia
- Cambios aplicados en:
  - lib/features/carga/services/geojson_background_parser.dart
  - lib/features/carga/presentation/carga_archivo_screen.dart
- Verificacion con analisis estatico en archivos modificados sin errores de compilacion.

## Proximo paso
- Ejecutar prueba manual con GeoJSON problematico y validar trazas `[GEOJSON]` para confirmar secuencia completa: parseo, inicio de guardado, backend/fallback y finalizacion.
