import 'dart:convert';

import 'propietario.dart';

class Predio {
  final String id;
  final String claveCatastral; // ID SEDATU o identificador del predio
  final String? propietarioNombre; // Nombre directo del propietario
  final String tramo; // T1, T2, T3, T4
  final String tipoPropiedad; // SOCIAL, DOMINIO PLENO, PRIVADA
  final String? ejido;
  final String? estado;
    /// ID del archivo importado (ImportedFile.id) que originó este predio.
    final String? archivoId;
  final String? municipio;
  final double? kmInicio;
  final double? kmFin;
  final double? kmLineales;
  final double? kmEfectivos;
  final double? superficie; // M2
  final bool cop; // Convenio de Ocupación Previa
  final String? copFirmado; // Archivo PDF del COP firmado
  final String? pdfUrl; // URL publica del PDF COP/DOT en storage
  final DateTime? copFecha; // Fecha asociada al documento COP/DOT
  final String? poligonoDwg; // Archivo DWG del polígono
  final String? oficio; // Oficio entregado
  final String? proyecto;
  final bool poligonoInsertado;
  final bool identificacion;
  final bool levantamiento;
  final bool negociacion;
  final String? situacionSocial;
  final double? latitud;
  final double? longitud;
  final Map<String, dynamic>? geometry;
  final String? propietarioId;
  final Propietario? propietario;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Aliases para compatibilidad con pantallas existentes
  String get usoSuelo => tipoPropiedad;
  String get zona => tramo;
  String get direccion => ejido ?? '-';

