# IMPL_37 Plantilla Textual de Reporte como Borrador

- Estado: Implementado
- Fecha: 2026-05-19
- Rama: desktop/fase-1

## 1. Objetivo
Alinear el texto del PDF generado con la estructura y redacción del archivo de referencia `Borrador reporte.pdf`, manteniendo la hoja membretada como fondo.

## 2. Diagnóstico / contexto actual
El reporte previo mostraba texto resumido y no seguía fielmente el cuerpo textual del borrador (asunto, redacción principal, viñetas y cierre institucional).

## 3. Fases

### Fase 1. Lectura de referencia y mapeo textual
- Descripción: extracción del contenido del PDF de ejemplo y detección de encabezados/secciones.
- Archivos afectados:
  - `/Users/dayana/Downloads/Borrador reporte.pdf` (referencia)
- Código clave: extracción de texto con `pypdf` para mapear encabezados y bloques.
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 2. Actualización de plantilla en backend
- Descripción: reestructuración del `story` del PDF para replicar la narrativa del borrador.
- Archivos afectados:
  - `backend/app/main.py`
- Código clave:
  - Encabezado institucional
  - Asunto y folio informativo
  - Para/De/Presente
  - Párrafo principal de LDDV
  - Indicadores de balance general
  - Cierre: Atentamente y CCP
  - Segunda página: Por propiedad privada / Por propiedad social
- Tiempo estimado: 35 min
- Riesgo: Medio

### Fase 3. Validación funcional
- Descripción: reinicio de backend, generación de PDF y verificación de texto extraído.
- Archivos afectados:
  - `backend/app/main.py`
- Tiempo estimado: 15 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Lectura y mapeo del borrador | 20 min | Bajo |
| Ajuste de plantilla | 35 min | Medio |
| Validación final | 15 min | Bajo |
| Total | 70 min | Medio |

## 5. Criterio de éxito
- El PDF generado incluye la estructura textual del borrador de referencia.
- El reporte mantiene hoja membretada como fondo y texto por encima.
- El endpoint `/reportes/generar` responde con PDF válido.

## 6. Resultado / evidencia
- Endpoint probado con HTTP 200.
- PDF generado con tamaño aproximado de 224 KB.
- Extracción de texto del PDF generado confirma presencia de:
  - "Asunto: Informe del balance actual del proyecto ..."
  - "Indicadores de balance general"
  - "Atentamente"
  - "Por propiedad privada / Por propiedad social"

## 7. Próximo paso
- Validar visualmente en la aplicación de escritorio con datos reales de operación y ajustar espaciado fino (tipografía/posición) si el usuario requiere una coincidencia visual 1:1 con el borrador.
