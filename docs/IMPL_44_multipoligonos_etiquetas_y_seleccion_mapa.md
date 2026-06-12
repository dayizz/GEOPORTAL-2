# IMPL_44: Multipolígonos con etiquetas y selección en mapa

- Estado: Implementado
- Fecha: 27 de mayo de 2026
- Rama: desktop/fase-1

## 1. Objetivo
Corregir el mapa para que los predios con geometría multipolígono muestren todas sus partes, puedan seleccionarse en cualquiera de ellas y rendericen etiqueta de clave en cada parte separada.

## 2. Diagnóstico / contexto actual
- Algunos predios aparecían con tono más claro o incompleto porque solo se estaba usando la primera parte de la geometría del predio.
- Las etiquetas de clave se calculaban con un solo punto por predio, por lo que algunas partes separadas quedaban sin etiqueta.
- La selección por clic revisaba un solo conjunto de anillos, dejando partes del multipolígono sin interacción.

## 3. Fases
### Fase 1: Render completo de multipolígonos
- Descripción:
  - Se ajustó la construcción visual del mapa para pintar todas las partes del predio, no solo la principal.
- Archivos afectados:
  - lib/features/mapa/presentation/mapa_screen.dart
- Código clave:
  - `_buildVisualData(...)`
  - `PolygonLayer(polygons: visuals.expand((v) => v.polygons).toList())`
- Tiempo estimado: 20 min
- Riesgo: Medio

### Fase 2: Selección sobre cualquier parte del predio
- Descripción:
  - Se actualizó el hit-test para recorrer cada parte del multipolígono y devolver el predio correcto cuando el usuario toca cualquiera de ellas.
- Archivos afectados:
  - lib/features/mapa/presentation/mapa_screen.dart
- Código clave:
  - `_findVisualAtPoint(...)`
- Tiempo estimado: 15 min
- Riesgo: Medio

### Fase 3: Etiqueta por cada parte separada
- Descripción:
  - Se añadieron puntos de etiqueta por cada polígono del predio para repetir la clave en cada parte aislada del multipolígono.
  - Estos puntos se cachean para no degradar el encendido/apagado de etiquetas.
- Archivos afectados:
  - lib/features/mapa/presentation/mapa_screen.dart
- Código clave:
  - `_labelPointsFromPolygons(...)`
  - `_buildPredioClaveMarkers(...)`
  - `_PredioGeometryCacheEntry`
- Tiempo estimado: 20 min
- Riesgo: Medio

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Render de multipolígonos | 20 min | Medio |
| Selección por parte | 15 min | Medio |
| Etiquetas por parte | 20 min | Medio |
| Total | 55 min | Medio |

## 5. Criterio de éxito
- Todas las partes de un predio multipolígono se renderizan en el mapa.
- El usuario puede seleccionar cualquiera de las partes del predio.
- Cada parte separada del multipolígono muestra la clave del predio cuando las etiquetas están activas.

## 6. Resultado / evidencia
- Validación estática sin errores en `mapa_screen.dart`.
- Se amplió el cache geométrico para incluir multipolígonos completos y puntos de etiqueta por parte.
- La instancia web requiere reinicio para aceptar cambios de estructura de clases `const`.

## 7. Próximo paso
1. Validar visualmente con sesión iniciada un caso real de multipolígono con partes separadas.
2. Si hay saturación visual, limitar etiquetas por parte según el nivel de zoom.
