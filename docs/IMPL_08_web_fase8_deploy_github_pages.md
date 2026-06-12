# IMPL-08 — Web Fase 8: Deploy automático a GitHub Pages

**Estado:** ✅ Implementado  
**Fecha:** 2026-05-07  
**Rama:** `desktop/fase-1`  
**Proyecto:** geoportal-lddv  

---

## Objetivo

Publicar automáticamente la versión web de la app en GitHub Pages en cada push a `main` o `desktop/fase-1`.

**URL pública**: https://dayizz.github.io/GEOPORTAL-2/

---

## Archivo

`.github/workflows/deploy_web.yml`

---

## Activación requerida en GitHub (una vez)

Antes de que el workflow funcione, hay que habilitar GitHub Pages con fuente Actions:

```
GitHub → GEOPORTAL-2 → Settings → Pages
Source: GitHub Actions
```

---

## Triggers

| Evento | Condición |
|---|---|
| `push` a `main` | Deploy automático |
| `push` a `desktop/fase-1` | Deploy automático (rama activa) |
| `workflow_dispatch` | Manual desde GitHub Actions UI |

---

## Pasos del workflow

```
build-web job (ubuntu-latest):
  1. checkout
  2. instalar Flutter 3.41.7 (con caché)
  3. flutter pub get
  4. flutter analyze
  5. flutter build web --release --base-href /GEOPORTAL-2/
  6. configure-pages
  7. upload-pages-artifact  ← sube build/web

deploy job (depende de build-web):
  8. deploy-pages  ← publica en https://dayizz.github.io/GEOPORTAL-2/
```

---

## base-href

Flutter web requiere un `base-href` correcto para que el routing funcione:

```bash
flutter build web --base-href /GEOPORTAL-2/
```

Esto reemplaza `$FLUTTER_BASE_HREF` en `web/index.html` con `/GEOPORTAL-2/`.

Sin esta flag, los assets no se cargan correctamente al no estar en el root `/`.

---

## Tiempo estimado

| Paso | Tiempo |
|---|---|
| Flutter (con caché) | ~30 seg |
| `flutter build web` | ~2-3 min |
| Deploy | ~30 seg |
| **Total** | **~4-5 min** |

---

## Permisos configurados

```yaml
permissions:
  contents: read
  pages: write
  id-token: write
```

`id-token: write` es necesario para la autenticación OIDC de `deploy-pages`.

---

## Concurrencia

```yaml
concurrency:
  group: pages
  cancel-in-progress: true
```

Si se hacen dos pushes rápidos, el segundo cancela el primero — evita deploys obsoletos en cola.

---

## Criterio de éxito

- [x] `.github/workflows/deploy_web.yml` creado
- [x] Trigger en `push` a `main` y `desktop/fase-1`
- [x] `--base-href /GEOPORTAL-2/` para routing correcto
- [x] `concurrency: cancel-in-progress` para evitar colas
- [ ] *(requiere acción manual)* Activar GitHub Pages → Source: GitHub Actions
- [ ] *(post-activación)* Verificar https://dayizz.github.io/GEOPORTAL-2/ carga correctamente

---

## Próximo paso

**[IMPL-09]** — Merge `desktop/fase-1` → `main` + tag `v1.0.0` para lanzar build macOS y deploy web simultáneamente
