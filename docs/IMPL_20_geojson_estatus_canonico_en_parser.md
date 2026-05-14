# IMPL_20: Estandarizacion canonica de estatus en parser GeoJSON

**Estado**: Implementado
**Fecha**: 13 de mayo de 2026
**Rama**: desktop/fase-1

## Objetivo
Resolver el caso en que los poligonos importados seguian apareciendo en gris aunque el GeoJSON contuviera la propiedad estatus.

## Diagnostico / contexto actual
La normalizacion solo ocurria en la capa de render del mapa. Si el feature llegaba con llaves o valores heterogeneos, el flujo podia seguir sin una propiedad canonica estable. Eso dejaba la deteccion dependiente del render y no del dato importado.

## Fases
### Fase 1: Canonizar estatus en el parser de GeoJSON
- Descripcion: detectar, normalizar y guardar el estatus en properties.estatus y properties.estatus_predio durante el parseo.
- Archivos afectados: lib/features/carga/services/geojson_background_parser.dart
- Codigo clave:
  - `_extractNormalizedStatus(...)`
  - `_normalizeStatusKey(...)`
  - `_normalizeStatusValue(...)`
- Tiempo estimado: 30 min
- Riesgo: Bajo

### Fase 2: Exponer estatus normalizado en preview
- Descripcion: agregar el estatus al preview del archivo importado para inspeccion visual durante la carga.
- Archivos afectados: lib/features/carga/services/geojson_background_parser.dart
- Tiempo estimado: 10 min
- Riesgo: Bajo

## Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|------|------------------|--------|
| Canonizacion en parser | 30 min | Bajo |
| Preview de estatus | 10 min | Bajo |

## Criterio de exito
- Cada feature importado contiene un campo canonico de estatus tras parsearse.
- El mapa puede pintar verde/rojo/gris usando ese dato ya normalizado.
- El preview de carga permite confirmar el estatus reconocido antes de renderizar.

## Resultado / evidencia
- Sin errores de analisis en parser y mapa tras el ajuste.
- El estatus ya no depende solo de heuristicas de render; ahora viaja normalizado desde la importacion.

## Proximo paso
Reimportar el GeoJSON en la app de escritorio y validar que el preview muestre estatus y que los poligonos se rellenen correctamente en el mapa.
