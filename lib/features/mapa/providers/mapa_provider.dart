import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MapaBaseLayer {
	estandar,
	satelital,
}

enum MapaColorMode {
	estatusPredio,
	tipoPropiedad,
}

/// Estado del proceso de importación / sincronización GeoJSON.
/// Permite bloquear la UI mientras los predios se están guardando en la BD.
enum ImportacionEstado { idle, procesando, completado, error }

class ImportacionProgreso {
	final int procesados;
	final int total;
	final String? etapa;

	const ImportacionProgreso({
		required this.procesados,
		required this.total,
		this.etapa,
	});

	double get porcentaje {
		if (total <= 0) return 0;
		final ratio = procesados / total;
		if (ratio < 0) return 0;
		if (ratio > 1) return 1;
		return ratio;
	}
}

class ImportacionUiState {
	final ImportacionEstado estado;
	final ImportacionProgreso progreso;
	final String? error;

	const ImportacionUiState({
		required this.estado,
		required this.progreso,
		this.error,
	});

	const ImportacionUiState.idle()
		: estado = ImportacionEstado.idle,
			progreso = const ImportacionProgreso(procesados: 0, total: 0),
			error = null;

	ImportacionUiState copyWith({
		ImportacionEstado? estado,
		ImportacionProgreso? progreso,
		String? error,
		bool clearError = false,
	}) {
		return ImportacionUiState(
			estado: estado ?? this.estado,
			progreso: progreso ?? this.progreso,
			error: clearError ? null : (error ?? this.error),
		);
	}
}

class ImportacionAsyncNotifier extends AsyncNotifier<ImportacionUiState> {
	Timer? _autoResetTimer;
	Timer? _processingWatchdog;

	static const Duration _autoResetDelay = Duration(seconds: 5);
	static const Duration _processingWatchdogDelay = Duration(seconds: 45);

	void _cancelTimers() {
		_autoResetTimer?.cancel();
		_autoResetTimer = null;
		_processingWatchdog?.cancel();
		_processingWatchdog = null;
	}

	void _armProcessingWatchdog() {
		_processingWatchdog?.cancel();
		_processingWatchdog = Timer(_processingWatchdogDelay, () {
			final current = state.valueOrNull;
			if (current?.estado == ImportacionEstado.procesando) {
				reset();
			}
		});
	}

	void _scheduleAutoReset() {
		_autoResetTimer?.cancel();
		_autoResetTimer = Timer(_autoResetDelay, () {
			final current = state.valueOrNull;
			if (current == null) return;
			if (current.estado == ImportacionEstado.completado ||
					current.estado == ImportacionEstado.error) {
				reset();
			}
		});
	}

	@override
	Future<ImportacionUiState> build() async {
		ref.onDispose(_cancelTimers);
		return const ImportacionUiState.idle();
	}

	void iniciar({required int total, String etapa = 'Sincronizando'}) {
		_autoResetTimer?.cancel();
		_armProcessingWatchdog();
		state = AsyncData(
			ImportacionUiState(
				estado: ImportacionEstado.procesando,
				progreso: ImportacionProgreso(
					procesados: 0,
					total: total,
					etapa: etapa,
				),
			),
		);
	}

	void actualizar({
		required int procesados,
		required int total,
		String etapa = 'Sincronizando',
	}) {
		_autoResetTimer?.cancel();
		_armProcessingWatchdog();
		final current = state.valueOrNull ?? const ImportacionUiState.idle();
		state = AsyncData(
			current.copyWith(
				estado: ImportacionEstado.procesando,
				progreso: ImportacionProgreso(
					procesados: procesados,
					total: total,
					etapa: etapa,
				),
				clearError: true,
			),
		);
	}

	void completar({required int total, String etapa = 'Completado'}) {
		_processingWatchdog?.cancel();
		final current = state.valueOrNull ?? const ImportacionUiState.idle();
		state = AsyncData(
			current.copyWith(
				estado: ImportacionEstado.completado,
				progreso: ImportacionProgreso(
					procesados: total,
					total: total,
					etapa: etapa,
				),
				clearError: true,
			),
		);
		_scheduleAutoReset();
	}

	void fallar({
		required int procesados,
		required int total,
		String etapa = 'Error',
		String? mensaje,
	}) {
		_processingWatchdog?.cancel();
		final current = state.valueOrNull ?? const ImportacionUiState.idle();
		state = AsyncData(
			current.copyWith(
				estado: ImportacionEstado.error,
				progreso: ImportacionProgreso(
					procesados: procesados,
					total: total,
					etapa: etapa,
				),
				error: mensaje,
			),
		);
		_scheduleAutoReset();
	}

	void reset() {
		_cancelTimers();
		state = const AsyncData(ImportacionUiState.idle());
	}
}

final mapaBaseLayerProvider = StateProvider<MapaBaseLayer>(
	(ref) => MapaBaseLayer.estandar,
);

final mapaColorModeProvider = StateProvider<MapaColorMode>(
	(ref) => MapaColorMode.estatusPredio,
);

/// Features GeoJSON importados desde archivo — se renderizan directamente en el mapa
/// sin necesidad de guardar a la base de datos primero.
final importedFeaturesProvider = StateProvider<List<Map<String, dynamic>>>(
	(ref) => const [],
);

/// ID del predio que debe ser enfocado en el mapa (desde Gestión o Propietarios).
/// El mapa limpia este valor después de hacer el fly-to.
final focusPredioIdProvider = StateProvider<String?>((ref) => null);

/// ID del predio seleccionado en Gestión para iniciar el flujo de
/// vinculación manual en el mapa.
final manualVincularPredioIdProvider = StateProvider<String?>((ref) => null);

/// Proyecto que debe ser seleccionado automáticamente en Gestión
/// (se establece después de importar un GeoJSON para llevar al usuario
/// directo al proyecto correcto). Gestión lo consume y lo limpia.
final gestionProyectoProvider = StateProvider<String?>((ref) => null);

final importacionAsyncProvider =
	AsyncNotifierProvider<ImportacionAsyncNotifier, ImportacionUiState>(
		ImportacionAsyncNotifier.new,
	);

final importacionEstadoProvider = Provider<ImportacionEstado>((ref) {
	final asyncState = ref.watch(importacionAsyncProvider);
	return asyncState.maybeWhen(
		data: (s) => s.estado,
		orElse: () => ImportacionEstado.idle,
	);
});

final importacionProgresoProvider = Provider<ImportacionProgreso>((ref) {
	final asyncState = ref.watch(importacionAsyncProvider);
	return asyncState.maybeWhen(
		data: (s) => s.progreso,
		orElse: () => const ImportacionProgreso(procesados: 0, total: 0),
	);
});
