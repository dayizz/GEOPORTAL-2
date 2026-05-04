import 'dart:convert';
import 'package:http/http.dart' as http;

class BackendService {
  static const String _baseUrl = 'http://127.0.0.1:8000';

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
