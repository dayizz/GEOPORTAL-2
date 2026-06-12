# IMPL_49 - Ajuste de copy operativo en Balance

- Estado: Completado
- Fecha: 2026-06-03
- Rama: desktop/fase-1

## 1. Objetivo
Ajustar textos de la pantalla Balance para alinear la nomenclatura visual con el lenguaje operativo solicitado.

## 2. Diagnostico / contexto actual
La estructura funcional del rediseño ya estaba implementada, pero algunos encabezados y etiquetas no reflejaban de forma literal la nomenclatura acordada.

## 3. Fases
### Fase 1: Normalizacion de encabezados de secciones
- Descripcion: Se ajustaron los titulos visibles de las secciones principales.
- Archivos afectados:
  - `lib/features/reportes/presentation/reportes_screen.dart`
- Codigo clave:
  - `Avance General` -> `avance general`
  - `Avance por Tipo de Propiedad` -> `avance por tipo de propiedad`
  - `Avance por Segmentos` -> `avance por segmentos`
- Tiempo estimado: 10 minutos
- Riesgo: Bajo

### Fase 2: Ajuste de copy de bloques operativos
- Descripcion: Se refinaron labels de paneles y descripcion de cuantificacion para lectura operativa.
- Archivos afectados:
  - `lib/features/reportes/presentation/reportes_screen.dart`
- Codigo clave:
  - `Cuantificación general` -> `Cuadro de cuantificación`
  - `Km efectivos liberados vs no liberados` -> `Total de km efectivos liberados y km efectivos no liberados`
  - `Privada` -> `propiedad privada`
  - `Social + Dominio Pleno` -> `propiedad social y dominio pleno`
- Tiempo estimado: 15 minutos
- Riesgo: Bajo

### Fase 3: Validacion tecnica
- Descripcion: Se ejecuto formato y validacion de errores del archivo modificado.
- Archivos afectados:
  - `lib/features/reportes/presentation/reportes_screen.dart`
- Tiempo estimado: 5 minutos
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 10 min | Bajo |
| Fase 2 | 15 min | Bajo |
| Fase 3 | 5 min | Bajo |
| Total | 30 min | Bajo |

## 5. Criterio de exito
- Los encabezados y etiquetas clave reflejan la nomenclatura operativa solicitada.
- No existen errores de analisis tras los cambios de texto.

## 6. Resultado / evidencia
- Copy operativo actualizado en pantalla Balance.
- Analisis del archivo sin errores.

## 7. Proximo paso
Validar visualmente con usuarios del flujo para confirmar tono y terminologia final antes de congelar release.
