# IMPL_17 Plan Regresion Importacion GeoJSON

Estado: Propuesto
Fecha: 2026-05-14
Rama: desktop/fase-1

## Objetivo
Definir un plan de implementacion para corregir la regresion donde la importacion GeoJSON queda atorada en "Sincronizando 0% / Guardando" y no completa de forma confiable.

## Diagnostico / contexto actual
Hallazgo principal de regresion (comparacion de historial):
- Version previa funcional: commit `55a2c58`
- Cambio grande introducido en: commit `2a6bb91`
- Magnitud: refactor masiva en motor de sincronizacion y pantalla de carga

Diferencias relevantes que explican el fallo percibido:
1. El flujo paso de secuencial simple (crear/actualizar por feature) a un motor en 2 fases (lookup concurrente + batch create).
2. En fase lookup, los features nuevos se agregan a `pendingCreates` y NO reportan progreso inmediatamente.
3. Para archivos donde la mayoria son "nuevos", la barra puede quedarse en 0% durante mucho tiempo aunque el proceso siga ejecutandose.
4. La fase lookup hace llamadas por feature (`buscarPorClaveCatastral`) y puede generar N+1 round-trips con latencia acumulada.
5. Si backend/Supabase responde lento, retries + timeouts por operacion incrementan la duracion total y parecen cuelgue.

## Hipotesis de causa raiz
La importacion no falla al parsear ni al seleccionar archivo; la regresion se concentra en sincronizacion remota por:
- diseno de progreso que no refleja avance real en fase lookup de nuevos,
- costo de red por feature en lookup,
- fallback que llega tarde para percepcion de UX en archivos medianos/grandes.

## Fases de implementacion

### Fase 1: Hotfix de progreso real en fase lookup
Descripcion:
- Reportar progreso por feature procesado aunque sea "pending create".
- Mostrar etapa separada: "Validando en BD" y despues "Creando registros".

Archivos afectados:
- lib/features/carga/services/sincronizacion_service.dart
- lib/features/carga/presentation/carga_archivo_screen.dart

Codigo clave:
- `_processLaneLookup(...)`
- callback `onProgress(...)`
- etiquetas `etapa` en `importacionAsyncProvider`

Tiempo estimado: 1 h
Riesgo: Bajo

### Fase 2: Fast-path para archivo grande (local-first)
Descripcion:
- Para archivos >= umbral (ej. 100 features), ejecutar importacion local primero (persistir, mostrar en Gestion, desbloquear UI).
- Sincronizacion remota posterior en segundo plano (opt-in o boton "Sincronizar ahora").

Archivos afectados:
- lib/features/carga/presentation/carga_archivo_screen.dart
- lib/features/carga/providers/carga_provider.dart
- lib/features/carga/services/sincronizacion_service.dart

Codigo clave:
- decision por umbral `features.length`
- reutilizar `_importarGeoJsonEnModoLocal(...)`
- estado de sincronizacion diferida por archivo

Tiempo estimado: 3 h
Riesgo: Medio

### Fase 3: Reducir N+1 con lookup por lote
Descripcion:
- Agregar endpoint backend para consultar claves catastrales en lote.
- Reemplazar `buscarPorClaveCatastral` por feature con 1-2 llamadas batch.

Archivos afectados:
- backend/app/main.py
- lib/features/predios/data/predios_repository.dart
- lib/features/carga/services/sincronizacion_service.dart

Codigo clave:
- `POST /predios/by-claves` (nuevo)
- mapa local `clave -> predio`

Tiempo estimado: 6 h
Riesgo: Medio

### Fase 4: Guardrail de version estable
Descripcion:
- Introducir feature flag para modo sincronizacion "legacy" (similar a 55a2c58) como fallback operativo inmediato.
- Permite continuidad mientras se estabiliza modo robusto.

Archivos afectados:
- lib/core/config/cloud_data_config.dart
- lib/features/carga/services/sincronizacion_service.dart

Codigo clave:
- `useLegacyGeoJsonSync`
- ruta condicional secuencial vs robusta

Tiempo estimado: 2 h
Riesgo: Bajo

### Fase 5: Validacion y pruebas de no regresion
Descripcion:
- Pruebas con 3 tamanos de archivo (pequeno, mediano, grande) y backend lento/sin respuesta.
- Verificar: progreso visible, no bloqueo indefinido, persistencia en lista, conteo correcto en Gestion.

Archivos afectados:
- test/ (nuevos tests de servicio/proveedor)
- checklist manual en docs

Tiempo estimado: 2 h
Riesgo: Bajo

## Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 1 h | Bajo |
| Fase 2 | 3 h | Medio |
| Fase 3 | 6 h | Medio |
| Fase 4 | 2 h | Bajo |
| Fase 5 | 2 h | Bajo |
| Total | 14 h | Medio |

## Criterio de exito
- No existe estado indefinido en "Sincronizando 0% / Guardando".
- El usuario siempre obtiene resultado (importado local, remoto o fallback controlado).
- Para TSNL_16_17.geojson la operacion completa y se visualiza en Gestion.

## Resultado / evidencia esperada
- Progreso continuo por etapa con logs y estado UI coherente.
- Tiempo maximo acotado por timeout/fallback sin cuelgue permanente.
- Importaciones registradas en lista sin duplicados.

## Proximo paso
- Implementar Fase 1 + Fase 2 en un solo PR de estabilizacion rapida.
- Dejar Fase 3 (lookup batch backend) como PR separado de optimizacion estructural.
