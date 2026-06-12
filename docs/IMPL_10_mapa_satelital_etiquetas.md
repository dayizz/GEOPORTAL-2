# IMPL_10 - Etiquetas en Mapa Satelital

- Estado: Implementado
- Fecha: 2026-05-12
- Rama: desktop/fase-1

## 1. Objetivo
Mostrar etiquetas de ubicacion (calles, municipios y referencias) cuando el usuario selecciona la capa satelital en la vista de mapa.

## 2. Diagnostico / contexto actual
La capa satelital utilizaba solo imagen aerea (`World_Imagery`), por lo que no mostraba texto ni referencias geograficas.

## 3. Fases
### Fase 1 - Superposicion de etiquetas
- Descripcion: Se agrego una segunda capa de tiles transparente de etiquetas sobre la base satelital.
- Archivos afectados:
  - `lib/features/mapa/presentation/mapa_screen.dart`
  - `lib/app.dart`
  - `lib/main.dart`
- Codigo clave:
  - Render condicional de `TileLayer` para etiquetas solo en modo satelital.
  - Nuevos helpers `_labelsPlacesTileTemplate()` y `_labelsRoadsTileTemplate()` con proveedores de labels ArcGIS.
- Tiempo estimado: 20 minutos
- Riesgo: Bajo (cambio visual acotado a la capa satelital)

## 4. Resumen de esfuerzo
| Fase | Esfuerzo |
|---|---|
| Superposicion de etiquetas | Bajo |
| Validacion de analisis estatico | Bajo |

## 5. Criterio de exito
- Al seleccionar "Satelital", el mapa muestra imagen aerea con etiquetas legibles.
- Al seleccionar "Estandar", el comportamiento se mantiene sin cambios.
- Sin errores de compilacion o analisis estatico en el archivo modificado.

## 6. Resultado / evidencia
- Se agregaron capas de labels:
  - `https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}`
  - `https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}`
- Se actualizo titulo de app escritorio a `Geoportal de Gestion` en MaterialApp y ventana macOS.
- Validacion: sin errores en analisis del archivo `mapa_screen.dart`.

## 7. Proximo paso
Verificar visualmente en distintos niveles de zoom (urbano y rural) para confirmar legibilidad de etiquetas y evaluar, si se requiere, un estilo de labels alterno (oscuro/claro).
