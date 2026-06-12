import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../carga/utils/geojson_mapper.dart';
import '../models/predio.dart';

final localPrediosProvider =
    StateNotifierProvider<LocalPrediosNotifier, List<Predio>>(
  (ref) => LocalPrediosNotifier(),
);

class LocalPrediosNotifier extends StateNotifier<List<Predio>> {
  LocalPrediosNotifier() : super(const []);

  int removeDuplicatesAfterManualLink({
    required String keepPredioId,
    required Map<String, dynamic> linkedGeometry,
    String? keepClave,
    String? linkedOwner,
  }) {
    if (state.isEmpty) return 0;

    final linkedGeometryJson = jsonEncode(linkedGeometry);
    final normalizedOwner = _normalizeOwner(linkedOwner);
    final current = List<Predio>.from(state);
    final filtered = <Predio>[];
    var removed = 0;

    for (final predio in current) {
      if (predio.id == keepPredioId) {
        filtered.add(predio);
        continue;
      }

      final isLocal = predio.id.startsWith('local-') || _isLocalClave(predio.claveCatastral);
      if (!isLocal) {
        filtered.add(predio);
        continue;
      }

      final sameClave = keepClave != null &&
          keepClave.trim().isNotEmpty &&
          predio.claveCatastral.trim().toUpperCase() == keepClave.trim().toUpperCase();

      final predioGeom = predio.geometry;
      final sameGeometry = predioGeom != null && jsonEncode(predioGeom) == linkedGeometryJson;

      final predioOwner = _normalizeOwner(predio.propietarioNombre ?? predio.propietario?.nombreCompleto);
      final sameOwner = normalizedOwner.isNotEmpty &&
          predioOwner.isNotEmpty &&
          _ownerSimilarity(normalizedOwner, predioOwner) >= 0.95;

      if (sameClave || sameGeometry || sameOwner) {
        removed++;
        continue;
      }

      filtered.add(predio);
    }

    if (removed > 0) {
      state = filtered;
    }
    return removed;
  }

  int normalizeExistingData() {
    if (state.isEmpty) return 0;
    var changed = 0;
    final now = DateTime.now();
    final normalized = state.map((predio) {
      final next = predio.copyWith(
        claveCatastral: _normalizeUpperCode(predio.claveCatastral),
        propietarioNombre: _normalizeOptionalText(predio.propietarioNombre),
        tramo: _normalizeUpperCode(predio.tramo),
        tipoPropiedad: _normalizeTipoPropiedad(predio.tipoPropiedad),
        ejido: _normalizeOptionalText(predio.ejido),
        proyecto: _normalizeProyecto(predio.proyecto),
        copFirmado: _normalizeOptionalText(predio.copFirmado),
        pdfUrl: _normalizeOptionalText(predio.pdfUrl),
        copFecha: predio.copFecha,
        poligonoDwg: _normalizeOptionalText(predio.poligonoDwg),
        oficio: _normalizeOptionalText(predio.oficio),
        updatedAt: now,
      );
      if (!_samePredioValues(predio, next)) {
        changed++;
      }
      return next;
    }).toList(growable: false);

    if (changed > 0) {
      state = normalized;
    }
    return changed;
  }

  int deduplicateExistingData() {
    if (state.length < 2) return 0;

    final merged = <Predio>[];
    for (final predio in state) {
      final existingIndex = _findMatchingPredioIndex(merged, predio);
      if (existingIndex >= 0) {
        merged[existingIndex] = _mergePredios(merged[existingIndex], predio);
      } else {
        merged.add(predio);
      }
    }

    final removed = state.length - merged.length;
    if (removed > 0) {
      state = merged;
    }
    return removed;
  }

  Map<String, int> upsertMany(List<Predio> predios) {
    var created = 0;
    var updated = 0;
    var current = List<Predio>.from(state);

    for (final predio in predios) {
      final index = _findMatchingPredioIndex(current, predio);

      if (index >= 0) {
        current[index] = _mergePredios(current[index], predio);
        updated++;
      } else {
        current = [predio, ...current];
        created++;
      }
    }

    state = current;
    return {'creados': created, 'actualizados': updated};
  }

