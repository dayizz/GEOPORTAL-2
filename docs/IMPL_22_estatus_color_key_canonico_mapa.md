# IMPL_22: Campo canónico _estatusColorKey para render de mapa

**Estado**: Implementado
**Fecha**: 13 de mayo de 2026
**Rama**: desktop/fase-1

## Objetivo
Eliminar cualquier ambigüedad en el render de color por estatus para features GeoJSON importados.

## Diagnóstico / contexto actual
Aunque el parser y la sincronización ya preservaban el estatus del GeoJSON, el color seguía dependiendo de múltiples rutas de lectura e inferencia. Para cerrar esa brecha, se creó una fuente única de verdad para el render.

## Fases
### Fase 1: Inyectar clave canónica de color en parser
- Archivo afectado: lib/features/carga/services/geojson_background_parser.dart
- Cambio: guardar `_estatusColorKey` junto con `estatus` y `estatus_predio`.

### Fase 2: Preservar clave canónica en sincronización
- Archivo afectado: lib/features/carga/services/sincronizacion_service.dart
- Cambio: mantener `_estatusColorKey` al enriquecer properties.

### Fase 3: Prioridad absoluta en render de mapa
- Archivo afectado: lib/features/mapa/presentation/mapa_screen.dart
- Cambio: `_importedFeatureColor(...)` pinta primero desde `_estatusColorKey`, luego desde `estatus/ESTATUS`, y solo después recurre a inferencias.

## Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|------|------------------|--------|
| Clave canónica en parser | 10 min | Bajo |
| Preservación en sincronización | 10 min | Bajo |
| Prioridad en render | 10 min | Bajo |

## Criterio de éxito
- Features con `ESTATUS = LIBERADO` se pintan en verde.
- Features con `ESTATUS = NO LIBERADO` se pintan en rojo.
- Solo quedan grises los features sin estatus detectable.

## Resultado / evidencia
- Sin errores de análisis en parser, sincronización y mapa.
- Render basado en una fuente técnica única de estatus.

## Próximo paso
Reimportar el GeoJSON y validar específicamente el feature `SNL-SLV-052-5-GS` con `ESTATUS = NO LIBERADO`.
