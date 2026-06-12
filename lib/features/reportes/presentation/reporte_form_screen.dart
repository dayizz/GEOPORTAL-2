import 'dart:typed_data';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/download_bytes.dart';
import '../../../features/predios/models/predio.dart';
import '../../../features/predios/providers/predios_provider.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../services/reporte_service.dart';

class ReporteFormScreen extends ConsumerStatefulWidget {
  const ReporteFormScreen({super.key});

  @override
  ConsumerState<ReporteFormScreen> createState() => _ReporteFormScreenState();
}

class _ReporteFormScreenState extends ConsumerState<ReporteFormScreen> {
  static const _proyectos = ['TQI', 'TSNL', 'TAP', 'TQM'];
  static const _opcionPredefinida = 'predefinido';
  static const _opcionOtro = 'otro';
  static const _destinatarioNombrePredefinido = 'Ing. Pavel López Medina';
  static const _destinatarioCargoPredefinido =
      'Titular de la Unidad de Verificación, Seguridad y Registro';
  static const _remitenteNombrePredefinido =
      'Ing. Carlos Alberto Sandoval Manrique de Lara';
  static const _remitenteCargoPredefinido =
      'Director de Verificación Ferroviaria "A"';

  final _formKey = GlobalKey<FormState>();
  final _segmentoCtrl = TextEditingController();
  final _paraNombreCtrl = TextEditingController();
  final _paraCargoCtrl = TextEditingController();
  final _deNombreCtrl = TextEditingController();
  final _deCargoCtrl = TextEditingController();
  final _elaboroRevisoCtrl = TextEditingController(text: 'BDVV/RSR');
  final _descripcionCtrl = TextEditingController();

  final bool _loading = false;
  bool _generating = false;
  String _proyecto = 'TSNL';
  String _destinatarioSeleccion = _opcionPredefinida;
  String _remitenteSeleccion = _opcionPredefinida;
  String _tramoSeleccionado = '';
  String _folioPreview = 'Se generará al presionar Generar';
  DateTime _fecha = DateTime.now();
  Uint8List? _lastPdfBytes;
  String? _lastFileName;

  bool get _destinatarioEsOtro => _destinatarioSeleccion == _opcionOtro;
  bool get _remitenteEsOtro => _remitenteSeleccion == _opcionOtro;

  @override
  void initState() {
    super.initState();
    _aplicarDestinatarioPredefinido();
    _aplicarRemitentePredefinido();
  }

  @override
  void dispose() {
    _segmentoCtrl.dispose();
    _paraNombreCtrl.dispose();
    _paraCargoCtrl.dispose();
    _deNombreCtrl.dispose();
    _deCargoCtrl.dispose();
    _elaboroRevisoCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  void _aplicarDestinatarioPredefinido() {
    _paraNombreCtrl.text = _destinatarioNombrePredefinido;
    _paraCargoCtrl.text = _destinatarioCargoPredefinido;
  }

  void _aplicarRemitentePredefinido() {
    _deNombreCtrl.text = _remitenteNombrePredefinido;
    _deCargoCtrl.text = _remitenteCargoPredefinido;
  }

  String _predioProyecto(Predio predio) {
    final proyectoDirecto = predio.proyecto?.trim().toUpperCase();
    if (proyectoDirecto != null && _proyectos.contains(proyectoDirecto)) {
      return proyectoDirecto;
    }

    final clave = predio.claveCatastral.trim().toUpperCase();
    final compact = clave.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compact.startsWith('TQI') || compact.startsWith('QI')) return 'TQI';
    if (compact.startsWith('TSNL') ||
        compact.startsWith('SNL') ||
        compact.startsWith('SL'))
      return 'TSNL';
    if (compact.startsWith('TAP') || compact.startsWith('AP')) return 'TAP';
    if (compact.startsWith('TQM') || compact.startsWith('QM')) return 'TQM';

    final contenido = [
      predio.claveCatastral,
      predio.ejido ?? '',
      predio.poligonoDwg ?? '',
      predio.oficio ?? '',
      predio.copFirmado ?? '',
    ].join(' ').toUpperCase();

    for (final proyecto in _proyectos) {
      if (contenido.contains(proyecto)) return proyecto;
    }

    return 'Sin proyecto';
  }

