# IMPL_29: Estatus textual prioritario en Gestion

**Estado**: Implementado
**Fecha**: 2026-05-14
**Rama**: desktop/fase-1

## Objetivo
Hacer que la columna de estatus en Gestion priorice el valor textual importado (`Liberado` / `No liberado`) en lugar de inferir primero por campos tecnicos (`cop`, `negociacion`, etc.).

## Diagnostico / contexto actual
Aunque se inyectaban banderas tecnicas para compatibilidad, el requerimiento funcional es que el estatus mostrado en Gestion refleje el texto detectado en el archivo importado. Si el dato textual existe, debe dominar sobre inferencias secundarias.

## Fases con alcance tecnico

### Fase 1: Prioridad de estatus textual en modelo de dominio
Descripcion:
- Se actualiza `Predio.estatusGestion` para leer primero estatus textual normalizado desde `situacionSocial`.
- Solo si no existe estatus textual valido, aplica fallback por banderas tecnicas.

Archivos afectados:
- lib/features/predios/models/predio.dart

Codigo clave:
- `estatusGestion`
- `_normalizeEstatusText(...)`

Tiempo estimado: 25 min
Riesgo: Bajo

### Fase 2: Persistencia del estatus textual en importacion local
Descripcion:
- Durante la importacion local, el estatus canonico detectado se guarda en `situacionSocial`.
- Esto garantiza que Gestion renderice `Liberado/No liberado` desde el dato importado.

Archivos afectados:
- lib/features/predios/providers/local_predios_provider.dart

Codigo clave:
- `upsertManyFromGeoJsonFeatures(...)`
- `situacionSocial: estatusCanonico`

Tiempo estimado: 20 min
Riesgo: Bajo

### Fase 3: Persistencia del estatus textual en sincronizacion remota
Descripcion:
- En create/update remoto se escribe `situacion_social` cuando existe estatus textual canonico.
- El dato queda disponible para Gestion aun sin URL de PDF.

Archivos afectados:
- lib/features/carga/services/sincronizacion_service.dart

Codigo clave:
- `_buildNuevoPredioData(...)`
- `_buildGestionUpdateData(...)`

Tiempo estimado: 25 min
Riesgo: Bajo

## Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Prioridad en modelo | 25 min | Bajo |
| Persistencia local | 20 min | Bajo |
| Persistencia remota | 25 min | Bajo |
| Total | 70 min | Bajo |

## Criterio de exito
- Gestion muestra `Liberado` o `No liberado` cuando el archivo importado trae estatus.
- El estatus no depende de que exista PDF.
- No hay errores de compilacion en archivos intervenidos.

## Resultado / evidencia
- Ajustes aplicados en modelo, provider local y servicio de sincronizacion.
- Validacion estatica ejecutada sobre archivos modificados sin errores de compilacion (solo warnings/info no bloqueantes).

## Proximo paso
- Reimportar el GeoJSON de prueba y verificar visualmente en Gestion que la columna estatus coincide con el texto importado.
