import 'package:flutter/material.dart';

class PropertyNormalizationTest {
  static Map<String, dynamic> normalizeFeatureProperties(Map<String, dynamic> properties) {
    final normalized = Map<String, dynamic>.from(properties);
    normalized['estatus'] ??= 'Sin estatus';
    normalized['tipo_propiedad'] ??= 'Sin tipo';
    normalized['estado'] ??= 'Desconocido';
    normalized['municipio'] ??= 'Desconocido';
    normalized['ejido'] ??= 'No especificado';
    return normalized;
  }

  static Color polygonColor(Map<String, dynamic> properties) {
    final estatus = properties['estatus']?.toString() ?? 'Sin estatus';
    final tipoPropiedad = properties['tipo_propiedad']?.toString() ?? 'Sin tipo';

    if (estatus == 'Liberado') {
      return Colors.green;
    } else if (estatus == 'No liberado') {
      return Colors.red;
    } else {
      return Colors.blue; // Default color for other types
    }
  }
}