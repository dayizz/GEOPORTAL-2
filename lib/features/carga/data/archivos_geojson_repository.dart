import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final archivosGeoJsonRepositoryProvider = Provider<ArchivosGeoJsonRepository>(
  (ref) => ArchivosGeoJsonRepository(Supabase.instance.client),
);

class ArchivosGeoJsonRepository {
  final SupabaseClient _client;

  ArchivosGeoJsonRepository(this._client);

  /// Obtiene todos los archivos guardados, ordenados del más reciente al más antiguo.
  Future<List<Map<String, dynamic>>> getArchivos() async {
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
    await _client.from('archivos_geojson').delete().eq('id', id);
  }
}
