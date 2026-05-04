import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = 'http://localhost:8000'; // Cambia para producción

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
