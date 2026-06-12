# IMPL-02 — Desktop Fase 2: Adaptar APIs web-específicas

**Estado:** ✅ Implementado  
**Fecha:** 2026-05-07  
**Rama:** `desktop/fase-1` (continúa rama activa)  
**Proyecto:** geoportal-lddv  

---

## Objetivo

Adaptar los tres usos de APIs web-específicas para que funcionen correctamente en macOS desktop sin romper el comportamiento en web:

1. `launchUrl(..., webOnlyWindowName: '_blank')` — parámetro ignorado/inexistente en desktop
2. `FilePicker.pickFiles(withData: true)` + `file.bytes` — en desktop `bytes` es null si la ruta se usa directamente, es más eficiente leer con `dart:io`

---

## Diagnóstico

### Problema 1 — `webOnlyWindowName`

`url_launcher` acepta el parámetro `webOnlyWindowName` en todas las plataformas (no es un error de compilación), pero en desktop el modo por defecto (`LaunchMode.platformDefault`) puede no abrir el navegador correctamente. La solución es usar `LaunchMode.externalApplication` que funciona en todas las plataformas.

```dart
// ANTES — solo abre en navegador en web, comportamiento indefinido en desktop
launchUrl(uri, webOnlyWindowName: '_blank')

// DESPUÉS — abre en la app registrada (navegador) en todas las plataformas
launchUrl(uri, mode: LaunchMode.externalApplication)
```

### Problema 2 — `FilePicker` bytes en memoria vs path en disco

En **web**, `file.path` no existe. Es obligatorio usar `withData: true` para obtener `file.bytes`.  
En **desktop/macOS**, `file.path` sí existe. Leer los bytes desde el path es más eficiente en memoria (evita cargar archivos grandes enteros en RAM al mismo tiempo que los procesa).

```dart
// ANTES — withData: true siempre (web obligatorio, innecesario en desktop)
final result = await FilePicker.platform.pickFiles(withData: true);
final bytes = file.bytes;  // null en desktop si no se pide withData

// DESPUÉS — estrategia adaptativa por plataforma
final result = await FilePicker.platform.pickFiles(withData: kIsWeb);
final Uint8List? bytes = kIsWeb
    ? file.bytes
    : file.path != null ? await File(file.path!).readAsBytes() : null;
```

---

## Archivos modificados

| Archivo | Cambio |
|---|---|
| `lib/features/predios/presentation/predio_form_screen.dart` | `launchUrl` + `FilePicker` bytes |
| `lib/features/tabla/presentation/tabla_screen.dart` | `launchUrl` + `FilePicker` bytes |
| `lib/features/carga/presentation/carga_archivo_screen.dart` | `FilePicker` + lectura bytes |

---

## Cambios detallados

### `predio_form_screen.dart`

**Imports añadidos:**
```dart
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
```

**`_openPdf` (línea ~154):**
```dart
// ANTES
final opened = await launchUrl(uri, webOnlyWindowName: '_blank');

// DESPUÉS
final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
```

**`_cargarPdf` (línea ~229) — FilePicker PDF:**
```dart
// ANTES
pickFiles(withData: true)
final bytes = file.bytes;
if (bytes == null) { /* error */ }

// DESPUÉS
pickFiles(withData: kIsWeb)
final Uint8List? bytes = kIsWeb
    ? file.bytes
    : file.path != null ? await File(file.path!).readAsBytes() : null;
if (bytes == null) { /* error */ }
```

---

### `tabla_screen.dart`

**Imports añadidos:**
```dart
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
```

**`_openPdfUrl` (línea ~665):**
```dart
// ANTES
final opened = await launchUrl(uri, webOnlyWindowName: '_blank');

// DESPUÉS
final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
```

**`_handleCopPdfTap` (línea ~678) — FilePicker PDF:**
```dart
// ANTES
pickFiles(withData: true)
final bytes = file.bytes;

// DESPUÉS
pickFiles(withData: kIsWeb)
final Uint8List? bytes = kIsWeb
    ? file.bytes
    : file.path != null ? await File(file.path!).readAsBytes() : null;
```

---

### `carga_archivo_screen.dart`

**Imports añadidos:**
```dart
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
```

**`_seleccionarArchivo` (línea ~98) — FilePicker GeoJSON/XLSX:**
```dart
// ANTES
pickFiles(type: FileType.any, withData: true)
Uint8List? bytes = file.bytes;
if (bytes == null && file.readStream != null) { /* stream fallback */ }

// DESPUÉS
pickFiles(type: FileType.any, withData: kIsWeb)
Uint8List? bytes;
if (kIsWeb) {
  bytes = file.bytes;
  if (bytes == null && file.readStream != null) { /* stream fallback */ }
} else {
  if (file.path != null) bytes = await File(file.path!).readAsBytes();
}
```

---

## Criterio de éxito

- [x] `flutter analyze` — 0 errores nuevos
- [x] `flutter build macos` — OK (`geoportal_predios.app 51.2 MB`)
- [ ] Verificar en macOS: botón "Abrir PDF" abre Safari/Chrome
- [ ] Verificar en macOS: FilePicker abre panel nativo y lee el archivo
- [ ] Verificar en web: comportamiento sin cambios

---

## Resultado

```
✓ Built build/macos/Build/Products/Release/geoportal_predios.app (51.2 MB)
```

`flutter analyze` — 0 errores (solo warnings preexistentes de `withOpacity` deprecated y `value` → `initialValue`). Fase 2 completada.

---

## Próximo paso

**[IMPL-03] Desktop Fase 3** — `path_provider` para persistencia de archivos grandes en desktop
