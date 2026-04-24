import 'dart:math' as math;

/// Resultado del parsing de un archivo DXF.
class DxfParseResult {
  final List<Map<String, dynamic>> features; // GeoJSON-style features
  final CoordSystem coordSystem;
  final int? detectedUtmZone; // 13-16 para México
  final int totalEntities;

  const DxfParseResult({
    required this.features,
    required this.coordSystem,
    this.detectedUtmZone,
    required this.totalEntities,
  });
}

enum CoordSystem {
  geographic, // ya en WGS84 lat/lng
  utm,        // proyección UTM (requiere zona)
  local,      // coordenadas locales / arbitrarias
}

/// Entidad vectorial extraída de un DXF.
class _DxfEntity {
  final String type; // LWPOLYLINE, POLYLINE, POINT, LINE
  final String layer;
  final List<List<double>> vertices; // cada elemento = [x, y] o [x, y, z]
  final bool closed;
  final Map<String, String> xdata; // datos extendidos XDATA/group 1000

  const _DxfEntity({
    required this.type,
    required this.layer,
    required this.vertices,
    required this.closed,
    this.xdata = const {},
  });
}

class DxfParser {
  // ──────────────────────────────────────────────────────────
  // Punto de entrada principal
  // ──────────────────────────────────────────────────────────

  /// Parsea contenido ASCII DXF y retorna features GeoJSON-compatibles.
  /// [utmZoneOverride] fuerza una zona UTM específica (1-60). Si es null se
  /// auto-detecta o se deja en [CoordSystem.utm] sin convertir.
  static DxfParseResult parse(String content, {int? utmZoneOverride}) {
    final tokens = _tokenize(content);
    final entities = _extractEntities(tokens);

    if (entities.isEmpty) {
      return const DxfParseResult(
        features: [],
        coordSystem: CoordSystem.local,
        totalEntities: 0,
      );
    }

    // ── Detectar sistema de coordenadas ──────────────────────
    final sampleX = entities
        .expand((e) => e.vertices)
        .map((v) => v[0])
        .take(50)
        .toList();
    final sampleY = entities
        .expand((e) => e.vertices)
        .map((v) => v[1])
        .take(50)
        .toList();

    final maxAbsX = sampleX.map((v) => v.abs()).fold<double>(0, math.max);
    final maxAbsY = sampleY.map((v) => v.abs()).fold<double>(0, math.max);

    CoordSystem cs;
    int? utmZone;

    if (maxAbsX <= 180 && maxAbsY <= 90) {
      cs = CoordSystem.geographic;
    } else if (maxAbsX > 100000) {
      // Probablemente UTM – intentar detectar zona desde el rango de X
      cs = CoordSystem.utm;
      utmZone = utmZoneOverride ?? _detectMexicoUtmZone(sampleX, sampleY);
    } else {
      cs = CoordSystem.local;
    }

    // ── Construir features GeoJSON ────────────────────────────
    final features = <Map<String, dynamic>>[];
    for (final entity in entities) {
      if (entity.vertices.isEmpty) continue;

      List<List<double>> coords = entity.vertices;

      // Convertir UTM→WGS84 si aplica
      if (cs == CoordSystem.utm && utmZone != null) {
        coords = coords.map((v) {
          final ll = _utmToWgs84(v[0], v[1], utmZone!);
          return [ll[0], ll[1]]; // [lng, lat]
        }).toList();
      }

      Map<String, dynamic> geometry;
      if (entity.type == 'POINT') {
        geometry = {
          'type': 'Point',
          'coordinates': coords.first,
        };
      } else if (entity.type == 'LINE' || entity.vertices.length == 2 && !entity.closed) {
        geometry = {
          'type': 'LineString',
          'coordinates': coords,
        };
      } else {
        // Polygon: cerrar el anillo si no está cerrado
        final ring = List<List<double>>.from(coords);
        if (ring.first[0] != ring.last[0] || ring.first[1] != ring.last[1]) {
          ring.add(ring.first);
        }
        geometry = {
          'type': 'Polygon',
          'coordinates': [ring],
        };
      }

      features.add({
        'type': 'Feature',
        'geometry': geometry,
        'properties': {
          'layer': entity.layer,
          ...entity.xdata,
        },
      });
    }

    return DxfParseResult(
      features: features,
      coordSystem: cs,
      detectedUtmZone: utmZone,
      totalEntities: entities.length,
    );
  }

