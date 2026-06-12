# IMPL_12 - Persistencia remota para Estructura

- Estado: Implementado
- Fecha: 2026-05-12
- Rama: desktop/fase-1

## 1. Objetivo
Conectar el módulo Estructura a persistencia remota para que el control de usuarios (alta, edición y baja) se comparta entre dispositivos.

## 2. Diagnóstico / contexto actual
El módulo Estructura ya contaba con estado global y persistencia local (SharedPreferences), pero los cambios no se sincronizaban entre equipos ni sesiones en diferentes dispositivos.

## 3. Fases
### Fase 1 - Repositorio remoto de usuarios
- Descripción: Se creó un repositorio dedicado para CRUD en Supabase.
- Archivos afectados:
  - lib/features/auth/data/estructura_users_repository.dart
- Código clave:
  - `getUsers()`
  - `upsertUser()`
  - `deleteUser()`
- Tiempo estimado: 30 min
- Riesgo: Medio (dependencia de infraestructura remota)

### Fase 2 - Sincronización del gestor global
- Descripción: El provider global ahora hidrata desde remoto con fallback local, y sincroniza operaciones de alta/edición/baja en ambos orígenes.
- Archivos afectados:
  - lib/features/auth/providers/user_management_provider.dart
- Código clave:
  - `_safeRemoteLoad`, `_safeRemoteUpsert`, `_safeRemoteDelete`
  - `_syncAllRemote`
  - fallback local cuando remoto no está disponible
- Tiempo estimado: 45 min
- Riesgo: Medio

### Fase 3 - Esquema y políticas de seguridad
- Descripción: Se agregó tabla `usuarios_estructura` y políticas RLS para usuarios autenticados.
- Archivos afectados:
  - supabase_schema.sql
- Código clave:
  - creación de tabla, índices y políticas SELECT/INSERT/UPDATE/DELETE
- Tiempo estimado: 25 min
- Riesgo: Medio

## 4. Resumen de esfuerzo
| Fase | Esfuerzo |
|---|---|
| Repositorio remoto | Medio |
| Sincronización de estado global | Medio |
| SQL + RLS | Medio |

## 5. Criterio de éxito
- Estructura conserva datos localmente y además sincroniza a Supabase cuando está disponible.
- Al iniciar, la app prioriza datos remotos; si falla, usa persistencia local.
- Alta/edición/baja de usuarios queda reflejada en la tabla `usuarios_estructura`.

## 6. Resultado / evidencia
- Nuevo repositorio remoto para usuarios de estructura.
- Provider global sincronizado con remoto + fallback local.
- Tabla `usuarios_estructura` con políticas RLS agregada al script SQL.
- Validación estática sin errores en archivos modificados.

## 7. Próximo paso
Crear endpoint/backend de auditoría para registrar quién modifica cada usuario y desde qué módulo/pantalla.
