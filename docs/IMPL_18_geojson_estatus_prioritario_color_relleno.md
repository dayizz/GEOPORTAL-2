# IMPL_18: Estatus prioritario desde GeoJSON para color de relleno

**Estado**: Implementado
**Fecha**: 13 de mayo de 2026
**Rama**: desktop/fase-1

## Objetivo
Garantizar que, al cargar un GeoJSON con propiedad estatus, el polígono se rellene con color por estatus:
- liberado: verde
- no liberado: rojo
- sin estatus detectado: gris

## Diagnóstico / contexto actual
- El mapa intentaba inferir estatus desde múltiples fuentes y podía priorizar estado remoto.
- Aunque el GeoJSON trajera estatus, en algunos casos no se aplicaba como fuente principal de color.

## Fases
### Fase 1: Priorizar estatus directo del GeoJSON
- Descripción: leer primero el estatus del propio feature importado.
- Archivos afectados: lib/features/mapa/presentation/mapa_screen.dart
- Código clave:
  - Nuevo método _rawStatusFromGeoJson(...)
  - Prioridad de estado: estatus directo -> estatus inferido -> estatus remoto
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 2: Normalización robusta de estatus
- Descripción: normalizar variantes y asegurar salida de color (incluyendo fallback a Sin estatus).
- Archivos afectados: lib/features/mapa/presentation/mapa_screen.dart
- Código clave:
  - _normalizeEstatusText(...)
  - Manejo de variantes y fallback a Sin estatus
- Tiempo estimado: 15 min
- Riesgo: Bajo

## Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|------|------------------|--------|
| Prioridad de estatus GeoJSON | 20 min | Bajo |
| Normalización y fallback | 15 min | Bajo |

## Criterio de éxito
- Si el GeoJSON contiene estatus = liberado, el polígono se pinta en verde.
- Si contiene estatus = no liberado, se pinta en rojo.
- Si no hay estatus válido, se pinta en gris.

## Resultado / evidencia
- Ajuste aplicado en capa de polígonos importados.
- Validación estática del archivo sin errores de análisis.

## Próximo paso
Probar con un GeoJSON que tenga mezcla de estatus válidos e inválidos para confirmar coloración final en mapa.