  // ──────────────────────────────────────────────────────────
  // Tokenización
  // ──────────────────────────────────────────────────────────

  /// Divide el DXF en pares (groupCode, value).
  static List<(int, String)> _tokenize(String content) {
    final lines = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');

    final tokens = <(int, String)>[];
    for (var i = 0; i + 1 < lines.length; i += 2) {
      final code = int.tryParse(lines[i].trim());
      if (code == null) continue;
      tokens.add((code, lines[i + 1].trim()));
    }
    return tokens;
  }

  // ──────────────────────────────────────────────────────────
  // Extracción de entidades
  // ──────────────────────────────────────────────────────────

  static List<_DxfEntity> _extractEntities(List<(int, String)> tokens) {
    // Encontrar la sección ENTITIES
    int start = -1;
    int end = tokens.length;
    bool inSection = false;

    for (var i = 0; i < tokens.length; i++) {
      final (code, val) = tokens[i];
      if (code == 2 && val == 'ENTITIES') {
        inSection = true;
        start = i + 1;
      } else if (inSection && code == 0 && val == 'ENDSEC') {
        end = i;
        break;
      }
    }

    if (start == -1) return const [];

    final entities = <_DxfEntity>[];
    var i = start;

    while (i < end) {
      final (code, val) = tokens[i];
      if (code != 0) { i++; continue; }

      switch (val) {
        case 'LWPOLYLINE':
          final result = _parseLwPolyline(tokens, i + 1, end);
          if (result != null) entities.add(result.$1);
          i = result?.$2 ?? i + 1;
          break;
        case 'POLYLINE':
          final result = _parsePolyline(tokens, i + 1, end);
          if (result != null) entities.add(result.$1);
          i = result?.$2 ?? i + 1;
          break;
        case 'POINT':
          final result = _parsePoint(tokens, i + 1, end);
          if (result != null) entities.add(result.$1);
          i = result?.$2 ?? i + 1;
          break;
        case 'LINE':
          final result = _parseLine(tokens, i + 1, end);
          if (result != null) entities.add(result.$1);
          i = result?.$2 ?? i + 1;
          break;
        default:
          i++;
      }
    }

    return entities;
  }

  // ── LWPOLYLINE ──────────────────────────────────────────────

  static (_DxfEntity, int)? _parseLwPolyline(
      List<(int, String)> tokens, int start, int end) {
    String layer = '0';
    bool closed = false;
    final vertices = <List<double>>[];
    final xdata = <String, String>{};
    double? currentX;
    var i = start;

    while (i < end) {
      final (code, val) = tokens[i];
      if (code == 0) break; // next entity

      switch (code) {
        case 8:
          layer = val;
          break;
        case 70:
          // bit 0 = closed
          closed = (int.tryParse(val) ?? 0) & 1 == 1;
          break;
        case 10:
          currentX = double.tryParse(val);
          break;
        case 20:
          if (currentX != null) {
            final y = double.tryParse(val);
            if (y != null) vertices.add([currentX!, y]);
            currentX = null;
          }
          break;
        case 1000:
          // XDATA key
          final nextI = i + 1;
          if (nextI < end) {
            final (nextCode, nextVal) = tokens[nextI];
            if (nextCode == 1000 || nextCode == 1005 || nextCode == 1040) {
              xdata[val] = nextVal;
              i = nextI;
            }
          }
          break;
      }
      i++;
    }

    if (vertices.isEmpty) return null;
    return (
      _DxfEntity(
        type: 'LWPOLYLINE',
        layer: layer,
        vertices: vertices,
        closed: closed,
        xdata: xdata,
      ),
      i
    );
  }

  // ── POLYLINE + VERTEX ────────────────────────────────────────

  static (_DxfEntity, int)? _parsePolyline(
      List<(int, String)> tokens, int start, int end) {
    String layer = '0';
    bool closed = false;
    final xdata = <String, String>{};
    var i = start;

    // Header
    while (i < end) {
      final (code, val) = tokens[i];
      if (code == 0) break;
      if (code == 8) layer = val;
      if (code == 70) closed = (int.tryParse(val) ?? 0) & 1 == 1;
      i++;
    }

    // Vertices
    final vertices = <List<double>>[];
    while (i < end) {
      final (code, val) = tokens[i];
      if (code == 0 && val == 'SEQEND') { i++; break; }
      if (code == 0 && val == 'VERTEX') {
        i++;
        double? vx, vy;
        while (i < end) {
          final (vc, vv) = tokens[i];
          if (vc == 0) break;
          if (vc == 10) vx = double.tryParse(vv);
          if (vc == 20) vy = double.tryParse(vv);
          i++;
        }
        if (vx != null && vy != null) vertices.add([vx, vy]);
      } else {
        i++;
      }
    }

    if (vertices.isEmpty) return null;
    return (
      _DxfEntity(
        type: 'POLYLINE',
        layer: layer,
        vertices: vertices,
        closed: closed,
        xdata: xdata,
      ),
      i
    );
  }

