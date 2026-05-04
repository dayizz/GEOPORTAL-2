import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/importacion_repository.dart';

final xlsxImportServiceProvider = Provider<XlsxImportService>((ref) {
  return XlsxImportService(ref.read(importacionRepositoryProvider));
});

enum XlsxTargetTable {
  predios,
  propietarios,
}

class XlsxSheetImport {
  final String hoja;
  final XlsxTargetTable tabla;
  final List<Map<String, dynamic>> rows;

  const XlsxSheetImport({
    required this.hoja,
    required this.tabla,
    required this.rows,
  });
}

class XlsxParseResult {
  final List<XlsxSheetImport> hojas;
  final List<Map<String, dynamic>> preview;
  final int totalRows;

  const XlsxParseResult({
    required this.hojas,
    required this.preview,
    required this.totalRows,
  });
}

class XlsxImportResult {
  final int procesados;
  final int creados;
  final int actualizados;
  final int errores;
  final List<String> mensajes;

  const XlsxImportResult({
    required this.procesados,
    required this.creados,
    required this.actualizados,
    required this.errores,
    this.mensajes = const [],
  });
}

class _HeaderDetection {
  final int headerRowIndex;
  final List<String> headers;
  final XlsxTargetTable tabla;
  final int score;

  const _HeaderDetection({
    required this.headerRowIndex,
    required this.headers,
    required this.tabla,
    required this.score,
  });
}

class XlsxImportService {
  static const int _batchSize = 40;
  final ImportacionRepository? _importacionRepository;

  XlsxImportService([this._importacionRepository]);

