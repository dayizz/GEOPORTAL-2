# IMPL_55 - Fix overflow en dropdowns de reporte

Estado: Completado  
Fecha: 2026-06-04  
Rama: desktop/fase-1

## 1. Objetivo
Corregir el overflow visual que aparecía en el formulario de generación de reporte dentro de la sección Balance, especialmente en los dropdowns con textos largos.

## 2. Diagnostico / contexto actual
La pantalla de reporte mostraba un `RenderFlex overflowed` en los `DropdownButtonFormField` de Proyecto, Destinatario, Remitente y Tramo. El problema se disparaba cuando el texto seleccionado o los items de la lista eran demasiado largos para el ancho disponible en escritorio.

## 3. Fases

### Fase 1 - Identificacion del origen del overflow
- Descripcion: Revisar el formulario y ubicar los dropdowns que contienen textos largos dentro de un layout fijo.
- Archivos afectados: `lib/features/reportes/presentation/reporte_form_screen.dart`
- Codigo clave: `DropdownButtonFormField<String>` en Proyecto, Destinatario, Remitente y Tramo.
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2 - Compactacion visual de dropdowns
- Descripcion: Hacer que los dropdowns se expandan correctamente y truncar los textos largos para evitar desbordamiento.
- Archivos afectados: `lib/features/reportes/presentation/reporte_form_screen.dart`
- Codigo clave: `isExpanded: true`, `TextOverflow.ellipsis`, `selectedItemBuilder` con etiquetas resumidas.
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 3 - Validacion tecnica
- Descripcion: Formatear y revisar errores de analisis tras el ajuste.
- Archivos afectados: `lib/features/reportes/presentation/reporte_form_screen.dart`
- Codigo clave: `dart format` y `get_errors`.
- Tiempo estimado: 5 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 20 min | Bajo |
| Fase 3 | 5 min | Bajo |
| **Total** | **35 min** | **Bajo** |

## 5. Criterio de exito
- No aparece overflow horizontal en los dropdowns del formulario.
- Los valores largos se muestran de forma compacta dentro del campo.
- La informacion detallada sigue visible en las secciones de resumen debajo del dropdown.

## 6. Resultado / evidencia
- Se habilito `isExpanded` en los dropdowns.
- Se resumieron los labels seleccionados de Destinatario y Remitente a valores cortos.
- Se mantuvo el detalle completo en los bloques de resumen inferiores.

## 7. Proximo paso
Validar manualmente en la pantalla de reporte:
1. Abrir el formulario en escritorio.
2. Confirmar que no se marque overflow en Proyecto, Destinatario, Remitente ni Tramo.
3. Verificar que la generacion del PDF siga funcionando normalmente.
