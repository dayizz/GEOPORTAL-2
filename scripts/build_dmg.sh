#!/bin/bash
# scripts/build_dmg.sh
# Empaqueta geoportal_predios.app en un DMG distribuible.
#
# Uso:
#   ./scripts/build_dmg.sh [VERSION]
#
# Ejemplo:
#   ./scripts/build_dmg.sh 1.0.0
#
# Requiere que build/ sea un symlink a /tmp/geoportal_build (fuera de iCloud).
# Si flutter clean lo eliminó, lo recrea automáticamente.

set -e

VERSION="${1:-1.0.0}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_PATH="/tmp/geoportal_build/macos/Build/Products/Release/geoportal_predios.app"
DMG_NAME="geoportal_predios_v${VERSION}.dmg"
DIST_DIR="${PROJECT_DIR}/dist"

echo "==> Verificando symlink build/ -> /tmp/geoportal_build"
if [ ! -L "${PROJECT_DIR}/build" ]; then
  echo "    El symlink build/ no existe. Recreando..."
  mkdir -p /tmp/geoportal_build
  ln -s /tmp/geoportal_build "${PROJECT_DIR}/build"
  echo "    build/ -> /tmp/geoportal_build creado"
else
  echo "    OK: $(ls -la "${PROJECT_DIR}/build" | awk '{print $NF}')"
fi

echo "==> Compilando Flutter macOS (release)..."
cd "${PROJECT_DIR}"
flutter pub get
flutter build macos --release

echo "==> Verificando .app generado..."
if [ ! -d "${APP_PATH}" ]; then
  echo "ERROR: No se encontró ${APP_PATH}"
  exit 1
fi
echo "    OK: $(du -sh "${APP_PATH}" | cut -f1)"

echo "==> Creando DMG..."
mkdir -p "${DIST_DIR}"
hdiutil create \
  -volname "Geoportal Predios" \
  -srcfolder "${APP_PATH}" \
  -ov \
  -format UDZO \
  -o "${DIST_DIR}/${DMG_NAME}"

echo ""
echo "✓ DMG generado: dist/${DMG_NAME}"
ls -lh "${DIST_DIR}/${DMG_NAME}"
