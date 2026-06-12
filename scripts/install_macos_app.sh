#!/usr/bin/env bash
set -euo pipefail

# Instala la app macOS en Aplicaciones y, opcionalmente, la mantiene actualizada.
# Uso:
#   ./scripts/install_macos_app.sh
#   ./scripts/install_macos_app.sh --mode debug
#   ./scripts/install_macos_app.sh --mode release
#   ./scripts/install_macos_app.sh --watch
#   ./scripts/install_macos_app.sh --watch --mode debug

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODE="debug"
WATCH="false"
TMP_BUILD_DIR="/tmp/geoportal-lddv-install-run"
POLL_SECONDS="2"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --watch)
      WATCH="true"
      shift
      ;;
    *)
      echo "Argumento no reconocido: $1"
      exit 1
      ;;
  esac
done

if [[ "$MODE" != "debug" && "$MODE" != "release" ]]; then
  echo "Modo invalido: $MODE (usa debug o release)"
  exit 1
fi

build_once() {
  rm -rf "$TMP_BUILD_DIR"
  rsync -a \
    --exclude build \
    --exclude .dart_tool \
    --exclude .git \
    "$ROOT_DIR/" "$TMP_BUILD_DIR/"

  pushd "$TMP_BUILD_DIR" >/dev/null

  # Evita fallos de CodeSign por atributos extendidos (common on macOS).
  xattr -cr "$TMP_BUILD_DIR/macos" 2>/dev/null || true
  xattr -cr "$TMP_BUILD_DIR/build" 2>/dev/null || true

  local flutter_arg="--debug"
  local mode_dir="Debug"
  if [[ "$MODE" == "release" ]]; then
    flutter_arg="--release"
    mode_dir="Release"
  fi

  echo "[install] Construyendo app macOS ($MODE)..."
  flutter build macos "$flutter_arg"

  local app_src="$TMP_BUILD_DIR/build/macos/Build/Products/$mode_dir/geoportal_predios.app"
  if [[ ! -d "$app_src" ]]; then
    echo "[install] No se encontro app en: $app_src"
    exit 1
  fi

  local target_dir="/Applications"
  if [[ ! -w "$target_dir" ]]; then
    target_dir="$HOME/Applications"
  fi
  mkdir -p "$target_dir"

  local app_dest="$target_dir/geoportal_predios.app"
  echo "[install] Instalando en: $app_dest"
  rm -rf "$app_dest"
  ditto "$app_src" "$app_dest"
  xattr -cr "$app_dest" 2>/dev/null || true

  echo "[install] Listo: $app_dest"
  popd >/dev/null
}

build_once

if [[ "$WATCH" == "true" ]]; then
  declare -a WATCH_PATHS=()
  for path in "$ROOT_DIR/lib" "$ROOT_DIR/macos" "$ROOT_DIR/pubspec.yaml" "$ROOT_DIR/assets"; do
    if [[ -e "$path" ]]; then
      WATCH_PATHS+=("$path")
    fi
  done

  if [[ ${#WATCH_PATHS[@]} -eq 0 ]]; then
    echo "[watch] No hay rutas para monitorear."
    exit 1
  fi

  if command -v fswatch >/dev/null 2>&1; then
    echo "[watch] Monitoreando cambios con fswatch..."
    fswatch -0 "${WATCH_PATHS[@]}" 2>/dev/null | while IFS= read -r -d '' _; do
        echo "[watch] Cambio detectado. Reinstalando..."
        if ! build_once; then
          echo "[watch] Error en reinstalacion. Se reintentara en el siguiente cambio."
        fi
      done
  else
    echo "[watch] fswatch no esta instalado. Usando sondeo cada ${POLL_SECONDS}s."

    compute_fingerprint() {
      find "${WATCH_PATHS[@]}" -type f -exec stat -f '%m %N' {} \; 2>/dev/null | shasum | awk '{print $1}'
    }

    local_fingerprint="$(compute_fingerprint)"
    while true; do
      sleep "$POLL_SECONDS"
      new_fingerprint="$(compute_fingerprint)"
      if [[ "$new_fingerprint" != "$local_fingerprint" ]]; then
        local_fingerprint="$new_fingerprint"
        echo "[watch] Cambio detectado. Reinstalando..."
        if ! build_once; then
          echo "[watch] Error en reinstalacion. Se reintentara en el siguiente cambio."
        fi
      fi
    done
  fi
fi
