# Geoportal Predios - Descripción del proyecto

## 1. ¿Qué es este proyecto?

Geoportal Predios es una aplicación Flutter para gestión catastral y territorial.
Permite visualizar predios en mapa, administrar información de propietarios, importar archivos geoespaciales (GeoJSON) y generar reportes operativos por proyecto.

Está pensada para trabajar con una base de datos en Supabase (PostgreSQL), con una capa de autenticación y persistencia de archivos importados.

## 2. ¿Qué hace la aplicación?

La aplicación cubre cuatro frentes principales:

1. Mapa
- Muestra predios georreferenciados y capas base para análisis visual.
- Permite resaltar/ubicar predios desde otras vistas de la app.

2. Gestión de predios y propietarios
- CRUD de predios.
- CRUD de propietarios.
- Asociación entre predio y propietario.
- Filtros y búsqueda por clave catastral, propietario, zona y otros campos.

3. Carga y sincronización geoespacial
- Importa archivos GeoJSON.
- Normaliza propiedades de entrada y detecta alias de campos.
- Sincroniza contra la base de datos por clave catastral:
  - Si el predio existe, enriquece y actualiza campos faltantes.
  - Si no existe, crea predio (y propietario cuando aplica).
- Guarda los archivos importados y métricas de sincronización (encontrados, creados, errores).

4. Reportes y balance
- Muestra KPIs y gráficas (ej. total de predios, COP firmados, superficie DDV).
- Segmenta por proyecto (TQI, TSNL, TAP, TQM).
- Desglosa métricas por tipo de propiedad y tramo.

## 3. ¿Cómo está construido? (arquitectura)

### Stack principal
- Flutter + Dart (SDK ^3.11.4)
- Estado: Riverpod
- Navegación: GoRouter
- Backend: Supabase (Auth, Postgres, Storage)
- Mapa: flutter_map + GeoJSON
- Visualización de métricas: fl_chart

### Estructura general
- lib/main.dart
  - Inicializa Flutter y Supabase.
- lib/app.dart
  - Configura MaterialApp.router con tema y enrutamiento.
- lib/core/
  - Configuración global (router, tema, constantes, supabase config).
- lib/features/
  - auth: autenticación.
  - mapa: visualización y estado del mapa.
  - predios: modelos, repositorios, providers y pantallas de predios.
  - propietarios: modelos, repositorios, providers y pantallas de propietarios.
  - carga: importación GeoJSON, parseo y sincronización.
  - reportes: pantalla de indicadores y gráficas.
  - tabla: pantalla de gestión tabular por proyecto.
- lib/shared/widgets/
  - Componentes compartidos (por ejemplo, el scaffold de navegación principal).

### Patrón de capas por feature
En la mayoría de módulos se usa una separación simple:
- presentation: pantallas/widgets.
- providers: estado y lógica de orquestación (Riverpod).
- data: acceso a Supabase (repositorios).
- models: entidades de dominio.

## 4. ¿Cómo funciona internamente? (flujo técnico)

### Inicio y autenticación
1. main() inicializa Supabase con SupabaseConfig.
2. Se crea el árbol de providers con ProviderScope.
3. GoRouter aplica un redirect por estado de sesión.
4. Si no hay sesión, envía a /login.

Nota: actualmente está activado localOnlyAuthMode = true.
- Credenciales locales habilitadas: admin@sao.mx / admin123.
- En este modo no se permite registro ni reset de contraseña.

### Navegación funcional
La navegación principal agrupa módulos en:
- /mapa
- /reportes
- /carga
- /tabla

También existen rutas para predios y propietarios (listado, detalle, alta, edición), además de /proyectos.

### Flujo de datos de predios
1. UI solicita datos mediante providers.
2. Providers consultan repositorios de Supabase.
3. Los resultados remotos se combinan con estado local temporal (cuando aplica).
4. La UI renderiza listas, detalles, filtros y estadísticas.

