# IMPL_18 Fix Regresion Import Local-First y Progreso Lookup

Estado: Implementado
Fecha: 2026-05-14
Rama: desktop/fase-1

## Objetivo
Aplicar estabilizacion rapida ante regresion de importacion GeoJSON atascada en "Sincronizando 0%" mediante:
- progreso visible durante fase lookup,
- modo local-first para archivos grandes.

## Diagnostico / contexto actual
- En flujo robusto de sincronizacion (lookup + batch), los features nuevos quedaban en `pendingCreates` sin reflejar avance en UI durante gran parte del proceso.
- Para archivos grandes, la latencia acumulada en lookup remoto generaba percepcion de cuelgue.
- El usuario necesitaba resultado inmediato utilizable en Gestion sin depender de estabilidad remota.

## Fases con alcance tecnico

### Fase 1: Progreso real en fase lookup
Descripcion:
- Se modifica lookup para devolver outcome tambien cuando el feature queda pendiente de creacion.
- Esto incrementa progreso por feature procesado durante validacion y elimina periodos largos en 0%.

Archivos afectados:
- lib/features/carga/services/sincronizacion_service.dart

Codigo clave:
- `_processFeatureLookup(...)` ahora devuelve `_FeatureSyncOutcome` siempre
- estado temporal `'_syncStatus': 'pending_create'`
- `_processLaneLookup(...)` reporta outcome en todos los casos

Tiempo estimado: 45 min
Riesgo: Bajo

### Fase 2: Local-first para GeoJSON grande
Descripcion:
- Se agrega umbral para priorizar importacion local inmediata en archivos grandes.
- Evita bloqueo en sincronizacion remota y garantiza resultado funcional para usuario.

Archivos afectados:
- lib/features/carga/presentation/carga_archivo_screen.dart

Codigo clave:
- `static const int _geoJsonLocalFirstThreshold = 100`
- rama local-first en `_guardarYVerEnMapa()`
- etapa inicial ajustada a "Validando en BD" para flujo no local-first

Tiempo estimado: 35 min
Riesgo: Bajo

## Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 45 min | Bajo |
| Fase 2 | 35 min | Bajo |
| Total | 80 min | Bajo |

## Criterio de exito
- No persiste estado indefinido en 0% para archivo grande.
- Para GeoJSON >= 100 features, la importacion completa en modo local y registra archivo en Gestion.
- El usuario deja de experimentar "accion que se esfuma" al importar.

## Resultado / evidencia
- Cambios aplicados en:
  - lib/features/carga/services/sincronizacion_service.dart
  - lib/features/carga/presentation/carga_archivo_screen.dart
- Verificacion con analisis estatico en ambos archivos sin errores de compilacion.

## Proximo paso
- Probar TSNL_16_17.geojson y confirmar importacion local completa (navegacion a Gestion + archivo en lista importada).
- Definir en siguiente iteracion sincronizacion remota diferida para archivos grandes (opcional, no bloqueante).
