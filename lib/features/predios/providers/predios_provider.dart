import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/predios_repository.dart';
import '../models/predio.dart';
import '../../auth/providers/demo_provider.dart';
import '../../auth/providers/demo_data.dart';
import 'demo_predios_notifier.dart';

// Filtros activos
class PrediosFiltros {
  final String busqueda;
  final String? usoSuelo;
  final String? zona;
  final String? propietarioId;
  final String? proyecto; // TQI, TSNL, TAP, TQM, etc.

  const PrediosFiltros({
    this.busqueda = '',
    this.usoSuelo,
    this.zona,
    this.propietarioId,
    this.proyecto,
  });

  PrediosFiltros copyWith({
    String? busqueda,
    String? usoSuelo,
    String? zona,
    String? propietarioId,
    String? proyecto,
    bool clearUsoSuelo = false,
    bool clearZona = false,
    bool clearPropietario = false,
    bool clearProyecto = false,
  }) {
    return PrediosFiltros(
      busqueda: busqueda ?? this.busqueda,
      usoSuelo: clearUsoSuelo ? null : (usoSuelo ?? this.usoSuelo),
      zona: clearZona ? null : (zona ?? this.zona),
      propietarioId: clearPropietario ? null : (propietarioId ?? this.propietarioId),
      proyecto: clearProyecto ? null : (proyecto ?? this.proyecto),
    );
  }
}

final prediosFiltrosProvider = StateProvider<PrediosFiltros>(
  (ref) => const PrediosFiltros(),
);

final prediosListProvider = FutureProvider<List<Predio>>((ref) async {
  final isDemo = ref.watch(demoModeProvider);
  if (isDemo) {
    final filtros = ref.watch(prediosFiltrosProvider);
    var lista = List<Predio>.from(ref.watch(demoPrediosNotifierProvider));
    if (filtros.busqueda.isNotEmpty) {
      final q = filtros.busqueda.toLowerCase();
      lista = lista.where((p) =>
        p.claveCatastral.toLowerCase().contains(q) ||
        (p.propietarioNombre?.toLowerCase().contains(q) ?? false) ||
        (p.ejido?.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    if (filtros.usoSuelo != null) {
      lista = lista.where((p) => p.usoSuelo == filtros.usoSuelo).toList();
    }
    if (filtros.zona != null) {
      lista = lista.where((p) => p.zona == filtros.zona).toList();
    }
    if (filtros.proyecto != null) {
      lista = lista.where((p) => _extractProjectoFromPredio(p) == filtros.proyecto).toList();
    }
    return lista;
  }
  final filtros = ref.watch(prediosFiltrosProvider);
  final repo = ref.read(prediosRepositoryProvider);
  return repo.getPredios(
    busqueda: filtros.busqueda,
    usoSuelo: filtros.usoSuelo,
    zona: filtros.zona,
    propietarioId: filtros.propietarioId,
  );
});

/// Extrae el proyecto de un predio según sus campos
String _extractProjectoFromPredio(Predio predio) {
  final proyectoDirecto = predio.proyecto?.trim().toUpperCase();
  if (proyectoDirecto != null && proyectoDirecto.isNotEmpty) {
    return proyectoDirecto;
  }

  final contenido = [
    predio.claveCatastral,
    predio.ejido ?? '',
    predio.poligonoDwg ?? '',
    predio.oficio ?? '',
    predio.copFirmado ?? '',
  ].join(' ').toUpperCase();

  const proyectos = ['TQI', 'TSNL', 'TAP', 'TQM'];
  for (final proyecto in proyectos) {
    if (contenido.contains(proyecto)) return proyecto;
  }

  return 'Sin proyecto';
}

final prediosMapaProvider = FutureProvider<List<Predio>>((ref) async {
  final isDemo = ref.watch(demoModeProvider);
  if (isDemo) return ref.watch(demoPrediosNotifierProvider);
  final repo = ref.read(prediosRepositoryProvider);
  return repo.getPredios(limit: 200);
});

final predioDetalleProvider = FutureProvider.family<Predio?, String>((ref, id) async {
  final isDemo = ref.watch(demoModeProvider);
  if (isDemo) {
    final lista = ref.watch(demoPrediosNotifierProvider);
    try {
      return lista.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
  final repo = ref.read(prediosRepositoryProvider);
  return repo.getPredioById(id);
});

final estadisticasProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final isDemo = ref.watch(demoModeProvider);
  if (isDemo) return demoEstadisticas;
  final repo = ref.read(prediosRepositoryProvider);
  return repo.getEstadisticas();
});