### Flujo de importación GeoJSON
1. Usuario selecciona archivo (.geojson o .json).
2. El archivo se parsea y normaliza a FeatureCollection.
3. Se enriquecen features (clave catastral, superficie, propiedades detectadas).
4. SincronizacionService procesa feature por feature:
- Busca por clave catastral.
- Si encuentra, inyecta datos de gestión/propietario y completa campos vacíos.
- Si no encuentra, crea nuevo predio y, cuando hay datos suficientes, propietario asociado.
5. Se guarda el archivo sincronizado en la tabla archivos_geojson.
6. Se actualiza el estado de importación para reflejar progreso/resultado en UI.

### Reportes
1. Se toma el conjunto de predios disponible.
2. Se filtra por proyecto activo.
3. Se calculan métricas de conteo y superficie.
4. Se presentan tarjetas KPI, barras DDV, pastel por tipo y barras por tramo.

## 5. Modelo de datos (resumen)

Según el script supabase_schema.sql, las entidades principales son:

1. propietarios
- Datos personales/fiscales y de contacto.

2. predios
- Identificación catastral, datos de ubicación, atributos de gestión y geometría (JSONB).
- Relación opcional con propietarios.

3. archivos_geojson
- Persistencia del archivo importado y sus features.
- Resultado de sincronización (encontrados, creados, errores).

Además:
- Se habilita RLS.
- Las políticas permiten operaciones a usuarios autenticados.
- Existe bucket de Storage: predios-archivos.

## 6. Configuración requerida

1. Backend
- Crear proyecto en Supabase.
- Ejecutar supabase_schema.sql en SQL Editor.

### Opción alterna: Google Sheets como base de datos

El proyecto ya puede operar con Google Sheets como backend de datos para:
- predios
- propietarios
- archivos_geojson

Configuración:
- Archivo: lib/core/google_sheets/google_sheets_config.dart
- enabled = true para activar Google Sheets
- webAppUrl = URL del Web App de Apps Script
- scriptId = ID del script (opcional, se envía por compatibilidad)

Contrato esperado del Web App (recomendado):
- GET con action=list y sheet=<nombre> devuelve filas del sheet.
- POST con JSON action=upsert y sheet=<nombre> inserta/actualiza por id.
- POST con JSON action=delete y sheet=<nombre> elimina por id.

Formato de respuesta soportado por la app:
- Lista de objetos JSON [{...}, {...}]
- o matriz 2D [[header1, header2], [v1, v2], ...]
- o { data: [...] } / { rows: [...] }

Notas:
- Si tu Apps Script solo implementa doGet, el cliente intenta fallback por GET para upsert/delete.
- Si Google Sheets está activo, los repositorios usan Sheets y mantienen Supabase como fallback cuando está desactivado.
- Se incluye plantilla lista para pegar en Apps Script: google_sheets_backend.gs
- Para importaciones muy grandes, el historial de archivos en Sheets guarda una muestra limitada de `features` para evitar errores por tamano de payload/URL.
- En cargas grandes, prioriza que `doPost` funcione correctamente en Apps Script para no depender del fallback GET.

2. Credenciales
- Editar lib/core/supabase/supabase_config.dart con URL y anon key reales.

3. Dependencias
- flutter pub get

4. Ejecución
- flutter run -d chrome
  o
- flutter run -d macos

## 7. Estado actual y observaciones

- El README actual está en plantilla base de Flutter y no describe el sistema.
- El proyecto sí contiene una implementación funcional de geoportal con módulos de negocio claros.
- La autenticación está en modo local por defecto (útil para pruebas rápidas).

## 8. Resumen ejecutivo

Este proyecto implementa un geoportal operativo para gestión de predios:
- centraliza información catastral,
- integra cartografía GeoJSON,
- sincroniza datos geoespaciales con base de datos,
- y entrega vista analítica para seguimiento de avance por proyecto.

## 9. Mejoras recomendadas en importación GeoJSON y vínculo Mapa-BD

