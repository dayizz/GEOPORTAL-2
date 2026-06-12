# IMPL_62 Estrella De 8 Puntas Para Puntos Cardinales En Mapa

- Estado: Implementado
- Fecha: 2026-06-12
- Rama: desktop/fase-1

## 1. Objetivo
Representar los 4 puntos cardinales mediante una estrella de 8 puntas y colocarla en la parte inferior derecha del mapa.

## 2. Diagnostico / Contexto Actual
La implementación previa mostraba una rosa de los vientos basada en cruz simple ubicada en la zona superior derecha. Se requirió una representación visual de 8 puntas y cambio de posición hacia la esquina inferior derecha.

## 3. Fases

### Fase 1 - Reubicación Del Overlay
- Descripcion: Se movió el overlay del control cardinal a la esquina inferior derecha.
- Archivos afectados: `lib/features/mapa/presentation/mapa_screen.dart`
- Codigo clave: `Positioned(bottom: ..., right: 16, child: _buildCompassRose())`
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 2 - Construcción De Estrella De 8 Puntas
- Descripcion: Se reemplazó la cruz anterior por una estrella de 8 radios (4 principales + 4 diagonales), conservando etiquetas N/S/E/O.
- Archivos afectados: `lib/features/mapa/presentation/mapa_screen.dart`
- Codigo clave: `List.generate(8, ...)` con rotación angular de `pi/4`
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 3 - Ajuste De Separación Con Tarjeta De Predio
- Descripcion: Se añadió offset dinámico en `bottom` cuando hay predio seleccionado para evitar traslape con la tarjeta inferior.
- Archivos afectados: `lib/features/mapa/presentation/mapa_screen.dart`
- Codigo clave: `bottom: _selectedPredio != null ? 166 : 16`
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen De Esfuerzo

| Fase | Tiempo estimado | Riesgo |
|---|---:|---|
| Reubicación del overlay | 10 min | Bajo |
| Estrella de 8 puntas | 20 min | Bajo |
| Ajuste por tarjeta de predio | 10 min | Bajo |
| **Total** | **40 min** | **Bajo** |

## 5. Criterio De Exito
- La visual cardinal aparece en la parte inferior derecha del mapa.
- La figura base es una estrella de 8 puntas.
- Las etiquetas N/S/E/O permanecen visibles y legibles.
- No hay traslape con la tarjeta de detalle cuando se selecciona un predio.

## 6. Resultado / Evidencia
- Se actualizó el widget `_buildCompassRose` para usar 8 radios con jerarquía visual entre puntas principales y diagonales.
- Se reubicó el `Positioned` del overlay a esquina inferior derecha con offset dinámico.
- Se reemplazó la representación por una estrella geométrica de 8 puntas dibujada con `CustomPainter`.
- Se eliminó el recuadro/fondo blanco contenedor para dejar solo la estrella con los cardinales.
- Se refinó el estilo a variante náutica: puntas cardinales más largas, diagonales más cortas y contraste visual por secciones.
- Se incrementó tamaño y margen inferior/derecho para mejorar legibilidad y evitar recorte visual.

## 7. Proximo Paso
Validar en desktop y web que la nueva posición se mantenga correcta en resoluciones pequeñas y ajustar `bottom` si cambia el alto de la tarjeta inferior.