/// Normaliza las claves de un objeto `properties` de GeoJSON
/// para que coincidan exactamente con las columnas del esquema de Supabase.
///
/// Uso:
/// ```dart
/// final normalized = GeoJsonMapper.normalizeProperties(feature['properties']);
/// ```
class GeoJsonMapper {
  GeoJsonMapper._();

  /// Mapa de alias: columna_supabase → [alias1, alias2, ...]
  static const _keyAliases = <String, List<String>>{
    'clave_catastral': [
      'clave_catastral', 'CLAVE_CATASTRAL',
      'id_catastral',    'ID_CATASTRAL',
      'id_sedatu',       'ID_SEDATU',
      'clave',           'CLAVE',
      'folio',           'FOLIO',
      'id_predio',       'ID_PREDIO',
      'cvegeo',          'CVEGEO',
      'objectid',        'OBJECTID',
      'fid',             'FID',
      'gid',             'GID',
      'id',              'ID',
    ],
    'proyecto': [
      'proyecto', 'PROYECTO',
      'nombre_proyecto', 'NOMBRE_PROYECTO',
      'tramo_proyecto',  'obra', 'OBRA',
    ],
    'tramo': [
      'tramo', 'TRAMO',
      'tramo_vial', 'TRAMO_VIAL',
      'seccion', 'SECCION',
    ],
    'tipo_propiedad': [
      'tipo_propiedad', 'TIPO_PROPIEDAD',
      'tipopropiedad',  'tipo', 'TIPO',
      'regimen',        'REGIMEN',
    ],
    'ejido': [
      'ejido', 'EJIDO',
      'nom_ejido', 'NOM_EJIDO',
      'nombre_ejido', 'comunidad', 'localidad',
    ],
    'propietario_nombre': [
      'propietario', 'PROPIETARIO',
      'propietario_nombre', 'nombre_propietario',
      'nom_propietario', 'NOM_PROPIETARIO',
      'titular', 'TITULAR',
      'nombre',
    ],
    'superficie': [
      'superficie', 'SUPERFICIE',
      'area', 'AREA',
      'shape_area', 'SHAPE_AREA',
      'area_m2', 'area_ha',
    ],
    'uso_suelo': [
      'uso_suelo', 'USO_SUELO',
      'uso', 'USO',
      'land_use', 'LAND_USE',
      'clasificacion', 'CLASIFICACION',
    ],
    'zona': [
      'zona', 'ZONA',
      'sector', 'SECTOR',
      'region', 'REGION',
    ],
    'valor_catastral': [
      'valor_catastral', 'VALOR_CATASTRAL',
      'valor', 'VALOR',
      'avaluo', 'AVALUO',
      'valor_terreno', 'VALOR_TERRENO',
    ],
    'descripcion': [
      'descripcion', 'DESCRIPCION',
      'description', 'DESCRIPTION',
      'observaciones', 'OBSERVACIONES',
    ],
    'direccion': [
      'direccion', 'DIRECCION',
      'domicilio', 'DOMICILIO',
      'calle', 'CALLE',
      'address', 'ADDRESS',
    ],
    'colonia': [
      'colonia', 'COLONIA',
      'asentamiento', 'ASENTAMIENTO',
      'barrio', 'BARRIO',
    ],
    'municipio': [
      'municipio', 'MUNICIPIO',
      'mun', 'MUN',
      'municipality', 'MUNICIPALITY',
    ],
    'estado': [
      'estado', 'ESTADO',
      'entidad', 'ENTIDAD',
      'state', 'STATE',
    ],
    'codigo_postal': [
      'codigo_postal', 'CODIGO_POSTAL',
      'cp', 'CP', 'postal_code', 'POSTAL_CODE',
    ],
    'imagen_url': [
      'imagen_url', 'IMAGEN_URL',
      'foto_url', 'FOTO_URL',
      'image_url', 'IMAGE_URL',
    ],
    'km_inicio': [
      'km_inicio', 'KM_INICIO',
      'cadenamiento_inicial', 'cad_ini', 'km_i',
    ],
    'km_fin': [
      'km_fin', 'KM_FIN',
      'cadenamiento_final', 'cad_fin', 'km_f',
    ],
    'km_lineales': [
      'km_lineales', 'KM_LINEALES',
      'longitud_km', 'longitud',
    ],
    'km_efectivos': ['km_efectivos', 'KM_EFECTIVOS'],
    'latitud':  ['latitud', 'lat', 'LAT', 'latitude'],
    'longitud': ['longitud', 'lon', 'lng', 'LON', 'longitude'],
    'rfc':  ['rfc', 'RFC'],
    'curp': ['curp', 'CURP'],
    'telefono': ['telefono', 'TELEFONO', 'tel', 'TEL', 'phone'],
    'correo':   ['correo', 'email', 'EMAIL', 'correo_electronico'],
    'razon_social': ['razon_social', 'RAZON_SOCIAL', 'empresa', 'EMPRESA', 'denominacion'],
  };

  /// Proyectos conocidos para detección automática.
  static const _proyectosConocidos = ['TQI', 'TSNL', 'TAP', 'TQM'];

  static String _normalizeKey(String input) {
    var s = input.toLowerCase();
    const replacements = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
    };
    replacements.forEach((k, v) => s = s.replaceAll(k, v));
    return s.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static String? _inferProyectoDesdeTexto(String? value) {
    if (value == null) return null;
    final upper = _normalizeSpaces(value).toUpperCase();
    if (upper.isEmpty) return null;

    for (final code in _proyectosConocidos) {
      final regex = RegExp('(^|[^A-Z0-9])' + code + r'([^A-Z0-9]|$)');
      if (regex.hasMatch(upper) || upper.contains(code)) {
        return code;
      }
    }

    return null;
  }

