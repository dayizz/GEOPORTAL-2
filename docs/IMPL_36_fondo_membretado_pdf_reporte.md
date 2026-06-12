# IMPL_36 Fondo Membretado PDF Reporte

- Estado: Implementado
- Fecha: 2026-05-19
- Rama: desktop/fase-1

## 1. Objetivo
Usar una imagen membretada de página completa como fondo del PDF del reporte, colocando toda la información del reporte por encima.

## 2. Diagnóstico / contexto actual
El generador PDF del backend dibujaba un encabezado y pie vectorial con ReportLab. Se requería reemplazar ese esquema por una imagen membretada oficial como fondo de la hoja.

## 3. Fases

### Fase 1. Integración de fondo por imagen en backend
- Descripción: cargar una plantilla de imagen y dibujarla en cada página del PDF antes del contenido.
- Archivos afectados:
  - `backend/app/main.py`
- Código clave:
  - Constante `REPORTE_MEMBRETE_FILE = backend/data/reporte_membrete.png`
  - Uso de `ImageReader` de ReportLab
  - `canvas.drawImage(...)` en `onFirstPage/onLaterPages`
  - Fallback al encabezado/pie vectorial actual si no existe la imagen
- Tiempo estimado: 30 min
- Riesgo: Bajo

### Fase 2. Validación funcional
- Descripción: validar sintaxis Python y endpoint `/reportes/generar`.
- Archivos afectados:
  - `backend/app/main.py`
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Integración de fondo membretado | 30 min | Bajo |
| Validación endpoint | 10 min | Bajo |
| Total | 40 min | Bajo |

## 5. Criterio de éxito
- El PDF toma como fondo la imagen `backend/data/reporte_membrete.png` cuando existe.
- El contenido de reporte queda por encima del fondo.
- Si falta imagen, el PDF sigue generando con fallback visual.

## 6. Resultado / evidencia
- Se implementó lectura de imagen membretada y pintado de fondo por página.
- Se verificó compilación de `backend/app/main.py`.
- Se verificó generación de PDF con `POST /reportes/generar` (HTTP 200).

## 7. Próximo paso
- Guardar la imagen oficial adjunta por el usuario en:
  - `backend/data/reporte_membrete.png`
- Regenerar un reporte para validar el fondo oficial exacto.
