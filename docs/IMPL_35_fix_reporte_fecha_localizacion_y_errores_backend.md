# IMPL_35 - Fix Reporte: Fecha (Red Screen) y Errores de Generacion PDF

- Estado: Implementado
- Fecha: 2026-05-19
- Rama: desktop/fase-1

## 1. Objetivo
Corregir dos fallas en la seccion Reporte de Balance:
1) El selector de fecha mostraba Red Screen.
2) La generacion de reporte no mostraba la causa real del error cuando fallaba el backend.

## 2. Diagnostico / Contexto Actual
- El formulario de reporte usa `showDatePicker` con locale `es_MX`.
- La app no tenia `localizationsDelegates` ni `supportedLocales` configurados en `MaterialApp.router`.
- El servicio HTTP de reporte devolvia `null` para errores, sin diagnostico de timeout, backend caido o mensaje del servidor.

## 3. Fases

### Fase 1 - Localizacion de la App para DatePicker
- Descripcion: habilitar localizacion Material/Cupertino/Widgets y locale soportado.
- Archivos afectados:
  - `lib/app.dart`
  - `pubspec.yaml`
- Codigo clave:
  - Import `flutter_localizations`.
  - Configuracion `locale`, `supportedLocales`, `localizationsDelegates`.
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 2 - Diagnostico de Error en Generacion de Reporte
- Descripcion: mejorar `BackendService.generarReporte` para exponer causa real de falla.
- Archivos afectados:
  - `lib/shared/services/backend_service.dart`
- Codigo clave:
  - Manejo explicito de `TimeoutException`.
  - Manejo explicito de `SocketException`.
  - Parseo de `detail/message` en respuestas no 200.
- Tiempo estimado: 25 min
- Riesgo: Bajo

## 4. Resumen de Esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| Localizacion DatePicker | 20 min | Bajo |
| Diagnostico de errores backend | 25 min | Bajo |
| Total | 45 min | Bajo |

## 5. Criterio de Exito
- El boton de fecha abre el DatePicker sin Red Screen.
- Si falla la generacion, el usuario ve mensaje util (timeout, backend no disponible o error de servidor).
- Si el backend responde 200 con PDF, se genera y comparte correctamente.

## 6. Resultado / Evidencia
- Se agrego `flutter_localizations` en dependencias.
- `MaterialApp.router` ahora declara delegados y locales soportados.
- El servicio de backend ahora lanza errores explicitos con contexto de conexion y detalle HTTP.

## 7. Proximo Paso
- Validar en entorno local con backend levantado (`http://127.0.0.1:8000`) y ejecutar flujo completo en Balance > Reporte.