  // Estado de liberacion unificado para Gestion y Mapa.
  String get estatusGestion {
    if (cop) return 'Liberado';
    if (negociacion || levantamiento || identificacion) {
      return 'No liberado';
    }
    return 'Sin estatus';
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'si' ||
          normalized == 'sí' ||
          normalized == 'yes' ||
          normalized == 'y';
    }
    return false;
  }

  const Predio({
    required this.id,
    required this.claveCatastral,
    this.propietarioNombre,
    required this.tramo,
    required this.tipoPropiedad,
    this.ejido,
    this.estado,
    this.municipio,
      this.archivoId,
    this.kmInicio,
    this.kmFin,
    this.kmLineales,
    this.kmEfectivos,
    this.superficie,
    this.cop = false,
    this.copFirmado,
    this.pdfUrl,
    this.copFecha,
    this.poligonoDwg,
    this.oficio,
    this.proyecto,
    this.poligonoInsertado = false,
    this.identificacion = false,
    this.levantamiento = false,
    this.negociacion = false,
    this.situacionSocial,
    this.latitud,
    this.longitud,
    this.geometry,
    this.propietarioId,
    this.propietario,
    required this.createdAt,
    this.updatedAt,
  });

  factory Predio.fromMap(Map<String, dynamic> map) {
    // Normalizar geometría: puede venir como string JSON o como Map
    Map<String, dynamic>? geometry;
    final geometryRaw = map['geometry'];
    if (geometryRaw != null) {
      if (geometryRaw is String) {
        try {
          geometry = jsonDecode(geometryRaw) as Map<String, dynamic>;
        } catch (_) {
          geometry = null;
        }
      } else if (geometryRaw is Map) {
        geometry = Map<String, dynamic>.from(geometryRaw);
      }
    }
    
    return Predio(
      id: map['id'] as String,
      claveCatastral: map['clave_catastral'] as String? ?? map['id_sedatu'] as String? ?? '',
      propietarioNombre: map['propietario_nombre'] as String?,
      tramo: map['tramo'] as String? ?? 'T1',
      tipoPropiedad: map['tipo_propiedad'] as String? ?? 'PRIVADA',
      ejido: map['ejido'] as String?,
      estado: map['estado'] as String?,
      municipio: map['municipio'] as String?,
        archivoId: map['archivo_id'] as String?,
      kmInicio: (map['km_inicio'] as num?)?.toDouble(),
      kmFin: (map['km_fin'] as num?)?.toDouble(),
      kmLineales: (map['km_lineales'] as num?)?.toDouble(),
      kmEfectivos: (map['km_efectivos'] as num?)?.toDouble(),
      superficie: (map['superficie'] as num?)?.toDouble(),
      cop: _asBool(map['cop']),
      copFirmado: map['cop_firmado'] as String?,
      pdfUrl: map['pdf_url'] as String? ?? map['cop_firmado'] as String?,
        copFecha: map['cop_fecha'] != null
          ? DateTime.tryParse(map['cop_fecha'] as String)
          : null,
      poligonoDwg: map['poligono_dwg'] as String?,
      oficio: map['oficio'] as String?,
      proyecto: map['proyecto'] as String?,
      poligonoInsertado: _asBool(map['poligono_insertado']),
      identificacion: _asBool(map['identificacion']),
      levantamiento: _asBool(map['levantamiento']),
      negociacion: _asBool(map['negociacion']),
      situacionSocial: map['situacion_social'] as String?,
      latitud: (map['latitud'] as num?)?.toDouble(),
      longitud: (map['longitud'] as num?)?.toDouble(),
      geometry: geometry,
      propietarioId: map['propietario_id'] as String?,
      propietario: map['propietarios'] != null
          ? Propietario.fromMap(map['propietarios'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'clave_catastral': claveCatastral,
      'propietario_nombre': propietarioNombre,
      'tramo': tramo,
      'tipo_propiedad': tipoPropiedad,
      'ejido': ejido,
      'estado': estado,
      'municipio': municipio,
        if (archivoId != null) 'archivo_id': archivoId,
      'km_inicio': kmInicio,
      'km_fin': kmFin,
      'km_lineales': kmLineales,
      'km_efectivos': kmEfectivos,
      'superficie': superficie,
      'cop': cop,
      'cop_firmado': copFirmado,
      'pdf_url': pdfUrl,
      'cop_fecha': copFecha?.toIso8601String(),
      'poligono_dwg': poligonoDwg,
      'oficio': oficio,
      'poligono_insertado': poligonoInsertado,
      'identificacion': identificacion,
      'levantamiento': levantamiento,
      'negociacion': negociacion,
      'situacion_social': situacionSocial,
      'latitud': latitud,
      'longitud': longitud,
      'geometry': geometry,
      'propietario_id': propietarioId,
    };
  }

  double get porcentajeAvance {
    int c = 0;
    if (identificacion) c++;
    if (levantamiento) c++;
    if (negociacion) c++;
    if (cop) c++;
    if (poligonoInsertado) c++;
    return c / 5.0;
  }

  String get nombrePropietario {
    if (propietario != null) return propietario!.nombreCompleto;
    return propietarioNombre ?? claveCatastral;
  }

  Predio copyWith({
    String? id,
    String? claveCatastral,
    String? propietarioNombre,
    String? tramo,
    String? tipoPropiedad,
    String? ejido,
    String? estado,
    String? municipio,
      String? archivoId,
    double? kmInicio,
    double? kmFin,
    double? kmLineales,
    double? kmEfectivos,
    double? superficie,
    bool? cop,
    String? copFirmado,
    String? pdfUrl,
    DateTime? copFecha,
    String? poligonoDwg,
    String? oficio,
    String? proyecto,
    bool? poligonoInsertado,
    bool? identificacion,
    bool? levantamiento,
    bool? negociacion,
    String? situacionSocial,
    double? latitud,
    double? longitud,
    Map<String, dynamic>? geometry,
    String? propietarioId,
    Propietario? propietario,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Predio(
      id: id ?? this.id,
      claveCatastral: claveCatastral ?? this.claveCatastral,
      propietarioNombre: propietarioNombre ?? this.propietarioNombre,
      tramo: tramo ?? this.tramo,
      tipoPropiedad: tipoPropiedad ?? this.tipoPropiedad,
      ejido: ejido ?? this.ejido,
      estado: estado ?? this.estado,
      municipio: municipio ?? this.municipio,
        archivoId: archivoId ?? this.archivoId,
      kmInicio: kmInicio ?? this.kmInicio,
      kmFin: kmFin ?? this.kmFin,
      kmLineales: kmLineales ?? this.kmLineales,
      kmEfectivos: kmEfectivos ?? this.kmEfectivos,
      superficie: superficie ?? this.superficie,
      cop: cop ?? this.cop,
      copFirmado: copFirmado ?? this.copFirmado,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      copFecha: copFecha ?? this.copFecha,
      poligonoDwg: poligonoDwg ?? this.poligonoDwg,
      oficio: oficio ?? this.oficio,
      proyecto: proyecto ?? this.proyecto,
      poligonoInsertado: poligonoInsertado ?? this.poligonoInsertado,
      identificacion: identificacion ?? this.identificacion,
      levantamiento: levantamiento ?? this.levantamiento,
      negociacion: negociacion ?? this.negociacion,
      situacionSocial: situacionSocial ?? this.situacionSocial,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      geometry: geometry ?? this.geometry,
      propietarioId: propietarioId ?? this.propietarioId,
      propietario: propietario ?? this.propietario,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
