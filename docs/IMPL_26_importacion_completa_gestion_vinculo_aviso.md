# IMPL_26: Importacion completa en Gestion, estatus canonico y aviso de vinculacion

**Estado**: Implementado
**Fecha**: 2026-05-14
**Rama**: desktop/fase-1

## Objetivo
Corregir la importacion GeoJSON para que no colapse registros al pasar de mapa a Gestion, autoidentificar el estatus en los campos que usa Gestion, y mostrar un aviso visual en el mapa cuando un poligono no tenga datos suficientes para vincularse a la BD.

## Diagnostico / contexto actual
El archivo GeoJSON ya se parseaba y se renderizaba, pero el flujo local estaba consolidando registros por clave y eso reducia el total visible en Gestion. Ademas, el estatus normalizado no siempre se traducía a las banderas booleanas que usa la vista de Gestion, por lo que algunos predios quedaban sin clasificacion util. Finalmente, faltaba una señal visual para diferenciar los poligonos sin vinculacion clara con la base de datos.

## Fases con alcance tecnico

### Fase 1: Evitar colapso de registros importados
Descripcion:
- Se elimina la deduplicacion por similitud durante la importacion local.
- Cada feature importado conserva una identidad local unica para no perder filas en Gestion.
- Se preserva `archivoId` para trazar el origen de la carga.

Archivos afectados:
- lib/features/predios/providers/local_predios_provider.dart
- lib/features/carga/presentation/carga_archivo_screen.dart

Codigo clave:
- `upsertManyFromGeoJsonFeatures(..., { String? archivoId })`
- id local unico por feature importado

Tiempo estimado: 35 min
Riesgo: Medio

### Fase 2: Autoidentificar estatus en campos de Gestion
Descripcion:
- El estatus textual del GeoJSON se traduce a banderas booleanas que usa la UI de Gestion.
- `Liberado` se marca como COP.
- `No liberado` se refleja como estado en negociacion o pendiente, segun la logica local.

Archivos afectados:
- lib/features/predios/providers/local_predios_provider.dart

Codigo clave:
- `_flagsFromEstatus(...)`
- mapeo de `cop`, `identificacion`, `levantamiento`, `negociacion`

Tiempo estimado: 25 min
Riesgo: Medio

### Fase 3: Aviso visual en poligonos sin vinculacion
Descripcion:
- Se anotan features importados con una marca de advertencia cuando no tienen suficientes datos de negocio para vincularse.
- El mapa dibuja un icono de warning en el centroide del poligono.

Archivos afectados:
- lib/features/carga/presentation/carga_archivo_screen.dart
- lib/features/mapa/presentation/mapa_screen.dart

Codigo clave:
- `_annotateGeoJsonFeaturesForMap(...)`
- `_buildImportedMarkers(...)` con marcador de advertencia

Tiempo estimado: 30 min
Riesgo: Bajo

## Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Evitar colapso de registros | 35 min | Medio |
| Autoidentificar estatus | 25 min | Medio |
| Aviso visual de vinculacion | 30 min | Bajo |
| Total | 90 min | Medio |

## Criterio de exito
- La importacion registra los 159 elementos esperados sin reducir el conteo por deduplicacion accidental.
- Gestion muestra los registros importados con el estatus reflejado en sus banderas.
- El mapa muestra un icono de aviso en los poligonos sin datos suficientes para vinculacion.

## Resultado / evidencia
- Se aplicaron cambios en la ruta de importacion local, en la normalizacion de estatus y en el render del mapa.
- Validacion estatica ejecutada sobre los archivos tocados sin errores de compilacion.

## Proximo paso
- Probar el mismo GeoJSON de referencia y verificar:
  - conteo completo en Gestion,
  - clasificacion por estatus,
  - advertencias visuales sobre poligonos sin vinculacion.
