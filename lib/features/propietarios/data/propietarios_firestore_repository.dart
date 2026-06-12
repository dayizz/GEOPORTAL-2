import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../predios/models/propietario.dart';

final propietariosFirestoreRepositoryProvider = Provider<PropietariosFirestoreRepository>((ref) {
  return PropietariosFirestoreRepository();
});

class PropietariosFirestoreRepository {
  Future<Propietario?> findOrCreateByNombreCompleto(String nombreCompleto) async {
    final query = await _collection.where('nombreCompleto', isEqualTo: nombreCompleto).limit(1).get();
    if (query.docs.isNotEmpty) {
      return Propietario.fromMap(query.docs.first.data());
    }
    // Si no existe, puedes crear uno vacío o retornar null según la lógica de tu app
    return null;
  }
  Future<Propietario> findOrCreateFromData(Map<String, dynamic> data) async {
    final id = data['id'] as String?;
    if (id != null) {
      final existing = await getPropietarioById(id);
      if (existing != null) {
        await updatePropietario(id, data);
        return (await getPropietarioById(id))!;
      }
    }
    return await createPropietario(data);
  }
  final _collection = FirebaseFirestore.instance.collection('propietarios');

  Future<List<Propietario>> getPropietarios({String? busqueda, String? tipoPersona, int limit = 100}) async {
    Query query = _collection.limit(limit);
    if (tipoPersona != null && tipoPersona.isNotEmpty) {
      query = query.where('tipo_persona', isEqualTo: tipoPersona);
    }
    final snapshot = await query.get();
    var propietarios = snapshot.docs.map((doc) => Propietario.fromMap(doc.data() as Map<String, dynamic>)).toList();
    if (busqueda != null && busqueda.trim().isNotEmpty) {
      final q = busqueda.trim().toLowerCase();
      propietarios = propietarios.where((p) {
        return p.nombre.toLowerCase().contains(q) ||
            p.apellidos.toLowerCase().contains(q) ||
            (p.rfc?.toLowerCase().contains(q) ?? false) ||
            (p.curp?.toLowerCase().contains(q) ?? false) ||
            (p.razonSocial?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    propietarios.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    if (propietarios.length > limit) {
      propietarios = propietarios.sublist(0, limit);
    }
    return propietarios;
  }

  Future<Propietario?> getPropietarioById(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return Propietario.fromMap(doc.data()!);
  }

  Future<Propietario> createPropietario(Map<String, dynamic> data) async {
    final doc = _collection.doc(data['id']);
    await doc.set(data);
    final saved = await doc.get();
    return Propietario.fromMap(saved.data()!);
  }

  Future<Propietario> updatePropietario(String id, Map<String, dynamic> data) async {
    final doc = _collection.doc(id);
    await doc.update(data);
    final updated = await doc.get();
    return Propietario.fromMap(updated.data()!);
  }

  Future<void> deletePropietario(String id) async {
    await _collection.doc(id).delete();
  }
}
