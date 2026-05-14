import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/backend_config.dart';

class ApiClient {
  static String get baseUrl => BackendConfig.baseUrl;

  Future<Map<String, dynamic>> importGeoJsonToGis({
    required List<Map<String, dynamic>> features,
    String? archivoId,
    String? proyecto,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/gis/import-geojson'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (archivoId != null && archivoId.isNotEmpty) 'archivo_id': archivoId,
        if (proyecto != null && proyecto.isNotEmpty) 'proyecto': proyecto,
        'features': features,
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Error al importar GeoJSON al servidor GIS');
  }

  Future<List<Map<String, dynamic>>> getGestionEstatusBatch({
    List<String> predioIds = const [],
    List<String> clavesCatastrales = const [],
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/gestion/estatus/batch'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'predio_ids': predioIds,
        'claves_catastrales': clavesCatastrales,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = data['items'];
      if (items is List) {
        return items
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }
      return const [];
    }
    throw Exception('Error al consultar estatus de gestion en batch');
  }

  Future<List<Map<String, dynamic>>> getGestionEstatusViewport({
    required double west,
    required double south,
    required double east,
    required double north,
    String? proyecto,
    int? limit,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/gestion/estatus/viewport'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'bbox': {
          'west': west,
          'south': south,
          'east': east,
          'north': north,
        },
        if (proyecto != null && proyecto.isNotEmpty) 'proyecto': proyecto,
        if (limit != null && limit > 0) 'limit': limit,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = data['items'];
      if (items is List) {
        return items
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }
      return const [];
    }
    throw Exception('Error al consultar estatus por viewport');
  }

  Future<List<dynamic>> getPredios({String? proyecto, String? claveCatastral}) async {
    final uri = Uri.parse('$baseUrl/predios').replace(
      queryParameters: {
        if (proyecto != null && proyecto.isNotEmpty) 'proyecto': proyecto,
        if (claveCatastral != null && claveCatastral.isNotEmpty)
          'clave_catastral': claveCatastral,
      },
    );
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    } else {
      throw Exception('Error al obtener predios');
    }
  }

  Future<Map<String, dynamic>> getPredio(String id) async {
    final response = await http.get(Uri.parse('$baseUrl/predios/$id'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Error al obtener predio');
    }
  }

  Future<Map<String, dynamic>?> getPredioByClaveCatastral(String clave) async {
    final response = await http.get(
      Uri.parse('$baseUrl/predios/by-clave/${Uri.encodeComponent(clave)}'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    if (response.statusCode == 404) {
      return null;
    }
    throw Exception('Error al buscar predio por clave catastral');
  }

  Future<Map<String, dynamic>> createPredio(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/predios'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Error al crear predio');
    }
  }

  /// Inserta múltiples predios en una sola llamada atómica (evita race conditions).
  Future<List<Map<String, dynamic>>> createPrediosBatch(
    List<Map<String, dynamic>> items,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/predios/batch'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(items),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return (jsonDecode(response.body) as List)
          .cast<Map<String, dynamic>>();
    } else {
      throw Exception('Error al crear predios en batch');
    }
  }

  Future<Map<String, dynamic>> updatePredio(String id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/predios/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Error al actualizar predio');
    }
  }

  Future<void> deletePredio(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/predios/$id'));
    if (response.statusCode != 200) {
      throw Exception('Error al eliminar predio');
    }
  }

  Future<Map<String, dynamic>> getEstadisticas() async {
    final response = await http.get(Uri.parse('$baseUrl/predios/estadisticas'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Error al obtener estadisticas');
  }
}
