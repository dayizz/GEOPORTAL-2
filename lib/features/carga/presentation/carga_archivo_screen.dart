import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../mapa/providers/mapa_provider.dart';
import '../providers/carga_provider.dart';

class CargaArchivoScreen extends ConsumerStatefulWidget {
  const CargaArchivoScreen({super.key});

  @override
  ConsumerState<CargaArchivoScreen> createState() => _CargaArchivoScreenState();
}

class _CargaArchivoScreenState extends ConsumerState<CargaArchivoScreen> {
  bool _loading = false;
  String? _mensaje;
  bool _exito = false;
  List<Map<String, dynamic>> _preview = [];
  PlatformFile? _archivoSeleccionado;
  Map<String, dynamic>? _geoJsonData;

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

  // ── Envío al mapa ───────────────────────────────────────────

  /// Guarda los features en el provider de importación y navega al mapa.
  void _enviarAlMapa() {
    if (_geoJsonData == null) {
      print('❌ _geoJsonData es null');
      return;
    }

    try {
      final featuresList = _geoJsonData!['features'];
      if (featuresList is! List) {
        print('❌ features no es una List: ${featuresList.runtimeType}');
        return;
      }

      final features = <Map<String, dynamic>>[];
      for (final f in featuresList) {
        final mapped = _asStringDynamicMap(f);
        if (mapped != null) {
          final geo = mapped['geometry'] as Map<String, dynamic>?;
          final props = mapped['properties'] as Map<String, dynamic>?;
          print('✅ Feature: geom=${geo?["type"] ?? "null"}, props=${props?.keys.toList() ?? "null"}');
          features.add(mapped);
        }
      }

      print('📤 Enviando ${features.length} features al mapa...');
      if (features.isEmpty) {
        print('⚠️ Ningún feature válido para enviar');
        return;
      }

      // Guardar en la lista de archivos importados
      ref.read(cargaProvider.notifier).addFile(
        _archivoSeleccionado?.name ?? 'archivo_${DateTime.now().millisecondsSinceEpoch}',
        features,
      );

      ref.read(importedFeaturesProvider.notifier).state = features;
      context.go('/mapa');
    } catch (e) {
      print('❌ Error en _enviarAlMapa: $e');
    }
  }

  /// Envía un archivo de la tabla al mapa
  void _verEnMapaDesdeTabla(String fileId) {
    final importedFiles = ref.read(cargaProvider);
    final file = importedFiles.firstWhere((f) => f.id == fileId);
    
    ref.read(importedFeaturesProvider.notifier).state = file.features;
    context.go('/mapa');
  }

  /// Elimina un archivo de la lista
  void _eliminarArchivo(String fileId) {
    ref.read(cargaProvider.notifier).removeFile(fileId);
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

            if (_loading) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 6),
              const Text('Leyendo archivo…', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
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
            if (_archivoSeleccionado != null && _preview.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.map_outlined),
                  label: Text(_loading ? 'Procesando...' : 'Ver en mapa'),
                  onPressed: _loading ? null : _enviarAlMapa,
                ),
              ),

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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: DataTable(
                          columnSpacing: 12,
                          horizontalMargin: 8,
                          headingRowColor: MaterialStateColor.resolveWith(
                            (states) => AppColors.secondary.withOpacity(0.08),
                          ),
                          columns: const [
                            DataColumn(
                              label: Text(
                                'Archivo',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Features',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Importado',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Acciones',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                          rows: importedFiles.map((file) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Tooltip(
                                    message: file.name,
                                    child: Text(
                                      file.name.length > 25
                                          ? '${file.name.substring(0, 22)}...'
                                          : file.name,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    file.featureCount.toString(),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    file.formattedDate,
                                    style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Tooltip(
                                        message: 'Ver en mapa',
                                        child: IconButton(
                                          icon: const Icon(Icons.map_outlined, size: 18),
                                          onPressed: () => _verEnMapaDesdeTabla(file.id),
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                      Tooltip(
                                        message: 'Eliminar',
                                        child: IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Eliminar archivo'),
                                                content: Text(
                                                  '\u00bfEst\u00e1s seguro de que deseas eliminar \"${file.name}\"?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(ctx),
                                                    child: const Text('Cancelar'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      _eliminarArchivo(file.id);
                                                      Navigator.pop(ctx);
                                                    },
                                                    child: const Text(
                                                      'Eliminar',
                                                      style: TextStyle(color: AppColors.danger),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
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
}