  int upsertManyFromGeoJsonFeatures(
    List<Map<String, dynamic>> features, {
    String? archivoId,
  }) {
    var inserted = 0;
    for (var i = 0; i < features.length; i++) {
      final feature = features[i];
      final rawProps = feature['properties'];
      final props = rawProps is Map
          ? Map<String, dynamic>.from(rawProps)
          : <String, dynamic>{};
      final mergedProps = <String, dynamic>{...props};
      for (final entry in feature.entries) {
        final key = entry.key;
        if (key == 'type' || key == 'geometry' || key == 'properties') {
          continue;
        }
        mergedProps.putIfAbsent(key, () => entry.value);
      }
      final normalized = GeoJsonMapper.normalizeProperties(mergedProps);
      final geometry = feature['geometry'] is Map
          ? Map<String, dynamic>.from(feature['geometry'] as Map)
          : null;

      final propietarioDetectado = _extractPropietario(normalized, mergedProps);

      final claveBase = _stringValue(normalized['clave_catastral']) ??
          'LOCAL-${DateTime.now().millisecondsSinceEpoch}-${(i + 1).toString().padLeft(4, '0')}';

      final proyectoDetectado = _stringValue(normalized['proyecto']) ??
          GeoJsonMapper.detectarProyecto(normalized) ??
          GeoJsonMapper.inferProyectoDesdeClave(claveBase);

      final estatusNormalizado = _stringValue(normalized['estatus']) ??
          _stringValue(normalized['estatus_predio']);
      final flags = _flagsFromEstatus(estatusNormalizado);
      final observaciones = _extractObservaciones(normalized, mergedProps);

      final superficie = _toDouble(normalized['superficie']) ?? 0;

      final safeClave = claveBase.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final uniqueSuffix = (i + 1).toString().padLeft(4, '0');
      final predioId = 'local-${archivoId ?? DateTime.now().millisecondsSinceEpoch}-$safeClave-$uniqueSuffix';

      final now = DateTime.now();
      final predio = Predio(
        id: predioId,
        claveCatastral: claveBase,
        propietarioNombre: propietarioDetectado,
        tramo: _stringValue(normalized['tramo']) ?? 'T1',
        tipoPropiedad: _stringValue(normalized['tipo_propiedad']) ?? 'PRIVADA',
        ejido: _stringValue(normalized['ejido']),
        estructura: _stringValue(normalized['estructura']),
        estado: _stringValue(normalized['estado']),
        municipio: _stringValue(normalized['municipio']),
        kmInicio: _toDouble(normalized['km_inicio']) ?? 0,
        kmFin: _toDouble(normalized['km_fin']) ?? 0,
        kmLineales: _toDouble(normalized['km_lineales']) ?? 0,
        kmEfectivos: _toDouble(normalized['km_efectivos']) ?? 0,
        superficie: superficie,
        cop: _toBool(normalized['cop']) || flags['cop']!,
        proyecto: proyectoDetectado,
        archivoId: archivoId,
        poligonoInsertado: geometry != null,
        identificacion: _toBool(normalized['identificacion']) || flags['identificacion']!,
        levantamiento: _toBool(normalized['levantamiento']) || flags['levantamiento']!,
        negociacion: _toBool(normalized['negociacion']) || flags['negociacion']!,
        situacionSocial: observaciones,
        latitud: _toDouble(normalized['latitud']),
        longitud: _toDouble(normalized['longitud']),
        geometry: geometry,
        createdAt: now,
        updatedAt: now,
      );

      // Mantener todos los elementos del archivo importado en Gestión;
      // solo evitar duplicación exacta por ID local.
      final alreadyExists = state.any((item) => item.id == predio.id);
      if (!alreadyExists) {
        state = [predio, ...state];
        inserted++;
      }
    }
    return inserted;
  }

  Map<String, bool> _flagsFromEstatus(String? estatus) {
    final canonical = GeoJsonMapper.normalizeEstatusNullable(estatus);
    if (canonical == null || canonical == 'Sin estatus') {
      return {
        'cop': false,
        'identificacion': false,
        'levantamiento': false,
        'negociacion': false,
      };
    }

    if (canonical == 'Liberado') {
      return {
        'cop': true,
        'identificacion': false,
        'levantamiento': false,
        'negociacion': false,
      };
    }

    if (canonical == 'No liberado') {
      return {
        'cop': false,
        'identificacion': false,
        'levantamiento': false,
        'negociacion': true,
      };
    }

    return {
      'cop': false,
      'identificacion': false,
      'levantamiento': false,
      'negociacion': false,
    };
  }

  void clearAll() {
    state = const [];
  }

