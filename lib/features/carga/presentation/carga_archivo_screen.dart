import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../mapa/providers/mapa_provider.dart';
import '../../predios/providers/predios_provider.dart';
import '../../predios/providers/local_predios_provider.dart';
import '../../predios/models/predio.dart';
import '../../predios/models/propietario.dart';
import '../../propietarios/providers/propietarios_provider.dart';
import '../../propietarios/providers/local_propietarios_provider.dart';
import '../data/archivos_geojson_repository.dart';
import '../data/local_archivos_repository.dart';
import '../providers/carga_provider.dart';
import '../services/geojson_background_parser.dart';
import '../services/sincronizacion_service.dart';
import '../services/xlsx_import_service.dart';
import '../utils/geojson_mapper.dart';

class CargaArchivoScreen extends ConsumerStatefulWidget {
  const CargaArchivoScreen({super.key});

  @override
  ConsumerState<CargaArchivoScreen> createState() => _CargaArchivoScreenState();
}

class _CargaArchivoScreenState extends ConsumerState<CargaArchivoScreen> {
  bool _loading = false;
  bool _sincronizando = false;
  List<Map<String, dynamic>> _preview = [];
  PlatformFile? _archivoSeleccionado;
  Map<String, dynamic>? _geoJsonData;
  SincronizacionResultado? _syncResultado;
  XlsxParseResult? _xlsxParseResult;
  /// Mapa campo → N° de features que lo contienen (detectado al parsear).
  Map<String, int> _camposDetectados = {};
  int _totalFeatures = 0;

