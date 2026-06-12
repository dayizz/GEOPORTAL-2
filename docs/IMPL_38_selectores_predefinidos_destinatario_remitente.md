# IMPL_38_selectores_predefinidos_destinatario_remitente

Estado: Implementado
Fecha: 2026-05-19
Rama: desktop/fase-1

## 1. Objetivo
Implementar en el formulario de reporte la selección predefinida de destinatario y remitente con opción "Otro", habilitando captura manual de nombre y cargo solo cuando se elija "Otro".

## 2. Diagnóstico / contexto actual
El formulario solicitaba siempre captura manual en campos separados para:
- Para - Nombre
- Para - Cargo
- De - Nombre
- De - Cargo

Se requería agilizar la captura mediante valores institucionales por defecto y conservar flexibilidad para casos excepcionales.

## 3. Fases

### Fase 1: Definición de opciones y estado de selección
Descripción:
- Se agregaron constantes para opciones de selector y textos predefinidos de destinatario/remitente.
- Se añadieron variables de estado para controlar la opción activa en cada selector.

Archivos afectados:
- lib/features/reportes/presentation/reporte_form_screen.dart

Código clave:
- Constantes de opción: predefinido, otro
- Constantes de nombre/cargo predefinidos
- Estado: _destinatarioSeleccion, _remitenteSeleccion

Tiempo estimado:
- 20 minutos

Riesgo:
- Bajo (ajuste de UI sin cambiar contrato del backend)

### Fase 2: Inicialización y autocompletado de controladores
Descripción:
- Se agregaron métodos para aplicar valores predefinidos a controladores de payload.
- En initState se cargan automáticamente destinatario y remitente predefinidos.

Archivos afectados:
- lib/features/reportes/presentation/reporte_form_screen.dart

Código clave:
- _aplicarDestinatarioPredefinido()
- _aplicarRemitentePredefinido()
- initState()

Tiempo estimado:
- 15 minutos

Riesgo:
- Bajo

### Fase 3: Render condicional de campos manuales
Descripción:
- Se reemplazaron campos directos por DropdownButtonFormField para Destinatario y Remitente.
- Si se elige "Otro", se muestran dos casillas manuales (nombre y cargo).
- Si se elige predefinido, se muestra un bloque informativo con nombre/cargo institucionales y los controladores se rellenan automáticamente.

Archivos afectados:
- lib/features/reportes/presentation/reporte_form_screen.dart

Código clave:
- DropdownButtonFormField para Destinatario
- DropdownButtonFormField para Remitente
- Render condicional con _destinatarioEsOtro y _remitenteEsOtro

Tiempo estimado:
- 35 minutos

Riesgo:
- Medio-bajo (validaciones condicionales en formulario)

## 4. Resumen de esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 20 min | Bajo |
| Fase 2 | 15 min | Bajo |
| Fase 3 | 35 min | Medio-bajo |
| Total | 70 min | Medio-bajo |

## 5. Criterio de éxito
- En Destinatario se muestran:
  - "Ing. Pavel López Medina / Titular de la Unidad de Verificación, Seguridad y Registro"
  - "Otro"
- Si se elige "Otro" en Destinatario, aparecen casillas para nombre y cargo manuales.
- En Remitente se muestran:
  - "Ing. Carlos Alberto Sandoval Manrique de Lara / Director de Verificación Ferroviaria \"A\""
  - "Otro"
- Si se elige "Otro" en Remitente, aparecen casillas para nombre y cargo manuales.
- El payload enviado al backend conserva claves existentes: para_nombre, para_cargo, de_nombre, de_cargo.

## 6. Resultado / evidencia
Resultado alcanzado:
- Cambio implementado en UI del formulario de reportes.
- El archivo modificado no reporta errores de análisis tras el ajuste.

Evidencia técnica:
- Reemplazo de TextFormField de Para/De por selectores y captura condicional.
- Autocompletado de controladores al seleccionar opción predefinida.

## 7. Próximo paso
Validar visualmente en ejecución Flutter que:
- El cambio de opción entre predefinido y "Otro" actualiza los campos correctamente.
- El PDF generado refleja nombre/cargo correctos según la selección realizada.
