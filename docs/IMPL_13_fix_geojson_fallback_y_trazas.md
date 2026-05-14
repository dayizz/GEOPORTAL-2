# IMPL_13 Fix GeoJSON Fallback y Trazas

Estado: Implementado
Fecha: 2026-05-14
Rama: desktop/fase-1

## Objetivo
Asegurar que la importacion GeoJSON se ejecute de forma visible y completa aun cuando el backend no este disponible, evitando bloqueos percibidos por el usuario.

## Diagnostico / Contexto actual
- El flujo GeoJSON podia quedar en espera durante sincronizacion remota cuando el backend no respondia.
- En fallback local, el archivo no siempre quedaba registrado en la lista de importados.
- Se detecto inconsistencia en el enrutamiento de extension XLS/XLSX (`xlsl` en lugar de `xls`) que podia generar rutas equivocadas.
- Faltaba trazabilidad en tiempo de ejecucion para confirmar el punto de bloqueo.

## Fases

### Fase 1: Pre-check rapido de backend y fallback local inmediato
Descripcion:
- Se agrego verificacion rapida de disponibilidad de backend para GeoJSON.
- Si no hay backend, se importa directamente en modo local y se completa estado/progreso.

Archivos afectados:
- lib/features/carga/presentation/carga_archivo_screen.dart

Codigo clave:
- `_backendDisponibleParaGeoJson()`
- `_importarGeoJsonEnModoLocal(...)`
- uso en `_guardarYVerEnMapa()` antes de llamar `sincronizar(...)`

Tiempo estimado: 45 min
Riesgo: Medio

### Fase 2: Persistencia del archivo en fallback local
Descripcion:
- Se registro el archivo importado en almacenamiento local y provider aun en modo offline.
- Se conserva navegacion a Gestion y feedback de exito para evitar percepcion de fallo.

Archivos afectados:
- lib/features/carga/presentation/carga_archivo_screen.dart

Codigo clave:
- `localArchivosRepository.saveArchivo(...)` en fallback local
- `cargaProvider.addFile(...)` con `fileId` y `bdId` opcional

Tiempo estimado: 25 min
Riesgo: Bajo

### Fase 3: Correccion de extension y trazas de ejecucion
Descripcion:
- Se corrigio typo de extension (`xlsl` -> `xls`) en dispatch y texto de ayuda.
- Se agregaron trazas de depuracion para: seleccion, parseo, inicio de sincronizacion, primer progreso y activacion de fallback.

Archivos afectados:
- lib/features/carga/presentation/carga_archivo_screen.dart

Codigo clave:
- condicion `if (ext == 'xlsx' || ext == 'xls')`
- `debugPrint('[GEOJSON] ...')` en parseo/sincronizacion

Tiempo estimado: 20 min
Riesgo: Bajo

## Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 45 min | Medio |
| Fase 2 | 25 min | Bajo |
| Fase 3 | 20 min | Bajo |
| Total | 90 min | Medio |

## Criterio de exito
- La importacion GeoJSON inicia y completa sin quedarse congelada cuando backend no esta disponible.
- El archivo importado aparece en la lista de documentos importados en modo local.
- Se observan trazas de ejecucion que confirman el avance por etapas.

## Resultado / Evidencia
- Cambios aplicados en:
  - lib/features/carga/presentation/carga_archivo_screen.dart
- Verificacion con analisis estatico del archivo modificado sin errores de compilacion.

## Proximo paso
- Ejecutar prueba manual con un GeoJSON real y revisar consola para confirmar la secuencia de trazas `[GEOJSON]`.
- Si el backend local esta disponible, validar que la ruta remota emite progreso y guarda en lista sin duplicados.
