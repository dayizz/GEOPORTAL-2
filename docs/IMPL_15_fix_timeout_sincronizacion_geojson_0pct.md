# IMPL_15 Fix Timeout Sincronizacion GeoJSON 0pct

Estado: Implementado
Fecha: 2026-05-14
Rama: desktop/fase-1

## Objetivo
Evitar que la importacion GeoJSON quede indefinidamente en estado "Guardando" o "Sincronizando 0%" cuando la sincronizacion remota se atora sin progreso.

## Diagnostico / contexto actual
- El frontend parsea correctamente el archivo y muestra vista previa/contadores.
- El bloqueo ocurre en la fase de sincronizacion remota: la UI puede quedarse en 0% por tiempo indefinido.
- En estos casos el usuario percibe que la accion "se esfuma" aunque ya habia datos listos para importar.

## Fases con alcance tecnico

### Fase 1: Timeout explicito en sincronizacion remota
Descripcion:
- Se agrega un timeout de 45 segundos para la llamada a `sincronizar(...)`.
- Si no hay progreso util en ese intervalo, se dispara `TimeoutException`.

Archivos afectados:
- lib/features/carga/presentation/carga_archivo_screen.dart

Codigo clave:
- `static const Duration _geoJsonSyncTimeout = Duration(seconds: 45)`
- `.timeout(_geoJsonSyncTimeout, onTimeout: ...)` sobre `syncService.sincronizar(...)`

Tiempo estimado: 20 min
Riesgo: Bajo

### Fase 2: Fallback controlado y feedback al usuario
Descripcion:
- Ante timeout, se muestra mensaje explicito y se continua importacion en modo local.
- Se conserva navegacion/registro para no perder la operacion.

Archivos afectados:
- lib/features/carga/presentation/carga_archivo_screen.dart

Codigo clave:
- Snackbar: "La sincronizacion remota tardo demasiado. Continuando en modo local."
- reutilizacion de `_importarGeoJsonEnModoLocal(...)`

Tiempo estimado: 15 min
Riesgo: Bajo

### Fase 3: Ajuste de etapa inicial de progreso
Descripcion:
- Se cambia etapa inicial de importacion a "Preparando envio" antes de recibir progreso remoto.
- Reduce percepcion de estancamiento en 0% sin contexto.

Archivos afectados:
- lib/features/carga/presentation/carga_archivo_screen.dart

Codigo clave:
- `iniciar(... etapa: 'Preparando envio')`

Tiempo estimado: 10 min
Riesgo: Bajo

## Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 20 min | Bajo |
| Fase 2 | 15 min | Bajo |
| Fase 3 | 10 min | Bajo |
| Total | 45 min | Bajo |

## Criterio de exito
- La importacion GeoJSON no queda indefinidamente en 0%.
- Si la sincronizacion remota se atora, la app completa por modo local automaticamente.
- El usuario recibe feedback claro del fallback aplicado.

## Resultado / evidencia
- Cambios aplicados en:
  - lib/features/carga/presentation/carga_archivo_screen.dart
- Verificacion con analisis estatico del archivo modificado sin errores de compilacion.

## Proximo paso
- Probar con TSNL_16_17.geojson y confirmar que, ante atoro remoto, se observe timeout + fallback local + registro en Gestion.
