import json
import hashlib
import re
import threading
from collections import Counter
from io import BytesIO
from json import JSONDecodeError, JSONDecoder
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from uuid import uuid4

# Protege las lecturas/escrituras concurrentes del archivo JSON.
_store_lock = threading.Lock()

from fastapi import FastAPI, HTTPException, Query, Response
from fastapi.middleware.cors import CORSMiddleware
from reportlab.graphics.charts.piecharts import Pie
from reportlab.graphics.shapes import Circle, Drawing, String
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.lib.utils import ImageReader
from reportlab.platypus import KeepTogether, PageBreak, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

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
REPORTES_FILE = DATA_DIR / "reportes.json"
REPORTE_MEMBRETE_CANDIDATES = (
    DATA_DIR / "reporte_membrete.png",
    DATA_DIR / "reporte_membrete.jpg",
    DATA_DIR / "reporte_membrete.jpeg",
)
REPORTE_FONT_DIR = DATA_DIR / "fonts"
PROJECT_CODES = ("TQI", "TSNL", "TAP", "TQM")


def _ensure_store() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    if not DATA_FILE.exists():
        DATA_FILE.write_text("[]", encoding="utf-8")
    if not GIS_FILE.exists():
        GIS_FILE.write_text("[]", encoding="utf-8")
    if not REPORTES_FILE.exists():
        REPORTES_FILE.write_text("[]", encoding="utf-8")
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


def _read_reportes() -> list[dict[str, Any]]:
    return _read_store(REPORTES_FILE)


def _write_reportes(items: list[dict[str, Any]]) -> None:
    _write_store(REPORTES_FILE, items)


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


def _read_bool_field(payload: dict[str, Any], keys: tuple[str, ...]) -> bool:
    for key in keys:
        value = payload.get(key)
        if value is None:
            continue
        text = str(value).strip()
        if not text or text.lower() == "null":
            continue
        return _as_bool(value)
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
    predio["cop"] = _read_bool_field(predio, ("cop", "_cop", "COP", "cop_firmado", "COP_FIRMADO"))
    predio["identificacion"] = _read_bool_field(
        predio,
        (
            "identificacion",
            "_identificacion",
            "IDENTIFICACION",
            "identificación",
            "IDENTIFICACIÓN",
            "acercamiento",
            "acercamiento_si",
            "id_realizada",
            "identificacion_si",
        ),
    )
    predio["levantamiento"] = _read_bool_field(
        predio,
        (
            "levantamiento",
            "_levantamiento",
            "LEVANTAMIENTO",
            "levantado",
            "levantamiento_si",
            "lev",
            "levantacion",
        ),
    )
    predio["negociacion"] = _read_bool_field(
        predio,
        ("negociacion", "_negociacion", "NEGOCIACION", "negociacion_si", "neg"),
    )
    predio["poligono_insertado"] = _read_bool_field(
        predio,
        ("poligono_insertado", "_poligono_insertado", "POLIGONO_INSERTADO"),
    )
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


def _normalize_token(value: Any) -> str:
    return re.sub(r"[^A-Z0-9]+", "", str(value or "").upper())


def _to_float(value: Any) -> float:
    if isinstance(value, bool):
        return 0.0
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        try:
            return float(value.strip().replace(",", ""))
        except ValueError:
            return 0.0
    return 0.0


def _segment_value(predio: dict[str, Any]) -> str:
    for key in ("segmento", "tramo", "segment", "seccion"):
        value = _clean_text(predio.get(key))
        if value:
            return value
    return ""


def _segment_matches(predio: dict[str, Any], segmento: str) -> bool:
    target = _normalize_token(segmento)
    if not target:
        return True

    current = _normalize_token(_segment_value(predio))
    if not current:
        return False
    if current == target:
        return True
    if current.endswith(target) or target.endswith(current):
        return True

    current_digits = re.sub(r"\D", "", current)
    target_digits = re.sub(r"\D", "", target)
    if current_digits and current_digits == target_digits:
        return True
    return False


def _owner_label(predio: dict[str, Any]) -> str:
    for key in (
        "propietario_nombre",
        "propietario",
        "nombre_propietario",
        "titular",
        "ejido",
    ):
        value = _clean_text(predio.get(key))
        if value:
            return value
    return "Sin propietario"


