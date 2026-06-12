# IMPL_25: Colores vibrantes de estatus en mapa y correccion de arranque macOS

**Estado**: Implementado
**Fecha**: 13 de mayo de 2026
**Rama**: desktop/fase-1

## Objetivo
Mejorar la diferenciacion visual entre poligonos por estatus en el mapa y resolver el bloqueo de ejecucion local en macOS.

## Diagnostico / contexto actual
Se detectaron dos problemas independientes:
- El verde, rojo y gris del mapa quedaban demasiado apagados por combinacion de paleta y opacidad baja.
- La app no arrancaba en macOS por dos causas distintas: una rotura estructural en `tabla_screen.dart` y luego un fallo de CodeSign por atributos extendidos del bundle.

## Fases
### Fase 1: Refuerzo visual de colores por estatus
**Archivo afectado**: lib/features/mapa/presentation/mapa_screen.dart
**Cambios**:
- `Liberado` ahora usa verde mas vibrante.
- `No liberado` ahora usa rojo mas vibrante.
- `Sin estatus` usa gris mas profundo.
- Se incremento la opacidad del relleno y del borde en poligonos persistidos, importados, capturados y en borrador.
**Tiempo estimado**: 20 min
**Riesgo**: Bajo

### Fase 2: Correccion de build roto en Gestion
**Archivo afectado**: lib/features/tabla/presentation/tabla_screen.dart
**Cambios**:
- Se corrigio un bloque OCR incrustado dentro de `_applyFilters(...)`.
- Se restauro el retorno correcto del filtro.
- Se recompusieron `_predioProyecto(...)`, `_conteoProyecto(...)` y `build(...)`.
**Tiempo estimado**: 20 min
**Riesgo**: Medio

### Fase 3: Correccion de firma local macOS
**Ambito afectado**: proyecto local / build macOS
**Cambios**:
- Limpieza de atributos extendidos con `xattr -cr .`.
- Rebuild de macOS debug exitoso.
**Tiempo estimado**: 10 min
**Riesgo**: Bajo

## Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|------|------------------|--------|
| Refuerzo visual de colores | 20 min | Bajo |
| Reparacion de `tabla_screen.dart` | 20 min | Medio |
| Limpieza CodeSign + rebuild | 10 min | Bajo |

## Criterio de exito
- El mapa distingue claramente verde, rojo y gris.
- La app vuelve a compilar en macOS.
- El bundle debug puede abrirse localmente.

## Resultado / evidencia
- `flutter analyze lib/features/mapa/presentation/mapa_screen.dart`: sin errores.
- `flutter analyze lib/features/tabla/presentation/tabla_screen.dart`: sin issues.
- `flutter build macos --debug`: exitoso.
- Bundle abierto desde `build/macos/Build/Products/Debug/geoportal_predios.app`.

## Proximo paso
Validar visualmente con el mismo GeoJSON que contenga mezcla de `Liberado`, `No liberado` y features sin estatus para confirmar que la nueva intensidad visual sea suficiente en operación real.