1. Rendimiento de sincronización
- Evitar consultas repetidas por la misma clave catastral durante una importación masiva.
- Aplicar caché por lote (clave catastral -> predio) para reducir roundtrips.
- Procesar en concurrencia controlada por carriles; las features con la misma clave catastral se asignan al mismo carril para evitar colisiones/duplicados.
- Aplicar reintentos automáticos con backoff exponencial en operaciones críticas (buscar, crear y actualizar predios; vincular propietario) para tolerar fallos transitorios de red/servicio.
- Mostrar progreso real en UI (procesados/total y porcentaje) durante la sincronización para cargas grandes.

2. Trazabilidad del vínculo
- Enriquecer `properties` de cada feature con metadatos de enlace:
  - `_syncStatus` (`linked` o `error`)
  - `_syncAt` (timestamp)
  - `_syncSource` (`geojson_import`)
  - `predio_id` y `clave_catastral_db`

3. Cargas grandes en Google Sheets
- Mantener `doPost` operativo para `upsert/delete`.
- Evitar depender de GET para payloads grandes.
- Guardar en historial una muestra de `features` y conservar `features_count` total.

4. Diagnóstico de importación
- La pantalla de carga puede exportar reporte de errores de sincronización en `JSON` y `CSV`.
- El reporte toma las features con `_syncStatus = error` y los mensajes de error acumulados del proceso.

---

## 10. Implementación: Flutter Web → Aplicación de Escritorio (macOS)

### Objetivo

Convertir el geoportal de una aplicación web (Flutter Web) a una **aplicación nativa de escritorio para macOS**, conservando toda la funcionalidad existente y adaptando la experiencia de usuario a entorno de escritorio.

---

### Diagnóstico de compatibilidad actual

El código base es **~85 % compatible** con macOS sin cambios. Los problemas identificados son puntuales y están en 3 archivos.

| Código / paquete | Problema | Impacto |
|---|---|---|
| `launchUrl(..., webOnlyWindowName: '_blank')` | Parámetro exclusivo de web | Build falla en macOS |
| `Share.shareXFiles(...)` | Funciona en macOS (panel nativo) | Sin cambio |
| `FilePicker.pickFiles(withData: true)` | En web devuelve bytes en memoria; en desktop devuelve path | Leer bytes con `dart:io` desde el path |
| `shared_preferences` | En web → localStorage; en macOS → NSUserDefaults | Funciona sin cambios |
| `CodeSign failed` (build actual) | Atributos extendidos de macOS en carpeta `build/` | Limpiar con `xattr` y agregar entitlements |

---

### Fases de implementación

---

#### Fase 1 — Arreglar el build de macOS
**Duración estimada: 30 minutos**
**Riesgo: Bajo**

El único error de build actual es una falla de firma de código causada por atributos extendidos (`resource fork / Finder detritus`) en el directorio `build/macos/`.

**Pasos:**

1. Limpiar atributos extendidos:
   ```bash
   xattr -cr build/macos
   flutter build macos
   ```

2. Agregar entitlements de red y archivos en `macos/Runner/DebugProfile.entitlements` y `macos/Runner/Release.entitlements`:
   ```xml
   <!-- Red (para mapas, Supabase, HTTP) -->
   <key>com.apple.security.network.client</key>
   <true/>
   <!-- Acceso a archivos seleccionados por el usuario (FilePicker) -->
   <key>com.apple.security.files.user-selected.read-only</key>
   <true/>
   ```

3. Verificar que el app abre correctamente con `flutter run -d macos`.

**Archivos a modificar:**
- `macos/Runner/DebugProfile.entitlements`
- `macos/Runner/Release.entitlements`

---

#### Fase 2 — Adaptar APIs web-específicas
**Duración estimada: 1–2 horas**
**Riesgo: Bajo**

Hay 3 usos de APIs que tienen comportamiento diferente en web vs desktop.

**2.1 — `webOnlyWindowName` en `launchUrl`**

Archivos afectados:
- `lib/features/predios/presentation/predio_form_screen.dart` (línea 154)
- `lib/features/tabla/presentation/tabla_screen.dart` (línea 665)

Cambio:
```dart
// ANTES (web)
await launchUrl(uri, webOnlyWindowName: '_blank');

// DESPUÉS (multiplataforma)
await launchUrl(uri, mode: LaunchMode.externalApplication);
```

**2.2 — `FilePicker` con lectura de bytes**

