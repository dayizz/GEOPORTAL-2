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
  bool _showCapturaModal = true;
  bool _showLayersPanel = false;
  bool _isDrawing = false;
  bool _draftClosed = false;
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
  int? _lastImportedFeaturesIdentity;

  static const _defaultCenter = LatLng(20.72, -100.35);
  static const _defaultZoom = 10.0;

  @override
  void dispose() {
    _tramoCtrl.dispose();
    _propietarioCtrl.dispose();
    _estadoCtrl.dispose();
    _municipioCtrl.dispose();
    _kmInicioCtrl.dispose();
    _kmFinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prediosAsync = ref.watch(prediosMapaProvider);
    final baseLayer = ref.watch(mapaBaseLayerProvider);
    final colorMode = ref.watch(mapaColorModeProvider);
    final importedFeatures = ref.watch(importedFeaturesProvider);
    final importedPolygons = _buildImportedPolygons(importedFeatures);
    final importedMarkers = _buildImportedMarkers(importedPolygons);
    _focusImportedIfNeeded(importedFeatures, importedPolygons);

    return AppScaffold(
      currentIndex: 0,
      title: 'Mapa LDDV',
      child: Stack(
        children: [
          prediosAsync.when(
            data: (predios) {
              final visuals = _buildVisualData(predios, colorMode);
              return FlutterMap(
                mapController: _mapCtrl,
                options: MapOptions(
                  initialCenter: _defaultCenter,
                  initialZoom: _defaultZoom,
                  onTap: (_, point) {
                    // 1. Polígonos importados (tienen prioridad cuando no estamos en modo dibujo)
                    if (importedFeatures.isNotEmpty && !_isDrawing) {
                      final impIdx = _findImportedAtPoint(point, importedFeatures);
                      if (impIdx != null) {
                        _openCapturaForImportedFeature(importedFeatures[impIdx], impIdx);
                        return;
                      }
                    }
                    // 2. Predios guardados en DB
                    final tappedVisual = _findVisualAtPoint(point, visuals);
                    var shouldAutofillUbicacion = false;
                    setState(() {
                      if (tappedVisual != null) {
                        _selectedPredio = tappedVisual.predio;
                        if (_isDrawing && tappedVisual.rings.isNotEmpty) {
                          final selectedPoints = List<LatLng>.from(tappedVisual.rings.first);
                          if (selectedPoints.first != selectedPoints.last) {
                            selectedPoints.add(selectedPoints.first);
                          }
                          _draftPoints
                            ..clear()
                            ..addAll(selectedPoints);
                          _draftClosed = true;
                          _isDrawing = false;
                          _detectedAreaM2 = _calculateAreaSquareMeters(_draftPoints);
                          shouldAutofillUbicacion = true;
                        }
                        return;
                      }

                      _selectedPredio = null;
                      if (_isDrawing) {
                        _draftPoints.clear();
                        _draftClosed = false;
                        _detectedAreaM2 = 0;
                      }
                    });
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
                              color: _savedPolygonColor(sp, colorMode).withValues(alpha: 0.32),
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
                          color: _draftPolygonColor(colorMode).withValues(alpha: 0.25),
                          borderColor: _draftPolygonColor(colorMode),
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: visuals
                        .where((v) => v.markerPoint != null)
                        .map(
                          (v) => Marker(
                            point: v.markerPoint!,
                            width: 36,
                            height: 36,
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedPredio = v.predio),
                              child: _buildMarkerDot(v.color, v.predio.cop),
                            ),
                          ),
                        )
                        .toList(),
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
                Material(
                  color: Colors.white,
                  elevation: 4,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _showLayersPanel = !_showLayersPanel),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.layers_outlined,
                        size: 22,
                        color: _showLayersPanel ? AppColors.primary : const Color(0xFF555555),
                      ),
                    ),
                  ),
                ),
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
          // Badge de polígonos importados pendientes
          if (importedFeatures.isNotEmpty)
            Positioned(
              top: 72,
              left: 16,
              child: Material(
                color: const Color(0xFFFF8C00),
                borderRadius: BorderRadius.circular(20),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.upload_file, color: Colors.white, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        '${importedFeatures.length} polígono${importedFeatures.length == 1 ? '' : 's'} importado${importedFeatures.length == 1 ? '' : 's'} — toca para capturar',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
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
              color: color.withValues(alpha: 0.28),
              borderColor: color,
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

  List<Polygon> _buildImportedPolygons(List<Map<String, dynamic>> features) {
    final polygons = <Polygon>[];
    for (int i = 0; i < features.length; i++) {
      final feature = features[i];
      final geometry = _geometryAsMap(feature['geometry']);
      final extractedPolygons = _extractPolygons(geometry);
      print('🧭 Import feature $i: type=${geometry?['type']} polygons=${extractedPolygons.length}');
      for (final rings in extractedPolygons) {
        if (rings.isEmpty || rings.first.length < 3) continue;
        polygons.add(
          Polygon(
            points: rings.first,
            holePointsList: rings.length > 1 ? rings.sublist(1) : const [],
            color: const Color(0x33FF8C00),
            borderColor: const Color(0xFFFF8C00),
            borderStrokeWidth: 2.5,
          ),
        );
      }
    }
    print('🗺️ Polígonos importados renderizables: ${polygons.length}');
    return polygons;
  }

  List<Marker> _buildImportedMarkers(List<Polygon> polygons) {
    final markers = <Marker>[];
    for (final polygon in polygons) {
      final center = _centroidOfRing(polygon.points);
      if (center == null) continue;
      markers.add(
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
      );
    }
    return markers;
  }

  LatLng? _centroidOfRing(List<LatLng> ring) {
    if (ring.length < 3) return null;
    final points = ring.length > 1 && ring.first == ring.last
        ? ring.sublist(0, ring.length - 1)
        : ring;
    if (points.isEmpty) return null;

    final lat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final lng = points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
    return LatLng(lat, lng);
  }

  void _focusImportedIfNeeded(List<Map<String, dynamic>> features, List<Polygon> polygons) {
    if (features.isEmpty || polygons.isEmpty) {
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
        print('⚠️ No se pudo interpretar anillo: sin lat/lng ni zona UTM detectable');
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

      print('✅ Anillo convertido desde UTM zona ${utmZone}N: ${converted.length} puntos');
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
    if (predio.latitud != null && predio.longitud != null) {
      return LatLng(predio.latitud!, predio.longitud!);
    }
    if (rings.isEmpty || rings.first.isEmpty) return null;

    final points = rings.first;
    final lat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final lng = points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
    return LatLng(lat, lng);
  }

  Widget _buildMarkerDot(Color color, bool tieneCop) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.38),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        Positioned(
          right: -1,
          top: -1,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: tieneCop ? AppColors.secondary : Colors.grey.shade500,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.4),
            ),
          ),
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
          width: 220,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ver color de mapa por',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
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
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBaseLayerControl(MapaBaseLayer currentLayer) {
    final isSatelital = currentLayer == MapaBaseLayer.satelital;
    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Text(
              'Capa',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            _layerButton(
              title: 'Estandar',
              subtitle: 'Calles y etiquetas',
              icon: Icons.map_outlined,
              selected: !isSatelital,
              onTap: () => ref.read(mapaBaseLayerProvider.notifier).state = MapaBaseLayer.estandar,
            ),
            const SizedBox(height: 6),
            _layerButton(
              title: 'Satelital',
              subtitle: 'Imagen aerea',
              icon: Icons.satellite_alt_outlined,
              selected: isSatelital,
              onTap: () => ref.read(mapaBaseLayerProvider.notifier).state = MapaBaseLayer.satelital,
            ),
          ],
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
                    onPressed: _draftPoints.length >= 4 ? _saveSelectedPolygon : null,
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
          value: value,
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
        _draftClosed = false;
        _draftPoints.clear();
        _detectedAreaM2 = 0;
      });
      return;
    }

    setState(() {
      _isDrawing = false;
      _draftPoints.clear();
      _draftClosed = false;
      _detectedAreaM2 = 0;
    });
  }

  void _clearSelectedPolygon() {
    setState(() {
      _importedFeatureIndex = null;
      _draftPoints.clear();
      _draftClosed = false;
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

    // Feature importado → crear nuevo predio
    if (_importedFeatureIndex != null) {
      await _saveImportedFeatureAsPredio();
      return;
    }

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

      if (isDemo) {
        ref.read(demoPrediosNotifierProvider.notifier).updatePredio(
              selected.copyWith(
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
              ),
            );
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
        _draftClosed = false;
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
      _draftClosed = true;
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
        _draftClosed = false;
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

}

Color _estatusColor(String? estatus) {
  switch (estatus) {
    case 'Liberado':
      return const Color(0xFF2E7D32); // green
    case 'No liberado':
      return const Color(0xFFC62828); // red
    default:
      return const Color(0xFF757575); // gray
  }
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


