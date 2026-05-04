import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'google_sheets_config.dart';

final googleSheetsDbEnabledProvider = Provider<bool>(
  (ref) => GoogleSheetsConfig.enabled,
);

final googleSheetsServiceProvider = Provider<GoogleSheetsService>(
  (ref) => GoogleSheetsService(
    webAppUrl: GoogleSheetsConfig.webAppUrl,
    scriptId: GoogleSheetsConfig.scriptId,
  ),
);

class GoogleSheetsService {
  final String webAppUrl;
  final String scriptId;
  static const int _maxFallbackGetQueryBytes = 7000;

  const GoogleSheetsService({
    required this.webAppUrl,
    required this.scriptId,
  });

  Future<List<Map<String, dynamic>>> getRows({
    required String sheet,
  }) async {
    final attempts = <Map<String, String>>[
      {'action': 'list', 'sheet': sheet},
      {'sheet': sheet},
      {},
    ];

    for (final query in attempts) {
      final payload = await _getJson(query);
      final rows = _parseRows(payload);
      if (rows.isNotEmpty) return rows;
      if (query.isEmpty) return rows;
    }

    return const [];
  }

  Future<Map<String, dynamic>> upsertRow({
    required String sheet,
    required Map<String, dynamic> row,
    String idField = 'id',
  }) async {
    dynamic payload;
    try {
      payload = await _postJson({
        'action': 'upsert',
        'sheet': sheet,
        'idField': idField,
        'row': row,
      });
    } catch (_) {
      final fallbackQuery = <String, String>{
        'action': 'upsert',
        'sheet': sheet,
        'idField': idField,
        'row': jsonEncode(row),
      };

      if (_estimateQueryBytes(fallbackQuery) > _maxFallbackGetQueryBytes) {
        throw Exception(
          'Sheets POST fallo y fallback GET excede el tamano seguro de URL. '
          'Reducir payload o habilitar POST en Apps Script.',
        );
      }

      payload = await _getJson(fallbackQuery);
    }

    if (payload is Map<String, dynamic>) {
      final rowRaw = payload['row'];
      if (rowRaw is Map) return _stringKeyMap(rowRaw);
      return payload;
    }

    return row;
  }

  Future<void> deleteById({
    required String sheet,
    required String id,
    String idField = 'id',
  }) async {
    try {
      await _postJson({
        'action': 'delete',
        'sheet': sheet,
        'idField': idField,
        'id': id,
      });
    } catch (_) {
      await _getJson({
        'action': 'delete',
        'sheet': sheet,
        'idField': idField,
        'id': id,
      });
    }
  }

  Future<dynamic> _getJson(Map<String, String> query) async {
    final params = <String, String>{...query};
    if (scriptId.trim().isNotEmpty) {
      params['scriptId'] = scriptId;
    }

    final uri = Uri.parse(webAppUrl).replace(
      queryParameters: params.isEmpty ? null : params,
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Sheets GET fallo (${response.statusCode}).');
    }
    return _decodeBody(response.body);
  }

  Future<dynamic> _postJson(Map<String, dynamic> body) async {
    final payload = <String, dynamic>{
      ...body,
      if (scriptId.trim().isNotEmpty) 'scriptId': scriptId,
    };

    final response = await http
        .post(
          Uri.parse(webAppUrl),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Sheets POST fallo (${response.statusCode}).');
    }

    final bodyTrimmed = response.body.trimLeft();
    // Algunos deployments redirigen a una pagina HTML de Drive para POST.
    // En ese caso forzamos fallback por GET en el caller.
    if (bodyTrimmed.startsWith('<!DOCTYPE html') ||
        bodyTrimmed.startsWith('<html')) {
      throw Exception('Sheets POST devolvio HTML en lugar de JSON.');
    }

    return _decodeBody(response.body);
  }

  dynamic _decodeBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return const [];
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return const [];
    }
  }

  List<Map<String, dynamic>> _parseRows(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final data = payload['data'] ?? payload['rows'] ?? payload['items'];
      return _parseRows(data);
    }

    if (payload is List) {
      if (payload.isEmpty) return const [];

      if (payload.first is Map) {
        return payload
            .whereType<Map>()
            .map(_stringKeyMap)
            .toList(growable: false);
      }

      if (payload.first is List) {
        final matrix = payload.whereType<List>().toList(growable: false);
        if (matrix.isEmpty) return const [];
        final headers = matrix.first
            .map((h) => h?.toString().trim() ?? '')
            .toList(growable: false);

        if (headers.where((h) => h.isNotEmpty).isEmpty) return const [];

        final rows = <Map<String, dynamic>>[];
        for (var i = 1; i < matrix.length; i++) {
          final row = matrix[i];
          final item = <String, dynamic>{};
          for (var c = 0; c < headers.length; c++) {
            final header = headers[c];
            if (header.isEmpty) continue;
            item[header] = c < row.length ? row[c] : null;
          }
          final hasAnyValue = item.values
              .any((v) => v != null && v.toString().trim().isNotEmpty);
          if (hasAnyValue) rows.add(item);
        }
        return rows;
      }
    }

    return const [];
  }

  Map<String, dynamic> _stringKeyMap(Map raw) {
    final out = <String, dynamic>{};
    for (final entry in raw.entries) {
      out[entry.key.toString()] = entry.value;
    }
    return out;
  }

  int _estimateQueryBytes(Map<String, String> query) {
    final params = <String, String>{...query};
    if (scriptId.trim().isNotEmpty) {
      params['scriptId'] = scriptId;
    }

    final uri = Uri.parse(webAppUrl).replace(
      queryParameters: params.isEmpty ? null : params,
    );

    return utf8.encode(uri.toString()).length;
  }
}