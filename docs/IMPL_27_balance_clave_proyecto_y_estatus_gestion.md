# IMPL_27: Balance por clave+proyecto y estatus visible en Gestión

**Estado**: Implementado
**Fecha**: 2026-05-14
**Rama**: desktop/fase-1

## Objetivo
Corregir la pérdida de registros en la tabla de Gestión y asegurar que el estatus importado se refleje en las columnas derivadas de `Predio.estatusGestion`.

## Diagnostico / contexto actual
La tabla de Gestión estaba compactando filas al deduplicar predios con la misma clave catastral, aun cuando pertenecían a proyectos distintos. Eso provocaba que parte de los 159 registros del GeoJSON terminaran visibles como 108. Además, algunos registros quedaban sin banderas booleanas (`cop`, `identificacion`, `levantamiento`, `negociacion`), por lo que la columna de estatus seguía mostrando `Sin estatus`.

## Fases con alcance tecnico

### Fase 1: Cambiar la llave de merge a clave+proyecto
Descripcion:
- El merge y la deduplicacion de predios ahora usan una llave compuesta por `clave_catastral + proyecto`.
- Se evita compactar filas distintas que comparten clave pero pertenecen a proyectos diferentes.

Archivos afectados:
- lib/features/predios/providers/local_predios_provider.dart
- lib/features/predios/providers/predios_provider.dart

Codigo clave:
- `_findMatchingPredioIndex(...)`
- `_mergeKey(...)`
- `_buildMergedPredios(...)`

Tiempo estimado: 35 min
Riesgo: Medio

### Fase 2: Mantener el estatus importado en las banderas de Gestion
Descripcion:
- La importacion local traduce `estatus` textual a las banderas booleanas que consume la UI.
- El estatus de Gestión deriva correctamente en `Liberado` o `No liberado`.

Archivos afectados:
- lib/features/predios/providers/local_predios_provider.dart
- lib/features/carga/services/sincronizacion_service.dart

Codigo clave:
- `_flagsFromEstatus(...)`
- `_buildNuevoPredioData(...)`
- `_buildGestionUpdateData(...)`

Tiempo estimado: 25 min
Riesgo: Bajo

### Fase 3: Validacion de la tabla de Gestion
Descripcion:
- Se valida que la vista de tabla no vuelva a compactar los registros importados en exceso.
- Se conserva la normalizacion inicial de datos, pero con una llave consistente con el flujo de importacion.

Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart

Codigo clave:
- `_normalizarDatosLocalesExistentes()`
- `prediosListProvider`

Tiempo estimado: 20 min
Riesgo: Bajo

## Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Llave compuesta para merge | 35 min | Medio |
| Estatus en banderas de Gestión | 25 min | Bajo |
| Validacion de tabla | 20 min | Bajo |
| Total | 80 min | Bajo |

## Criterio de exito
- La tabla de Gestión no reduce los 159 registros del GeoJSON a 108 por usar la clave catastral sola.
- Los predios importados muestran estatus consistente en la UI de Gestión.
- La deduplicacion deja de fusionar filas válidas de distintos proyectos.

## Resultado / evidencia
- Se ajustó la llave de merge y la deduplicacion a `clave+proyecto`.
- Se mantuvo la traduccion de estatus a banderas booleanas durante la importacion.
- Verificacion estatica de los archivos tocados sin errores de analisis.

## Proximo paso
- Reabrir la tabla de Gestión y confirmar que el conteo vuelve a reflejar el total esperado del archivo importado.
