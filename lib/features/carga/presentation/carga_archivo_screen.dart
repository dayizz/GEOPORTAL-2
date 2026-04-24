import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../auth/providers/demo_provider.dart';
import '../../mapa/providers/mapa_provider.dart';
import '../data/archivos_geojson_repository.dart';
import '../providers/carga_provider.dart';
import '../services/sincronizacion_service.dart';

class CargaArchivoScreen extends ConsumerStatefulWidget {
  const CargaArchivoScreen({super.key});

  @override
  ConsumerState<CargaArchivoScreen> createState() => _CargaArchivoScreenState();
}

class _CargaArchivoScreenState extends ConsumerState<CargaArchivoScreen> {
  bool _loading = false;
  bool _sincronizando = false;
  String? _mensaje;
  bool _exito = false;
  List<Map<String, dynamic>> _preview = [];
  PlatformFile? _archivoSeleccionado;
  Map<String, dynamic>? _geoJsonData;
  SincronizacionResultado? _syncResultado;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarArchivosDesdeBD());
  }

  Future<void> _cargarArchivosDesdeBD() async {
    final isDemo = ref.read(demoModeProvider);
    if (isDemo) return;
    try {
      final repo = ref.read(archivosGeoJsonRepositoryProvider);
      final rawList = await repo.getArchivos();
      final bdFiles = rawList.map(ImportedFile.fromBD).toList();
      ref.read(cargaProvider.notifier).initFromBD(bdFiles);
    } catch (_) {
      // Si la BD no está disponible, se muestran solo los archivos en memoria.
    }
  }

  Future<void> _seleccionarArchivo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    // Extraer extensión del nombre (file.extension puede no estar disponible en web)
    final ext = file.name.split('.').last.toLowerCase();

    // Validar que sea un archivo permitido
    if (!['geojson', 'json'].contains(ext)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Archivo no soportado. Usa .geojson o .json',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() {
      _archivoSeleccionado = file;
      _geoJsonData = null;
      _preview = [];
      _mensaje = null;
      _loading = true;
    });

    try {
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.readStream != null) {
        final collected = <int>[];
        await for (final chunk in file.readStream!) {
          collected.addAll(chunk);
        }
        bytes = Uint8List.fromList(collected);
      }

      if (bytes == null) {
        if (!mounted) return;
        setState(() {
          _mensaje = 'No se pudo leer el archivo seleccionado.';
          _exito = false;
        });
        return;
      }

      await _parsearGeoJSON(bytes);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _parsearGeoJSON(List<int> bytes) async {
    try {
      final jsonStr = utf8.decode(bytes);
      final raw = jsonDecode(jsonStr);
      if (raw is! Map) {
        if (!mounted) return;
        setState(() {
          _mensaje = 'El archivo GeoJSON no tiene una estructura válida.';
          _exito = false;
        });
        return;
      }

      final geojson = Map<String, dynamic>.from(raw);
      final normalized = _normalizeGeoJson(geojson);
      if (normalized == null) {
        if (!mounted) return;
        setState(() {
          _mensaje = 'El archivo debe contener una FeatureCollection, Feature o geometría GeoJSON.';
          _exito = false;
        });
        return;
      }

      final features = normalized['features'] as List?;
      if (features == null || features.isEmpty) {
        if (!mounted) return;
        setState(() => _mensaje = 'El archivo no contiene features válidos.');
        return;
      }

      print('📄 GeoJSON parseado: ${features.length} features');
      for (int i = 0; i < features.length && i < 3; i++) {
        final f = features[i];
        final fmap = _asStringDynamicMap(f);
        if (fmap != null) {
          final geo = fmap['geometry'] as Map<String, dynamic>?;
          final props = fmap['properties'] as Map<String, dynamic>?;
          print('  📍 Feature $i: tipo=${geo?["type"]}, props=${props?.keys.toList()}');
        }
      }

      final preview = features.take(5).map((f) {
        final featureMap = _asStringDynamicMap(f);
        if (featureMap == null) {
          return {
            'clave': 'Sin clave',
            'uso_suelo': 'Otro',
            'superficie': 0,
            'geometry': null,
          };
        }
        final props = _asStringDynamicMap(featureMap['properties'] as dynamic?) ?? <String, dynamic>{};
        return {
          'clave': props['clave_catastral'] ?? props['clave'] ?? props['id'] ?? 'Sin clave',
          'uso_suelo': props['uso_suelo'] ?? props['USO'] ?? props['uso'] ?? 'Otro',
          'superficie': props['superficie'] ?? props['SUPERFICIE'] ?? props['area'] ?? 0,
          'geometry': featureMap['geometry'],
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _geoJsonData = normalized;
        _preview = preview.cast<Map<String, dynamic>>();
        _mensaje = '${features.length} features encontrados';
        _exito = true;
      });
    } catch (e) {
      print('❌ Error al parsear GeoJSON: $e');
      if (!mounted) return;
      setState(() {
        _mensaje = 'Error al leer el archivo: $e';
        _exito = false;
      });
    }
  }

  Map<String, dynamic>? _normalizeGeoJson(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == 'FeatureCollection') return data;

    if (type == 'Feature') {
      return {
        'type': 'FeatureCollection',
        'features': [data],
      };
    }

    const geometryTypes = {
      'Polygon',
      'MultiPolygon',
      'LineString',
      'MultiLineString',
      'Point',
      'MultiPoint',
    };
    if (type != null && geometryTypes.contains(type)) {
      return {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': data,
            'properties': <String, dynamic>{},
          }
        ],
      };
    }

    return null;
  }

  // ── Acciones sobre el GeoJSON ──────────────────────────────

  /// Extrae la lista de features del GeoJSON parseado.
  List<Map<String, dynamic>> _extraerFeatures() {
    final featuresList = _geoJsonData!['features'];
    if (featuresList is! List) return [];
    return featuresList
        .map(_asStringDynamicMap)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  /// Solo renderiza los features en el mapa, SIN guardar en la BD.
  void _soloRenderizar() {
    if (_geoJsonData == null) return;
    final features = _extraerFeatures();
    if (features.isEmpty) return;

    final nombre = _archivoSeleccionado?.name ??
        'archivo_${DateTime.now().millisecondsSinceEpoch}';

    ref.read(cargaProvider.notifier).addFile(
      nombre,
      features,
      guardadoEnBD: false,
      sincronizado: false,
    );
    ref.read(importedFeaturesProvider.notifier).state = features;
    context.go('/mapa');
  }

  /// Sincroniza con la BD, guarda el archivo en `archivos_geojson` y navega al mapa.
  Future<void> _guardarYVerEnMapa() async {
    if (_geoJsonData == null) return;
    final features = _extraerFeatures();
    if (features.isEmpty) return;

    final nombre = _archivoSeleccionado?.name ??
        'archivo_${DateTime.now().millisecondsSinceEpoch}';

    setState(() {
      _sincronizando = true;
      _mensaje = 'Sincronizando con la base de datos…';
      _exito = true;
    });

    try {
      final isDemo = ref.read(demoModeProvider);
      final syncService = ref.read(sincronizacionServiceProvider);
      final resultado = await syncService.sincronizar(features, isDemo: isDemo);

      if (!mounted) return;

      // Guardar archivo en la BD (solo si no es modo demo)
      String? bdId;
      if (!isDemo) {
        try {
          final archivosRepo = ref.read(archivosGeoJsonRepositoryProvider);
          final saved = await archivosRepo.saveArchivo(
            nombre: nombre,
            features: resultado.features,
            sincronizado: true,
            encontrados: resultado.encontrados,
            creados: resultado.creados,
            errores: resultado.errores,
          );
          bdId = saved['id'] as String?;
        } catch (_) {
          // Si falla el guardado del archivo, continuar igualmente.
        }
      }

      setState(() {
        _syncResultado = resultado;
        _sincronizando = false;
        _mensaje = 'Guardado. Sincronización: '
            '${resultado.encontrados} existentes, '
            '${resultado.creados} nuevos'
            '${resultado.errores > 0 ? ', ${resultado.errores} errores' : ''}';
        _exito = resultado.errores == 0;
      });

      ref.read(cargaProvider.notifier).addFile(
        nombre,
        resultado.features,
        bdId: bdId,
        guardadoEnBD: bdId != null,
        sincronizado: true,
        encontrados: resultado.encontrados,
        creados: resultado.creados,
        errores: resultado.errores,
      );

      ref.read(importedFeaturesProvider.notifier).state = resultado.features;
      context.go('/mapa');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sincronizando = false;
        _mensaje = 'Error: $e';
        _exito = false;
      });
    }
  }

  /// Envía un archivo de la tabla al mapa
  void _verEnMapaDesdeTabla(String fileId) {
    final importedFiles = ref.read(cargaProvider);
    final file = importedFiles.firstWhere((f) => f.id == fileId);
    ref.read(importedFeaturesProvider.notifier).state = file.features;
    context.go('/mapa');
  }

  /// Elimina un archivo: del provider en memoria y, si tiene bdId, también de la BD.
  Future<void> _eliminarArchivo(ImportedFile file) async {
    ref.read(cargaProvider.notifier).removeFile(file.id);
    if (file.guardadoEnBD && file.bdId != null) {
      try {
        final repo = ref.read(archivosGeoJsonRepositoryProvider);
        await repo.deleteArchivo(file.bdId!);
      } catch (_) {
        // Error silencioso: el archivo ya fue quitado de la UI.
      }
    }
  }

  Map<String, dynamic>? _asStringDynamicMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.replaceAll(',', '').trim();
      return double.tryParse(normalized);
    }
    return null;
  }

  Map<String, double>? _centroidFromRing(List<dynamic> ring) {
    if (ring.isEmpty) return null;
    
    final points = <Map<String, double>>[];
    
    for (final coord in ring) {
      if (coord is List && coord.length >= 2) {
        try {
          points.add({
            'lng': (coord[0] as num).toDouble(),
            'lat': (coord[1] as num).toDouble()
          });
        } catch (_) {
          continue;
        }
      }
    }
    
    if (points.isEmpty) return null;
    
    // Centroide de polígono usando fórmula de Shoelace
    double area = 0;
    double x = 0;
    double y = 0;
    
    for (var i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final lng1 = p1['lng']!;
      final lat1 = p1['lat']!;
      final lng2 = p2['lng']!;
      final lat2 = p2['lat']!;
      
      final cross = lng1 * lat2 - lng2 * lat1;
      area += cross;
      x += (lng1 + lng2) * cross;
      y += (lat1 + lat2) * cross;
    }
    
    if (area.abs() < 1e-10) {
      // Si el área es muy pequeña, retornar promedio simple
      double sumLat = 0, sumLng = 0;
      for (final p in points) {
        sumLat += p['lat']!;
        sumLng += p['lng']!;
      }
      return {'lng': sumLng / points.length, 'lat': sumLat / points.length};
    }
    
    area /= 2.0;
    x /= (6.0 * area);
    y /= (6.0 * area);
    
    return {'lng': x, 'lat': y};
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: 3,
      title: 'Carga de Archivos',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Importa predios desde GeoJSON. Los polígonos se renderizan en el mapa y puedes tocarlos para capturarlos en el sistema.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Zona de carga
            GestureDetector(
              onTap: _loading ? null : _seleccionarArchivo,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: _archivoSeleccionado != null
                      ? AppColors.secondary.withOpacity(0.05)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _archivoSeleccionado != null
                        ? AppColors.secondary
                        : AppColors.border,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _archivoSeleccionado != null
                          ? Icons.check_circle
                          : Icons.upload_file,
                      size: 56,
                      color: _archivoSeleccionado != null
                          ? AppColors.secondary
                          : AppColors.textLight,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _archivoSeleccionado != null
                          ? _archivoSeleccionado!.name
                          : 'Seleccionar archivo',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _archivoSeleccionado != null
                            ? AppColors.secondary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _archivoSeleccionado != null
                          ? 'Toca para cambiar el archivo'
                          : 'Formatos: .geojson  .json',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
            ),

            if (_loading || _sincronizando) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 6),
              Text(
                _sincronizando ? 'Sincronizando con la base de datos…' : 'Leyendo archivo…',
                style: const TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
            ],

            if (_mensaje != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _exito
                      ? AppColors.secondary.withOpacity(0.08)
                      : AppColors.danger.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _exito
                        ? AppColors.secondary.withOpacity(0.4)
                        : AppColors.danger.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _exito ? Icons.check_circle : Icons.error,
                      color: _exito ? AppColors.secondary : AppColors.danger,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _mensaje!,
                        style: TextStyle(
                          color: _exito ? AppColors.secondary : AppColors.danger,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Vista previa
            if (_preview.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Vista previa (primeros ${_preview.length} registros)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: _preview.asMap().entries.map((e) {
                    final item = e.value;
                    return Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.usoSueloColor(
                                      item['uso_suelo'].toString())
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.location_city,
                              color: AppColors.usoSueloColor(
                                  item['uso_suelo'].toString()),
                              size: 18,
                            ),
                          ),
                          title: Text(
                            item['clave'].toString(),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          subtitle: Text(
                            '${item['uso_suelo']} · ${item['superficie']} m²',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        if (e.key < _preview.length - 1)
                          const Divider(height: 1),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 28),
            if (_archivoSeleccionado != null && _preview.isNotEmpty) ...[
              // ── Dos botones de acción ──────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¿Qué deseas hacer con este archivo?',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Botón 1: Solo renderizar
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.map_outlined, size: 18),
                            label: const Text('Solo renderizar',
                                style: TextStyle(fontSize: 13)),
                            onPressed: (_loading || _sincronizando)
                                ? null
                                : _soloRenderizar,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Botón 2: Guardar en BD
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: (_sincronizando)
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.save_outlined, size: 18),
                            label: Text(
                              _sincronizando
                                  ? 'Guardando…'
                                  : 'Guardar en BD',
                              style: const TextStyle(fontSize: 13),
                            ),
                            onPressed: (_loading || _sincronizando)
                                ? null
                                : _guardarYVerEnMapa,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 12, color: AppColors.textLight),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            'Renderizar: visualiza en el mapa sin guardar.  '
                            'Guardar en BD: sincroniza predios y persiste el archivo.',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textLight),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // ── Tabla de archivos importados ────────────────────
            const SizedBox(height: 40),
            Consumer(
              builder: (context, ref, _) {
                final importedFiles = ref.watch(cargaProvider);
                
                if (importedFiles.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, color: AppColors.textLight, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'No hay archivos importados',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Archivos importados (${importedFiles.length})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: importedFiles.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (_, idx) =>
                            _buildArchivoTile(importedFiles[idx]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Tile de archivo en la lista ──────────────────────────

  Widget _buildArchivoTile(ImportedFile file) {
    final statusColor = file.guardadoEnBD ? AppColors.secondary : AppColors.textLight;
    final statusIcon = file.guardadoEnBD ? Icons.cloud_done_outlined : Icons.cloud_off_outlined;
    final statusLabel = file.guardadoEnBD ? 'Guardado en BD' : 'Solo en memoria';

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.insert_drive_file_outlined, color: statusColor, size: 18),
      ),
      title: Text(
        file.name.length > 40 ? '${file.name.substring(0, 37)}…' : file.name,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, size: 11, color: statusColor),
              const SizedBox(width: 3),
              Text(statusLabel,
                  style: TextStyle(fontSize: 11, color: statusColor)),
              if (file.sincronizado) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${file.encontrados} exist. / ${file.creados} nuevos'
                    '${file.errores > 0 ? " / ${file.errores} err" : ""}',
                    style:
                        TextStyle(fontSize: 10, color: AppColors.info.withOpacity(0.8)),
                  ),
                ),
              ],
            ],
          ),
          Text(
            '${file.featureCount} features · ${file.formattedDate}',
            style:
                const TextStyle(fontSize: 11, color: AppColors.textLight),
          ),
        ],
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'Ver en mapa',
            child: IconButton(
              icon: const Icon(Icons.map_outlined, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => _verEnMapaDesdeTabla(file.id),
            ),
          ),
          Tooltip(
            message: 'Eliminar',
            child: IconButton(
              icon: const Icon(Icons.delete_outline, size: 18,
                  color: AppColors.danger),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Eliminar archivo'),
                  content: Text(
                    '¿Eliminar "${file.name}"?'
                    '${file.guardadoEnBD ? '\nSe borrará también de la base de datos.' : ''}',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () {
                        _eliminarArchivo(file);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Eliminar',
                          style: TextStyle(color: AppColors.danger)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
