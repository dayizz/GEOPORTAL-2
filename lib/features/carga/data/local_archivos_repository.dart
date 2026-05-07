import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

final localArchivosRepositoryProvider = Provider<LocalArchivosRepository>(
  (ref) => LocalArchivosRepository(),
);

/// Persiste la lista de archivos importados en localStorage del navegador.
class LocalArchivosRepository {
  static const _key = 'archivos_importados';
  static const _uuid = Uuid();

  Future<List<Map<String, dynamic>>> getArchivos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> saveArchivo({
    required String nombre,
    required List<Map<String, dynamic>> features,
    int? rowCount,
    bool sincronizado = false,
    int encontrados = 0,
    int creados = 0,
    int errores = 0,
  }) async {
    final existing = await getArchivos();
    final now = DateTime.now().toIso8601String();
    final id = _uuid.v4();
    // Guardar máximo 20 features para no saturar localStorage
    final storedFeatures = features.length > 20 ? features.sublist(0, 20) : features;
    final entry = <String, dynamic>{
      'id': id,
      'nombre': nombre,
      'features_count': rowCount ?? features.length,
      'features': storedFeatures,
      'sincronizado': sincronizado,
      'encontrados': encontrados,
      'creados': creados,
      'errores': errores,
      'created_at': now,
      'updated_at': now,
    };
    existing.insert(0, entry);
    await _save(existing);
    return entry;
  }

  Future<void> deleteArchivo(String id) async {
    final existing = await getArchivos();
    existing.removeWhere((e) => e['id'] == id);
    await _save(existing);
  }

  Future<void> deleteAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<void> _save(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list));
  }
}