def _predio_is_liberado(predio: dict[str, Any]) -> bool:
    estatus = str(predio.get("estatus_gestion") or predio.get("estatus") or "").strip().upper()
    by_estatus = "LIBERADO" in estatus and "NO LIBERADO" not in estatus
    has_pdf = _clean_text(predio.get("pdf_url") or predio.get("cop_firmado")) is not None
    return _as_bool(predio.get("cop")) or has_pdf or by_estatus


def _next_reporte_folio() -> str:
    now = datetime.now(timezone.utc)
    year = now.year
    reportes = _read_reportes()
    max_suffix = 0
    for reporte in reportes:
        folio = str(reporte.get("folio_reporte") or "")
        match = re.fullmatch(rf"REP-{year}-(\d{{3}})", folio)
        if match:
            max_suffix = max(max_suffix, int(match.group(1)))
    return f"REP-{year}-{max_suffix + 1:03d}"


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


def _build_report_context(payload: dict[str, Any]) -> dict[str, Any]:
    datos_formulario = payload.get("datos_formulario")
    if not isinstance(datos_formulario, dict):
        raise HTTPException(status_code=400, detail="datos_formulario debe ser un objeto")

    proyecto = _clean_text(datos_formulario.get("proyecto"))
    segmento = _clean_text(datos_formulario.get("segmento"))
    fecha = _clean_text(datos_formulario.get("fecha"))
    para_nombre = _clean_text(datos_formulario.get("para_nombre"))
    para_cargo = _clean_text(datos_formulario.get("para_cargo"))
    de_nombre = _clean_text(datos_formulario.get("de_nombre"))
    de_cargo = _clean_text(datos_formulario.get("de_cargo"))
    elaboro_reviso = _clean_text(datos_formulario.get("elaboro_reviso")) or "BDVV/RSR"
    descripcion = _clean_text(datos_formulario.get("descripcion"))

    required_fields = {
        "proyecto": proyecto,
        "segmento": segmento,
        "fecha": fecha,
        "para_nombre": para_nombre,
        "para_cargo": para_cargo,
        "de_nombre": de_nombre,
        "de_cargo": de_cargo,
        "descripcion": descripcion,
    }
    missing = [name for name, value in required_fields.items() if not value]
    if missing:
        raise HTTPException(status_code=400, detail=f"Faltan campos del formulario: {', '.join(missing)}")

    predios = _read_predios()
    proyecto_predios = [predio for predio in predios if _matches_project(predio, proyecto)]
    segmento_predios = [predio for predio in proyecto_predios if _segment_matches(predio, segmento)]

    predios_totales_proy = len(proyecto_predios)
    predios_totales_seg = len(segmento_predios)
    predios_liberados_seg = len([predio for predio in segmento_predios if _predio_is_liberado(predio)])
    predios_no_liberados_seg = max(0, predios_totales_seg - predios_liberados_seg)
    km_efectivos = round(sum(_to_float(predio.get("km_efectivos")) for predio in segmento_predios), 2)
    km_liberados = round(
        sum(_to_float(predio.get("km_efectivos")) for predio in segmento_predios if _predio_is_liberado(predio)),
        2,
    )
    superficie_liberada_m2 = round(
        sum(_to_float(predio.get("superficie")) for predio in segmento_predios if _predio_is_liberado(predio)),
        2,
    )
    avance_lddv_doc = round(
        (predios_liberados_seg / predios_totales_seg * 100)
        if predios_totales_seg
        else 0.0,
        2,
    )
    avance_lddv_sindoc = round(max(0.0, 100.0 - avance_lddv_doc), 2)

    tipo_counts = Counter(str(predio.get("tipo_propiedad") or "SIN_TIPO").strip().upper() for predio in segmento_predios)
    privada = [
        predio
        for predio in segmento_predios
        if "PRIVADA" in str(predio.get("tipo_propiedad") or "").strip().upper()
    ]
    social = [
        predio
        for predio in segmento_predios
        if (
            "SOCIAL" in str(predio.get("tipo_propiedad") or "").strip().upper()
            or "DOMINIO" in str(predio.get("tipo_propiedad") or "").strip().upper()
        )
    ]

    def _tipo_balance_payload(items: list[dict[str, Any]]) -> dict[str, Any]:
        total = len(items)
        liberados = len([predio for predio in items if _predio_is_liberado(predio)])
        no_liberados = max(0, total - liberados)
        avance = round((liberados / total * 100) if total else 0.0, 2)
        return {
            "total": total,
            "liberados": liberados,
            "no_liberados": no_liberados,
            "avance": avance,
        }

    def _graph_payload(items: list[dict[str, Any]]) -> dict[str, Any]:
        unique_owners = {
            _normalize_token(_owner_label(predio))
            for predio in items
            if _owner_label(predio) != "Sin propietario"
        }
        return {
            "total_propietarios": len(unique_owners),
            "total_predios": len(items),
            "levantamiento_si": len([predio for predio in items if _as_bool(predio.get("levantamiento"))]),
            "acercamiento_si": len([predio for predio in items if _as_bool(predio.get("identificacion"))]),
            "negociacion_si": len([predio for predio in items if _as_bool(predio.get("negociacion"))]),
        }

    folio_reporte = str(payload.get("folio_reporte") or _next_reporte_folio())
    return {
        "folio_reporte": folio_reporte,
        "datos_formulario": {
            "fecha": fecha,
            "proyecto": proyecto,
            "segmento": segmento,
            "para_nombre": para_nombre,
            "para_cargo": para_cargo,
            "de_nombre": de_nombre,
            "de_cargo": de_cargo,
            "elaboro_reviso": elaboro_reviso,
            "descripcion": descripcion,
        },
        "datos_automatizados": {
            "predios_totales_proy": predios_totales_proy,
            "predios_totales_seg": predios_totales_seg,
            "predios_liberados_seg": predios_liberados_seg,
            "predios_no_liberados_seg": predios_no_liberados_seg,
            "km_efectivos": km_efectivos,
            "km_liberados": km_liberados,
            "superficie_liberada_m2": superficie_liberada_m2,
            "avance_lddv_doc": avance_lddv_doc,
            "avance_lddv_sindoc": avance_lddv_sindoc,
            "grafica_tipos": dict(tipo_counts),
            "graficas_privada": _graph_payload(privada),
            "graficas_social": _graph_payload(social),
            "avance_tipo_propiedad_segmento": {
                "privada": _tipo_balance_payload(privada),
                "social_dominio": _tipo_balance_payload(social),
            },
        },
    }


