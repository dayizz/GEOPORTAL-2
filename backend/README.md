# Geoportal Backend (FastAPI)

Este backend provee una API RESTful para la gestión de predios y recursos del Geoportal. Está diseñado para integrarse fácilmente con el frontend Flutter.

## Instalación y ejecución

1. Crea un entorno virtual:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```
2. Instala dependencias:
   ```bash
   pip install fastapi uvicorn
   ```
3. Ejecuta el servidor:
   ```bash
   uvicorn app.main:app --reload
   ```
   El backend estará disponible en http://localhost:8000

## Endpoints principales

- `GET /` — Prueba de vida
- `GET /predios` — Lista todos los predios
- `GET /predios/{predio_id}` — Detalle de un predio
- `POST /predios` — Crear un predio
- `POST /predios/batch` — Inserta/actualiza múltiples predios
- `PUT /predios/{predio_id}` — Actualizar un predio
- `DELETE /predios/{predio_id}` — Eliminar un predio

## Endpoints GIS (base local)

- `GET /gis/predios` — Lista capa GIS local persistida
- `POST /gis/import-geojson` — Importa features GeoJSON a capa GIS local (upsert por `predio_id`)

Contrato mínimo para `POST /gis/import-geojson`:

```json
{
   "archivo_id": "imp_20260508_001",
   "proyecto": "TQI",
   "features": [
      {
         "type": "Feature",
         "geometry": { "type": "Polygon", "coordinates": [] },
         "properties": {
            "predio_id": "p_001",
            "clave_catastral": "ABC-001"
         }
      }
   ]
}
```

## Endpoints de estatus COP/TEC

- `GET /gestion/estatus?predio_ids=p_001,p_002`
- `GET /gestion/estatus?claves_catastrales=ABC-001,ABC-002`
- `POST /gestion/estatus/batch`
- `POST /gestion/estatus/viewport`

Contrato sugerido para batch:

```json
{
   "predio_ids": ["p_001", "p_002"],
   "claves_catastrales": ["ABC-001", "ABC-002"]
}
```

Respuesta:

```json
{
   "items": [
      {
         "predio_id": "p_001",
         "clave_catastral": "ABC-001",
         "cop": true,
         "identificacion": true,
         "levantamiento": true,
         "negociacion": false,
         "estatus": "Liberado",
         "cops_tec_ref": null,
         "updated_at": "2026-05-08T19:20:00Z"
      }
   ]
}
```

Contrato sugerido para viewport:

```json
{
   "bbox": {
      "west": -100.7,
      "south": 20.4,
      "east": -100.1,
      "north": 20.9
   },
   "proyecto": "TQI",
   "limit": 5000
}
```

## Integración Flutter

En tu app Flutter, usa la URL base `http://localhost:8000` para consumir la API. Ejemplo con `http`:

```dart
final response = await http.get(Uri.parse('http://localhost:8000/predios'));
```

Para producción, reemplaza la URL por la del servidor real.

---

Puedes extender los endpoints y modelos según las necesidades del proyecto.
