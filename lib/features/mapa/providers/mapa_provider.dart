import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MapaBaseLayer {
	estandar,
	satelital,
}

enum MapaColorMode {
	estatusPredio,
	tipoPropiedad,
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
