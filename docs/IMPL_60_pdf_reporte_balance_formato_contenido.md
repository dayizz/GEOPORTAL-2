# IMPL_60 - PDF Reporte: contenido de balance segun formato

Estado: Completado  
Fecha: 2026-06-04  
Rama: desktop/fase-1

## 1. Objetivo
Ajustar el reporte generado en PDF para que incluya, conforme al formato solicitado:
1. Total de predios con barra de liberados y no liberados.
2. Avance por tipo de propiedad de acuerdo con el segmento indicado.

## 2. Diagnostico / contexto actual
El PDF previo mostraba indicadores generales y graficas de otro enfoque (identificacion/levantamiento/negociacion por tipo), lo cual no reflejaba exactamente el contenido operativo del Balance requerido para el formato final.

## 3. Fases

### Fase 1 - Alineacion de regla de liberacion
- Descripcion: Implementar en backend la misma logica de liberacion usada en Balance para evitar diferencias entre pantalla y PDF.
- Archivos afectados: `backend/app/main.py`
- Codigo clave: helper `_predio_is_liberado(predio)` usando `cop`, presencia de PDF y estatus gestion.
- Tiempo estimado: 15 min
- Riesgo: Bajo

### Fase 2 - Nuevos indicadores para PDF
- Descripcion: Calcular y exponer en `datos_automatizados` los campos necesarios para el formato solicitado.
- Archivos afectados: `backend/app/main.py`
- Codigo clave:
  - `predios_liberados_seg`
  - `predios_no_liberados_seg`
  - `avance_tipo_propiedad_segmento` (privada / social_dominio)
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 3 - Rediseño del cuerpo PDF
- Descripcion: Reemplazar el contenido principal por secciones A y B solicitadas:
  - A) total + barra liberados/no liberados
  - B) tabla de avance por tipo de propiedad segun segmento
- Archivos afectados: `backend/app/main.py`
- Codigo clave: seccion `story` en `_build_reporte_pdf`.
- Tiempo estimado: 25 min
- Riesgo: Medio bajo

### Fase 4 - Validacion tecnica
- Descripcion: Verificar sintaxis, generar PDF y confirmar persistencia de nuevos campos en historial de reportes.
- Archivos afectados: `backend/app/main.py`, `backend/data/reportes.json`
- Codigo clave: `python3 -m py_compile`, `POST /reportes/generar`, validacion de claves en ultimo registro.
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 15 min | Bajo |
| Fase 2 | 20 min | Bajo |
| Fase 3 | 25 min | Medio bajo |
| Fase 4 | 10 min | Bajo |
| **Total** | **70 min** | **Bajo / medio bajo** |

## 5. Criterio de exito
- El PDF incluye total de predios del segmento y barra visual de liberados/no liberados.
- El PDF incluye avance por tipo de propiedad para el segmento indicado.
- Los datos del PDF se calculan con la misma logica de liberacion que Balance.

## 6. Resultado / evidencia
- Endpoint `POST /reportes/generar` responde `200 OK` y devuelve PDF.
- El ultimo registro de `backend/data/reportes.json` contiene los campos nuevos (`predios_liberados_seg`, `predios_no_liberados_seg`, `avance_tipo_propiedad_segmento`).
- Backend reiniciado con la nueva logica.

## 7. Proximo paso
Validar visualmente un PDF generado desde la UI y confirmar con usuarios de negocio que el formato final cumple su plantilla operacional.
