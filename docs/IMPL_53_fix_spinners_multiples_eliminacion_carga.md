# IMPL_53 - Fix spinners multiples en eliminacion de carga

Estado: Completado  
Fecha: 2026-06-04  
Rama: desktop/fase-1

## 1. Objetivo
Evitar la aparicion de multiples iconos de carga al eliminar archivos en la pantalla de Carga de Archivos, manteniendo una experiencia de progreso clara y sin ruido visual.

## 2. Diagnostico / contexto actual
Durante la eliminacion individual o masiva, cada fila de archivo renderizaba un overlay propio con spinner y texto de espera cuando `_eliminando` estaba activo. En listas con varios elementos esto provocaba muchos indicadores simultaneos.

## 3. Fases

### Fase 1 - Identificacion del origen de spinners repetidos
- Descripcion: Revisar el tile de cada archivo para ubicar condiciones de render durante estados de carga y eliminacion.
- Archivos afectados: `lib/features/carga/presentation/carga_archivo_screen.dart`
- Codigo clave: Bloque `if (busy) Positioned.fill(...)` dentro de `_buildArchivoTile`.
- Tiempo estimado: 10 min
- Riesgo: Bajo (UI)

### Fase 2 - Ajuste de render en lista
- Descripcion: Eliminar overlay por fila para evitar repeticion de spinners.
- Archivos afectados: `lib/features/carga/presentation/carga_archivo_screen.dart`
- Codigo clave: Se removio el `Positioned.fill` con `CircularProgressIndicator` y texto "Actualizando, por favor espera..." por cada tile.
- Tiempo estimado: 10 min
- Riesgo: Bajo (sin cambios en logica de negocio)

### Fase 3 - Validacion tecnica
- Descripcion: Verificar formato y errores de analisis despues del ajuste.
- Archivos afectados: `lib/features/carga/presentation/carga_archivo_screen.dart`
- Codigo clave: `dart format` y revision de errores del archivo.
- Tiempo estimado: 5 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 10 min | Bajo |
| Fase 3 | 5 min | Bajo |
| **Total** | **25 min** | **Bajo** |

## 5. Criterio de exito
- Al eliminar un archivo, no se muestran overlays de carga repetidos por cada fila.
- Al eliminar varios archivos, no aparecen multiples spinners simultaneos en la lista.
- La pantalla mantiene un unico flujo visual de progreso durante la eliminacion.

## 6. Resultado / evidencia
- Se elimino el overlay de carga por fila en `_buildArchivoTile`.
- Se conserva el estado de bloqueo de acciones por `busy` para evitar interacciones conflictivas durante la operacion.
- La interfaz deja de renderizar indicadores redundantes en cascada.

## 7. Proximo paso
Validar de forma manual en la vista `#/carga` estos escenarios:
1. Eliminar un archivo individual.
2. Eliminar todos los archivos importados.
3. Confirmar que no reaparezcan spinners por fila en ninguno de los dos casos.
