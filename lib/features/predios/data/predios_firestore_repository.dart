import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/predio.dart';

final prediosFirestoreRepositoryProvider = Provider<PrediosFirestoreRepository>((ref) {
  return PrediosFirestoreRepository();
});

class PrediosFirestoreRepository {

    // Stub para compatibilidad con UI. Implementar lógica real si es necesario.
    Future<void> vincularPoligonoConPredio(String predioId, String poligonoId) async {
      // Dummy: no hace nada
    }
    Future<String?> uploadPredioPdf(String predioId, dynamic file) async {
      // Dummy: retorna URL vacía
      return null;
    }
  final _collection = FirebaseFirestore.instance.collection('predios');

  Future<List<Predio>> getPredios({int limit = 50, int offset = 0}) async {
    final query = await _collection.orderBy('created_at', descending: true).limit(limit).get();
    return query.docs.map((doc) => Predio.fromMap(doc.data())).toList();
  }

  Future<Predio?> getPredioById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return Predio.fromMap(doc.data()!);
  }

  Future<Predio?> buscarPorClaveCatastral(String clave) async {
    final query = await _collection.where('clave_catastral', isEqualTo: clave).limit(1).get();
    if (query.docs.isEmpty) return null;
    return Predio.fromMap(query.docs.first.data());
  }

  Future<Predio> createPredio(Map<String, dynamic> data) async {
    final doc = _collection.doc(data['id']);
    await doc.set(data);
    final saved = await doc.get();
    return Predio.fromMap(saved.data()!);
  }

  Future<List<Predio>> createPrediosBatch(List<Map<String, dynamic>> items) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final item in items) {
      final doc = _collection.doc(item['id']);
      batch.set(doc, item);
    }
    await batch.commit();
    return getPredios(limit: items.length);
  }

  Future<Predio> updatePredio(String id, Map<String, dynamic> data) async {
    final doc = _collection.doc(id);
    await doc.update(data);
    final updated = await doc.get();
    return Predio.fromMap(updated.data()!);
  }

  Future<void> deletePredio(String id) async {
    await _collection.doc(id).delete();
  }

  Future<List<Predio>> getPrediosByArchivoId(String archivoId) async {
    final query = await _collection.where('archivo_id', isEqualTo: archivoId).get();
    return query.docs.map((doc) => Predio.fromMap(doc.data())).toList();
  }

  Future<void> deletePrediosByArchivoId(String archivoId) async {
    final query = await _collection.where('archivo_id', isEqualTo: archivoId).get();
    for (final doc in query.docs) {
      await doc.reference.delete();
    }
  }

  Future<List<Predio>> getPrediosConGeometria() async {
    final query = await _collection.where('geometry', isNotEqualTo: null).get();
    return query.docs.map((doc) => Predio.fromMap(doc.data())).toList();
  }

  Future<Map<String, dynamic>> getEstadisticas() async {
    final query = await _collection.get();
    final predios = query.docs.map((doc) => Predio.fromMap(doc.data())).toList();
    final conteoUso = <String, int>{};
    double superficieTotal = 0;
    for (final p in predios) {
      conteoUso[p.usoSuelo] = (conteoUso[p.usoSuelo] ?? 0) + 1;
      superficieTotal += p.superficie ?? 0;
    }
    return {
      'total': predios.length,
      'por_uso_suelo': conteoUso,
      'superficie_total': superficieTotal,
    };
  }
}
