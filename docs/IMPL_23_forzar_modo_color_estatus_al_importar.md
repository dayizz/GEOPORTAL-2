# IMPL_23: Forzar modo de color por estatus al importar GeoJSON

**Estado**: Implementado
**Fecha**: 13 de mayo de 2026
**Rama**: desktop/fase-1

## Objetivo
Asegurar que, después de importar un GeoJSON, el mapa use inmediatamente el modo de color por estatus para renderizar polígonos en verde, rojo o gris.

## Diagnóstico / contexto actual
Aunque el estatus del GeoJSON ya podía venir correctamente normalizado, el mapa podía seguir mostrando todos los polígonos en tonos no esperados si el usuario tenía activo otro modo de visualización, por ejemplo `tipoPropiedad`.

## Fases
### Fase 1: Forzar modo de color al cargar features importados
- Descripción: al asignar `importedFeaturesProvider`, cambiar `mapaColorModeProvider` a `MapaColorMode.estatusPredio`.
- Archivo afectado: lib/features/carga/presentation/carga_archivo_screen.dart
- Tiempo estimado: 10 min
- Riesgo: Bajo

## Resumen de esfuerzo
| Fase | Tiempo estimado | Riesgo |
|------|------------------|--------|
| Forzar modo estatus al importar | 10 min | Bajo |

## Criterio de éxito
- Después de importar un GeoJSON, el mapa entra automáticamente en modo de color por estatus.
- Los polígonos importados se colorean usando el estatus detectado del archivo.

## Resultado / evidencia
- Cambio aplicado sin errores de análisis.
- La importación ahora alinea datos y visualización automáticamente.

## Próximo paso
Reimportar el GeoJSON y verificar que el mapa muestre el modo por estatus sin intervención manual.
