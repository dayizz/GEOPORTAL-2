# IMPL_31 - Filtros multiselección en Gestión
- Estado: Implementado
- Fecha: 2026-05-14
- Rama: desktop/fase-1

## 1. Objetivo
Permitir selección múltiple por categoría en la función de filtros de Gestión para combinar varios valores de `T/F/S`, `Tipo de propiedad`, `C.O.P.` y `Estatus` en una sola consulta.

## 2. Diagnóstico / contexto actual
- El filtrado estaba diseñado para un solo valor por categoría (`String?`), por lo que al elegir otra opción se reemplazaba la anterior.
- En escenarios de operación se requiere filtrar, por ejemplo, varios tramos a la vez o combinar `Con COP` y `Sin COP` según análisis.

## 3. Fases
### Fase 1 - Migración de estado de filtros a conjuntos
- Descripción: cambiar estado local de filtros de `String?` a `Set<String>` por categoría.
- Archivos afectados:
  - `lib/features/tabla/presentation/tabla_screen.dart`
- Código clave:
  - `_filtroTramos`, `_filtroTipos`, `_filtroCop`, `_filtroEstatus`
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 2 - Actualizar algoritmo de filtrado y memoización
- Descripción: aplicar pertenencia por conjunto (`contains`) y actualizar claves de memoización para detectar cambios en sets.
- Archivos afectados:
  - `lib/features/tabla/presentation/tabla_screen.dart`
- Código clave:
  - `_setMemoKey(...)`
  - `_applyFilters(...)` con comparación por conjuntos
- Tiempo estimado: 25 min
- Riesgo: Bajo

### Fase 3 - Actualizar UI de modal y chips activos
- Descripción: convertir `FilterChip` a comportamiento toggle multiselección y renderizar chips activos por cada valor seleccionado.
- Archivos afectados:
  - `lib/features/tabla/presentation/tabla_screen.dart`
- Código clave:
  - `_showFiltros(...)` con `Set<String>` temporales
  - sección de chips activos en top bar con eliminación individual
- Tiempo estimado: 25 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 20 min | Bajo |
| Fase 2 | 25 min | Bajo |
| Fase 3 | 25 min | Bajo |
| Total | 70 min | Bajo |

## 5. Criterio de éxito
- Se pueden seleccionar múltiples opciones en cada categoría de filtros.
- El resultado en tabla corresponde a la unión de valores seleccionados por categoría.
- Se pueden quitar filtros individualmente desde chips activos.

## 6. Resultado / evidencia
- Implementación aplicada en `tabla_screen.dart`.
- Validación estática ejecutada:
  - `flutter analyze lib/features/tabla/presentation/tabla_screen.dart`
  - Resultado: sin issues.

## 7. Próximo paso
Probar manualmente combinaciones multiselección, por ejemplo:
1. Tramos `T1 + T2 + S1`
2. Tipo `SOCIAL + PRIVADA`
3. Estatus `LIBERADO + NO LIBERADO`
4. Verificar conteo y paginación con filtros activos.
