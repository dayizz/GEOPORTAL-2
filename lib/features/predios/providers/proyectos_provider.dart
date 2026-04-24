import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/proyecto.dart';

class ProyectosNotifier extends StateNotifier<List<Proyecto>> {
  ProyectosNotifier() : super([]);

  void addProyecto(Proyecto proyecto) {
    state = [...state, proyecto];
  }

  void removeProyecto(String id) {
    state = state.where((p) => p.id != id).toList();
  }

  void updateProyecto(String id, Proyecto updated) {
    state = [
      for (final p in state)
        if (p.id == id) updated else p,
    ];
  }

  void clearAll() {
    state = [];
  }

  Proyecto? getProyecto(String id) {
    try {
      return state.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Proyecto> getByProyecto(String proyecto) {
    return state.where((p) => p.proyecto == proyecto).toList();
  }
}

final proyectosProvider = StateNotifierProvider<ProyectosNotifier, List<Proyecto>>(
  (ref) => ProyectosNotifier(),
);