  void _mostrarSnackBar(String mensaje, {bool exito = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: exito ? null : AppColors.danger,
        duration: Duration(seconds: exito ? 5 : 8),
      ),
    );
  }

  bool _yaCargoDesdeDB = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarArchivosDesdeBD());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_yaCargoDesdeDB) {
      // Se carga una vez por instancia del widget; initState ya lo dispara.
      return;
    }
    // Si el widget ya existía (volvimos a esta pantalla), recargamos desde BD.
    _cargarArchivosDesdeBD();
  }

  Future<void> _cargarArchivosDesdeBD() async {
    try {
      final repo = ref.read(localArchivosRepositoryProvider);
      final rawList = await repo.getArchivos();
      final bdFiles = rawList
          .map((m) {
            try {
              return ImportedFile.fromBD(m);
            } catch (_) {
              return null;
            }
          })
          .whereType<ImportedFile>()
          .toList();
      if (!mounted) return;
      ref.read(cargaProvider.notifier).initFromBD(bdFiles);
      _yaCargoDesdeDB = true;
    } catch (e) {
      // ignore: avoid_print
      debugPrint('Error cargando archivos desde Firestore: $e');
    }
  }

  Future<void> _seleccionarArchivo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    // Extraer extensión del nombre (file.extension puede no estar disponible en web)
    final ext = file.name.split('.').last.toLowerCase();

    // Validar que sea un archivo permitido
    if (!['geojson', 'json', 'xlsx', 'xlsl'].contains(ext)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Archivo no soportado. Usa .geojson, .json, .xlsx o .xlsl',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() {
      _archivoSeleccionado = file;
      _geoJsonData = null;
      _preview = [];
      _xlsxParseResult = null;
      _syncResultado = null;
      _camposDetectados = {};
      _totalFeatures = 0;
      _loading = true;
    });

    try {
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.readStream != null) {
        final collected = <int>[];
        await for (final chunk in file.readStream!) {
          collected.addAll(chunk);
        }
        bytes = Uint8List.fromList(collected);
      }

      if (bytes == null) {
        if (!mounted) return;
        _mostrarSnackBar('No se pudo leer el archivo seleccionado.', exito: false);
        return;
      }

      if (ext == 'xlsx' || ext == 'xlsl') {
        await _parsearXlsx(bytes);
      } else {
        await _parsearGeoJSON(bytes);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _parsearXlsx(Uint8List bytes) async {
    try {
      final service = ref.read(xlsxImportServiceProvider);
      final parseResult = await service.parseInBackground(bytes);
      if (!mounted) return;
      setState(() {
        _geoJsonData = null;
        _preview = [];
        _syncResultado = null;
        _camposDetectados = {};
        _totalFeatures = 0;
        _xlsxParseResult = parseResult;
      });
      _mostrarSnackBar('${parseResult.totalRows} filas detectadas en ${parseResult.hojas.length} hoja(s) compatibles.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _xlsxParseResult = null);
      _mostrarSnackBar('No se pudo leer el XLSX: $e', exito: false);
    }
  }

  Future<void> _parsearGeoJSON(Uint8List bytes) async {
    try {
      final parseResult = await parseGeoJsonInBackground(
        bytes: bytes,
        fileName: _archivoSeleccionado?.name ?? 'archivo.geojson',
      );

      if (!mounted) return;
      setState(() {
        _geoJsonData = {
          'type': 'FeatureCollection',
          'features': parseResult.features,
        };
        _preview = parseResult.preview;
        _totalFeatures = parseResult.totalFeatures;
        _camposDetectados = parseResult.camposDetectados;
      });
      _mostrarSnackBar('${parseResult.totalFeatures} features encontrados');
    } catch (e) {
      if (!mounted) return;
      _mostrarSnackBar('Error al leer el archivo: $e', exito: false);
    }
  }

  // ── Acciones sobre el GeoJSON ──────────────────────────────

  /// Extrae la lista de features del GeoJSON parseado.
  List<Map<String, dynamic>> _extraerFeatures() {
    final featuresList = _geoJsonData!['features'];
    if (featuresList is! List) return [];
    return featuresList
        .map(_asStringDynamicMap)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  /// Sincroniza, vincula y persiste en BD; después renderiza en mapa.
  Future<void> _guardarYVerEnMapa() async {
    if (_geoJsonData == null) return;
    final features = _extraerFeatures();
    if (features.isEmpty) return;

    final nombre = _archivoSeleccionado?.name ??
        'archivo_${DateTime.now().millisecondsSinceEpoch}';

    setState(() => _sincronizando = true);
    ref.read(importacionAsyncProvider.notifier).iniciar(
      total: features.length,
      etapa: 'Sincronizando',
    );

    try {
      final syncService = ref.read(sincronizacionServiceProvider);
      final resultado = await syncService.sincronizar(
        features,
        onProgress: (procesados, total) {
          ref.read(importacionAsyncProvider.notifier).actualizar(
            procesados: procesados,
            total: total,
            etapa: 'Sincronizando',
          );
        },
      );

      if (!mounted) return;

      // Guardar archivo en la BD
      String? bdId;
        try {
          final archivosRepo = ref.read(localArchivosRepositoryProvider);
          final saved = await archivosRepo.saveArchivo(
            nombre: nombre,
            features: resultado.features,
            sincronizado: true,
            encontrados: resultado.encontrados,
            creados: resultado.creados,
            errores: resultado.errores,
          );
          bdId = saved['id'] as String?;
        } catch (_) {
          // Si falla el guardado del archivo, continuar igualmente.
        }

      setState(() {
        _syncResultado = resultado;
        _sincronizando = false;
      });
      if (resultado.errores > 0 && resultado.creados == 0 && resultado.encontrados == 0) {
        final detalle = resultado.mensajesError.isNotEmpty
            ? resultado.mensajesError.first
            : 'Verifica que la migración SQL (sección 9 del supabase_schema.sql) haya sido ejecutada en Supabase.';
        _mostrarSnackBar('No se pudo registrar en Gestión.\n$detalle', exito: false);
      } else if (resultado.errores > 0) {
        _mostrarSnackBar(
          '${resultado.creados} guardados, ${resultado.errores} con error.\n'
          '${resultado.mensajesError.isNotEmpty ? resultado.mensajesError.first : ""}',
          exito: false,
        );
      }

      // Fallback local: si no se pudo persistir en BD, registrar en Gestión local.
      final totalGestion = resultado.creados + resultado.encontrados;
      if (totalGestion == 0) {
        final insertadosLocales = ref
            .read(localPrediosProvider.notifier)
            .upsertManyFromGeoJsonFeatures(features);

        ref.invalidate(prediosListProvider);
        ref.invalidate(prediosMapaProvider);

        final proyectoDetectado =
            GeoJsonMapper.detectarProyectoDesdeFeatures(features);
        if (proyectoDetectado != null) {
          ref.read(gestionProyectoProvider.notifier).state = proyectoDetectado;
        }

        ref.read(importacionAsyncProvider.notifier).completar(
          total: features.length,
          etapa: 'Completado',
        );
        if (mounted) {
          _mostrarSnackBar('BD no disponible. $insertadosLocales predio(s) registrados en Gestión local.');
          context.go('/tabla');
        }
      }

      ref.read(cargaProvider.notifier).addFile(
        nombre,
        resultado.features,
        bdId: bdId,
        guardadoEnBD: bdId != null,
        sincronizado: true,
        encontrados: resultado.encontrados,
        creados: resultado.creados,
        errores: resultado.errores,
      );

      ref.read(importedFeaturesProvider.notifier).state = resultado.features;

      // Refrescar Gestión y Mapa con los nuevos registros creados
      ref.invalidate(prediosListProvider);
      ref.invalidate(prediosMapaProvider);

      // Detectar proyecto predominante con GeoJsonMapper y auto-seleccionarlo en Gestión
      if (resultado.creados > 0 || resultado.encontrados > 0) {
        final proyectoDetectado =
            GeoJsonMapper.detectarProyectoDesdeFeatures(resultado.features);
        if (proyectoDetectado != null) {
          ref.read(gestionProyectoProvider.notifier).state = proyectoDetectado;
        }

        ref.read(importacionAsyncProvider.notifier).completar(
          total: features.length,
          etapa: 'Completado',
        );

        // Navegar a Gestión para que el usuario vea las filas inyectadas
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${resultado.creados} nuevo(s) + ${resultado.encontrados} actualizado(s) en Gestión',
              ),
              action: SnackBarAction(
                label: 'Ver Mapa',
                onPressed: () => context.go('/mapa'),
              ),
              duration: const Duration(seconds: 6),
            ),
          );
          context.go('/tabla');
        }
      }
    } catch (e) {
      if (!mounted) return;
      final insertadosLocales = ref
          .read(localPrediosProvider.notifier)
          .upsertManyFromGeoJsonFeatures(features);
      ref.invalidate(prediosListProvider);
      ref.invalidate(prediosMapaProvider);

      final proyectoDetectado =
          GeoJsonMapper.detectarProyectoDesdeFeatures(features);
      if (proyectoDetectado != null) {
        ref.read(gestionProyectoProvider.notifier).state = proyectoDetectado;
      }

      if (insertadosLocales > 0) {
        ref.read(importacionAsyncProvider.notifier).completar(
          total: features.length,
          etapa: 'Completado',
        );
      } else {
        ref.read(importacionAsyncProvider.notifier).fallar(
          procesados: 0,
          total: features.length,
          etapa: 'Error',
          mensaje: e.toString(),
        );
      }
      setState(() => _sincronizando = false);
      _mostrarSnackBar(
        'Error de BD: $e\n$insertadosLocales predio(s) registrados en Gestión local.',
        exito: insertadosLocales > 0,
      );
      if (insertadosLocales > 0) {
        context.go('/tabla');
      }
    }
  }

  /// Envía un archivo de la tabla al mapa
  void _verEnMapaDesdeTabla(String fileId) {
    final importedFiles = ref.read(cargaProvider);
    final file = importedFiles.firstWhere((f) => f.id == fileId);
    ref.read(importedFeaturesProvider.notifier).state = file.features;
    context.go('/mapa');
  }

  /// Elimina un archivo: del provider en memoria y, si tiene bdId, también de la BD.
  Future<void> _eliminarArchivo(ImportedFile file) async {
    ref.read(cargaProvider.notifier).removeFile(file.id);
    if (file.guardadoEnBD && file.bdId != null) {
      try {
        final repo = ref.read(localArchivosRepositoryProvider);
        await repo.deleteArchivo(file.bdId!);
      } catch (_) {
        // Error silencioso: el archivo ya fue quitado de la UI.
      }
    }
  }

  Future<void> _eliminarTodos(List<ImportedFile> files) async {
    ref.read(cargaProvider.notifier).clearAll();
    try {
      final repo = ref.read(localArchivosRepositoryProvider);
      await repo.deleteAll();
    } catch (_) {}
  }

  Future<void> _inyectarXlsxEnTablas() async {
    final parseResult = _xlsxParseResult;
    if (parseResult == null) return;

    if (!SupabaseConfig.isConfigured) {
      await _inyectarXlsxLocal(parseResult);
      return;
    }

    setState(() => _sincronizando = true);

    try {
      final service = ref.read(xlsxImportServiceProvider);
      final resultado = await service.importar(parseResult);

      ref.invalidate(prediosListProvider);
      ref.invalidate(prediosMapaProvider);
      ref.invalidate(propietariosListProvider);

      if (!mounted) return;
      setState(() => _sincronizando = false);
      if (resultado.errores == 0) {
        _mostrarSnackBar(
          'Inyección completada: ${resultado.procesados} fila(s), ${resultado.creados} creada(s), '
          '${resultado.actualizados} actualizada(s).',
        );
      } else {
        _mostrarSnackBar(
          resultado.mensajes.isNotEmpty
              ? resultado.mensajes.first
              : 'Algunas filas no pudieron inyectarse (${resultado.errores} error(es)).',
          exito: false,
        );
      }

      // Persistir el archivo XLSX en la BD y registrarlo en la lista
      if (_archivoSeleccionado != null) {
        String? bdId;
        try {
          final archivosRepo = ref.read(localArchivosRepositoryProvider);
          final saved = await archivosRepo.saveArchivo(
            nombre: _archivoSeleccionado!.name,
            features: const [],
            rowCount: resultado.procesados,
            sincronizado: true,
            encontrados: resultado.actualizados,
            creados: resultado.creados,
            errores: resultado.errores,
          );
          bdId = saved['id'] as String?;
        } catch (_) {
          // Si falla el guardado del archivo, continuar igualmente.
        }
        ref.read(cargaProvider.notifier).addFile(
          _archivoSeleccionado!.name,
          const [],
          bdId: bdId,
          guardadoEnBD: bdId != null,
          sincronizado: true,
          creados: resultado.creados,
          encontrados: resultado.actualizados,
          errores: resultado.errores,
          rowCount: resultado.procesados,
        );
      }

      if (resultado.errores > 0 && mounted) {
        // error SnackBar already shown above
      }

      if (mounted) {
        context.go('/tabla');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _sincronizando = false);
      _mostrarSnackBar(
        !SupabaseConfig.isConfigured
            ? 'Supabase no está configurado. Reemplaza la URL y la anon key reales en lib/core/supabase/supabase_config.dart antes de inyectar el XLSX.'
            : 'Error al inyectar XLSX: $e',
        exito: false,
      );
    }
  }

  Future<void> _inyectarXlsxLocal(XlsxParseResult parseResult) async {
    setState(() => _sincronizando = true);

    var procesados = 0;
    var creados = 0;
    var actualizados = 0;
    var errores = 0;
    final mensajes = <String>[];

    final localPropietarios = ref.read(localPropietariosProvider.notifier);
    final localPredios = ref.read(localPrediosProvider.notifier);
    final prediosParaUpsert = <Predio>[];

    try {
      for (final hoja in parseResult.hojas) {
        if (hoja.tabla == XlsxTargetTable.propietarios) {
          for (final row in hoja.rows) {
            procesados++;
            try {
              final existente = _findLocalPropietario(
                ref.read(localPropietariosProvider),
                row,
              );
              localPropietarios.upsertFromData(row);
              if (existente == null) {
                creados++;
              } else {
                actualizados++;
              }
            } catch (e) {
              errores++;
              if (mensajes.length < 8) {
                mensajes.add('Hoja ${hoja.hoja}: $e');
              }
            }
          }
          continue;
        }

        for (var i = 0; i < hoja.rows.length; i++) {
          final row = hoja.rows[i];
          procesados++;

          try {
            final clave = row['clave_catastral']?.toString().trim() ?? '';
            if (clave.isEmpty) {
              errores++;
              if (mensajes.length < 8) {
                mensajes.add('Hoja ${hoja.hoja}: fila sin clave_catastral.');
              }
              continue;
            }

            Propietario? propietario;
            final propietarioData = _buildLocalPropietarioData(row);
            if (propietarioData.isNotEmpty) {
              propietario = localPropietarios.upsertFromData(propietarioData);
            }

            final existente = ref.read(localPrediosProvider).any(
                  (item) => item.claveCatastral == clave,
                ) ||
                prediosParaUpsert.any((item) => item.claveCatastral == clave);

            prediosParaUpsert.add(
              Predio(
                id: 'local-xlsx-${clave.replaceAll(' ', '_')}-${i + 1}',
                claveCatastral: clave,
                propietarioNombre: propietario?.nombreCompleto ??
                    row['propietario_nombre']?.toString().trim(),
                tramo: row['tramo']?.toString().trim().isNotEmpty == true
                    ? row['tramo'].toString().trim()
                    : 'T1',
                tipoPropiedad:
                    row['tipo_propiedad']?.toString().trim().isNotEmpty == true
                        ? row['tipo_propiedad'].toString().trim()
                        : 'PRIVADA',
                ejido: _optionalText(row['ejido']),
                kmInicio: _toDouble(row['km_inicio']),
                kmFin: _toDouble(row['km_fin']),
                kmLineales: _toDouble(row['km_lineales']),
                kmEfectivos: _toDouble(row['km_efectivos']),
                superficie: _toDouble(row['superficie']),
                cop: _toBool(row['cop']),
                proyecto: _optionalText(row['proyecto']),
                poligonoInsertado: _toBool(row['poligono_insertado']),
                identificacion: _toBool(row['identificacion']),
                levantamiento: _toBool(row['levantamiento']),
                negociacion: _toBool(row['negociacion']),
                latitud: _toDouble(row['latitud']),
                longitud: _toDouble(row['longitud']),
                propietarioId: propietario?.id,
                propietario: propietario,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );

            if (existente) {
              actualizados++;
            } else {
              creados++;
            }
          } catch (e) {
            errores++;
            if (mensajes.length < 8) {
              mensajes.add('Hoja ${hoja.hoja}: $e');
            }
          }
        }
      }

      localPredios.upsertMany(prediosParaUpsert);
      ref.invalidate(prediosListProvider);
      ref.invalidate(prediosMapaProvider);
      ref.invalidate(propietariosListProvider);

      // Detectar proyecto dominante entre los predios importados
      const codigosProyecto = ['TQI', 'TSNL', 'TAP', 'TQM'];
      String? proyectoDetectado;

      // 1) Ver qué proyecto aparece más veces en el campo proyecto de los predios
      final conteo = <String, int>{};
      for (final predio in prediosParaUpsert) {
        final p = predio.proyecto?.trim().toUpperCase() ?? '';
        if (codigosProyecto.contains(p)) {
          conteo[p] = (conteo[p] ?? 0) + 1;
        }
      }
      if (conteo.isNotEmpty) {
        proyectoDetectado =
            conteo.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      }

      // 2) Si no se detectó, intentar desde el nombre de las hojas del Excel
      if (proyectoDetectado == null) {
        for (final hoja in parseResult.hojas) {
          final upper = hoja.hoja.toUpperCase();
          for (final code in codigosProyecto) {
            final regex =
                RegExp(r'(^|[^A-Z0-9])' + code + r'([^A-Z0-9]|$)');
            if (regex.hasMatch(upper)) {
              proyectoDetectado = code;
              break;
            }
          }
          if (proyectoDetectado != null) break;
        }
      }

      // Navegar al tab del proyecto detectado (o TQI si no se pudo determinar,
      // ya que _predioProyecto en TablaScreen usa TQI como fallback por defecto)
      ref.read(gestionProyectoProvider.notifier).state =
          proyectoDetectado ?? 'TQI';

      if (!mounted) return;
      setState(() => _sincronizando = false);
      if (errores == 0) {
        _mostrarSnackBar(
          'Inyección local completada: $procesados fila(s), $creados creada(s), $actualizados actualizada(s).',
        );
      } else {
        _mostrarSnackBar(
          mensajes.isNotEmpty
              ? mensajes.first
              : 'Algunas filas no pudieron inyectarse en modo local ($errores error(es)).',
          exito: false,
        );
      }

      // Registrar en la lista de archivos importados
      if (_archivoSeleccionado != null) {
        String? bdId;
        try {
          final archivosRepo = ref.read(localArchivosRepositoryProvider);
          final saved = await archivosRepo.saveArchivo(
            nombre: _archivoSeleccionado!.name,
            features: const [],
            rowCount: procesados,
            sincronizado: true,
            encontrados: actualizados,
            creados: creados,
            errores: errores,
          );
          bdId = saved['id'] as String?;
        } catch (_) {
          // En modo local sin BD/Sheets, continuar sin persistir el registro.
        }
        ref.read(cargaProvider.notifier).addFile(
          _archivoSeleccionado!.name,
          const [],
          bdId: bdId,
          guardadoEnBD: bdId != null,
          sincronizado: true,
          creados: creados,
          encontrados: actualizados,
          errores: errores,
          rowCount: procesados,
        );
      }

      if (errores > 0 && mounted) {
        // error SnackBar already shown above
      }

      if (mounted) {
        context.go('/tabla');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _sincronizando = false);
      _mostrarSnackBar('Error al inyectar XLSX en modo local: $e', exito: false);
    }
  }

  Map<String, dynamic> _buildLocalPropietarioData(Map<String, dynamic> row) {
    final out = <String, dynamic>{};

    final nombre = _optionalText(row['propietario_nombre']);
    if (nombre != null) {
      out['nombre_completo'] = nombre;
    }

    final rfc = _optionalText(row['rfc_propietario']);
    if (rfc != null) {
      out['rfc'] = rfc;
    }

    final curp = _optionalText(row['curp_propietario']);
    if (curp != null) {
      out['curp'] = curp;
    }

    final telefono = _optionalText(row['telefono_propietario']);
    if (telefono != null) {
      out['telefono'] = telefono;
    }

    final correo = _optionalText(row['correo_propietario']);
    if (correo != null) {
      out['correo'] = correo;
    }

    return out;
  }

  Propietario? _findLocalPropietario(
    List<Propietario> propietarios,
    Map<String, dynamic> row,
  ) {
    final rfc = _optionalText(row['rfc']);
    if (rfc != null) {
      for (final propietario in propietarios) {
        if ((propietario.rfc ?? '').trim().toUpperCase() == rfc.toUpperCase()) {
          return propietario;
        }
      }
    }

    final nombre = _optionalText(row['nombre']);
    final apellidos = _optionalText(row['apellidos']) ?? '';
    final nombreCompleto = _optionalText(row['nombre_completo']);
    final comparador = (nombreCompleto ?? [nombre, apellidos].whereType<String>().join(' '))
      .trim()
      .toUpperCase();
    if (comparador.isEmpty) {
      return null;
    }

    for (final propietario in propietarios) {
      if (propietario.nombreCompleto.trim().toUpperCase() == comparador) {
        return propietario;
      }
    }

    return null;
  }

  String? _optionalText(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') {
      return null;
    }
    return text;
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = _optionalText(value)?.toLowerCase();
    return text == 'true' || text == '1' || text == 'si' || text == 'sí' || text == 'yes';
  }

  Map<String, dynamic>? _asStringDynamicMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.replaceAll(',', '').trim();
      return double.tryParse(normalized);
    }
    return null;
  }

  List<Map<String, dynamic>> _erroresSincronizacion() {
    final resultado = _syncResultado;
    if (resultado == null) return const [];

    return resultado.features.where((feature) {
      final props = _asStringDynamicMap(feature['properties']) ?? <String, dynamic>{};
      return props['_syncStatus']?.toString() == 'error' ||
          (props['_syncError']?.toString().trim().isNotEmpty ?? false);
    }).toList(growable: false);
  }

  String _buildErrorReportJson() {
    final resultado = _syncResultado;
    final errores = _erroresSincronizacion();
    final report = <String, dynamic>{
      'archivo': _archivoSeleccionado?.name,
      'generado_en': DateTime.now().toIso8601String(),
      'resumen': {
        'total_features': _totalFeatures,
        'creados': resultado?.creados ?? 0,
        'encontrados': resultado?.encontrados ?? 0,
        'errores': resultado?.errores ?? 0,
        'errores_exportados': errores.length,
      },
      'mensajes_error': resultado?.mensajesError ?? const [],
      'features_con_error': errores,
    };

    return const JsonEncoder.withIndent('  ').convert(report);
  }

  String _csvEscape(dynamic value) {
    final text = value?.toString() ?? '';
    final escaped = text.replaceAll('"', '""');
    if (escaped.contains(',') || escaped.contains('"') || escaped.contains('\n')) {
      return '"$escaped"';
    }
    return escaped;
  }

  String _buildErrorReportCsv() {
    final rows = <String>[
      'clave_catastral,predio_id,sync_status,sync_error,proyecto,tramo,propietario,tipo_geom',
    ];

    for (final feature in _erroresSincronizacion()) {
      final props = _asStringDynamicMap(feature['properties']) ?? <String, dynamic>{};
      rows.add([
        _csvEscape(props['clave_catastral'] ?? props['_claveCatastral']),
        _csvEscape(props['predio_id'] ?? props['_predioId']),
        _csvEscape(props['_syncStatus']),
        _csvEscape(props['_syncError']),
        _csvEscape(props['_proyecto'] ?? props['proyecto']),
        _csvEscape(props['_tramo'] ?? props['tramo']),
        _csvEscape(props['_propietarioNombre'] ?? props['propietario']),
        _csvEscape(_asStringDynamicMap(feature['geometry'])?['type']),
      ].join(','));
    }

    return rows.join('\n');
  }

  Future<void> _exportarReporteErrores({required bool asCsv}) async {
    final resultado = _syncResultado;
    if (resultado == null) return;

    final contenido = asCsv ? _buildErrorReportCsv() : _buildErrorReportJson();
    final extension = asCsv ? 'csv' : 'json';
    final mimeType = asCsv ? 'text/csv' : 'application/json';
    final nombreBase = (_archivoSeleccionado?.name ?? 'reporte_importacion')
        .replaceAll(RegExp(r'\.[^.]+$'), '')
        .replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');
    final fileName = '${nombreBase}_errores_importacion.$extension';

    try {
      final file = XFile.fromData(
        Uint8List.fromList(utf8.encode(contenido)),
        mimeType: mimeType,
        name: fileName,
      );

      await Share.shareXFiles(
        [file],
        text: 'Reporte de errores de importación GeoJSON',
        subject: fileName,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reporte de errores generado.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo exportar el reporte: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progresoImportacion = ref.watch(importacionProgresoProvider);
    final porcentajeSync = progresoImportacion.porcentaje;
    final isBusy = _loading || _sincronizando;

    return AppScaffold(
      currentIndex: 2,
      title: 'Carga de Archivos',
      child: Stack(
        children: [
          AbsorbPointer(
            absorbing: isBusy,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Importa archivos GeoJSON y XLSX para vincular polígonos y propiedades.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Zona de carga
            GestureDetector(
              onTap: _loading ? null : _seleccionarArchivo,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: _archivoSeleccionado != null
                      ? AppColors.secondary.withValues(alpha: 0.05)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _archivoSeleccionado != null
                        ? AppColors.secondary
                        : AppColors.border,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _archivoSeleccionado != null
                          ? Icons.check_circle
                          : Icons.upload_file,
                      size: 56,
                      color: _archivoSeleccionado != null
                          ? AppColors.secondary
                          : AppColors.textLight,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _archivoSeleccionado != null
                          ? _archivoSeleccionado!.name
                          : 'Seleccionar archivo',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _archivoSeleccionado != null
                            ? AppColors.secondary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _archivoSeleccionado != null
                          ? 'Toca para cambiar el archivo'
                            : 'Formatos: .geojson  .json  .xlsx  .xlsl',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
            ),

            if ((_syncResultado?.errores ?? 0) > 0 ||
                (_syncResultado?.mensajesError.isNotEmpty ?? false)) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _exportarReporteErrores(asCsv: false),
                    icon: const Icon(Icons.data_object_outlined, size: 18),
                    label: const Text('Exportar errores JSON'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _exportarReporteErrores(asCsv: true),
                    icon: const Icon(Icons.table_view_outlined, size: 18),
                    label: const Text('Exportar errores CSV'),
                  ),
                ],
              ),
            ],

            // Vista previa
            if (_preview.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Vista previa (primeros ${_preview.length} registros)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: _preview.asMap().entries.map((e) {
                    final item = e.value;
                    return Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              (item['tipo_geom'] == 'Polygon' ||
                                      item['tipo_geom'] == 'MultiPolygon')
                                  ? Icons.crop_square_outlined
                                  : Icons.location_on_outlined,
                              color: AppColors.primary,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            item['clave'].toString(),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          isThreeLine: item['proyecto'] != null,
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (item['proyecto'] != null)
                                Text(
                                  'Proyecto: ${item['proyecto']}',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.info),
                                ),
                              Text(
                                [
                                  if (item['tramo'] != null)
                                    'Tramo: ${item['tramo']}',
                                  if (item['propietario'] != null)
                                    item['propietario'].toString(),
                                  '${item['superficie']} m²'  
                                      '${item['tipo_geom'] != null ? '  ·  ${item['tipo_geom']}' : ''}',
                                ].join('  ·  '),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        if (e.key < _preview.length - 1)
                          const Divider(height: 1),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],

            if (_xlsxParseResult != null) ...[
              const SizedBox(height: 24),
              Text(
                'Vista previa XLSX (primeros ${_xlsxParseResult!.preview.length} registros)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: _xlsxParseResult!.preview.asMap().entries.map((entry) {
                    final item = entry.value;
                    final tabla = item['tabla']?.toString() ?? 'desconocida';
                    final hoja = item['hoja']?.toString() ?? '-';
                    final clave = item['clave_catastral']?.toString();
                    final propietario = item['nombre_completo']?.toString() ??
                        item['propietario_nombre']?.toString() ??
                        item['nombre']?.toString();

                    return Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            tabla == 'predios'
                                ? Icons.table_chart_outlined
                                : Icons.person_outline,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            tabla == 'predios'
                                ? (clave ?? 'Sin clave')
                                : (propietario ?? 'Sin nombre'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            'Hoja: $hoja  ·  Tabla detectada: $tabla',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (entry.key < _xlsxParseResult!.preview.length - 1)
                          const Divider(height: 1),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],

            // ── Campos de Gestión detectados ─────────────────────────────
            if (_camposDetectados.isNotEmpty) ...[              
              const SizedBox(height: 16),
              Text(
                'Campos de Gestión detectados',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in {
                    'clave': 'Clave',
                    'proyecto': 'Proyecto',
                    'tramo': 'Tramo',
                    'propietario': 'Propietario',
                    'superficie': 'Superficie',
                    'km_inicio': 'KM inicio',
                    'km_fin': 'KM fin',
                  }.entries)
                    Builder(builder: (context) {
                      final count = _camposDetectados[entry.key] ?? 0;
                      final all  = count == _totalFeatures && count > 0;
                      final part = count > 0 && count < _totalFeatures;
                      final color = all
                          ? AppColors.secondary
                          : part
                              ? Colors.orange
                              : AppColors.textLight;
                      final icon = all
                          ? Icons.check_circle_outline
                          : part
                              ? Icons.warning_amber_outlined
                              : Icons.remove_circle_outline;
                      return Chip(
                        avatar: Icon(icon, size: 14, color: color),
                        label: Text(
                          count > 0
                              ? '${entry.value} ($count/$_totalFeatures)'
                              : entry.value,
                          style: TextStyle(fontSize: 11, color: color),
                        ),
                        backgroundColor: color.withValues(alpha: 0.08),
                        side: BorderSide(color: color.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                      );
                    }),
                ],
              ),
            ],

            const SizedBox(height: 28),
            if (_archivoSeleccionado != null &&
                (_preview.isNotEmpty || _xlsxParseResult != null)) ...[
              // ── Acción única de guardado ───────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Guardar e inyectar datos',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: (_sincronizando)
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.table_chart_outlined, size: 18),
                        label: Text(
                          _sincronizando
                              ? 'Guardando…'
                              : (_xlsxParseResult != null
                                  ? 'Inyectar XLSX y abrir Gestión'
                                  : 'Guardar e ir a Gestión'),
                          style: const TextStyle(fontSize: 13),
                        ),
                        onPressed: (_loading || _sincronizando)
                            ? null
                            : (_xlsxParseResult != null
                                ? _inyectarXlsxEnTablas
                                : _guardarYVerEnMapa),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 12, color: AppColors.textLight),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            'Para GeoJSON detecta proyecto/tramo/propietario. '
                            'Para XLSX detecta la tabla por encabezados y realiza upsert '
                            'del contenido similar, sin modificar tus encabezados existentes.',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textLight),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // ── Tabla de archivos importados ────────────────────
            const SizedBox(height: 40),
            Consumer(
              builder: (context, ref, _) {
                final importedFiles = ref.watch(cargaProvider);

                if (importedFiles.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, color: AppColors.textLight, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'No hay archivos importados',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Archivos importados (${importedFiles.length})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Eliminar todos'),
                              content: const Text(
                                '¿Eliminar todos los archivos importados? Se borrarán también de la base de datos.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _eliminarTodos(importedFiles);
                                  },
                                  child: const Text('Eliminar todos',
                                      style: TextStyle(color: AppColors.danger)),
                                ),
                              ],
                            ),
                          ),
                          icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: AppColors.danger),
                          label: const Text('Eliminar todos', style: TextStyle(fontSize: 12, color: AppColors.danger)),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: importedFiles.length,
                        separatorBuilder: (_, index) =>
                            const Divider(height: 1, color: AppColors.border),
                        itemBuilder: (_, idx) =>
                            _buildArchivoTile(importedFiles[idx]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
    if (isBusy)
      Positioned.fill(
        child: Container(
          color: Colors.black.withValues(alpha: 0.22),
          alignment: Alignment.center,
          child: Container(
            width: 260,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 12),
                Text(
                  _sincronizando
                      ? 'Inyectando y actualizando datos...'
                      : 'Leyendo archivo...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
  ],
),
    );
  }

  // ── Tile de archivo en la lista ──────────────────────────

  Widget _buildArchivoTile(ImportedFile file) {
    final statusColor = file.guardadoEnBD ? AppColors.secondary : AppColors.textLight;
    final statusIcon = file.guardadoEnBD ? Icons.cloud_done_outlined : Icons.cloud_off_outlined;
    final statusLabel = file.guardadoEnBD ? 'Guardado en BD' : 'Solo en memoria';

    final busy = _loading || _sincronizando;
    return Stack(
      children: [
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.insert_drive_file_outlined, color: statusColor, size: 18),
          ),
          title: Text(
            file.name.length > 40 ? '${file.name.substring(0, 37)}…' : file.name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(statusIcon, size: 11, color: statusColor),
                  const SizedBox(width: 3),
                  Text(statusLabel,
                      style: TextStyle(fontSize: 11, color: statusColor)),
                  if (file.sincronizado) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.info.withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${file.encontrados} exist. / ${file.creados} nuevos'
                        '${file.errores > 0 ? " / ${file.errores} err" : ""}',
                        style:
                            TextStyle(fontSize: 10, color: AppColors.info.withOpacity(0.8)),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '${file.featureCount} features · ${file.formattedDate}',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textLight),
              ),
            ],
          ),
          isThreeLine: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: 'Ver en mapa',
                child: IconButton(
                  icon: const Icon(Icons.map_outlined, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => _verEnMapaDesdeTabla(file.id),
                ),
              ),
              Tooltip(
                message: 'Eliminar',
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18,
                      color: AppColors.danger),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Eliminar archivo'),
                      content: Text(
                        '¿Eliminar "${file.name}"?'
                        '${file.guardadoEnBD ? '\nSe borrará también de la base de datos.' : ''}',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () {
                            _eliminarArchivo(file);
                            Navigator.pop(ctx);
                          },
                          child: const Text('Eliminar',
                              style: TextStyle(color: AppColors.danger)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (busy)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.2),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Actualizando, por favor espera...',
                        style: TextStyle(fontSize: 16, color: Colors.black)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