  bool _segmentMatches(String segmento, Predio predio) {
    final target = segmento.trim().toUpperCase();
    final current = predio.tramo.trim().toUpperCase();
    if (target.isEmpty) return true;
    if (current.isEmpty) return false;
    if (current == target) return true;
    if (current.endsWith(target) || target.endsWith(current)) return true;
    final currentDigits = current.replaceAll(RegExp(r'\D'), '');
    final targetDigits = target.replaceAll(RegExp(r'\D'), '');
    return currentDigits.isNotEmpty && currentDigits == targetDigits;
  }

  String _ownerLabel(Predio predio) {
    final owner = predio.nombrePropietario.trim();
    if (owner.isNotEmpty) return owner;
    final ejido = (predio.ejido ?? '').trim();
    if (ejido.isNotEmpty) return ejido;
    return 'Sin propietario';
  }

  Map<String, dynamic> _buildPayload(List<Predio> predios) {
    final proyectoPredios = predios
        .where((p) => _predioProyecto(p) == _proyecto)
        .toList();
    final segmentoPredios = proyectoPredios
        .where((p) => _segmentMatches(_segmentoCtrl.text, p))
        .toList();

    final privadas = segmentoPredios
        .where((p) => p.tipoPropiedad.toUpperCase() == 'PRIVADA')
        .toList();
    final sociales = segmentoPredios
        .where((p) => p.tipoPropiedad.toUpperCase() == 'SOCIAL')
        .toList();

    Map<String, dynamic> graphPayload(List<Predio> items) {
      final propietarios = items
          .map(_ownerLabel)
          .where((value) => value != 'Sin propietario')
          .toSet();
      return {
        'total_propietarios': propietarios.length,
        'total_predios': items.length,
        'levantamiento_si': items.where((p) => p.levantamiento).length,
        'acercamiento_si': items.where((p) => p.identificacion).length,
        'negociacion_si': items.where((p) => p.negociacion).length,
      };
    }

    return {
      'datos_formulario': {
        'fecha': _fmtDate(_fecha),
        'proyecto': _proyecto,
        'segmento': _segmentoCtrl.text.trim(),
        'para_nombre': _paraNombreCtrl.text.trim(),
        'para_cargo': _paraCargoCtrl.text.trim(),
        'de_nombre': _deNombreCtrl.text.trim(),
        'de_cargo': _deCargoCtrl.text.trim(),
        'elaboro_reviso': _elaboroRevisoCtrl.text.trim(),
        'descripcion': _descripcionCtrl.text.trim(),
      },
      'datos_automatizados': {
        'predios_totales_proy': proyectoPredios.length,
        'predios_totales_seg': segmentoPredios.length,
        'km_efectivos': segmentoPredios.fold<double>(
          0,
          (sum, predio) => sum + (predio.kmEfectivos ?? 0),
        ),
        'km_liberados': segmentoPredios
            .where((predio) => predio.cop)
            .fold<double>(0, (sum, predio) => sum + (predio.kmEfectivos ?? 0)),
        'superficie_liberada_m2': segmentoPredios
            .where((predio) => predio.cop)
            .fold<double>(0, (sum, predio) => sum + (predio.superficie ?? 0)),
        'avance_lddv_doc': segmentoPredios.isEmpty
            ? 0
            : (segmentoPredios.where((predio) => predio.cop).length /
                      segmentoPredios.length) *
                  100,
        'avance_lddv_sindoc': segmentoPredios.isEmpty
            ? 0
            : (segmentoPredios.where((predio) => !predio.cop).length /
                      segmentoPredios.length) *
                  100,
        'grafica_tipos': {
          for (final tipo in segmentoPredios.map(
            (predio) => predio.tipoPropiedad.toUpperCase(),
          ))
            tipo: segmentoPredios
                .where((predio) => predio.tipoPropiedad.toUpperCase() == tipo)
                .length,
        },
        'graficas_privada': graphPayload(privadas),
        'graficas_social': graphPayload(sociales),
      },
    };
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('es', 'MX'),
    );
    if (selected != null && mounted) {
      setState(() => _fecha = selected);
    }
  }

  Future<void> _downloadPdf(Uint8List bytes, String fileName) async {
    try {
      if (kIsWeb) {
        await triggerBrowserDownload(bytes, fileName);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Descarga iniciada en el navegador.')),
        );
        return;
      }

      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar reporte PDF',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );

      if (!mounted || savedPath == null) return;

      var outputPath = savedPath;
      if (!outputPath.toLowerCase().endsWith('.pdf')) {
        outputPath = '$outputPath.pdf';
      }

      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reporte descargado correctamente en $outputPath'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo descargar el PDF: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _generateReport() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _generating = true);
    try {
      final predios = await ref.read(prediosMapaProvider.future);
      final payload = _buildPayload(predios);
      final response = await const ReporteService().generarReporte(payload);
      if (response == null || response.bytes.isEmpty) {
        throw Exception('No fue posible generar el PDF.');
      }

      setState(() {
        _folioPreview = response.fileName.replaceAll('.pdf', '');
        _lastPdfBytes = response.bytes;
        _lastFileName = response.fileName;
      });

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reporte generado'),
          content: const Text(
            'El PDF fue generado correctamente. Puedes descargarlo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _downloadPdf(response.bytes, response.fileName);
              },
              child: const Text('Descargar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo generar el reporte: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prediosAsync = ref.watch(prediosMapaProvider);

    // Extraer tramos únicos del proyecto actual
    List<String> tramosDisponibles = [];
    prediosAsync.maybeWhen(
      data: (predios) {
        final proyectoPredios = predios
            .where((p) => _predioProyecto(p) == _proyecto)
            .toList();
        tramosDisponibles = proyectoPredios.map((p) => p.tramo).toSet().toList()
          ..sort();
      },
      orElse: () {},
    );

    return AppScaffold(
      currentIndex: 2,
      title: 'Balance  •  Reporte',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reporte automatizado',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        InputChip(
                          label: Text('Folio: $_folioPreview'),
                          avatar: const Icon(
                            Icons.receipt_long_outlined,
                            size: 18,
                          ),
                        ),
                        InputChip(
                          label: Text('Fecha: ${_fmtDate(_fecha)}'),
                          avatar: const Icon(Icons.event_outlined, size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  final formFields = <Widget>[
                    DropdownButtonFormField<String>(
                      initialValue: _proyecto,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Proyecto',
                        prefixIcon: Icon(Icons.work_outline),
                        border: OutlineInputBorder(),
                      ),
                      items: _proyectos
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _proyecto = value;
                            _tramoSeleccionado = '';
                            _segmentoCtrl.clear();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildTramoDropdown(tramos: tramosDisponibles),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha',
                          prefixIcon: Icon(Icons.date_range_outlined),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(_fmtDate(_fecha)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _destinatarioSeleccion,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Destinatario',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: _opcionPredefinida,
                          child: Text(
                            'Predefinido',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: _opcionOtro,
                          child: Text('Otro'),
                        ),
                      ],
                      selectedItemBuilder: (context) => const [
                        Text('Predefinido', overflow: TextOverflow.ellipsis),
                        Text('Otro', overflow: TextOverflow.ellipsis),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _destinatarioSeleccion = value;
                          if (value == _opcionPredefinida) {
                            _aplicarDestinatarioPredefinido();
                          } else {
                            _paraNombreCtrl.clear();
                            _paraCargoCtrl.clear();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    if (_destinatarioEsOtro) ...[
                      TextFormField(
                        controller: _paraNombreCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Destinatario - Nombre',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Captura el destinatario.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _paraCargoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Destinatario - Cargo',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Captura el cargo del destinatario.'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _remitenteSeleccion,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Remitente',
                        prefixIcon: Icon(Icons.person_pin_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: _opcionPredefinida,
                          child: Text(
                            'Predefinido',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: _opcionOtro,
                          child: Text('Otro'),
                        ),
                      ],
                      selectedItemBuilder: (context) => const [
                        Text('Predefinido', overflow: TextOverflow.ellipsis),
                        Text('Otro', overflow: TextOverflow.ellipsis),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _remitenteSeleccion = value;
                          if (value == _opcionPredefinida) {
                            _aplicarRemitentePredefinido();
                          } else {
                            _deNombreCtrl.clear();
                            _deCargoCtrl.clear();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    if (_remitenteEsOtro) ...[
                      TextFormField(
                        controller: _deNombreCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Remitente - Nombre',
                          prefixIcon: Icon(Icons.person_pin_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Captura el remitente.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _deCargoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Remitente - Cargo',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Captura el cargo del remitente.'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _elaboroRevisoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Elaboró / Revisó',
                        hintText: 'Ejemplo: BDVV/RSR',
                        prefixIcon: Icon(Icons.edit_note_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Captura el elaboró/revisó.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _descripcionCtrl,
                      minLines: 5,
                      maxLines: 8,
                      decoration: const InputDecoration(
                        labelText: 'Descripción del reporte',
                        hintText:
                            'Continúa después de: "...en referencia al segmento (número). "\n'
                            'Ej: Se informa el análisis de predios identificados y pk efectivos...',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.notes_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Agrega una descripción.'
                          : null,
                    ),
                  ];

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: isWide ? 5 : 1,
                        child: Column(children: formFields),
                      ),
                      if (isWide) ...[
                        const SizedBox(width: 18),
                        Expanded(flex: 4, child: _buildSidePanel()),
                      ],
                    ],
                  );
                },
              ),
              if (MediaQuery.of(context).size.width <= 900) ...[
                const SizedBox(height: 18),
                _buildSidePanel(),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading || _generating
                          ? null
                          : () => context.pop(),
                      icon: const Icon(Icons.arrow_back_outlined),
                      label: const Text('Volver a Balance'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _loading || _generating
                          ? null
                          : _generateReport,
                      icon: _generating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(
                        _generating ? 'Generando...' : 'Generar reporte',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidePanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF7F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8D9DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cruce automático',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'El sistema tomará el balance del proyecto y segmento para construir el payload del PDF.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          _infoRow('Folio', _folioPreview),
          _infoRow('Proyecto', _proyecto),
          _infoRow(
            'Segmento',
            _segmentoCtrl.text.trim().isEmpty
                ? 'Pendiente'
                : _segmentoCtrl.text.trim(),
          ),
          _infoRow('Fecha', _fmtDate(_fecha)),
          const SizedBox(height: 14),
          if (_lastPdfBytes != null)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    if (_lastPdfBytes == null || _lastFileName == null) return;
                    await _downloadPdf(_lastPdfBytes!, _lastFileName!);
                  },
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Descargar PDF'),
                ),
              ],
            )
          else
            const Text(
              'Cuando generes un reporte, aquí verás la acción de descarga.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _buildTramoDropdown({required List<String> tramos}) {
    if (tramos.isEmpty) {
      return DropdownButtonFormField<String>(
        initialValue: null,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Tramo / Frente / Segmento',
          prefixIcon: Icon(Icons.map_outlined),
          border: OutlineInputBorder(),
          helperText: 'Sin opciones para este proyecto',
        ),
        hint: const Text(
          'Sin tramos disponibles',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        items: const [],
        onChanged: null,
        validator: (_) => 'No hay tramos disponibles para este proyecto',
      );
    }

    return DropdownButtonFormField<String>(
      initialValue:
          _tramoSeleccionado.isEmpty || !tramos.contains(_tramoSeleccionado)
          ? null
          : _tramoSeleccionado,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Tramo / Frente / Segmento',
        prefixIcon: Icon(Icons.map_outlined),
        border: OutlineInputBorder(),
      ),
      hint: const Text('Selecciona un tramo'),
      items: tramos
          .map(
            (tramo) => DropdownMenuItem(
              value: tramo,
              child: Text(tramo, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _tramoSeleccionado = value;
            _segmentoCtrl.text = value;
          });
        }
      },
      validator: (value) =>
          (value == null || value.isEmpty) ? 'Selecciona un tramo.' : null,
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