En web, `pickFiles(withData: true)` devuelve los bytes directamente en `result.files.first.bytes`.
En macOS, devuelve el path en `result.files.first.path` y los bytes se leen con `dart:io`.

Archivos afectados:
- `lib/features/carga/presentation/carga_archivo_screen.dart` (línea 98)
- `lib/features/tabla/presentation/tabla_screen.dart` (línea 678)

Patrón de solución:
```dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

Uint8List bytes;
if (kIsWeb) {
  bytes = result.files.first.bytes!;
} else {
  bytes = await File(result.files.first.path!).readAsBytes();
}
```

**2.3 — `Share.shareXFiles` (sin cambio)**

`share_plus` en macOS muestra el panel nativo de compartir del sistema operativo. No requiere modificación.

---

#### Fase 3 — Persistencia en escritorio
**Duración estimada: 30 minutos**
**Riesgo: Bajo**

| Dato | Web | macOS |
|---|---|---|
| Archivos importados (metadata) | `shared_preferences` → localStorage | `shared_preferences` → NSUserDefaults ✅ |
| Predios locales | `shared_preferences` | `shared_preferences` ✅ |
| GeoJSON completo (archivos grandes) | Limitado a ~5 MB en localStorage | Guardar en `Documents/` con `path_provider` + `dart:io` |

Para soportar archivos grandes en desktop, `LocalArchivosRepository` puede extenderse con una segunda estrategia:

```dart
// En desktop: guardar features completas en archivo JSON en Documents/
final dir = await getApplicationDocumentsDirectory();
final file = File('${dir.path}/geoportal/archivo_$id.json');
await file.writeAsString(jsonEncode(features));
```

**Paquete necesario (ya disponible):**
- `path_provider` — solo se necesita re-agregar a `pubspec.yaml` para desktop.

---

#### Fase 4 — UX de escritorio (AppScaffold y navegación)
**Duración estimada: 2–3 horas**
**Riesgo: Medio**

La navegación actual usa una **barra inferior** (`BottomNavigationBar`) optimizada para móvil/web. En escritorio la convención es un **panel lateral** permanente (sidebar).

**4.1 — Rediseño de `AppScaffold`**

`lib/shared/widgets/app_scaffold.dart` es el único punto de cambio para toda la navegación.

Estrategia multiplataforma:
```dart
// Detectar si es escritorio
final isDesktop = !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

if (isDesktop) {
  // Sidebar: NavigationRail o Drawer permanente
  return Scaffold(
    body: Row(
      children: [
        NavigationRail(destinations: [...], selectedIndex: currentIndex, ...),
        const VerticalDivider(width: 1),
        Expanded(child: body),
      ],
    ),
  );
} else {
  // Barra inferior (comportamiento actual)
  return Scaffold(bottomNavigationBar: ..., body: body);
}
```

**4.2 — Tamaño de ventana mínimo**

Agregar `window_manager` para fijar tamaño mínimo y título de la ventana:

```yaml
# pubspec.yaml
window_manager: ^0.4.0
```

```dart
// main.dart
import 'package:window_manager/window_manager.dart';

await windowManager.ensureInitialized();
windowManager.waitUntilReadyToShow(
  const WindowOptions(
    minimumSize: Size(1100, 700),
    title: 'Geoportal LDDV',
  ),
  () async => await windowManager.show(),
);
```

**4.3 — Scroll con rueda del mouse**

En escritorio el scroll táctil no funciona. Agregar `ScrollConfiguration` global en `app.dart`:

```dart
ScrollConfiguration(
  behavior: ScrollConfiguration.of(context).copyWith(
    scrollbars: true,
    dragDevices: {PointerDeviceKind.mouse, PointerDeviceKind.touch},
  ),
  child: MaterialApp.router(...),
)
```

**4.4 — Densidad de UI**

Agregar `visualDensity` compacta para escritorio en `AppTheme`:

```dart
ThemeData(
  visualDensity: VisualDensity.adaptivePlatformDensity,
  ...
)
```

---

