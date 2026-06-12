# IMPL_42: Fix inyeccion de Observaciones en Gestion desde GeoJSON

- Estado: Implementado
- Fecha: 27 de mayo de 2026
- Rama: desktop/fase-1

## 1. Objetivo
Corregir que la columna Observaciones en Gestion se alimente con el contenido real de observaciones del GeoJSON, y no con el estatus de liberacion.

## 2. Diagnostico / contexto actual
- `situacion_social` se estaba poblando con `statusLabel` (Liberado/No liberado/Sin estatus) durante create/update de sincronizacion.
- En importacion local, `situacionSocial` tambien se rellenaba con estatus canonico.
- Esto provocaba que la columna Observaciones mostrara estatus en lugar de texto de observaciones del archivo.

## 3. Fases
### Fase 1: Separar mapeo de estatus y observaciones en sincronizacion
Descripcion:
- Se elimino `situacion` de la deteccion de estatus en sincronizacion.
- Se agrego selector dedicado `_pickObservaciones(...)`.
- En create/update de predio, `situacion_social` ahora toma observaciones detectadas del GeoJSON.

Archivos afectados:
- lib/features/carga/services/sincronizacion_service.dart

Codigo clave:
- `_normalizeStatusLabel(...)`
- `_pickObservaciones(...)`
- `_buildNuevoPredioData(...)`
- `_buildGestionUpdateData(...)`

Tiempo estimado: 25 min
Riesgo: Bajo

### Fase 2: Canonizar aliases de observaciones en mapper
Descripcion:
- Se agrego clave canonica `situacion_social` con aliases de observaciones.
- Se retiro alias generico `situacion` de `estatus` para evitar cruces.

Archivos afectados:
- lib/features/carga/utils/geojson_mapper.dart

Codigo clave:
- `_keyAliases['situacion_social']`
- `_keyAliases['estatus']`

Tiempo estimado: 15 min
Riesgo: Bajo

### Fase 3: Ajustar importacion local y fallback de estatus
Descripcion:
- En importacion local, `situacionSocial` ahora se extrae de observaciones.
- `estatusGestion` en modelo prioriza banderas (`cop/identificacion/levantamiento/negociacion`) y deja `situacion_social` como fallback historico.

Archivos afectados:
- lib/features/predios/providers/local_predios_provider.dart
- lib/features/predios/models/predio.dart

Codigo clave:
- `_extractObservaciones(...)`
- `Predio.estatusGestion`

Tiempo estimado: 20 min
Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Separar estatus vs observaciones en sync | 25 min | Bajo |
| Alias canonicos de observaciones | 15 min | Bajo |
| Importacion local + fallback de estatus | 20 min | Bajo |
| Total | 60 min | Bajo |

## 5. Criterio de exito
- La columna Observaciones en Gestion muestra texto de observaciones del GeoJSON.
- El estatus (Liberado/No liberado/Sin estatus) se mantiene por banderas y no contamina Observaciones.
- Importacion local y sincronizacion remota quedan alineadas en este comportamiento.

## 6. Resultado / evidencia
- Validacion estatica sin errores en los archivos modificados.
- Flujo de inyeccion separado: estatus por banderas, observaciones por campo dedicado.

## 7. Proximo paso
1. Reimportar un archivo GeoJSON de prueba con campo `observaciones` (o `situacion`) para validar render en Gestion.
2. Verificar que la columna Estatus conserve valores correctos cuando haya o no observaciones.
