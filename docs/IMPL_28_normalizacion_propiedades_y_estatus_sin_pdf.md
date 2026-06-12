# IMPL_28: Normalizacion de propiedades y estatus sin PDF

**Estado**: Implementado
**Fecha**: 2026-05-14
**Rama**: desktop/fase-1

## Objetivo
1) Normalizar la lectura de propiedades importadas sin depender de mayúsculas, minúsculas, espacios o separadores.
2) Inyectar estatus en Gestión desde el archivo importado aunque no exista URL de PDF.

## Diagnostico / contexto actual
Se detectaron variantes de propiedades y estatus como `NoLiberado`, `NO_LIBERADO`, ` no liberado ` o llaves con espacios/separadores que no siempre se interpretaban de forma consistente en todos los flujos (parser, sincronización y carga local). Eso podía dejar columnas de Gestión sin la bandera correcta (`cop`, `negociacion`) cuando no había PDF.

## Fases con alcance tecnico

### Fase 1: Normalizacion canonica de estatus
Descripcion:
- Se centraliza una API para normalizar estatus en formato canonico (`Liberado`, `No liberado`, `Sin estatus`).
- Se soportan variantes con espacios, guiones, guion bajo, slash, mayúsculas y formas compactas.

Archivos afectados:
- lib/features/carga/utils/geojson_mapper.dart

Codigo clave:
- `normalizeEstatusNullable(...)`
- `_normalizeEstatus(...)`

Tiempo estimado: 30 min
Riesgo: Bajo

### Fase 2: Propagar normalizacion al parser y sincronizacion
Descripcion:
- El parser de GeoJSON y la sincronización reutilizan la misma normalización canonica.
- La lectura de propiedades en sincronización agrega fallback por clave normalizada para tolerar variaciones de llaves.

Archivos afectados:
- lib/features/carga/services/geojson_background_parser.dart
- lib/features/carga/services/sincronizacion_service.dart

Codigo clave:
- `_normalizeStatusValue(...)`
- `_pick(...)`
- `_pickDynamic(...)`
- `_normalizeStatusLabel(...)`

Tiempo estimado: 35 min
Riesgo: Medio

### Fase 3: Inyeccion de estatus en Gestion sin PDF
Descripcion:
- La carga local convierte estatus canonico a banderas de Gestión aunque no exista URL de PDF.
- `Liberado` activa `cop`; `No liberado` activa `negociacion` cuando no hay otras banderas.

Archivos afectados:
- lib/features/predios/providers/local_predios_provider.dart

Codigo clave:
- `_flagsFromEstatus(...)`

Tiempo estimado: 20 min
Riesgo: Bajo

## Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Estandarizacion de estatus | 30 min | Bajo |
| Integracion parser/sync | 35 min | Medio |
| Inyeccion en Gestion sin PDF | 20 min | Bajo |
| Total | 85 min | Bajo |

## Criterio de exito
- Las propiedades y estatus del archivo importado se leen correctamente aunque cambie formato de llaves/valores.
- La columna de estatus en Gestión refleja datos importados sin depender de URL de PDF.
- No hay errores de compilación en los archivos intervenidos.

## Resultado / evidencia
- Ajustes aplicados en mapper, parser, sincronización y provider local.
- `flutter analyze` sobre archivos intervenidos sin errores (solo warnings/info preexistentes no bloqueantes).

## Proximo paso
- Reimportar el mismo GeoJSON de validación y confirmar que en Gestión aparecen los estatus correctos aun sin PDF.
