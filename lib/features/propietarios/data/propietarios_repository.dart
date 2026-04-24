import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../predios/models/propietario.dart';

final propietariosRepositoryProvider = Provider<PropietariosRepository>(
  (ref) => PropietariosRepository(Supabase.instance.client),
);

class PropietariosRepository {
  final SupabaseClient _client;

  PropietariosRepository(this._client);

  Future<List<Propietario>> getPropietarios({
    String? busqueda,
    String? tipoPersona,
    int limit = 100,
  }) async {
    var query = _client.from('propietarios').select();

    if (busqueda != null && busqueda.isNotEmpty) {
      query = query.or(
        'nombre.ilike.%$busqueda%,apellidos.ilike.%$busqueda%,rfc.ilike.%$busqueda%,curp.ilike.%$busqueda%,razon_social.ilike.%$busqueda%',
      );
    }

    if (tipoPersona != null && tipoPersona.isNotEmpty) {
      query = query.eq('tipo_persona', tipoPersona);
    }

    final response = await query
        .order('nombre', ascending: true)
        .limit(limit);

    return (response as List).map((e) => Propietario.fromMap(e)).toList();
  }

  Future<Propietario?> getPropietarioById(String id) async {
    final response = await _client
        .from('propietarios')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Propietario.fromMap(response);
  }

  Future<Propietario> createPropietario(Map<String, dynamic> data) async {
    final response = await _client
        .from('propietarios')
        .insert(data)
        .select()
        .single();

    return Propietario.fromMap(response);
  }

  Future<Propietario> findOrCreateByNombreCompleto(String nombreCompleto) async {
    final normalized = nombreCompleto.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      throw ArgumentError('nombreCompleto no puede estar vacio');
    }

    final parts = normalized.split(' ');
    final nombre = parts.first;
    final apellidos = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final existing = await _client
        .from('propietarios')
        .select()
        .ilike('nombre', nombre)
        .ilike('apellidos', apellidos)
        .limit(1)
        .maybeSingle();

    if (existing != null) {
      return Propietario.fromMap(existing);
    }

    final tipoPersona = normalized.contains('S.A.') ||
            normalized.contains('S. DE R.L.') ||
            normalized.contains('SAPI') ||
            normalized.contains('SAS')
        ? 'moral'
        : 'fisica';

    return createPropietario({
      'nombre': nombre,
      'apellidos': apellidos,
      'tipo_persona': tipoPersona,
      if (tipoPersona == 'moral') 'razon_social': normalized,
    });
  }

  Future<Propietario> updatePropietario(String id, Map<String, dynamic> data) async {
    final response = await _client
        .from('propietarios')
        .update({...data, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .select()
        .single();

    return Propietario.fromMap(response);
  }

  Future<void> deletePropietario(String id) async {
    await _client.from('propietarios').delete().eq('id', id);
  }
}
