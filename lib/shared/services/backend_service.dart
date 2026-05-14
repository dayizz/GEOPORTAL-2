import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/config/backend_config.dart';

class BackendService {
  static String get _baseUrl => BackendConfig.baseUrl;

  static Future<int?> procesarValor(int valor) async {
    final url = Uri.parse('$_baseUrl/procesar');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'valor': valor}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['resultado'] as int?;
    }
    return null;
  }
}
