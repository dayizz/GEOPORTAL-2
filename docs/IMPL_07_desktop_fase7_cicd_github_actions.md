# IMPL-07 — Desktop Fase 7: CI/CD GitHub Actions

**Estado:** ✅ Implementado  
**Fecha:** 2026-05-07  
**Rama:** `desktop/fase-1`  
**Proyecto:** geoportal-lddv  

---

## Objetivo

Automatizar el build macOS y generación del DMG en GitHub Actions al hacer push de un tag `v*`.

---

## Archivo

`.github/workflows/build_macos.yml`

---

## Triggers

| Evento | Condición | Resultado |
|---|---|---|
| `push` de tag | Tag que empiece con `v` (ej. `v1.0.0`) | Build + DMG + GitHub Release |
| `workflow_dispatch` | Manual desde GitHub Actions UI | Build + DMG (sin Release) |

---

## Pasos del workflow

```
1. checkout           — Clonar el repositorio
2. calcular versión   — Extraer "1.0.0" del tag "v1.0.0"
3. instalar Flutter   — subosito/flutter-action@v2 (Flutter 3.41.7, con caché)
4. flutter pub get    — Instalar dependencias
5. flutter analyze    — Verificar que no hay errores nuevos
6. flutter build macos --release
7. codesign (ad-hoc)  — Firma local sin Apple Developer Program
8. hdiutil create     — Genera dist/geoportal_predios_vX.Y.Z.dmg
9. upload-artifact    — Sube el DMG a los artefactos del run (30 días)
10. action-gh-release — Crea GitHub Release con el DMG adjunto (solo en tags)
```

---

## Cómo usar

### Publicar una nueva versión

```bash
git tag v1.1.0
git push origin v1.1.0
```

GitHub Actions ejecutará el workflow automáticamente y creará:
- `dist/geoportal_predios_v1.1.0.dmg` como artefacto del run
- Un GitHub Release `Geoportal Predios v1.1.0` con el DMG adjunto

### Ejecutar manualmente (sin release)

En GitHub: Actions → Build macOS DMG → Run workflow → ingresar versión

---

## Runner utilizado

`macos-latest` — macOS 15 Sequoia en GitHub Actions. No se necesita Mac propia para el CI.

> **Nota**: GitHub Actions en `macos-latest` NO tiene iCloud Drive, por lo que el problema de xattr que ocurre en desarrollo local no aplica en CI. No se necesita el symlink `build -> /tmp/geoportal_build`.

---

## Tiempo estimado de ejecución

| Paso | Tiempo |
|---|---|
| Instalar Flutter (sin caché) | ~3 min |
| Instalar Flutter (con caché) | ~30 seg |
| `flutter pub get` | ~1 min |
| `flutter build macos` | ~5-8 min |
| Firma + DMG | ~30 seg |
| **Total (con caché)** | **~8-10 min** |

---

## Artefactos generados

- **GitHub Release**: `https://github.com/dayizz/GEOPORTAL-2/releases`
- **Artefacto de run**: disponible en la pestaña Actions por 30 días

---

## Criterio de éxito

- [x] `.github/workflows/build_macos.yml` creado
- [x] Trigger en `push` de tag `v*` y `workflow_dispatch`
- [x] Flutter 3.41.7 con caché
- [x] Firma ad-hoc incluida
- [x] DMG subido como artefacto y como GitHub Release
- [ ] *(futuro)* Añadir `flutter test` al workflow
- [ ] *(futuro)* Build web + deploy a GitHub Pages en el mismo workflow

---

## Próximo paso

**[IMPL-08]** — Build web automático + deploy a GitHub Pages en cada push a `main`
