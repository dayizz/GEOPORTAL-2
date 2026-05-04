import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../predios/data/predios_repository.dart';
import '../../predios/models/propietario.dart';
import '../../propietarios/data/propietarios_repository.dart';

final importacionRepositoryProvider = Provider<ImportacionRepository>((ref) {
  return ImportacionRepository(
    prediosRepository: ref.read(prediosRepositoryProvider),
    propietariosRepository: ref.read(propietariosRepositoryProvider),
  );
});

class ImportacionUpsertResult {
  final bool creado;
  final bool actualizado;

  const ImportacionUpsertResult({
    required this.creado,
    required this.actualizado,
  });
}

class ImportacionRepository {
  final PrediosRepository _prediosRepository;
  final PropietariosRepository _propietariosRepository;

  const ImportacionRepository({
    required PrediosRepository prediosRepository,
    required PropietariosRepository propietariosRepository,
  })  : _prediosRepository = prediosRepository,
        _propietariosRepository = propietariosRepository;

  Future<ImportacionUpsertResult> upsertPredioConPropietario(
    Map<String, dynamic> row,
  ) async {
    final clave = row['clave_catastral']?.toString().trim() ?? '';
    if (clave.isEmpty) {
      throw ArgumentError('Fila sin clave_catastral.');
    }

    final payload = Map<String, dynamic>.from(row)
      ..remove('rfc_propietario')
      ..remove('curp_propietario')
      ..remove('telefono_propietario')
      ..remove('correo_propietario');

    final propietarioData = _buildPropietarioData(row);
    if (propietarioData.isNotEmpty) {
      final propietario = await _propietariosRepository.findOrCreateFromData(
        propietarioData,
      );
      payload['propietario_id'] = propietario.id;
      payload['propietario_nombre'] = propietario.nombreCompleto;
    }

    final existente = await _prediosRepository.buscarPorClaveCatastral(clave);
    if (existente != null) {
      await _prediosRepository.updatePredio(
        existente['id'].toString(),
        payload,
      );
      return const ImportacionUpsertResult(creado: false, actualizado: true);
    }

    await _prediosRepository.createPredio(payload);
    return const ImportacionUpsertResult(creado: true, actualizado: false);
  }

  Future<ImportacionUpsertResult> upsertPropietario(
    Map<String, dynamic> row,
  ) async {
    final existedBefore = await _propietarioExiste(row);
    await _propietariosRepository.findOrCreateFromData(row);
    return ImportacionUpsertResult(
      creado: !existedBefore,
      actualizado: existedBefore,
    );
  }

  Map<String, dynamic> _buildPropietarioData(Map<String, dynamic> row) {
    final out = <String, dynamic>{};

    final nombre = row['propietario_nombre']?.toString().trim();
    if (nombre != null && nombre.isNotEmpty) {
      out['nombre_completo'] = _normalizePlainText(nombre);
    }

    final rfc = row['rfc_propietario']?.toString().trim();
    if (rfc != null && rfc.isNotEmpty) {
      out['rfc'] = _normalizeUpperCode(rfc);
    }

    final curp = row['curp_propietario']?.toString().trim();
    if (curp != null && curp.isNotEmpty) {
      out['curp'] = _normalizeUpperCode(curp);
    }

    final telefono = row['telefono_propietario']?.toString().trim();
    if (telefono != null && telefono.isNotEmpty) {
      out['telefono'] = _normalizePlainText(telefono);
    }

    final correo = row['correo_propietario']?.toString().trim();
    if (correo != null && correo.isNotEmpty) {
      out['correo'] = _normalizeEmail(correo);
    }

    return out;
  }

  Future<bool> _propietarioExiste(Map<String, dynamic> row) async {
    final rfc = row['rfc']?.toString().trim();
    final nombre = row['nombre']?.toString().trim();
    final apellidos = row['apellidos']?.toString().trim();
    final nombreCompleto = row['nombre_completo']?.toString().trim();

    final seed = rfc?.isNotEmpty == true
        ? rfc!
        : (nombreCompleto?.isNotEmpty == true ? nombreCompleto! : nombre ?? '');
    if (seed.isEmpty) return false;

    final candidatos = await _propietariosRepository.getPropietarios(
      busqueda: seed,
      limit: 50,
    );

    for (final Propietario candidato in candidatos) {
      if (rfc != null && rfc.isNotEmpty) {
        if ((candidato.rfc ?? '').toLowerCase().trim() == rfc.toLowerCase()) {
          return true;
        }
      }

      final compNombre = '$nombre $apellidos'.trim().toLowerCase();
      if (compNombre.isNotEmpty &&
          candidato.nombreCompleto.trim().toLowerCase() == compNombre) {
        return true;
      }

      if (nombreCompleto != null && nombreCompleto.isNotEmpty) {
        if (candidato.nombreCompleto.trim().toLowerCase() ==
            nombreCompleto.toLowerCase()) {
          return true;
        }
      }
    }

    return false;
  }

  String _normalizePlainText(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _normalizeUpperCode(String value) {
    return _normalizePlainText(value).toUpperCase();
  }

  String _normalizeEmail(String value) {
    return _normalizePlainText(value).toLowerCase();
  }
}
