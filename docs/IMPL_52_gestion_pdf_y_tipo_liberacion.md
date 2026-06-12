# IMPL_52 - Gestion: encabezado PDF y columna Tipo de liberacion

- Estado: Completado
- Fecha: 2026-06-04
- Rama: desktop/fase-1

## 1. Objetivo
Actualizar la tabla de Gestion para renombrar la columna de COP a PDF y agregar una columna adicional llamada Tipo de liberacion.

## 2. Diagnostico / contexto actual
La tabla de Gestion mostraba un indicador de documento con el encabezado COP/DOT. No existia una columna separada para el tipo de liberacion. El modelo actual no persiste un campo explicito de tipo de liberacion, por lo que era necesario derivar una etiqueta util a partir del documento vinculado.

## 3. Fases
### Fase 1: Renombrar el encabezado del documento
- Descripcion: Se reemplazo el encabezado de la columna de COP/DOT por PDF.
- Archivos afectados:
  - `lib/features/tabla/presentation/tabla_screen.dart`
- Codigo clave:
  - `COP/DOT` -> `PDF`
- Tiempo estimado: 5 minutos
- Riesgo: Bajo

### Fase 2: Agregar columna Tipo de liberacion
- Descripcion: Se agrego una nueva columna textual para mostrar el tipo de liberacion derivado del documento vinculado.
- Archivos afectados:
  - `lib/features/tabla/presentation/tabla_screen.dart`
- Codigo clave:
  - Nuevo helper `_tipoLiberacionLabel(Predio predio)`
  - Insercion de columna entre PDF y Fecha
- Tiempo estimado: 15 minutos
- Riesgo: Bajo

### Fase 3: Ajuste de indices y anchos
- Descripcion: Se desplazaron indices y anchos de columnas para conservar la estructura y evitar desalineacion de celdas.
- Archivos afectados:
  - `lib/features/tabla/presentation/tabla_screen.dart`
- Codigo clave:
  - Actualizacion de `rawWidths`
  - Actualizacion de `headers`
  - Reasignacion de `widths[14]` a `widths[21]`
- Tiempo estimado: 10 minutos
- Riesgo: Bajo

### Fase 4: Validacion tecnica
- Descripcion: Se aplico formato y se verifico que el archivo compila sin errores.
- Archivos afectados:
  - `lib/features/tabla/presentation/tabla_screen.dart`
- Tiempo estimado: 5 minutos
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 5 min | Bajo |
| Fase 2 | 15 min | Bajo |
| Fase 3 | 10 min | Bajo |
| Fase 4 | 5 min | Bajo |
| Total | 35 min | Bajo |

## 5. Criterio de exito
- El encabezado del documento aparece como PDF.
- Existe una nueva columna llamada Tipo de liberacion.
- La tabla mantiene alineacion correcta y sin errores de analisis.

## 6. Resultado / evidencia
- Cambios aplicados en la tabla de Gestion.
- Validacion tecnica completada sin errores.

## 7. Proximo paso
Validar visualmente en la vista de Gestion que:
1. El encabezado PDF se vea correctamente.
2. La nueva columna Tipo de liberacion se muestre entre PDF y Fecha.
3. Los valores derivados sean coherentes con los documentos vinculados.
