# IMPL_33 Instalacion macOS Applications + Watch Fallback

- Estado: Completado
- Fecha: 2026-05-14
- Rama: desktop/fase-1

## 1. Objetivo
Instalar la aplicacion de escritorio en Applications y habilitar actualizacion automatica por cambios de codigo, incluso cuando no exista `fswatch` en el equipo.

## 2. Diagnostico / contexto actual
- La instalacion inicial fallaba por firma de codigo con error de atributos extendidos: `resource fork, Finder information, or similar detritus not allowed`.
- El modo `--watch` fallaba si `fswatch` no estaba instalado.
- Se necesitaba un flujo confiable para "instalar una vez" y "actualizar en cada cambio" en macOS.

## 3. Fases

### Fase 1: Mitigacion de CodeSign en build
- Descripcion: Se movio la compilacion a un arbol limpio temporal en `/tmp` para evitar metadatos de Finder del workspace principal.
- Archivos afectados: `scripts/install_macos_app.sh`
- Codigo clave:
  - Copia limpia con `rsync` excluyendo `build`, `.dart_tool`, `.git`.
  - Limpieza con `xattr -cr` antes y despues de instalar.
- Tiempo estimado: 20 min
- Riesgo: Bajo (flujo encapsulado en script)

### Fase 2: Instalacion en Applications
- Descripcion: Se conserva instalacion a `/Applications` con fallback a `~/Applications` si no hay permisos de escritura.
- Archivos afectados: `scripts/install_macos_app.sh`
- Codigo clave:
  - `ditto` para copiar `.app`
  - limpieza `xattr` en destino
- Tiempo estimado: 10 min
- Riesgo: Bajo

### Fase 3: Watch robusto con fallback sin dependencias
- Descripcion: Se implemento monitoreo dual: usa `fswatch` si existe, y si no, usa sondeo por huella de archivos cada 2 segundos.
- Archivos afectados: `scripts/install_macos_app.sh`
- Codigo clave:
  - Construccion dinamica de rutas validas a monitorear
  - `compute_fingerprint()` con `find + stat + shasum`
  - ciclo de reinstalacion al detectar cambios
- Tiempo estimado: 25 min
- Riesgo: Medio (sondeo puede consumir mas recursos que `fswatch`)

## 4. Resumen de esfuerzo

| Fase | Tiempo | Riesgo |
|---|---:|---|
| Fase 1 | 20 min | Bajo |
| Fase 2 | 10 min | Bajo |
| Fase 3 | 25 min | Medio |
| **Total** | **55 min** | **Bajo-Medio** |

## 5. Criterio de exito
- Script instala la app en Applications sin error de CodeSign.
- App puede abrirse desde Applications.
- Modo `--watch` no termina con error aunque `fswatch` no este instalado.
- Los cambios en rutas monitoreadas disparan reinstalacion automatica.

## 6. Resultado / evidencia
- Instalacion exitosa:
  - `✓ Built build/macos/Build/Products/Debug/geoportal_predios.app`
  - `[install] Listo: /Applications/geoportal_predios.app`
- Apertura de app desde Applications ejecutada con `open -a /Applications/geoportal_predios.app`.
- Fallback de watch implementado en script para equipos sin `fswatch`.

## 7. Proximo paso
- Ejecutar `./scripts/install_macos_app.sh --mode debug --watch` durante desarrollo diario.
- Opcional: instalar `fswatch` con `brew install fswatch` para monitoreo mas eficiente.
