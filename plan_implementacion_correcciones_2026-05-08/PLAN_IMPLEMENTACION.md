PLAN DE IMPLEMENTACION - Correcciones de Carga/Mapa/Gestion
Fecha: 2026-05-08

Objetivo
Corregir 4 problemas funcionales reportados en importacion y renderizado, y dejar una ruta de validacion para evitar regresiones.

Alcance de este plan
- Solo planificacion (sin cambios de logica en esta etapa).
- Se identifican causas probables y acciones concretas por modulo.

Resumen de problemas reportados
1) La notificacion de importacion (nuevos/actualizados en Gestion) no desaparece.
2) Al cargar archivo pesado aparecen 3 indicadores de carga empalmados.
3) En Mapa se respetan colores por estatus, pero en Gestion todos quedan como "No liberado" y no respeta "Liberado" desde archivo.
4) Al cerrar/abrir app, poligonos se ven grises y se pierde identificacion por estatus.

Diagnostico tecnico preliminar
A. Notificaciones persistentes
- En Carga hay dos rutas de SnackBar: helper general y SnackBar directo.
- Aunque existe un SnackBar con 3s para el mensaje de "nuevos/actualizados", hay otros SnackBar con duracion mayor que pueden quedar visibles y dar la sensacion de persistencia.
- Falta estrategia unificada para reemplazar/limpiar SnackBars previos antes de mostrar uno nuevo.

B. Triple loader en carga pesada
Actualmente coinciden 3 capas de feedback:
- Spinner en boton principal (estado _sincronizando).
- Tarjeta de progreso de importacion (importacionAsyncProvider).
- Overlay global por isBusy con CircularProgressIndicator.
Esto produce sobreposicion visual.

C. Gestion marca estatus incorrecto
- El estatus en Gestion depende de Predio.cop (y en mapa tambien de negociacion/levantamiento/identificacion).
- En sincronizacion GeoJSON, el mapeo de booleanos es fragil:
  - Para nuevos: campos como cop/identificacion/levantamiento/negociacion se leen con cast bool directo (riesgo de perder valor si llega como "SI", "1", "true" string o numero).
  - Para existentes: _buildGestionUpdateData actual solo rellena null/vacio y no incluye reglas de actualizacion de estatus booleanos.
Resultado: predios terminan con cop=false o sin estatus consolidado.

D. Al reiniciar app los colores se vuelven grises
- Color gris corresponde a "Sin estatus".
- Si los booleanos de estatus no se persisten correctamente en backend, al recargar predios desde API quedan sin bandera valida.
- Adicionalmente, Predio.fromMap usa cast bool directo; si backend devolviera 0/1 o string, se pierde interpretacion robusta.

Plan de implementacion por fases

Fase 1 - UX de notificaciones y carga (puntos 1 y 2)
1.1 Unificar notificaciones en Carga
- Centralizar todos los mensajes en un helper unico.
- Antes de mostrar un nuevo mensaje, limpiar los anteriores:
  - hideCurrentSnackBar / removeCurrentSnackBar.
- Establecer duracion estandar de 3 segundos para notificaciones de resultado de importacion.

1.2 Eliminar loaders duplicados
- Definir una sola fuente de verdad para carga de importacion pesada:
  - Mantener tarjeta de progreso (con porcentaje y etapa).
  - Quitar overlay global durante importacion (dejarlo solo para operaciones cortas de lectura local si aplica).
  - Desactivar spinner del boton cuando ya existe tarjeta de progreso visible, o viceversa (solo uno).

Criterio de aceptacion Fase 1
- Nunca hay mas de un loader visible para importacion.
- El mensaje de nuevos/actualizados desaparece en 3s de forma consistente.

Fase 2 - Normalizacion de estatus en inyeccion (puntos 3 y 4)
2.1 Robustecer parseo de booleanos en sincronizacion
- Crear helper de parseo booleano tolerante en SincronizacionService (true/false, 1/0, si/no, yes/no).
- Aplicarlo en:
  - _buildNuevoPredioData (cop, identificacion, levantamiento, negociacion).
  - cualquier mapeo de actualizacion de estatus para predio existente.

2.2 Actualizar estatus en predios existentes
- Extender _buildGestionUpdateData para considerar estatus booleanos del GeoJSON.
- Regla propuesta:
  - Si archivo trae valor explicito, aplicar update (no solo cuando valor actual es null).
  - Priorizar consistencia de negocio: cop=true debe reflejar "Liberado".

2.3 Robustecer parseo en modelo Predio
- En Predio.fromMap, reemplazar cast bool directo por normalizacion segura para:
  - cop
  - identificacion
  - levantamiento
  - negociacion
  - poligono_insertado
Esto garantiza persistencia y recarga consistente al reiniciar.

2.4 Validar mapeo visual Mapa/Gestion
- Confirmar que ambos consumen las mismas banderas persistidas.
- Mantener colores:
  - Liberado => verde
  - No liberado => rojo
  - Sin estatus => gris
- Asegurar que "Sin estatus" solo aparezca cuando realmente no hay banderas.

Criterio de aceptacion Fase 2
- Si un feature llega con cop/liberado, en Gestion queda Liberado y en Mapa verde.
- Tras cerrar y abrir app, estatus y color se conservan.

Fase 3 - Pruebas funcionales y de regresion
3.1 Casos de prueba de importacion
- GeoJSON pequeño con mezcla de:
  - cop=true / cop=false
  - identificacion/levantamiento/negociacion combinados
  - valores booleanos en formatos bool, string y numerico.

3.2 Casos de persistencia
- Importar, verificar colores en Mapa y estatus en Gestion.
- Cerrar app, reabrir, revalidar que nada cambia.

3.3 Casos de UX
- Archivo pesado: verificar un solo loader visible.
- Notificacion de resultado: visible 3s y desaparece.

Riesgos y mitigaciones
- Riesgo: sobreescribir estatus validado manualmente en Gestion.
  Mitigacion: actualizar estatus solo cuando el archivo aporte valor explicito (campo presente).
- Riesgo: cambios en parseo afecten XLSX.
  Mitigacion: limitar helpers al flujo GeoJSON y validar XLSX en smoke test.

Archivos objetivo para ejecutar el plan (fase de implementacion)
- lib/features/carga/presentation/carga_archivo_screen.dart
- lib/features/carga/services/sincronizacion_service.dart
- lib/features/predios/models/predio.dart
- (si aplica) lib/features/mapa/presentation/mapa_screen.dart
- (si aplica) lib/features/tabla/presentation/tabla_screen.dart

Definicion de terminado
- Los 4 problemas reportados quedan reproduciblemente corregidos en macOS build.
- Se valida con pruebas manuales de importacion, cierre/reapertura y renderizado.
