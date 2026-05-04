import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

import '../../../core/google_sheets/google_sheets_service.dart';

final archivosGeoJsonRepositoryProvider = Provider<ArchivosGeoJsonRepository>(
  (ref) {
    return ArchivosGeoJsonRepository(Supabase.instance.client);
  },
);

class ArchivosGeoJsonRepository {
  final SupabaseClient _client;
  final GoogleSheetsService? _sheets;

  ArchivosGeoJsonRepository(this._client, {GoogleSheetsService? sheets})
      : _sheets = sheets;

  static const _uuid = Uuid();
  static const int _sheetsMaxStoredFeatures = 40;
  static const int _sheetsMaxStoredFeaturesBytes = 180000;

  bool get _usingSheets => _sheets != null;

  String _toIso(dynamic value, {required DateTime fallback}) {
    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) return parsed.toIso8601String();
    }
    return fallback.toIso8601String();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase().trim();
      return v == 'true' || v == '1' || v == 'si' || v == 'sí' || v == 'yes';
    }
    return false;
  }

  List<dynamic> _toFeatures(dynamic value) {
    if (value is List) return value;
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded;
      } catch (_) {
        return const [];
      }
    }
    return const [];
  }

  List<Map<String, dynamic>> _featuresForSheets(
    List<Map<String, dynamic>> features,
  ) {
    if (features.isEmpty) return const [];

    final kept = <Map<String, dynamic>>[];
    var bytes = 0;

    for (final feature in features) {
      final encoded = jsonEncode(feature);
      final encodedBytes = utf8.encode(encoded).length;
      final exceedsCount = kept.length >= _sheetsMaxStoredFeatures;
      final exceedsBytes = (bytes + encodedBytes) > _sheetsMaxStoredFeaturesBytes;
      if (exceedsCount || exceedsBytes) break;

      kept.add(feature);
      bytes += encodedBytes;
    }

    return kept;
  }

  /// Obtiene todos los archivos guardados, ordenados del más reciente al más antiguo.
  Future<List<Map<String, dynamic>>> getArchivos() async {
    if (_usingSheets) {
      final rows = await _sheets!.getRows(sheet: 'archivos_geojson');
      final normalized = rows.map((row) {
        final now = DateTime.now();
        return <String, dynamic>{
          'id': row['id']?.toString() ?? _uuid.v4(),
          'nombre': row['nombre']?.toString() ?? 'archivo',
          'features_count': _toInt(row['features_count']),
          'features': _toFeatures(row['features']),
          'sincronizado': _toBool(row['sincronizado']),
          'encontrados': _toInt(row['encontrados']),
          'creados': _toInt(row['creados']),
          'errores': _toInt(row['errores']),
          'created_at': _toIso(row['created_at'], fallback: now),
          'updated_at': row['updated_at'] == null
              ? null
              : _toIso(row['updated_at'], fallback: now),
        };
      }).toList();

      normalized.sort((a, b) {
        final aDate = DateTime.parse(a['created_at'] as String);
        final bDate = DateTime.parse(b['created_at'] as String);
        return bDate.compareTo(aDate);
      });

      return normalized;
    }

    final response = await _client
        .from('archivos_geojson')
        .select()
        .order('created_at', ascending: false);
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Guarda un archivo GeoJSON en la BD. Devuelve el registro creado (con su UUID).
  Future<Map<String, dynamic>> saveArchivo({
    required String nombre,
    required List<Map<String, dynamic>> features,
    bool sincronizado = false,
    int encontrados = 0,
    int creados = 0,
    int errores = 0,
  }) async {
    if (_usingSheets) {
      final now = DateTime.now().toIso8601String();
      final storedFeatures = _featuresForSheets(features);
      final truncated = storedFeatures.length < features.length;
      final row = <String, dynamic>{
        'id': _uuid.v4(),
        'nombre': nombre,
        'features_count': features.length,
        'features': storedFeatures,
        'features_stored': storedFeatures.length,
        'features_truncated': truncated,
        'sincronizado': sincronizado,
        'encontrados': encontrados,
        'creados': creados,
        'errores': errores,
        'created_at': now,
        'updated_at': now,
      };
      final saved = await _sheets!.upsertRow(
        sheet: 'archivos_geojson',
        row: row,
        idField: 'id',
      );
      return Map<String, dynamic>.from(saved);
    }

    final response = await _client
        .from('archivos_geojson')
        .insert({
          'nombre': nombre,
          'features_count': features.length,
          'features': features,
          'sincronizado': sincronizado,
          'encontrados': encontrados,
          'creados': creados,
          'errores': errores,
        })
        .select()
        .single();
    return Map<String, dynamic>.from(response);
  }

  /// Elimina un archivo de la BD por su UUID.
  Future<void> deleteArchivo(String id) async {
    if (_usingSheets) {
      await _sheets!.deleteById(sheet: 'archivos_geojson', id: id, idField: 'id');
      return;
    }
    await _client.from('archivos_geojson').delete().eq('id', id);
  }
}
