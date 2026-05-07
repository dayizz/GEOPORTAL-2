# IMPL-01 — Desktop Fase 1: Fix build macOS

**Estado:** ✅ Implementado  
**Fecha:** 2026-05-07  
**Rama:** `desktop/fase-1`  
**Proyecto:** geoportal-lddv  

---

## Objetivo

Lograr que `flutter build macos` y `flutter run -d macos` completen sin errores, con permisos suficientes para que la app acceda a la red (mapas, Supabase, HTTP) y al sistema de archivos del usuario (FilePicker).

---

## Diagnóstico previo

El build fallaba con el siguiente error de Xcode:

```
/build/macos/Build/Products/Release/geoportal_predios.app:
resource fork, Finder information, or similar detritus not allowed
Command CodeSign failed with a nonzero exit code
** BUILD FAILED **
```

**Causa raíz 1 — Atributos extendidos (xattr):**  
Xcode no puede firmar el bundle `.app` cuando algún archivo dentro de `build/macos/` tiene atributos extendidos de macOS (resource forks, datos de Finder, flags de cuarentena). El comando `xattr -cr build/macos` no era suficiente porque los archivos en `.git/objects/` tienen permisos de solo lectura y bloqueaban el proceso. La solución fue ejecutar `xattr -cr .` desde la raíz del proyecto, lo cual limpia los atributos de todos los archivos incluyendo los del proyecto fuente.

**Causa raíz 2 — Entitlements incompletos:**  
Los entitlements del sandbox de macOS no incluían los permisos necesarios para:
- `network.client` → la app no podría hacer peticiones HTTP/HTTPS salientes (mapas OSM, Supabase, FastAPI backend)
- `files.user-selected.read-write` → FilePicker no podría abrir el panel nativo de selección de archivos del sistema

---

## Archivos modificados

| Archivo | Tipo de cambio |
|---|---|
| `macos/Runner/DebugProfile.entitlements` | + 2 entitlements (red + archivos) |
| `macos/Runner/Release.entitlements` | + 2 entitlements (red + archivos) |

---

## Cambios aplicados

### `macos/Runner/DebugProfile.entitlements`

```xml
<!-- ANTES -->
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
</dict>

<!-- DESPUÉS -->
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
```

### `macos/Runner/Release.entitlements`

```xml
<!-- ANTES -->
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
</dict>

<!-- DESPUÉS -->
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
```

---

## Entitlements — referencia

| Entitlement | Necesario para |
|---|---|
| `app-sandbox` | Requisito Apple — todos los apps macOS deben correr en sandbox |
| `cs.allow-jit` | Motor Dart (debug) — permite compilación JIT en tiempo de ejecución |
| `network.server` | Ya existía — permite abrir sockets de servidor (flutter run dev) |
| `network.client` | **Nuevo** — peticiones salientes HTTP/HTTPS: mapas OSM, Supabase, FastAPI |
| `files.user-selected.read-write` | **Nuevo** — leer/escribir archivos seleccionados por el usuario con FilePicker |

---

## Comandos de build

**Build limpio (recomendado si falla CodeSign):**
```bash
xattr -cr .
flutter build macos
```

**Desde cero:**
```bash
flutter clean && flutter pub get
xattr -cr .
flutter build macos
```

**Ejecutar en desarrollo:**
```bash
flutter run -d macos
```

---

## Criterio de éxito

- [x] `flutter build macos` termina sin error
- [x] La app abre en macOS sin crash
- [ ] El mapa carga tiles de OpenStreetMap ← verificar en Fase 2
- [ ] FilePicker abre el panel nativo ← verificar en Fase 2
- [ ] Las peticiones HTTP al backend funcionan ← verificar en Fase 2

---

## Resultado

```
✓ Built build/macos/Build/Products/Release/geoportal_predios.app (51.2 MB)
```

App abre correctamente en macOS.

---

## Próximo paso

**[IMPL-02] Desktop Fase 2 — Adaptar APIs web-específicas:**
- `webOnlyWindowName` en `launchUrl` → `LaunchMode.externalApplication`
- `FilePicker` bytes en web vs path en desktop → guard con `kIsWeb` + `dart:io`
