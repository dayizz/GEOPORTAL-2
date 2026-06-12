# IMPL_47 - Gestion: cambio de km lineales a km efectivos

- Estado: Completado
- Fecha: 2026-06-03
- Rama: desktop/fase-1

## 1. Objetivo
Actualizar las tablas y vistas del modulo de Gestion para mostrar km efectivos en lugar de km lineales.

## 2. Diagnostico / contexto actual
En Gestion se mostraba la columna/etiqueta de km lineales y su valor asociado, lo que no corresponde al criterio actual de visualizacion solicitado.

## 3. Fases
### Fase 1: Ajuste de encabezado y dato en tabla principal de Gestion
- Descripcion: Se reemplazo el encabezado de columna y se cambio la fuente del dato para usar `kmEfectivos`.
- Archivos afectados:
  - `lib/features/tabla/presentation/tabla_screen.dart`
- Codigo clave:
  - Encabezado: `KM LIN` -> `KM EFEC`
  - Comentario interno: `// KM LIN` -> `// KM EFEC`
  - Celda numerica: `p.kmLineales` -> `p.kmEfectivos`
- Tiempo estimado: 15 minutos
- Riesgo: Bajo

### Fase 2: Ajuste en detalle de predio de Gestion
- Descripcion: Se actualizo la tarjeta de metrica para mostrar km efectivos y su etiqueta correspondiente.
- Archivos afectados:
  - `lib/features/tabla/presentation/gestion_predio_detail_screen.dart`
- Codigo clave:
  - Valor: `predio.kmLineales` -> `predio.kmEfectivos`
  - Texto: `Km Lineales` -> `Km Efectivos`
- Tiempo estimado: 10 minutos
- Riesgo: Bajo

### Fase 3: Verificacion de analisis
- Descripcion: Se validaron ambos archivos modificados sin errores de analisis.
- Archivos afectados:
  - `lib/features/tabla/presentation/tabla_screen.dart`
  - `lib/features/tabla/presentation/gestion_predio_detail_screen.dart`
- Tiempo estimado: 5 minutos
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 15 min | Bajo |
| Fase 2 | 10 min | Bajo |
| Fase 3 | 5 min | Bajo |
| Total | 30 min | Bajo |

## 5. Criterio de exito
- La tabla principal de Gestion muestra "KM EFEC" y consume `kmEfectivos`.
- El detalle de predio en Gestion muestra "Km Efectivos" y consume `kmEfectivos`.
- No se introducen errores de analisis en los archivos modificados.

## 6. Resultado / evidencia
- Cambios aplicados en los archivos del modulo de Gestion.
- Validacion tecnica completada con resultado sin errores.

## 7. Proximo paso
Validar visualmente en la pagina de Gestion que:
1. La columna de km en tabla refleje KM EFEC.
2. El detalle de predio muestre Km Efectivos.
3. Los valores correspondan a datos de km efectivos existentes.
