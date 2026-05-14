# IMPL_10_fix_eliminacion_individual_archivos

- Estado: Completado
- Fecha: 2026-05-14
- Rama: desktop/fase-1

## 1. Objetivo
Corregir la eliminación individual de archivos importados para que no falle cuando hay error de conectividad o timeout al sincronizar borrado en Gestión.

## 2. Diagnóstico / contexto actual
- La opción "Eliminar todos" funcionaba porque encapsula cada borrado de Gestión en `try/catch` y siempre continúa con el borrado local.
- La opción de eliminación individual abortaba todo el flujo si fallaba una consulta/borrado remoto, dejando el archivo sin borrar en almacenamiento local.
- Resultado observado por usuario: mensaje de error al eliminar individualmente y archivo persistiendo.

## 3. Fases

### Fase 1: Aislar fallos de sincronización remota
- Descripción: Encapsular el bloque de borrado en Gestión en `try/catch` para no romper la eliminación local.
- Archivos afectados:
  - `lib/features/carga/presentation/carga_archivo_screen.dart`
- Código clave:
  - Método `_eliminarArchivo(ImportedFile file)`
  - Variable `falloGestion` para distinguir éxito parcial.
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 2: Alinear comportamiento con "Eliminar todos"
- Descripción: Agregar timeout de 3 segundos en consultas por `archivo_id` y `bdId`, con fallback por claves catastrales sin interrumpir el flujo.
- Archivos afectados:
  - `lib/features/carga/presentation/carga_archivo_screen.dart`
- Código clave:
  - `getPrediosByArchivoId(...).timeout(const Duration(seconds: 3), onTimeout: () => [])`
- Tiempo estimado: 20 min
- Riesgo: Bajo

### Fase 3: Mensajería de resultado
- Descripción: Mostrar mensaje explícito de eliminación local cuando falle sincronización remota.
- Archivos afectados:
  - `lib/features/carga/presentation/carga_archivo_screen.dart`
- Código clave:
  - SnackBar: "Archivo eliminado localmente. No se pudo sincronizar la eliminación en Gestión."
- Tiempo estimado: 10 min
- Riesgo: Bajo

## 4. Resumen de esfuerzo

| Fase | Esfuerzo |
|---|---:|
| Fase 1 | 20 min |
| Fase 2 | 20 min |
| Fase 3 | 10 min |
| **Total** | **50 min** |

## 5. Criterio de éxito
- Eliminar individual elimina el archivo de la lista local aun con falla remota.
- No se rompe la UI ni el flujo por excepción de backend.
- Se informa al usuario si la sincronización de borrado en Gestión no pudo completarse.

## 6. Resultado / evidencia
- Cambio aplicado en `_eliminarArchivo` para encapsular sincronización remota en `try/catch` y continuar con borrado local.
- Validación estática del archivo modificando sin errores: `No errors found`.

## 7. Próximo paso
1. Probar manualmente desde UI:
   - Eliminar 1 archivo con backend disponible.
   - Eliminar 1 archivo simulando backend no disponible.
2. Confirmar que en ambos escenarios el archivo desaparece de la lista y no reaparece al recargar la pantalla.
