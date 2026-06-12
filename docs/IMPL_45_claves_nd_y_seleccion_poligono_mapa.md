# IMPL_45: Claves N/D y selección de polígonos en mapa

- Estado: Implementado
- Fecha: 27 de mayo de 2026
- Rama: desktop/fase-1

## 1. Objetivo
Mostrar etiquetas de clave de predio aunque el valor sea N/D (o vacío) y mantener seleccionable el polígono asociado en mapa.

## 2. Diagnóstico / contexto actual
- La capa de etiquetas omitía predios cuando la clave llegaba vacía.
- En campo, predios sin clave formal deben seguir siendo visibles e identificables como N/D.
- La selección de polígono no debe depender del valor de la clave.

## 3. Fases
### Fase 1: Fallback de clave para etiquetas
- Descripción:
  - Se reemplazó la omisión por fallback explícito `N/D` cuando la clave está vacía.
- Archivos afectados:
  - lib/features/mapa/presentation/mapa_screen.dart
- Código clave:
  - `_buildPredioClaveMarkers(...)`
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2: Consistencia visual al seleccionar predio
- Descripción:
  - En la tarjeta de predio seleccionado, se muestra `N/D` cuando la clave está vacía para evitar confusión de selección.
- Archivos afectados:
  - lib/features/mapa/presentation/mapa_screen.dart
- Código clave:
  - `_buildPredioCard(...)`
- Tiempo estimado: 5 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fallback de etiquetas | 10 min | Bajo |
| Consistencia en tarjeta | 5 min | Bajo |
| Total | 15 min | Bajo |

## 5. Criterio de éxito
- Las etiquetas aparecen también en predios con clave vacía usando texto `N/D`.
- Seleccionar un polígono muestra la tarjeta con clave `N/D` cuando aplique.
- No se introducen errores de compilación en la pantalla de mapa.

## 6. Resultado / evidencia
- Validación estática sin errores en `mapa_screen.dart`.
- Hot reload ejecutado en servidor local web activo.

## 7. Próximo paso
1. Validar en sesión real un conjunto de predios con clave vacía para confirmar experiencia de usuario.
2. Si se desea, diferenciar visualmente `N/D` (por ejemplo, estilo itálico o tono distinto) para auditoría rápida.
