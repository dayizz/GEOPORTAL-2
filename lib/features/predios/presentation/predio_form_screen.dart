import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/predios_provider.dart';
import '../providers/demo_predios_notifier.dart';
import '../data/predios_repository.dart';
import '../models/predio.dart';
import '../../auth/providers/demo_provider.dart';
import '../../propietarios/data/propietarios_repository.dart';
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
  final _copFirmadoCtrl = TextEditingController();
  final _poligonoDwgCtrl = TextEditingController();
  final _oficioCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _propietarioNombreCtrl = TextEditingController();

  String _tramo = 'T1';
  String _tipoPropiedad = 'PRIVADA';
  bool _cop = false;
  bool _poligonoInsertado = false;
  bool _identificacion = false;
  bool _levantamiento = false;
  bool _negociacion = false;
  String? _propietarioId;

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
      final predio = await ref.read(prediosRepositoryProvider).getPredioById(widget.id!);
      if (predio != null && mounted) {
        _claveCtrl.text = predio.claveCatastral;
        _ejidoCtrl.text = predio.ejido ?? '';
        _kmInicioCtrl.text = predio.kmInicio?.toString() ?? '';
        _kmFinCtrl.text = predio.kmFin?.toString() ?? '';
        _kmLinealesCtrl.text = predio.kmLineales?.toString() ?? '';
        _kmEfectivosCtrl.text = predio.kmEfectivos?.toString() ?? '';
        _superficieCtrl.text = predio.superficie?.toString() ?? '';
        _copFirmadoCtrl.text = predio.copFirmado ?? '';
        _poligonoDwgCtrl.text = predio.poligonoDwg ?? '';
        _oficioCtrl.text = predio.oficio ?? '';
        _latCtrl.text = predio.latitud?.toString() ?? '';
        _lngCtrl.text = predio.longitud?.toString() ?? '';
        _propietarioNombreCtrl.text = predio.propietarioNombre ?? '';
        _tramo = predio.tramo;
        _tipoPropiedad = predio.tipoPropiedad;
        _cop = predio.cop;
        _poligonoInsertado = predio.poligonoInsertado;
        _identificacion = predio.identificacion;
        _levantamiento = predio.levantamiento;
        _negociacion = predio.negociacion;
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
      _kmEfectivosCtrl, _superficieCtrl, _copFirmadoCtrl, _poligonoDwgCtrl,
      _oficioCtrl, _latCtrl, _lngCtrl, _propietarioNombreCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final isDemo = ref.read(demoModeProvider);

      if (isDemo && widget.id != null) {
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
          cop: _cop,
          copFirmado: _copFirmadoCtrl.text.isEmpty ? null : _copFirmadoCtrl.text.trim(),
          poligonoDwg: _poligonoDwgCtrl.text.isEmpty ? null : _poligonoDwgCtrl.text.trim(),
          oficio: _oficioCtrl.text.isEmpty ? null : _oficioCtrl.text.trim(),
          poligonoInsertado: _poligonoInsertado,
          identificacion: _identificacion,
          levantamiento: _levantamiento,
          negociacion: _negociacion,
          latitud: _latCtrl.text.isEmpty ? null : double.tryParse(_latCtrl.text),
          longitud: _lngCtrl.text.isEmpty ? null : double.tryParse(_lngCtrl.text),
          propietarioNombre: _propietarioNombreCtrl.text.isEmpty ? null : _propietarioNombreCtrl.text.trim(),
          updatedAt: DateTime.now(),
        );
        ref.read(demoPrediosNotifierProvider.notifier).updatePredio(actualizado);
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
          'cop': _cop,
          'cop_firmado': _copFirmadoCtrl.text.isEmpty ? null : _copFirmadoCtrl.text.trim(),
          'poligono_dwg': _poligonoDwgCtrl.text.isEmpty ? null : _poligonoDwgCtrl.text.trim(),
          'oficio': _oficioCtrl.text.isEmpty ? null : _oficioCtrl.text.trim(),
          'poligono_insertado': _poligonoInsertado,
          'identificacion': _identificacion,
          'levantamiento': _levantamiento,
          'negociacion': _negociacion,
          'latitud': _latCtrl.text.isEmpty ? null : double.tryParse(_latCtrl.text),
          'longitud': _lngCtrl.text.isEmpty ? null : double.tryParse(_lngCtrl.text),
          'propietario_nombre': _propietarioNombreCtrl.text.isEmpty ? null : _propietarioNombreCtrl.text.trim(),
          'propietario_id': _propietarioId,
        };

        final repo = ref.read(prediosRepositoryProvider);
        if (widget.id == null) {
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
        context.pop();
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
                    value: _tramo,
                    decoration: const InputDecoration(labelText: 'Tramo', prefixIcon: Icon(Icons.route)),
                    items: ['T1','T2','T3','T4'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => _tramo = v ?? _tramo),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _tipoPropiedad,
                    decoration: const InputDecoration(labelText: 'Tipo Propiedad'),
                    items: ['SOCIAL','DOMINIO PLENO','PRIVADA'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => _tipoPropiedad = v ?? _tipoPropiedad),
                  ),
                ),
              ]),
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
              const SizedBox(height: 12),
              _PropietarioSelector(selectedId: _propietarioId, onChanged: (id) => setState(() => _propietarioId = id)),
              const SizedBox(height: 24),
              _buildSectionTitle('Documentos', Icons.folder_outlined),
              const SizedBox(height: 12),
              TextFormField(controller: _copFirmadoCtrl, decoration: const InputDecoration(labelText: 'Archivo COP Firmado (PDF)', prefixIcon: Icon(Icons.picture_as_pdf_outlined))),
              const SizedBox(height: 14),
              TextFormField(controller: _poligonoDwgCtrl, decoration: const InputDecoration(labelText: 'Archivo Poligono DWG', prefixIcon: Icon(Icons.map_outlined))),
              const SizedBox(height: 14),
              TextFormField(controller: _oficioCtrl, decoration: const InputDecoration(labelText: 'Oficio', prefixIcon: Icon(Icons.mail_outlined))),
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
              _buildSectionTitle('Avance DDV', Icons.checklist_outlined),
              const SizedBox(height: 8),
              CheckboxListTile(title: const Text('Identificacion'), value: _identificacion, onChanged: (v) => setState(() => _identificacion = v ?? false), dense: true),
              CheckboxListTile(title: const Text('Levantamiento'), value: _levantamiento, onChanged: (v) => setState(() => _levantamiento = v ?? false), dense: true),
              CheckboxListTile(title: const Text('Negociacion'), value: _negociacion, onChanged: (v) => setState(() => _negociacion = v ?? false), dense: true),
              CheckboxListTile(title: const Text('COP firmado'), value: _cop, onChanged: (v) => setState(() => _cop = v ?? false), dense: true),
              CheckboxListTile(title: const Text('Poligono Insertado'), value: _poligonoInsertado, onChanged: (v) => setState(() => _poligonoInsertado = v ?? false), dense: true),
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

