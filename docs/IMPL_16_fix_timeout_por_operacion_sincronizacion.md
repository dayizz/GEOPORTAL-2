# IMPL_16 Fix Timeout por Operacion Sincronizacion

Estado: Implementado
Fecha: 2026-05-14
Rama: desktop/fase-1

## Objetivo
Eliminar bloqueos indefinidos durante la sincronizacion GeoJSON cuando una operacion de red individual queda colgada y no devuelve control al flujo principal.

## Diagnostico / contexto actual
- El parseo local del GeoJSON se completa correctamente.
- El atasco se presenta dentro del motor de sincronizacion durante operaciones remotas.
- Aunque existia timeout a nivel pantalla, una operacion interna sin timeout podia dejar toda la fase en espera excesiva.

## Fases con alcance tecnico

### Fase 1: Timeout por operacion dentro de retry
Descripcion:
- Se agrega timeout fijo por cada operacion remota ejecutada mediante `_withRetry(...)`.
- Al vencer, la operacion lanza `TimeoutException` para activar reintentos/fallback.

Archivos afectados:
- lib/features/carga/services/sincronizacion_service.dart

Codigo clave:
- `static const Duration _operationTimeout = Duration(seconds: 12)`
- `operation().timeout(_operationTimeout, onTimeout: ...)`

Tiempo estimado: 20 min
Riesgo: Bajo

### Fase 2: Integracion con estrategia existente de retry
Descripcion:
- El timeout por operacion se integra con la logica actual de `_isRetryableError(...)` y backoff.
- Evita cuelgues silenciosos en fases lookup/create/update.

Archivos afectados:
- lib/features/carga/services/sincronizacion_service.dart

Codigo clave:
- `_withRetry(...)`
- `_isRetryableError(...)`

Tiempo estimado: 15 min
Riesgo: Bajo

## Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 20 min | Bajo |
| Fase 2 | 15 min | Bajo |
| Total | 35 min | Bajo |

## Criterio de exito
- Ninguna operacion remota de sincronizacion queda colgada indefinidamente.
- El flujo de importacion avanza por progreso o falla controladamente para activar fallback.
- La UI deja de quedarse permanentemente en "Sincronizando/Guardando".

## Resultado / evidencia
- Cambios aplicados en:
  - lib/features/carga/services/sincronizacion_service.dart
- Validacion con analisis estatico sobre archivos de sincronizacion/carga sin errores de compilacion.

## Proximo paso
- Ejecutar importacion de TSNL_16_17.geojson y validar que, ante latencia remota, se observe avance o fallback local sin bloqueo indefinido.
