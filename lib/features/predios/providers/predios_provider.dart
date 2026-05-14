import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/predios_repository.dart';
import '../models/predio.dart';
import 'local_predios_provider.dart';
import '../../auth/providers/auth_provider.dart';

// Filtros activos
class PrediosFiltros {
  final String busqueda;
  final String? usoSuelo;
  final String? zona;
  final String? segmento;
  final String? propietarioId;
  final String? proyecto; // TQI, TSNL, TAP, TQM, etc.

  const PrediosFiltros({
    this.busqueda = '',
    this.usoSuelo,
    this.zona,
    this.segmento,
    this.propietarioId,
    this.proyecto,
  });

  PrediosFiltros copyWith({
    String? busqueda,
    String? usoSuelo,
    String? zona,
    String? segmento,
    String? propietarioId,
    String? proyecto,
    bool clearUsoSuelo = false,
    bool clearZona = false,
    bool clearSegmento = false,
    bool clearPropietario = false,
    bool clearProyecto = false,
  }) {
    return PrediosFiltros(
      busqueda: busqueda ?? this.busqueda,
      usoSuelo: clearUsoSuelo ? null : (usoSuelo ?? this.usoSuelo),
      zona: clearZona ? null : (zona ?? this.zona),
      segmento: clearSegmento ? null : (segmento ?? this.segmento),
      propietarioId: clearPropietario ? null : (propietarioId ?? this.propietarioId),
      proyecto: clearProyecto ? null : (proyecto ?? this.proyecto),
    );
  }
}

final prediosFiltrosProvider = StateProvider<PrediosFiltros>(
  (ref) => const PrediosFiltros(),
);

final remotePrediosProvider = FutureProvider<List<Predio>>((ref) async {
  ref.keepAlive();
  final repo = ref.read(prediosRepositoryProvider);
  try {
    return await repo.getPredios(limit: 1000);
  } catch (_) {
    return const [];
  }
});

final prediosListProvider = FutureProvider<List<Predio>>((ref) async {
  ref.keepAlive();
  final filtros = ref.watch(prediosFiltrosProvider);
  final locales = ref.watch(localPrediosProvider);
  final proyectoSesion = ref.watch(proyectoActivoProvider);
  final remotos = await ref.watch(remotePrediosProvider.future);
  final proyectoFiltro = filtros.proyecto ?? proyectoSesion;
  return _buildMergedPredios(
    remotos: remotos,
    locales: locales,
    filtros: filtros,
    proyecto: proyectoFiltro,
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
    predio.pdfUrl ?? '',
    predio.copFirmado ?? '',
  ].join(' ').toUpperCase();

  const proyectos = ['TQI', 'TSNL', 'TAP', 'TQM'];
  for (final proyecto in proyectos) {
    if (contenido.contains(proyecto)) return proyecto;
  }

  return 'Sin proyecto';
}

final prediosMapaProvider = FutureProvider<List<Predio>>((ref) async {
  ref.keepAlive();
  final remotos = await ref.watch(remotePrediosProvider.future);
  final locales = ref.watch(localPrediosProvider);
  final proyectoSesion = ref.watch(proyectoActivoProvider);
  return _buildMergedPredios(
    remotos: remotos,
    locales: locales,
    proyecto: proyectoSesion,
  );
});

final prediosMapaByIdProvider = Provider<Map<String, Predio>>((ref) {
  final prediosAsync = ref.watch(prediosMapaProvider);
  return prediosAsync.maybeWhen(
    data: (predios) => {for (final predio in predios) predio.id: predio},
    orElse: () => const {},
  );
});

final predioDetalleProvider = FutureProvider.family<Predio?, String>((ref, id) async {
  final locales = ref.watch(localPrediosProvider);
  for (final local in locales) {
    if (local.id == id) return local;
  }
  final remotos = await ref.watch(remotePrediosProvider.future);
  for (final remoto in remotos) {
    if (remoto.id == id) return remoto;
  }
  final repo = ref.read(prediosRepositoryProvider);
  try {
    return await repo.getPredioById(id);
  } catch (_) {
    return null;
  }
});

final estadisticasProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final predios = await ref.watch(prediosMapaProvider.future);
  final porUso = <String, int>{};
  var superficie = 0.0;
  for (final p in predios) {
    porUso[p.tipoPropiedad] = (porUso[p.tipoPropiedad] ?? 0) + 1;
    superficie += p.superficie ?? 0;
  }
  return {
    'total': predios.length,
    'por_uso_suelo': porUso,
    'superficie_total': superficie,
  };
});

List<Predio> _buildMergedPredios({
  required List<Predio> remotos,
  required List<Predio> locales,
  PrediosFiltros filtros = const PrediosFiltros(),
  String? proyecto,
}) {
  var remotosFiltrados = remotos.where((p) => _matchesPredioFilters(p, filtros)).toList();
  var localesFiltrados = locales.where((p) => _matchesPredioFilters(p, filtros)).toList();

  if (proyecto != null) {
    remotosFiltrados = remotosFiltrados
        .where((p) => _extractProjectoFromPredio(p) == proyecto)
        .toList();
    localesFiltrados = localesFiltrados
        .where((p) => _extractProjectoFromPredio(p) == proyecto)
        .toList();
  }

  final merged = <Predio>[...remotosFiltrados];
  final claves = remotosFiltrados.map((p) => p.claveCatastral).toSet();
  for (final local in localesFiltrados) {
    if (!claves.contains(local.claveCatastral)) {
      merged.add(local);
    }
  }
  return merged;
}

bool _matchesPredioFilters(Predio predio, PrediosFiltros filtros) {
  if (filtros.busqueda.isNotEmpty) {
    final q = filtros.busqueda.toLowerCase();
    final matchesBusqueda = predio.claveCatastral.toLowerCase().contains(q) ||
        (predio.propietarioNombre?.toLowerCase().contains(q) ?? false) ||
        (predio.ejido?.toLowerCase().contains(q) ?? false);
    if (!matchesBusqueda) return false;
  }
  if (filtros.usoSuelo != null && predio.usoSuelo != filtros.usoSuelo) {
    return false;
  }
  if (filtros.zona != null && predio.zona != filtros.zona) {
    return false;
  }
  if (filtros.segmento != null && filtros.segmento!.trim().isNotEmpty) {
    final expected = _normalizeSegmentValue(filtros.segmento!);
    final tramo = _normalizeSegmentValue(predio.tramo);
    if (!tramo.contains(expected)) {
      return false;
    }
  }
  if (filtros.propietarioId != null && predio.propietarioId != filtros.propietarioId) {
    return false;
  }
  return true;
}

String _normalizeSegmentValue(String raw) {
  var value = raw.toUpperCase().trim();
  value = value.replaceAll('SEGMENTO', 'S');
  value = value.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  return value;
}
