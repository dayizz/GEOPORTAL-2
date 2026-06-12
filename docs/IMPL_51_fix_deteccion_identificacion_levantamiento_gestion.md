# IMPL_51 - Fix de detección de identificación y levantamiento en Gestión

- Estado: Completado
- Fecha: 2026-06-04
- Rama: desktop/fase-1

## 1. Objetivo
Corregir la detección de los campos de identificación y levantamiento para que Gestión y Balance lean correctamente los valores reales del proyecto.

## 2. Diagnostico / contexto actual
La pantalla de Gestión y los cálculos derivados dependían de claves exactas como `identificacion` y `levantamiento`. En datos históricos o importados podían existir variantes como `_identificacion`, `acercamiento`, `identificación`, `levantado`, `lev` o textos equivalentes, lo que provocaba que los flags se leyeran como falsos y que los conteos quedaran en cero.

## 3. Fases
### Fase 1: Normalización de lectura en el modelo de dominio
- Descripcion: Se amplió la lectura booleana en `Predio.fromMap` para resolver alias reales y campos con prefijos/variantes.
- Archivos afectados:
  - `lib/features/predios/models/predio.dart`
- Codigo clave:
  - Nuevo helper `_readBool(...)`
  - Lectura de `identificacion`, `levantamiento`, `negociacion`, `cop` y `poligono_insertado` con listas de alias
- Tiempo estimado: 20 minutos
- Riesgo: Bajo

### Fase 2: Normalización de GeoJSON
- Descripcion: Se agregaron alias canónicos para que el normalizador de GeoJSON conserve y convierta los nombres reales de los campos antes de sincronizar.
- Archivos afectados:
  - `lib/features/carga/utils/geojson_mapper.dart`
- Codigo clave:
  - Alias para `identificacion`, `levantamiento`, `negociacion` y `cop`
- Tiempo estimado: 15 minutos
- Riesgo: Bajo

### Fase 3: Normalización del importador XLSX
- Descripcion: Se reforzaron los alias del importador XLSX para detectar etiquetas como `acercamiento` y `levantamiento_si`.
- Archivos afectados:
  - `lib/features/carga/services/xlsx_import_service.dart`
- Codigo clave:
  - Alias ampliados para identificación y levantamiento
- Tiempo estimado: 10 minutos
- Riesgo: Bajo

### Fase 4: Normalización del backend
- Descripcion: Se reforzó la normalización del backend para aceptar las mismas variantes al persistir predios.
- Archivos afectados:
  - `backend/app/main.py`
- Codigo clave:
  - Nuevo helper `_read_bool_field(...)`
  - Lectura tolerante de alias para `identificacion` y `levantamiento`
- Tiempo estimado: 15 minutos
- Riesgo: Bajo

### Fase 5: Validacion tecnica
- Descripcion: Se aplicó formato y se verificó sintaxis/errores de los archivos modificados.
- Archivos afectados:
  - `lib/features/predios/models/predio.dart`
  - `lib/features/carga/utils/geojson_mapper.dart`
  - `lib/features/carga/services/xlsx_import_service.dart`
  - `backend/app/main.py`
- Tiempo estimado: 10 minutos
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 20 min | Bajo |
| Fase 2 | 15 min | Bajo |
| Fase 3 | 10 min | Bajo |
| Fase 4 | 15 min | Bajo |
| Fase 5 | 10 min | Bajo |
| Total | 70 min | Bajo |

## 5. Criterio de exito
- Gestión deja de mostrar los campos en falso cuando los datos llegan con variantes de nombre.
- Balance deja de reportar ceros por falta de reconocimiento de identificación/levantamiento.
- Los datos importados por GeoJSON, XLSX o backend convergen a claves canónicas.

## 6. Resultado / evidencia
- El modelo de lectura ya tolera alias y variantes reales.
- El normalizador GeoJSON y el importador XLSX fueron ampliados.
- El backend también acepta esas variantes al persistir.
- Validación técnica: sin errores de análisis ni de sintaxis.

## 7. Proximo paso
1. Probar con un predio que tenga `acercamiento`, `identificación` o `_identificacion` para confirmar que Gestión lo marca correctamente.
2. Revisar en Balance que los conteos de avance ya reflejen esos flags.
3. Si aún hay registros históricos inconsistentes, ejecutar una normalización masiva de datos persistidos.
