import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/predios_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../models/predio.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/app_scaffold.dart';

class PrediosListScreen extends ConsumerStatefulWidget {
  const PrediosListScreen({super.key});

  @override
  ConsumerState<PrediosListScreen> createState() => _PrediosListScreenState();
}

class _PrediosListScreenState extends ConsumerState<PrediosListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prediosAsync = ref.watch(prediosListProvider);
    final filtros = ref.watch(prediosFiltrosProvider);

    return AppScaffold(
      currentIndex: 1,
      title: AppStrings.predios,
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: () => _showFiltrosSheet(context),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Predio'),
        onPressed: () => context.push('/predios/nuevo'),
      ),
      child: Column(
        children: [
          // Barra de búsqueda
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por clave catastral, dirección...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              ref.read(prediosFiltrosProvider.notifier).state =
                                  filtros.copyWith(busqueda: '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) {
                    ref.read(prediosFiltrosProvider.notifier).state =
                        filtros.copyWith(busqueda: v);
                  },
                ),
                if (filtros.proyecto != null ||
                    filtros.usoSuelo != null ||
                    filtros.zona != null ||
                    (filtros.segmento?.trim().isNotEmpty ?? false)) ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (filtros.proyecto != null)
                          _buildFiltroChip(
                            'Proyecto: ${filtros.proyecto}',
                            () => ref.read(prediosFiltrosProvider.notifier).state =
                                filtros.copyWith(clearProyecto: true),
                          ),
                        if (filtros.usoSuelo != null)
                          _buildFiltroChip(
                            filtros.usoSuelo!,
                            () => ref.read(prediosFiltrosProvider.notifier).state =
                                filtros.copyWith(clearUsoSuelo: true),
                          ),
                        if (filtros.zona != null)
                          _buildFiltroChip(
                            'Zona: ${filtros.zona}',
                            () => ref.read(prediosFiltrosProvider.notifier).state =
                                filtros.copyWith(clearZona: true),
                          ),
                        if (filtros.segmento != null && filtros.segmento!.trim().isNotEmpty)
                          _buildFiltroChip(
                            'Segmento: ${filtros.segmento}',
                            () => ref.read(prediosFiltrosProvider.notifier).state =
                                filtros.copyWith(clearSegmento: true),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: prediosAsync.when(
              data: (predios) => predios.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: predios.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) => _buildPredioCard(predios[i]),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                    const SizedBox(height: 12),
                    Text(e.toString(), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.refresh(prediosListProvider),
                      child: const Text('Reintentar'),
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

  Widget _buildPredioCard(Predio predio) {
    final color = AppColors.tipoPropiedadColor(predio.tipoPropiedad);
    final estatus = predio.estatusGestion;
    final estatusColor = estatus == 'Liberado'
      ? AppColors.liberadoColor
      : estatus == 'No liberado'
        ? AppColors.noLiberadoColor
        : AppColors.textSecondary;
    final pct = (predio.porcentajeAvance * 100).round();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/predios/${predio.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.terrain, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      predio.nombrePropietario,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${predio.claveCatastral}  •  ${predio.tramo}${predio.ejido != null && predio.ejido != "-" ? "  •  ${predio.ejido}" : ""}',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildTag(estatus, estatusColor),
                        const SizedBox(width: 6),
                        _buildTag(predio.tipoPropiedad, color),
                        const SizedBox(width: 6),
                        if (predio.cop)
                          _buildTag('COP ✓', AppColors.secondary),
                        if (predio.superficie != null) ...[
                          const SizedBox(width: 6),
                          _buildTag(
                            '${NumberFormat('#,##0').format(predio.superficie)} m²',
                            AppColors.info,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Mini barra de avance
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: predio.porcentajeAvance,
                              backgroundColor: Colors.grey.shade200,
                              color: pct >= 80
                                  ? AppColors.secondary
                                  : pct >= 40
                                      ? AppColors.warning
                                      : AppColors.danger,
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$pct%',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.textLight, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFiltroChip(String label, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: onRemove,
        backgroundColor: AppColors.primary.withOpacity(0.1),
        side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 64, color: AppColors.textLight),
          const SizedBox(height: 16),
          Text(
            AppStrings.sinRegistros,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          const Text('Agrega el primer predio usando el botón +'),
        ],
      ),
    );
  }

  void _showFiltrosSheet(BuildContext context) {
    final filtros = ref.read(prediosFiltrosProvider);
    String? usoTmp = filtros.usoSuelo;
    String? zonaTmp = filtros.zona;
    String? proyectoTmp = filtros.proyecto;
    final segmentoCtrl = TextEditingController(text: filtros.segmento ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filtros', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              Text('Proyecto', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: ['TQI', 'TSNL', 'TAP', 'TQM'].map((proyecto) {
                  final selected = proyectoTmp == proyecto;
                  return FilterChip(
                    label: Text(proyecto),
                    selected: selected,
                    onSelected: (v) => setModalState(() => proyectoTmp = v ? proyecto : null),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Text('Segmento', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              TextField(
                controller: segmentoCtrl,
                decoration: const InputDecoration(
                  hintText: 'Ej. S1, SEGMENTO-2',
                  prefixIcon: Icon(Icons.route_outlined),
                ),
              ),
              const SizedBox(height: 20),
              Text('Tipo de Propiedad', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: ['SOCIAL', 'DOMINIO PLENO', 'PRIVADA'].map((tipo) {
                  final selected = usoTmp == tipo;
                  final color = AppColors.tipoPropiedadColor(tipo);
                  return FilterChip(
                    label: Text(tipo),
                    selected: selected,
                    selectedColor: color.withValues(alpha: 0.15),
                    onSelected: (v) => setModalState(() => usoTmp = v ? tipo : null),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Text('Tramo', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: ['T1', 'T2', 'T3', 'T4'].map((tramo) {
                  final selected = zonaTmp == tramo;
                  return FilterChip(
                    label: Text(tramo),
                    selected: selected,
                    onSelected: (v) => setModalState(() => zonaTmp = v ? tramo : null),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ref.read(prediosFiltrosProvider.notifier).state =
                            const PrediosFiltros();
                        segmentoCtrl.dispose();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Limpiar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final segmento = segmentoCtrl.text.trim();
                        ref.read(prediosFiltrosProvider.notifier).state =
                            filtros.copyWith(
                          usoSuelo: usoTmp,
                          zona: zonaTmp,
                          proyecto: proyectoTmp,
                          segmento: segmento.isEmpty ? null : segmento,
                          clearUsoSuelo: usoTmp == null,
                          clearZona: zonaTmp == null,
                          clearProyecto: proyectoTmp == null,
                          clearSegmento: segmento.isEmpty,
                        );
                        segmentoCtrl.dispose();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );
  }
}
