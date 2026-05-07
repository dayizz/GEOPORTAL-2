import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final firestoreArchivosRepositoryProvider = Provider<FirestoreArchivosRepository>(
  (ref) => FirestoreArchivosRepository(FirebaseFirestore.instance),
);

class FirestoreArchivosRepository {
  final FirebaseFirestore _db;
  static const _collection = 'archivos_geojson';
  static const _uuid = Uuid();

  FirestoreArchivosRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(_collection);

  /// Obtiene todos los archivos ordenados del más reciente al más antiguo.
  Future<List<Map<String, dynamic>>> getArchivos() async {
    final snapshot = await _col
        .orderBy('created_at', descending: true)
        .get();
    return snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Guarda un archivo. Devuelve el mapa con el id asignado.
  Future<Map<String, dynamic>> saveArchivo({
    required String nombre,
    required List<Map<String, dynamic>> features,
    int? rowCount,
    bool sincronizado = false,
    int encontrados = 0,
    int creados = 0,
    int errores = 0,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    // Limitar features almacenadas para no exceder límite de Firestore (1 MB/doc)
    final storedFeatures = _limitFeatures(features);
    final data = <String, dynamic>{
      'nombre': nombre,
      'features_count': rowCount ?? features.length,
      'features': storedFeatures,
      'sincronizado': sincronizado,
      'encontrados': encontrados,
      'creados': creados,
      'errores': errores,
      'created_at': now,
      'updated_at': now,
    };
    await _col.doc(id).set(data);
    return {'id': id, ...data};
  }

  /// Elimina un archivo por su id de Firestore.
  Future<void> deleteArchivo(String id) async {
    await _col.doc(id).delete();
  }

  /// Elimina todos los archivos.
  Future<void> deleteAll() async {
    final snapshot = await _col.get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Limita las features para no superar ~800 KB por documento de Firestore.
  List<Map<String, dynamic>> _limitFeatures(List<Map<String, dynamic>> features) {
    if (features.isEmpty) return const [];
    final result = <Map<String, dynamic>>[];
    var bytes = 0;
    for (final f in features) {
      final encoded = utf8.encode(jsonEncode(f)).length;
      if (result.length >= 50 || bytes + encoded > 700000) break;
      result.add(f);
      bytes += encoded;
    }
    return result;
  }
}
