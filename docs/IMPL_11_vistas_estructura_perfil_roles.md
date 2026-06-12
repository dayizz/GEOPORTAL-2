# IMPL_11 - Vistas Estructura y Perfil con Roles y Guardias

- Estado: Implementado
- Fecha: 2026-05-12
- Rama: desktop/fase-1

## 1. Objetivo
Agregar dos vistas nuevas en la app:
- Estructura: control de usuarios con nombre, correo, perfil y proyecto.
- Perfil: cuenta personal con datos del usuario, ultima operacion y cierre de sesion.

Implementar control de acceso para que solo Administrador vea y use Estructura, incluyendo guardias de ruta.

## 2. Diagnostico / contexto actual
La navegacion principal solo tenia Mapa, Gestion, Balance y Archivos.
No existia vista de perfil de cuenta, no habia una vista de control de usuarios y tampoco habia guardias por rol para rutas funcionales.

## 3. Fases
### Fase 1 - Estado global de usuario y roles
- Descripcion: Se creo un gestor de estado global con Riverpod para controlar usuarios, sesion actual, perfil y permisos.
- Archivos afectados:
  - lib/features/auth/providers/user_management_provider.dart
- Codigo clave:
  - enum UserProfile (administrador, colaborador)
  - userManagementProvider
  - currentAppUserProvider
  - canAccessEstructuraProvider
- Tiempo estimado: 40 min
- Riesgo: Medio (impacta permisos y visibilidad global)

### Fase 2 - Vista Estructura (admin)
- Descripcion: Se creo pantalla de listado y edicion de usuarios (nombre, correo, perfil, proyecto).
- Archivos afectados:
  - lib/features/estructura/presentation/estructura_screen.dart
- Codigo clave:
  - DataTable para control de usuarios
  - Dialogo de edicion de usuario
- Tiempo estimado: 45 min
- Riesgo: Bajo

### Fase 3 - Vista Perfil (usuario actual)
- Descripcion: Se creo pantalla de cuenta personal con datos y accion de cerrar sesion.
- Archivos afectados:
  - lib/features/perfil/presentation/perfil_screen.dart
- Codigo clave:
  - currentAppUserProvider para datos visibles
  - boton de cerrar sesion con limpieza de providers de auth/sesion
- Tiempo estimado: 30 min
- Riesgo: Bajo

### Fase 4 - Menu lateral con condicion por rol
- Descripcion: Se agregaron botones Perfil y Estructura, y Estructura se renderiza solo para administrador.
- Archivos afectados:
  - lib/shared/widgets/app_scaffold.dart
- Codigo clave:
  - navItems dinamico
  - condicional por canAccessEstructuraProvider
- Tiempo estimado: 35 min
- Riesgo: Medio

### Fase 5 - Guardias de ruta para Estructura
- Descripcion: Se protegieron rutas para impedir acceso por URL cuando el perfil no es administrador.
- Archivos afectados:
  - lib/core/router/app_router.dart
- Codigo clave:
  - redirect con validacion de ruta /estructura
  - alta de rutas /perfil y /estructura
- Tiempo estimado: 35 min
- Riesgo: Medio

## 4. Resumen de esfuerzo
| Fase | Esfuerzo |
|---|---|
| Estado global de usuario y roles | Medio |
| Vista Estructura | Bajo |
| Vista Perfil | Bajo |
| Menu lateral condicional | Medio |
| Guardias de ruta | Medio |

## 5. Criterio de exito
- Se visualiza Perfil en el menu lateral para usuarios autenticados.
- Estructura solo se visualiza para perfil Administrador.
- Ruta /estructura bloqueada para Colaborador (guardia de ruta activa).
- Vista Perfil muestra nombre, correo, perfil, proyecto y ultima operacion.
- Desde Perfil se puede cerrar sesion correctamente.

## 6. Resultado / evidencia
- Nuevos providers globales de gestion de usuario y permisos.
- Nuevas rutas: /perfil y /estructura.
- Boton Estructura condicionado por perfil administrador.
- Login sincroniza perfil y proyecto hacia estado global.
- Persistencia local de usuarios en SharedPreferences (`estructura_usuarios_v1`).
- Estructura ahora permite alta, edicion y baja de usuarios.
- Validacion estatica: archivos modificados sin errores.

## 7. Proximo paso
Conectar la lista de Estructura a backend remoto (tabla dedicada) para administracion multi-dispositivo y auditoria centralizada.
