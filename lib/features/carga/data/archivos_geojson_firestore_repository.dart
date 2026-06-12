import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final archivosGeoJsonFirestoreRepositoryProvider = Provider<ArchivosGeoJsonFirestoreRepository>((ref) {
  return ArchivosGeoJsonFirestoreRepository();
});

class ArchivosGeoJsonFirestoreRepository {
  final _collection = FirebaseFirestore.instance.collection('archivos_geojson');

  Future<List<Map<String, dynamic>>> getArchivos() async {
    final query = await _collection.orderBy('created_at', descending: true).get();
    return query.docs.map((doc) => doc.data()).toList();
  }

  Future<Map<String, dynamic>?> getArchivoById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  Future<Map<String, dynamic>> createArchivo(Map<String, dynamic> data) async {
    final doc = _collection.doc(data['id']);
    await doc.set(data);
    final saved = await doc.get();
    return saved.data()!;
  }

  Future<Map<String, dynamic>> updateArchivo(String id, Map<String, dynamic> data) async {
    final doc = _collection.doc(id);
    await doc.update(data);
    final updated = await doc.get();
    return updated.data()!;
  }

  Future<void> deleteArchivo(String id) async {
    await _collection.doc(id).delete();
  }
}
