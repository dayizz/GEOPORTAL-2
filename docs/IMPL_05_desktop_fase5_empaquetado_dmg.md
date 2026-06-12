# IMPL-05 — Desktop Fase 5: Empaquetado DMG

**Estado:** ✅ Implementado  
**Fecha:** 2026-05-07  
**Rama:** `desktop/fase-1`  
**Proyecto:** geoportal-lddv  

---

## Objetivo

Generar un archivo `.dmg` distribuible de `geoportal_predios.app` para macOS.

---

## Herramienta

`hdiutil` — utilidad nativa de macOS para crear y gestionar imágenes de disco.  
No requiere instalación adicional. Formato `UDZO` = compresión zlib.

---

## Script de empaquetado

`scripts/build_dmg.sh` — automatiza build + empaquetado DMG:

```bash
./scripts/build_dmg.sh [VERSION]
# Ejemplo:
./scripts/build_dmg.sh 1.0.0
```

El script:
1. Verifica / recrea el symlink `build/ -> /tmp/geoportal_build`
2. Ejecuta `flutter pub get && flutter build macos --release`
3. Crea `dist/geoportal_predios_vVERSION.dmg` con `hdiutil create`

---

## Comando manual

```bash
hdiutil create \
  -volname "Geoportal Predios" \
  -srcfolder "/tmp/geoportal_build/macos/Build/Products/Release/geoportal_predios.app" \
  -ov \
  -format UDZO \
  -o dist/geoportal_predios_v1.0.0.dmg
```

| Opción | Descripción |
|---|---|
| `-volname` | Nombre del volumen al montar el DMG |
| `-srcfolder` | Carpeta/archivo fuente a incluir |
| `-ov` | Sobreescribir si ya existe |
| `-format UDZO` | Compresión zlib (menor tamaño, lectura rápida) |
| `-o` | Ruta de salida |

---

## Resultado

```
dist/geoportal_predios_v1.0.0.dmg — 23MB
hdiutil verify: checksum VALID
```

`.app` original: 52.1MB → DMG comprimido: 23MB (56% de reducción).

---

## .gitignore

`dist/` y `*.dmg` añadidos a `.gitignore` — los binarios no se versionan en git.

---

## Nota: symlink build/ → /tmp/

`flutter clean` elimina el symlink `build/`. El script `build_dmg.sh` lo detecta y recrea automáticamente. Para builds manuales, recrear antes de compilar:

```bash
flutter clean
mkdir -p /tmp/geoportal_build && ln -s /tmp/geoportal_build build
flutter pub get && flutter build macos
```

---

## Criterio de éxito

- [x] `dist/geoportal_predios_v1.0.0.dmg` generado (23MB)
- [x] `hdiutil verify` — checksum VALID
- [x] `scripts/build_dmg.sh` funcional y ejecutable
- [x] `dist/` y `*.dmg` en `.gitignore`

---

## Próximo paso

**[IMPL-06] Desktop Fase 6** — Firma y notarización para distribución fuera del App Store (`codesign` + `xcrun notarytool`)
