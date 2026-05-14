import json
import hashlib
import re
import threading
from json import JSONDecodeError, JSONDecoder
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from uuid import uuid4

# Protege las lecturas/escrituras concurrentes del archivo JSON.
_store_lock = threading.Lock()

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Geoportal Backend API", version="1.0.0")

# CORS config for Flutter web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DATA_DIR = Path(__file__).resolve().parents[1] / "data"
DATA_FILE = DATA_DIR / "predios.json"
GIS_FILE = DATA_DIR / "gis_predios.json"
MUNICIPIOS_FILE = DATA_DIR / "municipios.geojson"
PROJECT_CODES = ("TQI", "TSNL", "TAP", "TQM")


def _ensure_store() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    if not DATA_FILE.exists():
        DATA_FILE.write_text("[]", encoding="utf-8")
    if not GIS_FILE.exists():
        GIS_FILE.write_text("[]", encoding="utf-8")
    if not MUNICIPIOS_FILE.exists():
        MUNICIPIOS_FILE.write_text('{"type":"FeatureCollection","features":[]}', encoding="utf-8")


def _read_store(store_file: Path) -> list[dict[str, Any]]:
    _ensure_store()
    raw = store_file.read_text(encoding="utf-8").strip() or "[]"
    try:
        data = json.loads(raw)
        if not isinstance(data, list):
            raise ValueError("El almacén de datos es inválido.")
        return [dict(item) for item in data if isinstance(item, dict)]
    except JSONDecodeError:
        decoder = JSONDecoder()
        index = 0
        recovered: list[dict[str, Any]] = []

        while index < len(raw):
            while index < len(raw) and raw[index].isspace():
                index += 1

            if index >= len(raw):
                break

            try:
                parsed, end_index = decoder.raw_decode(raw, index)
            except JSONDecodeError:
                break

            if isinstance(parsed, list):
                recovered.extend(dict(item) for item in parsed if isinstance(item, dict))
            elif isinstance(parsed, dict):
                recovered.append(dict(parsed))

            index = end_index

        if recovered:
            _write_store(store_file, recovered)
            return recovered

        raise ValueError("El almacén está dañado y no se pudo recuperar.")


