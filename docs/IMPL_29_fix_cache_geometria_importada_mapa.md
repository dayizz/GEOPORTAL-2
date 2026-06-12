# IMPL_29 - Fix cache de geometria importada en mapa
- Estado: Implementado
- Fecha: 2026-05-14
- Rama: desktop/fase-1

## 1. Objetivo
Corregir el riesgo de no renderizar poligonos importados por colisiones de cache en la extraccion de geometria (`vertices=0`) al usar `identityHashCode(feature)` como llave.

## 2. Diagnostico / contexto actual
- El flujo de importacion si entrega features al mapa (`features=159`) pero en ejecuciones reportadas no se dibujaban vertices.
- La extraccion de coordenadas UTM y conversion a WGS84 funciona con los datos reales del archivo `segmentos_1617_1405.geojson`.
- El cache de geometria importada estaba indexado por `int` derivado de `identityHashCode`, lo que permite colisiones y puede devolver geometrias incorrectas/vacias para objetos distintos.

## 3. Fases
### Fase 1 - Reemplazo de cache por identidad real de objeto
- Descripcion: Sustituir `Map<int, _ImportedGeometryCacheEntry>` por `Expando<_ImportedGeometryCacheEntry>` para asociar cache directamente al objeto feature, sin depender de hash manual.
- Archivos afectados:
  - `lib/features/mapa/presentation/mapa_screen.dart`
- Codigo clave:
  - `static final Expando<_ImportedGeometryCacheEntry> _importedGeometryCache = Expando<_ImportedGeometryCacheEntry>('importedGeometryCache');`
  - `_getImportedGeometryCache(...)` ahora lee/escribe con `_importedGeometryCache[feature]`.
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 2 - Validacion estatica
- Descripcion: Ejecutar analisis del archivo modificado para asegurar que el cambio compila sin errores.
- Archivos afectados:
  - `lib/features/mapa/presentation/mapa_screen.dart`
- Codigo clave:
  - `flutter analyze lib/features/mapa/presentation/mapa_screen.dart`
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Esfuerzo | Riesgo |
|---|---:|---|
| Fase 1 | 20 min | Bajo |
| Fase 2 | 10 min | Bajo |
| Total | 30 min | Bajo |

## 5. Criterio de exito
- No depender de hashes enteros para cache de geometria por feature.
- Mantener compatibilidad del flujo actual de render sin cambios de API.
- `flutter analyze` sin errores nuevos en el archivo intervenido.

## 6. Resultado / evidencia
- Cambio aplicado en `mapa_screen.dart`:
  - Cache migrado de `Map<int,...>` a `Expando<...>`.
  - Lectura/escritura de cache usando referencia de objeto feature.
- Validacion:
  - `flutter analyze lib/features/mapa/presentation/mapa_screen.dart` ejecutado.
  - Sin errores de compilacion; solo warnings preexistentes.

## 7. Proximo paso
Ejecutar prueba funcional manual en macOS:
1. Importar de nuevo `segmentos_1617_1405.geojson`.
2. Confirmar en log que `imported_visuals` reporta `vertices > 0`.
3. Verificar visualmente que los poligonos se dibujan en mapa.

## 8. Notas adicionales
Se mantiene temporalmente el log `geom_debug` para confirmar estructura de geometria en runtime durante validacion final de QA manual.
