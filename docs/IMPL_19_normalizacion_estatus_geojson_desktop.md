# IMPL_19: Normalizacion de estatus GeoJSON y ajuste en app de escritorio

**Estado**: Implementado
**Fecha**: 13 de mayo de 2026
**Rama**: desktop/fase-1

## Objetivo
Corregir la deteccion de la propiedad estatus en GeoJSON para renderizar relleno de poligonos por estatus:
- Liberado: verde
- No liberado: rojo
- Sin estatus detectado: gris

Aplicar y validar en la app de escritorio.

## Diagnostico / contexto actual
Aun cuando el archivo GeoJSON contenia campo estatus, podia no detectarse por:
- Variaciones en el nombre de llave (espacios, guiones, acentos, mayusculas)
- Variaciones semanticas del valor (si/no, true/false, pendiente, en proceso, no firmado)

## Fases
### Fase 1: Normalizacion robusta de llaves de estatus
**Descripcion**: crear normalizador de llave y aceptar variantes de nombres.
**Archivo afectado**: lib/features/mapa/presentation/mapa_screen.dart
**Codigo clave**:
- Metodo nuevo `_normalizeStatusKey(String)`
- `_rawStatusFromGeoJson(...)` con deteccion por llave normalizada y prefijo `estatus`
**Tiempo estimado**: 20 min
**Riesgo**: Bajo

### Fase 2: Normalizacion robusta de valores
**Descripcion**: ampliar clasificacion de textos para mapear a Liberado/No liberado/Sin estatus.
**Archivo afectado**: lib/features/mapa/presentation/mapa_screen.dart
**Codigo clave**:
- `_normalizeEstatusText(...)`
- Soporte para `si/sí/no`, `no firmado`, `no autorizado`, `pendiente`, `en proceso`, `sin dato`, `n/a`
**Tiempo estimado**: 20 min
**Riesgo**: Bajo

### Fase 3: Aplicacion en app desktop
**Descripcion**: ejecutar la version de escritorio actualizada para validacion manual.
**Archivos afectados**: N/A (ejecucion)
**Tiempo estimado**: 10 min
**Riesgo**: Bajo

## Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|------|------------------|--------|
| Normalizacion de llaves | 20 min | Bajo |
| Normalizacion de valores | 20 min | Bajo |
| Ejecucion desktop | 10 min | Bajo |

## Criterio de exito
- El campo estatus del GeoJSON se detecta aun con variaciones de formato.
- El relleno se pinta verde/rojo/gris segun corresponda.
- El comportamiento se refleja en la app de escritorio actualizada.

## Resultado / evidencia
- Sin errores de analisis en mapa_screen.dart luego de cambios.
- Normalizacion reforzada para llaves y valores de estatus.

## Proximo paso
Validar con un GeoJSON de muestra que incluya al menos estos casos:
- estatus = liberado
- estatus = no liberado
- estatus faltante o valor no reconocido
