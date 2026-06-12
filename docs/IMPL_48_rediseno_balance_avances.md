# IMPL_48 - Rediseno de Balance por avance general, tipo y segmentos

- Estado: Completado
- Fecha: 2026-06-03
- Rama: desktop/fase-1

## 1. Objetivo
Redisenar la pantalla Balance para mostrar tres bloques:
1) Avance general.
2) Avance por tipo de propiedad.
3) Avance por segmentos.

## 2. Diagnostico / contexto actual
La pantalla Balance anterior estaba orientada a KPIs compactos y graficas generales por tipo/tramo, pero no seguia la estructura operativa solicitada para lectura ejecutiva de liberacion, km efectivos y avance por tipo consolidado.

## 3. Fases
### Fase 1: Avance general
- Descripcion: Se implemento una seccion con tres componentes:
  - Cuadro de cuantificacion de total de predios del proyecto.
  - Barra de avance para predios liberados y no liberados.
  - Grafica de dona para km efectivos liberados vs no liberados.
- Archivos afectados:
  - `lib/features/reportes/presentation/reportes_screen.dart`
- Codigo clave:
  - Construccion de listas `liberados` y `noLiberados`.
  - Suma de `kmLiberados` y `kmNoLiberados`.
  - Widgets `_buildQuantCard`, `_buildPrediosAvanceBar`, `_buildDonutCard`.
- Tiempo estimado: 45 minutos
- Riesgo: Medio

### Fase 2: Avance por tipo de propiedad
- Descripcion: Se agrego una seccion con dos paneles:
  - Izquierda: Privada.
  - Derecha: Social + Dominio Pleno (consolidado).
  Cada panel incluye:
  - Total de propiedades (cuantificacion).
  - Dona de identificacion.
  - Dona de levantamiento.
  - Dona de negociacion.
  - Dona de liberados.
- Archivos afectados:
  - `lib/features/reportes/presentation/reportes_screen.dart`
- Codigo clave:
  - Clasificacion por tipo con `_isPrivada` y `_isSocialODominio`.
  - Panel reusable `_buildTipoPanel`.
- Tiempo estimado: 55 minutos
- Riesgo: Medio

### Fase 3: Avance por segmentos
- Descripcion: Se agrego grafica de barras agrupadas por segmento con tres series:
  - Liberados.
  - No liberados.
  - Negociacion.
- Archivos afectados:
  - `lib/features/reportes/presentation/reportes_screen.dart`
- Codigo clave:
  - Agrupacion por tramo en `porSegmento`.
  - Grafica en `_buildSegmentosBarChart` usando `BarChart` de `fl_chart`.
- Tiempo estimado: 35 minutos
- Riesgo: Medio

### Fase 4: Validacion tecnica
- Descripcion: Se ejecuto formato Dart y validacion de errores del archivo modificado.
- Archivos afectados:
  - `lib/features/reportes/presentation/reportes_screen.dart`
- Tiempo estimado: 5 minutos
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 45 min | Medio |
| Fase 2 | 55 min | Medio |
| Fase 3 | 35 min | Medio |
| Fase 4 | 5 min | Bajo |
| Total | 140 min | Medio |

## 5. Criterio de exito
- Existe seccion Avance general con los 3 componentes solicitados.
- Existe seccion Avance por tipo de propiedad con panel privado y panel social+dominio pleno, cada uno con 5 metricas visuales.
- Existe seccion Avance por segmentos con barras de liberados, no liberados y negociacion.
- El archivo compila y no presenta errores de analisis.

## 6. Resultado / evidencia
- Rediseno aplicado en pantalla Balance de reportes.
- Validacion completada: sin errores de analisis en el archivo modificado.

## 7. Proximo paso
1. Validar visualmente en escritorio y web con proyectos TQI, TSNL, TAP y TQM.
2. Ajustar colores/etiquetas en caso de requerir convencion corporativa final.
3. Confirmar con negocio la regla de liberacion usada para el calculo (COP, PDF o estatus).
