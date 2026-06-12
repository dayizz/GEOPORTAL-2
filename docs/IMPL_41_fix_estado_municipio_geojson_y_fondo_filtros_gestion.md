# IMPL_41: Fix deteccion estado/municipio GeoJSON y fondo filtros en Gestion

- Estado: Implementado
- Fecha: 26 de mayo de 2026
- Rama: desktop/fase-1

## 1. Objetivo
Corregir dos incidencias funcionales en Gestion:
- Asegurar deteccion robusta de `estado` y `municipio` desde GeoJSON para mostrar `estado/municipio` en la tabla.
- Forzar visualmente el recuadro de filtros en gris claro en el modal.

## 2. Diagnostico / contexto actual
- Algunos archivos GeoJSON usan aliases distintos para estado/municipio, o colocan campos a nivel raiz del feature fuera de `properties`.
- El modal de filtros podia mantener fondo blanco por la capa Material del `showModalBottomSheet`, aunque el contenedor interno ya tuviera color gris.

## 3. Fases
### Fase 1: Robustecer aliases de estado/municipio en mapper
Descripcion:
- Se ampliaron aliases canónicos para detectar múltiples variantes comunes de claves.

Archivos afectados:
- lib/features/carga/utils/geojson_mapper.dart

Codigo clave:
- `_keyAliases['estado']`
- `_keyAliases['municipio']`

Tiempo estimado: 15 min
Riesgo: Bajo

### Fase 2: Mezclar top-level props en importacion local
Descripcion:
- Se mezclan campos del nivel raiz del feature con `properties` antes de normalizar.
- Esto permite detectar estado/municipio aunque no vengan anidados en `properties`.

Archivos afectados:
- lib/features/predios/providers/local_predios_provider.dart

Codigo clave:
- `upsertManyFromGeoJsonFeatures(...)` con `mergedProps`

Tiempo estimado: 20 min
Riesgo: Bajo

### Fase 3: Forzar fondo gris claro del modal de filtros
Descripcion:
- Se configuró `backgroundColor: Colors.transparent` en `showModalBottomSheet`.
- Se envolvió contenido en `ClipRRect + Material(color: gris claro)` para garantizar render del color.

Archivos afectados:
- lib/features/tabla/presentation/tabla_screen.dart

Codigo clave:
- `_showFiltros(...)`

Tiempo estimado: 15 min
Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Aliases estado/municipio | 15 min | Bajo |
| Merge top-level en import local | 20 min | Bajo |
| Fondo gris modal filtros | 15 min | Bajo |
| Total | 50 min | Bajo |

## 5. Criterio de exito
- Tabla de Gestion muestra `estado/municipio` (ej. `Morelos/Zacatepec`) cuando esos campos existen en el GeoJSON.
- El modal de filtros se visualiza con fondo gris claro de forma consistente.

## 6. Resultado / evidencia
- Validacion estática sin errores en archivos modificados con `get_errors`.
- Correcciones aplicadas en mapper, importación local y UI del modal.

## 7. Proximo paso
1. Probar importación con un GeoJSON que use aliases alternos (`nom_edo`, `nom_mun`, etc.).
2. Verificar visualmente el modal de filtros en desktop y en diferentes escalas de ventana.
