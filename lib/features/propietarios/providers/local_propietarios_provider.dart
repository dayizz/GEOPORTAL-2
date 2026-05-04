import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../predios/models/propietario.dart';

final localPropietariosProvider =
    StateNotifierProvider<LocalPropietariosNotifier, List<Propietario>>(
  (ref) => LocalPropietariosNotifier(),
);

class LocalPropietariosNotifier extends StateNotifier<List<Propietario>> {
  LocalPropietariosNotifier() : super(const []);

  int normalizeExistingData() {
    if (state.isEmpty) return 0;
    var changed = 0;
    final now = DateTime.now();

    final normalized = state.map((prop) {
      final data = _normalizeData({
        'nombre': prop.nombre,
        'apellidos': prop.apellidos,
        'tipo_persona': prop.tipoPersona,
        'razon_social': prop.razonSocial,
        'curp': prop.curp,
        'rfc': prop.rfc,
        'telefono': prop.telefono,
        'correo': prop.correo,
      });

      final next = prop.copyWith(
        nombre: data['nombre'] as String? ?? prop.nombre,
        apellidos: data['apellidos'] as String? ?? prop.apellidos,
        tipoPersona: data['tipo_persona'] as String? ?? prop.tipoPersona,
        razonSocial: data['razon_social'] as String?,
        curp: data['curp'] as String?,
        rfc: data['rfc'] as String?,
        telefono: data['telefono'] as String?,
        correo: data['correo'] as String?,
        updatedAt: now,
      );

      if (!_samePropietarioValues(prop, next)) {
        changed++;
      }
      return next;
    }).toList(growable: false);

    if (changed > 0) {
      state = normalized;
    }
    return changed;
  }

  Propietario upsertFromData(Map<String, dynamic> data) {
    final now = DateTime.now();
    final normalized = _normalizeData(data);
    final existingIndex = _findExistingIndex(normalized);

    if (existingIndex >= 0) {
      final existing = state[existingIndex];
      final updated = existing.copyWith(
        nombre: normalized['nombre'] as String? ?? existing.nombre,
        apellidos: normalized['apellidos'] as String? ?? existing.apellidos,
        tipoPersona: normalized['tipo_persona'] as String? ?? existing.tipoPersona,
        razonSocial: normalized['razon_social'] as String? ?? existing.razonSocial,
        curp: normalized['curp'] as String? ?? existing.curp,
        rfc: normalized['rfc'] as String? ?? existing.rfc,
        telefono: normalized['telefono'] as String? ?? existing.telefono,
        correo: normalized['correo'] as String? ?? existing.correo,
        updatedAt: now,
      );

      final updatedState = List<Propietario>.from(state);
      updatedState[existingIndex] = updated;
      state = updatedState;
      return updated;
    }

    final propietario = Propietario(
      id: 'local-prop-${now.microsecondsSinceEpoch}',
      nombre: normalized['nombre'] as String? ?? '',
      apellidos: normalized['apellidos'] as String? ?? '',
      tipoPersona: normalized['tipo_persona'] as String? ?? 'fisica',
      razonSocial: normalized['razon_social'] as String?,
      curp: normalized['curp'] as String?,
      rfc: normalized['rfc'] as String?,
      telefono: normalized['telefono'] as String?,
      correo: normalized['correo'] as String?,
      createdAt: now,
      updatedAt: now,
    );

    state = [propietario, ...state];
    return propietario;
  }

  int _findExistingIndex(Map<String, dynamic> data) {
    final rfc = (data['rfc'] as String?)?.trim().toLowerCase();
    if (rfc != null && rfc.isNotEmpty) {
      return state.indexWhere(
        (prop) => (prop.rfc ?? '').trim().toLowerCase() == rfc,
      );
    }

    final nombre = (data['nombre'] as String?)?.trim().toLowerCase() ?? '';
    final apellidos = (data['apellidos'] as String?)?.trim().toLowerCase() ?? '';
    final razonSocial =
        (data['razon_social'] as String?)?.trim().toLowerCase() ?? '';
    final tipoPersona =
        (data['tipo_persona'] as String?)?.trim().toLowerCase() ?? 'fisica';

    return state.indexWhere((prop) {
      if (tipoPersona == 'moral') {
        final razonActual = (prop.razonSocial ?? '').trim().toLowerCase();
        return razonSocial.isNotEmpty && razonActual == razonSocial;
      }

      return prop.nombre.trim().toLowerCase() == nombre &&
          prop.apellidos.trim().toLowerCase() == apellidos;
    });
  }

  Map<String, dynamic> _normalizeData(Map<String, dynamic> data) {
    final nombreCompleto =
        data['nombre_completo']?.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
    final razonSocial = data['razon_social']?.toString().trim();

    String nombre = data['nombre']?.toString().trim() ?? '';
    String apellidos = data['apellidos']?.toString().trim() ?? '';

    if (nombre.isEmpty && nombreCompleto != null && nombreCompleto.isNotEmpty) {
      final parts = nombreCompleto.split(' ');
      nombre = parts.first;
      apellidos = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }

    final tipoPersona = data['tipo_persona']?.toString().trim().toLowerCase() ??
        ((razonSocial != null && razonSocial.isNotEmpty) ? 'moral' : 'fisica');

    return {
      'nombre': _cleanText(nombre),
      'apellidos': _cleanText(apellidos),
      'tipo_persona': tipoPersona,
      'razon_social': _optionalText(razonSocial),
      'curp': _optionalUpperText(data['curp']),
      'rfc': _optionalUpperText(data['rfc']),
      'telefono': _optionalText(data['telefono']),
      'correo': _optionalLowerText(data['correo']),
    };
  }

  String _cleanText(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? _optionalText(dynamic value) {
    final text = value?.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  String? _optionalUpperText(dynamic value) {
    final text = _optionalText(value);
    return text?.toUpperCase();
  }

  String? _optionalLowerText(dynamic value) {
    final text = _optionalText(value);
    return text?.toLowerCase();
  }

  bool _samePropietarioValues(Propietario a, Propietario b) {
    return a.nombre == b.nombre &&
        a.apellidos == b.apellidos &&
        a.tipoPersona == b.tipoPersona &&
        a.razonSocial == b.razonSocial &&
        a.curp == b.curp &&
        a.rfc == b.rfc &&
        a.telefono == b.telefono &&
        a.correo == b.correo;
  }
}