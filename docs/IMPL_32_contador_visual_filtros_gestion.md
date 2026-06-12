# IMPL_32 - Contador visual de filtros en Gestión
- Estado: Implementado
- Fecha: 2026-05-14
- Rama: desktop/fase-1

## 1. Objetivo
Agregar contadores visuales en la función de filtros de Gestión para mostrar cuántos filtros están activos en total y por categoría.

## 2. Diagnóstico / contexto actual
- La multiselección ya estaba implementada, pero no mostraba claramente la cantidad de opciones activas por bloque.
- Se requería feedback inmediato para mejorar UX y evitar confusión al combinar criterios.

## 3. Fases
### Fase 1 - Contador total en botón de filtros
- Descripción: mostrar total de filtros activos en el botón `Filtros` de la barra superior.
- Archivos afectados:
  - `lib/features/tabla/presentation/tabla_screen.dart`
- Código clave:
  - `_totalActiveFilters()`
  - Label `Filtros (N)`
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2 - Contadores por categoría en modal
- Descripción: mostrar cantidad activa por sección en la modal (`T/F/S`, `Tipo de Propiedad`, `C.O.P.`, `Estatus`) y en título general.
- Archivos afectados:
  - `lib/features/tabla/presentation/tabla_screen.dart`
- Código clave:
  - `Filtros (N)` en encabezado de modal
  - `T/F/S (n)`, `Tipo de Propiedad (n)`, `C.O.P. (n)`, `Estatus (n)`
- Tiempo estimado: 20 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 20 min | Bajo |
| Total | 30 min | Bajo |

## 5. Criterio de éxito
- El botón principal de filtros refleja el total de filtros activos.
- La modal refleja el conteo activo por categoría en tiempo real.
- No se introducen errores de compilación.

## 6. Resultado / evidencia
- Cambios aplicados en `tabla_screen.dart`.
- Validación estática:
  - `flutter analyze lib/features/tabla/presentation/tabla_screen.dart`
  - Resultado: sin issues.

## 7. Próximo paso
Validar en UI que los contadores suben y bajan correctamente al seleccionar/deseleccionar chips y al usar `Limpiar todo`.
