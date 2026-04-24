import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../predios/data/predios_repository.dart';
import '../../propietarios/data/propietarios_repository.dart';

/// Resultado del procesamiento de un único feature GeoJSON.
class FeatureSyncResult {
  /// Feature con properties enriquecidas (datos del sistema inyectados).
  final Map<String, dynamic> feature;

  /// Si es `true`, el predio ya existía en la BD y los datos fueron inyectados.
  final bool existia;

  /// ID del predio en la BD (nuevo o existente). `null` en modo demo.
  final String? predioId;

  const FeatureSyncResult({
    required this.feature,
    required this.existia,
    this.predioId,
  });
}

/// Resultado global de la sincronización de un archivo GeoJSON.
class SincronizacionResultado {
  final List<FeatureSyncResult> resultados;
  final int encontrados;
  final int creados;
  final int errores;

  const SincronizacionResultado({
    required this.resultados,
    required this.encontrados,
    required this.creados,
    required this.errores,
  });

  List<Map<String, dynamic>> get features =>
      resultados.map((r) => r.feature).toList();
}

/// Motor de sincronización GeoJSON ↔ Base de datos.
///
/// Para cada feature:
/// 1. Extrae el identificador único del campo `clave_catastral` (o aliases).
/// 2. Consulta la tabla `predios`.
/// 3. Si existe → inyecta datos de gestión y propietario en `properties`.
/// 4. Si no existe → crea el registro en `predios` (y opcionalmente en `propietarios`).
class SincronizacionService {
  final PrediosRepository _prediosRepo;
  final PropietariosRepository _propietariosRepo;

  SincronizacionService(this._prediosRepo, this._propietariosRepo);

  /// Claves que se buscan en `properties` para identificar el predio.
  static const _idKeys = [
    'clave_catastral',
    'id_catastral',
    'clave',
    'folio',
    'id_sedatu',
    'id_predio',
    'cvegeo',
    'id',
    'fid',
    'gid',
  ];

  /// Extrae la clave catastral de las properties del feature.
  String? _extractId(Map<String, dynamic> props) {
    for (final key in _idKeys) {
      final value = props[key];
      if (value != null) {
        final str = value.toString().trim();
        if (str.isNotEmpty) return str;
      }
    }
    return null;
  }

  /// Combina properties del feature con datos del sistema.
  Map<String, dynamic> _injectData(
    Map<String, dynamic> props,
    Map<String, dynamic> predioMap,
  ) {
    final enriched = Map<String, dynamic>.from(props);

    // Datos de gestión
    enriched['_predioId'] = predioMap['id'];
    enriched['_claveCatastral'] = predioMap['clave_catastral'];
    enriched['_tramo'] = predioMap['tramo'];
    enriched['_tipoPropiedad'] = predioMap['tipo_propiedad'];
    enriched['_cop'] = predioMap['cop'];
    enriched['_superficie'] = predioMap['superficie'];
    enriched['_identificacion'] = predioMap['identificacion'];
    enriched['_levantamiento'] = predioMap['levantamiento'];
    enriched['_negociacion'] = predioMap['negociacion'];
    enriched['_poligonoInsertado'] = predioMap['poligono_insertado'];
    enriched['_ejido'] = predioMap['ejido'];
    enriched['_kmInicio'] = predioMap['km_inicio'];
    enriched['_kmFin'] = predioMap['km_fin'];
    enriched['_proyecto'] = predioMap['proyecto'];
    enriched['_sincronizado'] = true;

    // Datos del propietario (si están en el join)
    final propietarioRaw = predioMap['propietarios'];
    if (propietarioRaw is Map) {
      final propMap = Map<String, dynamic>.from(propietarioRaw);
      enriched['_propietarioNombre'] = [
        propMap['nombre'],
        propMap['apellidos'],
      ].where((v) => v != null && v.toString().isNotEmpty).join(' ');
      enriched['_propietarioRfc'] = propMap['rfc'];
    } else {
      enriched['_propietarioNombre'] = predioMap['propietario_nombre'];
    }

    return enriched;
  }

