import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/predio.dart';
import '../../auth/providers/demo_data.dart';

class DemoPrediosNotifier extends StateNotifier<List<Predio>> {
  DemoPrediosNotifier() : super(List<Predio>.from(demoPredios));

  void updatePredio(Predio updated) {
    state = [
      for (final p in state)
        if (p.id == updated.id) updated else p,
    ];
  }

  void addPredio(Predio predio) {
    state = [...state, predio];
  }

  void deletePredio(String id) {
    state = state.where((p) => p.id != id).toList();
  }
}

final demoPrediosNotifierProvider =
    StateNotifierProvider<DemoPrediosNotifier, List<Predio>>(
  (ref) => DemoPrediosNotifier(),
);
