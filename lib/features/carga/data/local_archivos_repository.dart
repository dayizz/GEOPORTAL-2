import 'dart:convert';
import 'dart:io' show File, Directory;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

final localArchivosRepositoryProvider = Provider<LocalArchivosRepository>(
  (ref) => LocalArchivosRepository(),
);

/// Persiste la lista de archivos importados.
///
/// - Web: usa shared_preferences (localStorage), cap de 20 features por archivo.
/// - Desktop (macOS): usa shared_preferences para el índice (metadata + 20 features
///   de preview) y escribe el JSON completo en
///   `~/Documents/geoportal_predios/archivos/{id}.json`.
class LocalArchivosRepository {
  static const _key = 'archivos_importados';
  static const _uuid = Uuid();

  // ── Helpers de archivos en disco (solo desktop) ──────────────────────────

  Future<File?> _featuresFile(String id) async {
    if (kIsWeb) return null;
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/geoportal_predios/archivos');
    if (!folder.existsSync()) folder.createSync(recursive: true);
    return File('${folder.path}/$id.json');
  }

  Future<void> _writeFeaturesFile(
      String id, List<Map<String, dynamic>> features) async {
    final file = await _featuresFile(id);
    if (file == null) return;
    await file.writeAsString(jsonEncode(features));
  }

  Future<List<Map<String, dynamic>>?> _readFeaturesFile(String id) async {
    final file = await _featuresFile(id);
    if (file == null || !file.existsSync()) return null;
    try {
      final raw = await file.readAsString();
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteFeaturesFile(String id) async {
    final file = await _featuresFile(id);
    if (file != null && file.existsSync()) await file.delete();
  }

  Future<void> _deleteAllFeaturesFiles() async {
    if (kIsWeb) return;
    final dir = await getApplicationDocumentsDirectory();
    final folder =
        Directory('${dir.path}/geoportal_predios/archivos');
    if (folder.existsSync()) await folder.delete(recursive: true);
  }

  // ── API pública ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getArchivos({
    bool withFullFeatures = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    List<Map<String, dynamic>> list;
    try {
      list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }

    if (!kIsWeb && withFullFeatures) {
      // En desktop, reemplazar features con el archivo completo si existe
      for (var entry in list) {
        final id = entry['id'] as String?;
        if (id == null) continue;
        final fullFeatures = await _readFeaturesFile(id);
        if (fullFeatures != null) {
          entry['features'] = fullFeatures;
          entry['features_count'] = fullFeatures.length;
        }
      }
    }

    return list;
  }

  Future<Map<String, dynamic>?> getArchivoById(
    String id, {
    bool withFullFeatures = true,
  }) async {
    final list = await getArchivos(withFullFeatures: withFullFeatures);
    final index = list.indexWhere((entry) => entry['id'] == id);
    if (index < 0) return null;
    return list[index];
  }

  Future<Map<String, dynamic>> saveArchivo({
    required String nombre,
    required List<Map<String, dynamic>> features,
    String? customId,
    int? rowCount,
    bool sincronizado = false,
    int encontrados = 0,
    int creados = 0,
    int errores = 0,
  }) async {
    final existing = await getArchivos(withFullFeatures: false);
    // getArchivos() en desktop ya enriqueció las entradas con features completos;
    // para guardar en prefs volvemos a usar el preview de cada una.
    final indexEntries = existing.map((e) {
      final preview = (e['features'] as List?)
              ?.cast<Map<String, dynamic>>()
              .take(20)
              .toList() ??
          [];
      return <String, dynamic>{...e, 'features': preview};
    }).toList();

    final now = DateTime.now().toIso8601String();
    final id = customId ?? _uuid.v4();

    // Guardar features completos en disco en desktop
    if (!kIsWeb) {
      await _writeFeaturesFile(id, features);
    }

    // En prefs siempre guardamos solo preview (máx 20)
    final storedFeatures =
        features.length > 20 ? features.sublist(0, 20) : features;
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
    indexEntries.insert(0, entry);
    await _saveIndex(indexEntries);

    // Devolver entry con features completos para uso inmediato
    return <String, dynamic>{...entry, 'features': features};
  }

  Future<Map<String, dynamic>?> updateArchivo({
    required String id,
    List<Map<String, dynamic>>? features,
    int? rowCount,
    bool? sincronizado,
    int? encontrados,
    int? creados,
    int? errores,
  }) async {
    final existing = await getArchivos(withFullFeatures: false);
    final index = existing.indexWhere((entry) => entry['id'] == id);
    if (index < 0) return null;

    final current = existing[index];
    final updatedFeatures = features ??
        ((current['features'] as List?)
                ?.cast<Map<String, dynamic>>()
                .toList(growable: false) ??
            const <Map<String, dynamic>>[]);

    if (!kIsWeb && features != null) {
      await _writeFeaturesFile(id, updatedFeatures);
    }

    final preview = updatedFeatures.length > 20
        ? updatedFeatures.sublist(0, 20)
        : updatedFeatures;
    final now = DateTime.now().toIso8601String();

    final updated = <String, dynamic>{
      ...current,
      'features_count': rowCount ?? current['features_count'] ?? updatedFeatures.length,
      'features': preview,
      'sincronizado': sincronizado ?? current['sincronizado'] ?? false,
      'encontrados': encontrados ?? current['encontrados'] ?? 0,
      'creados': creados ?? current['creados'] ?? 0,
      'errores': errores ?? current['errores'] ?? 0,
      'updated_at': now,
    };

    existing[index] = updated;
    final indexEntries = existing.map((e) {
      final previewFeatures = (e['features'] as List?)
              ?.cast<Map<String, dynamic>>()
              .take(20)
              .toList() ??
          [];
      return <String, dynamic>{...e, 'features': previewFeatures};
    }).toList();
    await _saveIndex(indexEntries);

    return <String, dynamic>{...updated, 'features': updatedFeatures};
  }

  Future<void> deleteArchivo(String id) async {
    final existing = await getArchivos(withFullFeatures: false);
    existing.removeWhere((e) => e['id'] == id);
    final indexEntries = existing.map((e) {
      final preview = (e['features'] as List?)
              ?.cast<Map<String, dynamic>>()
              .take(20)
              .toList() ??
          [];
      return <String, dynamic>{...e, 'features': preview};
    }).toList();
    await _saveIndex(indexEntries);
    await _deleteFeaturesFile(id);
  }

  Future<void> deleteAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await _deleteAllFeaturesFiles();
  }

  Future<void> _saveIndex(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list));
  }
}
