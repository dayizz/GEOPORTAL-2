import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/google_sheets/google_sheets_service.dart';
import '../../predios/models/propietario.dart';

final propietariosRepositoryProvider = Provider<PropietariosRepository>(
  (ref) {
    return PropietariosRepository(Supabase.instance.client);
  },
);

class PropietariosRepository {
  final SupabaseClient _client;
  final GoogleSheetsService? _sheets;

  PropietariosRepository(this._client, {GoogleSheetsService? sheets})
      : _sheets = sheets;

  static const _uuid = Uuid();

  bool get _usingSheets => _sheets != null;

  String _toIso(dynamic value, {required DateTime fallback}) {
    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) return parsed.toIso8601String();
    }
    return fallback.toIso8601String();
  }

  Map<String, dynamic> _normalizePropietarioMap(Map<String, dynamic> raw) {
    final now = DateTime.now();
    return {
      'id': (raw['id']?.toString().trim().isNotEmpty ?? false)
          ? raw['id'].toString().trim()
          : _uuid.v4(),
      'nombre': raw['nombre']?.toString() ?? '',
      'apellidos': raw['apellidos']?.toString() ?? '',
      'tipo_persona': raw['tipo_persona']?.toString() ?? 'fisica',
      'razon_social': raw['razon_social']?.toString(),
      'curp': raw['curp']?.toString(),
      'rfc': raw['rfc']?.toString(),
      'telefono': raw['telefono']?.toString(),
      'correo': raw['correo']?.toString(),
      'created_at': _toIso(raw['created_at'], fallback: now),
      'updated_at': raw['updated_at'] == null
          ? null
          : _toIso(raw['updated_at'], fallback: now),
    };
  }

  Future<List<Propietario>> getPropietarios({
    String? busqueda,
    String? tipoPersona,
    int limit = 100,
  }) async {
    if (_usingSheets) {
      var propietarios = (await _sheets!.getRows(sheet: 'propietarios'))
          .map((e) => Propietario.fromMap(_normalizePropietarioMap(e)))
          .toList();

      if (busqueda != null && busqueda.trim().isNotEmpty) {
        final q = busqueda.trim().toLowerCase();
        propietarios = propietarios.where((p) {
          return p.nombre.toLowerCase().contains(q) ||
              p.apellidos.toLowerCase().contains(q) ||
              (p.rfc?.toLowerCase().contains(q) ?? false) ||
              (p.curp?.toLowerCase().contains(q) ?? false) ||
              (p.razonSocial?.toLowerCase().contains(q) ?? false);
        }).toList();
      }

      if (tipoPersona != null && tipoPersona.isNotEmpty) {
        propietarios = propietarios.where((p) => p.tipoPersona == tipoPersona).toList();
      }

      propietarios.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      if (propietarios.length > limit) {
        return propietarios.sublist(0, limit);
      }
      return propietarios;
    }

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
    if (_usingSheets) {
      final rows = await _sheets!.getRows(sheet: 'propietarios');
      for (final row in rows) {
        if (row['id']?.toString() == id) {
          return Propietario.fromMap(_normalizePropietarioMap(row));
        }
      }
      return null;
    }

    final response = await _client
        .from('propietarios')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Propietario.fromMap(response);
  }

  Future<Propietario> createPropietario(Map<String, dynamic> data) async {
    if (_usingSheets) {
      final now = DateTime.now().toIso8601String();
      final row = {
        ...data,
        'id': data['id']?.toString() ?? _uuid.v4(),
        'created_at': data['created_at']?.toString() ?? now,
        'updated_at': now,
      };
      final saved = await _sheets!.upsertRow(
        sheet: 'propietarios',
        row: row,
        idField: 'id',
      );
      return Propietario.fromMap(_normalizePropietarioMap(saved));
    }

    final response = await _client
        .from('propietarios')
        .insert(data)
        .select()
        .single();

    return Propietario.fromMap(response);
  }

  Future<Propietario> findOrCreateByNombreCompleto(String nombreCompleto) async {
    return findOrCreateFromData({'nombre_completo': nombreCompleto});
  }

  /// Busca o crea un propietario usando todos los datos disponibles del mapa [data].
  /// Acepta claves: nombre, apellidos, nombre_completo, rfc, curp,
  /// telefono, correo, razon_social, tipo_persona.
  Future<Propietario> findOrCreateFromData(Map<String, dynamic> data) async {
    // Resolver nombre y apellidos
    String nombre;
    String apellidos;

    if (data['nombre'] != null && data['nombre'].toString().isNotEmpty) {
      nombre = data['nombre'].toString().trim();
      apellidos = data['apellidos']?.toString().trim() ?? '';
    } else {
      final full = (data['nombre_completo'] ?? '').toString().trim()
          .replaceAll(RegExp(r'\s+'), ' ');
      if (full.isEmpty) throw ArgumentError('Se requiere nombre del propietario');
      final parts = full.split(' ');
      nombre = parts.first;
      apellidos = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }

    // Buscar por RFC primero (más preciso), luego por nombre
    Map<String, dynamic>? existing;
    final rfc = data['rfc']?.toString().trim();
    if (_usingSheets) {
      final rows = await _sheets!.getRows(sheet: 'propietarios');
      if (rfc != null && rfc.isNotEmpty) {
        for (final row in rows) {
          if ((row['rfc']?.toString().toLowerCase().trim() ?? '') ==
              rfc.toLowerCase()) {
            existing = _normalizePropietarioMap(row);
            break;
          }
        }
      }

      if (existing == null) {
        for (final row in rows) {
          final nombreRow = row['nombre']?.toString().toLowerCase().trim() ?? '';
          final apellidosRow = row['apellidos']?.toString().toLowerCase().trim() ?? '';
          if (nombreRow == nombre.toLowerCase() &&
              apellidosRow == apellidos.toLowerCase()) {
            existing = _normalizePropietarioMap(row);
            break;
          }
        }
      }
    } else {
      if (rfc != null && rfc.isNotEmpty) {
        existing = await _client
            .from('propietarios')
            .select()
            .ilike('rfc', rfc)
            .limit(1)
            .maybeSingle();
      }

      if (existing == null) {
        var query = _client
            .from('propietarios')
            .select()
            .ilike('nombre', nombre);

        if (apellidos.isNotEmpty) {
          query = query.ilike('apellidos', apellidos);
        }

        existing = await query.limit(1).maybeSingle();
      }
    }

    if (existing != null) {
      // Actualizar con nuevos datos si los tenemos
      final updates = <String, dynamic>{};
      if (rfc != null && existing['rfc'] == null) updates['rfc'] = rfc;
      final curp = data['curp']?.toString().trim();
      if (curp != null && curp.isNotEmpty && existing['curp'] == null) updates['curp'] = curp;
      final tel = data['telefono']?.toString().trim();
      if (tel != null && tel.isNotEmpty && existing['telefono'] == null) updates['telefono'] = tel;
      final correo = data['correo']?.toString().trim();
      if (correo != null && correo.isNotEmpty && existing['correo'] == null) updates['correo'] = correo;

      if (updates.isNotEmpty) {
        updates['updated_at'] = DateTime.now().toIso8601String();
        if (_usingSheets) {
          await _sheets!.upsertRow(
            sheet: 'propietarios',
            row: {...existing, ...updates, 'id': existing['id']},
            idField: 'id',
          );
        } else {
          await _client.from('propietarios').update(updates).eq('id', existing['id']);
        }
        existing = {...existing, ...updates};
      }

      return Propietario.fromMap(existing);
    }

    // Construir datos del nuevo propietario
    final razonSocial = data['razon_social']?.toString().trim();
    final nombreCompleto = '$nombre $apellidos'.trim();
    final tipoPersona = data['tipo_persona']?.toString() ??
        (razonSocial != null ||
                nombreCompleto.contains('S.A.') ||
                nombreCompleto.contains('S.DE R.L.') ||
                nombreCompleto.contains('SAPI') ||
                nombreCompleto.contains('SAS')
            ? 'moral'
            : 'fisica');

    final insertData = <String, dynamic>{
      'nombre': nombre,
      'apellidos': apellidos,
      'tipo_persona': tipoPersona,
      if (razonSocial != null && razonSocial.isNotEmpty) 'razon_social': razonSocial,
      if (rfc != null && rfc.isNotEmpty) 'rfc': rfc,
      if (data['curp']?.toString().trim().isNotEmpty == true) 'curp': data['curp'].toString().trim(),
      if (data['telefono']?.toString().trim().isNotEmpty == true) 'telefono': data['telefono'].toString().trim(),
      if (data['correo']?.toString().trim().isNotEmpty == true) 'correo': data['correo'].toString().trim(),
    };

    return createPropietario(insertData);
  }

  Future<Propietario> updatePropietario(String id, Map<String, dynamic> data) async {
    if (_usingSheets) {
      final existente = await getPropietarioById(id);
      final row = {
        ...existente?.toMap() ?? <String, dynamic>{},
        ...data,
        'id': id,
        'created_at': existente?.createdAt.toIso8601String() ?? DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      final saved = await _sheets!.upsertRow(
        sheet: 'propietarios',
        row: row,
        idField: 'id',
      );
      return Propietario.fromMap(_normalizePropietarioMap(saved));
    }

    final response = await _client
        .from('propietarios')
        .update({...data, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .select()
        .single();

    return Propietario.fromMap(response);
  }

  Future<void> deletePropietario(String id) async {
    if (_usingSheets) {
      await _sheets!.deleteById(sheet: 'propietarios', id: id, idField: 'id');
      return;
    }
    await _client.from('propietarios').delete().eq('id', id);
  }
}
