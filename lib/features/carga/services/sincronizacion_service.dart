import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../predios/data/predios_repository.dart';
import '../../propietarios/data/propietarios_repository.dart';
import '../utils/geojson_mapper.dart';

/// Resultado del procesamiento de un único feature GeoJSON.
class FeatureSyncResult {
  /// Feature con properties enriquecidas (datos del sistema inyectados).
  final Map<String, dynamic> feature;

  /// Si es `true`, el predio ya existía en la BD y los datos fueron inyectados.
  final bool existia;

  /// ID del predio en la BD (nuevo o existente).
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
  /// Mensajes de error para diagnóstico (máx. 5).
  final List<String> mensajesError;

  const SincronizacionResultado({
    required this.resultados,
    required this.encontrados,
    required this.creados,
    required this.errores,
    this.mensajesError = const [],
  });

  List<Map<String, dynamic>> get features =>
      resultados.map((r) => r.feature).toList();
}

class _FeatureSyncOutcome {
  final int featureIndex;
  final FeatureSyncResult result;
  final int encontrados;
  final int creados;
  final int errores;
  final List<String> mensajesError;

  const _FeatureSyncOutcome({
    required this.featureIndex,
    required this.result,
    required this.encontrados,
    required this.creados,
    required this.errores,
    this.mensajesError = const [],
  });
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
  static const int _defaultSyncConcurrency = 50;
  static const int _maxSyncConcurrency = 100;
  static const int _maxRetryAttempts = 2;
  static const int _baseRetryDelayMs = 100;

  SincronizacionService(this._prediosRepo, this._propietariosRepo);

