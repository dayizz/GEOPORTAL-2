# IMPL_15_ocr_regex_km_rango.md

**Estado**: ✅ Implementado
**Fecha**: 13 de mayo de 2026
**Rama**: desktop/fase-1

## Objetivo
Adaptar el servicio OCR para detectar y extraer correctamente los valores de km inicio y km fin de frases como:

> "va del km 7+582.67 al 7+978.00 km"

asignando el valor menor como km inicio y el mayor como km fin.

## Diagnóstico / contexto actual
- El OCR ya extraía valores de km inicio y fin solo si estaban en formato simple (ej: "km inicio: 7.582").
- No detectaba frases con el patrón "km X+YYY.YY al X+YYY.YY km".

## Fases
- **Análisis de patrones reales en documentos**
- **Implementación de regex para detectar ambos valores**
- **Conversión de formato X+YYY.YY a decimal**
- **Asignación de menor a km inicio y mayor a km fin**
- **Integración y pruebas**

**Archivos afectados:**
- lib/features/tabla/services/pdf_ocr_service.dart

**Código clave:**
- Función `_extractKmPair` y lógica en `extractFromBytes`

| Fase | Tiempo estimado | Riesgo |
|------|-----------------|--------|
| Regex y parsing | 30 min | Bajo |
| Pruebas con PDF reales | 20 min | Medio |

## Criterio de éxito
- El sistema detecta ambos valores de km en frases con formato "va del km X+YYY.YY al X+YYY.YY km".
- El menor se asigna a km inicio y el mayor a km fin.
- Se mantiene compatibilidad con formatos anteriores.

## Resultado / evidencia
- Regex implementado y probado en entorno local.
- Extracción correcta de ambos valores y asignación adecuada.

## Próximo paso
- Validar con más documentos reales y ajustar si aparecen variantes de formato.