  void updatePredio(Predio updated) {
    state = [
      for (final p in state)
        if (p.id == updated.id) updated else p,
    ];
  }

  String? _stringValue(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return s;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '').trim());
    }
    return null;
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'si' ||
          normalized == 'sí' ||
          normalized == 'yes';
    }
    return false;
  }

  String? _extractPropietario(
    Map<String, dynamic> normalized,
    Map<String, dynamic> original,
  ) {
    final directo = _stringValue(normalized['propietario_nombre']) ??
        _stringValue(normalized['razon_social']);
    if (directo != null) return directo;

    // Fallback flexible: buscar columnas con nombres comunes de propietario.
    for (final entry in original.entries) {
      final key = _normalizeKey(entry.key.toString());
      final keyLooksLikeOwner = key.contains('propiet') ||
          key.contains('titular') ||
          key.contains('dueno') ||
          key.contains('owner') ||
          key.contains('benefici') ||
          key.contains('razonsocial') ||
          key.contains('nombreprop') ||
          key.contains('nomprop');
      if (!keyLooksLikeOwner) continue;
      final value = _stringValue(entry.value);
      if (value == null) continue;

      // Evitar tomar identificadores técnicos como nombre.
      final looksLikeId = RegExp(r'^[A-Z0-9_\-]{6,}$').hasMatch(value);
      if (looksLikeId) continue;

      return value;
    }

    // Último intento: campo "nombre" cuando no parece id.
    final nombre = _stringValue(normalized['nombre']) ??
        _stringValue(original['nombre']) ??
        _stringValue(original['NOMBRE']);
    if (nombre != null &&
        !RegExp(r'^[A-Z0-9_\-]{6,}$').hasMatch(nombre)) {
      return nombre;
    }

    return null;
  }

  String? _extractObservaciones(
    Map<String, dynamic> normalized,
    Map<String, dynamic> original,
  ) {
    final directo = _stringValue(normalized['situacion_social']);
    if (directo != null) return directo;

    for (final entry in original.entries) {
      final key = _normalizeKey(entry.key.toString());
      final looksLikeObservation = key.contains('observ') ||
          key.contains('nota') ||
          key.contains('coment') ||
          key == 'situacion';
      if (!looksLikeObservation) continue;
      final value = _stringValue(entry.value);
      if (value != null) return value;
    }

    return null;
  }

  String _normalizeKey(String input) {
    var s = input.toLowerCase();
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
    replacements.forEach((k, v) => s = s.replaceAll(k, v));
    return s.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  int _findMatchingPredioIndex(List<Predio> current, Predio incoming) {
    final incomingKey = _mergeKey(incoming);
    return current.indexWhere((item) => _mergeKey(item) == incomingKey);
  }

  String _mergeKey(Predio predio) {
    final clave = predio.claveCatastral.trim().toUpperCase();
    final proyecto = (predio.proyecto ?? 'Sin proyecto').trim().toUpperCase();
    return '$clave|$proyecto';
  }

  Predio _mergePredios(Predio existing, Predio incoming) {
    final now = DateTime.now();
    return Predio(
      id: existing.id,
      claveCatastral: _preferClave(existing.claveCatastral, incoming.claveCatastral),
      propietarioNombre: _preferOwner(existing.propietarioNombre, incoming.propietarioNombre),
      tramo: _preferText(existing.tramo, incoming.tramo, defaultValue: 'T1'),
      tipoPropiedad: _preferText(existing.tipoPropiedad, incoming.tipoPropiedad, defaultValue: 'PRIVADA'),
      ejido: _preferNullableText(existing.ejido, incoming.ejido),
      kmInicio: incoming.kmInicio ?? existing.kmInicio,
      kmFin: incoming.kmFin ?? existing.kmFin,
      kmLineales: incoming.kmLineales ?? existing.kmLineales,
      kmEfectivos: incoming.kmEfectivos ?? existing.kmEfectivos,
      superficie: incoming.superficie ?? existing.superficie,
      cop: existing.cop || incoming.cop,
      copFirmado: _preferNullableText(existing.copFirmado, incoming.copFirmado),
      pdfUrl: _preferNullableText(existing.pdfUrl, incoming.pdfUrl),
      copFecha: incoming.copFecha ?? existing.copFecha,
      poligonoDwg: _preferNullableText(existing.poligonoDwg, incoming.poligonoDwg),
      oficio: _preferNullableText(existing.oficio, incoming.oficio),
      proyecto: _preferNullableText(existing.proyecto, incoming.proyecto),
      poligonoInsertado: existing.poligonoInsertado || incoming.poligonoInsertado,
      identificacion: existing.identificacion || incoming.identificacion,
      levantamiento: existing.levantamiento || incoming.levantamiento,
      negociacion: existing.negociacion || incoming.negociacion,
      latitud: incoming.latitud ?? existing.latitud,
      longitud: incoming.longitud ?? existing.longitud,
      geometry: incoming.geometry ?? existing.geometry,
      propietarioId: incoming.propietarioId ?? existing.propietarioId,
      propietario: incoming.propietario ?? existing.propietario,
      createdAt: existing.createdAt,
      updatedAt: now,
    );
  }

  String _normalizeOwner(String? value) {
    if (value == null) return '';
    var s = value.toLowerCase();
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
    replacements.forEach((k, v) => s = s.replaceAll(k, v));
    final cleaned = s.replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ');
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _isLocalClave(String clave) {
    final s = clave.toUpperCase();
    return s.startsWith('LOCAL-') || s.startsWith('LOCAL_');
  }

  double _ownerSimilarity(String a, String b) {
    if (a == b) return 1.0;
    final aTokens = a.split(' ').where((t) => t.isNotEmpty).toSet();
    final bTokens = b.split(' ').where((t) => t.isNotEmpty).toSet();
    if (aTokens.isEmpty || bTokens.isEmpty) return 0;
    final inter = aTokens.intersection(bTokens).length;
    final union = aTokens.union(bTokens).length;
    return union == 0 ? 0 : inter / union;
  }

  String _normalizeUpperCode(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim().toUpperCase();
  }

  String? _normalizeOptionalText(String? value) {
    final text = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  String _normalizeTipoPropiedad(String value) {
    final upper = _normalizeUpperCode(value);
    if (upper.contains('SOC')) return 'SOCIAL';
    if (upper.contains('PRI')) return 'PRIVADA';
    return upper;
  }

  String? _normalizeProyecto(String? value) {
    final upper = _normalizeOptionalText(value)?.toUpperCase();
    if (upper == null) return null;
    for (final code in const ['TQI', 'TSNL', 'TAP', 'TQM']) {
      if (upper.contains(code)) return code;
    }
    return upper;
  }

  String _preferClave(String current, String incoming) {
    final currentIsLocal = current.toUpperCase().startsWith('LOCAL-') || current.toUpperCase().startsWith('LOCAL_');
    final incomingIsLocal = incoming.toUpperCase().startsWith('LOCAL-') || incoming.toUpperCase().startsWith('LOCAL_');
    if (!incomingIsLocal) return incoming;
    if (!currentIsLocal) return current;
    return incoming.isNotEmpty ? incoming : current;
  }

  String _preferText(String current, String incoming, {String? defaultValue}) {
    final cleanIncoming = incoming.trim();
    if (cleanIncoming.isEmpty) return current;
    if (defaultValue != null && cleanIncoming.toUpperCase() == defaultValue.toUpperCase()) {
      return current.trim().isNotEmpty ? current : cleanIncoming;
    }
    return cleanIncoming;
  }

  String? _preferNullableText(String? current, String? incoming) {
    final inValue = incoming?.trim();
    if (inValue != null && inValue.isNotEmpty) return inValue;
    final curValue = current?.trim();
    return (curValue == null || curValue.isEmpty) ? null : curValue;
  }

  String? _preferOwner(String? current, String? incoming) {
    final inValue = incoming?.trim();
    final curValue = current?.trim();
    if (inValue == null || inValue.isEmpty) return curValue;
    if (curValue == null || curValue.isEmpty) return inValue;
    return inValue.length >= curValue.length ? inValue : curValue;
  }

  bool _samePredioValues(Predio a, Predio b) {
    return a.claveCatastral == b.claveCatastral &&
        a.propietarioNombre == b.propietarioNombre &&
        a.tramo == b.tramo &&
        a.tipoPropiedad == b.tipoPropiedad &&
        a.ejido == b.ejido &&
        a.proyecto == b.proyecto &&
        a.copFirmado == b.copFirmado &&
        a.pdfUrl == b.pdfUrl &&
        a.copFecha == b.copFecha &&
        a.poligonoDwg == b.poligonoDwg &&
        a.oficio == b.oficio;
  }

}
