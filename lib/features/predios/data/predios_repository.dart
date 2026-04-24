import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/predio.dart';

final prediosRepositoryProvider = Provider<PrediosRepository>(
  (ref) => PrediosRepository(Supabase.instance.client),
);

class PrediosRepository {
  final SupabaseClient _client;

  PrediosRepository(this._client);

  Future<List<Predio>> getPredios({
    String? busqueda,
    String? usoSuelo,
    String? zona,
    String? propietarioId,
    int limit = 50,
    int offset = 0,
  }) async {
    var query = _client
        .from('predios')
        .select('*, propietarios(*)');

    if (busqueda != null && busqueda.isNotEmpty) {
      query = query.or(
        'clave_catastral.ilike.%$busqueda%,direccion.ilike.%$busqueda%,colonia.ilike.%$busqueda%',
      );
    }

    if (usoSuelo != null && usoSuelo.isNotEmpty) {
      query = query.eq('uso_suelo', usoSuelo);
    }

    if (zona != null && zona.isNotEmpty) {
      query = query.eq('zona', zona);
    }

    if (propietarioId != null && propietarioId.isNotEmpty) {
      query = query.eq('propietario_id', propietarioId);
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List).map((e) => Predio.fromMap(e)).toList();
  }

  Future<Predio?> getPredioById(String id) async {
    final response = await _client
        .from('predios')
        .select('*, propietarios(*)')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Predio.fromMap(response);
  }

  Future<Predio> createPredio(Map<String, dynamic> data) async {
    final response = await _client
        .from('predios')
        .insert(data)
        .select('*, propietarios(*)')
        .single();

    return Predio.fromMap(response);
  }

  Future<Predio> updatePredio(String id, Map<String, dynamic> data) async {
    final response = await _client
        .from('predios')
        .update({...data, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .select('*, propietarios(*)')
        .single();

    return Predio.fromMap(response);
  }

  Future<void> deletePredio(String id) async {
    await _client.from('predios').delete().eq('id', id);
  }

  Future<List<Predio>> getPrediosConGeometria() async {
    final response = await _client
        .from('predios')
        .select('*, propietarios(*)')
        .not('geometry', 'is', null);

    return (response as List).map((e) => Predio.fromMap(e)).toList();
  }

  Future<Map<String, dynamic>> getEstadisticas() async {
    final total = await _client.from('predios').select('id');
    final porUso = await _client
        .from('predios')
        .select('uso_suelo')
        .order('uso_suelo');

    final Map<String, int> conteoUso = {};
    for (final item in porUso as List) {
      final uso = item['uso_suelo'] as String;
      conteoUso[uso] = (conteoUso[uso] ?? 0) + 1;
    }

    double superficieTotal = 0;
    final superficies = await _client
        .from('predios')
        .select('superficie')
        .not('superficie', 'is', null);

    for (final item in superficies as List) {
      superficieTotal += (item['superficie'] as num).toDouble();
    }

    return {
      'total': (total as List).length,
      'por_uso_suelo': conteoUso,
      'superficie_total': superficieTotal,
    };
  }

  Future<String> uploadArchivo(String filePath, Uint8List bytes, String extension) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage.from('predios-archivos').uploadBinary(
          'uploads/$fileName',
          bytes,
        );
    return fileName;
  }
}