  // ── POINT ────────────────────────────────────────────────────

  static (_DxfEntity, int)? _parsePoint(
      List<(int, String)> tokens, int start, int end) {
    String layer = '0';
    double? x, y;
    var i = start;
    while (i < end) {
      final (code, val) = tokens[i];
      if (code == 0) break;
      if (code == 8) layer = val;
      if (code == 10) x = double.tryParse(val);
      if (code == 20) y = double.tryParse(val);
      i++;
    }
    if (x == null || y == null) return null;
    return (
      _DxfEntity(
          type: 'POINT', layer: layer, vertices: [[x, y]], closed: false),
      i
    );
  }

  // ── LINE ─────────────────────────────────────────────────────

  static (_DxfEntity, int)? _parseLine(
      List<(int, String)> tokens, int start, int end) {
    String layer = '0';
    double? x1, y1, x2, y2;
    var i = start;
    while (i < end) {
      final (code, val) = tokens[i];
      if (code == 0) break;
      if (code == 8) layer = val;
      if (code == 10) x1 = double.tryParse(val);
      if (code == 20) y1 = double.tryParse(val);
      if (code == 11) x2 = double.tryParse(val);
      if (code == 21) y2 = double.tryParse(val);
      i++;
    }
    if (x1 == null || y1 == null || x2 == null || y2 == null) return null;
    return (
      _DxfEntity(
          type: 'LINE',
          layer: layer,
          vertices: [[x1, y1], [x2, y2]],
          closed: false),
      i
    );
  }

  // ──────────────────────────────────────────────────────────
  // Detección de zona UTM para México
  // ──────────────────────────────────────────────────────────

  /// Intenta detectar la zona UTM a partir del northing (Y).
  /// Para México el northing va de ~1 600 000 (15°N) a ~3 600 000 (32°N).
  /// Todos los zonas de México tienen northing en ese rango, así que
  /// intentamos probar zonas 13-16 y validar que el resultado caiga en México.
  static int? _detectMexicoUtmZone(List<double> sampleX, List<double> sampleY) {
    if (sampleX.isEmpty || sampleY.isEmpty) return null;
    final x = sampleX.first;
    final y = sampleY.first;

    for (final zone in [14, 15, 13, 16]) {
      final ll = _utmToWgs84(x, y, zone);
      final lng = ll[0];
      final lat = ll[1];
      // México: latitudes 14°N–33°N, longitudes -118°W–-86°W
      if (lat >= 13 && lat <= 34 && lng >= -120 && lng <= -84) {
        return zone;
      }
    }
    return null; // no se pudo determinar
  }

  // ──────────────────────────────────────────────────────────
  // Conversión UTM → WGS84
  // ──────────────────────────────────────────────────────────

  /// Retorna [longitude, latitude] en grados decimales.
  static List<double> _utmToWgs84(double easting, double northing, int zone,
      {bool isNorth = true}) {
    const a = 6378137.0;
    const f = 1 / 298.257223563;
    const k0 = 0.9996;
    const e0 = 500000.0;

    final e2 = 2 * f - f * f;
    final ePrime2 = e2 / (1 - e2);
    final e1 =
        (1 - math.sqrt(1 - e2)) / (1 + math.sqrt(1 - e2));

    final x = easting - e0;
    final y = isNorth ? northing : northing - 10000000.0;

    final m = y / k0;
    final mu = m /
        (a *
            (1 -
                e2 / 4 -
                3 * e2 * e2 / 64 -
                5 * e2 * e2 * e2 / 256));

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
    final r1 =
        a * (1 - e2) / math.pow(1 - e2 * sinPhi1 * sinPhi1, 1.5);
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

    return [
      lng * 180 / math.pi, // longitude
      lat * 180 / math.pi, // latitude
    ];
  }
}
