# IMPL_17: GeoJSON estatus para color y pin de seleccion

**Estado**: Implementado
**Fecha**: 13 de mayo de 2026
**Rama**: desktop/fase-1

## Objetivo
Corregir dos comportamientos del mapa:
1. Detectar correctamente estatus Liberado/No liberado al cargar GeoJSON para pintar poligonos por estatus.
2. Mostrar un icono de ubicacion visible al seleccionar un poligono importado.

## Diagnostico / contexto actual
- El coloreo de features importados dependia de pocas llaves y comparacion exacta de valores de estatus.
- Variaciones comunes del GeoJSON (status, estatus_juridico, estado_liberacion, booleanos, texto con guiones/underscores o acentos) podian quedar sin clasificar.
- El resaltado del feature importado seleccionado usaba un punto circular, no un pin de ubicacion.

## Fases
### Fase 1: Normalizacion robusta de estatus en GeoJSON
**Descripcion**: agregar normalizador de texto para clasificar variantes de estatus.
**Archivo afectado**: lib/features/mapa/presentation/mapa_screen.dart
**Codigo clave**:
- Nuevo metodo `_normalizeEstatusText(String?)`.
- Uso en `_importedFeatureColor(...)` para resolver color final.
- Soporte para variantes: `status`, `estatus_juridico`, `liberacion`, `estado_liberacion`.
- Soporte para valores booleanos/string (`1/0`, `true/false`) y textos parciales (`liberad`, `no liberad`, `pendiente`, `en proceso`).
**Tiempo estimado**: 35 min
**Riesgo**: Bajo

### Fase 2: Prefill de estatus al abrir captura de feature importado
**Descripcion**: al seleccionar poligono importado, detectar y precargar estatus en el modal.
**Archivo afectado**: lib/features/mapa/presentation/mapa_screen.dart
**Codigo clave**:
- En `_openCapturaForImportedFeature(...)` se calcula `estatusRaw` y se asigna `_estatusPredio = _normalizeEstatusText(estatusRaw)`.
**Tiempo estimado**: 10 min
**Riesgo**: Bajo

### Fase 3: Pin de ubicacion para enfatizar seleccion
**Descripcion**: reemplazar marcador circular del feature importado seleccionado por pin de ubicacion.
**Archivo afectado**: lib/features/mapa/presentation/mapa_screen.dart
**Codigo clave**:
- En `_buildImportedMarkers(...)` se usa `_buildMarkerDot(...)` (icono location pin).
**Tiempo estimado**: 10 min
**Riesgo**: Bajo

## Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|------|------------------|--------|
| Normalizacion de estatus | 35 min | Bajo |
| Prefill de estatus en captura | 10 min | Bajo |
| Pin de seleccion | 10 min | Bajo |

## Criterio de exito
- Al importar GeoJSON, los poligonos con estatus de liberacion se colorean correctamente.
- Variantes frecuentes de llaves y valores de estatus se reconocen sin ajuste manual.
- Al seleccionar un poligono importado, se visualiza un pin de ubicacion sobre el poligono.

## Resultado / evidencia
- Compilacion sin errores en `mapa_screen.dart` tras los cambios.
- Flujo de color por estatus y pin de seleccion actualizado en la vista de mapa.

## Proximo paso
Probar con un GeoJSON real que contenga al menos un feature liberado y uno no liberado (con variantes de llaves/valores) para validar visualmente el coloreo y el pin de seleccion.
