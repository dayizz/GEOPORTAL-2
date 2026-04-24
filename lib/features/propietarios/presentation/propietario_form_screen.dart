import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/propietarios_provider.dart';
import '../data/propietarios_repository.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

class PropietarioFormScreen extends ConsumerStatefulWidget {
  final String? id;
  const PropietarioFormScreen({super.key, this.id});

  @override
  ConsumerState<PropietarioFormScreen> createState() => _PropietarioFormScreenState();
}

class _PropietarioFormScreenState extends ConsumerState<PropietarioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _loadingData = true;

  final _nombreCtrl = TextEditingController();
  final _apellidosCtrl = TextEditingController();
  final _razonSocialCtrl = TextEditingController();
  final _curpCtrl = TextEditingController();
  final _rfcCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();

  String _tipoPersona = 'fisica';

  @override
  void initState() {
    super.initState();
    if (widget.id != null) {
      _loadPropietario();
    } else {
      _loadingData = false;
    }
  }

  Future<void> _loadPropietario() async {
    try {
      final p =
          await ref.read(propietariosRepositoryProvider).getPropietarioById(widget.id!);
      if (p != null && mounted) {
        _tipoPersona = p.tipoPersona;
        _nombreCtrl.text = p.nombre;
        _apellidosCtrl.text = p.apellidos;
        _razonSocialCtrl.text = p.razonSocial ?? '';
        _curpCtrl.text = p.curp ?? '';
        _rfcCtrl.text = p.rfc ?? '';
        _telCtrl.text = p.telefono ?? '';
        _correoCtrl.text = p.correo ?? '';
      }
    } finally {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nombreCtrl, _apellidosCtrl, _razonSocialCtrl, _curpCtrl,
      _rfcCtrl, _telCtrl, _correoCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final data = {
        'nombre': _nombreCtrl.text.trim(),
        'apellidos': _apellidosCtrl.text.trim(),
        'tipo_persona': _tipoPersona,
        'razon_social': _razonSocialCtrl.text.isEmpty ? null : _razonSocialCtrl.text.trim(),
        'curp': _curpCtrl.text.isEmpty ? null : _curpCtrl.text.trim().toUpperCase(),
        'rfc': _rfcCtrl.text.isEmpty ? null : _rfcCtrl.text.trim().toUpperCase(),
        'telefono': _telCtrl.text.isEmpty ? null : _telCtrl.text.trim(),
        'correo': _correoCtrl.text.isEmpty ? null : _correoCtrl.text.trim().toLowerCase(),
      };

      final repo = ref.read(propietariosRepositoryProvider);
      if (widget.id == null) {
        await repo.createPropietario(data);
      } else {
        await repo.updatePropietario(widget.id!, data);
      }

      ref.invalidate(propietariosListProvider);

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
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.id == null
        ? AppStrings.nuevoPropietario
        : AppStrings.editarPropietario;

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
                    width: 20, height: 20,
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
              // Tipo persona
              Text('Tipo de Persona', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildTipoCard(
                      'fisica',
                      Icons.person,
                      'Persona Física',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTipoCard(
                      'moral',
                      Icons.business,
                      'Persona Moral',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_tipoPersona == 'moral') ...[
                TextFormField(
                  controller: _razonSocialCtrl,
                  decoration: const InputDecoration(
                    labelText: AppStrings.razonSocial,
                    prefixIcon: Icon(Icons.business),
                  ),
                  validator: (v) => _tipoPersona == 'moral' && (v == null || v.isEmpty)
                      ? 'Campo requerido para persona moral'
                      : null,
                ),
                const SizedBox(height: 14),
              ],

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: AppStrings.nombre,
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Campo requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _apellidosCtrl,
                      decoration: const InputDecoration(labelText: AppStrings.apellidos),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _curpCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: AppStrings.curp),
                      validator: (v) {
                        if (v != null && v.isNotEmpty && v.length != 18) {
                          return 'CURP debe tener 18 caracteres';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _rfcCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: AppStrings.rfc),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _telCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: AppStrings.telefono,
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _correoCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: AppStrings.correoContacto,
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                      return 'Correo inválido';
                    }
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: Text(widget.id == null ? 'Crear Propietario' : 'Actualizar Propietario'),
                onPressed: _loading ? null : _submit,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipoCard(String tipo, IconData icon, String label) {
    final selected = _tipoPersona == tipo;
    return InkWell(
      onTap: () => setState(() => _tipoPersona = tipo),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.1) : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.textSecondary, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
