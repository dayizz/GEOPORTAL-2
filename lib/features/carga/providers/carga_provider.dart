import 'package:flutter_riverpod/flutter_riverpod.dart';

class ImportedFile {
  final String id;
  final String name;
  final int featureCount;
  final DateTime importedAt;
  final List<Map<String, dynamic>> features;

  /// UUID de la fila en la tabla `archivos_geojson`. Null = solo en memoria.
  final String? bdId;

  /// Si el archivo fue persistido en la base de datos.
  final bool guardadoEnBD;

  /// Si los features pasaron por el motor de sincronización con predios.
  final bool sincronizado;

  final int encontrados;
  final int creados;
  final int errores;

  ImportedFile({
    required this.id,
    required this.name,
    required this.featureCount,
    required this.importedAt,
    required this.features,
    this.bdId,
    this.guardadoEnBD = false,
    this.sincronizado = false,
    this.encontrados = 0,
    this.creados = 0,
    this.errores = 0,
  });

  ImportedFile copyWith({
    String? bdId,
    bool? guardadoEnBD,
    bool? sincronizado,
    int? encontrados,
    int? creados,
    int? errores,
    List<Map<String, dynamic>>? features,
  }) {
    return ImportedFile(
      id: id,
      name: name,
      featureCount: featureCount,
      importedAt: importedAt,
      features: features ?? this.features,
      bdId: bdId ?? this.bdId,
      guardadoEnBD: guardadoEnBD ?? this.guardadoEnBD,
      sincronizado: sincronizado ?? this.sincronizado,
      encontrados: encontrados ?? this.encontrados,
      creados: creados ?? this.creados,
      errores: errores ?? this.errores,
    );
  }

  /// Reconstruye un ImportedFile desde un registro de la BD.
  factory ImportedFile.fromBD(Map<String, dynamic> map) {
    final rawFeatures = map['features'];
    final features = rawFeatures is List
        ? rawFeatures.map((f) {
            if (f is Map<String, dynamic>) return f;
            if (f is Map) return Map<String, dynamic>.from(f);
            return <String, dynamic>{};
          }).toList()
        : <Map<String, dynamic>>[];

    final uuid = (map['id'] ?? '').toString();
    final nombre = (map['nombre'] ?? 'archivo').toString();
    final createdAtRaw = map['created_at'];
    final importedAt = createdAtRaw is String
        ? (DateTime.tryParse(createdAtRaw) ?? DateTime.now())
        : DateTime.now();
    return ImportedFile(
      id: uuid.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : uuid,
      name: nombre,
      featureCount: (map['features_count'] as num?)?.toInt() ?? features.length,
      importedAt: importedAt,
      features: features,
      bdId: uuid.isEmpty ? null : uuid,
      guardadoEnBD: true,
      sincronizado: map['sincronizado'] == true || map['sincronizado'] == 1,
      encontrados: (map['encontrados'] as num?)?.toInt() ?? 0,
      creados: (map['creados'] as num?)?.toInt() ?? 0,
      errores: (map['errores'] as num?)?.toInt() ?? 0,
    );
  }

  String get formattedDate =>
      '${importedAt.day}/${importedAt.month}/${importedAt.year} '
      '${importedAt.hour}:${importedAt.minute.toString().padLeft(2, '0')}';
}

class CargaNotifier extends StateNotifier<List<ImportedFile>> {
  CargaNotifier() : super([]);

  /// Carga (o recarga) la lista desde BD.
  /// Los archivos que solo están en memoria (sin bdId) se conservan al final.
  void initFromBD(List<ImportedFile> bdFiles) {
    final soloEnMemoria = state.where((f) => f.bdId == null).toList();
    final bdIds = bdFiles.map((f) => f.bdId).whereType<String>().toSet();
    final memoriaExtra = soloEnMemoria.where((f) => !bdIds.contains(f.bdId)).toList();
    state = [...bdFiles, ...memoriaExtra];
  }

  void addFile(
    String name,
    List<Map<String, dynamic>> features, {
    String? bdId,
    bool guardadoEnBD = false,
    bool sincronizado = false,
    int encontrados = 0,
    int creados = 0,
    int errores = 0,
    int? rowCount,
  }) {
    final id = bdId ?? DateTime.now().millisecondsSinceEpoch.toString();
    final file = ImportedFile(
      id: id,
      name: name,
      featureCount: rowCount ?? features.length,
      importedAt: DateTime.now(),
      features: features,
      bdId: bdId,
      guardadoEnBD: guardadoEnBD,
      sincronizado: sincronizado,
      encontrados: encontrados,
      creados: creados,
      errores: errores,
    );
    state = [file, ...state];
  }

  void removeFile(String id) {
    state = state.where((f) => f.id != id).toList();
  }

  ImportedFile? getFile(String id) {
    try {
      return state.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  void clearAll() {
    state = [];
  }
}

final cargaProvider = StateNotifierProvider<CargaNotifier, List<ImportedFile>>(
  (ref) => CargaNotifier(),
);

