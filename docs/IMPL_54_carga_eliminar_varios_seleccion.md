# IMPL_54 - Carga: eliminar varios con seleccion

Estado: Completado  
Fecha: 2026-06-04  
Rama: desktop/fase-1

## 1. Objetivo
Cambiar la accion de borrado masivo en la seccion de Archivos para que el usuario pueda seleccionar varios elementos y eliminarlos en un solo flujo guiado, con un texto mas claro en la interfaz.

## 2. Diagnostico / contexto actual
La pantalla de Carga mostraba una accion de "Eliminar todos" ligada al conjunto completo de archivos importados. No existia un mecanismo visible de seleccion por fila, por lo que el usuario no podia acotar el borrado a un subconjunto.

## 3. Fases

### Fase 1 - Identificacion del flujo actual
- Descripcion: Revisar el listado de archivos importados y la accion de eliminacion global.
- Archivos afectados: `lib/features/carga/presentation/carga_archivo_screen.dart`
- Codigo clave: Boton "Eliminar todos" y metodo `_eliminarTodos`.
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2 - Seleccion multiple por fila
- Descripcion: Agregar casillas de seleccion a cada archivo importado y estado visual para elementos marcados.
- Archivos afectados: `lib/features/carga/presentation/carga_archivo_screen.dart`
- Codigo clave: `Set<String> _archivosSeleccionados`, `_toggleArchivoSeleccionado`, `Checkbox` en `_buildArchivoTile`.
- Tiempo estimado: 20 min
- Riesgo: Medio bajo

### Fase 3 - Renombrado de accion y borrado parcial
- Descripcion: Renombrar la accion a "Eliminar varios" y ejecutar el borrado solo sobre los archivos seleccionados.
- Archivos afectados: `lib/features/carga/presentation/carga_archivo_screen.dart`
- Codigo clave: `_eliminarVarios(List<ImportedFile> files)` y dialogo de confirmacion con conteo de seleccionados.
- Tiempo estimado: 15 min
- Riesgo: Medio bajo

### Fase 4 - Limpieza de estado y validacion
- Descripcion: Limpiar la seleccion al recargar o terminar la eliminacion y validar formato/errores.
- Archivos afectados: `lib/features/carga/presentation/carga_archivo_screen.dart`
- Codigo clave: `_limpiarSeleccionArchivos()`, validacion con `dart format` y analisis del archivo.
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 20 min | Medio bajo |
| Fase 3 | 15 min | Medio bajo |
| Fase 4 | 10 min | Bajo |
| **Total** | **55 min** | **Bajo / medio bajo** |

## 5. Criterio de exito
- La interfaz muestra "Eliminar varios" en lugar de "Eliminar todos".
- El usuario puede marcar uno o mas archivos importados.
- La eliminacion actua solo sobre los archivos seleccionados.
- La pantalla no queda con estados seleccionados obsoletos despues del proceso.

## 6. Resultado / evidencia
- Se agrego seleccion por fila con `Checkbox`.
- Se renombro el flujo de eliminacion masiva a "Eliminar varios".
- Se agrego contador de seleccionados y accion para limpiar seleccion.
- Se conserva el borrado individual por archivo.

## 7. Proximo paso
Validar manualmente en `#/carga` estos escenarios:
1. Marcar varios archivos.
2. Ejecutar "Eliminar varios".
3. Confirmar que solo se eliminen los seleccionados y que la seleccion se limpie al finalizar.
