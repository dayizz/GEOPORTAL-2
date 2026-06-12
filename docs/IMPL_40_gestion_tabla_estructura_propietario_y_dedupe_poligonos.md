# IMPL_40: Ajustes de Gestion (tabla/filtros) y deduplicacion visual de poligonos

- Estado: Implementado
- Fecha: 26 de mayo de 2026
- Rama: desktop/fase-1

## 1. Objetivo
Aplicar ajustes operativos solicitados en Gestion y Mapa:
- Evitar doble relleno visual cuando existan poligonos importados duplicados.
- Ajustar columnas de la tabla de Gestion (eliminar km efectivos, agregar estructura y propietario, renombrar situacion social a observaciones).
- Mostrar estado/municipio con formato compacto estado/municipio.
- Actualizar estilo del recuadro de filtros a gris claro y quitar borde de botones/chips de filtro.
- Asegurar que estructura y propietario se rellenen desde propiedades GeoJSON.

## 2. Diagnostico / contexto actual
- La capa importada podia dibujar poligonos repetidos, lo cual oscurecia algunos predios por superposicion.
- La tabla de Gestion no tenia columna de estructura ni propietario visible en el grid principal.
- La columna de km efectivos seguia visible aunque ya no era requerida en el tablero.
- Para importaciones locales faltaba mapear estado/municipio en el modelo de predio local.

## 3. Fases
### Fase 1: Deduplicacion de poligonos importados en render de mapa
- Descripcion:
  - Se agrego una firma geometrica por anillo/poligono para detectar duplicados y omitir su render.
  - Solo afecta el pintado de capas importadas, sin alterar datos fuente.
- Archivos afectados:
  - lib/features/mapa/presentation/mapa_screen.dart
- Codigo clave:
  - _buildImportedLayerData(...)
  - _polygonRingsSignature(...)
  - _ringSignature(...)
- Tiempo estimado: 30 min
- Riesgo: Medio (precision de firma en coordenadas redondeadas)

### Fase 2: Ajustes de tabla Gestion
- Descripcion:
  - Se elimino la columna KM EF.
  - Se agregaron columnas ESTRUCTURA y PROPIETARIO.
  - Se mantuvo/ajusto el encabezado OBSERVACIONES para situacion social.
  - Se formato estado y municipio como estado/municipio.
- Archivos afectados:
  - lib/features/tabla/presentation/tabla_screen.dart
- Codigo clave:
  - _buildTable(...)
  - _buildDataRow(...)
- Tiempo estimado: 35 min
- Riesgo: Bajo

### Fase 3: Ajustes visuales del panel de filtros
- Descripcion:
  - Se aplico fondo gris claro al recuadro del modal de filtros.
  - Se removio borde en chips/botones de filtro.
- Archivos afectados:
  - lib/features/tabla/presentation/tabla_screen.dart
- Codigo clave:
  - _showFiltros(...)
- Tiempo estimado: 15 min
- Riesgo: Bajo

### Fase 4: Mapeo de estructura/ubicacion desde GeoJSON
- Descripcion:
  - Se agrego soporte canonico para estructura en normalizacion de propiedades.
  - Se persistio estructura en creacion/actualizacion de predios por sincronizacion.
  - Se incorporo estructura, estado y municipio al flujo local de importacion para que aparezcan en Gestion.
  - Se amplio el modelo Predio para leer/mostrar estructura.
- Archivos afectados:
  - lib/features/carga/utils/geojson_mapper.dart
  - lib/features/carga/services/sincronizacion_service.dart
  - lib/features/predios/providers/local_predios_provider.dart
  - lib/features/predios/models/predio.dart
- Codigo clave:
  - GeoJsonMapper._keyAliases['estructura']
  - _buildNuevoPredioData(...)
  - _buildGestionUpdateData(...)
  - Predio.estructura
- Tiempo estimado: 35 min
- Riesgo: Medio (dependencia de columna estructura en backend)

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Deduplicacion visual de poligonos | 30 min | Medio |
| Ajustes de tabla Gestion | 35 min | Bajo |
| Estilo del panel de filtros | 15 min | Bajo |
| Mapeo de estructura/ubicacion GeoJSON | 35 min | Medio |
| Total | 115 min | Medio |

## 5. Criterio de exito
- No se aprecia doble relleno en predios con geometrias importadas duplicadas.
- La tabla de Gestion ya no muestra KM EF.
- La tabla de Gestion muestra ESTRUCTURA y PROPIETARIO con datos del predio.
- La celda de ubicacion muestra estado/municipio.
- El panel de filtros se visualiza con fondo gris claro y sin borde en chips de filtro.

## 6. Resultado / evidencia
- Validacion estatica sin errores en los archivos modificados con get_errors.
- Cambios aplicados en mapa, tabla, normalizador GeoJSON, sincronizacion y modelo local/remoto.

## 7. Proximo paso
1. Probar en UI un GeoJSON con duplicados exactos para confirmar que solo se pinta una capa.
2. Validar en entorno remoto que la tabla predios tenga columna estructura para persistencia completa.
3. Ejecutar prueba funcional de filtros y de columnas nuevas en Gestion (desktop y web).
