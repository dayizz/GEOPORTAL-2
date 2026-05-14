# IMPL_21: Preservar estatus del GeoJSON durante la sincronizacion

**Estado**: Implementado
**Fecha**: 13 de mayo de 2026
**Rama**: desktop/fase-1

## Objetivo
Evitar que el campo ESTATUS del GeoJSON se pierda o se sobrescriba al pasar por la sincronizacion con Gestion, manteniendo el color correcto en el mapa.

## Diagnostico / contexto actual
Aunque el parser ya normalizaba el estatus del archivo, durante la sincronizacion el metodo `_injectData(...)` recalculaba `estatus` desde banderas del backend (`cop`, `identificacion`, `levantamiento`, `negociacion`) y luego sobrescribia `properties.estatus`.

Esto provocaba que features con `ESTATUS = NO LIBERADO` terminaran renderizados como `Sin estatus` y por tanto en gris.

## Fases
### Fase 1: Priorizar estatus del GeoJSON en sincronizacion
- Descripcion: tomar primero el estatus normalizado proveniente del feature importado.
- Archivos afectados: lib/features/carga/services/sincronizacion_service.dart
- Codigo clave:
  - `_injectData(...)`
  - `estatusGeoJson = _normalizeStatusLabel(props)`
  - `estatus = estatusGeoJson ?? estatusBackend`
- Tiempo estimado: 15 min
- Riesgo: Bajo

## Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|------|------------------|--------|
| Preservar estatus en sincronizacion | 15 min | Bajo |

## Criterio de exito
- Si el GeoJSON trae `ESTATUS = LIBERADO`, el feature sincronizado conserva `Liberado`.
- Si el GeoJSON trae `ESTATUS = NO LIBERADO`, el feature sincronizado conserva `No liberado`.
- El color final del poligono refleja el valor del archivo importado.

## Resultado / evidencia
- Sin errores de analisis en `sincronizacion_service.dart`.
- El estatus del GeoJSON ya no se sobrescribe por calculo interno si viene explicitamente en el archivo.

## Proximo paso
Reimportar el GeoJSON y validar el feature de prueba con `ESTATUS = NO LIBERADO` para confirmar que el poligono ahora se renderiza en rojo.
