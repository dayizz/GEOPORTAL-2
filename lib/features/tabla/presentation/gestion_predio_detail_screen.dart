import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../predios/providers/predios_provider.dart';
import '../../predios/providers/demo_predios_notifier.dart';
import '../../predios/data/predios_repository.dart';
import '../../predios/models/predio.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../auth/providers/demo_provider.dart';

import '../../../shared/widgets/app_scaffold.dart';

class GestionPredioDetailScreen extends ConsumerWidget {
  final String id;
  const GestionPredioDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final predioAsync = ref.watch(predioDetalleProvider(id));
    final isDemo = ref.watch(demoModeProvider);

    return AppScaffold(
      currentIndex: 3,
      title: 'Detalle de Predio - Gestión',
      actions: [
        predioAsync.whenOrNull(
              data: (predio) => predio != null
                  ? IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => context.push('/predios/$id/editar'),
                    )
                  : null,
            ) ??
            const SizedBox.shrink(),
        if (!isDemo)
          predioAsync.whenOrNull(
                data: (predio) => predio != null
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(context, ref),
                      )
                    : null,
              ) ??
              const SizedBox.shrink(),
      ],
      floatingActionButton: predioAsync.whenOrNull(
        data: (predio) => predio != null
            ? FloatingActionButton.extended(
                icon: const Icon(Icons.checklist_rtl),
                label: const Text('Actualizar Avance'),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                onPressed: () => _showActualizarEtapasSheet(context, ref, predio),
              )
            : null,
      ),
      child: predioAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (predio) {
          if (predio == null) {
            return const Center(child: Text('Predio no encontrado'));
          }

          final color = AppColors.tipoPropiedadColor(predio.tipoPropiedad);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con tipo de propiedad y avance
                Container(
                  width: double.infinity,
                  color: color.withValues(alpha: 0.08),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.terrain, color: Colors.white, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  predio.claveCatastral,
                                  style: Theme.of(context).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _buildChip(predio.tipoPropiedad, color),
                                    const SizedBox(width: 8),
                                    _buildChip(predio.tramo, AppColors.info),
                                  ],
                                ),
                                if (predio.ejido != null && predio.ejido != '-') ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Ejido: ${predio.ejido}',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Barra de avance
                      _buildAvanceBar(context, predio.porcentajeAvance),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // KMs y M2
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              context,
                              Icons.straighten,
                              predio.kmLineales != null
                                  ? '${predio.kmLineales!.toStringAsFixed(4)} km'
                                  : '-',
                              'Km Lineales',
                              AppColors.info,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              context,
                              Icons.square_foot,
                              predio.superficie != null
                                  ? '${NumberFormat('#,##0.00').format(predio.superficie)} m²'
                                  : '-',
                              'Superficie DDV',
                              color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Tramo y COP
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              context,
                              Icons.route,
                              '${predio.kmInicio?.toStringAsFixed(3) ?? "-"} – ${predio.kmFin?.toStringAsFixed(3) ?? "-"}',
                              'Cadenamiento',
                              AppColors.secondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              context,
                              predio.cop ? Icons.check_circle : Icons.radio_button_unchecked,
                              predio.cop ? 'FIRMADO' : 'PENDIENTE',
                              'C.O.P.',
                              predio.cop ? AppColors.secondary : AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                      // Documentos
                      if (predio.poligonoDwg != null)
                        _buildInfoRow('Polígono DWG', predio.poligonoDwg!),
                      if (predio.oficio != null)
                        _buildInfoRow('Oficio', predio.oficio!),
                      if (predio.copFirmado == null && predio.poligonoDwg == null && predio.oficio == null)
                        _buildInfoRow('Estado', 'Sin documentos registrados'),
                    ],
                  ),
                ),

                // Propietario
                if (predio.propietario != null || predio.propietarioNombre != null)
                  _buildSection(
                    context,
                    'Propietario',
                    Icons.person_outline,
                    [
                      _buildInfoRow(
                        'Nombre',
                        predio.propietario?.nombreCompleto ?? predio.propietarioNombre ?? '-',
                      ),
                      if (predio.tipoPropiedad == 'SOCIAL' && predio.ejido != null)
                        _buildInfoRow('Ejido', predio.ejido!),
                      if (predio.propietario?.rfc != null)
                        _buildInfoRow('RFC', predio.propietario!.rfc!),
                      if (predio.propietario?.telefono != null &&
                          predio.propietario!.telefono!.isNotEmpty)
                        _buildInfoRow('Teléfono', predio.propietario!.telefono!),
                      if (predio.propietario?.correo != null &&
                          predio.propietario!.correo!.isNotEmpty)
                        _buildInfoRow('Correo', predio.propietario!.correo!),
                    ],
                    trailing: predio.propietario != null
                        ? TextButton.icon(
                            icon: const Icon(Icons.open_in_new, size: 14),
                            label: const Text('Ver propietario'),
                            onPressed: () => context
                                .push('/propietarios/${predio.propietario!.id}'),
                          )
                        : null,
                  ),

                // Coordenadas
                if (predio.latitud != null && predio.longitud != null)
                  _buildSection(
                    context,
                    'Georreferencia',
                    Icons.place_outlined,
                    [
                      _buildInfoRow(
                        'Coordenadas',
                        '${predio.latitud!.toStringAsFixed(6)}, ${predio.longitud!.toStringAsFixed(6)}',
                      ),
                    ],
                  ),

                // Metadatos
                _buildSection(
                  context,
                  'Registro',
                  Icons.info_outline,
                  [
                    _buildInfoRow(
                      'Registrado',
                      DateFormat('dd/MM/yyyy').format(predio.createdAt),
                    ),
                    if (predio.updatedAt != null)
                      _buildInfoRow(
                        'Actualizado',
                        DateFormat('dd/MM/yyyy').format(predio.updatedAt!),
                      ),
                  ],
                ),

                if (predio.latitud != null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Ver en Mapa'),
                      onPressed: () => context.go('/mapa'),
                    ),
                  ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Widget _buildAvanceBar(BuildContext context, double porcentaje) {
    final pct = (porcentaje * 100).round();
    final color = pct >= 80
        ? AppColors.secondary
        : pct >= 40
            ? AppColors.warning
            : AppColors.danger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Avance del proceso', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text('$pct%', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: porcentaje,
            backgroundColor: Colors.grey.shade200,
            color: color,
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(BuildContext context, IconData icon, String value,
      String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color),
          ),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildEtapaRow(String label, bool completado) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            completado ? Icons.check_circle : Icons.radio_button_unchecked,
            color: completado ? AppColors.secondary : Colors.grey.shade400,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: completado ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: completado ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          Text(
            completado ? 'Completado' : 'Pendiente',
            style: TextStyle(
              fontSize: 11,
              color: completado ? AppColors.secondary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children, {
    Widget? trailing,
  }) {
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
              if (trailing != null) ...[
                const Spacer(),
                trailing,
              ],
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
                final isLast = e.key == children.length - 1;
                return Column(
                  children: [
                    e.value,
                    if (!isLast) const Divider(height: 1),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  static void _showActualizarEtapasSheet(
    BuildContext context,
    WidgetRef ref,
    Predio predio,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool ident = predio.identificacion;
        bool levant = predio.levantamiento;
        bool negoc = predio.negociacion;
        bool cop = predio.cop;
        bool poli = predio.poligonoInsertado;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> save() async {
              final messenger = ScaffoldMessenger.of(context);
              final isDemo = ref.read(demoModeProvider);
              final actualizado = predio.copyWith(
                identificacion: ident,
                levantamiento: levant,
                negociacion: negoc,
                cop: cop,
                poligonoInsertado: poli,
                updatedAt: DateTime.now(),
              );
              if (isDemo) {
                ref
                    .read(demoPrediosNotifierProvider.notifier)
                    .updatePredio(actualizado);
              } else {
                await ref.read(prediosRepositoryProvider).updatePredio(
                  predio.id,
                  {
                    'identificacion': ident,
                    'levantamiento': levant,
                    'negociacion': negoc,
                    'cop': cop,
                    'poligono_insertado': poli,
                  },
                );
                ref.invalidate(predioDetalleProvider(predio.id));
              }
              ref.invalidate(prediosListProvider);
              ref.invalidate(prediosMapaProvider);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Avance actualizado'),
                  backgroundColor: AppColors.secondary,
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timeline, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Etapas de Avance',
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Text(
                    predio.claveCatastral,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const Divider(height: 24),
                  _buildEtapaSwitch(
                    ctx,
                    'Identificación / Acercamiento',
                    Icons.search,
                    ident,
                    (v) => setModalState(() => ident = v),
                  ),
                  _buildEtapaSwitch(
                    ctx,
                    'Levantamiento',
                    Icons.straighten,
                    levant,
                    (v) => setModalState(() => levant = v),
                  ),
                  _buildEtapaSwitch(
                    ctx,
                    'Negociación / Asamblea',
                    Icons.handshake_outlined,
                    negoc,
                    (v) => setModalState(() => negoc = v),
                  ),
                  _buildEtapaSwitch(
                    ctx,
                    'C.O.P. (Convenio de Ocupación)',
                    Icons.assignment_turned_in_outlined,
                    cop,
                    (v) => setModalState(() => cop = v),
                    activeColor: AppColors.secondary,
                  ),
                  _buildEtapaSwitch(
                    ctx,
                    'Polígono Insertado en Larguillo',
                    Icons.map_outlined,
                    poli,
                    (v) => setModalState(() => poli = v),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar cambios'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: save,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildEtapaSwitch(
    BuildContext context,
    String label,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged, {
    Color? activeColor,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(
        icon,
        color: value ? (activeColor ?? AppColors.primary) : Colors.grey.shade400,
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: value ? FontWeight.w600 : FontWeight.normal,
          color: value ? AppColors.textPrimary : AppColors.textSecondary,
        ),
      ),
      value: value,
      activeColor: activeColor ?? AppColors.primary,
      onChanged: onChanged,
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Predio'),
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
        await ref.read(prediosRepositoryProvider).deletePredio(id);
        ref.invalidate(prediosListProvider);
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
