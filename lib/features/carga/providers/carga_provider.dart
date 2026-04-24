import 'package:flutter_riverpod/flutter_riverpod.dart';

class ImportedFile {
  final String id;
  final String name;
  final int featureCount;
  final DateTime importedAt;
  final List<Map<String, dynamic>> features;

  ImportedFile({
    required this.id,
    required this.name,
    required this.featureCount,
    required this.importedAt,
    required this.features,
  });

  String get formattedDate =>
      '${importedAt.day}/${importedAt.month}/${importedAt.year} ${importedAt.hour}:${importedAt.minute.toString().padLeft(2, '0')}';
}

class CargaNotifier extends StateNotifier<List<ImportedFile>> {
  CargaNotifier() : super([]);

  void addFile(String name, List<Map<String, dynamic>> features) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final file = ImportedFile(
      id: id,
      name: name,
      featureCount: features.length,
      importedAt: DateTime.now(),
      features: features,
    );
    state = [...state, file];
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