  /// Construye el mapa de datos mínimos para crear un predio nuevo.
  Map<String, dynamic> _buildNuevoPredioData(
    String claveCatastral,
    Map<String, dynamic> props,
    Map<String, dynamic>? geometry,
  ) {
    return {
      'clave_catastral': claveCatastral,
      'tramo': props['tramo']?.toString() ?? 'T1',
      'tipo_propiedad': props['tipo_propiedad']?.toString() ??
          props['tipopropiedad']?.toString() ??
          'PRIVADA',
      'ejido': props['ejido']?.toString(),
      'propietario_nombre': props['propietario']?.toString() ??
          props['propietario_nombre']?.toString() ??
          props['nombre_propietario']?.toString(),
      'superficie': _toDouble(props['superficie'] ?? props['area']),
      'geometry': geometry,
      'poligono_insertado': geometry != null,
      'cop': false,
      'identificacion': false,
      'levantamiento': false,
      'negociacion': false,
    };
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '').trim());
    return null;
  }

  /// Procesa todos los features del archivo GeoJSON de forma asíncrona.
  ///
  /// [features]: Lista de features crudos del GeoJSON.
  /// [isDemo]: Si es `true`, salta las operaciones de BD y marca todo como nuevo.
  Future<SincronizacionResultado> sincronizar(
    List<Map<String, dynamic>> features, {
    bool isDemo = false,
  }) async {
    final resultados = <FeatureSyncResult>[];
    int encontrados = 0;
    int creados = 0;
    int errores = 0;

    for (final feature in features) {
      try {
        final rawProps = feature['properties'];
        final props = rawProps is Map
            ? Map<String, dynamic>.from(rawProps)
            : <String, dynamic>{};
        final geometry = feature['geometry'] is Map
            ? Map<String, dynamic>.from(feature['geometry'] as Map)
            : null;

        if (isDemo) {
          // En modo demo no hay BD: marcar como "predio nuevo" sin crear nada.
          final enriched = Map<String, dynamic>.from(props);
          enriched['_sincronizado'] = false;
          enriched['_predioNuevo'] = true;
          resultados.add(FeatureSyncResult(
            feature: {
              ...feature,
              'properties': enriched,
            },
            existia: false,
          ));
          creados++;
          continue;
        }

        final clave = _extractId(props);

        if (clave != null) {
          // Buscar en la BD por clave catastral
          final existente = await _prediosRepo.buscarPorClaveCatastral(clave);

          if (existente != null) {
            // ── COINCIDENCIA: inyectar datos del sistema ──────────────────
            final enrichedProps = _injectData(props, existente);
            resultados.add(FeatureSyncResult(
              feature: {
                ...feature,
                'properties': enrichedProps,
              },
              existia: true,
              predioId: existente['id'] as String?,
            ));
            encontrados++;
            continue;
          }
        }

        // ── NO ENCONTRADO: crear predio nuevo ──────────────────────────
        final nuevaClave = clave ?? 'IMP-${DateTime.now().millisecondsSinceEpoch}';
        final predioData = _buildNuevoPredioData(nuevaClave, props, geometry);

        // Si hay nombre de propietario, crear/buscar registro en propietarios
        final nombreProp = predioData['propietario_nombre'] as String?;
        if (nombreProp != null && nombreProp.isNotEmpty) {
          try {
            final propietario = await _propietariosRepo
                .findOrCreateByNombreCompleto(nombreProp);
            predioData['propietario_id'] = propietario.id;
          } catch (_) {
            // No bloquear la creación del predio si el propietario falla
          }
        }

        final nuevoPredio = await _prediosRepo.createPredio(predioData);

        final enrichedProps = Map<String, dynamic>.from(props);
        enrichedProps['_predioId'] = nuevoPredio.id;
        enrichedProps['_claveCatastral'] = nuevoPredio.claveCatastral;
        enrichedProps['_predioNuevo'] = true;
        enrichedProps['_sincronizado'] = true;

        resultados.add(FeatureSyncResult(
          feature: {
            ...feature,
            'properties': enrichedProps,
          },
          existia: false,
          predioId: nuevoPredio.id,
        ));
        creados++;
      } catch (e) {
        // Agregar el feature sin enriquecer para no perderlo
        resultados.add(FeatureSyncResult(
          feature: feature,
          existia: false,
        ));
        errores++;
      }
    }

    return SincronizacionResultado(
      resultados: resultados,
      encontrados: encontrados,
      creados: creados,
      errores: errores,
    );
  }
}

final sincronizacionServiceProvider = Provider<SincronizacionService>((ref) {
  return SincronizacionService(
    ref.read(prediosRepositoryProvider),
    ref.read(propietariosRepositoryProvider),
  );
});
