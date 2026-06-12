# IMPL_63 Control De Giro De Mapa Por Grados

- Estado: Implementado
- Fecha: 2026-06-12
- Rama: desktop/fase-1

## 1. Objetivo
Agregar un control nuevo en el mapa con icono de giro y barra pequeña de captura para escribir grados y visualizar el mapa con la rotacion deseada.

## 2. Diagnostico / Contexto Actual
La pantalla de mapa no tenia entrada directa para fijar rotacion en grados. El usuario no podia indicar un valor numerico de giro para la visualizacion.

## 3. Fases

### Fase 1 - Estado Y Controladores De Rotacion
- Descripcion: Se agregaron controlador de texto, focus node y estado de rotacion actual en la pantalla.
- Archivos afectados: `lib/features/mapa/presentation/mapa_screen.dart`
- Codigo clave: `_rotationDegreesCtrl`, `_rotationDegreesFocus`, `_currentRotation`
- Tiempo estimado: 15 min
- Riesgo: Bajo

### Fase 2 - Funcion Nueva De UI Para Captura De Grados
- Descripcion: Se implemento la funcion nueva `_buildMapRotationInput()` con icono de giro y campo compacto para grados.
- Archivos afectados: `lib/features/mapa/presentation/mapa_screen.dart`
- Codigo clave: `Widget _buildMapRotationInput()`
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 3 - Aplicacion De Rotacion Al Mapa
- Descripcion: Se conecto el valor capturado a `MapController.rotate(...)`, con normalizacion de grados y sincronizacion desde el estado del mapa.
- Archivos afectados: `lib/features/mapa/presentation/mapa_screen.dart`
- Codigo clave: `_applyRotationFromInput()`, `_normalizeRotationDegrees(...)`, `onPositionChanged`
- Tiempo estimado: 20 min
- Riesgo: Bajo

## 4. Resumen De Esfuerzo

| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Estado y controladores | 15 min | Bajo |
| Funcion nueva UI | 20 min | Bajo |
| Integracion de rotacion | 20 min | Bajo |
| **Total** | **55 min** | **Bajo** |

## 5. Criterio De Exito
- El mapa muestra un control compacto con icono de giro y barra de entrada.
- El usuario puede escribir grados y aplicar la rotacion.
- El valor se normaliza y se mantiene consistente con la orientacion actual del mapa.

## 6. Resultado / Evidencia
- Se agrego un `Positioned` nuevo en la zona inferior derecha para el control de giro.
- Se incluyo aplicacion directa de grados via `MapController.rotate`.
- Se incorporo sincronizacion de entrada cuando cambia la rotacion por interaccion del mapa.

## 7. Proximo Paso
Validar manualmente casos de entrada: `45`, `-30`, `370` y verificar que el mapa rota en el angulo normalizado esperado.