  static String? inferProyectoDesdeClave(String? clave) {
    if (clave == null) return null;
    final upper = clave.trim().toUpperCase();
    if (upper.isEmpty) return null;

    final compact = upper.replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (compact.startsWith('TQI') || compact.startsWith('QI')) return 'TQI';
    if (compact.startsWith('TSNL') || compact.startsWith('SNL') || compact.startsWith('SL')) {
      return 'TSNL';
    }
    if (compact.startsWith('TAP') || compact.startsWith('AP')) return 'TAP';
    if (compact.startsWith('TQM') || compact.startsWith('QM')) return 'TQM';

    return null;
  }

  /// Normaliza las claves del mapa [props] al esquema de Supabase.
  ///
  /// Las claves originales que no tienen alias conocido se preservan tal cual.
  /// Las claves canónicas tienen precedencia sobre las originales.
  static Map<String, dynamic> normalizeProperties(Map<String, dynamic> props) {
    final result = Map<String, dynamic>.from(props);

    for (final entry in _keyAliases.entries) {
      final canonicalKey = entry.key;
      dynamic selected = result[canonicalKey];

      if (selected == null || selected.toString().trim().isEmpty || selected.toString() == 'null') {
        for (final alias in entry.value) {
          final value = props[alias];
          if (value != null) {
            final str = value.toString().trim();
            if (str.isNotEmpty && str != 'null') {
              selected = value;
              break;
            }
          }
        }
      }

      if (selected != null) {
        result[canonicalKey] = _normalizeCanonicalValue(canonicalKey, selected);
      }
    }

    return result;
  }

  static dynamic _normalizeCanonicalValue(String key, dynamic value) {
    if (value is! String) return value;
    final text = _normalizeSpaces(value);

    switch (key) {
      case 'clave_catastral':
      case 'rfc':
      case 'curp':
        return text.toUpperCase();
      case 'correo':
        return text.toLowerCase();
      case 'proyecto':
        return _normalizeProyecto(text);
      case 'tipo_propiedad':
        return _normalizeTipoPropiedad(text);
      default:
        return text;
    }
  }

  static String _normalizeSpaces(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _normalizeProyecto(String value) {
    final inferred = _inferProyectoDesdeTexto(value);
    if (inferred != null) return inferred;
    return value.toUpperCase();
  }

  static String _normalizeTipoPropiedad(String value) {
    final upper = value.toUpperCase();
    if (upper.contains('SOC')) return 'SOCIAL';
    if (upper.contains('PRI')) return 'PRIVADA';
    return upper;
  }

  /// Intenta detectar el proyecto a partir de las properties normalizadas.
  ///
  /// Busca en los campos más relevantes y en todos los valores como fallback.
  static String? detectarProyecto(Map<String, dynamic> props) {
    // 1. Campo directo / alias con nombre relacionado a proyecto
    final candidatos = <String?>[
      props['proyecto']?.toString(),
      props['PROYECTO']?.toString(),
      props['nombre_proyecto']?.toString(),
      props['NOMBRE_PROYECTO']?.toString(),
      props['tramo_proyecto']?.toString(),
      props['TRAMO_PROYECTO']?.toString(),
      props['obra']?.toString(),
      props['OBRA']?.toString(),
    ];

    for (final entry in props.entries) {
      final key = _normalizeKey(entry.key);
      final keyIsProjectLike = key.contains('proyecto') ||
          key.contains('obra') ||
          key.contains('tramoproyecto');
      if (!keyIsProjectLike) continue;
      candidatos.add(entry.value?.toString());
    }

    for (final candidate in candidatos) {
      final inferred = _inferProyectoDesdeTexto(candidate);
      if (inferred != null) return inferred;
    }

    // 2. Prefijo de clave catastral
    final clave = props['clave_catastral']?.toString() ??
        props['CLAVE_CATASTRAL']?.toString() ??
        props['id_sedatu']?.toString() ??
        props['ID_SEDATU']?.toString() ??
        props['clave']?.toString() ??
        props['CLAVE']?.toString();
    final fromClave = inferProyectoDesdeClave(clave);
    if (fromClave != null) return fromClave;

    // 3. Buscar en todos los valores del mapa
    for (final value in props.values) {
      if (value == null) continue;
      final inferred = _inferProyectoDesdeTexto(value.toString());
      if (inferred != null) return inferred;
    }

    return null;
  }

  /// Detecta el proyecto desde una lista de features enriquecidos.
  ///
  /// Usa el campo `_proyecto` inyectado por el motor de sincronización,
  /// o busca en las properties originales como fallback.
  ///
  /// Si detecta más de un proyecto distinto dentro del mismo lote,
  /// devuelve `null` para no forzar un filtro incorrecto en Gestión.
  static String? detectarProyectoDesdeFeatures(
    List<Map<String, dynamic>> features,
  ) {
    final proyectosDetectados = <String>{};

    for (final feature in features) {
      final rawProps = feature['properties'];
      if (rawProps is! Map) continue;
      final props = Map<String, dynamic>.from(rawProps);

      // Campo inyectado por SincronizacionService
      final inyectado = props['_proyecto']?.toString().trim().toUpperCase();
      if (inyectado != null && _proyectosConocidos.contains(inyectado)) {
        proyectosDetectados.add(inyectado);
        if (proyectosDetectados.length > 1) return null;
        continue;
      }

      final detectado = detectarProyecto(props);
      if (detectado != null) {
        proyectosDetectados.add(detectado);
        if (proyectosDetectados.length > 1) return null;
      }
    }

    if (proyectosDetectados.length == 1) {
      return proyectosDetectados.first;
    }

    return null;
  }
}