def _write_store(store_file: Path, items: list[dict[str, Any]]) -> None:
    _ensure_store()
    temp_file = store_file.with_suffix(".tmp")
    temp_file.write_text(
        json.dumps(items, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    temp_file.replace(store_file)


def _read_predios() -> list[dict[str, Any]]:
    return _read_store(DATA_FILE)


def _write_predios(predios: list[dict[str, Any]]) -> None:
    _write_store(DATA_FILE, predios)


def _read_gis_predios() -> list[dict[str, Any]]:
    return _read_store(GIS_FILE)


def _write_gis_predios(items: list[dict[str, Any]]) -> None:
    _write_store(GIS_FILE, items)


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _as_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value != 0
    if isinstance(value, str):
        return value.strip().lower() in {"true", "1", "si", "sí", "yes"}
    return False


def _infer_project_from_text(value: str | None) -> str | None:
    text = str(value or "").strip().upper()
    if not text:
        return None

    for code in PROJECT_CODES:
        if re.search(rf"(^|[^A-Z0-9]){re.escape(code)}([^A-Z0-9]|$)", text):
            return code
        if code in text:
            return code

    return None


def _infer_project_from_clave(value: str | None) -> str | None:
    clave = str(value or "").strip().upper()
    if not clave:
        return None

    compact = re.sub(r"[^A-Z0-9]", "", clave)

    if compact.startswith(("TQI", "QI")):
        return "TQI"
    if compact.startswith(("TSNL", "SNL", "SL")):
        return "TSNL"
    if compact.startswith(("TAP", "AP")):
        return "TAP"
    if compact.startswith(("TQM", "QM")):
        return "TQM"

    return None


def _infer_project(predio: dict[str, Any]) -> str | None:
    explicit = _infer_project_from_text(str(predio.get("proyecto") or ""))
    if explicit is not None:
        return explicit

    content = " ".join(
        [
            str(predio.get("proyecto") or ""),
            str(predio.get("clave_catastral") or ""),
            str(predio.get("ejido") or ""),
            str(predio.get("poligono_dwg") or ""),
            str(predio.get("oficio") or ""),
            str(predio.get("pdf_url") or ""),
            str(predio.get("cop_firmado") or ""),
        ]
    ).upper()

    from_content = _infer_project_from_text(content)
    if from_content is not None:
        return from_content

    clave = str(predio.get("clave_catastral") or "").strip().upper()
    from_clave = _infer_project_from_clave(clave)
    if from_clave is not None:
        return from_clave

    return None


def _normalize_predio(payload: dict[str, Any], existing: dict[str, Any] | None = None) -> dict[str, Any]:
    now = _now_iso()
    predio = dict(existing or {})

    for key, value in payload.items():
        if value is not None:
            predio[key] = value

    predio["id"] = str(predio.get("id") or uuid4())
    predio["clave_catastral"] = str(
        predio.get("clave_catastral") or predio.get("id_sedatu") or ""
    ).strip()
    predio["tramo"] = predio.get("tramo") or "T1"
    predio["tipo_propiedad"] = predio.get("tipo_propiedad") or "PRIVADA"
    pdf_url = str(predio.get("pdf_url") or predio.get("cop_firmado") or "").strip()
    predio["pdf_url"] = pdf_url or None
    cop_fecha = predio.get("cop_fecha")
    predio["cop_fecha"] = str(cop_fecha).strip() if cop_fecha else None
    if pdf_url and not str(predio.get("cop_firmado") or "").strip():
        predio["cop_firmado"] = pdf_url
    predio["cop"] = _as_bool(predio.get("cop"))
    predio["identificacion"] = _as_bool(predio.get("identificacion"))
    predio["levantamiento"] = _as_bool(predio.get("levantamiento"))
    predio["negociacion"] = _as_bool(predio.get("negociacion"))
    predio["poligono_insertado"] = _as_bool(predio.get("poligono_insertado"))
    inferred_project = _infer_project(predio)
    if inferred_project is not None:
        predio["proyecto"] = inferred_project
    predio["created_at"] = (
        existing.get("created_at")
        if existing is not None
        else predio.get("created_at") or now
    )
    predio["updated_at"] = now
    return predio


def _find_predio_or_404(predio_id: str) -> tuple[list[dict[str, Any]], int, dict[str, Any]]:
    predios = _read_predios()
    for index, predio in enumerate(predios):
        if str(predio.get("id")) == predio_id:
            return predios, index, predio
    raise HTTPException(status_code=404, detail="Predio no encontrado")


def _matches_project(predio: dict[str, Any], proyecto: str) -> bool:
    target = proyecto.strip().upper()
    effective_project = _infer_project(predio)
    return effective_project == target


def _matches_clave(predio: dict[str, Any], clave_catastral: str) -> bool:
    return str(predio.get("clave_catastral") or "").strip().upper() == clave_catastral.strip().upper()


def _clean_text(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _hash_feature_source(feature: dict[str, Any]) -> str:
    normalized = json.dumps(feature, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha1(normalized.encode("utf-8")).hexdigest()


def _extract_predio_keys(properties: dict[str, Any]) -> tuple[str | None, str | None]:
    predio_id = _clean_text(
        properties.get("predio_id")
        or properties.get("_predioId")
        or properties.get("predioId")
    )
    clave = _clean_text(
        properties.get("clave_catastral_db")
        or properties.get("_claveCatastral")
        or properties.get("clave_catastral")
        or properties.get("CLAVE_CATASTRAL")
        or properties.get("clave")
        or properties.get("CLAVE")
    )
    return predio_id, clave


def _derive_estatus(predio: dict[str, Any]) -> str:
    if _as_bool(predio.get("cop")):
        return "Liberado"
    if _as_bool(predio.get("identificacion")) or _as_bool(predio.get("levantamiento")) or _as_bool(predio.get("negociacion")):
        return "No liberado"
    return "Sin estatus"


def _normalize_estatus_item(predio: dict[str, Any]) -> dict[str, Any]:
    return {
        "predio_id": str(predio.get("id") or ""),
        "clave_catastral": str(predio.get("clave_catastral") or ""),
        "cop": _as_bool(predio.get("cop")),
        "identificacion": _as_bool(predio.get("identificacion")),
        "levantamiento": _as_bool(predio.get("levantamiento")),
        "negociacion": _as_bool(predio.get("negociacion")),
        "estatus": _derive_estatus(predio),
        "cops_tec_ref": predio.get("cops_tec_ref"),
        "updated_at": predio.get("updated_at"),
    }


def _iter_coordinate_pairs(value: Any):
    if isinstance(value, list):
        if len(value) >= 2 and isinstance(value[0], (int, float)) and isinstance(value[1], (int, float)):
            yield float(value[0]), float(value[1])
        else:
            for item in value:
                yield from _iter_coordinate_pairs(item)


def _geometry_bbox(geometry: dict[str, Any] | None) -> tuple[float, float, float, float] | None:
    if not isinstance(geometry, dict):
        return None

    coords = geometry.get("coordinates")
    if not isinstance(coords, list):
        return None

    min_x = None
    min_y = None
    max_x = None
    max_y = None

    for x, y in _iter_coordinate_pairs(coords):
        min_x = x if min_x is None else min(min_x, x)
        min_y = y if min_y is None else min(min_y, y)
        max_x = x if max_x is None else max(max_x, x)
        max_y = y if max_y is None else max(max_y, y)

    if min_x is None or min_y is None or max_x is None or max_y is None:
        return None

    return min_x, min_y, max_x, max_y


def _bboxes_intersect(
    a: tuple[float, float, float, float],
    b: tuple[float, float, float, float],
) -> bool:
    a_w, a_s, a_e, a_n = a
    b_w, b_s, b_e, b_n = b
    if a_e < b_w or b_e < a_w:
        return False
    if a_n < b_s or b_n < a_s:
        return False
    return True


def _read_municipios_features() -> list[dict[str, Any]]:
    _ensure_store()
    raw = MUNICIPIOS_FILE.read_text(encoding="utf-8").strip() or '{"type":"FeatureCollection","features":[]}'
    try:
        data = json.loads(raw)
    except JSONDecodeError as exc:
        raise HTTPException(status_code=500, detail=f"municipios.geojson invalido: {exc}")

    if isinstance(data, dict) and str(data.get("type")) == "FeatureCollection":
        features = data.get("features")
        if isinstance(features, list):
            return [dict(item) for item in features if isinstance(item, dict)]
    if isinstance(data, list):
        return [dict(item) for item in data if isinstance(item, dict)]
    return []


def _extract_municipio_name(properties: dict[str, Any]) -> str | None:
    for key in (
        "municipio",
        "MUNICIPIO",
        "nom_mun",
        "NOM_MUN",
        "shapeName",
        "SHAPENAME",
        "nombre",
        "NOMBRE",
        "name",
        "NAME",
    ):
        value = _clean_text(properties.get(key))
        if value:
            return value
    return None


def _point_in_ring(x: float, y: float, ring: list[Any]) -> bool:
    inside = False
    n = len(ring)
    if n < 3:
        return False

    j = n - 1
    for i in range(n):
        pi = ring[i]
        pj = ring[j]
        if not (
            isinstance(pi, list)
            and isinstance(pj, list)
            and len(pi) >= 2
            and len(pj) >= 2
            and isinstance(pi[0], (int, float))
            and isinstance(pi[1], (int, float))
            and isinstance(pj[0], (int, float))
            and isinstance(pj[1], (int, float))
        ):
            j = i
            continue

        xi, yi = float(pi[0]), float(pi[1])
        xj, yj = float(pj[0]), float(pj[1])
        intersects = ((yi > y) != (yj > y)) and (
            x < (xj - xi) * (y - yi) / ((yj - yi) or 1e-12) + xi
        )
        if intersects:
            inside = not inside
        j = i

    return inside


def _point_in_geometry(x: float, y: float, geometry: dict[str, Any]) -> bool:
    geo_type = str(geometry.get("type") or "")
    coords = geometry.get("coordinates")
    if not isinstance(coords, list):
        return False

    if geo_type == "Polygon":
        if not coords:
            return False
        outer = coords[0] if isinstance(coords[0], list) else []
        if not _point_in_ring(x, y, outer):
            return False
        holes = coords[1:] if len(coords) > 1 else []
        for hole in holes:
            if isinstance(hole, list) and _point_in_ring(x, y, hole):
                return False
        return True

    if geo_type == "MultiPolygon":
        for polygon in coords:
            if not isinstance(polygon, list) or not polygon:
                continue
            outer = polygon[0] if isinstance(polygon[0], list) else []
            if not _point_in_ring(x, y, outer):
                continue
            holes = polygon[1:] if len(polygon) > 1 else []
            in_hole = False
            for hole in holes:
                if isinstance(hole, list) and _point_in_ring(x, y, hole):
                    in_hole = True
                    break
            if not in_hole:
                return True
        return False

    return False


def _geometry_center_latlng(geometry: dict[str, Any] | None) -> tuple[float, float] | None:
    if not isinstance(geometry, dict):
        return None
    bbox = _geometry_bbox(geometry)
    if bbox is None:
        return None
    min_x, min_y, max_x, max_y = bbox
    center_lng = (min_x + max_x) / 2
    center_lat = (min_y + max_y) / 2
    return center_lat, center_lng


def _find_municipio_for_point(lat: float, lng: float, features: list[dict[str, Any]]) -> tuple[str, str | None] | None:
    for feature in features:
        geometry = feature.get("geometry")
        if not isinstance(geometry, dict):
            continue
        props = feature.get("properties")
        properties = dict(props) if isinstance(props, dict) else {}
        municipio = _extract_municipio_name(properties)
        if not municipio:
            continue
        if _point_in_geometry(lng, lat, geometry):
            estado = _clean_text(
                properties.get("estado")
                or properties.get("ESTADO")
                or properties.get("nom_ent")
                or properties.get("NOM_ENT")
            )
            return municipio, estado
    return None

@app.get("/")
def root():
    return {"message": "Geoportal Backend API running"}


@app.get("/gis/predios")
def list_gis_predios():
    items = _read_gis_predios()
    items.sort(key=lambda item: str(item.get("updated_at") or ""), reverse=True)
    return items


@app.get("/municipios")
def list_municipios():
    features = _read_municipios_features()
    output: list[dict[str, Any]] = []
    for feature in features:
        geometry = feature.get("geometry")
        if not isinstance(geometry, dict):
            continue
        props = feature.get("properties")
        properties = dict(props) if isinstance(props, dict) else {}
        nombre = _extract_municipio_name(properties)
        if not nombre:
            continue
        output.append(
            {
                "id": _clean_text(feature.get("id")) or _clean_text(properties.get("id")) or nombre,
                "nombre": nombre,
                "estado": _clean_text(
                    properties.get("estado")
                    or properties.get("ESTADO")
                    or properties.get("nom_ent")
                    or properties.get("NOM_ENT")
                ),
                "geometry": geometry,
            }
        )
    return output


@app.post("/predios/autofill-municipio")
def autofill_municipio(overwrite: bool = Query(default=False)):
    with _store_lock:
        municipios = _read_municipios_features()
        if not municipios:
            raise HTTPException(
                status_code=400,
                detail="No hay limites municipales. Agrega backend/data/municipios.geojson",
            )

        predios = _read_predios()
        updated = 0
        scanned = 0
        unresolved = 0

        for predio in predios:
            scanned += 1
            if not overwrite and _clean_text(predio.get("municipio")):
                continue

            lat_lng = _geometry_center_latlng(predio.get("geometry"))
            if lat_lng is None:
                lat = predio.get("latitud")
                lng = predio.get("longitud")
                if isinstance(lat, (int, float)) and isinstance(lng, (int, float)):
                    lat_lng = float(lat), float(lng)

            if lat_lng is None:
                unresolved += 1
                continue

            lat, lng = lat_lng
            hit = _find_municipio_for_point(lat, lng, municipios)
            if hit is None:
                unresolved += 1
                continue

            municipio, estado = hit
            before = _clean_text(predio.get("municipio"))
            predio["municipio"] = municipio
            if estado:
                predio["estado"] = estado
            predio["updated_at"] = _now_iso()
            if before != municipio:
                updated += 1

        if updated > 0:
            _write_predios(predios)

    return {
        "updated": updated,
        "scanned": scanned,
        "unresolved": unresolved,
        "overwrite": overwrite,
    }


@app.post("/gis/import-geojson")
def import_geojson_to_gis(payload: dict[str, Any]):
    features = payload.get("features")
    if not isinstance(features, list):
        raise HTTPException(status_code=400, detail="features debe ser una lista de GeoJSON features")

    archivo_id = _clean_text(payload.get("archivo_id"))
    proyecto = _clean_text(payload.get("proyecto"))
    now = _now_iso()

    created = 0
    updated = 0
    errors: list[dict[str, Any]] = []

    with _store_lock:
        existing = _read_gis_predios()
        by_predio_id: dict[str, int] = {
            str(item.get("predio_id")): idx
            for idx, item in enumerate(existing)
            if _clean_text(item.get("predio_id")) is not None
        }

        for index, raw_feature in enumerate(features):
            if not isinstance(raw_feature, dict):
                errors.append({"index": index, "error": "feature inválido"})
                continue

            geometry = raw_feature.get("geometry")
            if not isinstance(geometry, dict):
                errors.append({"index": index, "error": "geometry ausente o inválida"})
                continue

            props_raw = raw_feature.get("properties")
            properties = dict(props_raw) if isinstance(props_raw, dict) else {}
            predio_id, clave = _extract_predio_keys(properties)

            if predio_id is None and clave is None:
                errors.append({
                    "index": index,
                    "error": "sin predio_id/clave_catastral para relación con estatus",
                })
                continue

            if predio_id is None and clave is not None:
                predio_id = f"clave:{clave.upper()}"

            assert predio_id is not None

            item = {
                "predio_id": predio_id,
                "clave_catastral": clave,
                "archivo_id": archivo_id or _clean_text(properties.get("archivo_id")),
                "proyecto": proyecto or _clean_text(properties.get("proyecto")),
                "tramo": _clean_text(properties.get("tramo")),
                "geometry": geometry,
                "source_hash": _hash_feature_source(raw_feature),
                "updated_at": now,
            }

            if predio_id in by_predio_id:
                current_idx = by_predio_id[predio_id]
                existing_item = existing[current_idx]
                item["created_at"] = existing_item.get("created_at") or now
                existing[current_idx] = item
                updated += 1
            else:
                item["created_at"] = now
                by_predio_id[predio_id] = len(existing)
                existing.append(item)
                created += 1

        _write_gis_predios(existing)

    return {
        "total": len(features),
        "insertados": created,
        "actualizados": updated,
        "errores": len(errors),
        "error_items": errors,
    }


@app.get("/gestion/estatus")
def get_estatus(
    predio_ids: str | None = Query(default=None),
    claves_catastrales: str | None = Query(default=None),
):
    predio_ids_set = {
        item.strip()
        for item in str(predio_ids or "").split(",")
        if item.strip()
    }
    claves_set = {
        item.strip().upper()
        for item in str(claves_catastrales or "").split(",")
        if item.strip()
    }

    predios = _read_predios()
    items = []
    for predio in predios:
        pid = str(predio.get("id") or "")
        clave = str(predio.get("clave_catastral") or "").strip().upper()

        if predio_ids_set and pid in predio_ids_set:
            items.append(_normalize_estatus_item(predio))
            continue
        if claves_set and clave in claves_set:
            items.append(_normalize_estatus_item(predio))

    return {"items": items}


@app.post("/gestion/estatus/batch")
def get_estatus_batch(payload: dict[str, Any]):
    predio_ids = payload.get("predio_ids")
    claves = payload.get("claves_catastrales")

    predio_ids_set = {
        str(item).strip()
        for item in (predio_ids if isinstance(predio_ids, list) else [])
        if str(item).strip()
    }
    claves_set = {
        str(item).strip().upper()
        for item in (claves if isinstance(claves, list) else [])
        if str(item).strip()
    }

    predios = _read_predios()
    items = []
    for predio in predios:
        pid = str(predio.get("id") or "")
        clave = str(predio.get("clave_catastral") or "").strip().upper()

        if predio_ids_set and pid in predio_ids_set:
            items.append(_normalize_estatus_item(predio))
            continue
        if claves_set and clave in claves_set:
            items.append(_normalize_estatus_item(predio))

    return {"items": items}


@app.post("/gestion/estatus/viewport")
def get_estatus_viewport(payload: dict[str, Any]):
    bbox_raw = payload.get("bbox")
    if not isinstance(bbox_raw, dict):
        raise HTTPException(status_code=400, detail="bbox es requerido")

    try:
        viewport_bbox = (
            float(bbox_raw.get("west")),
            float(bbox_raw.get("south")),
            float(bbox_raw.get("east")),
            float(bbox_raw.get("north")),
        )
    except (TypeError, ValueError):
        raise HTTPException(status_code=400, detail="bbox inválido")

    proyecto = _clean_text(payload.get("proyecto"))
    limit_raw = payload.get("limit")
    limit = 5000
    if isinstance(limit_raw, int) and limit_raw > 0:
        limit = min(limit_raw, 20000)

    predios = _read_predios()
    by_predio_id = {str(item.get("id") or ""): item for item in predios}
    by_clave = {
        str(item.get("clave_catastral") or "").strip().upper(): item
        for item in predios
        if str(item.get("clave_catastral") or "").strip()
    }

    gis_items = _read_gis_predios()
    output = []
    for gis_item in gis_items:
        if len(output) >= limit:
            break

        if proyecto and str(gis_item.get("proyecto") or "").strip().upper() != proyecto.upper():
            continue

        geom_bbox = _geometry_bbox(gis_item.get("geometry"))
        if geom_bbox is None or not _bboxes_intersect(geom_bbox, viewport_bbox):
            continue

        predio_id = str(gis_item.get("predio_id") or "").strip()
        clave = str(gis_item.get("clave_catastral") or "").strip().upper()

        predio = by_predio_id.get(predio_id)
        if predio is None and clave:
            predio = by_clave.get(clave)

        if predio is None:
            output.append(
                {
                    "predio_id": predio_id,
                    "clave_catastral": clave,
                    "cop": False,
                    "identificacion": False,
                    "levantamiento": False,
                    "negociacion": False,
                    "estatus": "Sin estatus",
                    "cops_tec_ref": None,
                    "updated_at": gis_item.get("updated_at"),
                }
            )
            continue

        output.append(_normalize_estatus_item(predio))

    return {
        "items": output,
        "count": len(output),
    }

@app.get("/predios")
def list_predios(
    proyecto: str | None = Query(default=None),
    clave_catastral: str | None = Query(default=None),
):
    predios = _read_predios()

    if proyecto:
        predios = [p for p in predios if _matches_project(p, proyecto)]

    if clave_catastral:
        predios = [p for p in predios if _matches_clave(p, clave_catastral)]

    predios.sort(key=lambda item: str(item.get("created_at") or ""), reverse=True)
    return predios


@app.get("/predios/estadisticas")
def get_estadisticas():
    predios = _read_predios()
    conteo: dict[str, int] = {}
    superficie_total = 0.0

    for predio in predios:
        uso = str(predio.get("tipo_propiedad") or "Sin tipo")
        conteo[uso] = (conteo.get(uso) or 0) + 1

        superficie = predio.get("superficie")
        if isinstance(superficie, (int, float)):
            superficie_total += float(superficie)

    return {
        "total": len(predios),
        "por_uso_suelo": conteo,
        "superficie_total": superficie_total,
    }


@app.get("/predios/by-clave/{clave_catastral}")
def get_predio_by_clave(clave_catastral: str):
    predios = _read_predios()
    for predio in predios:
        if _matches_clave(predio, clave_catastral):
            return predio
    raise HTTPException(status_code=404, detail="Predio no encontrado")

@app.get("/predios/{predio_id}")
def get_predio(predio_id: str):
    _, _, predio = _find_predio_or_404(predio_id)
    return predio

@app.post("/predios")
def create_predio(predio: dict):
    with _store_lock:
        predios = _read_predios()
        normalized = _normalize_predio(predio)

        replaced = False
        for index, existing in enumerate(predios):
            if str(existing.get("id")) == normalized["id"]:
                predios[index] = _normalize_predio(normalized, existing)
                normalized = predios[index]
                replaced = True
                break

        if not replaced:
            predios.append(normalized)

        _write_predios(predios)
    return normalized


@app.post("/predios/batch")
def create_predios_batch(items: list[dict]):
    """Inserta o actualiza múltiples predios en una sola escritura atómica."""
    with _store_lock:
        predios = _read_predios()
        existing_index = {str(p.get("id")): i for i, p in enumerate(predios)}
        results = []
        for predio in items:
            normalized = _normalize_predio(predio)
            pid = normalized["id"]
            if pid in existing_index:
                idx = existing_index[pid]
                merged = _normalize_predio(normalized, predios[idx])
                predios[idx] = merged
                results.append(merged)
            else:
                predios.append(normalized)
                existing_index[pid] = len(predios) - 1
                results.append(normalized)
        _write_predios(predios)
    return results

@app.put("/predios/{predio_id}")
def update_predio(predio_id: str, predio: dict):
    with _store_lock:
        predios, index, existing = _find_predio_or_404(predio_id)
        payload = dict(predio)
        payload["id"] = predio_id
        normalized = _normalize_predio(payload, existing)
        predios[index] = normalized
        _write_predios(predios)
    return normalized

@app.delete("/predios/{predio_id}")
def delete_predio(predio_id: str):
    with _store_lock:
        predios, index, _ = _find_predio_or_404(predio_id)
        predios.pop(index)
        _write_predios(predios)
    return {"deleted": True, "id": predio_id}
