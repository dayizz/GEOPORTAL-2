import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../utils/geojson_mapper.dart';

class GeoJsonBackgroundParseResult {
  final List<Map<String, dynamic>> features;
  final List<Map<String, dynamic>> preview;
  final Map<String, int> camposDetectados;
  final int totalFeatures;

  const GeoJsonBackgroundParseResult({
    required this.features,
    required this.preview,
    required this.camposDetectados,
    required this.totalFeatures,
  });

  factory GeoJsonBackgroundParseResult.fromMap(Map<String, dynamic> map) {
    final rawFeatures = map['features'] as List? ?? const [];
    final rawPreview = map['preview'] as List? ?? const [];
    final rawCampos = map['camposDetectados'] as Map? ?? const {};

    return GeoJsonBackgroundParseResult(
      features: rawFeatures
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false),
      preview: rawPreview
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false),
      camposDetectados: rawCampos.map(
        (key, value) => MapEntry(key.toString(), (value as num).toInt()),
      ),
      totalFeatures: (map['totalFeatures'] as num?)?.toInt() ?? 0,
    );
  }
}

Future<GeoJsonBackgroundParseResult> parseGeoJsonInBackground({
  required Uint8List bytes,
  required String fileName,
}) async {
  final payload = await compute(
    _parseGeoJsonPayload,
    {
      'bytes': bytes,
      'fileName': fileName,
    },
  );
  return GeoJsonBackgroundParseResult.fromMap(payload);
}