#### Fase 5 — Empaquetado y distribución macOS
**Duración estimada: 1 hora**
**Riesgo: Bajo–Medio**

| Opción | Descripción | Recomendado |
|---|---|---|
| `flutter build macos` | Genera `.app` en `build/macos/Build/Products/Release/` | ✅ Para uso interno |
| DMG manual | Empaquetar el `.app` en un DMG con `hdiutil` | Para distribución |
| Notarización Apple | Firma y envío a Apple para distribución fuera del App Store | Solo si se distribuye externamente |

Para uso interno en el equipo, el `.app` generado directamente es suficiente. Se puede copiar a `/Applications` o distribuir por carpeta compartida.

---

### Resumen de esfuerzo

| Fase | Tarea principal | Tiempo estimado | Riesgo |
|---|---|---|---|
| 1 | Arreglar build macOS (entitlements + xattr) | 30 min | Bajo |
| 2 | Adaptar APIs web-específicas (3 puntos) | 1–2 h | Bajo |
| 3 | Persistencia desktop (path_provider para archivos grandes) | 30 min | Bajo |
| 4 | UX escritorio (sidebar, ventana, scroll) | 2–3 h | Medio |
| 5 | Empaquetado `.app` / DMG | 1 h | Bajo |
| **Total** | | **~5–7 horas** | **Bajo–Medio** |

---

### Orden de ejecución recomendado

```
Fase 1 → Fase 2 → build macos funcional ✓
         ↓
      Fase 3 → Fase 4 → Fase 5 → App lista para distribución
```

Se recomienda completar Fases 1 y 2 primero para tener la app corriendo en macOS y poder probar funcionalidad completa antes de invertir tiempo en el rediseño de UI.

---

### Cambios en `pubspec.yaml`

```yaml
# Agregar (para desktop):
window_manager: ^0.4.0
path_provider: ^2.1.5   # re-agregar, fue removido en limpieza web

# Los demás paquetes ya son compatibles con macOS
```

---

### Notas de compatibilidad de paquetes

| Paquete | Web | macOS | Notas |
|---|---|---|---|
| `flutter_map` | ✅ | ✅ | Sin cambios |
| `flutter_riverpod` | ✅ | ✅ | Sin cambios |
| `go_router` | ✅ | ✅ | Sin cambios |
| `shared_preferences` | ✅ | ✅ | NSUserDefaults en macOS |
| `file_picker` | ✅ | ✅ | Leer bytes desde path en desktop |
| `url_launcher` | ✅ | ✅ | Quitar `webOnlyWindowName` |
| `share_plus` | ✅ | ✅ | Panel nativo macOS |
| `fl_chart` | ✅ | ✅ | Sin cambios |
| `supabase_flutter` | ✅ | ✅ | Sin cambios |
| `http` | ✅ | ✅ | Requiere entitlement `network.client` |


---

## 11. Implementaciones Desktop

Cada fase tiene su propio documento en la carpeta `docs/`:

| # | Documento | Estado |
|---|---|---|
| 1 | [docs/IMPL_01_desktop_fase1_build_macos.md](docs/IMPL_01_desktop_fase1_build_macos.md) | ✅ Completado |
| 2 | [docs/IMPL_02_desktop_fase2_apis_web_especificas.md](docs/IMPL_02_desktop_fase2_apis_web_especificas.md) | ✅ Completado |
| 3 | [docs/IMPL_03_desktop_fase3_path_provider.md](docs/IMPL_03_desktop_fase3_path_provider.md) | ✅ Completado |
| 4 | [docs/IMPL_04_desktop_fase4_ux_escritorio.md](docs/IMPL_04_desktop_fase4_ux_escritorio.md) | ✅ Completado |
| 5 | [docs/IMPL_05_desktop_fase5_empaquetado_dmg.md](docs/IMPL_05_desktop_fase5_empaquetado_dmg.md) | ✅ Completado |
| 6 | [docs/IMPL_06_desktop_fase6_firma_notarizacion.md](docs/IMPL_06_desktop_fase6_firma_notarizacion.md) | ✅ Ad-hoc / ⏳ Developer ID (requiere Apple Developer Program) |

