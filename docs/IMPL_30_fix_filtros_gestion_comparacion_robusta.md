# IMPL_30 - Fix filtros de Gestión con comparación robusta
- Estado: Implementado
- Fecha: 2026-05-14
- Rama: desktop/fase-1

## 1. Objetivo
Corregir la función de filtros en Gestión para que sí aplique la selección del usuario cuando los valores de datos vienen con variaciones de formato (mayúsculas/minúsculas, espacios, guiones bajos o textos equivalentes).

## 2. Diagnóstico / contexto actual
- Los filtros en `tabla_screen.dart` usaban igualdad exacta (`==`) para `tramo`, `tipo_propiedad` y `estatus`.
- En datos reales puede haber variantes como:
  - `DOMINIO_PLENO` vs `DOMINIO PLENO`
  - `No liberado` vs `NO_LIBERADO`
  - Espacios adicionales o cambios de mayúsculas
- Resultado: selección visible en UI, pero filtrado sin coincidencia efectiva.

## 3. Fases
### Fase 1 - Normalización de tokens de filtro
- Descripción: agregar funciones de normalización para comparar valores en forma canónica.
- Archivos afectados:
  - `lib/features/tabla/presentation/tabla_screen.dart`
- Código clave:
  - `_normalizeFilterToken(...)`
  - `_normalizeTipoPropiedadFilter(...)`
  - `_normalizeEstatusFilter(...)`
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 2 - Aplicar normalización en `_applyFilters`
- Descripción: reemplazar comparaciones exactas por comparaciones normalizadas para `tramo`, `tipo` y `estatus`.
- Archivos afectados:
  - `lib/features/tabla/presentation/tabla_screen.dart`
- Código clave:
  - `if (_normalizeFilterToken(p.tramo) != _normalizeFilterToken(_filtroTramo))`
  - `if (_normalizeTipoPropiedadFilter(p.tipoPropiedad) != _normalizeTipoPropiedadFilter(_filtroTipo))`
  - `if (_normalizeEstatusFilter(p.estatusGestion) != _normalizeEstatusFilter(_filtroEstatus))`
- Tiempo estimado: 20 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 20 min | Bajo |
| Fase 2 | 20 min | Bajo |
| Total | 40 min | Bajo |

## 5. Criterio de éxito
- La selección de filtros en Gestión impacta el resultado mostrado de forma consistente.
- Variantes de texto en datos no rompen la coincidencia del filtro.
- El archivo modificado compila sin errores.

## 6. Resultado / evidencia
- Cambios aplicados en `tabla_screen.dart` con normalización de comparación.
- Validación estática:
  - `flutter analyze lib/features/tabla/presentation/tabla_screen.dart`
  - Resultado: sin issues.

## 7. Próximo paso
Probar manualmente en Gestión combinaciones de filtros (Tramo + Tipo + Estatus + COP) y verificar que el conteo y la tabla cambian conforme a la selección.
