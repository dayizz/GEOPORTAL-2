# IMPL_24: Canonizacion de propiedades GeoJSON para Gestion y Mapa

**Estado**: Implementado
**Fecha**: 13 de mayo de 2026
**Rama**: desktop/fase-1

## Objetivo
Corregir la lectura incompleta de propiedades del GeoJSON para que se registren correctamente en Gestion y se rendericen los poligonos por estatus en el mapa.

## Diagnostico / contexto actual
El problema no estaba solo en el render. El flujo tenia una inconsistencia estructural:
- El parser marcaba el feature como normalizado.
- La sincronizacion seguia usando en gran parte las properties originales del archivo.
- El normalizador central no contemplaba varias columnas reales del archivo compartido.

Esto afectaba tanto el registro en Gestion como el coloreo por estatus en el mapa.

## Fases
### Fase 1: Ampliar alias reales del GeoJSON
**Archivo afectado**: lib/features/carga/utils/geojson_mapper.dart
**Cambios**:
- `TIPO DE PROPIEDAD` -> `tipo_propiedad`
- `PROPIETARIO O PARCELA` -> `propietario_nombre`
- `M2` -> `superficie`
- `KM INIICIO` / `KM INICIO` -> `km_inicio`
- `KM FIN` -> `km_fin`
- `KM LINEALES` -> `km_lineales`
- `KM EFECTIVOS` -> `km_efectivos`
- `ESTATUS` / `ESTATUS ACTUAL` -> `estatus`

### Fase 2: Canonizar estatus como valor de negocio
**Archivo afectado**: lib/features/carga/utils/geojson_mapper.dart
**Cambios**:
- Nuevo normalizador para `estatus`.
- Salidas canónicas: `Liberado`, `No liberado`, `Sin estatus`.

### Fase 3: Canonizar desde parser y reutilizar en sincronizacion
**Archivos afectados**:
- lib/features/carga/services/geojson_background_parser.dart
- lib/features/carga/services/sincronizacion_service.dart
**Cambios**:
- El parser genera properties enriquecidas a partir de props originales + props canonizadas.
- La sincronizacion siempre mezcla properties originales con properties normalizadas antes de registrar en Gestion o renderizar en mapa.

## Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|------|------------------|--------|
| Alias reales del archivo | 20 min | Bajo |
| Normalizacion de estatus | 10 min | Bajo |
| Canonizacion en parser y sync | 20 min | Bajo |

## Criterio de exito
- El GeoJSON registra correctamente las propiedades relevantes en Gestion.
- El campo ESTATUS del archivo se detecta y normaliza.
- El mapa rellena verde, rojo o gris segun el estatus identificado.

## Resultado / evidencia
- Sin errores de analisis en mapper, parser y sincronizacion.
- Flujo unificado de propiedades canonicas desde importacion hasta render.

## Proximo paso
Reimportar el archivo GeoJSON y validar en paralelo:
1. El preview muestre estatus.
2. Gestion reciba las columnas canonicas.
3. El feature `SNL-SLV-052-5-GS` con `ESTATUS = NO LIBERADO` se renderice en rojo.
