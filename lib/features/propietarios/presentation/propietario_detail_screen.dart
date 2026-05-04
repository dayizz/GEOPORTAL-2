import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/propietarios_provider.dart';
import '../data/propietarios_repository.dart';
import '../../mapa/providers/mapa_provider.dart';
import '../../predios/models/predio.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

class PropietarioDetailScreen extends ConsumerWidget {
  final String id;
  const PropietarioDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propietarioAsync = ref.watch(propietarioDetalleProvider(id));
    final prediosAsync = ref.watch(prediosPorPropietarioProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle Propietario'),
        actions: [
          propietarioAsync.whenOrNull(
                data: (p) => p != null
                    ? IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => context.push('/propietarios/$id/editar'),
                      )
                    : null,
              ) ??
              const SizedBox.shrink(),
          propietarioAsync.whenOrNull(
                data: (p) => p != null
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(context, ref),
                      )
                    : null,
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: propietarioAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (p) {
          if (p == null) return const Center(child: Text('Propietario no encontrado'));
          final esMoral = p.tipoPersona == 'moral';
          final color = esMoral ? AppColors.secondary : AppColors.primary;

          return SingleChildScrollView(
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  color: color.withOpacity(0.08),
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: color.withOpacity(0.2),
                        child: Icon(
                          esMoral ? Icons.business : Icons.person,
                          color: color,
                          size: 36,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.nombreCompleto,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Persona ${esMoral ? "Moral" : "Física"}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoSection(context, 'Datos Personales', Icons.badge_outlined, [
                        if (p.rfc != null) _buildRow('RFC', p.rfc!),
                        if (p.curp != null) _buildRow('CURP', p.curp!),
                        _buildRow(
                          'Registrado',
                          DateFormat('dd/MM/yyyy').format(p.createdAt),
                        ),
                      ]),
                      _buildInfoSection(context, 'Contacto', Icons.contact_phone_outlined, [
                        if (p.telefono != null) _buildRow('Teléfono', p.telefono!),
                        if (p.correo != null) _buildRow('Correo', p.correo!),
                      ]),
                      _buildPrediosVinculadosSection(context, ref, prediosAsync),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.list_alt),
                          label: const Text('Abrir gestión de predios'),
                          onPressed: () => context.go('/predios'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoSection(
      BuildContext context, String title, IconData icon, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: children.asMap().entries.map((e) {
                return Column(
                  children: [
                    e.value,
                    if (e.key < children.length - 1) const Divider(height: 1),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrediosVinculadosSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Predio>> prediosAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.home_work_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Predios vinculados', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: prediosAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error cargando predios: $e'),
              ),
              data: (predios) {
                if (predios.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Este propietario aún no tiene predios vinculados.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  );
                }

                return Column(
                  children: List.generate(predios.length, (index) {
                    final predio = predios[index];
                    final tieneGeometria =
                        predio.geometry != null ||
                        (predio.latitud != null && predio.longitud != null);

                    return Column(
                      children: [
                        ListTile(
                          dense: true,
                          title: Text(
                            predio.claveCatastral,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          subtitle: Text(
                            '${predio.tramo} · ${predio.tipoPropiedad}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          trailing: Tooltip(
                            message: tieneGeometria
                                ? 'Ver en mapa'
                                : 'Predio sin geometría',
                            child: IconButton(
                              icon: Icon(
                                Icons.map_outlined,
                                color: tieneGeometria
                                    ? AppColors.secondary
                                    : AppColors.textLight,
                              ),
                              onPressed: tieneGeometria
                                  ? () {
                                      ref.read(focusPredioIdProvider.notifier).state = predio.id;
                                      context.go('/mapa');
                                    }
                                  : null,
                            ),
                          ),
                        ),
                        if (index < predios.length - 1) const Divider(height: 1),
                      ],
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Propietario'),
        content: const Text(AppStrings.confirmacionEliminar),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancelar),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(AppStrings.eliminar),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await ref.read(propietariosRepositoryProvider).deletePropietario(id);
        ref.invalidate(propietariosListProvider);
        if (context.mounted) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(AppStrings.exitoEliminar),
              backgroundColor: AppColors.secondary,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
          );
        }
      }
    }
  }
}
