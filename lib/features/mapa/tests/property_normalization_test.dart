import 'package:flutter_test/flutter_test.dart';
import '../presentation/mapa_screen.dart';
import '../../../core/constants/app_colors.dart';

void main() {
  group('Property Normalization and Color Assignment', () {
    test('Normalize properties with missing fields', () {
      final properties = {'clave': '123'};
      final normalized = normalizeFeatureProperties(properties); // Ensure function is accessible

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

      expect(polygonColor(propertiesLiberado), AppColors.liberadoColor); // Ensure function and constant are accessible
      expect(polygonColor(propertiesNoLiberado), AppColors.noLiberadoColor);
      expect(polygonColor(propertiesDefault), AppColors.tipoPropiedadColor('Sin tipo'));
    });

    test('Detect estatus with non-standard key format', () {
      final properties = {
        '  Estatus Predio  ': 'no liberado',
        'CLAVE': 'A-001',
      };

      final normalized = normalizeFeatureProperties(properties);

      expect(normalized['estatus'], 'No liberado');
      expect(polygonColor(normalized), AppColors.noLiberadoColor);
    });
  });
}