  Future<XlsxParseResult> parseInBackground(Uint8List bytes) async {
    final payload = await compute(_parseXlsxPayload, bytes);
    final rawHojas = payload['hojas'] as List? ?? const [];
    final rawPreview = payload['preview'] as List? ?? const [];

    final hojas = rawHojas.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final rawRows = map['rows'] as List? ?? const [];
      return XlsxSheetImport(
        hoja: map['hoja'] as String,
        tabla: map['tabla'] == 'predios'
            ? XlsxTargetTable.predios
            : XlsxTargetTable.propietarios,
        rows: rawRows
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false),
      );
    }).toList(growable: false);

    return XlsxParseResult(
      hojas: hojas,
      preview: rawPreview
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false),
      totalRows: (payload['totalRows'] as num?)?.toInt() ?? 0,
    );
  }

  static const Map<String, List<String>> _prediosAliases = {
    'clave_catastral': [
      'clave_catastral',
      'clave',
      'id_catastral',
      'id_sedatu',
      'idsedatu',
      'id_predio',
      'folio',
      'cvegeo',
      'num_predio',
      'no_predio',
      'clave_predio',
      'clave_registro',
    ],
    'tramo': [
      'tramo',
      'zona',
      'segmento',
      'sector',
      'modulo',
      'tramo_vial',
    ],
    'tipo_propiedad': [
      'tipo_propiedad',
      'tipo',
      'uso_suelo',
      'uso',
      'regimen',
      'tipo_tenencia',
      'tenencia',
    ],
    'ejido': ['ejido', 'comunidad', 'localidad', 'municipio'],
    'km_inicio': [
      'km_inicio',
      'km_inicial',
      'cadenamiento_inicial',
      'cad_ini',
      'km_i',
      'cadenamiento_inicio',
      'inicio',
    ],
    'km_fin': [
      'km_fin',
      'km_final',
      'cadenamiento_final',
      'cad_fin',
      'km_f',
      'cadenamiento_fin',
      'fin',
    ],
    'km_lineales': ['km_lineales', 'longitud_lineal', 'frente'],
    'km_efectivos': ['km_efectivos', 'longitud_efectiva'],
    'superficie': [
      'superficie',
      'area',
      'area_m2',
      'shape_area',
      'sup',
      'superficie_m2',
      'sup_m2',
      'm2',
      'hectareas',
      'ha',
    ],
    'proyecto': [
      'proyecto',
      'obra',
      'nombre_proyecto',
      'proyecto_nombre',
      'proyecto_vial',
    ],
    'propietario_nombre': [
      'propietario',
      'propietario_nombre',
      'nombre_propietario',
      'titular',
      'nombre_titular',
      'titular_derecho',
      'dueno',
      'nombre',
      'razon_social',
      'beneficiario',
    ],
    'rfc_propietario': [
      'rfc_propietario',
      'rfc',
      'rfc_titular',
    ],
    'curp_propietario': [
      'curp_propietario',
      'curp',
      'curp_titular',
    ],
    'telefono_propietario': [
      'telefono_propietario',
      'telefono',
      'celular',
      'tel',
      'tel_propietario',
    ],
    'correo_propietario': [
      'correo_propietario',
      'correo',
      'email',
      'correo_electronico',
    ],
    'cop': [
      'cop',
      'liberado',
      'libre',
      'convenio',
      'cop_firmado',
      'status',
      'estatus',
    ],
    'identificacion': ['identificacion', 'identificado', 'id_realizada'],
    'levantamiento': ['levantamiento', 'levantado', 'lev'],
    'negociacion': ['negociacion', 'negociado', 'neg'],
    'poligono_insertado': [
      'poligono_insertado',
      'poligono',
      'polig',
      'geometria',
    ],
    'latitud': ['latitud', 'lat', 'y', 'coordy'],
    'longitud': ['longitud', 'lon', 'lng', 'x', 'coordx'],
  };

  static const Map<String, List<String>> _propietariosAliases = {
    'nombre': ['nombre'],
    'apellidos': ['apellidos'],
    'nombre_completo': ['nombre_completo', 'propietario', 'titular'],
    'tipo_persona': ['tipo_persona'],
    'razon_social': ['razon_social'],
    'curp': ['curp'],
    'rfc': ['rfc'],
    'telefono': ['telefono', 'celular'],
    'correo': ['correo', 'email'],
  };

  XlsxParseResult parse(Uint8List bytes) {
    final workbook = Excel.decodeBytes(bytes);
    final imports = <XlsxSheetImport>[];
    final preview = <Map<String, dynamic>>[];
    var totalRows = 0;

    for (final hoja in workbook.tables.keys) {
      final table = workbook.tables[hoja];
      if (table == null || table.rows.length < 2) {
        continue;
      }

      final headerInfo = _detectarHeaderYTabla(table.rows);
      if (headerInfo == null) {
        continue;
      }

      final headers = headerInfo.headers;
      final target = headerInfo.tabla;

      final proyectoDeHoja = _inferirProyectoDeHoja(hoja);

      final rows = <Map<String, dynamic>>[];
      for (final row in table.rows.skip(headerInfo.headerRowIndex + 1)) {
        final rowMap = <String, String>{};
        for (var i = 0; i < headers.length; i++) {
          if (i >= row.length) continue;
          final key = headers[i];
          if (key.isEmpty) continue;
          final val = _cellToText(row[i]).trim();
          if (val.isNotEmpty) {
            rowMap[key] = val;
          }
        }
        if (rowMap.isEmpty) continue;

        var normalizedRow = target == XlsxTargetTable.predios
            ? _normalizarFilaPredio(rowMap)
            : _normalizarFilaPropietario(rowMap);
        if (normalizedRow.isEmpty) continue;

        // Inyectar proyecto inferido del nombre de hoja si la fila no lo tiene
        if (target == XlsxTargetTable.predios &&
            proyectoDeHoja != null &&
            (normalizedRow['proyecto'] == null ||
                (normalizedRow['proyecto'] as String).isEmpty)) {
          normalizedRow = {...normalizedRow, 'proyecto': proyectoDeHoja};
        }

        rows.add(normalizedRow);
      }

      if (rows.isEmpty) continue;

      totalRows += rows.length;
      imports.add(XlsxSheetImport(hoja: hoja, tabla: target, rows: rows));

      for (final row in rows.take(3)) {
        preview.add({
          'hoja': hoja,
          'tabla': target == XlsxTargetTable.predios ? 'predios' : 'propietarios',
          ...row,
        });
      }
    }

    if (imports.isEmpty) {
      throw const FormatException(
        'El XLSX no contiene filas detectables para predios o propietarios. '
        'Verifica que incluya encabezados como clave_catastral, tramo, propietario, nombre o rfc.',
      );
    }

    return XlsxParseResult(hojas: imports, preview: preview, totalRows: totalRows);
  }

  _HeaderDetection? _detectarHeaderYTabla(List<List<dynamic>> allRows) {
    final maxRowsToScan = allRows.length < 10 ? allRows.length : 10;

    _HeaderDetection? best;

    for (var rowIndex = 0; rowIndex < maxRowsToScan; rowIndex++) {
      final rawHeaders = allRows[rowIndex].map(_cellToText).toList(growable: false);
      final headers = rawHeaders.map(_normalize).toList(growable: false);

      final hasAtLeastOneHeader = headers.any((h) => h.isNotEmpty);
      if (!hasAtLeastOneHeader) continue;

      final prediosScore = _score(headers, _prediosAliases);
      final propietariosScore = _score(headers, _propietariosAliases);
      final totalScore = prediosScore > propietariosScore ? prediosScore : propietariosScore;
      if (totalScore == 0) continue;

      final tabla = prediosScore >= propietariosScore
          ? XlsxTargetTable.predios
          : XlsxTargetTable.propietarios;

      final current = _HeaderDetection(
        headerRowIndex: rowIndex,
        headers: headers,
        tabla: tabla,
        score: totalScore,
      );

      if (best == null || current.score > best.score) {
        best = current;
      }
    }

    // Fallback: si no encuentra encabezado claro, intentar con la primera fila no vacía como predios.
    if (best == null) {
      for (var rowIndex = 0; rowIndex < maxRowsToScan; rowIndex++) {
        final rawHeaders = allRows[rowIndex].map(_cellToText).toList(growable: false);
        final headers = rawHeaders.map(_normalize).toList(growable: false);
        if (headers.any((h) => h.isNotEmpty)) {
          return _HeaderDetection(
            headerRowIndex: rowIndex,
            headers: headers,
            tabla: XlsxTargetTable.predios,
            score: 0,
          );
        }
      }
    }

    return best;
  }

  Future<XlsxImportResult> importar(XlsxParseResult parseResult) async {
    final repo = _importacionRepository;
    if (repo == null) {
      throw StateError(
        'XlsxImportService.importar requiere un ImportacionRepository configurado.',
      );
    }

    var procesados = 0;
    var creados = 0;
    var actualizados = 0;
    var errores = 0;
    final mensajes = <String>[];

    for (final hoja in parseResult.hojas) {
      for (final batch in _chunkRows(hoja.rows, _batchSize)) {
        final batchResults = await Future.wait(
          batch.map((row) => _importarFila(hoja: hoja, row: row)),
        );

        for (final result in batchResults) {
          procesados += 1;
          creados += result.creados;
          actualizados += result.actualizados;
          errores += result.errores;
          if (result.mensaje != null && mensajes.length < 8) {
            mensajes.add(result.mensaje!);
          }
        }
      }
    }

    return XlsxImportResult(
      procesados: procesados,
      creados: creados,
      actualizados: actualizados,
      errores: errores,
      mensajes: mensajes,
    );
  }

  Future<_ImportRowResult> _importarFila({
    required XlsxSheetImport hoja,
    required Map<String, dynamic> row,
  }) async {
    final repo = _importacionRepository;
    if (repo == null) {
      return _ImportRowResult.error(
        'Servicio de importacion no configurado para escritura.',
      );
    }

    try {
      if (hoja.tabla == XlsxTargetTable.predios) {
        final clave = row['clave_catastral']?.toString().trim() ?? '';
        if (clave.isEmpty) {
          return _ImportRowResult.error(
            'Hoja ${hoja.hoja}: fila sin clave_catastral.',
          );
        }

        final result = await repo.upsertPredioConPropietario(row);
        return _ImportRowResult(
          creados: result.creado ? 1 : 0,
          actualizados: result.actualizado ? 1 : 0,
          errores: 0,
        );
      }

      final result = await repo.upsertPropietario(row);
      return _ImportRowResult(
        creados: result.creado ? 1 : 0,
        actualizados: result.actualizado ? 1 : 0,
        errores: 0,
      );
    } catch (e) {
      return _ImportRowResult.error('Hoja ${hoja.hoja}: $e');
    }
  }

  Iterable<List<Map<String, dynamic>>> _chunkRows(
    List<Map<String, dynamic>> rows,
    int size,
  ) sync* {
    if (rows.isEmpty) return;
    for (var i = 0; i < rows.length; i += size) {
      final end = (i + size) > rows.length ? rows.length : i + size;
      yield rows.sublist(i, end);
    }
  }

  int _score(List<String> headers, Map<String, List<String>> aliases) {
    var score = 0;
    for (final al in aliases.values) {
      if (headers.any(al.contains)) {
        score++;
      }
    }
    return score;
  }

  Map<String, dynamic> _normalizarFilaPredio(Map<String, String> row) {
    final out = <String, dynamic>{};

    String? pick(List<String> aliases) {
      for (final a in aliases) {
        final value = row[_normalize(a)]?.trim();
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }
      return null;
    }

    double? pickDouble(List<String> aliases) {
      final raw = pick(aliases);
      if (raw == null) return null;
      return double.tryParse(raw.replaceAll(',', '').trim());
    }

    bool? pickBool(List<String> aliases) {
      final raw = pick(aliases);
      if (raw == null) return null;
      final v = _normalize(raw);
      if (v == '1' || v == 'true' || v == 'si' || v == 'sí' || v == 'yes') {
        return true;
      }
      if (v == '0' || v == 'false' || v == 'no') {
        return false;
      }
      return null;
    }

    final clave = pick(_prediosAliases['clave_catastral']!);
    if (clave != null) out['clave_catastral'] = _normalizeUpperCode(clave);

    final tramo = pick(_prediosAliases['tramo']!);
    if (tramo != null) out['tramo'] = _normalizeUpperCode(tramo);

    final tipo = pick(_prediosAliases['tipo_propiedad']!);
    if (tipo != null) out['tipo_propiedad'] = _normalizeTipoPropiedadValue(tipo);

    final ejido = pick(_prediosAliases['ejido']!);
    if (ejido != null) out['ejido'] = _normalizePlainText(ejido);

    final proyecto = pick(_prediosAliases['proyecto']!);
    if (proyecto != null) out['proyecto'] = _normalizeProyectoValue(proyecto);

    final propietarioNombre = pick(_prediosAliases['propietario_nombre']!);
    if (propietarioNombre != null) out['propietario_nombre'] = _normalizePlainText(propietarioNombre);

    final kmInicio = pickDouble(_prediosAliases['km_inicio']!);
    if (kmInicio != null) out['km_inicio'] = kmInicio;

    final kmFin = pickDouble(_prediosAliases['km_fin']!);
    if (kmFin != null) out['km_fin'] = kmFin;

    final kmLineales = pickDouble(_prediosAliases['km_lineales']!);
    if (kmLineales != null) out['km_lineales'] = kmLineales;

    final kmEfectivos = pickDouble(_prediosAliases['km_efectivos']!);
    if (kmEfectivos != null) out['km_efectivos'] = kmEfectivos;

    final superficie = pickDouble(_prediosAliases['superficie']!);
    if (superficie != null) out['superficie'] = superficie;

    final lat = pickDouble(_prediosAliases['latitud']!);
    if (lat != null) out['latitud'] = lat;

    final lng = pickDouble(_prediosAliases['longitud']!);
    if (lng != null) out['longitud'] = lng;

    final cop = pickBool(_prediosAliases['cop']!);
    if (cop != null) out['cop'] = cop;

    final identificacion = pickBool(_prediosAliases['identificacion']!);
    if (identificacion != null) out['identificacion'] = identificacion;

    final levantamiento = pickBool(_prediosAliases['levantamiento']!);
    if (levantamiento != null) out['levantamiento'] = levantamiento;

    final negociacion = pickBool(_prediosAliases['negociacion']!);
    if (negociacion != null) out['negociacion'] = negociacion;

    final poligonoInsertado = pickBool(_prediosAliases['poligono_insertado']!);
    if (poligonoInsertado != null) out['poligono_insertado'] = poligonoInsertado;

    final rfcProp = pick(_prediosAliases['rfc_propietario']!);
    if (rfcProp != null) out['rfc_propietario'] = _normalizeUpperCode(rfcProp);

    final curpProp = pick(_prediosAliases['curp_propietario']!);
    if (curpProp != null) out['curp_propietario'] = _normalizeUpperCode(curpProp);

    final telProp = pick(_prediosAliases['telefono_propietario']!);
    if (telProp != null) out['telefono_propietario'] = _normalizePlainText(telProp);

    final correoProp = pick(_prediosAliases['correo_propietario']!);
    if (correoProp != null) out['correo_propietario'] = _normalizeEmail(correoProp);

    return out;
  }

  Map<String, dynamic> _normalizarFilaPropietario(Map<String, String> row) {
    final out = <String, dynamic>{};

    String? pick(List<String> aliases) {
      for (final a in aliases) {
        final value = row[_normalize(a)]?.trim();
        if (value != null && value.isNotEmpty) {
          return value;
        }
      }
      return null;
    }

    for (final entry in _propietariosAliases.entries) {
      final value = pick(entry.value);
      if (value != null) {
        out[entry.key] = _normalizePropietarioField(entry.key, value);
      }
    }

    if (!out.containsKey('nombre') && out['nombre_completo'] == null) {
      return {};
    }

    return out;
  }

  // ── Extraer texto de una celda de excel 4.x (CellValue typed) ─────────────
  String _cellToText(dynamic cell) {
    if (cell == null) return '';
    final v = (cell as dynamic).value;
    if (v == null) return '';
    if (v is TextCellValue) return v.value.toString().trim();
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) {
      final d = v.value;
      return d == d.truncateToDouble() ? d.toInt().toString() : d.toString();
    }
    if (v is BoolCellValue) return v.value.toString();
    if (v is DateTimeCellValue) return v.asDateTimeUtc().toIso8601String();
    if (v is DateCellValue) return v.asDateTimeLocal().toIso8601String();
    return v.toString();
  }

  // ── Detectar código de proyecto en el nombre de la hoja ──────────────────
  static const _proyectosCodigo = ['TQI', 'TSNL', 'TAP', 'TQM'];

  String? _inferirProyectoDeHoja(String hoja) {
    final upper = hoja.toUpperCase();
    for (final code in _proyectosCodigo) {
      // Debe aparecer como palabra completa o delimitada por no-alfanumérico
      final regex = RegExp(r'(^|[^A-Z0-9])' + code + r'([^A-Z0-9]|$)');
      if (regex.hasMatch(upper)) return code;
    }
    return null;
  }

  String _normalizePlainText(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _normalizeUpperCode(String value) {
    return _normalizePlainText(value).toUpperCase();
  }

  String _normalizeEmail(String value) {
    return _normalizePlainText(value).toLowerCase();
  }

  String _normalizeProyectoValue(String value) {
    final upper = _normalizeUpperCode(value);
    for (final code in _proyectosCodigo) {
      if (upper.contains(code)) return code;
    }
    return upper;
  }

  String _normalizeTipoPropiedadValue(String value) {
    final upper = _normalizeUpperCode(value);
    if (upper.contains('SOC')) return 'SOCIAL';
    if (upper.contains('PRI')) return 'PRIVADA';
    return upper;
  }

  String _normalizePropietarioField(String key, String value) {
    switch (key) {
      case 'rfc':
      case 'curp':
        return _normalizeUpperCode(value);
      case 'correo':
        return _normalizeEmail(value);
      case 'tipo_persona':
        return _normalizePlainText(value).toLowerCase();
      default:
        return _normalizePlainText(value);
    }
  }

  String _normalize(String value) {
    var s = value.toLowerCase().trim();
    const replacements = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
    };
    replacements.forEach((k, v) => s = s.replaceAll(k, v));
    return s.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  }
}

class _ImportRowResult {
  final int creados;
  final int actualizados;
  final int errores;
  final String? mensaje;

  const _ImportRowResult({
    this.creados = 0,
    this.actualizados = 0,
    this.errores = 0,
  }) : mensaje = null;

  const _ImportRowResult.error(this.mensaje)
      : creados = 0,
        actualizados = 0,
        errores = 1;
}

Map<String, dynamic> _parseXlsxPayload(Uint8List bytes) {
  final service = XlsxImportService();
  final result = service.parse(bytes);

  return {
    'hojas': result.hojas
        .map(
          (hoja) => {
            'hoja': hoja.hoja,
            'tabla': hoja.tabla == XlsxTargetTable.predios
                ? 'predios'
                : 'propietarios',
            'rows': hoja.rows,
          },
        )
        .toList(growable: false),
    'preview': result.preview,
    'totalRows': result.totalRows,
  };
}
