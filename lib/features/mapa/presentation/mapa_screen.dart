import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../auth/providers/demo_provider.dart';
import '../../predios/models/predio.dart';
import '../../predios/models/proyecto.dart';
import '../../predios/data/predios_repository.dart';
import '../../predios/providers/demo_predios_notifier.dart';
import '../../predios/providers/predios_provider.dart';
import '../../predios/providers/local_predios_provider.dart';
import '../../predios/providers/proyectos_provider.dart';
import '../../propietarios/data/propietarios_repository.dart';
import '../../propietarios/providers/propietarios_provider.dart';
import '../providers/mapa_provider.dart';

class MapaScreen extends ConsumerStatefulWidget {
  const MapaScreen({super.key});

  @override
  ConsumerState<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends ConsumerState<MapaScreen> {
  final MapController _mapCtrl = MapController();
  Predio? _selectedPredio;
  bool _showCapturaModal = false;
  bool _showLayersPanel = false;
  bool _showVisualizacionPanel = false;
  bool _isDrawing = false;
  bool _isManualLinkMode = false;
  bool _isLinkingManual = false;
  final List<LatLng> _draftPoints = [];
  final List<_SavedPolygon> _capturedPolygons = [];
  final TextEditingController _tramoCtrl = TextEditingController();
  final TextEditingController _propietarioCtrl = TextEditingController();
  final TextEditingController _estadoCtrl = TextEditingController();
  final TextEditingController _municipioCtrl = TextEditingController();
  final TextEditingController _kmInicioCtrl = TextEditingController(text: '0+000');
  final TextEditingController _kmFinCtrl = TextEditingController(text: '0+000');
  String? _proyecto;
  String? _estatusPredio;
  String? _tipoPropiedad;
  double _detectedAreaM2 = 0;
  bool _detectingUbicacion = false;
  /// Índice del feature importado actualmente seleccionado para captura.
  int? _importedFeatureIndex;
  int? _manualFeatureIndex;
  String? _manualSelectedPredioId;
  final TextEditingController _manualPredioSearchCtrl = TextEditingController();
  int? _lastImportedFeaturesIdentity;

  static const _defaultCenter = LatLng(20.72, -100.35);
  static const _defaultZoom = 10.0;

  // Memoización de polígonos importados (deben ser de instancia, no static locales)
  List<Map<String, dynamic>>? _lastImportedFeatures;
  MapaColorMode? _lastColorMode;
  List<Polygon>? _lastImportedPolygons;
  // Memoización de visuales
  List<Predio>? _lastPredios;
  MapaColorMode? _lastColorModeVisual;
  List<_PredioVisualData>? _lastVisuals;

  @override
  void dispose() {
    _tramoCtrl.dispose();
    _propietarioCtrl.dispose();
    _estadoCtrl.dispose();
    _municipioCtrl.dispose();
    _kmInicioCtrl.dispose();
    _kmFinCtrl.dispose();
    _manualPredioSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prediosAsync = ref.watch(prediosMapaProvider);
    final prediosById = ref.watch(prediosMapaByIdProvider);
    final baseLayer = ref.watch(mapaBaseLayerProvider);
    final colorMode = ref.watch(mapaColorModeProvider);
    final importedFeatures = ref.watch(importedFeaturesProvider);

    List<Polygon> importedPolygons;
    if (_lastImportedFeatures == importedFeatures && _lastColorMode == colorMode) {
      importedPolygons = _lastImportedPolygons ?? [];
    } else {
      importedPolygons = _buildImportedPolygons(importedFeatures, colorMode);
      _lastImportedFeatures = importedFeatures;
      _lastColorMode = colorMode;
      _lastImportedPolygons = importedPolygons;
    }

    final importedMarkers = _buildImportedMarkers(
      features: importedFeatures,
      selectedFeatureIndex: _importedFeatureIndex,
    );
    _focusImportedIfNeeded(importedFeatures, importedPolygons);

    // Focus desde Gestión/Propietarios: fly-to al predio solicitado.
    final focusId = ref.watch(focusPredioIdProvider);
    if (focusId != null) {
      final predio = prediosById[focusId];
      if (predio != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _flyToPredio(predio);
          ref.read(focusPredioIdProvider.notifier).state = null;
          setState(() => _selectedPredio = predio);
        });
      } else {
        // Predio no en prediosMapaProvider (ej: recién importado) →
        // intentar en importedFeaturesProvider como fallback.
        final imported = ref.read(importedFeaturesProvider);
        final match = imported.cast<Map<String, dynamic>?>().firstWhere(
          (f) => f?['properties']?['_predioId']?.toString() == focusId,
          orElse: () => null,
        );
        if (match != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _flyToFeatureGeometry(
              match['geometry'] is Map
                  ? Map<String, dynamic>.from(match['geometry'] as Map)
                  : null,
            );
            ref.read(focusPredioIdProvider.notifier).state = null;
          });
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) ref.read(focusPredioIdProvider.notifier).state = null;
          });
        }
      }
    }

    // Solicitud desde Gestión: abrir modo de vinculación manual para un predio.
    final manualVincularPredioId = ref.watch(manualVincularPredioIdProvider);
    if (manualVincularPredioId != null) {
      prediosAsync.whenData((predios) {
        final target = predios.cast<Predio?>().firstWhere(
              (p) => p?.id == manualVincularPredioId,
              orElse: () => null,
            );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _showCapturaModal = true;
            _isManualLinkMode = true;
            _isDrawing = false;
            _manualSelectedPredioId = manualVincularPredioId;
            _manualPredioSearchCtrl.text =
                target != null ? _manualPredioLabel(target) : '';
          });
          ref.read(manualVincularPredioIdProvider.notifier).state = null;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selecciona un poligono huérfano en el mapa y luego pulsa Vincular.'),
            ),
          );
        });
      });
    }

    return AppScaffold(
      currentIndex: 0,
      title: 'Mapa LDDV',
      child: Stack(
        children: [
          prediosAsync.when(
            data: (predios) {
              List<_PredioVisualData> visuals;
              if (_lastPredios == predios && _lastColorModeVisual == colorMode) {
                visuals = _lastVisuals ?? [];
              } else {
                visuals = _buildVisualData(predios, colorMode);
                _lastPredios = predios;
                _lastColorModeVisual = colorMode;
                _lastVisuals = visuals;
              }
              final selectedVisual = _selectedPredio == null
                  ? null
                  : visuals.cast<_PredioVisualData?>().firstWhere(
                        (v) => v?.predio.id == _selectedPredio!.id,
                        orElse: () => null,
                      );
              return FlutterMap(
                mapController: _mapCtrl,
                options: MapOptions(
                  initialCenter: _defaultCenter,
                  initialZoom: _defaultZoom,
                  onTap: (_, point) {
                    // Predios guardados en DB
                    final tappedVisual = _findVisualAtPoint(point, visuals);
                    var shouldAutofillUbicacion = false;
                    int? importedIdxToOpen;

                    setState(() {
                      if (_isManualLinkMode) {
                        final currentImported = ref.read(importedFeaturesProvider);
                        final importedIdx = _findImportedAtPoint(point, currentImported);
                        if (importedIdx != null) {
                          final feature = currentImported[importedIdx];
                          if (_isImportedFeatureLinked(feature)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Ese poligono ya esta vinculado a un registro de Gestion.'),
                              ),
                            );
                            return;
                          }
                          _manualFeatureIndex = importedIdx;
                          _importedFeatureIndex = importedIdx;
                        }
                        return;
                      }

                      if (tappedVisual != null) {
                        _selectedPredio = tappedVisual.predio;
                        _importedFeatureIndex = null;
                        if (_isDrawing && tappedVisual.rings.isNotEmpty) {
                          final selectedPoints = List<LatLng>.from(tappedVisual.rings.first);
                          if (selectedPoints.first != selectedPoints.last) {
                            selectedPoints.add(selectedPoints.first);
                          }
                          _draftPoints
                            ..clear()
                            ..addAll(selectedPoints);
                          _isDrawing = false;
                          _detectedAreaM2 = _calculateAreaSquareMeters(_draftPoints);
                          shouldAutofillUbicacion = true;

                          // ── Pre-rellenar formulario con datos del predio seleccionado ──
                          final predio = tappedVisual.predio;
                          final nombrePropOwner = predio.propietario != null
                              ? predio.propietario!.nombreCompleto.trim()
                              : predio.propietarioNombre?.trim() ?? '';
                          _propietarioCtrl.text = nombrePropOwner;
                          _tramoCtrl.text = predio.tramo.trim();
                          _kmInicioCtrl.text = predio.kmInicio != null
                              ? _formatKm(predio.kmInicio!)
                              : '0+000';
                          _kmFinCtrl.text = predio.kmFin != null
                              ? _formatKm(predio.kmFin!)
                              : '0+000';
                          _tipoPropiedad = (predio.tipoPropiedad.trim().isNotEmpty &&
                                  predio.tipoPropiedad != 'PRIVADA')
                              ? predio.tipoPropiedad
                              : predio.tipoPropiedad.trim().isNotEmpty
                                  ? predio.tipoPropiedad
                                  : null;
                          _proyecto = _normalizeProyecto(predio.proyecto) ??
                              _inferProyectoFromText([
                                predio.proyecto ?? '',
                                predio.oficio ?? '',
                                predio.copFirmado ?? '',
                                predio.poligonoDwg ?? '',
                                predio.claveCatastral,
                              ].join(' '));
                        }
                        return;
                      }

                      // Buscar en polígonos importados (naranja) cuando modo selección activo
                      if (_isDrawing) {
                        final currentImported = ref.read(importedFeaturesProvider);
                        final importedIdx = _findImportedAtPoint(point, currentImported);
                        if (importedIdx != null) {
                          importedIdxToOpen = importedIdx;
                        }
                        // Toque fuera de cualquier polígono → no borrar draft, no hacer nada
                        return;
                      }

                      _selectedPredio = null;
                    });

                    // Abrir captura fuera del setState para evitar setState anidado
                    if (importedIdxToOpen != null) {
                      final currentImported = ref.read(importedFeaturesProvider);
                      if (importedIdxToOpen! < currentImported.length) {
                        _openCapturaForImportedFeature(
                          currentImported[importedIdxToOpen!],
                          importedIdxToOpen!,
                        );
                      }
                    }

                    if (shouldAutofillUbicacion) {
                      _autofillEstadoMunicipioDesdePoligono();
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: _tileTemplate(baseLayer),
                    maxZoom: 19,
                    userAgentPackageName: 'com.geoportal.predios',
                  ),
                  PolygonLayer(
                    polygons: visuals
                        .where((v) => v.polygon != null)
                        .map((v) => v.polygon!)
                        .toList(),
                  ),
                  // Capa de polígonos importados desde GeoJSON (naranja / pendientes de captura)
                  if (importedPolygons.isNotEmpty)
                    PolygonLayer(
                      polygons: importedPolygons,
                    ),
                  if (importedMarkers.isNotEmpty)
                    MarkerLayer(markers: importedMarkers),
                  if (_capturedPolygons.isNotEmpty)
                    PolygonLayer(
                      polygons: _capturedPolygons
                          .map(
                            (sp) => Polygon(
                              points: sp.points,
                              color: _savedPolygonColor(sp, colorMode).withValues(alpha: 0.46),
                              borderColor: _savedPolygonColor(sp, colorMode),
                              borderStrokeWidth: 2,
                            ),
                          )
                          .toList(),
                    ),
                  if (_draftPoints.length >= 3)
                    PolygonLayer(
                      polygons: [
                        Polygon(
                          points: _draftPoints,
                          color: _draftPolygonColor(colorMode).withValues(alpha: 0.4),
                          borderColor: _draftPolygonColor(colorMode).withValues(alpha: 0.4),
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: selectedVisual != null && selectedVisual.markerPoint != null
                        ? [
                            Marker(
                              point: selectedVisual.markerPoint!,
                              width: 36,
                              height: 36,
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _selectedPredio = selectedVisual.predio;
                                  _importedFeatureIndex = null;
                                }),
                                child: _buildMarkerDot(selectedVisual.color),
                              ),
                            ),
                          ]
                        : const [],
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No fue posible cargar el mapa.\n$e',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: Colors.white,
                      elevation: 4,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() {
                          _showVisualizacionPanel = !_showVisualizacionPanel;
                          if (_showVisualizacionPanel) {
                            _showLayersPanel = false;
                          }
                        }),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          child: Icon(
                            _showVisualizacionPanel
                                ? Icons.visibility
                                : Icons.visibility_outlined,
                            size: 22,
                            color: _showVisualizacionPanel
                                ? AppColors.primary
                                : const Color(0xFF555555),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.white,
                      elevation: 4,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() {
                          _showLayersPanel = !_showLayersPanel;
                          if (_showLayersPanel) {
                            _showVisualizacionPanel = false;
                          }
                        }),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.layers_outlined,
                            size: 22,
                            color: _showLayersPanel
                                ? AppColors.primary
                                : const Color(0xFF555555),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_showVisualizacionPanel) ...[
                  const SizedBox(height: 6),
                  _buildVisualizacionControl(colorMode),
                ],
                if (_showLayersPanel) ...[
                  const SizedBox(height: 6),
                  _buildLayersPanel(colorMode, baseLayer),
                ],
              ],
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: _buildCapturaToggleButton(),
          ),

          if (_showCapturaModal)
            Positioned(
              top: 72,
              left: 16,
              child: _buildCapturaModal(),
            ),
          if (_selectedPredio != null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: _buildPredioCard(_selectedPredio!),
            ),
          // Banner "procesando importación" — bloquea interacción hasta que BD confirme
          if (ref.watch(importacionEstadoProvider) == ImportacionEstado.procesando)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black45,
                child: Center(
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Guardando predios en la base de datos…',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Los polígonos se pintarán cuando el backend confirme.',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textLight),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
    ),
  );
  }

  String _tileTemplate(MapaBaseLayer layer) {
    if (layer == MapaBaseLayer.satelital) {
      return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  List<_PredioVisualData> _buildVisualData(
    List<Predio> predios,
    MapaColorMode mode,
  ) {
    return predios.map((predio) {
      final color = _predioColor(predio, mode);
      final rings = _extractRings(predio.geometry);
      final polygon = rings.isNotEmpty
          ? Polygon(
              points: rings.first,
              holePointsList: rings.length > 1 ? rings.sublist(1) : const [],
              color: color.withValues(alpha: 0.46),
              borderColor: color.withValues(alpha: 0.46),
              borderStrokeWidth: 1.8,
            )
          : null;

      final markerPoint = _markerPoint(predio, rings);

      return _PredioVisualData(
        predio: predio,
        color: color,
        rings: rings,
        polygon: polygon,
        markerPoint: markerPoint,
      );
    }).toList();
  }

  _PredioVisualData? _findVisualAtPoint(LatLng point, List<_PredioVisualData> visuals) {
    for (final visual in visuals.reversed) {
      if (visual.rings.isEmpty) continue;
      final outerRing = visual.rings.first;
      if (!_pointInRing(point, outerRing)) continue;

      final insideHole = visual.rings.skip(1).any((ring) => _pointInRing(point, ring));
      if (!insideHole) {
        return visual;
      }
    }
    return null;
  }

  bool _pointInRing(LatLng point, List<LatLng> ring) {
    if (ring.length < 3) return false;

    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final xi = ring[i].longitude;
      final yi = ring[i].latitude;
      final xj = ring[j].longitude;
      final yj = ring[j].latitude;

      final intersects = ((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude <
              (xj - xi) * (point.latitude - yi) / ((yj - yi) == 0 ? 0.0000001 : (yj - yi)) + xi);
      if (intersects) {
        inside = !inside;
      }
    }
    return inside;
  }

  Color _predioColor(Predio predio, MapaColorMode mode) {
    if (mode == MapaColorMode.tipoPropiedad) {
      return AppColors.tipoPropiedadColor(predio.tipoPropiedad);
    }

    return _estatusColor(_predioEstatus(predio));
  }

  Color _draftPolygonColor(MapaColorMode mode) {
    if (mode == MapaColorMode.tipoPropiedad) {
      return AppColors.tipoPropiedadColor(_tipoPropiedad ?? 'Sin tipo');
    }
    return _estatusColor(_estatusPredio);
  }

  Color _savedPolygonColor(_SavedPolygon polygon, MapaColorMode mode) {
    if (mode == MapaColorMode.tipoPropiedad) {
      return AppColors.tipoPropiedadColor(polygon.tipoPropiedad ?? 'Sin tipo');
    }
    return _estatusColor(polygon.estatus);
  }

  String _predioEstatus(Predio predio) {
    if (predio.cop) return 'Liberado';
    if (predio.negociacion || predio.levantamiento || predio.identificacion) {
      return 'No liberado';
    }
    return 'Sin estatus';
  }

  bool _isLiberado(String? estatus) => estatus == 'Liberado';

  bool _isNoLiberado(String? estatus) => estatus == 'No liberado';

  List<Polygon> _buildImportedPolygons(
    List<Map<String, dynamic>> features,
    MapaColorMode mode,
  ) {
    final polygons = <Polygon>[];
    for (int i = 0; i < features.length; i++) {
      final feature = features[i];
      final geometry = _geometryAsMap(feature['geometry']);
      final extractedPolygons = _extractPolygons(geometry);
      final color = _importedFeatureColor(feature, mode);
      for (final rings in extractedPolygons) {
        if (rings.isEmpty || rings.first.length < 3) continue;
        polygons.add(
          Polygon(
            points: rings.first,
            holePointsList: rings.length > 1 ? rings.sublist(1) : const [],
            color: color.withValues(alpha: 0.4),
            borderColor: color.withValues(alpha: 0.4),
            borderStrokeWidth: 2.5,
          ),
        );
      }
    }
    return polygons;
  }

  List<Marker> _buildImportedMarkers({
    required List<Map<String, dynamic>> features,
    required int? selectedFeatureIndex,
  }) {
    if (selectedFeatureIndex == null ||
        selectedFeatureIndex < 0 ||
        selectedFeatureIndex >= features.length) {
      return const [];
    }

    final feature = features[selectedFeatureIndex];
    final geometry = _geometryAsMap(feature['geometry']);
    final polygons = _extractPolygons(geometry);
    final center = _centroidOfPolygons(polygons);
    if (center == null) return const [];

    return [
      Marker(
        point: center,
        width: 22,
        height: 22,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFF8C00),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66FF8C00),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    ];
  }

  LatLng? _centroidOfPolygons(List<List<List<LatLng>>> polygons) {
    if (polygons.isEmpty) return null;

    List<List<LatLng>>? bestRings;
    var bestArea = -1.0;
    for (final rings in polygons) {
      if (rings.isEmpty || rings.first.length < 3) continue;
      var area = _ringSignedArea(rings.first).abs();
      for (final hole in rings.skip(1)) {
        area -= _ringSignedArea(hole).abs();
      }
      if (area > bestArea) {
        bestArea = area;
        bestRings = rings;
      }
    }

    if (bestRings == null) return null;
    return _pointForPolygonRings(bestRings);
  }

  (LatLng, double)? _ringCentroidWithArea(List<LatLng> ring) {
    final points = ring.length > 1 && ring.first == ring.last
        ? ring.sublist(0, ring.length - 1)
        : ring;
    if (points.length < 3) return null;

    var twiceArea = 0.0;
    var centroidX6A = 0.0;
    var centroidY6A = 0.0;

    for (var i = 0; i < points.length; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];
      final cross = (p1.longitude * p2.latitude) - (p2.longitude * p1.latitude);
      twiceArea += cross;
      centroidX6A += (p1.longitude + p2.longitude) * cross;
      centroidY6A += (p1.latitude + p2.latitude) * cross;
    }

    final signedArea = twiceArea / 2;
    if (signedArea.abs() < 1e-12) return null;

    final cx = centroidX6A / (6 * signedArea);
    final cy = centroidY6A / (6 * signedArea);

    return (LatLng(cy, cx), signedArea.abs());
  }

  LatLng? _pointForPolygonRings(List<List<LatLng>> rings) {
    if (rings.isEmpty || rings.first.length < 3) return null;

    final outerCentroid = _ringCentroidWithArea(rings.first)?.$1;
    if (outerCentroid != null && _isPointInPolygonWithHoles(outerCentroid, rings)) {
      return outerCentroid;
    }

    final polylabel = _polylabelPoint(rings);
    if (polylabel != null) return polylabel;

    final outer = rings.first;
    final lat = outer.map((p) => p.latitude).reduce((a, b) => a + b) / outer.length;
    final lng = outer.map((p) => p.longitude).reduce((a, b) => a + b) / outer.length;
    return LatLng(lat, lng);
  }

  LatLng? _polylabelPoint(List<List<LatLng>> rings) {
    final outer = rings.first;
    final cleanOuter = outer.length > 1 && outer.first == outer.last
        ? outer.sublist(0, outer.length - 1)
        : outer;
    if (cleanOuter.length < 3) return null;

    var minLng = cleanOuter.first.longitude;
    var maxLng = cleanOuter.first.longitude;
    var minLat = cleanOuter.first.latitude;
    var maxLat = cleanOuter.first.latitude;

    for (final p in cleanOuter.skip(1)) {
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
    }

    final width = maxLng - minLng;
    final height = maxLat - minLat;
    final cellSize = math.min(width, height);
    if (cellSize <= 0) {
      final fallback = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
      return _isPointInPolygonWithHoles(fallback, rings) ? fallback : null;
    }

    final precision = math.max(cellSize / 1000, 1e-7);
    final cells = <_PolylabelCell>[];

    for (double x = minLng; x < maxLng; x += cellSize) {
      for (double y = minLat; y < maxLat; y += cellSize) {
        final c = _PolylabelCell(
          x + cellSize / 2,
          y + cellSize / 2,
          cellSize / 2,
          _signedDistanceToPolygonEdges(LatLng(y + cellSize / 2, x + cellSize / 2), rings),
        );
        cells.add(c);
      }
    }

    var bestCell = _PolylabelCell(
      (minLng + maxLng) / 2,
      (minLat + maxLat) / 2,
      0,
      _signedDistanceToPolygonEdges(LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2), rings),
    );

    final centroid = _ringCentroidWithArea(rings.first)?.$1;
    if (centroid != null) {
      final centroidCell = _PolylabelCell(
        centroid.longitude,
        centroid.latitude,
        0,
        _signedDistanceToPolygonEdges(centroid, rings),
      );
      if (centroidCell.d > bestCell.d) bestCell = centroidCell;
    }

    while (cells.isNotEmpty) {
      cells.sort((a, b) => b.max.compareTo(a.max));
      final cell = cells.removeAt(0);

      if (cell.d > bestCell.d) {
        bestCell = cell;
      }

      if (cell.max - bestCell.d <= precision) continue;

      final h = cell.h / 2;
      cells.addAll([
        _PolylabelCell(cell.x - h, cell.y - h, h, _signedDistanceToPolygonEdges(LatLng(cell.y - h, cell.x - h), rings)),
        _PolylabelCell(cell.x + h, cell.y - h, h, _signedDistanceToPolygonEdges(LatLng(cell.y - h, cell.x + h), rings)),
        _PolylabelCell(cell.x - h, cell.y + h, h, _signedDistanceToPolygonEdges(LatLng(cell.y + h, cell.x - h), rings)),
        _PolylabelCell(cell.x + h, cell.y + h, h, _signedDistanceToPolygonEdges(LatLng(cell.y + h, cell.x + h), rings)),
      ]);
    }

    final point = LatLng(bestCell.y, bestCell.x);
    return _isPointInPolygonWithHoles(point, rings) ? point : null;
  }

  bool _isPointInPolygonWithHoles(LatLng point, List<List<LatLng>> rings) {
    if (rings.isEmpty) return false;
    if (!_pointInRing(point, rings.first)) return false;
    for (final hole in rings.skip(1)) {
      if (_pointInRing(point, hole)) return false;
    }
    return true;
  }

  double _ringSignedArea(List<LatLng> ring) {
    final points = ring.length > 1 && ring.first == ring.last
        ? ring.sublist(0, ring.length - 1)
        : ring;
    if (points.length < 3) return 0;

    var sum = 0.0;
    for (var i = 0; i < points.length; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];
      sum += (p1.longitude * p2.latitude) - (p2.longitude * p1.latitude);
    }
    return sum / 2;
  }

  double _signedDistanceToPolygonEdges(LatLng point, List<List<LatLng>> rings) {
    var minDistSq = double.infinity;

    for (final ring in rings) {
      final points = ring.length > 1 && ring.first == ring.last
          ? ring.sublist(0, ring.length - 1)
          : ring;
      if (points.length < 2) continue;

      for (var i = 0; i < points.length; i++) {
        final a = points[i];
        final b = points[(i + 1) % points.length];
        final distSq = _distanceToSegmentSquared(point, a, b);
        if (distSq < minDistSq) minDistSq = distSq;
      }
    }

    if (minDistSq == double.infinity) return -1;

    final inside = _isPointInPolygonWithHoles(point, rings);
    final dist = math.sqrt(minDistSq);
    return inside ? dist : -dist;
  }

  double _distanceToSegmentSquared(LatLng p, LatLng a, LatLng b) {
    final vx = b.longitude - a.longitude;
    final vy = b.latitude - a.latitude;
    final wx = p.longitude - a.longitude;
    final wy = p.latitude - a.latitude;

    final c1 = (wx * vx) + (wy * vy);
    if (c1 <= 0) {
      final dx = p.longitude - a.longitude;
      final dy = p.latitude - a.latitude;
      return (dx * dx) + (dy * dy);
    }

    final c2 = (vx * vx) + (vy * vy);
    if (c2 <= c1) {
      final dx = p.longitude - b.longitude;
      final dy = p.latitude - b.latitude;
      return (dx * dx) + (dy * dy);
    }

    final t = c1 / c2;
    final projX = a.longitude + (t * vx);
    final projY = a.latitude + (t * vy);
    final dx = p.longitude - projX;
    final dy = p.latitude - projY;
    return (dx * dx) + (dy * dy);
  }

  /// Centra el mapa en el predio dado (polígono o punto).
  void _flyToPredio(Predio predio) {
    try {
      final rings = _extractRings(predio.geometry);
      if (rings.isNotEmpty && rings.first.isNotEmpty) {
        final allPoints = <LatLng>[];
        for (final ring in rings) {
          allPoints.addAll(ring);
        }
        final bounds = LatLngBounds(allPoints.first, allPoints.first);
        for (final point in allPoints.skip(1)) {
          bounds.extend(point);
        }
        _mapCtrl.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(80),
          ),
        );
        return;
      }
      // Fallback: coordenadas directas
      if (predio.latitud != null && predio.longitud != null) {
        _mapCtrl.move(LatLng(predio.latitud!, predio.longitud!), 16.0);
      }
    } catch (_) {
      // Controlador no listo todavía — ignorar silenciosamente.
    }
  }

  /// Centra el mapa en una geometría GeoJSON cruda.
  /// Usado como fallback cuando el predio aún no está en prediosMapaProvider.
  void _flyToFeatureGeometry(Map<String, dynamic>? geometry) {
    if (geometry == null) return;
    try {
      final polygons = _extractPolygons(geometry);
      if (polygons.isNotEmpty) {
        final allPoints = <LatLng>[];
        for (final rings in polygons) {
            for (final ring in rings) {
              allPoints.addAll(ring);
            }
        }
        if (allPoints.isNotEmpty) {
          final bounds = LatLngBounds(allPoints.first, allPoints.first);
            for (final p in allPoints.skip(1)) {
              bounds.extend(p);
            }
          _mapCtrl.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(80),
            ),
          );
          return;
        }
      }
    } catch (_) {
      // Controlador no listo — ignorar.
    }
  }

  void _focusImportedIfNeeded(List<Map<String, dynamic>> features, List<Polygon> polygons) {    if (features.isEmpty || polygons.isEmpty) {
      _lastImportedFeaturesIdentity = null;
      return;
    }

    final identity = identityHashCode(features);
    if (_lastImportedFeaturesIdentity == identity) return;
    _lastImportedFeaturesIdentity = identity;

    final allPoints = <LatLng>[];
    for (final polygon in polygons) {
      allPoints.addAll(polygon.points);
      for (final hole in polygon.holePointsList ?? const <List<LatLng>>[]) {
        allPoints.addAll(hole);
      }
    }
    if (allPoints.isEmpty) return;

    final bounds = LatLngBounds(allPoints.first, allPoints.first);
    for (final point in allPoints.skip(1)) {
      bounds.extend(point);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapCtrl.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(48),
          ),
        );
      } catch (_) {
        // Si el controlador aún no está listo, el usuario puede navegar manualmente.
      }
    });
  }

  Map<String, dynamic>? _geometryAsMap(dynamic geometry) {
    if (geometry is Map<String, dynamic>) return geometry;
    if (geometry is Map) {
      try {
        return Map<String, dynamic>.from(geometry);
      } catch (_) {
        return null;
      }
    }
    if (geometry is String) {
      try {
        final decoded = jsonDecode(geometry);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  List<List<List<LatLng>>> _extractPolygons(Map<String, dynamic>? geometry) {
    if (geometry == null) return const [];

    final type = geometry['type'] as String?;
    final coords = geometry['coordinates'];
    if (type == null || coords is! List || coords.isEmpty) return const [];

    if (type == 'Polygon') {
      final rings = coords
          .whereType<List>()
          .map(_ringToLatLng)
          .where((ring) => ring.length >= 3)
          .toList();
      return rings.isEmpty ? const [] : [rings];
    }

    if (type == 'MultiPolygon') {
      final polygons = <List<List<LatLng>>>[];
      for (final polygon in coords.whereType<List>()) {
        final rings = polygon
            .whereType<List>()
            .map(_ringToLatLng)
            .where((ring) => ring.length >= 3)
            .toList();
        if (rings.isNotEmpty) polygons.add(rings);
      }
      return polygons;
    }

    return const [];
  }

  List<List<LatLng>> _extractRings(Map<String, dynamic>? geometry) {
    final polygons = _extractPolygons(geometry);
    return polygons.isEmpty ? const [] : polygons.first;
  }

  List<LatLng> _ringToLatLng(List<dynamic> ring) {
    try {
      final pairs = <(double, double)>[];
      for (final coord in ring.whereType<List>()) {
        if (coord.length < 2) continue;
        final x = _parseCoord(coord[0]);
        final y = _parseCoord(coord[1]);
        if (x == null || y == null || x.isNaN || y.isNaN) continue;
        pairs.add((x, y));
      }
      if (pairs.isEmpty) return const [];

      // 1) GeoJSON estándar [lng, lat] o invertido [lat, lng]
      final direct = pairs
          .map((p) {
            final x = p.$1;
            final y = p.$2;
            if (_isValidLatLng(lat: y, lng: x)) return LatLng(y, x);
            if (_isValidLatLng(lat: x, lng: y)) return LatLng(x, y);
            return null;
          })
          .whereType<LatLng>()
          .toList();
      if (direct.length >= 3) {
        return direct;
      }

      // 2) Fallback UTM (común en archivos geolocalizados de México)
      final sampleX = pairs.map((p) => p.$1).toList();
      final sampleY = pairs.map((p) => p.$2).toList();
      final utmZone = _detectMexicoUtmZone(sampleX, sampleY);
      if (utmZone == null) {
        return const [];
      }

      final converted = pairs
          .map((p) {
            final ll = _utmToWgs84(p.$1, p.$2, utmZone);
            final lng = ll[0];
            final lat = ll[1];
            if (!_isValidLatLng(lat: lat, lng: lng)) return null;
            return LatLng(lat, lng);
          })
          .whereType<LatLng>()
          .toList();

      return converted;
    } catch (_) {
      return const [];
    }
  }

  double? _parseCoord(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  bool _isValidLatLng({required double lat, required double lng}) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  int? _detectMexicoUtmZone(List<double> sampleX, List<double> sampleY) {
    if (sampleX.isEmpty || sampleY.isEmpty) return null;
    final x = sampleX.first;
    final y = sampleY.first;
    for (final zone in [14, 15, 13, 16]) {
      final ll = _utmToWgs84(x, y, zone);
      final lng = ll[0];
      final lat = ll[1];
      if (lat >= 13 && lat <= 34 && lng >= -120 && lng <= -84) {
        return zone;
      }
    }
    return null;
  }

  List<double> _utmToWgs84(double easting, double northing, int zone,
      {bool isNorth = true}) {
    const a = 6378137.0;
    const f = 1 / 298.257223563;
    const k0 = 0.9996;
    const e0 = 500000.0;

    final e2 = 2 * f - f * f;
    final ePrime2 = e2 / (1 - e2);
    final e1 = (1 - math.sqrt(1 - e2)) / (1 + math.sqrt(1 - e2));

    final x = easting - e0;
    final y = isNorth ? northing : northing - 10000000.0;

    final m = y / k0;
    final mu = m /
        (a * (1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * e2 * e2 * e2 / 256));

    final phi1 = mu +
        (3 * e1 / 2 - 27 * math.pow(e1, 3) / 32) * math.sin(2 * mu) +
        (21 * e1 * e1 / 16 - 55 * math.pow(e1, 4) / 32) * math.sin(4 * mu) +
        (151 * math.pow(e1, 3) / 96) * math.sin(6 * mu) +
        (1097 * math.pow(e1, 4) / 512) * math.sin(8 * mu);

    final sinPhi1 = math.sin(phi1);
    final cosPhi1 = math.cos(phi1);
    final tanPhi1 = math.tan(phi1);

    final n1 = a / math.sqrt(1 - e2 * sinPhi1 * sinPhi1);
    final t1 = tanPhi1 * tanPhi1;
    final c1 = ePrime2 * cosPhi1 * cosPhi1;
    final r1 = a * (1 - e2) / math.pow(1 - e2 * sinPhi1 * sinPhi1, 1.5);
    final d = x / (n1 * k0);

    final lat = phi1 -
        (n1 * tanPhi1 / r1) *
            (d * d / 2 -
                (5 + 3 * t1 + 10 * c1 - 4 * c1 * c1 - 9 * ePrime2) *
                    math.pow(d, 4) /
                    24 +
                (61 +
                        90 * t1 +
                        298 * c1 +
                        45 * t1 * t1 -
                        252 * ePrime2 -
                        3 * c1 * c1) *
                    math.pow(d, 6) /
                    720);

    final lambda0 = ((zone - 1) * 6 - 180 + 3) * math.pi / 180;
    final lng = lambda0 +
        (d -
                (1 + 2 * t1 + c1) * math.pow(d, 3) / 6 +
                (5 -
                        2 * c1 +
                        28 * t1 -
                        3 * c1 * c1 +
                        8 * ePrime2 +
                        24 * t1 * t1) *
                    math.pow(d, 5) /
                    120) /
            cosPhi1;

    return [lng * 180 / math.pi, lat * 180 / math.pi];
  }

  LatLng? _markerPoint(Predio predio, List<List<LatLng>> rings) {
    if (rings.isNotEmpty) {
      return _pointForPolygonRings(rings);
    }

    if (predio.latitud != null && predio.longitud != null) {
      return LatLng(predio.latitud!, predio.longitud!);
    }
    return null;
  }

  Widget _buildMarkerDot(Color color) {
    return Icon(
      Icons.location_pin,
      size: 34,
      color: color,
      shadows: [
        Shadow(
          color: color.withValues(alpha: 0.38),
          blurRadius: 8,
        ),
      ],
    );
  }

  Widget _buildLayersPanel(MapaColorMode mode, MapaBaseLayer currentLayer) {
    final isSatelital = currentLayer == MapaBaseLayer.satelital;
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: SizedBox(
          width: 200,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tipo de mapa',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF555555)),
              ),
              const SizedBox(height: 8),
              _layerButton(
                title: 'Estándar',
                subtitle: 'Calles y etiquetas',
                icon: Icons.map_outlined,
                selected: !isSatelital,
                onTap: () {
                  ref.read(mapaBaseLayerProvider.notifier).state = MapaBaseLayer.estandar;
                  setState(() => _showLayersPanel = false);
                },
              ),
              const SizedBox(height: 6),
              _layerButton(
                title: 'Satelital',
                subtitle: 'Imagen aérea',
                icon: Icons.satellite_alt_outlined,
                selected: isSatelital,
                onTap: () {
                  ref.read(mapaBaseLayerProvider.notifier).state = MapaBaseLayer.satelital;
                  setState(() => _showLayersPanel = false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisualizacionControl(MapaColorMode mode) {
    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: SizedBox(
          width: 240,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Visualizar polígonos por',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF555555),
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonHideUnderline(
                child: DropdownButton<MapaColorMode>(
                  value: mode,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: MapaColorMode.estatusPredio,
                      child: Text('Estatus de predio'),
                    ),
                    DropdownMenuItem(
                      value: MapaColorMode.tipoPropiedad,
                      child: Text('Tipo de propiedad'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    ref.read(mapaColorModeProvider.notifier).state = value;
                    setState(() => _showVisualizacionPanel = false);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _layerButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 210,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredioCard(Predio predio) {
    final mode = ref.watch(mapaColorModeProvider);
    final color = _predioColor(predio, mode);
    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color),
                  ),
                  child: Text(
                    predio.tipoPropiedad,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _selectedPredio = null),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(predio.nombrePropietario, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              predio.claveCatastral,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            if (predio.ejido != null && predio.ejido!.isNotEmpty && predio.ejido != '-') ...[
              const SizedBox(height: 4),
              Text(predio.ejido!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _statusChip('Identificacion', predio.identificacion),
                _statusChip('Levantamiento', predio.levantamiento),
                _statusChip('Negociacion', predio.negociacion),
                _statusChip('COP', predio.cop),
                _statusChip('Poligono', predio.poligonoInsertado),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.info_outline, size: 16),
                label: const Text('Ver detalle'),
                onPressed: () => context.push('/predios/${predio.id}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapturaModal() {
    final area = _detectedAreaM2 > 0 ? _detectedAreaM2 : _calculateAreaSquareMeters(_draftPoints);
    final predios = ref.watch(prediosMapaProvider).asData?.value ?? const <Predio>[];
    final prediosNoVinculados = _prediosSinPoligono(predios);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Captura de predio',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => setState(() => _showCapturaModal = false),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD9D9D9)),
                    ),
                    child: const Icon(Icons.close, size: 13, color: Color(0xFF7A7A7A)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _togglePolygonSelection,
                icon: Icon(_isDrawing ? Icons.close : Icons.gesture_outlined, size: 16),
                label: Text(_isDrawing ? 'Cancelar seleccion' : 'Seleccionar poligono'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8A8A8A),
                  side: const BorderSide(color: Color(0xFFD9D9D9)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _toggleManualLinkMode,
                icon: Icon(
                  _isManualLinkMode ? Icons.link_off_outlined : Icons.link_outlined,
                  size: 16,
                ),
                label: Text(
                  _isManualLinkMode
                      ? 'Salir de asociacion manual'
                      : 'Asociacion manual',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _isManualLinkMode
                      ? AppColors.secondary
                      : const Color(0xFF8A8A8A),
                  side: BorderSide(
                    color: _isManualLinkMode
                        ? AppColors.secondary.withValues(alpha: 0.5)
                        : const Color(0xFFD9D9D9),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            if (_isManualLinkMode) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F9FB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE3E8ED)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Asociacion manual',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _manualFeatureIndex == null
                          ? '1) Toca un poligono huérfano en el mapa.'
                          : 'Poligono seleccionado: ${_poligonoIdFromFeature(importedFeatures: ref.read(importedFeaturesProvider), index: _manualFeatureIndex!)}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF5E6670)),
                    ),
                    const SizedBox(height: 8),
                    Autocomplete<Predio>(
                      optionsBuilder: (value) {
                        final query = value.text.trim().toLowerCase();
                        final source = prediosNoVinculados;
                        if (query.isEmpty) return source.take(20);
                        return source.where((p) {
                          final label = _manualPredioLabel(p).toLowerCase();
                          return label.contains(query);
                        }).take(20);
                      },
                      displayStringForOption: _manualPredioLabel,
                      onSelected: (selected) {
                        setState(() {
                          _manualSelectedPredioId = selected.id;
                          _manualPredioSearchCtrl.text = _manualPredioLabel(selected);
                        });
                      },
                      fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
                        if (textController.text != _manualPredioSearchCtrl.text) {
                          textController.value = TextEditingValue(
                            text: _manualPredioSearchCtrl.text,
                            selection: TextSelection.collapsed(
                              offset: _manualPredioSearchCtrl.text.length,
                            ),
                          );
                        }
                        return TextField(
                          controller: textController,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'Registro de Gestion (sin poligono)',
                            labelStyle: const TextStyle(fontSize: 11),
                            hintText: 'Buscar por clave o propietario',
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (v) {
                            setState(() {
                              _manualPredioSearchCtrl.text = v;
                              _manualSelectedPredioId = null;
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_manualFeatureIndex == null ||
                                _manualSelectedPredioId == null ||
                                _isLinkingManual)
                            ? null
                            : () => _vincularPoligonoManual(predios),
                        icon: _isLinkingManual
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.link_rounded, size: 16),
                        label: Text(_isLinkingManual ? 'Vinculando...' : 'Vincular'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A5B52),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_isDrawing)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Toca un polígono en el mapa para seleccionarlo.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF6A6A6A)),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSelectField(
                    label: 'Proyecto',
                    value: _proyecto,
                    placeholder: 'Sin proyecto',
                    options: const ['Sin proyecto', 'TQI', 'TSNL', 'TQM', 'TAP'],
                    onChanged: (v) => setState(() => _proyecto = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTextField(
                    label: 'Tramo',
                    controller: _tramoCtrl,
                    hintText: 'Ej. Tramo Norte',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _buildTextField(
              label: 'Propietario *',
              controller: _propietarioCtrl,
              hintText: '',
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'Estado',
                    controller: _estadoCtrl,
                    hintText: '',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTextField(
                    label: 'Municipio',
                    controller: _municipioCtrl,
                    hintText: '',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _buildSelectField(
                    label: 'Estatus del predio',
                    value: _estatusPredio,
                    placeholder: 'Sin estatus',
                    options: const ['Sin estatus', 'Liberado', 'No liberado'],
                    onChanged: (v) => setState(() => _estatusPredio = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSelectField(
                    label: 'Tipo de propiedad',
                    value: _tipoPropiedad,
                    placeholder: 'Sin tipo',
                    options: const ['Sin tipo', 'SOCIAL', 'PRIVADA'],
                    onChanged: (v) => setState(() => _tipoPropiedad = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _buildKmField(
                    label: 'KM inicio',
                    controller: _kmInicioCtrl,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildKmField(
                    label: 'KM fin',
                    controller: _kmFinCtrl,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F5F8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Text('Área:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(width: 6),
                  Text(
                    _formatArea(area),
                    style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w700),
                  ),
                  if (_detectingUbicacion) ...[  
                    const SizedBox(width: 8),
                    const Text('Detectando ubicación...', style: TextStyle(fontSize: 11, color: Color(0xFF6A6A6A))),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _draftPoints.length >= 4
                        ? (_importedFeatureIndex != null
                            ? _saveImportedFeatureAsPredio
                            : _saveSelectedPolygon)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2A5B52),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Guardar predio'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _clearSelectedPolygon();
                      setState(() {
                        _tramoCtrl.clear();
                        _propietarioCtrl.clear();
                        _estadoCtrl.clear();
                        _municipioCtrl.clear();
                        _kmInicioCtrl.text = '0+000';
                        _kmFinCtrl.text = '0+000';
                        _proyecto = null;
                        _estatusPredio = null;
                        _tipoPropiedad = null;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7A7A7A),
                      side: const BorderSide(color: Color(0xFFD9D9D9)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),

          ],
        ),
      ),
    );
  }

  void _toggleManualLinkMode() {
    setState(() {
      _isManualLinkMode = !_isManualLinkMode;
      _isDrawing = false;
      if (!_isManualLinkMode) {
        _manualFeatureIndex = null;
        _manualSelectedPredioId = null;
        _manualPredioSearchCtrl.clear();
      }
    });
  }

  List<Predio> _prediosSinPoligono(List<Predio> predios) {
    return predios.where((p) {
      final vinculado = p.poligonoInsertado || p.geometry != null;
      return !vinculado;
    }).toList(growable: false);
  }

  String _manualPredioLabel(Predio predio) {
    final owner = predio.nombrePropietario.trim();
    return '${predio.claveCatastral} · $owner';
  }

  bool _isImportedFeatureLinked(Map<String, dynamic> feature) {
    final s = _linkedPredioIdFromFeature(feature);
    return s != null && s.isNotEmpty;
  }

  String? _linkedPredioIdFromFeature(Map<String, dynamic> feature) {
    final rawProps = feature['properties'];
    if (rawProps is! Map) return null;
    final props = Map<String, dynamic>.from(rawProps);
    final predioId = props['_predioId'] ?? props['predio_id'];
    final s = predioId?.toString().trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  String _poligonoIdFromFeature({
    required List<Map<String, dynamic>> importedFeatures,
    required int index,
  }) {
    if (index < 0 || index >= importedFeatures.length) return 'sin-id';
    final feature = importedFeatures[index];
    final rawProps = feature['properties'];
    if (rawProps is! Map) return 'feature-$index';
    final props = Map<String, dynamic>.from(rawProps);
    final value = props['id_poligono'] ??
        props['ID_POLIGONO'] ??
        props['fid'] ??
        props['FID'] ??
        props['objectid'] ??
        props['OBJECTID'] ??
        props['id'] ??
        props['ID'];
    final asText = value?.toString().trim();
    if (asText != null && asText.isNotEmpty) return asText;
    return 'feature-$index';
  }

  bool _sameGeometryMap(
    Map<String, dynamic>? a,
    Map<String, dynamic>? b,
  ) {
    if (a == null || b == null) return false;
    return jsonEncode(a) == jsonEncode(b);
  }

  List<Map<String, dynamic>> _removeImportedDuplicatesAfterLink({
    required List<Map<String, dynamic>> imported,
    required int selectedIndex,
    required String linkedPredioId,
    required String linkedPoligonoId,
    required Map<String, dynamic> linkedGeometry,
  }) {
    final output = <Map<String, dynamic>>[];
    for (var i = 0; i < imported.length; i++) {
      final feature = imported[i];
      if (i == selectedIndex) {
        continue;
      }

      final samePredio = _linkedPredioIdFromFeature(feature) == linkedPredioId;
      final samePoligono =
          _poligonoIdFromFeature(importedFeatures: imported, index: i) == linkedPoligonoId;
      final geometry = feature['geometry'] is Map
          ? Map<String, dynamic>.from(feature['geometry'] as Map)
          : null;
      final sameGeometry = _sameGeometryMap(geometry, linkedGeometry);

      if (samePredio || samePoligono || sameGeometry) {
        continue;
      }
      output.add(feature);
    }
    return output;
  }

  Future<void> _vincularPoligonoManual(List<Predio> predios) async {
    final idx = _manualFeatureIndex;
    final predioId = _manualSelectedPredioId;
    if (idx == null || predioId == null) return;

    final imported = ref.read(importedFeaturesProvider);
    if (idx < 0 || idx >= imported.length) return;
    final feature = imported[idx];
    final geometry = feature['geometry'] is Map
        ? Map<String, dynamic>.from(feature['geometry'] as Map)
        : null;
    if (geometry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El poligono seleccionado no tiene geometria valida.')),
      );
      return;
    }

    final predio = predios.cast<Predio?>().firstWhere(
          (p) => p?.id == predioId,
          orElse: () => null,
        );
    if (predio == null) return;

    setState(() => _isLinkingManual = true);
    try {
      final idPoligono = _poligonoIdFromFeature(importedFeatures: imported, index: idx);

      if (predio.id.startsWith('local-')) {
        ref.read(localPrediosProvider.notifier).updatePredio(
              predio.copyWith(
                geometry: geometry,
                poligonoInsertado: true,
                updatedAt: DateTime.now(),
              ),
            );
      } else {
        await ref.read(prediosRepositoryProvider).vincularPoligonoConPredio(
              idPoligono: idPoligono,
              idGestion: predio.id,
              geometry: geometry,
            );
      }

        final removedLocalDuplicates =
            ref.read(localPrediosProvider.notifier).removeDuplicatesAfterManualLink(
              keepPredioId: predio.id,
              linkedGeometry: geometry,
              keepClave: predio.claveCatastral,
              linkedOwner: predio.nombrePropietario,
            );

      final updatedImported = _removeImportedDuplicatesAfterLink(
        imported: imported,
        selectedIndex: idx,
        linkedPredioId: predio.id,
        linkedPoligonoId: idPoligono,
        linkedGeometry: geometry,
      );
      ref.read(importedFeaturesProvider.notifier).state = updatedImported;

      ref.invalidate(prediosListProvider);
      ref.invalidate(prediosMapaProvider);

      if (!mounted) return;
      setState(() {
        _isLinkingManual = false;
        _manualFeatureIndex = null;
        _manualSelectedPredioId = null;
        _manualPredioSearchCtrl.clear();
        _isManualLinkMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            removedLocalDuplicates > 0
                ? 'Vinculacion completada. Se eliminaron $removedLocalDuplicates duplicado(s).'
                : 'Vinculacion completada correctamente.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLinkingManual = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo vincular el poligono: $e')),
      );
    }
  }

  Widget _buildCapturaToggleButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _showCapturaModal = !_showCapturaModal),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD9D9D9)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_location_alt_outlined, size: 18, color: Color(0xFF2A5B52)),
              const SizedBox(width: 8),
              const Text(
                'Captura de predio',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _showCapturaModal ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 18,
                color: const Color(0xFF747474),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF555555))),
        const SizedBox(height: 2),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Color(0xFFB2B2B2), fontSize: 13),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDCDCDC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFBABABA)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectField({
    required String label,
    required String? value,
    required String placeholder,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF555555))),
        const SizedBox(height: 2),
        DropdownButtonFormField<String>(
          initialValue: value,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF9A9A9A), size: 18),
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDCDCDC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFBABABA)),
            ),
          ),
          hint: Text(placeholder, style: const TextStyle(color: Color(0xFF9D9D9D))),
          items: options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildKmField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF555555))),
        const SizedBox(height: 2),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 13),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: '0+000',
            hintStyle: const TextStyle(color: Color(0xFFB2B2B2), fontSize: 13),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDCDCDC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFBABABA)),
            ),
          ),
        ),

      ],
    );
  }

  Future<void> _togglePolygonSelection() async {
    if (!_isDrawing) {
      setState(() {
        _isDrawing = true;
        _draftPoints.clear();
        _detectedAreaM2 = 0;
      });
      return;
    }

    setState(() {
      _isDrawing = false;
      _draftPoints.clear();
      _detectedAreaM2 = 0;
    });
  }

  void _clearSelectedPolygon() {
    setState(() {
      _importedFeatureIndex = null;
      _draftPoints.clear();
      _isDrawing = false;
      _detectedAreaM2 = 0;
      _detectingUbicacion = false;
    });
  }

  String? _normalizeProyecto(String? proyecto) {
    if (proyecto == null) return null;
    final normalized = proyecto.trim().toUpperCase();
    if (normalized.isEmpty || normalized == 'SIN PROYECTO') return null;
    return normalized;
  }

  String? _mergeOficioProyectoTag(String? oficioActual, String? proyecto) {
    final cleanOficio = (oficioActual ?? '')
        .replaceAll(RegExp(r'\[PROY:[^\]]+\]\s*'), '')
        .trim();
    final proyectoNormalizado = _normalizeProyecto(proyecto);

    if (proyectoNormalizado == null) {
      return cleanOficio.isEmpty ? null : cleanOficio;
    }

    final tag = '[PROY:$proyectoNormalizado]';
    if (cleanOficio.isEmpty) return tag;
    return '$tag $cleanOficio';
  }

  String? _inferProyectoFromText(String text) {
    final upper = text.toUpperCase();
    const proyectos = ['TQI', 'TSNL', 'TAP', 'TQM'];
    for (final proyecto in proyectos) {
      if (upper.contains(proyecto)) return proyecto;
    }
    return null;
  }

  String _normalizeFieldKey(String input) {
    var value = input.toLowerCase();
    const replacements = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
    };
    replacements.forEach((k, v) => value = value.replaceAll(k, v));
    value = value.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    return value;
  }

  Set<String> _keyParts(String input) {
    final normalized = _normalizeFieldKey(input);
    if (normalized.isEmpty) return <String>{};
    return normalized.split(' ').where((part) => part.isNotEmpty).toSet();
  }

  int _similarityScore(String candidateKey, String expectedKey) {
    final candidateNorm = _normalizeFieldKey(candidateKey).replaceAll(' ', '');
    final expectedNorm = _normalizeFieldKey(expectedKey).replaceAll(' ', '');
    if (candidateNorm.isEmpty || expectedNorm.isEmpty) return 0;

    if (candidateNorm == expectedNorm) return 100;
    if (candidateNorm.contains(expectedNorm) || expectedNorm.contains(candidateNorm)) {
      return 88;
    }

    final candidateParts = _keyParts(candidateKey);
    final expectedParts = _keyParts(expectedKey);
    if (candidateParts.isEmpty || expectedParts.isEmpty) return 0;

    final shared = candidateParts.intersection(expectedParts).length;
    if (shared == 0) return 0;

    if (shared == expectedParts.length) return 80;
    return 60;
  }

  String? _propValue(Map<String, dynamic> props, List<String> keys) {
    String? bestValue;
    var bestScore = 0;

    for (final entry in props.entries) {
      final rawValue = entry.value;
      if (rawValue == null) continue;
      final text = rawValue.toString().trim();
      if (text.isEmpty) continue;

      for (var i = 0; i < keys.length; i++) {
        final key = keys[i];
        final score = _similarityScore(entry.key, key) - (i * 2);
        if (score > bestScore) {
          bestScore = score;
          bestValue = text;
        }
      }
    }

    // Umbral moderado para tolerar variaciones reales de llaves en GeoJSON.
    return bestScore >= 40 ? bestValue : null;
  }

  Map<String, dynamic> _flattenFeatureProps(
    Map<String, dynamic> feature,
    Map<String, dynamic> props,
  ) {
    final merged = <String, dynamic>{...props};

    // Incluir campos de primer nivel del feature (algunos archivos no usan "properties").
    for (final entry in feature.entries) {
      final key = entry.key;
      if (key == 'type' || key == 'geometry' || key == 'properties') continue;
      merged[key] = entry.value;
    }

    // Aplanar maps anidados para detectar llaves tipo attributes.owner, data.proyecto, etc.
    final flattened = <String, dynamic>{...merged};
    for (final entry in merged.entries) {
      final parentKey = entry.key;
      final value = entry.value;
      if (value is Map) {
        final nested = Map<String, dynamic>.from(value);
        for (final nestedEntry in nested.entries) {
          flattened['$parentKey.${nestedEntry.key}'] = nestedEntry.value;
          flattened.putIfAbsent(nestedEntry.key, () => nestedEntry.value);
        }
      }
    }

    return flattened;
  }

  Future<void> _saveSelectedPolygon() async {
    if (_draftPoints.length < 4) return;

    if (_selectedPredio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un predio antes de guardar el poligono.')),
      );
      return;
    }

    final selected = _selectedPredio!;
    final geoJson = _polygonToGeoJson(_draftPoints);
    final proyectoNormalizado = _normalizeProyecto(_proyecto);
    final oficioConProyecto = _mergeOficioProyectoTag(selected.oficio, proyectoNormalizado);

    try {
      final isDemo = ref.read(demoModeProvider);
      final superficieDetectada = _detectedAreaM2 > 0 ? _detectedAreaM2 : _calculateAreaSquareMeters(_draftPoints);

      final isLocal = selected.id.startsWith('local-');

      if (isDemo || isLocal) {
        final notifier = isDemo
            ? ref.read(demoPrediosNotifierProvider.notifier)
            : null;
        final updatedPredio = selected.copyWith(
          geometry: geoJson,
          poligonoInsertado: true,
          superficie: superficieDetectada,
          tipoPropiedad: _tipoPropiedad ?? 'Sin tipo',
          proyecto: proyectoNormalizado,
          oficio: oficioConProyecto,
          cop: _isLiberado(_estatusPredio),
          identificacion: false,
          levantamiento: false,
          negociacion: _isNoLiberado(_estatusPredio),
        );
        if (isLocal) {
          ref.read(localPrediosProvider.notifier).updatePredio(updatedPredio);
        } else {
          notifier!.updatePredio(updatedPredio);
        }
      } else {
        final repo = ref.read(prediosRepositoryProvider);
        await repo.updatePredio(selected.id, {
          'geometry': geoJson,
          'poligono_insertado': true,
          'superficie': superficieDetectada,
          'tipo_propiedad': _tipoPropiedad ?? 'Sin tipo',
          'oficio': oficioConProyecto,
          'cop': _isLiberado(_estatusPredio),
          'identificacion': false,
          'levantamiento': false,
          'negociacion': _isNoLiberado(_estatusPredio),
          'estado': _estadoCtrl.text.trim().isEmpty ? null : _estadoCtrl.text.trim(),
          'municipio': _municipioCtrl.text.trim().isEmpty ? null : _municipioCtrl.text.trim(),
        });
      }

      ref.invalidate(prediosMapaProvider);
      ref.invalidate(prediosListProvider);
      ref.invalidate(propietariosListProvider);
      ref.invalidate(predioDetalleProvider(selected.id));

      if (!mounted) return;
      setState(() {
        _capturedPolygons.add(
          _SavedPolygon(
            points: List<LatLng>.from(_draftPoints),
            estatus: _estatusPredio,
            tipoPropiedad: _tipoPropiedad,
          ),
        );
        _draftPoints.clear();
        _isDrawing = false;
        _detectedAreaM2 = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Poligono guardado correctamente en el predio seleccionado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el poligono: $e')),
      );
    }
  }

  // ── Helpers para features GeoJSON importados ──────────────────────────────

  /// Devuelve el índice del primer feature importado que contiene [point].
  int? _findImportedAtPoint(LatLng point, List<Map<String, dynamic>> features) {
    for (int i = features.length - 1; i >= 0; i--) {
      final polygons = _extractPolygons(_geometryAsMap(features[i]['geometry']));
      if (polygons.isEmpty) continue;
      for (final rings in polygons) {
        if (rings.isEmpty) continue;
        if (_pointInRing(point, rings.first)) return i;
      }
    }
    return null;
  }

  /// Abre el modal de captura pre-relleno con los datos del feature importado.
  void _openCapturaForImportedFeature(Map<String, dynamic> feature, int idx) {
    final rawProps = feature['properties'];
    final props = rawProps is Map
        ? Map<String, dynamic>.from(rawProps)
        : <String, dynamic>{};
    final allProps = _flattenFeatureProps(feature, props);
    final rings = _extractRings(_geometryAsMap(feature['geometry']));
    final points = rings.isNotEmpty ? List<LatLng>.from(rings.first) : <LatLng>[];
    if (points.length > 1 &&
        (points.first.latitude != points.last.latitude ||
            points.first.longitude != points.last.longitude)) {
      points.add(points.first);
    }
    setState(() {
      final tramoDetectado = _propValue(allProps, [
        'tramo',
        'tramo_id',
        'id_tramo',
        'zona',
        'segmento',
        'sector',
      ]);
      final propietarioDetectado = _propValue(allProps, [
        'propietario',
        'propietario_nombre',
        'nombre_propietario',
        'nom_prop',
        'nombre_dueno',
        'dueno',
        'owner_name',
        'owner',
        'titular',
      ]);
      final proyectoDetectado = _propValue(allProps, [
        'proyecto',
        'id_proyecto',
        'proy',
        'nom_proyecto',
        'project',
      ]);

      _importedFeatureIndex = idx;
      _selectedPredio = null;
      _draftPoints
        ..clear()
        ..addAll(points);
      _isDrawing = false;
      _detectedAreaM2 = _calculateAreaSquareMeters(points);
      _showCapturaModal = true;
      _tramoCtrl.text = tramoDetectado ?? '';
      _propietarioCtrl.text = propietarioDetectado ?? '';
      _estadoCtrl.text = _propValue(allProps, ['estado', 'entidad', 'state']) ?? '';
      _municipioCtrl.text = _propValue(allProps, ['municipio', 'municipality', 'city', 'alcaldia']) ?? '';
      _tipoPropiedad = _propValue(allProps, ['tipo_propiedad', 'tipopropiedad', 'uso_suelo', 'usosuelo']);
      _estatusPredio = null;
        _proyecto = _normalizeProyecto(proyectoDetectado) ??
          _inferProyectoFromText([
          proyectoDetectado ?? '',
        _propValue(allProps, ['oficio']) ?? '',
        _propValue(allProps, ['cop_firmado', 'copfirmado']) ?? '',
        _propValue(allProps, ['poligono_dwg', 'dwg']) ?? '',
        _propValue(allProps, ['clave_catastral', 'clave']) ?? '',
          ].join(' '));
    });
    if (_estadoCtrl.text.isEmpty || _municipioCtrl.text.isEmpty) {
      _autofillEstadoMunicipioDesdePoligono();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Este poligono no tiene registro en Gestion. Completa la captura para vincularlo.'),
      ),
    );
  }

  /// Crea un nuevo predio en la base de datos a partir del feature importado activo.
  Future<void> _saveImportedFeatureAsPredio() async {
    if (_draftPoints.length < 4 || _importedFeatureIndex == null) return;
    if (_propietarioCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el nombre del propietario.')),
      );
      return;
    }
    final idx = _importedFeatureIndex!;
    final geoJson = _polygonToGeoJson(_draftPoints);
    final superficie = _detectedAreaM2 > 0
        ? _detectedAreaM2
        : _calculateAreaSquareMeters(_draftPoints);
    final clave = 'IMP-${DateTime.now().millisecondsSinceEpoch}';
    final propietarioNombre = _propietarioCtrl.text.trim();
    final proyectoNormalizado = _normalizeProyecto(_proyecto);
    final oficioConProyecto = _mergeOficioProyectoTag(null, proyectoNormalizado);

    try {
      final isDemo = ref.read(demoModeProvider);
      if (!isDemo) {
        final propietariosRepo = ref.read(propietariosRepositoryProvider);
        final propietario = await propietariosRepo.findOrCreateByNombreCompleto(propietarioNombre);

        final repo = ref.read(prediosRepositoryProvider);
        await repo.createPredio({
          'clave_catastral': clave,
          'tramo': _tramoCtrl.text.trim().isEmpty ? 'T1' : _tramoCtrl.text.trim(),
          'propietario_nombre': propietarioNombre,
          'propietario_id': propietario.id,
          'estado': _estadoCtrl.text.trim().isEmpty ? null : _estadoCtrl.text.trim(),
          'municipio': _municipioCtrl.text.trim().isEmpty ? null : _municipioCtrl.text.trim(),
          'tipo_propiedad': _tipoPropiedad ?? 'PRIVADA',
          'oficio': oficioConProyecto,
          'geometry': geoJson,
          'superficie': superficie,
          'cop': _isLiberado(_estatusPredio),
          'poligono_insertado': true,
          'identificacion': false,
          'levantamiento': false,
          'negociacion': _isNoLiberado(_estatusPredio),
        });
      } else {
        ref.read(demoPrediosNotifierProvider.notifier).addPredio(
              Predio(
                id: clave,
                claveCatastral: clave,
                propietarioNombre: propietarioNombre,
                tramo: _tramoCtrl.text.trim().isEmpty ? 'T1' : _tramoCtrl.text.trim(),
                tipoPropiedad: _tipoPropiedad ?? 'PRIVADA',
                ejido: null,
                kmInicio: _parseKm(_kmInicioCtrl.text),
                kmFin: _parseKm(_kmFinCtrl.text),
                superficie: superficie,
                cop: _isLiberado(_estatusPredio),
                poligonoInsertado: true,
                identificacion: false,
                levantamiento: false,
                negociacion: _isNoLiberado(_estatusPredio),
                oficio: oficioConProyecto,
                proyecto: proyectoNormalizado,
                geometry: geoJson,
                createdAt: DateTime.now(),
              ),
            );
      }

      // Guardar en la tabla de proyectos capturados
      final proyecto = Proyecto(
        id: clave,
        propietario: propietarioNombre,
        tramo: _tramoCtrl.text.trim().isEmpty ? 'T1' : _tramoCtrl.text.trim(),
        tipoPropiedad: _tipoPropiedad ?? 'PRIVADA',
        estado: _estadoCtrl.text.trim().isEmpty ? null : _estadoCtrl.text.trim(),
        municipio: _municipioCtrl.text.trim().isEmpty ? null : _municipioCtrl.text.trim(),
        estatusPredio: _estatusPredio,
        kmInicio: _parseKm(_kmInicioCtrl.text),
        kmFin: _parseKm(_kmFinCtrl.text),
        superficie: superficie,
        proyecto: proyectoNormalizado ?? 'Sin proyecto',
        geometry: geoJson,
        createdAt: DateTime.now(),
      );
      ref.read(proyectosProvider.notifier).addProyecto(proyecto);

      // Eliminar el feature de la lista de importados
      final current = ref.read(importedFeaturesProvider);
      final updated = List<Map<String, dynamic>>.from(current);
      if (idx < updated.length) updated.removeAt(idx);
      ref.read(importedFeaturesProvider.notifier).state = updated;

      ref.invalidate(prediosMapaProvider);
      ref.invalidate(prediosListProvider);
      ref.invalidate(propietariosListProvider);

      if (!mounted) return;
      setState(() {
        _importedFeatureIndex = null;
        _capturedPolygons.add(
          _SavedPolygon(
            points: List<LatLng>.from(_draftPoints),
            estatus: _estatusPredio,
            tipoPropiedad: _tipoPropiedad,
          ),
        );
        _draftPoints.clear();
        _isDrawing = false;
        _detectedAreaM2 = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Predio capturado correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el predio: $e')),
      );
    }
  }

  /// Convierte un double de km (ej. 10.5) al formato "10+500"
  String _formatKm(double km) {
    final enteros = km.truncate();
    final metros = ((km - enteros) * 1000).round();
    return '$enteros+${metros.toString().padLeft(3, '0')}';
  }

  /// Convierte un string KM (ej. "0+000" o "10.5") a double
  double? _parseKm(String kmStr) {
    if (kmStr.trim().isEmpty) return null;
    final str = kmStr.trim();
    if (str.contains('+')) {
      final parts = str.split('+');
      if (parts.length == 2) {
        final km = double.tryParse(parts[0]) ?? 0;
        final metros = double.tryParse(parts[1]) ?? 0;
        return km + (metros / 1000);
      }
    }
    return double.tryParse(str);
  }

  Map<String, dynamic> _polygonToGeoJson(List<LatLng> points) {
    final closed = points.first == points.last ? points : [...points, points.first];
    final ring = closed
        .map((p) => [p.longitude, p.latitude])
        .toList();
    return {
      'type': 'Polygon',
      'coordinates': [ring],
    };
  }

  double _calculateAreaSquareMeters(List<LatLng> points) {
    if (points.length < 3) return 0;
    final closed = points.first == points.last ? points : [...points, points.first];
    if (closed.length < 4) return 0;

    final meanLat = closed.map((p) => p.latitude).reduce((a, b) => a + b) / closed.length;
    final metersPerDegLat = 111132.0;
    final metersPerDegLng = 111320.0 * math.cos(meanLat * math.pi / 180.0);

    double sum = 0;
    for (var i = 0; i < closed.length - 1; i++) {
      final x1 = closed[i].longitude * metersPerDegLng;
      final y1 = closed[i].latitude * metersPerDegLat;
      final x2 = closed[i + 1].longitude * metersPerDegLng;
      final y2 = closed[i + 1].latitude * metersPerDegLat;
      sum += (x1 * y2) - (x2 * y1);
    }
    return (sum.abs() / 2.0);
  }

  Future<void> _autofillEstadoMunicipioDesdePoligono() async {
    if (_draftPoints.length < 3) return;

    final centroid = _polygonCentroid(_draftPoints);
    if (centroid == null) return;

    setState(() => _detectingUbicacion = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${centroid.latitude}&lon=${centroid.longitude}',
      );
      final response = await http.get(uri, headers: const {'Accept': 'application/json'});
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final address = (data['address'] as Map?)?.cast<String, dynamic>() ?? {};

      final estado = (address['state'] ?? address['region'] ?? '').toString().trim();
      final municipio = (
        address['city'] ??
        address['town'] ??
        address['municipality'] ??
        address['county'] ??
        ''
      ).toString().trim();

      if (!mounted) return;
      setState(() {
        if (estado.isNotEmpty) _estadoCtrl.text = estado;
        if (municipio.isNotEmpty) _municipioCtrl.text = municipio;
      });
    } catch (_) {
      // Silencioso: el usuario puede capturar manualmente si no hay geocodificacion.
    } finally {
      if (mounted) {
        setState(() => _detectingUbicacion = false);
      }
    }
  }

  LatLng? _polygonCentroid(List<LatLng> points) {
    if (points.length < 3) return null;
    final clean = points.first == points.last ? points.sublist(0, points.length - 1) : points;
    if (clean.isEmpty) return null;

    final lat = clean.map((p) => p.latitude).reduce((a, b) => a + b) / clean.length;
    final lng = clean.map((p) => p.longitude).reduce((a, b) => a + b) / clean.length;
    return LatLng(lat, lng);
  }

  String _formatArea(double areaM2) {
    if (areaM2 >= 1000000) {
      return '${(areaM2 / 1000000).toStringAsFixed(2)} km2';
    }
    return '${areaM2.toStringAsFixed(2)} m2';
  }

  Widget _statusChip(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppColors.secondary.withValues(alpha: 0.12) : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? AppColors.secondary : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: active ? AppColors.secondaryDark : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _importedFeatureColor(Map<String, dynamic> feature, MapaColorMode mode) {
    final props = feature['properties'];
    final propsMap = props is Map ? Map<String, dynamic>.from(props) : <String, dynamic>{};
    final allProps = _flattenFeatureProps(feature, propsMap);

    if (mode == MapaColorMode.tipoPropiedad) {
      final tipo = _propValue(allProps, [
        'tipo_propiedad',
        'tipopropiedad',
        'tipo propiedad',
        'uso_suelo',
        'usosuelo',
      ]);
      return AppColors.tipoPropiedadColor(tipo ?? 'Sin tipo');
    }

    final estatus = _propValue(allProps, [
      'estatus_predio',
      'estatus',
      'estado_predio',
      'situacion',
    ]);

    if (estatus != null) {
      final normalized = estatus.trim().toLowerCase();
      if (normalized == 'liberado') return _estatusColor('Liberado');
      if (normalized == 'no liberado') return _estatusColor('No liberado');
    }

    return _estatusColor(null);
  }

}

Color _estatusColor(String? estatus) {
  switch (estatus) {
    case 'Liberado':
      return const Color(0xFF2E9E44); // green
    case 'No liberado':
      return const Color(0xFFD63A3A); // red
    default:
      return const Color(0xFF6D6D6D); // gray
  }
}

class _PolylabelCell {
  final double x;
  final double y;
  final double h;
  final double d;

  const _PolylabelCell(this.x, this.y, this.h, this.d);

  double get max => d + h * math.sqrt2;
}

class _SavedPolygon {
  final List<LatLng> points;
  final String? estatus;
  final String? tipoPropiedad;

  const _SavedPolygon({
    required this.points,
    this.estatus,
    this.tipoPropiedad,
  });
}

class _PredioVisualData {
  final Predio predio;
  final Color color;
  final List<List<LatLng>> rings;
  final Polygon? polygon;
  final LatLng? markerPoint;

  const _PredioVisualData({
    required this.predio,
    required this.color,
    required this.rings,
    required this.polygon,
    required this.markerPoint,
  });
}


