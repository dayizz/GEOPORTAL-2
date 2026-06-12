# IMPL_43: Etiquetas de clave de predio con toggle en mapa

- Estado: Implementado
- Fecha: 27 de mayo de 2026
- Rama: desktop/fase-1

## 1. Objetivo
Agregar en el mapa una etiqueta con la clave de cada predio y un control para encender/apagar esta visualización.

## 2. Diagnóstico / contexto actual
- El mapa mostraba polígonos y pin de selección, pero no existía una capa textual para identificar cada predio por su clave.
- No había control de usuario para activar/desactivar etiquetas de identificación.

## 3. Fases
### Fase 1: Estado UI para alternar etiquetas
- Descripción:
  - Se agregó un flag de estado para controlar visibilidad de etiquetas de clave.
- Archivos afectados:
  - lib/features/mapa/presentation/mapa_screen.dart
- Código clave:
  - `_showPredioClaveLabels`
- Tiempo estimado: 5 min
- Riesgo: Bajo

### Fase 2: Capa de marcadores de etiqueta
- Descripción:
  - Se creó builder de marcadores para renderizar la clave catastral en un chip sobre cada predio.
  - Se usa `IgnorePointer` para no bloquear interacción del mapa.
- Archivos afectados:
  - lib/features/mapa/presentation/mapa_screen.dart
- Código clave:
  - `_buildPredioClaveMarkers(...)`
  - `MarkerLayer(markers: _buildPredioClaveMarkers(visuals))`
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 3: Botón/selector de encendido-apagado
- Descripción:
  - Se añadió opción en panel de capas para alternar visibilidad de etiquetas.
- Archivos afectados:
  - lib/features/mapa/presentation/mapa_screen.dart
- Código clave:
  - sección `Etiquetas` en `_buildLayersPanel(...)`
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Estado de toggle | 5 min | Bajo |
| Capa de etiquetas | 20 min | Bajo |
| Control en panel de capas | 10 min | Bajo |
| Total | 35 min | Bajo |

## 5. Criterio de éxito
- El usuario puede activar y desactivar etiquetas de clave desde el panel de capas.
- Cuando está activa, cada predio muestra su clave en el mapa.
- La interacción del mapa no se bloquea por los labels.

## 6. Resultado / evidencia
- Validación estática sin errores en `mapa_screen.dart`.
- Capa de etiquetas y toggle integrados en la UI del mapa.

## 7. Próximo paso
1. Ajustar tamaño/visibilidad de etiquetas por nivel de zoom si se requiere reducir saturación visual en vistas amplias.
2. Evaluar opción de mostrar etiquetas solo en predios filtrados o seleccionados.
