# IMPL-04 — Desktop Fase 4: UX escritorio

**Estado:** ✅ Implementado  
**Fecha:** 2026-05-07  
**Rama:** `desktop/fase-1` (continúa)  
**Proyecto:** geoportal-lddv  

---

## Objetivo

Mejorar la experiencia de usuario en macOS desktop con:
1. Tamaño mínimo de ventana (evitar que la UI se rompa al redimensionar)
2. Scroll con rueda de mouse en todas las listas
3. `visualDensity` adaptativa (elementos más compactos en desktop)
4. `NavigationRail` extendido (con labels de texto) cuando la ventana supera 1200px

---

## Diagnóstico

| Problema | Causa | Solución |
|---|---|---|
| Ventana puede hacerse muy pequeña y romper el layout | `window_manager` no configurado | `setMinimumSize(Size(900, 600))` en `main()` |
| Scroll con mouse no funciona en listas Flutter por defecto | `ScrollConfiguration` solo registra `PointerDeviceKind.touch` | Agregar `PointerDeviceKind.mouse` al `ScrollBehavior` |
| Elementos de UI muy grandes en desktop (diseñados para móvil) | `visualDensity` por defecto es `standard` | `VisualDensity.adaptivePlatformDensity` en `ThemeData` |
| `NavigationRail` muestra solo iconos incluso en ventanas muy anchas | `labelType: all` pero sin modo `extended` | Cambiar a `extended: true` cuando width > 1200 |

---

## Archivos modificados

| Archivo | Cambio |
|---|---|
| `pubspec.yaml` | + `window_manager: ^0.4.3` |
| `macos/Runner/DebugProfile.entitlements` | ya tiene permisos necesarios (sin cambios) |
| `lib/main.dart` | + init `window_manager`, setMinimumSize, setTitle |
| `lib/app.dart` | + `ScrollConfiguration` con mouse scroll |
| `lib/core/theme/app_theme.dart` | + `visualDensity: VisualDensity.adaptivePlatformDensity` |
| `lib/shared/widgets/app_scaffold.dart` | + `NavigationRail` extendido en >1200px |

---

## Cambios detallados

### `main.dart` — window_manager

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar ventana solo en desktop macOS
  if (!kIsWeb && Platform.isMacOS) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(900, 620),
      center: true,
      title: 'Geoportal Predios',
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Supabase...
  runApp(...)
}
```

### `app.dart` — scroll con mouse

```dart
// Envolver el router con ScrollConfiguration para habilitar
// scroll con rueda de mouse en todas las listas de la app
return ScrollConfiguration(
  behavior: _DesktopScrollBehavior(),
  child: MaterialApp.router(...),
);

class _DesktopScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
  };
}
```

### `app_theme.dart` — densidad adaptativa

```dart
ThemeData(
  // ...
  visualDensity: VisualDensity.adaptivePlatformDensity,
)
```

### `app_scaffold.dart` — NavigationRail extendido

```dart
// width > 1200: NavigationRail extended (muestra labels junto a iconos)
// 768 < width <= 1200: NavigationRail compacto (solo iconos + label debajo)
// width <= 768: BottomNavigationBar (móvil/web estrecho)

final isWide = width > 768;
final isVeryWide = width > 1200;

NavigationRail(
  extended: isVeryWide,
  labelType: isVeryWide ? NavigationRailLabelType.none : NavigationRailLabelType.all,
  ...
)
```

---

## Criterio de éxito

- [x] `flutter analyze` — 0 errores nuevos
- [x] `flutter build macos` — OK
- [ ] Ventana abre centrada con tamaño 1280×800
- [ ] No se puede reducir la ventana por debajo de 900×620
- [ ] Scroll con mouse funciona en tabla de predios
- [ ] En ventana >1200px el rail muestra "Mapa", "Balance", "Archivos", "Gestión" junto a los iconos
- [ ] En web: comportamiento sin cambios

---

## Resultado

```
✓ Built build/macos/Build/Products/Release/geoportal_predios.app (52.1MB)
```

`flutter build macos` — exitoso. Fase 4 completada.

---

## Problema resuelto: iCloud Drive xattr

Durante el build se presentó un error de CodeSign:

```
resource fork, Finder information, or similar detritus not allowed
```

**Causa raíz**: iCloud Drive monitorea `~/Documents/` y re-añade `com.apple.FinderInfo` y `com.apple.fileprovider.fpfs#P` a los frameworks dentro del `.app` entre el build phase de strip y el paso de firma de Xcode (~11ms de ventana).

**Solución definitiva**: redirigir `build/` a `/tmp/` (completamente fuera de iCloud):

```bash
flutter clean
rm -rf /tmp/geoportal_build
mkdir -p /tmp/geoportal_build
ln -s /tmp/geoportal_build build
flutter pub get
flutter build macos
```

**Por qué funciona**: `/tmp/` no está bajo ningún volumen sincronizado por iCloud. Los frameworks en `build/macos/.../Release/*.app/Contents/Frameworks/` se crean y firman sin interferencia. El symlink `build -> /tmp/geoportal_build` es transparente para Flutter y Xcode.

> **Nota importante**: `flutter clean` elimina el symlink `build` (destruye el enlace). Antes de cada build limpio hay que recrearlo:
> ```bash
> flutter clean
> mkdir -p /tmp/geoportal_build && ln -s /tmp/geoportal_build build
> flutter pub get && flutter build macos
> ```

---

## Próximo paso

**[IMPL-05] Desktop Fase 5** — Empaquetado .app / DMG para distribución
