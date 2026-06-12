# IMPL_46 - Enter de teclado en pantalla inicial de acceso

- Estado: Completado
- Fecha: 2026-06-03
- Rama: desktop/fase-1

## 1. Objetivo
Habilitar que al presionar Enter en la pantalla inicial de autenticacion se lean las credenciales capturadas y se ejecute el flujo de acceso existente.

## 2. Diagnostico / contexto actual
La pantalla de login solo disparaba el acceso desde el boton de iniciar sesion. No habia una accion explicita asociada a Enter en los campos de correo y contrasena.

## 3. Fases
### Fase 1: Enlace de Enter al flujo de autenticacion
- Descripcion: Se conecto Enter al mismo metodo `_submit()` para evitar duplicar logica de validacion y acceso.
- Archivos afectados:
  - `lib/features/auth/presentation/login_screen.dart`
- Codigo clave:
  - `textInputAction: TextInputAction.next` en correo
  - `onFieldSubmitted` en correo para mover foco a contrasena
  - `focusNode` para contrasena
  - `textInputAction: TextInputAction.done` en contrasena
  - `onFieldSubmitted` en contrasena para ejecutar `_submit()`
- Tiempo estimado: 20 minutos
- Riesgo: Bajo (cambio de UI controlado, reutiliza flujo existente)

### Fase 2: Validacion tecnica
- Descripcion: Se verifico que el archivo modificado no introdujera errores de analisis.
- Archivos afectados:
  - `lib/features/auth/presentation/login_screen.dart`
- Codigo clave:
  - Revision de errores del archivo con herramientas del workspace
- Tiempo estimado: 5 minutos
- Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 20 min | Bajo |
| Fase 2 | 5 min | Bajo |
| Total | 25 min | Bajo |

## 5. Criterio de exito
- Enter en campo correo mueve el foco a contrasena.
- Enter en campo contrasena ejecuta autenticacion con las credenciales capturadas.
- No se altera la logica de validacion ni la logica de roles/proyecto.

## 6. Resultado / evidencia
- Implementacion aplicada en `login_screen.dart`.
- Verificacion de analisis: sin errores en el archivo modificado.

## 7. Proximo paso
Probar manualmente en desktop y web:
1. Capturar correo y presionar Enter para validar cambio de foco.
2. Capturar contrasena y presionar Enter para confirmar acceso.
3. Verificar que, con `_loading = true`, no se dispare un envio adicional.
