import json
import re
from json import JSONDecodeError, JSONDecoder
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from uuid import uuid4

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
PROJECT_CODES = ("TQI", "TSNL", "TAP", "TQM")


def _ensure_store() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    if not DATA_FILE.exists():
        DATA_FILE.write_text("[]", encoding="utf-8")


def _read_predios() -> list[dict[str, Any]]:
    _ensure_store()
    raw = DATA_FILE.read_text(encoding="utf-8").strip() or "[]"
    try:
        data = json.loads(raw)
        if not isinstance(data, list):
            raise ValueError("El almacén de predios es inválido.")
        return [dict(item) for item in data if isinstance(item, dict)]
    except JSONDecodeError:
        # Recuperación tolerante: permite archivos con múltiples documentos JSON
        # concatenados o con basura al final. Se conserva lo parseable y se reescribe.
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
            _write_predios(recovered)
            return recovered

        raise ValueError("El almacén de predios está dañado y no se pudo recuperar.")


def _write_predios(predios: list[dict[str, Any]]) -> None:
    _ensure_store()
    temp_file = DATA_FILE.with_suffix(".tmp")
    temp_file.write_text(
        json.dumps(predios, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    temp_file.replace(DATA_FILE)


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

@app.get("/")
def root():
    return {"message": "Geoportal Backend API running"}

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

@app.put("/predios/{predio_id}")
def update_predio(predio_id: str, predio: dict):
    predios, index, existing = _find_predio_or_404(predio_id)
    payload = dict(predio)
    payload["id"] = predio_id
    normalized = _normalize_predio(payload, existing)
    predios[index] = normalized
    _write_predios(predios)
    return normalized

@app.delete("/predios/{predio_id}")
def delete_predio(predio_id: str):
    predios, index, _ = _find_predio_or_404(predio_id)
    predios.pop(index)
    _write_predios(predios)
    return {"deleted": True, "id": predio_id}
