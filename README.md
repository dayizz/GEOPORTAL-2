# Geoportal LDDV

Aplicación web Flutter para la gestión y visualización de predios catastrales del proyecto LDDV (Línea de Ducto De Vapor).

## Características

- **Mapa interactivo**: visualización de predios GeoJSON sobre capas OpenStreetMap
- **Carga de archivos**: importación de GeoJSON y XLSX con previsualización
- **Gestión de predios**: CRUD completo con campos catastrales, etapas y COP
- **Gestión de propietarios**: vinculación propietario-predio
- **Tabla de datos**: filtrado, paginación y exportación
- **Reportes**: estadísticas y gráficas por proyecto, etapa y estatus
- **Persistencia local**: los archivos importados se conservan en localStorage (SharedPreferences/web)

## Stack tecnológico

| Capa | Tecnología |
|---|---|
| Frontend | Flutter Web |
| Estado | Riverpod (`StateNotifierProvider`) |
| Navegación | go_router |
| Mapas | flutter_map + OpenStreetMap |
| Persistencia | shared_preferences (localStorage en web) |
| Backend (opcional) | FastAPI (`backend/`) |
| Base de datos (opcional) | Supabase (credenciales en `lib/core/supabase/supabase_config.dart`) |

## Estructura del proyecto

```
lib/
├── main.dart               # Punto de entrada, inicialización Supabase
├── app.dart                # MaterialApp + ThemeData
├── core/
│   ├── constants/          # AppColors, AppStrings
│   ├── router/             # app_router.dart (rutas go_router)
│   ├── supabase/           # SupabaseConfig (credenciales)
│   ├── theme/              # AppTheme
│   └── api/                # ApiClient (cliente HTTP para backend FastAPI)
├── features/
│   ├── auth/               # Login, providers de autenticación y demo
│   ├── carga/              # Importación de archivos GeoJSON/XLSX
│   │   ├── data/           # LocalArchivosRepository (localStorage)
│   │   ├── providers/      # carga_provider (lista de archivos importados)
│   │   ├── services/       # Parser GeoJSON background, XLSX, sincronización
│   │   └── utils/          # GeoJSON mapper
│   ├── mapa/               # Pantalla de mapa, mapa_provider
│   ├── predios/            # Modelo Predio, CRUD, lista, formulario, detalle
│   ├── propietarios/       # Modelo Propietario, CRUD, lista, detalle
│   ├── reportes/           # Pantalla de reportes y estadísticas
│   └── tabla/              # Tabla de gestión, detalle de gestión
└── shared/
    ├── services/           # BackendService (HTTP)
    └── widgets/            # AppScaffold (navbar/sidebar compartido)
```

## Configuración inicial

1. Clona el repositorio:
   ```bash
   git clone https://github.com/dayizz/GEOPORTAL-2.git
   cd GEOPORTAL-2
   ```

2. Instala dependencias:
   ```bash
   flutter pub get
   ```

3. (Opcional) Configura Supabase en `lib/core/supabase/supabase_config.dart`:
   ```dart
   static const String url = 'https://TU_PROJECT_ID.supabase.co';
   static const String anonKey = 'TU_ANON_KEY';
   ```
   Sin configuración válida, la app funciona en modo local (localStorage).

4. Construye para web:
   ```bash
   flutter build web
   ```

5. Sirve localmente:
   ```bash
   python3 -m http.server 8083 --directory build/web
   ```
   Abre `http://localhost:8083` en el navegador.

## Backend FastAPI (opcional)

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

## Ramas

| Rama | Descripción |
|---|---|
| `main` | Rama principal |
| `v1` | Primera versión estable: localStorage, reportes rediseñados, limpieza de código |
