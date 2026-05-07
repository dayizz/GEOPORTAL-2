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
  ref.keepAlive();
  final filtros = ref.watch(prediosFiltrosProvider);
  final locales = ref.watch(localPrediosProvider);
  // Filtro por proyecto de sesión (null = admin, ve todos)
  final proyectoSesion = ref.watch(proyectoActivoProvider);
  final repo = ref.read(prediosRepositoryProvider);
  List<Predio> remotos = const [];
  try {
    remotos = await repo.getPredios(
      busqueda: filtros.busqueda,
      usoSuelo: filtros.usoSuelo,
      zona: filtros.zona,
      propietarioId: filtros.propietarioId,
      limit: 1000,
    );
  } catch (_) {
    remotos = const [];
  }

  var localesFiltrados = locales.where((p) {
    if (filtros.busqueda.isNotEmpty) {
      final q = filtros.busqueda.toLowerCase();
      final matchesBusqueda = p.claveCatastral.toLowerCase().contains(q) ||
          (p.propietarioNombre?.toLowerCase().contains(q) ?? false) ||
          (p.ejido?.toLowerCase().contains(q) ?? false);
      if (!matchesBusqueda) return false;
    }
    if (filtros.usoSuelo != null && p.usoSuelo != filtros.usoSuelo) {
      return false;
    }
    if (filtros.zona != null && p.zona != filtros.zona) {
      return false;
    }
    if (filtros.propietarioId != null && p.propietarioId != filtros.propietarioId) {
      return false;
    }
    return true;
  }).toList();

  // Aplicar filtro de proyecto desde filtros UI
  final proyectoFiltro = filtros.proyecto ?? proyectoSesion;
  if (proyectoFiltro != null) {
    remotos = remotos
        .where((p) => _extractProjectoFromPredio(p) == proyectoFiltro)
        .toList();
    localesFiltrados = localesFiltrados
        .where((p) => _extractProjectoFromPredio(p) == proyectoFiltro)
        .toList();
  }

  final merged = <Predio>[...remotos];
  final claves = remotos.map((p) => p.claveCatastral).toSet();
  for (final local in localesFiltrados) {
    if (!claves.contains(local.claveCatastral)) {
      merged.add(local);
    }
  }
  return merged;
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
  final locales = ref.watch(localPrediosProvider);
  final proyectoSesion = ref.watch(proyectoActivoProvider);
  final repo = ref.read(prediosRepositoryProvider);
  List<Predio> remotos = const [];
  try {
    remotos = await repo.getPredios(limit: 200);
  } catch (_) {
    remotos = const [];
  }
  var localesFiltrados = locales.toList();
  if (proyectoSesion != null) {
    remotos = remotos.where((p) => _extractProjectoFromPredio(p) == proyectoSesion).toList();
    localesFiltrados = localesFiltrados.where((p) => _extractProjectoFromPredio(p) == proyectoSesion).toList();
  }
  final merged = <Predio>[...remotos];
  final claves = remotos.map((p) => p.claveCatastral).toSet();
  for (final local in localesFiltrados) {
    if (!claves.contains(local.claveCatastral)) {
      merged.add(local);
    }
  }
  return merged;
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
  final repo = ref.read(prediosRepositoryProvider);
  try {
    return await repo.getPredioById(id);
  } catch (_) {
    return null;
  }
});

final estadisticasProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final locales = ref.watch(localPrediosProvider);
  final repo = ref.read(prediosRepositoryProvider);
  try {
    final remotas = await repo.getEstadisticas();
    final totalRemoto = (remotas['total'] as int?) ?? 0;
    final total = totalRemoto + locales.length;
    final superficieLocal = locales.fold<double>(
      0,
      (sum, p) => sum + (p.superficie ?? 0),
    );
    return {
      ...remotas,
      'total': total,
      'superficie_total': ((remotas['superficie_total'] as num?)?.toDouble() ?? 0) + superficieLocal,
    };
  } catch (_) {
    final porUso = <String, int>{};
    var superficie = 0.0;
    for (final p in locales) {
      porUso[p.tipoPropiedad] = (porUso[p.tipoPropiedad] ?? 0) + 1;
      superficie += p.superficie ?? 0;
    }
    return {
      'total': locales.length,
      'por_uso_suelo': porUso,
      'superficie_total': superficie,
    };
  }
});
