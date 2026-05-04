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
