import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_config.dart';
import '../data/propietarios_repository.dart';
import '../../../features/predios/models/propietario.dart';
import '../../predios/models/predio.dart';
import '../../predios/providers/predios_provider.dart';
import 'local_propietarios_provider.dart';

final propietariosFiltroProvider = StateProvider<String>((ref) => '');
final propietariosProyectoFiltroProvider = StateProvider<String?>((ref) => null);

final propietariosListProvider = FutureProvider<List<Propietario>>((ref) async {
  final proyecto = ref.watch(propietariosProyectoFiltroProvider);
  final busqueda = ref.watch(propietariosFiltroProvider);
  final locales = ref.watch(localPropietariosProvider);
  final repo = ref.read(propietariosRepositoryProvider);

  List<Propietario> remotos = const [];
  if (SupabaseConfig.isConfigured) {
    try {
      remotos = await repo.getPropietarios(busqueda: busqueda, limit: 500);
    } catch (_) {
      remotos = const [];
    }
  }

  var propietarios = <Propietario>[...remotos];
  final ids = remotos.map((item) => item.id).toSet();
  final rfcs = remotos
      .map((item) => (item.rfc ?? '').trim().toUpperCase())
      .where((item) => item.isNotEmpty)
      .toSet();
  final nombres = remotos
      .map((item) => item.nombreCompleto.trim().toUpperCase())
      .where((item) => item.isNotEmpty)
      .toSet();

  for (final local in locales) {
    final localRfc = (local.rfc ?? '').trim().toUpperCase();
    final localNombre = local.nombreCompleto.trim().toUpperCase();
    final alreadyIncluded = ids.contains(local.id) ||
        (localRfc.isNotEmpty && rfcs.contains(localRfc)) ||
        (localNombre.isNotEmpty && nombres.contains(localNombre));
    if (!alreadyIncluded) {
      propietarios.add(local);
    }
  }

  if (busqueda.trim().isNotEmpty) {
    final q = busqueda.trim().toLowerCase();
    propietarios = propietarios.where((p) {
      return p.nombre.toLowerCase().contains(q) ||
          p.apellidos.toLowerCase().contains(q) ||
          p.nombreCompleto.toLowerCase().contains(q) ||
          (p.rfc?.toLowerCase().contains(q) ?? false) ||
          (p.curp?.toLowerCase().contains(q) ?? false) ||
          (p.razonSocial?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  if (proyecto == null) return propietarios;

  final predios = await ref.read(prediosListProvider.future);
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
  final locales = ref.watch(localPropietariosProvider);
  for (final local in locales) {
    if (local.id == id) return local;
  }

  if (!SupabaseConfig.isConfigured) {
    return null;
  }

  final repo = ref.read(propietariosRepositoryProvider);
  try {
    return repo.getPropietarioById(id);
  } catch (_) {
    return null;
  }
});

final prediosPorPropietarioProvider =
    FutureProvider.family<List<Predio>, String>((ref, propietarioId) async {
  final predios = await ref.read(prediosListProvider.future);
  return predios.where((predio) => predio.propietarioId == propietarioId).toList();
});
