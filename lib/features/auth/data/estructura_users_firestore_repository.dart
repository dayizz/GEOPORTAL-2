import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final estructuraUsersFirestoreRepositoryProvider = Provider<EstructuraUsersFirestoreRepository>((ref) {
  return EstructuraUsersFirestoreRepository();
});

class EstructuraUsersFirestoreRepository {
  final _collection = FirebaseFirestore.instance.collection('usuarios_estructura');

  Future<List<Map<String, dynamic>>> getUsers() async {
    final query = await _collection.orderBy('updated_at', descending: false).get();
    return query.docs.map((doc) => doc.data()).toList(growable: false);
  }

  Future<void> upsertUser(Map<String, dynamic> user) async {
    final payload = Map<String, dynamic>.from(user)
      ..['updated_at'] = DateTime.now().toIso8601String();
    payload.putIfAbsent('created_at', () => DateTime.now().toIso8601String());
    await _collection.doc(payload['id']).set(payload, SetOptions(merge: true));
  }

  Future<void> deleteUser(String id) async {
    await _collection.doc(id).delete();
  }
}
