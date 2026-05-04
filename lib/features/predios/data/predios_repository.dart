import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/api/api_client.dart';
import 'package:uuid/uuid.dart';

import '../../../core/google_sheets/google_sheets_service.dart';
import '../models/predio.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final prediosRepositoryProvider = Provider<PrediosRepository>(
  (ref) {
    // Para migración: usar ApiClient en vez de Supabase
    final api = ref.watch(apiClientProvider);
    return PrediosRepository(Supabase.instance.client, apiClient: api);
  },
);


class PrediosRepository {

  bool get _usingSheets => _sheets != null;

    double? _toDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value.replaceAll(',', '').trim());
        return parsed;
      }
      return null;
    }

    bool _toBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final v = value.trim().toLowerCase();
        return v == 'true' || v == '1' || v == 'si' || v == 'sí' || v == 'yes';
      }
      return false;
    }

    String _toIso(dynamic value, {required DateTime fallback}) {
      if (value is String && value.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(value.trim());
        if (parsed != null) return parsed.toIso8601String();
      }
      return fallback.toIso8601String();
    }
  final SupabaseClient _client;
  final GoogleSheetsService? _sheets;
  final ApiClient? _apiClient;
  static const _uuid = Uuid();

  PrediosRepository(this._client, {GoogleSheetsService? sheets, ApiClient? apiClient})
      : _sheets = sheets,
        _apiClient = apiClient;

  Map<String, dynamic> _normalizePredioMap(
    Map<String, dynamic> raw, {
    Map<String, dynamic>? propietario,
  }) {
    final now = DateTime.now();
    final geometryRaw = raw['geometry'];
    return {
      'id': (raw['id']?.toString().trim().isNotEmpty ?? false)
          ? raw['id'].toString().trim()
          : _uuid.v4(),
      'clave_catastral': raw['clave_catastral']?.toString().trim() ??
          raw['id_sedatu']?.toString().trim() ??
          '',
      'propietario_nombre': raw['propietario_nombre']?.toString(),
      'tramo': raw['tramo']?.toString() ?? 'T1',
      'tipo_propiedad': raw['tipo_propiedad']?.toString() ?? 'PRIVADA',
      'ejido': raw['ejido']?.toString(),
      'km_inicio': _toDouble(raw['km_inicio']),
      'km_fin': _toDouble(raw['km_fin']),
      'km_lineales': _toDouble(raw['km_lineales']),
      'km_efectivos': _toDouble(raw['km_efectivos']),
      'superficie': _toDouble(raw['superficie']) ?? 0,
      'cop': _toBool(raw['cop']),
      'cop_firmado': raw['cop_firmado']?.toString(),
      'poligono_dwg': raw['poligono_dwg']?.toString(),
      'oficio': raw['oficio']?.toString(),
      'proyecto': raw['proyecto']?.toString(),
      'poligono_insertado': _toBool(raw['poligono_insertado']),
      'identificacion': _toBool(raw['identificacion']),
      'levantamiento': _toBool(raw['levantamiento']),
      'negociacion': _toBool(raw['negociacion']),
      'latitud': _toDouble(raw['latitud']),
      'longitud': _toDouble(raw['longitud']),
      'geometry': geometryRaw,
      'propietario_id': raw['propietario_id']?.toString(),
      'created_at': _toIso(raw['created_at'], fallback: now),
      'updated_at': raw['updated_at'] == null
          ? null
          : _toIso(raw['updated_at'], fallback: now),
      'uso_suelo': raw['uso_suelo']?.toString() ?? 'Otro',
      'zona': raw['zona']?.toString(),
      'valor_catastral': _toDouble(raw['valor_catastral']) ?? 0,
      'descripcion': raw['descripcion']?.toString(),
      'direccion': raw['direccion']?.toString(),
      'colonia': raw['colonia']?.toString(),
      'municipio': raw['municipio']?.toString(),
      'estado': raw['estado']?.toString(),
      'codigo_postal': raw['codigo_postal']?.toString(),
      'imagen_url': raw['imagen_url']?.toString(),
      if (propietario != null) 'propietarios': propietario,
    };
  }

  Future<Map<String, Map<String, dynamic>>> _propietariosPorId() async {
    if (!_usingSheets) return const {};
    final rows = await _sheets!.getRows(sheet: 'propietarios');
    final out = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final id = row['id']?.toString();
      if (id == null || id.isEmpty) continue;
      out[id] = {
        'id': id,
        'nombre': row['nombre']?.toString() ?? '',
        'apellidos': row['apellidos']?.toString() ?? '',
        'tipo_persona': row['tipo_persona']?.toString() ?? 'fisica',
        'razon_social': row['razon_social']?.toString(),
        'curp': row['curp']?.toString(),
        'rfc': row['rfc']?.toString(),
        'telefono': row['telefono']?.toString(),
        'correo': row['correo']?.toString(),
        'created_at': _toIso(row['created_at'], fallback: DateTime.now()),
        'updated_at': row['updated_at'] == null
            ? null
            : _toIso(row['updated_at'], fallback: DateTime.now()),
      };
    }
    return out;
  }

  Future<List<Predio>> getPredios({
    String? busqueda,
    String? usoSuelo,
    String? zona,
    String? propietarioId,
    int limit = 50,
    int offset = 0,
  }) async {
    // Si hay ApiClient, usar backend FastAPI
    if (_apiClient != null) {
      final data = await _apiClient!.getPredios();
      return data.map((e) => Predio.fromMap(e as Map<String, dynamic>)).toList();
    }
    // ...existing code...
    if (_usingSheets) {
      final rows = await _sheets!.getRows(sheet: 'predios');
      final propietarios = await _propietariosPorId();

      var predios = rows.map((row) {
        final propietarioId = row['propietario_id']?.toString();
        final propietario = propietarioId != null ? propietarios[propietarioId] : null;
        return Predio.fromMap(_normalizePredioMap(row, propietario: propietario));
      }).toList();

      if (busqueda != null && busqueda.trim().isNotEmpty) {
        final q = busqueda.trim().toLowerCase();
        predios = predios.where((p) {
          return p.claveCatastral.toLowerCase().contains(q) ||
              (p.direccion.toLowerCase().contains(q));
        }).toList();
      }

      return predios;
    }

    final response = await _client
        .from('predios')
        .select('*, propietarios(*)')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List).map((e) => Predio.fromMap(e)).toList();
  }



  Future<Predio?> getPredioById(String id) async {
    // Si hay ApiClient, usar backend FastAPI
    if (_apiClient != null) {
      try {
        final data = await _apiClient!.getPredio(id);
        return Predio.fromMap(data);
      } catch (_) {
        return null;
      }
    }
    if (_usingSheets) {
      final rows = await _sheets!.getRows(sheet: 'predios');
      final row = rows.where((r) => r['id']?.toString() == id).firstOrNull;
      if (row == null) return null;

      Map<String, dynamic>? propietario;
      final propId = row['propietario_id']?.toString();
      if (propId != null && propId.isNotEmpty) {
        final propietarios = await _propietariosPorId();
        propietario = propietarios[propId];
      }

      return Predio.fromMap(_normalizePredioMap(row, propietario: propietario));
    }

    final response = await _client
        .from('predios')
        .select('*, propietarios(*)')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Predio.fromMap(response);
  }

  /// Busca un predio por clave catastral. Devuelve el mapa crudo (con join de
  /// propietarios) para que el motor de sincronización pueda inyectar los datos
  /// directamente en las properties del feature GeoJSON.
  Future<Map<String, dynamic>?> buscarPorClaveCatastral(String clave) async {
    if (_apiClient != null) {
      return _apiClient!.getPredioByClaveCatastral(clave);
    }
    if (_usingSheets) {
      final rows = await _sheets!.getRows(sheet: 'predios');
      final row = rows.where((r) {
        final c = r['clave_catastral']?.toString().trim() ?? '';
        return c == clave.trim();
      }).firstOrNull;

      if (row == null) return null;

      final propId = row['propietario_id']?.toString();
      Map<String, dynamic>? propietario;
      if (propId != null && propId.isNotEmpty) {
        final propietarios = await _propietariosPorId();
        propietario = propietarios[propId];
      }

      return _normalizePredioMap(row, propietario: propietario);
    }

    final response = await _client
        .from('predios')
        .select('*, propietarios(*)')
        .eq('clave_catastral', clave)
        .maybeSingle();

    return response != null ? Map<String, dynamic>.from(response) : null;
  }

  Future<Predio> createPredio(Map<String, dynamic> data) async {
    if (_apiClient != null) {
      final saved = await _apiClient!.createPredio(data);
      return Predio.fromMap(saved);
    }
    if (_usingSheets) {
      final now = DateTime.now().toIso8601String();
      final row = {
        ...data,
        'id': data['id']?.toString() ?? _uuid.v4(),
        'created_at': data['created_at']?.toString() ?? now,
        'updated_at': now,
      };

      final saved = await _sheets!.upsertRow(
        sheet: 'predios',
        row: row,
        idField: 'id',
      );

      final normalized = _normalizePredioMap(saved);
      return Predio.fromMap(normalized);
    }

    final response = await _client
        .from('predios')
        .insert(data)
        .select('*, propietarios(*)')
        .single();

    return Predio.fromMap(response);
  }

  Future<Predio> updatePredio(String id, Map<String, dynamic> data) async {
    if (_apiClient != null) {
      final saved = await _apiClient!.updatePredio(id, data);
      return Predio.fromMap(saved);
    }
    if (_usingSheets) {
      final existente = await getPredioById(id);
      final row = {
        ...existente?.toMap() ?? <String, dynamic>{},
        ...data,
        'id': id,
        'created_at': existente?.createdAt.toIso8601String() ?? DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final saved = await _sheets!.upsertRow(
        sheet: 'predios',
        row: row,
        idField: 'id',
      );

      final normalized = _normalizePredioMap(saved);
      return Predio.fromMap(normalized);
    }

    final response = await _client
        .from('predios')
        .update({...data, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .select('*, propietarios(*)')
        .single();

    return Predio.fromMap(response);
  }

  Future<void> deletePredio(String id) async {
    if (_apiClient != null) {
      await _apiClient!.deletePredio(id);
      return;
    }
    if (_usingSheets) {
      await _sheets!.deleteById(sheet: 'predios', id: id, idField: 'id');
      return;
    }
    await _client.from('predios').delete().eq('id', id);
  }

  Future<List<Predio>> getPrediosConGeometria() async {
    if (_apiClient != null) {
      final all = await getPredios(limit: 100000);
      return all.where((p) => p.geometry != null).toList();
    }
    if (_usingSheets) {
      final all = await getPredios(limit: 100000);
      return all.where((p) => p.geometry != null).toList();
    }

    final response = await _client
        .from('predios')
        .select('*, propietarios(*)')
        .not('geometry', 'is', null);

    return (response as List).map((e) => Predio.fromMap(e)).toList();
  }

  Future<Map<String, dynamic>> getEstadisticas() async {
    if (_apiClient != null) {
      return _apiClient!.getEstadisticas();
    }
    if (_usingSheets) {
      final predios = await getPredios(limit: 100000);
      final conteoUso = <String, int>{};
      var superficieTotal = 0.0;

      for (final p in predios) {
        conteoUso[p.usoSuelo] = (conteoUso[p.usoSuelo] ?? 0) + 1;
        superficieTotal += p.superficie ?? 0;
      }

      return {
        'total': predios.length,
        'por_uso_suelo': conteoUso,
        'superficie_total': superficieTotal,
      };
    }

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

  /// Vincula un poligono huérfano con un registro de Gestión.
  ///
  /// En Supabase actualiza el predio con la geometría del polígono y marca
  /// `poligono_insertado=true`. Si la columna `id_poligono` existe, también
  /// la actualiza; si no existe, hace fallback sin esa columna.
  Future<Predio> vincularPoligonoConPredio({
    required String idPoligono,
    required String idGestion,
    required Map<String, dynamic> geometry,
  }) async {
    final payload = <String, dynamic>{
      'geometry': geometry,
      'id_poligono': idPoligono,
      'poligono_insertado': true,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (_apiClient != null) {
      final saved = await _apiClient!.updatePredio(idGestion, payload);
      return Predio.fromMap(saved);
    }

    if (_usingSheets) {
      final existente = await getPredioById(idGestion);
      final row = {
        ...existente?.toMap() ?? <String, dynamic>{},
        ...payload,
        'id': idGestion,
        'id_poligono': idPoligono,
        'created_at': existente?.createdAt.toIso8601String() ?? DateTime.now().toIso8601String(),
      };

      final saved = await _sheets!.upsertRow(
        sheet: 'predios',
        row: row,
        idField: 'id',
      );

      final normalized = _normalizePredioMap(saved);
      return Predio.fromMap(normalized);
    }

    try {
      final rpcResponse = await _client.rpc(
        'api_predios_vincular',
        params: {
          'p_id_poligono': idPoligono,
          'p_id_gestion': idGestion,
          'p_geometry': geometry,
        },
      );

      if (rpcResponse is List && rpcResponse.isNotEmpty) {
        final raw = Map<String, dynamic>.from(rpcResponse.first as Map);
        final hydrated = await _client
            .from('predios')
            .select('*, propietarios(*)')
            .eq('id', raw['id'])
            .single();
        return Predio.fromMap(hydrated);
      }

      final response = await _client
          .from('predios')
          .update({...payload, 'id_poligono': idPoligono})
          .eq('id', idGestion)
          .select('*, propietarios(*)')
          .single();
      return Predio.fromMap(response);
    } on PostgrestException {
      final response = await _client
          .from('predios')
          .update(payload)
          .eq('id', idGestion)
          .select('*, propietarios(*)')
          .single();
      return Predio.fromMap(response);
    }
  }

  Future<String> uploadArchivo(String filePath, Uint8List bytes, String extension) async {
    if (_usingSheets) {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
      return fileName;
    }

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage.from('predios-archivos').uploadBinary(
          'uploads/$fileName',
          bytes,
        );
    return fileName;
  }
}
