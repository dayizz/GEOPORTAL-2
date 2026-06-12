# IMPL_19 Fix Bloqueo Guardado Local GeoJSON

Estado: Implementado
Fecha: 2026-05-14
Rama: desktop/fase-1

## Objetivo
Eliminar el bloqueo en "Guardando/Sincronizando" durante importacion GeoJSON cuando la persistencia del archivo importado consume demasiado tiempo, y garantizar inyeccion de datos para Mapa y Gestion.

## Diagnostico / contexto actual
- El parseo GeoJSON era correcto, pero la operacion podia atorarse en guardado local del archivo importado.
- Guardar features completos (con geometria) en persistencia local puede ser costoso y bloquear la finalizacion visible de la importacion.
- Se requiere mantener render inmediato de poligonos y datos en Gestion sin depender de persistencia pesada.

## Fases con alcance tecnico

### Fase 1: Persistencia local ligera para GeoJSON
Descripcion:
- Se agrega limite de features guardadas en indice local para evitar escrituras pesadas.
- Se conserva `rowCount` real para mostrar conteo total importado.

Archivos afectados:
- lib/features/carga/presentation/carga_archivo_screen.dart

Codigo clave:
- `static const int _maxStoredGeoJsonFeatures = 80`
- `_geoJsonFeaturesForStorage(...)`

Tiempo estimado: 30 min
Riesgo: Bajo

### Fase 2: Timeout en guardado de archivo importado
Descripcion:
- Se aplica timeout al `saveArchivo(...)` local para impedir bloqueo indefinido.
- Si falla o expira, la importacion continua sin bloquear al usuario.

Archivos afectados:
- lib/features/carga/presentation/carga_archivo_screen.dart

Codigo clave:
- `.timeout(const Duration(seconds: 3), onTimeout: ...)`

Tiempo estimado: 20 min
Riesgo: Bajo

### Fase 3: Inyeccion garantizada para render y Gestion
Descripcion:
- Se inyectan features completas en estado de mapa para render inmediato en sesion.
- Se mantienen invalidaciones de predios para refrescar Gestion/Mapa.

Archivos afectados:
- lib/features/carga/presentation/carga_archivo_screen.dart

Codigo clave:
- `importedFeaturesProvider.notifier.state = features`
- `mapaColorModeProvider.notifier.state = MapaColorMode.estatusPredio`

Tiempo estimado: 15 min
Riesgo: Bajo

## Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 30 min | Bajo |
| Fase 2 | 20 min | Bajo |
| Fase 3 | 15 min | Bajo |
| Total | 65 min | Bajo |

## Criterio de exito
- La importacion no queda atorada en "Guardando/Sincronizando".
- El archivo GeoJSON se acepta y procesa en flujo completo.
- Los poligonos y la informacion de Gestion quedan inyectados en sesion tras la importacion.

## Resultado / evidencia
- Cambios aplicados en:
  - lib/features/carga/presentation/carga_archivo_screen.dart
- Verificacion con analisis estatico del archivo modificado sin errores de compilacion.

## Proximo paso
- Ejecutar prueba con TSNL_16_17.geojson validando:
  - finalizacion de importacion sin bloqueo,
  - presencia en Gestion,
  - render de poligonos en mapa.
