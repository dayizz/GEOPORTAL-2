# IMPL_59 - Avance por tipo de propiedad: General y por segmento

Estado: Completado  
Fecha: 2026-06-04  
Rama: desktop/fase-1

## 1. Objetivo
Agregar en Balance una opcion para ver el bloque "Avance por tipo de propiedad" en dos modos:
- General (todo el proyecto)
- Por segmento

## 2. Diagnostico / contexto actual
La seccion "Avance por tipo de propiedad" calculaba siempre sobre todos los predios del proyecto activo, sin posibilidad de filtrar por segmento.

## 3. Fases

### Fase 1 - Estado de vista
- Descripcion: Incorporar estado UI para alternar entre modo general y modo por segmento.
- Archivos afectados: `lib/features/reportes/presentation/reportes_screen.dart`
- Codigo clave: `_avanceTipoPorSegmento`, `_segmentoTipoActual`.
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2 - Base de calculo dinamica
- Descripcion: Ajustar la fuente de predios para el bloque de tipo de propiedad segun modo seleccionado.
- Archivos afectados: `lib/features/reportes/presentation/reportes_screen.dart`
- Codigo clave: `baseTipoPredios` con lectura por proyecto o por segmento.
- Tiempo estimado: 15 min
- Riesgo: Bajo

### Fase 3 - Controles UI de seleccion
- Descripcion: Agregar controles para alternar General/Por segmento y seleccionar segmento cuando aplique.
- Archivos afectados: `lib/features/reportes/presentation/reportes_screen.dart`
- Codigo clave: `_buildTipoViewControls`, `_buildSegmentoTipoDropdown`.
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 4 - Validacion tecnica
- Descripcion: Ejecutar formato y revisar errores de analisis.
- Archivos afectados: `lib/features/reportes/presentation/reportes_screen.dart`
- Codigo clave: `dart format` y `get_errors`.
- Tiempo estimado: 5 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 15 min | Bajo |
| Fase 3 | 20 min | Bajo |
| Fase 4 | 5 min | Bajo |
| **Total** | **50 min** | **Bajo** |

## 5. Criterio de exito
- El usuario puede cambiar entre vista General y Por segmento.
- En vista General, el avance por tipo usa todos los predios del proyecto.
- En vista Por segmento, el avance por tipo usa solo el segmento seleccionado.

## 6. Resultado / evidencia
- Se agregaron chips de seleccion para los dos modos.
- Se agregó selector de segmento cuando se activa la vista por segmento.
- Las tarjetas de propiedad privada y social/dominio usan la base filtrada acorde al modo.

## 7. Proximo paso
Validar manualmente en `#/reportes`:
1. Cambiar entre General y Por segmento.
2. Elegir distintos segmentos.
3. Confirmar que cambian los totales y graficas del bloque "Avance por tipo de propiedad".
