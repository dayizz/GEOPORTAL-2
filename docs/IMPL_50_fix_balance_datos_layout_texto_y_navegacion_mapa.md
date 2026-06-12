# IMPL_50 - Fix Balance: datos desde Gestion, layout, textos y navegación a Mapa

- Estado: Completado
- Fecha: 2026-06-03
- Rama: desktop/fase-1

## 1. Objetivo
Corregir cuatro problemas reportados:
1. Balance mostraba valores en cero al no tomar proyecto con datos.
2. El contenido visual se encimaba entre graficas y textos.
3. Los textos de secciones no respetaban formato tipo oracion.
4. La navegación a Mapa presentaba latencia perceptible.

## 2. Diagnostico / contexto actual
- Balance filtraba por `_proyectoActual` fijo (inicialmente TQI), lo que provocaba ceros cuando los datos activos correspondian a otro proyecto.
- En cards de dona y panel de tipo, textos largos y quiebres de layout en anchos intermedios causaban sobreposicion visual.
- Algunos titulos estaban en minusculas iniciales.
- La navegación ejecutaba marca de operacion de usuario antes de completar el cambio de ruta.

## 3. Fases
### Fase 1: Seleccion automatica de proyecto con datos en Balance
- Descripcion: Se incorporo resolucion dinamica del proyecto activo para evitar dashboard en ceros.
- Archivos afectados:
  - `lib/features/reportes/presentation/reportes_screen.dart`
- Codigo clave:
  - Nuevo helper `_resolveProyectoActual(...)`.
  - Integracion de `proyectoActivoProvider` para priorizar proyecto de sesion.
  - Filtro principal de Balance actualizado para usar `proyectoActual` resuelto.
- Tiempo estimado: 25 minutos
- Riesgo: Bajo

### Fase 2: Correccion de encimado de contenido
- Descripcion: Se fortalecio el layout responsivo y truncado de textos en cards.
- Archivos afectados:
  - `lib/features/reportes/presentation/reportes_screen.dart`
- Codigo clave:
  - `maxLines` y `overflow: TextOverflow.ellipsis` en titulos de cards.
  - Umbral de grilla en tipo de propiedad ajustado (`>= 760`) para evitar sobrecarga horizontal.
- Tiempo estimado: 20 minutos
- Riesgo: Bajo

### Fase 3: Normalizacion de textos en formato oracion
- Descripcion: Se ajustaron encabezados y paneles para iniciar con mayuscula inicial.
- Archivos afectados:
  - `lib/features/reportes/presentation/reportes_screen.dart`
- Codigo clave:
  - `Avance general`
  - `Avance por tipo de propiedad`
  - `Avance por segmentos`
  - `Propiedad privada`
  - `Propiedad social y dominio pleno`
- Tiempo estimado: 10 minutos
- Riesgo: Bajo

### Fase 4: Optimización de navegación a Mapa
- Descripcion: Se movio la marca de operacion de usuario a microtarea posterior al `context.go(...)` para no bloquear la transición.
- Archivos afectados:
  - `lib/shared/widgets/app_scaffold.dart`
- Codigo clave:
  - `Future.microtask(() => markCurrentUserOperation())` tras el cambio de ruta en desktop y mobile.
- Tiempo estimado: 15 minutos
- Riesgo: Bajo

### Fase 5: Validacion tecnica
- Descripcion: Se aplico formato y validacion de errores de analisis en archivos modificados.
- Archivos afectados:
  - `lib/features/reportes/presentation/reportes_screen.dart`
  - `lib/shared/widgets/app_scaffold.dart`
- Tiempo estimado: 5 minutos
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 25 min | Bajo |
| Fase 2 | 20 min | Bajo |
| Fase 3 | 10 min | Bajo |
| Fase 4 | 15 min | Bajo |
| Fase 5 | 5 min | Bajo |
| Total | 75 min | Bajo |

## 5. Criterio de exito
- Balance no aparece en ceros cuando existen datos en Gestion para algun proyecto.
- No se observan encimados en cards/graficas en anchos intermedios.
- Los encabezados principales muestran mayuscula inicial.
- La navegación hacia Mapa responde de forma mas inmediata.

## 6. Resultado / evidencia
- Cambios implementados y verificados sin errores de analisis.
- Formato Dart aplicado en ambos archivos.

## 7. Proximo paso
1. Validar en UI con datos reales de al menos dos proyectos distintos.
2. Validar layout en resoluciones 1366x768, 1536x864 y 1920x1080.
3. Medir tiempo percibido de navegación Balance -> Mapa para confirmar mejora.
