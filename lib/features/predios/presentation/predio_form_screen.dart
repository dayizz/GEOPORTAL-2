import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/predios_provider.dart';
import '../providers/demo_predios_notifier.dart';
import '../providers/local_predios_provider.dart';
import '../data/predios_repository.dart';
import '../models/predio.dart';
import '../../auth/providers/demo_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

class PredioFormScreen extends ConsumerStatefulWidget {
  final String? id; // null = nuevo predio
  const PredioFormScreen({super.key, this.id});

  @override
  ConsumerState<PredioFormScreen> createState() => _PredioFormScreenState();
}

class _PredioFormScreenState extends ConsumerState<PredioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _loadingData = true;

  final _claveCtrl = TextEditingController();
  final _ejidoCtrl = TextEditingController();
  final _kmInicioCtrl = TextEditingController();
  final _kmFinCtrl = TextEditingController();
  final _kmLinealesCtrl = TextEditingController();
  final _kmEfectivosCtrl = TextEditingController();
  final _superficieCtrl = TextEditingController();
  final _poligonoDwgCtrl = TextEditingController();
  final _oficioCtrl = TextEditingController();
  final _situacionSocialCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _propietarioNombreCtrl = TextEditingController();

  String _tramo = 'T1';
  String _tramoTipo = 'TRAMO';
  String _tramoNumero = '1';
  String _tipoPropiedad = 'PRIVADA';
  bool _cop = false;
  bool _poligonoInsertado = false;
  bool _identificacion = false;
  bool _levantamiento = false;
  bool _negociacion = false;
  String _estatusPredio = 'No liberado';
  String? _propietarioId;
  String? _pdfUrl;
  DateTime? _copFecha;
  bool _uploadingPdf = false;

  String _buildTramoValue() {
    const prefijos = {
      'TRAMO': 'T',
      'FRENTE': 'F',
      'SEGMENTO': 'S',
    };
    final prefijo = prefijos[_tramoTipo] ?? 'T';
    return '$prefijo$_tramoNumero';
  }

  void _setTramoFromValue(String valor) {
    final limpio = valor.trim().toUpperCase();
    final match = RegExp(r'^([TFS])\s*([1-5])$').firstMatch(limpio);

    if (match != null) {
      final prefijo = match.group(1)!;
      final numero = match.group(2)!;
      _tramoTipo = switch (prefijo) {
        'F' => 'FRENTE',
        'S' => 'SEGMENTO',
        _ => 'TRAMO',
      };
      _tramoNumero = numero;
      _tramo = _buildTramoValue();
      return;
    }

    _tramoTipo = 'TRAMO';
    _tramoNumero = '1';
    _tramo = _buildTramoValue();
  }

  @override
  void initState() {
    super.initState();
    if (widget.id != null) {
      _loadPredio();
    } else {
      _loadingData = false;
    }
  }

  Future<void> _loadPredio() async {
    try {
      final predio = await ref.read(predioDetalleProvider(widget.id!).future);
      if (predio != null && mounted) {
        _claveCtrl.text = predio.claveCatastral;
        _ejidoCtrl.text = predio.ejido ?? '';
        _kmInicioCtrl.text = predio.kmInicio?.toString() ?? '';
        _kmFinCtrl.text = predio.kmFin?.toString() ?? '';
        _kmLinealesCtrl.text = predio.kmLineales?.toString() ?? '';
        _kmEfectivosCtrl.text = predio.kmEfectivos?.toString() ?? '';
        _superficieCtrl.text = predio.superficie?.toString() ?? '';
        _pdfUrl = predio.pdfUrl ?? predio.copFirmado;
        _copFecha = predio.copFecha;
        _poligonoDwgCtrl.text = predio.poligonoDwg ?? '';
        _oficioCtrl.text = predio.oficio ?? '';
        _situacionSocialCtrl.text = predio.situacionSocial ?? '';
        _latCtrl.text = predio.latitud?.toString() ?? '';
        _lngCtrl.text = predio.longitud?.toString() ?? '';
        _propietarioNombreCtrl.text = predio.propietarioNombre ?? '';
        _setTramoFromValue(predio.tramo);
        _tipoPropiedad = predio.tipoPropiedad;
        _cop = predio.cop;
        _poligonoInsertado = predio.poligonoInsertado;
        _identificacion = predio.identificacion;
        _levantamiento = predio.levantamiento;
        _negociacion = predio.negociacion;
        _estatusPredio = predio.cop ? 'Liberado' : 'No liberado';
        _propietarioId = predio.propietarioId;
      }
    } finally {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _claveCtrl, _ejidoCtrl, _kmInicioCtrl, _kmFinCtrl, _kmLinealesCtrl,
      _kmEfectivosCtrl, _superficieCtrl, _poligonoDwgCtrl,
      _oficioCtrl, _situacionSocialCtrl, _latCtrl, _lngCtrl, _propietarioNombreCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _resolvedPdfUrl() {
    final value = (_pdfUrl ?? '').trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _openPdf(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      throw Exception('La URL del PDF es invalida.');
    }
    final opened = await launchUrl(uri, webOnlyWindowName: '_blank');
    if (!opened) {
      throw Exception('No se pudo abrir el PDF.');
    }
  }

  Future<void> _persistPdfUrl(String url) async {
    final isEdit = widget.id != null;
    if (!isEdit) {
      setState(() => _pdfUrl = url);
      return;
    }

    final isDemo = ref.read(demoModeProvider);
    final isLocalPredio = widget.id!.startsWith('local-');
    final now = DateTime.now();

    if (isDemo) {
      final predioActual = ref
          .read(demoPrediosNotifierProvider)
          .firstWhere((p) => p.id == widget.id);
      ref.read(demoPrediosNotifierProvider.notifier).updatePredio(
            predioActual.copyWith(
              pdfUrl: url,
              copFirmado: url,
              copFecha: now,
              updatedAt: now,
            ),
          );
    } else if (isLocalPredio) {
      final predioActual = ref
          .read(localPrediosProvider)
          .firstWhere((p) => p.id == widget.id);
      ref.read(localPrediosProvider.notifier).updatePredio(
            predioActual.copyWith(
              pdfUrl: url,
              copFirmado: url,
              copFecha: now,
              updatedAt: now,
            ),
          );
    } else {
      await ref.read(prediosRepositoryProvider).updatePredio(
        widget.id!,
        {
          'pdf_url': url,
          'cop_firmado': url,
          'cop_fecha': now.toIso8601String(),
        },
      );
    }

    ref.invalidate(prediosListProvider);
    ref.invalidate(prediosMapaProvider);
    ref.invalidate(predioDetalleProvider(widget.id!));
    if (mounted) {
      setState(() {
        _pdfUrl = url;
        _copFecha = now;
      });
    }
  }

  Future<void> _pickAndUploadPdf() async {
    if (_uploadingPdf) return;
    if (widget.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guarda el predio primero para habilitar la carga del PDF.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );

    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudieron leer los bytes del PDF seleccionado.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    setState(() => _uploadingPdf = true);

    try {
      final extension = (file.extension?.isNotEmpty ?? false)
          ? file.extension!
          : 'pdf';
      final url = await ref.read(prediosRepositoryProvider).uploadPredioPdf(
            predioId: widget.id!,
            bytes: bytes,
            extension: extension,
          );
      await _persistPdfUrl(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF vinculado correctamente.'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingPdf = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final isDemo = ref.read(demoModeProvider);
      final isEdit = widget.id != null;
      final isLocalPredio = isEdit && widget.id!.startsWith('local-');
      final estatusLiberado = _estatusPredio == 'Liberado';
      final estatusNoLiberado = _estatusPredio == 'No liberado';

      if (isDemo && isEdit) {
        // En modo demo: actualizar estado local
        final predioActual = ref
            .read(demoPrediosNotifierProvider)
            .firstWhere((p) => p.id == widget.id);
        final actualizado = predioActual.copyWith(
          claveCatastral: _claveCtrl.text.trim(),
          tramo: _tramo,
          tipoPropiedad: _tipoPropiedad,
          ejido: _ejidoCtrl.text.isEmpty ? null : _ejidoCtrl.text.trim(),
          kmInicio: _kmInicioCtrl.text.isEmpty ? null : double.tryParse(_kmInicioCtrl.text),
          kmFin: _kmFinCtrl.text.isEmpty ? null : double.tryParse(_kmFinCtrl.text),
          kmLineales: _kmLinealesCtrl.text.isEmpty ? null : double.tryParse(_kmLinealesCtrl.text),
          kmEfectivos: _kmEfectivosCtrl.text.isEmpty ? null : double.tryParse(_kmEfectivosCtrl.text),
          superficie: _superficieCtrl.text.isEmpty ? null : double.tryParse(_superficieCtrl.text),
          cop: estatusLiberado,
          copFirmado: _resolvedPdfUrl(),
          pdfUrl: _resolvedPdfUrl(),
          copFecha: _copFecha,
          poligonoDwg: _poligonoDwgCtrl.text.isEmpty ? null : _poligonoDwgCtrl.text.trim(),
          oficio: _oficioCtrl.text.isEmpty ? null : _oficioCtrl.text.trim(),
          situacionSocial: _situacionSocialCtrl.text.isEmpty ? null : _situacionSocialCtrl.text.trim(),
          poligonoInsertado: _poligonoInsertado,
          identificacion: _identificacion,
          levantamiento: _levantamiento,
          negociacion: estatusNoLiberado,
          latitud: _latCtrl.text.isEmpty ? null : double.tryParse(_latCtrl.text),
          longitud: _lngCtrl.text.isEmpty ? null : double.tryParse(_lngCtrl.text),
          propietarioNombre: _propietarioNombreCtrl.text.isEmpty ? null : _propietarioNombreCtrl.text.trim(),
          updatedAt: DateTime.now(),
        );
        ref.read(demoPrediosNotifierProvider.notifier).updatePredio(actualizado);
      } else if (isLocalPredio) {
        final localState = ref.read(localPrediosProvider);
        final predioActual = localState.firstWhere((p) => p.id == widget.id);
        final actualizado = predioActual.copyWith(
          claveCatastral: _claveCtrl.text.trim(),
          tramo: _tramo,
          tipoPropiedad: _tipoPropiedad,
          ejido: _ejidoCtrl.text.isEmpty ? null : _ejidoCtrl.text.trim(),
          kmInicio: _kmInicioCtrl.text.isEmpty ? null : double.tryParse(_kmInicioCtrl.text),
          kmFin: _kmFinCtrl.text.isEmpty ? null : double.tryParse(_kmFinCtrl.text),
          kmLineales: _kmLinealesCtrl.text.isEmpty ? null : double.tryParse(_kmLinealesCtrl.text),
          kmEfectivos: _kmEfectivosCtrl.text.isEmpty ? null : double.tryParse(_kmEfectivosCtrl.text),
          superficie: _superficieCtrl.text.isEmpty ? null : double.tryParse(_superficieCtrl.text),
          cop: estatusLiberado,
          copFirmado: _resolvedPdfUrl(),
          pdfUrl: _resolvedPdfUrl(),
          copFecha: _copFecha,
          poligonoDwg: _poligonoDwgCtrl.text.isEmpty ? null : _poligonoDwgCtrl.text.trim(),
          oficio: _oficioCtrl.text.isEmpty ? null : _oficioCtrl.text.trim(),
          situacionSocial: _situacionSocialCtrl.text.isEmpty ? null : _situacionSocialCtrl.text.trim(),
          poligonoInsertado: _poligonoInsertado,
          identificacion: _identificacion,
          levantamiento: _levantamiento,
          negociacion: estatusNoLiberado,
          latitud: _latCtrl.text.isEmpty ? null : double.tryParse(_latCtrl.text),
          longitud: _lngCtrl.text.isEmpty ? null : double.tryParse(_lngCtrl.text),
          propietarioNombre: _propietarioNombreCtrl.text.isEmpty ? null : _propietarioNombreCtrl.text.trim(),
          propietarioId: _propietarioId,
          updatedAt: DateTime.now(),
        );
        ref.read(localPrediosProvider.notifier).updatePredio(actualizado);
      } else {
        final data = {
          'clave_catastral': _claveCtrl.text.trim(),
          'tramo': _tramo,
          'tipo_propiedad': _tipoPropiedad,
          'ejido': _ejidoCtrl.text.isEmpty ? null : _ejidoCtrl.text.trim(),
          'km_inicio': _kmInicioCtrl.text.isEmpty ? null : double.tryParse(_kmInicioCtrl.text),
          'km_fin': _kmFinCtrl.text.isEmpty ? null : double.tryParse(_kmFinCtrl.text),
          'km_lineales': _kmLinealesCtrl.text.isEmpty ? null : double.tryParse(_kmLinealesCtrl.text),
          'km_efectivos': _kmEfectivosCtrl.text.isEmpty ? null : double.tryParse(_kmEfectivosCtrl.text),
          'superficie': _superficieCtrl.text.isEmpty ? null : double.tryParse(_superficieCtrl.text),
          'cop': estatusLiberado,
          'cop_firmado': _resolvedPdfUrl(),
          'pdf_url': _resolvedPdfUrl(),
          'cop_fecha': _copFecha?.toIso8601String(),
          'poligono_dwg': _poligonoDwgCtrl.text.isEmpty ? null : _poligonoDwgCtrl.text.trim(),
          'oficio': _oficioCtrl.text.isEmpty ? null : _oficioCtrl.text.trim(),
          'situacion_social': _situacionSocialCtrl.text.isEmpty ? null : _situacionSocialCtrl.text.trim(),
          'poligono_insertado': _poligonoInsertado,
          'identificacion': _identificacion,
          'levantamiento': _levantamiento,
          'negociacion': estatusNoLiberado,
          'latitud': _latCtrl.text.isEmpty ? null : double.tryParse(_latCtrl.text),
          'longitud': _lngCtrl.text.isEmpty ? null : double.tryParse(_lngCtrl.text),
          'propietario_nombre': _propietarioNombreCtrl.text.isEmpty ? null : _propietarioNombreCtrl.text.trim(),
          'propietario_id': _propietarioId,
        };

        final repo = ref.read(prediosRepositoryProvider);
        if (!isEdit) {
          await repo.createPredio(data);
        } else {
          await repo.updatePredio(widget.id!, data);
        }
      }

      ref.invalidate(prediosListProvider);
      ref.invalidate(prediosMapaProvider);
      if (widget.id != null) ref.invalidate(predioDetalleProvider(widget.id!));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.exitoGuardar),
            backgroundColor: AppColors.secondary,
          ),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/predios');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.id == null ? AppStrings.nuevoPredio : AppStrings.editarPredio;

    if (_loadingData) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(AppStrings.guardar, style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Identificacion LDDV', Icons.description_outlined),
              const SizedBox(height: 12),
              TextFormField(
                controller: _claveCtrl,
                decoration: const InputDecoration(labelText: 'Clave Catastral (ID SEDATU)', prefixIcon: Icon(Icons.tag)),
                validator: (v) => (v == null || v.isEmpty) ? 'Campo requerido' : null,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _tramoTipo,
                    decoration: const InputDecoration(labelText: 'T/F/S', prefixIcon: Icon(Icons.route)),
                    items: const ['TRAMO', 'FRENTE', 'SEGMENTO']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _tramoTipo = v ?? _tramoTipo;
                      _tramo = _buildTramoValue();
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _tramoNumero,
                    decoration: const InputDecoration(labelText: 'Numero'),
                    items: const ['1', '2', '3', '4', '5']
                        .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _tramoNumero = v ?? _tramoNumero;
                      _tramo = _buildTramoValue();
                    }),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                    value: _tipoPropiedad,
                    decoration: const InputDecoration(labelText: 'Tipo Propiedad'),
                    items: ['SOCIAL','DOMINIO PLENO','PRIVADA'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => _tipoPropiedad = v ?? _tipoPropiedad),
                  ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _ejidoCtrl,
                decoration: const InputDecoration(labelText: 'Ejido', prefixIcon: Icon(Icons.agriculture_outlined)),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Cadenamiento (km)', Icons.linear_scale),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _kmInicioCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'km Inicio'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _kmFinCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'km Fin'))),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: TextFormField(controller: _kmLinealesCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'km Lineales'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _kmEfectivosCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'km Efectivos'))),
              ]),
              const SizedBox(height: 14),
              TextFormField(
                controller: _superficieCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Superficie DDV (m2)', prefixIcon: Icon(Icons.square_foot)),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Propietario', Icons.person_outline),
              const SizedBox(height: 12),
              TextFormField(
                controller: _propietarioNombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre del Propietario', prefixIcon: Icon(Icons.person)),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Documentos', Icons.folder_outlined),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.description,
                          color: _resolvedPdfUrl() != null
                              ? AppColors.secondary
                              : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'COP/DOT PDF',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _resolvedPdfUrl() != null
                                    ? 'Documento vinculado al expediente.'
                                    : 'No hay PDF cargado para este predio.',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _uploadingPdf ? null : _pickAndUploadPdf,
                          icon: _uploadingPdf
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(_resolvedPdfUrl() == null
                                  ? Icons.upload_file
                                  : Icons.sync),
                          label: Text(_resolvedPdfUrl() == null
                              ? 'Subir PDF'
                              : 'Actualizar PDF'),
                        ),
                        if (_resolvedPdfUrl() != null)
                          OutlinedButton.icon(
                            onPressed: () => _openPdf(_resolvedPdfUrl()!),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Abrir PDF'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(controller: _oficioCtrl, decoration: const InputDecoration(labelText: 'Oficio', prefixIcon: Icon(Icons.mail_outlined))),
              const SizedBox(height: 14),
              TextFormField(
                controller: _situacionSocialCtrl,
                decoration: const InputDecoration(
                  labelText: 'Situacion social',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Georeferencia', Icons.gps_fixed),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(
                  controller: _latCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'Latitud'),
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      final d = double.tryParse(v);
                      if (d == null || d < -90 || d > 90) return 'Invalida';
                    }
                    return null;
                  },
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  controller: _lngCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'Longitud'),
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      final d = double.tryParse(v);
                      if (d == null || d < -180 || d > 180) return 'Invalida';
                    }
                    return null;
                  },
                )),
              ]),
              const SizedBox(height: 24),
              _buildSectionTitle('Estatus del Predio', Icons.flag_outlined),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _estatusPredio,
                decoration: const InputDecoration(
                  labelText: 'Estatus',
                  prefixIcon: Icon(Icons.verified_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'Liberado', child: Text('Liberado')),
                  DropdownMenuItem(value: 'No liberado', child: Text('No liberado')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _estatusPredio = v;
                    _cop = v == 'Liberado';
                    _negociacion = v == 'No liberado';
                  });
                },
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Avance DDV', Icons.checklist_outlined),
              const SizedBox(height: 8),
              CheckboxListTile(title: const Text('Identificacion'), value: _identificacion, onChanged: (v) => setState(() => _identificacion = v ?? false), dense: true),
              CheckboxListTile(title: const Text('Levantamiento'), value: _levantamiento, onChanged: (v) => setState(() => _levantamiento = v ?? false), dense: true),
              CheckboxListTile(
                title: const Text('Negociacion'),
                value: _negociacion,
                onChanged: (v) => setState(() {
                  _negociacion = v ?? false;
                  if (_negociacion) {
                    _cop = false;
                    _estatusPredio = 'No liberado';
                  }
                }),
                dense: true,
              ),
              CheckboxListTile(
                title: const Text('COP firmado'),
                value: _cop,
                onChanged: (v) => setState(() {
                  _cop = v ?? false;
                  if (_cop) {
                    _negociacion = false;
                    _estatusPredio = 'Liberado';
                  } else {
                    _estatusPredio = 'No liberado';
                  }
                }),
                dense: true,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(widget.id == null ? 'Crear Predio' : 'Actualizar Predio'),
                  onPressed: _loading ? null : _submit,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