  /// Claves que se buscan en `properties` para identificar el predio.
  /// Incluye variantes en mayúsculas y minúsculas.
  static const _idKeys = [
    'clave_catastral', 'CLAVE_CATASTRAL',
    'id_catastral',    'ID_CATASTRAL',
    'clave',           'CLAVE',
    'folio',           'FOLIO',
    'id_sedatu',       'ID_SEDATU',
    'id_predio',       'ID_PREDIO',
    'cvegeo',          'CVEGEO',
    'id',              'ID',
    'fid',             'FID',
    'gid',             'GID',
    'objectid',        'OBJECTID',
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
    final syncAt = DateTime.now().toIso8601String();

    // Datos de gestión
    enriched['_predioId'] = predioMap['id'];
    enriched['predio_id'] = predioMap['id'];
    enriched['_claveCatastral'] = predioMap['clave_catastral'];
    enriched['clave_catastral_db'] = predioMap['clave_catastral'];
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
    enriched['_kmLineales'] = predioMap['km_lineales'];
    enriched['_kmEfectivos'] = predioMap['km_efectivos'];
    enriched['_proyecto'] = predioMap['proyecto'];
    enriched['_sincronizado'] = true;
    enriched['_syncStatus'] = 'linked';
    enriched['_syncSource'] = 'geojson_import';
    enriched['_syncAt'] = syncAt;

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

  /// Busca el primer valor no nulo/vacío de una lista de claves en [props].
  /// Solo ignora valores realmente vacíos o nulos.
  static final _invalidValues = {
    'null', 'nulo', 'undefined', 'none', '',
  };
  
  String? _pick(Map<String, dynamic> props, List<String> keys) {
    for (final k in keys) {
      final v = props[k]?.toString().trim();
      if (v != null && v.isNotEmpty && !_invalidValues.contains(v.toLowerCase())) {
        return v;
      }
    }
    return null;
  }

  String? _resolveProyecto(Map<String, dynamic> props) {
    final detectado = GeoJsonMapper.detectarProyecto(props);
    if (detectado != null) return detectado;

    final fromClave = GeoJsonMapper.inferProyectoDesdeClave(_extractId(props));
    if (fromClave != null) return fromClave;

    return _pick(props, [
      'proyecto',
      'PROYECTO',
      'nombre_proyecto',
      'NOMBRE_PROYECTO',
      'tramo_proyecto',
      'TRAMO_PROYECTO',
      'obra',
      'OBRA',
    ]);
  }

  String? _pickPropietarioFlexible(Map<String, dynamic> props) {
    final directo = _pick(props, [
      'propietario_nombre', 'PROPIETARIO_NOMBRE',
      'propietario', 'PROPIETARIO',
      'nombre_propietario', 'nom_propietario', 'NOM_PROPIETARIO',
      'titular', 'TITULAR',
      'razon_social', 'RAZON_SOCIAL',
      'dueno', 'dueño', 'owner',
    ]);
    if (directo != null) return directo;

    for (final entry in props.entries) {
      final key = _normalizeKey(entry.key);
      final keyLooksLikeOwner = key.contains('propiet') ||
          key.contains('titular') ||
          key.contains('dueno') ||
          key.contains('owner') ||
          key.contains('benefici') ||
          key.contains('razonsocial') ||
          key.contains('nombreprop') ||
          key.contains('nomprop');
      if (!keyLooksLikeOwner) continue;
      final v = entry.value?.toString().trim();
      if (v == null || v.isEmpty || v == 'null') continue;
      final looksLikeId = RegExp(r'^[A-Z0-9_\-]{6,}$').hasMatch(v);
      if (looksLikeId) continue;
      return v;
    }

    final nombre = _pick(props, ['nombre', 'NOMBRE']);
    if (nombre != null && !RegExp(r'^[A-Z0-9_\-]{6,}$').hasMatch(nombre)) {
      return nombre;
    }

    return null;
  }

  String _normalizeKey(String input) {
    var s = input.toLowerCase();
    const replacements = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'ñ': 'n',
    };
    replacements.forEach((k, v) => s = s.replaceAll(k, v));
    return s.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Future<T> _withRetry<T>(
    Future<T> Function() operation, {
    required String operationName,
  }) async {
    Object? lastError;

    for (var attempt = 1; attempt <= _maxRetryAttempts; attempt++) {
      try {
        return await operation();
      } catch (e) {
        lastError = e;
        final shouldRetry = attempt < _maxRetryAttempts && _isRetryableError(e);
        if (!shouldRetry) rethrow;
        await Future.delayed(_retryDelay(attempt));
      }
    }

    throw Exception('$operationName fallo tras $_maxRetryAttempts intentos: $lastError');
  }

  bool _isRetryableError(Object error) {
    final msg = error.toString().toLowerCase();
    const retryableHints = [
      'timeout', 'timed out', 'socket', 'network', 'connection',
      'failed to fetch', 'fetch failed', 'could not connect', 'connection refused',
      '429', '500', '502', '503', '504', 'sheets get fallo', 'sheets post fallo',
    ];
    return retryableHints.any(msg.contains);
  }

  Duration _retryDelay(int attempt) {
    final multiplier = 1 << (attempt - 1);
    final ms = _baseRetryDelayMs * multiplier;
    return Duration(milliseconds: ms);
  }

  /// Extrae todos los datos disponibles de las properties para crear/actualizar
  /// un predio en la BD, mapeando los alias más comunes de archivos GeoJSON.
  Map<String, dynamic> _buildNuevoPredioData(
    String claveCatastral,
    Map<String, dynamic> props,
    Map<String, dynamic>? geometry, {
    Map<String, dynamic>? propsOriginal,
  }) {
    // Extraer superficie con más aliases
    final superficie = _toDouble(
      props['superficie'] ?? props['SUPERFICIE'] ??
      props['area'] ?? props['AREA'] ?? props['shape_area'] ??
      props['SHAPE_AREA'] ?? props['area_ha'] ?? props['area_m2'] ??
      props['superficie_m2'] ?? props['m2'] ?? props['Area'] ??
      (propsOriginal != null ? propsOriginal['m2'] : null),
    ) ;

    // Extraer km_inicio con más aliases
    final kmInicio = _toDouble(
      props['km_inicio'] ?? props['KM_INICIO'] ??
      props['cadenamiento_inicial'] ?? props['cad_ini'] ?? props['km_i'] ??
      props['km_ini'] ?? props['km0'] ?? props['cadenamiento_i'] ??
      (propsOriginal != null ? propsOriginal['km_inicio'] : null) ??
      (propsOriginal != null ? propsOriginal['KM_INICIO'] : null),
    ) ;

    // Extraer km_fin con más aliases
    final kmFin = _toDouble(
      props['km_fin'] ?? props['KM_FIN'] ??
      props['cadenamiento_final'] ?? props['cad_fin'] ?? props['km_f'] ??
      props['km1'] ?? props['cadenamiento_f'] ?? props['cadenamiento_1'] ??
      (propsOriginal != null ? propsOriginal['km_fin'] : null) ??
      (propsOriginal != null ? propsOriginal['KM_FIN'] : null),
    ) ;

    final kmLineales = _toDouble(
      props['km_lineales'] ?? props['KM_LINEALES'] ??
      props['longitud_km'] ?? props['longitud'] ?? props['km'],
    ) ;

    // Extraer km_efectivos con más aliases
    final kmEfectivos = _toDouble(
      props['km_efectivos'] ?? props['KM_EFECTIVOS'] ??
      props['km_efectivo'] ?? props['km_e'] ??
      (propsOriginal != null ? propsOriginal['km_efectivos'] : null) ??
      (propsOriginal != null ? propsOriginal['KM_EFECTIVOS'] : null),
    ) ;

    final valorCatastral = _toDouble(
      props['valor_catastral'] ?? props['VALOR_CATASTRAL'] ??
      props['valor'] ?? props['VALOR'] ?? props['avaluo'] ?? props['AVALUO'],
    ) ;

    final data = <String, dynamic>{
      // ── Identificación ──────────────────────────────────────────────────
      'clave_catastral': claveCatastral,

      // ── Clasificación ───────────────────────────────────────────────────
      'tramo': _pick(props, [
        'tramo', 'TRAMO', 'tramo_vial', 'seccion',
        'frente', 'FRENTE', 'segmento', 'SEGMENTO',
        't_f_s', 'T_F_S', 'tipofs', 'TIPO_FS',
      ]) ?? 'T1',
      'tipo_propiedad': _normalizeTipoPropiedad(_pick(props, [
        'tipo_propiedad', 'tipopropiedad', 'TIPO_PROPIEDAD',
        'tipo', 'TIPO', 'regimen', 'REGIMEN',
      ])),
      'ejido': _pick(props, [
        'ejido', 'nom_ejido', 'nombre_ejido', 'NOM_EJIDO', 'EJIDO',
        'comunidad', 'localidad',
      ]),
      'proyecto': _resolveProyecto(props),
      'uso_suelo': _pick(props, [
        'uso_suelo', 'USO_SUELO', 'uso', 'USO', 'land_use', 'LAND_USE',
      ]) ?? 'Otro',
      'zona': _pick(props, ['zona', 'ZONA', 'sector', 'SECTOR', 'region', 'REGION']),
      'valor_catastral': valorCatastral,
      'descripcion': _pick(props, [
        'descripcion', 'DESCRIPCION', 'description', 'DESCRIPTION',
      ]),
      'direccion': _pick(props, ['direccion', 'DIRECCION', 'domicilio', 'DOMICILIO', 'calle', 'CALLE']),
      'colonia': _pick(props, ['colonia', 'COLONIA', 'barrio', 'BARRIO']),
      'municipio': _pick(props, [
        'municipio', 'MUNICIPIO', 'mun', 'MUN',
        'localidad', 'LOCALIDAD', 'ciudad', 'CIUDAD',
      ]),
      'estado': _pick(props, [
        'estado', 'ESTADO', 'entidad', 'ENTIDAD',
        'state', 'STATE', 'nombre_entidad', 'NOMBRE_ENTIDAD',
      ]),
      'codigo_postal': _pick(props, ['codigo_postal', 'CODIGO_POSTAL', 'cp', 'CP']),
      'imagen_url': _pick(props, ['imagen_url', 'IMAGEN_URL', 'foto_url', 'FOTO_URL', 'image_url', 'IMAGE_URL']),

      // ── Propietario (nombre directo) ─────────────────────────────────────
      'propietario_nombre': _pick(props, [
        'propietario', 'propietario_nombre', 'nombre_propietario',
        'nom_propietario', 'PROPIETARIO', 'titular', 'TITULAR',
        'dueno', 'dueño', 'nombre',
      ]) ?? _pickPropietarioFlexible(props),

      // ── Dimensiones / Geometría ──────────────────────────────────────────
      'superficie': superficie,
      'km_inicio': kmInicio,
      'km_fin': kmFin,
      'km_lineales': kmLineales,
      'km_efectivos': kmEfectivos,

      // ── Coordenadas ──────────────────────────────────────────────────────
      'latitud': _toDouble(
        props['latitud'] ?? props['lat'] ?? props['LAT'] ?? props['latitude'],
      ),
      'longitud': _toDouble(
        props['longitud'] ?? props['lon'] ?? props['lng'] ?? props['LON'] ??
        props['longitude'],
      ),

      // ── Geometría ────────────────────────────────────────────────────────
      'geometry': geometry,
      'poligono_insertado': geometry != null,

      // ── Gestión (estado inicial) ─────────────────────────────────────────
      // Convierte valores booleanos o strings a boolean
      'cop': _toBool(props['cop']),
      'identificacion': _toBool(props['identificacion']),
      'levantamiento': _toBool(props['levantamiento']),
      'negociacion': _toBool(props['negociacion']),

      // ── Tipo de Liberación ───────────────────────────────────────────────
      'tipo_liberacion': _pick(props, [
        'tipo_liberacion', 'TIPO_LIBERACION',
        'tipo_de_liberacion', 'TIPO_DE_LIBERACION',
        'liberacion', 'LIBERACION',
        'tipo_release', 'TIPO_RELEASE',
        'tipo', 'TIPO',
      ]),
    };

    // Eliminar claves con valor null para no pisar datos existentes
    data.removeWhere((k, v) => v == null);
    
    // Incluir TODAS las propiedades originales del GeoJSON que no estén ya en data
    if (propsOriginal != null) {
      for (final entry in propsOriginal.entries) {
        final key = entry.key;
        if (!data.containsKey(key) && entry.value != null) {
          final valueStr = entry.value.toString().trim();
          if (valueStr.isNotEmpty && valueStr.toLowerCase() != 'null') {
            data[key] = entry.value;
          }
        }
      }
    }
    return data;
  }

  /// Extrae datos del propietario desde las properties del feature.
  Map<String, dynamic> _buildPropietarioData(Map<String, dynamic> props) {
    final nombreCompleto = _pick(props, [
      'propietario', 'propietario_nombre', 'nombre_propietario',
      'nom_propietario', 'PROPIETARIO', 'titular', 'nombre',
    ]) ?? '';

    final parts = nombreCompleto.trim().split(' ');
    final nombre = parts.isNotEmpty ? parts.first : '';
    final apellidos = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final razonSocial = _pick(props, [
      'razon_social', 'RAZON_SOCIAL', 'empresa', 'denominacion', 'EMPRESA',
    ]);

    final tipoPersona = (razonSocial != null ||
            nombreCompleto.contains('S.A.') ||
            nombreCompleto.contains('S.DE R.L.') ||
            nombreCompleto.contains('SAPI') ||
            nombreCompleto.contains('SAS'))
        ? 'moral'
        : 'fisica';

    final data = <String, dynamic>{
      'nombre': nombre,
      'apellidos': apellidos,
      'tipo_persona': tipoPersona,
      if (razonSocial != null) 'razon_social': razonSocial,
      if (_pick(props, ['rfc', 'RFC']) != null)
        'rfc': _pick(props, ['rfc', 'RFC']),
      if (_pick(props, ['curp', 'CURP']) != null)
        'curp': _pick(props, ['curp', 'CURP']),
      if (_pick(props, ['telefono', 'tel', 'TEL', 'phone', 'TELEFONO']) != null)
        'telefono': _pick(props, ['telefono', 'tel', 'TEL', 'phone', 'TELEFONO']),
      if (_pick(props, ['correo', 'email', 'EMAIL', 'correo_electronico']) != null)
        'correo': _pick(props, ['correo', 'email', 'EMAIL', 'correo_electronico']),
    };

    return data;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '').trim());
    return null;
  }

  /// Convierte valores a boolean para campos de gestión
  bool _toBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final upper = v.toUpperCase().trim();
      if (upper == 'SI' || upper == 'YES' || upper == 'S' || upper == 'Y' || 
          upper == 'TRUE' || upper == '1' || upper == 'X' ||
          upper == 'COMPLETADO' || upper == 'COMPLETE' || 
          upper == 'LIBERADO' || upper == 'LIBERADA' ||
          upper == 'IDENTIFICADO' || upper == 'LEVANTADO' || upper == 'NEGOCIADO') {
        return true;
      }
      if (upper == 'NO' || upper == 'FALSE' || upper == '0' || upper == '-' || upper.isEmpty) {
        return false;
      }
    }
    return false;
  }

  /// Normaliza el valor de tipo_propiedad a los valores válidos del sistema
  String? _normalizeTipoPropiedad(String? value) {
    if (value == null) return 'PRIVADA';
    final upper = value.toUpperCase().trim();
    if (upper.contains('SOC')) return 'SOCIAL';
    if (upper.contains('PRI')) return 'PRIVADA';
    if (upper.contains('DOMINIO') || upper.contains('PLENO')) return 'DOMINIO PLENO';
    return upper.isEmpty ? 'PRIVADA' : upper;
  }

  /// Construye los campos de Gestión para ACTUALIZAR un predio existente.
  Map<String, dynamic> _buildGestionUpdateData(
    Map<String, dynamic> props,
    Map<String, dynamic>? geometry,
    Map<String, dynamic> existente,
  ) {
    final updates = <String, dynamic>{};

    void trySet(String dbKey, dynamic newValue) {
      if (newValue == null) return;
      final cur = existente[dbKey];
      if (cur == null || (cur is String && cur.trim().isEmpty)) {
        updates[dbKey] = newValue;
      }
    }

    trySet('tramo',      _pick(props, ['tramo', 'TRAMO', 'tramo_vial', 'seccion', 'SECCION']));
    trySet('tipo_propiedad', _normalizeTipoPropiedad(_pick(props, ['tipo_propiedad', 'TIPO_PROPIEDAD', 'tipo', 'TIPO', 'regimen', 'REGIMEN'])));
    trySet('ejido',      _pick(props, ['ejido', 'EJIDO', 'nom_ejido', 'NOM_EJIDO', 'comunidad', 'localidad']));
    trySet('proyecto',   _resolveProyecto(props));
    trySet('propietario_nombre', _pick(props, [
      'propietario', 'PROPIETARIO', 'propietario_nombre', 'nombre_propietario',
      'nom_propietario', 'NOM_PROPIETARIO', 'titular', 'TITULAR', 'dueno', 'nombre',
    ]) ?? _pickPropietarioFlexible(props));
    trySet('superficie',    _toDouble(props['superficie']    ?? props['SUPERFICIE']    ?? props['area'] ?? props['AREA'] ?? props['shape_area'] ?? props['SHAPE_AREA'] ?? props['superficie_m2'] ?? props['m2'] ?? props['Area']));
    trySet('uso_suelo',     _pick(props, ['uso_suelo', 'USO_SUELO', 'uso', 'USO', 'land_use', 'LAND_USE']) ?? 'Otro');
    trySet('zona',          _pick(props, ['zona', 'ZONA', 'sector', 'SECTOR', 'region', 'REGION']));
    trySet('valor_catastral', _toDouble(props['valor_catastral'] ?? props['VALOR_CATASTRAL'] ?? props['valor'] ?? props['VALOR'] ?? props['avaluo'] ?? props['AVALUO']));
    trySet('descripcion',   _pick(props, ['descripcion', 'DESCRIPCION', 'description', 'DESCRIPTION']));
    trySet('direccion',     _pick(props, ['direccion', 'DIRECCION', 'domicilio', 'DOMICILIO', 'calle', 'CALLE']));
    trySet('colonia',       _pick(props, ['colonia', 'COLONIA', 'barrio', 'BARRIO']));
    trySet('municipio',     _pick(props, ['municipio', 'MUNICIPIO', 'mun', 'MUN', 'localidad', 'ciudad']));
    trySet('estado',        _pick(props, ['estado', 'ESTADO', 'entidad', 'ENTIDAD', 'state', 'nombre_entidad']));
    trySet('codigo_postal', _pick(props, ['codigo_postal', 'CODIGO_POSTAL', 'cp', 'CP']));
    trySet('km_inicio',     _toDouble(props['km_inicio']     ?? props['KM_INICIO']     ?? props['cadenamiento_inicial'] ?? props['cad_ini'] ?? props['km_i'] ?? props['km_ini'] ?? props['km0'] ?? props['cadenamiento_i']));
    trySet('km_fin',        _toDouble(props['km_fin']        ?? props['KM_FIN']        ?? props['cadenamiento_final']   ?? props['cad_fin'] ?? props['km_f'] ?? props['km1'] ?? props['cadenamiento_f'] ?? props['cadenamiento_1']));
    trySet('km_lineales',   _toDouble(props['km_lineales']   ?? props['KM_LINEALES']   ?? props['longitud_km'] ?? props['longitud'] ?? props['km']));
    trySet('km_efectivos',  _toDouble(props['km_efectivos']  ?? props['KM_EFECTIVOS']  ?? props['km_efectivo'] ?? props['km_e']));

    // Campos booleanos de gestión
    trySet('identificacion', _toBool(props['identificacion']));
    trySet('levantamiento',   _toBool(props['levantamiento']));
    trySet('negociacion',    _toBool(props['negociacion']));
    trySet('cop',            _toBool(props['cop']));

    // Tipo de liberación
    trySet('tipo_liberacion', _pick(props, [
      'tipo_liberacion', 'TIPO_LIBERACION',
      'tipo_de_liberacion', 'TIPO_DE_LIBERACION',
      'liberacion', 'LIBERACION',
      'tipo_release', 'TIPO_RELEASE',
      'tipo', 'TIPO',
    ]));

    if (geometry != null && existente['geometry'] == null) {
      updates['geometry']           = geometry;
      updates['poligono_insertado'] = true;
    }
    return updates;
  }

  /// Procesa todos los features del archivo GeoJSON de forma asíncrona.
  Future<SincronizacionResultado> sincronizar(
    List<Map<String, dynamic>> features, {
    int concurrency = _defaultSyncConcurrency,
    void Function(int procesados, int total)? onProgress,
  }) async {
    if (features.isEmpty) {
      return const SincronizacionResultado(
        resultados: [],
        encontrados: 0,
        creados: 0,
        errores: 0,
      );
    }

    final resultadosByIndex = <int, FeatureSyncResult>{};
    final mensajesError = <String>[];
    final predioByClaveCache = <String, Map<String, dynamic>?>{};
    var encontrados = 0;
    var creados = 0;
    var errores = 0;
    var procesados = 0;

    onProgress?.call(0, features.length);

    final lanes = _buildLanes(features, concurrency);
    await Future.wait(
      lanes.map(
        (lane) => _processLane(
          lane,
          predioByClaveCache: predioByClaveCache,
          onOutcome: (outcome) {
            resultadosByIndex[outcome.featureIndex] = outcome.result;
            encontrados += outcome.encontrados;
            creados += outcome.creados;
            errores += outcome.errores;
            procesados += 1;
            onProgress?.call(procesados, features.length);

            for (final msg in outcome.mensajesError) {
              if (mensajesError.length >= 5) break;
              mensajesError.add(msg);
            }
          },
        ),
      ),
    );

    onProgress?.call(features.length, features.length);

    final resultados = <FeatureSyncResult>[];
    for (var i = 0; i < features.length; i++) {
      final item = resultadosByIndex[i];
      if (item != null) {
        resultados.add(item);
      }
    }

    return SincronizacionResultado(
      resultados: resultados,
      encontrados: encontrados,
      creados: creados,
      errores: errores,
      mensajesError: mensajesError,
    );
  }

  List<List<MapEntry<int, Map<String, dynamic>>>> _buildLanes(
    List<Map<String, dynamic>> features,
    int requestedConcurrency,
  ) {
    final safeConcurrency = requestedConcurrency.clamp(1, _maxSyncConcurrency);
    final laneCount = safeConcurrency > features.length
        ? features.length
        : safeConcurrency;

    final lanes = List.generate(
      laneCount,
      (_) => <MapEntry<int, Map<String, dynamic>>>[],
    );

    for (var i = 0; i < features.length; i++) {
      final feature = features[i];
      final lane = _laneForFeature(feature, i, laneCount);
      lanes[lane].add(MapEntry(i, feature));
    }

    return lanes;
  }

  int _laneForFeature(
    Map<String, dynamic> feature,
    int fallbackIndex,
    int laneCount,
  ) {
    final rawProps = feature['properties'];
    final propsOriginal = rawProps is Map
        ? Map<String, dynamic>.from(rawProps)
        : <String, dynamic>{};
    final props = GeoJsonMapper.normalizeProperties(propsOriginal);
    final clave = _extractId(props)?.trim();

    if (clave != null && clave.isNotEmpty) {
      return clave.hashCode.abs() % laneCount;
    }

    return fallbackIndex % laneCount;
  }

  Future<void> _processLane(
    List<MapEntry<int, Map<String, dynamic>>> lane, {
    required Map<String, Map<String, dynamic>?> predioByClaveCache,
    required void Function(_FeatureSyncOutcome outcome) onOutcome,
  }) async {
    for (final item in lane) {
      final outcome = await _processFeature(
        item.key,
        item.value,
        predioByClaveCache: predioByClaveCache,
      );
      onOutcome(outcome);
    }
  }

  Future<_FeatureSyncOutcome> _processFeature(
    int featureIndex,
    Map<String, dynamic> feature, {
    required Map<String, Map<String, dynamic>?> predioByClaveCache,
  }) async {
    final featureNumber = featureIndex + 1;

    try {
      final rawProps = feature['properties'];
      final propsOriginal = rawProps is Map
          ? Map<String, dynamic>.from(rawProps)
          : <String, dynamic>{};
      final props = GeoJsonMapper.normalizeProperties(propsOriginal);
      final geometry = feature['geometry'] is Map
          ? Map<String, dynamic>.from(feature['geometry'] as Map)
          : null;
      final clave = _extractId(props);

      // Siempre intentar procesar el feature, sin importar si tiene clave o no
      String? claveNormalizada;
      Map<String, dynamic>? existente;

      if (clave != null && clave.trim().isNotEmpty) {
        claveNormalizada = clave.trim();
        
        if (predioByClaveCache.containsKey(claveNormalizada)) {
          existente = predioByClaveCache[claveNormalizada];
        } else {
          try {
            existente = await _withRetry(
              () => _prediosRepo.buscarPorClaveCatastral(claveNormalizada!),
              operationName: 'buscarPorClaveCatastral',
            );
          } catch (_) {
            // Si falla la búsqueda, continuar como si no existiera
            existente = null;
          }
          predioByClaveCache[claveNormalizada!] = existente;
        }

        // Si existe, actualizar
        if (existente != null) {
          var existenteActual = existente;
          final updateData = _buildGestionUpdateData(
            props,
            geometry,
            existenteActual,
          );

          if (updateData.isNotEmpty) {
            try {
              final updated = await _withRetry(
                () => _prediosRepo.updatePredio(
                  existenteActual['id'] as String,
                  updateData,
                ),
                operationName: 'updatePredio',
              );
              final propietariosRaw = existenteActual['propietarios'];
              existenteActual = updated.toMap()
                ..['id'] = updated.id
                ..['propietarios'] = propietariosRaw;
              predioByClaveCache[claveNormalizada!] = existenteActual;
            } catch (_) {
              // Si falla el update, continuar con los datos existentes.
            }
          }

          final enrichedProps = _injectData(props, existenteActual);
          return _FeatureSyncOutcome(
            featureIndex: featureIndex,
            result: FeatureSyncResult(
              feature: {
                ...feature,
                'properties': enrichedProps,
              },
              existia: true,
              predioId: existenteActual['id'] as String?,
            ),
            encontrados: 1,
            creados: 0,
            errores: 0,
          );
        }
      }

      // Si no hay clave o no existe, crear nuevo registro
      final nuevaClave = claveNormalizada ?? 'IMP-${DateTime.now().microsecondsSinceEpoch}-$featureNumber';
      final predioData = _buildNuevoPredioData(nuevaClave, props, geometry, propsOriginal: propsOriginal);

      final nombreProp = predioData['propietario_nombre'] as String?;
      if (nombreProp != null && nombreProp.isNotEmpty) {
        try {
          final propData = _buildPropietarioData(props);
          final propietario = await _withRetry(
            () => _propietariosRepo.findOrCreateFromData(propData),
            operationName: 'findOrCreatePropietario',
          );
          predioData['propietario_id'] = propietario.id;
        } catch (_) {
          // No bloquear la creación del predio si el propietario falla.
        }
      }

      final nuevoPredio = await _withRetry(
        () => _prediosRepo.createPredio(predioData),
        operationName: 'createPredio',
      );

      final nuevoMap = nuevoPredio.toMap()
        ..['id'] = nuevoPredio.id
        ..['created_at'] = nuevoPredio.createdAt.toIso8601String();
      predioByClaveCache[nuevaClave.trim()] = nuevoMap;

      final enrichedProps = _injectData(props, nuevoMap);
      enrichedProps['_predioNuevo'] = true;

      return _FeatureSyncOutcome(
        featureIndex: featureIndex,
        result: FeatureSyncResult(
          feature: {
            ...feature,
            'properties': enrichedProps,
          },
          existia: false,
          predioId: nuevoPredio.id,
        ),
        encontrados: 0,
        creados: 1,
        errores: 0,
      );
    } catch (e) {
      final featureError = 'Feature $featureNumber: ${e.toString()}';

      try {
        final rawProps = feature['properties'];
        final propsOriginal = rawProps is Map
            ? Map<String, dynamic>.from(rawProps)
            : <String, dynamic>{};
        final props = GeoJsonMapper.normalizeProperties(propsOriginal);
        final geometry = feature['geometry'] is Map
            ? Map<String, dynamic>.from(feature['geometry'] as Map)
            : null;
        final clave = _extractId(props) ??
            'IMP-${DateTime.now().microsecondsSinceEpoch}-$featureNumber';

        final minData = <String, dynamic>{
          'clave_catastral': clave,
          'tramo': 'T1',
          'tipo_propiedad': 'PRIVADA',
          if (_resolveProyecto(props) != null) 'proyecto': _resolveProyecto(props),
          if (geometry != null) 'geometry': geometry,
          if (geometry != null) 'poligono_insertado': true,
          'cop': false,
          'identificacion': false,
          'levantamiento': false,
          'negociacion': false,
        };

        final nuevoPredio = await _withRetry(
          () => _prediosRepo.createPredio(minData),
          operationName: 'createPredioMinimo',
        );

        final nuevoMap = nuevoPredio.toMap()
          ..['id'] = nuevoPredio.id
          ..['created_at'] = nuevoPredio.createdAt.toIso8601String();
        predioByClaveCache[clave.trim()] = nuevoMap;

        final enrichedProps = _injectData(props, nuevoMap);
        enrichedProps['_predioNuevo'] = true;

        return _FeatureSyncOutcome(
          featureIndex: featureIndex,
          result: FeatureSyncResult(
            feature: {
              ...feature,
              'properties': enrichedProps,
            },
            existia: false,
            predioId: nuevoPredio.id,
          ),
          encontrados: 0,
          creados: 1,
          errores: 0,
          mensajesError: [featureError],
        );
      } catch (e2) {
        final minError = 'Feature $featureNumber (min): ${e2.toString()}';
        final rawProps = feature['properties'];
        final propsConError = rawProps is Map
            ? Map<String, dynamic>.from(rawProps)
            : <String, dynamic>{};
        propsConError['_syncStatus'] = 'error';
        propsConError['_syncSource'] = 'geojson_import';
        propsConError['_syncAt'] = DateTime.now().toIso8601String();
        propsConError['_syncError'] = e2.toString();

        return _FeatureSyncOutcome(
          featureIndex: featureIndex,
          result: FeatureSyncResult(
            feature: {
              ...feature,
              'properties': propsConError,
            },
            existia: false,
          ),
          encontrados: 0,
          creados: 0,
          errores: 1,
          mensajesError: [featureError, minError],
        );
      }
    }
  }
}

final sincronizacionServiceProvider = Provider<SincronizacionService>((ref) {
  return SincronizacionService(
    ref.read(prediosRepositoryProvider),
    ref.read(propietariosRepositoryProvider),
  );
});
