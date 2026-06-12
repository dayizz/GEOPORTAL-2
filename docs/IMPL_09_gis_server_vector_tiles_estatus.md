# IMPL 09 - Servidor GIS + estatus COP/TEC (vector tiles)

## 1. Objetivo

Optimizar la carga del mapa moviendo la geometria pesada a un servidor GIS, manteniendo el estatus de gestion (COP/TEC) como fuente de verdad en la base de datos transaccional.

Resultado esperado:
- Geometria servida como tiles vectoriales (MVT) por zoom.
- Estatus actualizado desde BD sin reprocesar GeoJSON completo.
- Relacion estable entre feature geoespacial y registro de gestion.

## 2. Principio de integracion

Separar responsabilidades:
- GIS: almacena y sirve geometria (predios) optimizada para render.
- BD de gestion: almacena estatus operativo (cop, identificacion, levantamiento, negociacion, estatus derivado).

Llaves de union obligatorias:
- Llave primaria: predio_id.
- Llave secundaria: clave_catastral.
- Llave de trazabilidad de importacion: archivo_id.

## 3. Pieza 1 - Esquema de datos recomendado

## 3.1 Capa GIS (PostGIS)

Tabla para geometria de predios:

```sql
create table if not exists gis_predios (
  predio_id text primary key,
  clave_catastral text,
  archivo_id text,
  proyecto text,
  tramo text,
  geom geometry(MultiPolygon, 4326) not null,
  source_hash text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_gis_predios_geom
  on gis_predios using gist (geom);

create index if not exists idx_gis_predios_clave
  on gis_predios (clave_catastral);

create index if not exists idx_gis_predios_archivo
  on gis_predios (archivo_id);
```

Recomendaciones:
- Convertir Polygon a MultiPolygon al persistir (consistencia).
- Mantener source_hash para upsert idempotente de carga GeoJSON.
- Validar geometria antes de guardar (ST_IsValid).

## 3.2 Estado de gestion (tabla transaccional)

Si ya existe tabla predios, solo asegurar campos y llaves. Si se separa la vista operacional:

```sql
create table if not exists predios_estatus_operativo (
  predio_id text primary key,
  clave_catastral text,
  cop boolean not null default false,
  identificacion boolean not null default false,
  levantamiento boolean not null default false,
  negociacion boolean not null default false,
  estatus text not null default 'Sin estatus',
  cops_tec_ref text,
  updated_at timestamptz default now()
);

create index if not exists idx_estatus_clave
  on predios_estatus_operativo (clave_catastral);
```

## 3.3 Vista unificada para consumo rapido

```sql
create or replace view vw_mapa_predios as
select
  g.predio_id,
  g.clave_catastral,
  g.archivo_id,
  g.proyecto,
  g.tramo,
  e.cop,
  e.identificacion,
  e.levantamiento,
  e.negociacion,
  e.estatus,
  e.updated_at as estatus_updated_at,
  g.geom
from gis_predios g
left join predios_estatus_operativo e
  on e.predio_id = g.predio_id;
```

## 4. Pieza 2 - Endpoints backend

## 4.1 Ingesta GeoJSON al GIS

POST /api/gis/import-geojson
- Input: FeatureCollection + metadata (archivo_id, proyecto).
- Proceso:
  1) normaliza feature y extrae predio_id/clave_catastral.
  2) valida geometria.
  3) upsert en gis_predios.
- Output: total, insertados, actualizados, errores.

Contrato sugerido:

```json
{
  "archivo_id": "imp_20260508_001",
  "proyecto": "TQI",
  "features": []
}
```

## 4.2 Servicio de tiles vectoriales

Opciones:
- Opcion A: pg_tileserv sobre PostGIS (rapido de desplegar).
- Opcion B: GeoServer con publicacion de layer MVT.

Endpoint ejemplo:
- GET /tiles/gis_predios/{z}/{x}/{y}.pbf

Campos minimos en cada feature de tile:
- predio_id
- clave_catastral
- archivo_id
- proyecto
- tramo

## 4.3 API de estatus por lote (capa ligera)

GET /api/gestion/estatus?predio_ids=... o POST batch

Respuesta sugerida:

```json
{
  "items": [
    {
      "predio_id": "p_001",
      "cop": true,
      "identificacion": true,
      "levantamiento": true,
      "negociacion": false,
      "estatus": "Liberado",
      "updated_at": "2026-05-08T19:20:00Z"
    }
  ]
}
```

## 4.4 API opcional por viewport

POST /api/gestion/estatus/viewport
- Input: bbox + zoom + filtros de proyecto.
- Output: estatus de predios visibles.

Ventaja:
- evita pedir estatus de todo el universo cuando el usuario ve un area limitada.

## 5. Pieza 3 - Adaptacion Flutter

