# IMPL-06 — Desktop Fase 6: Firma y notarización

**Estado:** ✅ Ad-hoc completado / ⏳ Developer ID pendiente (requiere Apple Developer Program)  
**Fecha:** 2026-05-07  
**Rama:** `desktop/fase-1`  
**Proyecto:** geoportal-lddv  

---

## Contexto: niveles de firma en macOS

| Nivel | Requisito | Resultado en Gatekeeper |
|---|---|---|
| **Sin firma** | Ninguno | Bloqueado por Gatekeeper (usuario debe hacer clic derecho > Abrir) |
| **Ad-hoc** (`-`) | Ninguno | Permite ejecutar en la misma Mac; otras Macs muestran aviso de Gatekeeper |
| **Apple Development** | Apple Developer (gratis) | Solo para testing en dispositivos propios |
| **Developer ID Application** | Apple Developer Program ($99/año) | Distribución fuera del App Store sin avisos de Gatekeeper |
| **Developer ID + Notarizado** | Apple Developer Program + notarytool | Distribución sin ningún aviso de Gatekeeper en cualquier Mac |

---

## Fase 6a — Firma ad-hoc ✅ (implementada)

### Qué hace la firma ad-hoc

Genera una firma local con identidad temporal (`-`). No requiere certificados. Permite:
- Ejecutar en la Mac donde se compiló sin avisos
- En otras Macs: Gatekeeper muestra aviso, pero el usuario puede abrir con clic derecho

### Comando

```bash
codesign --force --deep --sign - /tmp/geoportal_build/macos/Build/Products/Release/geoportal_predios.app
codesign --verify --deep --strict geoportal_predios.app
```

### Resultado

```
geoportal_predios.app: replacing existing signature
verify OK
Format=app bundle with Mach-O universal (x86_64 arm64)
Signature=adhoc
```

El script `scripts/build_dmg.sh` incluye la firma ad-hoc automáticamente en el paso de empaquetado.

**Artefacto**: `dist/geoportal_predios_v1.0.0_adhoc.dmg` (23MB)

---

## Fase 6b — Developer ID + Notarización ⏳ (documentado para implementación futura)

### Requisitos

1. **Apple Developer Program** — https://developer.apple.com/programs/ ($99/año)
2. Certificado **Developer ID Application** generado en Xcode > Settings > Accounts
3. **App-specific password** o **App Store Connect API Key** para `notarytool`

### Paso 1 — Generar Developer ID Application en Xcode

```
Xcode > Settings > Accounts > Manage Certificates > (+) > Developer ID Application
```

Verificar que aparece en el keychain:
```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
# => "Developer ID Application: Tu Nombre (TEAMID)"
```

### Paso 2 — Firma con Developer ID

```bash
APP="/tmp/geoportal_build/macos/Build/Products/Release/geoportal_predios.app"
CERT="Developer ID Application: Tu Nombre (TEAMID)"
ENTITLEMENTS="macos/Runner/Release.entitlements"

codesign \
  --force \
  --deep \
  --options runtime \
  --entitlements "$ENTITLEMENTS" \
  --sign "$CERT" \
  "$APP"

codesign --verify --deep --strict "$APP" && echo "OK"
```

`--options runtime` es **obligatorio** para notarización (Hardened Runtime).

### Paso 3 — Crear DMG

```bash
hdiutil create \
  -volname "Geoportal Predios" \
  -srcfolder "$APP" \
  -ov -format UDZO \
  -o dist/geoportal_predios_v1.0.0.dmg
```

### Paso 4 — Notarizar

Opción A — Con Apple ID + app-specific password:
```bash
xcrun notarytool submit dist/geoportal_predios_v1.0.0.dmg \
  --apple-id "tu@email.com" \
  --team-id "TEAMID" \
  --password "xxxx-xxxx-xxxx-xxxx" \
  --wait
```

Opción B — Con API Key (más seguro, recomendado para CI):
```bash
xcrun notarytool submit dist/geoportal_predios_v1.0.0.dmg \
  --key "AuthKey_XXXXXXXX.p8" \
  --key-id "XXXXXXXX" \
  --issuer "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" \
  --wait
```

### Paso 5 — Staple (incrustar el ticket de notarización)

```bash
xcrun stapler staple dist/geoportal_predios_v1.0.0.dmg
xcrun stapler validate dist/geoportal_predios_v1.0.0.dmg
```

El staple permite que el DMG funcione sin conexión a internet en otras Macs.

### Verificación final en máquina limpia

```bash
spctl --assess --type execute --verbose geoportal_predios.app
# Resultado esperado: "accepted" (source=Notarized Developer ID)
```

---

## Entitlements necesarios para Hardened Runtime

El archivo `macos/Runner/Release.entitlements` ya tiene los entitlements correctos de fases anteriores:

```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

No se necesitan entitlements adicionales para la firma con Developer ID.

---

## Criterio de éxito

- [x] Firma ad-hoc: `codesign --verify` → `verify OK`, `Signature=adhoc`
- [x] `dist/geoportal_predios_v1.0.0_adhoc.dmg` (23MB)
- [x] `scripts/build_dmg.sh` incluye firma ad-hoc automáticamente
- [ ] *(futuro)* `codesign --verify` → `Signature=Developer ID Application`
- [ ] *(futuro)* `xcrun notarytool submit` → `status: Accepted`
- [ ] *(futuro)* `spctl --assess` → `accepted (source=Notarized Developer ID)`

---

## Próximo paso

**[IMPL-07]** — CI/CD: GitHub Actions workflow para build + DMG automático en cada tag `v*`
