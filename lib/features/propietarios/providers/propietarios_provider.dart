import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/propietarios_repository.dart';
import '../../../features/predios/models/propietario.dart';
import '../../predios/models/predio.dart';
import '../../predios/data/predios_repository.dart';
import '../../auth/providers/demo_provider.dart';
import '../../auth/providers/demo_data.dart';

final propietariosFiltroProvider = StateProvider<String>((ref) => '');
final propietariosProyectoFiltroProvider = StateProvider<String?>((ref) => null);

final propietariosListProvider = FutureProvider<List<Propietario>>((ref) async {
  final isDemo = ref.watch(demoModeProvider);
  final proyecto = ref.watch(propietariosProyectoFiltroProvider);
  if (isDemo) {
    final busqueda = ref.watch(propietariosFiltroProvider).toLowerCase();
    var lista = demoPropietarios;
    if (busqueda.isNotEmpty) {
      lista = lista.where((p) =>
      p.nombreCompleto.toLowerCase().contains(busqueda) ||
      (p.rfc?.toLowerCase().contains(busqueda) ?? false)
    ).toList();
    }

    if (proyecto != null) {
      final nombresProyecto = demoPredios
          .where((predio) => _extractProyectoFromPredio(predio) == proyecto)
          .map((predio) => (predio.propietarioNombre ?? '').trim().toUpperCase())
          .where((nombre) => nombre.isNotEmpty)
          .toSet();
      lista = lista
          .where((propietario) => nombresProyecto.contains(propietario.nombreCompleto.trim().toUpperCase()))
          .toList();
    }

    return lista;
  }

  final busqueda = ref.watch(propietariosFiltroProvider);
  final repo = ref.read(propietariosRepositoryProvider);
  final propietarios = await repo.getPropietarios(busqueda: busqueda, limit: 500);

  if (proyecto == null) return propietarios;

  final prediosRepo = ref.read(prediosRepositoryProvider);
  final predios = await prediosRepo.getPredios(limit: 1000);
  final prediosDelProyecto = predios
      .where((predio) => _extractProyectoFromPredio(predio) == proyecto)
      .toList();

  final propietarioIds = prediosDelProyecto
      .map((predio) => predio.propietarioId)
      .whereType<String>()
      .toSet();

  final nombresProyecto = prediosDelProyecto
      .map((predio) => (predio.propietarioNombre ?? '').trim().toUpperCase())
      .where((nombre) => nombre.isNotEmpty)
      .toSet();

  return propietarios.where((propietario) {
    if (propietarioIds.contains(propietario.id)) return true;
    return nombresProyecto.contains(propietario.nombreCompleto.trim().toUpperCase());
  }).toList();
});

String _extractProyectoFromPredio(Predio predio) {
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

final propietarioDetalleProvider =
    FutureProvider.family<Propietario?, String>((ref, id) async {
  final isDemo = ref.watch(demoModeProvider);
  if (isDemo) {
    try {
      return demoPropietarios.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
  final repo = ref.read(propietariosRepositoryProvider);
  return repo.getPropietarioById(id);
});
