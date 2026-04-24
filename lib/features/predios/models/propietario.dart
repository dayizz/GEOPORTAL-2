// Modelos de datos

class Propietario {
  final String id;
  final String nombre;
  final String apellidos;
  final String tipoPersona; // 'fisica' | 'moral'
  final String? razonSocial;
  final String? curp;
  final String? rfc;
  final String? telefono;
  final String? correo;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Propietario({
    required this.id,
    required this.nombre,
    required this.apellidos,
    required this.tipoPersona,
    this.razonSocial,
    this.curp,
    this.rfc,
    this.telefono,
    this.correo,
    required this.createdAt,
    this.updatedAt,
  });

  String get nombreCompleto => tipoPersona == 'moral'
      ? (razonSocial ?? '$nombre $apellidos')
      : '$nombre $apellidos';

  factory Propietario.fromMap(Map<String, dynamic> map) {
    return Propietario(
      id: map['id'] as String,
      nombre: map['nombre'] as String,
      apellidos: map['apellidos'] as String? ?? '',
      tipoPersona: map['tipo_persona'] as String? ?? 'fisica',
      razonSocial: map['razon_social'] as String?,
      curp: map['curp'] as String?,
      rfc: map['rfc'] as String?,
      telefono: map['telefono'] as String?,
      correo: map['correo'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'apellidos': apellidos,
      'tipo_persona': tipoPersona,
      'razon_social': razonSocial,
      'curp': curp,
      'rfc': rfc,
      'telefono': telefono,
      'correo': correo,
    };
  }

  Propietario copyWith({
    String? id,
    String? nombre,
    String? apellidos,
    String? tipoPersona,
    String? razonSocial,
    String? curp,
    String? rfc,
    String? telefono,
    String? correo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Propietario(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      apellidos: apellidos ?? this.apellidos,
      tipoPersona: tipoPersona ?? this.tipoPersona,
      razonSocial: razonSocial ?? this.razonSocial,
      curp: curp ?? this.curp,
      rfc: rfc ?? this.rfc,
      telefono: telefono ?? this.telefono,
      correo: correo ?? this.correo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
