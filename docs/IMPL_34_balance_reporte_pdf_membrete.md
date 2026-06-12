# IMPL_34: Balance > Reporte automatizado en PDF con membrete oficial

**Estado**: Implementado
**Fecha**: 2026-05-18
**Rama**: desktop/fase-1

## Objetivo
Agregar dentro de la sección **Balance** una subvista llamada **Reporte** para capturar solo los datos que requieren criterio humano, cruzarlos con los datos automáticos del balance y generar un PDF final con formato membretado, folio autogenerado y gráficas embebidas.

## Diagnostico / contexto actual
La app ya cuenta con la ruta de Balance en `/reportes` y un flujo de resumen visual basado en los predios cargados. Sin embargo, no existe una vista específica para captura previa de reporte ni un motor de generación de PDF con diseño oficial. Para un documento con encabezados institucionales, bloques de texto fijo, campos variables y gráficas, la composición directa en UI de Flutter sería frágil y costosa de ajustar.

La alternativa más estable fue separar responsabilidades: el frontend recolecta el formulario y el backend genera el PDF con membrete y folio autogenerado.

## Fases con alcance tecnico

### Fase 1: Nueva subruta Reporte dentro de Balance
Descripcion:
- Agregar una entrada secundaria en Balance para abrir la vista de reporte.
- Reutilizar el contexto de proyecto y segmento ya filtrado en Balance.
- Mantener el acceso como una pantalla dedicada y no como un modal temporal.

Archivos afectados:
- lib/shared/widgets/app_scaffold.dart
- lib/core/router/app_router.dart
- lib/features/reportes/presentation/reportes_screen.dart
- lib/features/reportes/presentation/reporte_form_screen.dart

Codigo clave:
- Navegacion a `/reportes/reporte`
- Selector de proyecto/segmento enlazado con el contexto del balance

Tiempo estimado: 45 min
Riesgo: Bajo

### Fase 2: Formulario de captura y payload cruzado
Descripcion:
- Construir un formulario con los campos humanos: proyecto, segmento, fecha, para, de y descripcion del reporte.
- Generar el folio en el momento de presionar Generar, sin exponerlo como campo editable.
- Cruzar el formulario con los datos calculados del balance para formar el payload del motor de PDF.

Archivos afectados:
- lib/features/reportes/presentation/reporte_form_screen.dart
- lib/features/reportes/services/reporte_service.dart
- lib/shared/services/backend_service.dart

Codigo clave:
- `folio_reporte` autogenerado
- `datos_formulario`
- `datos_automatizados`

Tiempo estimado: 60 min
Riesgo: Medio

### Fase 3: Motor de PDF en backend con HTML/CSS
Descripcion:
- Construir el PDF directamente en backend con reportlab y composición declarativa.
- Generar las gráficas dentro del flujo de render y colocarlas en el documento final.
- Devolver el PDF como `application/pdf` con folio en `Content-Disposition`.

Archivos afectados:
- backend/main.py
- backend/requirements.txt

Codigo clave:
- Endpoint de generación de reporte
- Render de plantilla HTML
- Conversión HTML a PDF

Tiempo estimado: 120 min
Riesgo: Alto

### Fase 4: Integracion de descarga y vista previa
Descripcion:
- Exponer el PDF generado al frontend para compartir o guardar desde la hoja del sistema.
- Manejar errores de validacion, datos faltantes y generación fallida.
- Dejar listo el flujo para repetir la generación con otro folio.

Archivos afectados:
- lib/features/reportes/presentation/reporte_form_screen.dart
- lib/shared/services/backend_service.dart
- lib/features/reportes/services/reporte_service.dart

Codigo clave:
- Descarga del PDF
- Preview o apertura externa
- Manejo de errores del backend

Tiempo estimado: 40 min
Riesgo: Medio

## Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Subruta Reporte | 45 min | Bajo |
| Formulario y payload | 60 min | Medio |
| Motor PDF en backend | 120 min | Alto |
| Integracion final | 40 min | Medio |
| Total | 265 min | Medio |

## Criterio de exito
- La sección Reporte aparece dentro de Balance y permite capturar solo los datos humanos.
- El folio del reporte se genera automáticamente al presionar Generar.
- El PDF sale con membrete oficial, datos variables, texto fijo y gráficas.
- La generación pesada ocurre en backend y no bloquea la UI.

## Resultado / evidencia
- Se implementó la subruta `/reportes/reporte` y el formulario de captura.
- El backend ahora genera y devuelve el PDF en `/reportes/generar`.
- Se validó el archivo Dart del reporte y el módulo backend sin errores de sintaxis.

## Proximo paso
- Reprobar el flujo end-to-end contra una instancia local del backend y ajustar el membrete visual si se requiere usar la imagen oficial exacta.
