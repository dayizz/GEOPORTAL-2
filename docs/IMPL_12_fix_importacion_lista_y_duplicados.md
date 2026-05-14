# IMPL_12 Fix Importacion Lista y Duplicados

Estado: Implementado
Fecha: 2026-05-14
Rama: desktop/fase-1

## Objetivo
Corregir dos fallas reportadas en importacion:
- El archivo importado no quedaba guardado correctamente en la lista de documentos.
- El total de registros podia duplicarse o triplicarse por ejecuciones simultaneas/reentradas.

## Diagnostico / Contexto actual
- En flujos XLSX, el archivo se registraba con `features` vacios (`const []`).
- En casos de reentrada (acciones repetidas de importacion), se podia ejecutar mas de una sincronizacion sobre el mismo archivo.
- El `cargaProvider.addFile` insertaba siempre al inicio, sin deduplicar por `id`/`bdId`.

## Fases

### Fase 1: Persistir features reales en lista importada
Descripcion:
- Se agrego helper para transformar filas XLSX en features serializables y guardarlas junto al archivo.

Archivos afectados:
- lib/features/carga/presentation/carga_archivo_screen.dart

Codigo clave:
- `_xlsxRowsAsFeatures(...)`
- uso de `customId: fileId`
- `saveArchivo(... features: xlsxFeatures ...)`
- `addFile(... xlsxFeatures ... fileId: fileId ...)`

Tiempo estimado: 30 min
Riesgo: Bajo

### Fase 2: Evitar reentrada en importaciones
Descripcion:
- Se agregaron guardas para no iniciar una nueva importacion mientras `_sincronizando` es `true`.

Archivos afectados:
- lib/features/carga/presentation/carga_archivo_screen.dart

Codigo clave:
- `if (_sincronizando) return;` en `_guardarYVerEnMapa`, `_inyectarXlsxEnTablas` y `_inyectarXlsxLocal`.

Tiempo estimado: 20 min
Riesgo: Bajo

### Fase 3: Deduplicar lista en provider
Descripcion:
- `addFile` ahora reemplaza elementos repetidos por `id` y `bdId` para evitar entradas duplicadas.

Archivos afectados:
- lib/features/carga/providers/carga_provider.dart

Codigo clave:
- bloque `deduped` antes de reconstruir `state`.

Tiempo estimado: 20 min
Riesgo: Bajo

## Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 30 min | Bajo |
| Fase 2 | 20 min | Bajo |
| Fase 3 | 20 min | Bajo |
| Total | 70 min | Bajo |

## Criterio de exito
- El archivo importado aparece en la lista de documentos importados tras completar la operacion.
- La cantidad de registros mostrada coincide con el contenido real del archivo.
- No se generan entradas duplicadas para el mismo archivo en la lista.

## Resultado / Evidencia
- Cambios aplicados en:
  - lib/features/carga/presentation/carga_archivo_screen.dart
  - lib/features/carga/providers/carga_provider.dart
- Analisis estatico sin errores de compilacion en archivos modificados.

## Proximo paso
- Probar flujo manual de importacion (GeoJSON y XLSX) y validar conteo final vs origen.
- Si el entorno de macOS vuelve a fallar por code signing local, ejecutar prueba en copia limpia temporal del workspace.