Map<String, dynamic> _parseGeoJsonPayload(Map<String, dynamic> request) {
  final bytes = request['bytes'] as Uint8List;
  final fileName = request['fileName'] as String;
  String jsonStr;
  try {
    jsonStr = utf8.decode(bytes);
  } on FormatException {
    // Algunos exportadores GIS guardan texto con bytes no UTF-8 estrictos.
    jsonStr = utf8.decode(bytes, allowMalformed: true);
  }
  if (jsonStr.startsWith('\uFEFF')) {
    jsonStr = jsonStr.substring(1);
  }
  final raw = jsonDecode(jsonStr);

  if (raw is! Map) {
    throw const FormatException(
      'El archivo GeoJSON no tiene una estructura valida.',
    );
  }

  final geojson = Map<String, dynamic>.from(raw);
  final normalized = _normalizeGeoJson(geojson);
  if (normalized == null) {
    throw const FormatException(
      'El archivo debe contener una FeatureCollection, Feature o geometria GeoJSON.',
    );
  }

  final features = normalized['features'] as List?;
  if (features == null || features.isEmpty) {
    throw const FormatException('El archivo no contiene features validos.');
  }

  final nombreBase = fileName
      .replaceAll(RegExp(r'\.[^.]+$'), '')
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .toUpperCase();

  final enrichedFeatures = <Map<String, dynamic>>[];
  for (var i = 0; i < features.length; i++) {
    final fmap = _asStringDynamicMap(features[i]);
    if (fmap == null) continue;

    final propsOriginal = _asStringDynamicMap(fmap['properties']) ?? <String, dynamic>{};
    final props = GeoJsonMapper.normalizeProperties(propsOriginal);
    final geometry = _asStringDynamicMap(fmap['geometry']);

    final claveActual = _pickVal(props, const [
      'clave_catastral',
      'CLAVE_CATASTRAL',
      'id_catastral',
      'ID_CATASTRAL',
      'clave',
      'CLAVE',
      'folio',
      'FOLIO',
      'id_sedatu',
      'ID_SEDATU',
      'id_predio',
      'ID_PREDIO',
      'cvegeo',
      'CVEGEO',
      'id',
      'ID',
      'fid',
      'FID',
      'gid',
      'GID',
    ]);

    final claveFinal =
        claveActual ?? '$nombreBase-${(i + 1).toString().padLeft(4, '0')}';
    final superficieExistente = _toDouble(
      props['superficie'] ??
          props['SUPERFICIE'] ??
          props['area'] ??
          props['AREA'] ??
          props['shape_area'] ??
          props['SHAPE_AREA'] ??
          props['area_m2'],
    );
    final superficieQgis = superficieExistente ?? 0;
    final estatusNormalizado = _extractNormalizedStatus(props, fmap);

    final propsEnriched = Map<String, dynamic>.from(propsOriginal)
      ..addAll(props)
      ..['clave_catastral'] =
          ((props['clave_catastral']?.toString().trim().isNotEmpty ?? false)
              ? props['clave_catastral']
              : claveFinal)
      ..['id_sedatu'] =
          ((props['id_sedatu']?.toString().trim().isNotEmpty ?? false)
              ? props['id_sedatu']
              : claveFinal)
      ..['superficie'] = superficieQgis
      ..['area_m2'] = superficieQgis;

    if (estatusNormalizado != null) {
      propsEnriched['estatus'] = estatusNormalizado;
      propsEnriched['estatus_predio'] = estatusNormalizado;
      propsEnriched['_estatusColorKey'] = estatusNormalizado;
    }

    enrichedFeatures.add({
      ...fmap,
      '_geojsonBackgroundNormalized': true,
      'properties': propsEnriched,
      'geometry': geometry,
    });
  }

  if (enrichedFeatures.isEmpty) {
    throw const FormatException(
      'El archivo contiene features, pero ninguna tiene estructura valida para importar.',
    );
  }

  const aliasProyecto = [
    'proyecto',
    'PROYECTO',
    'nombre_proyecto',
    'tramo_proyecto',
    'obra',
    'OBRA',
  ];
  const aliasTramo = ['tramo', 'TRAMO', 'tramo_vial', 'seccion', 'SECCION'];
  const aliasPropietario = [
    'propietario',
    'propietario_nombre',
    'nombre_propietario',
    'nom_propietario',
    'PROPIETARIO',
    'titular',
    'TITULAR',
    'nombre',
  ];
  const aliasClave = [
    'clave_catastral',
    'id_catastral',
    'clave',
    'folio',
    'id_sedatu',
    'id_predio',
    'cvegeo',
    'id',
    'fid',
    'gid',
  ];
  const aliasSuperficie = [
    'superficie',
    'SUPERFICIE',
    'area',
    'AREA',
    'shape_area',
    'SHAPE_AREA',
    'area_ha',
    'area_m2',
  ];
  const aliasKmInicio = [
    'km_inicio',
    'KM_INICIO',
    'cadenamiento_inicial',
    'cad_ini',
    'km_i',
  ];
  const aliasKmFin = [
    'km_fin',
    'KM_FIN',
    'cadenamiento_final',
    'cad_fin',
    'km_f',
  ];
  const aliasEstatus = [
    'estatus',
    'ESTATUS',
    'estatus_predio',
    'ESTATUS_PREDIO',
    'status',
    'STATUS',
    'estado_liberacion',
    'ESTADO_LIBERACION',
    'liberacion',
    'LIBERACION',
  ];

  final camposDetect = <String, int>{};
  for (final f in enrichedFeatures) {
    final p = _asStringDynamicMap(f['properties']) ?? <String, dynamic>{};
    if (_pickVal(p, aliasClave) != null) {
      camposDetect['clave'] = (camposDetect['clave'] ?? 0) + 1;
    }
    if (_pickVal(p, aliasProyecto) != null) {
      camposDetect['proyecto'] = (camposDetect['proyecto'] ?? 0) + 1;
    }
    if (_pickVal(p, aliasTramo) != null) {
      camposDetect['tramo'] = (camposDetect['tramo'] ?? 0) + 1;
    }
    if (_pickVal(p, aliasPropietario) != null) {
      camposDetect['propietario'] = (camposDetect['propietario'] ?? 0) + 1;
    }
    if (_pickVal(p, aliasSuperficie) != null) {
      camposDetect['superficie'] = (camposDetect['superficie'] ?? 0) + 1;
    }
    if (_pickVal(p, aliasKmInicio) != null) {
      camposDetect['km_inicio'] = (camposDetect['km_inicio'] ?? 0) + 1;
    }
    if (_pickVal(p, aliasKmFin) != null) {
      camposDetect['km_fin'] = (camposDetect['km_fin'] ?? 0) + 1;
    }
    if (_pickVal(p, aliasEstatus) != null) {
      camposDetect['estatus'] = (camposDetect['estatus'] ?? 0) + 1;
    }
  }

  final preview = enrichedFeatures.take(5).map((featureMap) {
    final props = _asStringDynamicMap(featureMap['properties']) ??
        <String, dynamic>{};

    final normalizedProps = GeoJsonMapper.normalizeProperties(props);
    return <String, dynamic>{
      'clave': _pickVal(normalizedProps, aliasClave) ?? 'Sin clave',
      'proyecto': _pickVal(normalizedProps, aliasProyecto),
      'tramo': _pickVal(normalizedProps, aliasTramo),
      'propietario': _pickVal(normalizedProps, aliasPropietario),
      'superficie': normalizedProps['superficie'] ??
          normalizedProps['SUPERFICIE'] ??
          normalizedProps['area'] ??
          normalizedProps['area_m2'] ??
          0,
      'estatus': _pickVal(normalizedProps, aliasEstatus) ?? 'Sin estatus',
      'tipo_geom': _asStringDynamicMap(featureMap['geometry'])?['type'],
    };
  }).toList(growable: false);

  return {
    'features': enrichedFeatures,
    'preview': preview,
    'camposDetectados': camposDetect,
    'totalFeatures': enrichedFeatures.length,
  };
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

String? _pickVal(Map<String, dynamic> props, List<String> keys) {
  for (final key in keys) {
    final v = props[key]?.toString().trim();
    if (v != null && v.isNotEmpty && v != 'null') return v;
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

String? _extractNormalizedStatus(
  Map<String, dynamic> props,
  Map<String, dynamic> feature,
) {
  final candidates = <String?>[];

  const directKeys = [
    'estatus',
    'ESTATUS',
    'estatus_predio',
    'ESTATUS_PREDIO',
    'status',
    'STATUS',
    'estado_liberacion',
    'ESTADO_LIBERACION',
    'liberacion',
    'LIBERACION',
    'estatus_juridico',
    'ESTATUS_JURIDICO',
  ];

  for (final key in directKeys) {
    candidates.add(props[key]?.toString());
  }

  for (final entry in props.entries) {
    final normalizedKey = _normalizeStatusKey(entry.key);
    if (normalizedKey == 'estatus' ||
        normalizedKey == 'estatuspredio' ||
        normalizedKey == 'status' ||
        normalizedKey == 'estadoliberacion' ||
        normalizedKey == 'liberacion' ||
        normalizedKey == 'estatusjuridico' ||
        normalizedKey == 'situacionjuridica' ||
        normalizedKey.startsWith('estatus')) {
      candidates.add(entry.value?.toString());
    }
  }

  for (final entry in feature.entries) {
    if (entry.key == 'properties' || entry.key == 'geometry' || entry.key == 'type') {
      continue;
    }
    final normalizedKey = _normalizeStatusKey(entry.key);
    if (normalizedKey == 'estatus' || normalizedKey.startsWith('estatus')) {
      candidates.add(entry.value?.toString());
    }
  }

  for (final candidate in candidates) {
    final normalized = _normalizeStatusValue(candidate);
    if (normalized != null) return normalized;
  }

  return null;
}

String _normalizeStatusKey(String key) {
  return key
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
}

String? _normalizeStatusValue(String? value) {
  if (value == null) return null;
  final compact = value
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (compact.isEmpty || compact == 'null') return null;
  if (compact == '1' || compact == 'true' || compact == 'si') return 'Liberado';
  if (compact == '0' || compact == 'false' || compact == 'no') return 'No liberado';
  if (compact.contains('no liberad') ||
      compact.contains('no firmado') ||
      compact.contains('no autorizado') ||
      compact.contains('pendiente') ||
      compact.contains('en proceso')) {
    return 'No liberado';
  }
  if (compact.contains('liberad') || compact.contains('firmado')) {
    return 'Liberado';
  }
  if (compact.contains('sin estatus') || compact.contains('sin estado') || compact.contains('sin dato')) {
    return 'Sin estatus';
  }
  return 'Sin estatus';
}

List<Map<String, dynamic>> _normalizeFeatures(List<Map<String, dynamic>> features) {
  return features.map((feature) {
    final properties = feature['properties'] as Map<String, dynamic>? ?? {};
    final normalizedProperties = GeoJsonMapper.normalizeProperties(properties);
    if (!normalizedProperties.containsKey('estatus')) {
      normalizedProperties['estatus'] = 'Sin estatus';
    }
    return {
      ...feature,
      'properties': normalizedProperties,
    };
  }).toList();
}