class _PropietarioSelector extends ConsumerStatefulWidget {
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _PropietarioSelector({required this.selectedId, required this.onChanged});

  @override
  ConsumerState<_PropietarioSelector> createState() => _PropietarioSelectorState();
}

class _PropietarioSelectorState extends ConsumerState<_PropietarioSelector> {
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final propietariosAsync = ref.watch(
      FutureProvider((ref) => ref
          .read(propietariosRepositoryProvider)
          .getPropietarios(busqueda: _busqueda)),
    );

    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: 'Buscar propietario...',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => _busqueda = v),
        ),
        const SizedBox(height: 8),
        propietariosAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(e.toString()),
          data: (propietarios) {
            if (propietarios.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    const Text('Sin propietarios registrados'),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Registrar propietario'),
                      onPressed: () => context.push('/propietarios/nuevo'),
                    ),
                  ],
                ),
              );
            }

            return Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListView.separated(
                itemCount: propietarios.length + 1,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  if (i == 0) {
                    return RadioListTile<String?>(
                      value: null,
                      groupValue: widget.selectedId,
                      onChanged: widget.onChanged,
                      title: const Text('Sin asignar'),
                      dense: true,
                    );
                  }
                  final p = propietarios[i - 1];
                  return RadioListTile<String?>(
                    value: p.id,
                    groupValue: widget.selectedId,
                    onChanged: widget.onChanged,
                    title: Text(p.nombreCompleto, style: const TextStyle(fontSize: 13)),
                    subtitle: p.rfc != null ? Text(p.rfc!, style: const TextStyle(fontSize: 11)) : null,
                    dense: true,
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
