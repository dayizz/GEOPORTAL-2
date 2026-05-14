import 'package:flutter_test/flutter_test.dart';
import '../../lib/features/mapa/presentation/mapa_screen.dart';

void main() {
  group('Property Normalization and Color Assignment', () {
    test('Normalize properties with missing fields', () {
      final properties = {'clave': '123'};
      final normalized = _normalizeFeatureProperties(properties);

      expect(normalized['estatus'], 'Sin estatus');
      expect(normalized['tipo_propiedad'], 'Sin tipo');
      expect(normalized['estado'], 'Desconocido');
      expect(normalized['municipio'], 'Desconocido');
      expect(normalized['ejido'], 'No especificado');
    });

    test('Assign color based on estatus', () {
      final propertiesLiberado = {'estatus': 'Liberado'};
      final propertiesNoLiberado = {'estatus': 'No liberado'};
      final propertiesDefault = {'estatus': 'Otro'};

      expect(_polygonColor(propertiesLiberado), AppColors.liberadoColor);
      expect(_polygonColor(propertiesNoLiberado), AppColors.noLiberadoColor);
      expect(_polygonColor(propertiesDefault), AppColors.tipoPropiedadColor('Sin tipo'));
    });
  });
}