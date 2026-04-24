import 'dart:convert';

class Proyecto {
  final String id;
  final String propietario;
  final String tramo;
  final String tipoPropiedad; // SOCIAL, PRIVADA, Sin tipo
  final String? estado;
  final String? municipio;
  final String? estatusPredio; // Liberado, No liberado, Sin estatus
  final double? kmInicio;
  final double? kmFin;
  final double superficie; // m²
  final String proyecto; // TQI, TSNL, TAP, TQM, Sin proyecto
  final Map<String, dynamic>? geometry; // GeoJSON del polígono
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Proyecto({
    required this.id,
    required this.propietario,
    required this.tramo,
    required this.tipoPropiedad,
    this.estado,
    this.municipio,
    this.estatusPredio,
    this.kmInicio,
    this.kmFin,
    required this.superficie,
    required this.proyecto,
    this.geometry,
    required this.createdAt,
    this.updatedAt,
  });

  factory Proyecto.fromMap(Map<String, dynamic> map) {
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

    return Proyecto(
      id: map['id'] as String,
      propietario: map['propietario'] as String? ?? '',
      tramo: map['tramo'] as String? ?? '',
      tipoPropiedad: map['tipo_propiedad'] as String? ?? 'Sin tipo',
      estado: map['estado'] as String?,
      municipio: map['municipio'] as String?,
      estatusPredio: map['estatus_predio'] as String?,
      kmInicio: (map['km_inicio'] as num?)?.toDouble(),
      kmFin: (map['km_fin'] as num?)?.toDouble(),
      superficie: (map['superficie'] as num?)?.toDouble() ?? 0.0,
      proyecto: map['proyecto'] as String? ?? 'Sin proyecto',
      geometry: geometry,
      createdAt: map['created_at'] is String
          ? DateTime.parse(map['created_at'] as String)
          : map['created_at'] as DateTime,
      updatedAt: map['updated_at'] is String
          ? DateTime.parse(map['updated_at'] as String)
          : map['updated_at'] as DateTime?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'propietario': propietario,
      'tramo': tramo,
      'tipo_propiedad': tipoPropiedad,
      'estado': estado,
      'municipio': municipio,
      'estatus_predio': estatusPredio,
      'km_inicio': kmInicio,
      'km_fin': kmFin,
      'superficie': superficie,
      'proyecto': proyecto,
      'geometry': geometry != null ? jsonEncode(geometry) : null,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Proyecto copyWith({
    String? id,
    String? propietario,
    String? tramo,
    String? tipoPropiedad,
    String? estado,
    String? municipio,
    String? estatusPredio,
    double? kmInicio,
    double? kmFin,
    double? superficie,
    String? proyecto,
    Map<String, dynamic>? geometry,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Proyecto(
      id: id ?? this.id,
      propietario: propietario ?? this.propietario,
      tramo: tramo ?? this.tramo,
      tipoPropiedad: tipoPropiedad ?? this.tipoPropiedad,
      estado: estado ?? this.estado,
      municipio: municipio ?? this.municipio,
      estatusPredio: estatusPredio ?? this.estatusPredio,
      kmInicio: kmInicio ?? this.kmInicio,
      kmFin: kmFin ?? this.kmFin,
      superficie: superficie ?? this.superficie,
      proyecto: proyecto ?? this.proyecto,
      geometry: geometry ?? this.geometry,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