def _build_donut_chart(title: str, data: dict[str, int], palette: list[colors.Color]) -> Drawing:
    labels = [label for label, value in data.items() if value > 0]
    values = [value for value in data.values() if value > 0]

    drawing = Drawing(170, 180)
    drawing.add(
        String(85, 165, title, textAnchor="middle", fontSize=9, fillColor=colors.HexColor("#7A1E2B"))
    )

    if not values:
        drawing.add(String(85, 88, "Sin datos", textAnchor="middle", fontSize=9, fillColor=colors.grey))
        return drawing

    pie = Pie()
    pie.x = 20
    pie.y = 22
    pie.width = 130
    pie.height = 130
    pie.data = values
    pie.labels = [f"{label}: {value}" for label, value in zip(labels, values, strict=False)]
    pie.slices.strokeWidth = 0.6
    pie.slices.labelRadius = 1.15
    pie.slices.fontSize = 9
    pie.startAngle = 90

    for index, color in enumerate(palette):
        try:
            pie.slices[index].fillColor = color
        except Exception:
            break

    drawing.add(pie)
    drawing.add(Circle(85, 87, 32, fillColor=colors.white, strokeColor=colors.white))
    return drawing


def _build_reporte_pdf(report_context: dict[str, Any]) -> bytes:
    buffer = BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        leftMargin=20 * mm,
        rightMargin=20 * mm,
        topMargin=45 * mm,
        bottomMargin=35 * mm,
        title=f"Reporte {report_context['folio_reporte']}",
        author="Geoportal Backend API",
    )

    styles = getSampleStyleSheet()

    regular_font = "Helvetica"
    bold_font = "Helvetica-Bold"

    noto_regular_candidates = (
        REPORTE_FONT_DIR / "NotoSans-Regular.ttf",
        DATA_DIR / "NotoSans-Regular.ttf",
    )
    noto_bold_candidates = (
        REPORTE_FONT_DIR / "NotoSans-Bold.ttf",
        DATA_DIR / "NotoSans-Bold.ttf",
    )

    noto_regular = next((path for path in noto_regular_candidates if path.exists()), None)
    noto_bold = next((path for path in noto_bold_candidates if path.exists()), None)

    if noto_regular and noto_bold:
        registered = set(pdfmetrics.getRegisteredFontNames())
        if "NotoSans" not in registered:
            pdfmetrics.registerFont(TTFont("NotoSans", str(noto_regular)))
        if "NotoSans-Bold" not in registered:
            pdfmetrics.registerFont(TTFont("NotoSans-Bold", str(noto_bold)))
        pdfmetrics.registerFontFamily("NotoSans", normal="NotoSans", bold="NotoSans-Bold")
        regular_font = "NotoSans"
        bold_font = "NotoSans-Bold"

    title_style = ParagraphStyle(
        "ReporteTitle",
        parent=styles["Title"],
        fontName=bold_font,
        fontSize=9,
        leading=10.35,
        textColor=colors.HexColor("#6F1D2B"),
        alignment=1,
    )
    section_style = ParagraphStyle(
        "ReporteSection",
        parent=styles["Heading2"],
        fontName=bold_font,
        fontSize=9,
        leading=10.35,
        textColor=colors.HexColor("#6F1D2B"),
        spaceAfter=4,
    )
    body_style = ParagraphStyle(
        "ReporteBody",
        parent=styles["BodyText"],
        fontName=regular_font,
        fontSize=9,
        leading=10.35,
        textColor=colors.HexColor("#303030"),
    )
    small_style = ParagraphStyle(
        "ReporteSmall",
        parent=styles["BodyText"],
        fontName=regular_font,
        fontSize=9,
        leading=10.35,
        textColor=colors.HexColor("#4B4B4B"),
    )
    heading_style = ParagraphStyle(
        "ReporteHeading",
        parent=styles["Heading3"],
        fontName=bold_font,
        fontSize=9,
        leading=10.35,
        textColor=colors.HexColor("#222222"),
        spaceAfter=3,
    )
    right_style = ParagraphStyle(
        "ReporteRight",
        parent=body_style,
        alignment=2,
    )
    center_style = ParagraphStyle(
        "ReporteCentered",
        parent=body_style,
        alignment=1,
    )
    small_left_style = ParagraphStyle(
        "ReporteSmallLeft",
        parent=body_style,
        fontSize=5.5,
        leading=6.5,
        alignment=0,
    )
    center_bold_style = ParagraphStyle(
        "ReporteCenteredBold",
        parent=center_style,
        fontName=bold_font,
    )
    right_heading_style = ParagraphStyle(
        "ReporteRightHeading",
        parent=heading_style,
        alignment=2,
    )
    right_small_style = ParagraphStyle(
        "ReporteRightSmall",
        parent=small_style,
        alignment=2,
    )

    template_reader: ImageReader | None = None
    for candidate in REPORTE_MEMBRETE_CANDIDATES:
        if not candidate.exists():
            continue
        try:
            template_reader = ImageReader(str(candidate))
            break
        except Exception:
            template_reader = None

    form = report_context["datos_formulario"]
    auto = report_context["datos_automatizados"]

    fecha = form.get("fecha") or datetime.now().strftime("%d/%m/%Y")
    para_nombre = form.get("para_nombre") or "Ing. Pavel López Medina"
    para_cargo = form.get("para_cargo") or "Titular de la Unidad de Verificación, Seguridad y Registro"
    de_nombre = form.get("de_nombre") or "Ing. Carlos Alberto Sandoval Manrique de Lara"
    de_cargo = form.get("de_cargo") or "Director de Verificación Ferroviaria \"A\""
    elaboro_reviso = form.get("elaboro_reviso") or "BDVV/RSR"
    proyecto = form.get("proyecto") or "(nombre)"
    segmento = form.get("segmento") or "(número)"
    reporte_folio = report_context["folio_reporte"]

    def _fmt_int(value: Any) -> str:
        return f"{int(round(_to_float(value))):,}".replace(",", ".")

    def _fmt_float(value: Any) -> str:
        return f"{_to_float(value):,.2f}".replace(",", "_").replace(".", ",").replace("_", ".")

    total_seg = int(round(_to_float(auto.get("predios_totales_seg"))))
    liberados_seg = int(round(_to_float(auto.get("predios_liberados_seg"))))
    no_liberados_seg = int(round(_to_float(auto.get("predios_no_liberados_seg"))))
    safe_total_seg = total_seg if total_seg > 0 else 1
    pct_liberados_seg = (liberados_seg / safe_total_seg) * 100
    pct_no_liberados_seg = (no_liberados_seg / safe_total_seg) * 100

    bar_total_width = 130 * mm
    if total_seg <= 0:
        barra_data = [[""]]
        barra_col_widths = [bar_total_width]
        barra_style = TableStyle([
            ("BACKGROUND", (0, 0), (0, 0), colors.HexColor("#E6E8EB")),
            ("BOX", (0, 0), (0, 0), 0.5, colors.HexColor("#D2D6DC")),
        ])
    else:
        barra_liberados_w = max(0.6 * mm, bar_total_width * (liberados_seg / safe_total_seg))
        barra_no_liberados_w = max(0.6 * mm, bar_total_width - barra_liberados_w)
        barra_data = [["", ""]]
        barra_col_widths = [barra_liberados_w, barra_no_liberados_w]
        barra_style = TableStyle([
            ("BACKGROUND", (0, 0), (0, 0), colors.HexColor("#2FA36A")),
            ("BACKGROUND", (1, 0), (1, 0), colors.HexColor("#C94F4F")),
            ("BOX", (0, 0), (1, 0), 0.5, colors.HexColor("#D2D6DC")),
            ("LINEBEFORE", (1, 0), (1, 0), 0.3, colors.white),
        ])

    tipo_balance = auto.get("avance_tipo_propiedad_segmento")
    if not isinstance(tipo_balance, dict):
        tipo_balance = {}
    tipo_privada = tipo_balance.get("privada") if isinstance(tipo_balance.get("privada"), dict) else {}
    tipo_social = tipo_balance.get("social_dominio") if isinstance(tipo_balance.get("social_dominio"), dict) else {}

    def _tipo_cell(value: Any) -> str:
        return _fmt_int(value)

    tipo_table = Table(
        [
            [
                Paragraph("Tipo de propiedad", small_left_style),
                Paragraph("Total", center_bold_style),
                Paragraph("Liberados", center_bold_style),
                Paragraph("No liberados", center_bold_style),
                Paragraph("Avance", center_bold_style),
            ],
            [
                Paragraph("Privada", body_style),
                Paragraph(_tipo_cell(tipo_privada.get("total", 0)), center_style),
                Paragraph(_tipo_cell(tipo_privada.get("liberados", 0)), center_style),
                Paragraph(_tipo_cell(tipo_privada.get("no_liberados", 0)), center_style),
                Paragraph(f"{_to_float(tipo_privada.get('avance')):.2f}%", center_style),
            ],
            [
                Paragraph("Social y dominio pleno", body_style),
                Paragraph(_tipo_cell(tipo_social.get("total", 0)), center_style),
                Paragraph(_tipo_cell(tipo_social.get("liberados", 0)), center_style),
                Paragraph(_tipo_cell(tipo_social.get("no_liberados", 0)), center_style),
                Paragraph(f"{_to_float(tipo_social.get('avance')):.2f}%", center_style),
            ],
        ],
        colWidths=[58 * mm, 20 * mm, 24 * mm, 28 * mm, 22 * mm],
        style=TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#F2E7EA")),
            ("GRID", (0, 0), (-1, -1), 0.4, colors.HexColor("#D3D7DC")),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("LEFTPADDING", (0, 0), (-1, -1), 5),
            ("RIGHTPADDING", (0, 0), (-1, -1), 5),
            ("TOPPADDING", (0, 0), (-1, -1), 4),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ]),
    )

    story: list[Any] = [
        Paragraph("Agencia de Trenes y Transporte Público Integrado", right_heading_style),
        Paragraph("Unidad de Verificación, Seguridad y Registro", right_small_style),
        Paragraph("Dirección de Verificación Ferroviaria \"A\"", right_small_style),
        Paragraph(f"Ciudad de México a {fecha}", right_style),
        Paragraph(f"<b>Asunto:</b> Informe del balance actual del proyecto {proyecto}", right_style),
        Spacer(1, 3 * mm),
        Paragraph(f"<b>Reporte informativo {reporte_folio}</b>", center_style),
        Spacer(1, 4 * mm),
        Paragraph(f"<b>Para: {para_nombre}<br/>{para_cargo}</b>", body_style),
        Spacer(1, 2 * mm),
        Paragraph(f"<b>De: {de_nombre}<br/>{de_cargo}</b>", body_style),
        Spacer(1, 2 * mm),
        Paragraph("<b>Presente</b>", body_style),
        Spacer(1, 3 * mm),
        Paragraph(
            (
                "El presente documento expone la gestión predial del estatus actual sobre la "
                f"Liberación De Derecho De Vía del proyecto {proyecto} en referencia al segmento {segmento}. "
                + (form.get("descripcion") or "")
            ),
            body_style,
        ),
        Spacer(1, 5 * mm),
        Paragraph("A. Total de predios y avance de liberación", section_style),
        Spacer(1, 3 * mm),
        Paragraph(f"• Predios totales del segmento: ({_fmt_int(total_seg)})", body_style),
        Table(
            barra_data,
            colWidths=barra_col_widths,
            rowHeights=[7 * mm],
            style=barra_style,
        ),
        Spacer(1, 2 * mm),
        Paragraph(
            f"• Liberados: {_fmt_int(liberados_seg)} ({pct_liberados_seg:.2f}%)  |  "
            f"No liberados: {_fmt_int(no_liberados_seg)} ({pct_no_liberados_seg:.2f}%)",
            body_style,
        ),
        Spacer(1, 5 * mm),
        Paragraph("B. Avance por tipo de propiedad (segmento indicado)", section_style),
        Spacer(1, 3 * mm),
        tipo_table,
        Spacer(1, 8 * mm),
        Paragraph("Atentamente", center_bold_style),
        Spacer(1, 2 * mm),
        Paragraph(f"({elaboro_reviso})", small_left_style),
    ]

    def _draw_header_footer(canvas, doc):
        canvas.saveState()
        width, height = A4

        if template_reader is not None:
            canvas.drawImage(
                template_reader,
                0,
                0,
                width=width,
                height=height,
                mask="auto",
            )
        else:
            # Fallback visual if there is no membretado image available yet.
            canvas.setStrokeColor(colors.HexColor("#7A1E2B"))
            canvas.setLineWidth(1.2)
            canvas.line(doc.leftMargin, height - 18 * mm, width - doc.rightMargin, height - 18 * mm)
            canvas.line(doc.leftMargin, 16 * mm, width - doc.rightMargin, 16 * mm)

            canvas.setFillColor(colors.HexColor("#6D2330"))
            canvas.setFont(bold_font, 9)
            canvas.drawString(doc.leftMargin, height - 14 * mm, "Comunicaciones")
            canvas.setFont(regular_font, 9)
            canvas.drawString(doc.leftMargin, height - 17.5 * mm, "Secretaría de Infraestructura, Comunicaciones y Transportes")
            canvas.setFont(bold_font, 9)
            canvas.drawRightString(width - doc.rightMargin, height - 14 * mm, "TRENES")
            canvas.setFont(regular_font, 9)
            canvas.drawRightString(width - doc.rightMargin, height - 17.5 * mm, "Agencia de Trenes y Transporte Público Integrado")
            canvas.setFont(regular_font, 9)
            canvas.setFillColor(colors.HexColor("#8C3140"))
            canvas.drawString(doc.leftMargin, 10 * mm, "Avenida Universidad 1738, Colonia Santa Catarina, C.P. 04010, Alcaldía Coyoacán, Ciudad de México.")
            canvas.drawRightString(width - doc.rightMargin, 10 * mm, "www.gob.mx/attrapi")

        canvas.restoreState()

    doc.build(story, onFirstPage=_draw_header_footer, onLaterPages=_draw_header_footer)
    return buffer.getvalue()

@app.get("/")
def root():
    return {"message": "Geoportal Backend API running"}


@app.post("/reportes/generar")
def generar_reporte(payload: dict[str, Any]):
    with _store_lock:
        report_context = _build_report_context(payload)
        pdf_bytes = _build_reporte_pdf(report_context)

        reportes = _read_reportes()
        reportes.append(
            {
                "folio_reporte": report_context["folio_reporte"],
                "created_at": _now_iso(),
                "datos_formulario": report_context["datos_formulario"],
                "datos_automatizados": report_context["datos_automatizados"],
                "payload_hash": hashlib.sha1(
                    json.dumps(report_context, ensure_ascii=False, sort_keys=True).encode("utf-8")
                ).hexdigest(),
            }
        )
        _write_reportes(reportes)

    file_name = f"{report_context['folio_reporte']}.pdf"
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'inline; filename="{file_name}"'},
    )


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
