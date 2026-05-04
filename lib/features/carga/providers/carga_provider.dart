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

    final uuid = map['id'] as String;
    return ImportedFile(
      id: uuid,
      name: map['nombre'] as String,
      featureCount: map['features_count'] as int? ?? features.length,
      importedAt: DateTime.parse(map['created_at'] as String),
      features: features,
      bdId: uuid,
      guardadoEnBD: true,
      sincronizado: map['sincronizado'] as bool? ?? false,
      encontrados: map['encontrados'] as int? ?? 0,
      creados: map['creados'] as int? ?? 0,
      errores: map['errores'] as int? ?? 0,
    );
  }

  String get formattedDate =>
      '${importedAt.day}/${importedAt.month}/${importedAt.year} '
      '${importedAt.hour}:${importedAt.minute.toString().padLeft(2, '0')}';
}

class CargaNotifier extends StateNotifier<List<ImportedFile>> {
  CargaNotifier() : super([]);

  /// Inicializa con archivos cargados desde la BD (sin duplicar los que ya estén).
  void initFromBD(List<ImportedFile> bdFiles) {
    final existingBdIds =
        state.map((f) => f.bdId).where((id) => id != null).toSet();
    final nuevos =
        bdFiles.where((f) => !existingBdIds.contains(f.bdId)).toList();
    if (nuevos.isNotEmpty) {
      state = [...nuevos, ...state];
    }
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

