# IMPL_14: Instalacion Desktop macOS con Actualizaciones

Estado: Completado
Fecha: 13 de mayo de 2026
Rama: desktop/fase-1

## 1. Objetivo
Instalar en esta Mac la version mas reciente del programa de escritorio con todas las actualizaciones del proyecto.

## 2. Diagnostico / contexto actual
- La app compilo correctamente en Debug y Release durante las validaciones previas.
- Se detecto un error de CodeSign por metadatos extendidos de macOS en el bundle de build.

## 3. Fases

### Fase A: Compilacion Release actualizada
Descripcion:
- Se ejecuto limpieza, resolucion de dependencias y build en modo Release.

Archivos afectados:
- pubspec.lock (actualizacion de dependencias resueltas)
- build/macos/Build/Products/Release/geoportal_predios.app

Codigo/Comandos clave:
- flutter clean
- flutter pub get
- flutter build macos --release

Tiempo estimado: 10 min
Riesgo: Bajo

### Fase B: Correccion de firma local (CodeSign)
Descripcion:
- Se limpio xattr en el proyecto para eliminar resource fork/Finder metadata que bloqueaban la firma local.

Archivos afectados:
- Estructura local del proyecto (atributos extendidos)

Codigo/Comandos clave:
- xattr -cr .
- rm -rf build/macos
- flutter build macos --release

Tiempo estimado: 5 min
Riesgo: Bajo

### Fase C: Instalacion en Applications
Descripcion:
- Se copio el bundle Release a Applications reemplazando la version previa.

Archivos afectados:
- /Applications/geoportal_predios.app

Codigo/Comandos clave:
- cp -R build/macos/Build/Products/Release/geoportal_predios.app /Applications/geoportal_predios.app

Tiempo estimado: 2 min
Riesgo: Bajo

## 4. Resumen de esfuerzo
| Fase | Tiempo | Riesgo | Estado |
|---|---:|---|---|
| A. Build Release | 10 min | Bajo | Completado |
| B. Fix CodeSign local | 5 min | Bajo | Completado |
| C. Instalacion app | 2 min | Bajo | Completado |
| Total | 17 min | Bajo | Completado |

## 5. Criterio de exito
- Build Release generado sin errores.
- App instalada en Applications.
- App lista para abrirse localmente en macOS.

## 6. Resultado / evidencia
- Build exitoso:
  - build/macos/Build/Products/Release/geoportal_predios.app (53.3MB)
- Instalacion final:
  - /Applications/geoportal_predios.app

## 7. Proximo paso
- Validacion funcional en interfaz:
  - Abrir app instalada
  - Verificar flujo OCR en Gestion con PDF real de Google Drive
  - Confirmar auto-relleno de km inicio, km fin, m2 y fecha de firma