## 5.1 Dependencia y capa de mapa

Agregar soporte de vector tiles en flutter_map:
- paquete sugerido: flutter_map_vector_tile

Estrategia de render:
- Capa base: igual que hoy (OSM/satelital).
- Capa predios: vector tile del GIS.
- Estilo/color: determinado por mapa de estatus recibido desde API de gestion.

## 5.2 Contrato de union en cliente

Union por predio_id:
- Feature tile trae predio_id.
- Provider de estatus mantiene Map<predio_id, EstatusPredio>.
- Color final del feature se calcula con esa entidad.

Fallback:
- Si no hay estatus para predio_id:
  - usar Sin estatus.
  - no bloquear render del tile.

## 5.3 Providers recomendados

- gisTilesConfigProvider: URL y token del tile server.
- estatusByPredioProvider: cache reactiva de estatus.
- estatusViewportProvider: fetch por viewport (bbox/zoom) con debounce.

Regla de cache:
- TTL corto (15 a 60 segundos) para estatus.
- invalidacion por cambios de gestion o importacion completada.

## 5.4 Compatibilidad con flujo actual de importacion

Cuando se importa GeoJSON:
1) se sincroniza gestion (como hoy).
2) se publica geometria en GIS (nuevo paso).
3) se refresca estatus local y mapa.

No se pierde el estado actual de la app:
- importedFeaturesProvider puede quedar como fallback local.
- la vista principal de mapa debe preferir tiles GIS cuando esten disponibles.

## 6. Integracion con COPS TEC

Si COPS TEC alimenta estatus:
- mantener tabla puente o proceso ETL hacia predios_estatus_operativo.
- actualizar por predio_id o clave_catastral.
- recalcular estatus derivado con regla unica:
  - cop = true -> Liberado
  - si no, y hay identificacion/levantamiento/negociacion -> No liberado
  - en otro caso -> Sin estatus

Para trazabilidad:
- guardar cops_tec_ref y updated_at origen.

## 7. Seguridad y gobernanza

- Proteger endpoints de ingesta (auth + roles).
- Limitar upload por tamano y numero de features.
- Registrar auditoria de importacion (archivo_id, usuario, fecha, resultado).
- Mantener versionado de geometria si aplica (historial por archivo_id).

## 8. Plan de adopcion por fases

Fase A (MVP tecnico)
- Levantar PostGIS + pg_tileserv.
- Publicar capa gis_predios en tiles.
- Consumir tiles en una rama de mapa sin quitar flujo actual.

Fase B (union de estatus)
- Exponer endpoint batch de estatus.
- Pintar tiles por estatus COP/TEC en Flutter.
- Validar consistencia con Gestion y Tabla.

Fase C (produccion)
- Ingesta automatica desde importacion GeoJSON.
- Cache por viewport + invalidacion por eventos.
- Monitoreo de latencia de tiles y estatus.

## 9. KPIs de exito

- Tiempo de primera pintura de mapa < 2 s (dataset grande).
- Tiempo de refresco de estatus visible < 500 ms.
- Diferencia de estatus entre Gestion y Mapa = 0 registros.
- Reapertura de app sin perdida de estado visual.

## 10. Riesgos y mitigaciones

Riesgo: claves inconsistentes entre GIS y gestion.
Mitigacion: validar predio_id obligatorio en ingesta; fallback por clave_catastral.

Riesgo: latencia alta de endpoint de estatus.
Mitigacion: batch por viewport + cache TTL + compresion.

Riesgo: desalineacion temporal entre geometria y estatus.
Mitigacion: invalidar cache tras importacion y tras cambios de gestion.

## 11. Estado implementado en backend local

Implementado en esta fase (FastAPI local):
- POST /gis/import-geojson (ingesta GeoJSON con upsert por predio_id y persistencia local).
- GET /gis/predios (consulta de capa GIS local persistida).
- GET /gestion/estatus (consulta de estatus por predio_ids o claves_catastrales).
- POST /gestion/estatus/batch (consulta batch de estatus para union en mapa).
- POST /gestion/estatus/viewport (consulta de estatus por bounding box usando capa GIS local).

Implementado en Flutter (mapa):
- Sincronización de estatus por viewport visible con debounce durante movimiento/zoom.
- Fallback automático a consulta batch cuando el endpoint viewport no responde.
- Priorización del estatus remoto (COP/TEC) para color de polígonos importados, manteniendo fallback local por properties.

Notas:
- La capa GIS en esta fase usa almacenamiento JSON local (`backend/data/gis_predios.json`) para pruebas funcionales.
- El siguiente salto a produccion es reemplazar almacenamiento local por PostGIS + servicio de vector tiles (pg_tileserv o GeoServer) manteniendo el mismo contrato de union por predio_id.
