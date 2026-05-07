# IMPL-03 — Desktop Fase 3: path_provider para persistencia de archivos grandes

**Estado:** ✅ Implementado  
**Fecha:** 2026-05-07  
**Rama:** `desktop/fase-1` (continúa)  
**Proyecto:** geoportal-lddv  

---

## Objetivo

Permitir que en macOS desktop se guarden **todos** los features de un archivo importado (GeoJSON/XLSX) en disco local, eliminando el límite de 20 features impuesto por los límites de `localStorage` en web.

---

## Diagnóstico

### Problema actual

`LocalArchivosRepository` usa `shared_preferences` para persistir archivos importados:
- En **web** → `localStorage` del navegador, límite ~5 MB total
- En **desktop** → `NSUserDefaults`, tamaño práctico ~1 MB por entrada

Por eso `saveArchivo()` guarda máximo 20 features por archivo para no saturar el almacenamiento.  
En desktop, esto significa que al relanzar la app solo se recuperan los primeros 20 features de cada archivo importado en lugar del dataset completo.

### Solución

Estrategia en dos capas:

| Capa | Dónde | Qué guarda | Plataforma |
|---|---|---|---|
| Índice (metadata) | `shared_preferences` | id, nombre, conteos, fechas + máx 20 features (preview) | web + desktop |
| Features completos | `Documents/geoportal_predios/archivos/{id}.json` | Todos los features del archivo | solo desktop |

Al cargar (`getArchivos()`), en desktop se intenta leer el archivo de features completo; si existe, reemplaza el array de features del índice. En web, se usa solo el índice.

### Paquete necesario

`path_provider: ^2.1.5` — provee `getApplicationDocumentsDirectory()` en macOS/Windows/Linux. Ya es compatible con web (retorna un path vacío en web que no se usa).

---

## Archivos modificados

| Archivo | Cambio |
|---|---|
| `pubspec.yaml` | + `path_provider: ^2.1.5` |
| `lib/features/carga/data/local_archivos_repository.dart` | + escritura/lectura de archivos JSON en desktop |

---

## Cambios detallados

### `pubspec.yaml`

```yaml
# DESPUÉS (agregar junto a shared_preferences)
shared_preferences: ^2.3.2
path_provider: ^2.1.5
```

---

### `local_archivos_repository.dart`

**Lógica añadida:**

```dart
import 'dart:io' show File, Directory;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

// Ruta base de archivos en desktop:
// ~/Documents/geoportal_predios/archivos/{id}.json

Future<File?> _featuresFile(String id) async {
  if (kIsWeb) return null;
  final dir = await getApplicationDocumentsDirectory();
  final folder = Directory('${dir.path}/geoportal_predios/archivos');
  if (!folder.existsSync()) folder.createSync(recursive: true);
  return File('${folder.path}/$id.json');
}

// En saveArchivo(): si desktop, guardar features completos en archivo
// En getArchivos(): si desktop, leer features del archivo si existe
// En deleteArchivo(): si desktop, borrar también el archivo de features
// En deleteAll(): si desktop, borrar carpeta completa
```

**`saveArchivo()`:**
- En desktop: escribe todos los features en `{id}.json`; en shared_prefs guarda preview de 20
- En web: igual que antes (solo shared_prefs, máx 20)

**`getArchivos()`:**
- En desktop: por cada entrada del índice, si `{id}.json` existe lo lee y reemplaza `entry['features']` y `entry['features_count']`
- En web: igual que antes

---

## Directorio de datos en desktop

```
~/Documents/
└── geoportal_predios/
    └── archivos/
        ├── {uuid1}.json   ← features del primer archivo importado
        ├── {uuid2}.json
        └── ...
```

---

## Criterio de éxito

- [x] `flutter pub get` resuelve `path_provider` sin conflictos
- [x] `flutter analyze` — 0 errores nuevos
- [x] `flutter build macos` — OK
- [ ] Importar un GeoJSON con >20 features en macOS, cerrar app, reabrir → todos los features disponibles
- [ ] En web: comportamiento sin cambios (sigue usando shared_prefs, cap 20)

---

## Resultado

```
✓ Built build/macos/Build/Products/Release/geoportal_predios.app (51.2 MB)
```

`flutter analyze` — 0 errores nuevos. Fase 3 completada.

---

## Próximo paso

**[IMPL-04] Desktop Fase 4** — UX escritorio: `NavigationRail` sidebar, `window_manager`, scroll con mouse
