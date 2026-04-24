import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/propietarios_provider.dart';
import '../../../features/predios/models/propietario.dart';
import '../data/propietarios_repository.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/app_scaffold.dart';

class PropietariosListScreen extends ConsumerStatefulWidget {
  const PropietariosListScreen({super.key});

  @override
  ConsumerState<PropietariosListScreen> createState() =>
      _PropietariosListScreenState();
}

class _PropietariosListScreenState extends ConsumerState<PropietariosListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final propietariosAsync = ref.watch(propietariosListProvider);
    final proyectoFiltro = ref.watch(propietariosProyectoFiltroProvider);

    return AppScaffold(
      currentIndex: 2,
      title: AppStrings.propietarios,
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo Propietario'),
        onPressed: () => context.push('/propietarios/nuevo'),
      ),
      child: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, RFC, CURP...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              ref.read(propietariosFiltroProvider.notifier).state = '';
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) =>
                      ref.read(propietariosFiltroProvider.notifier).state = v,
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildProyectoChip(
                        label: 'Todos',
                        isSelected: proyectoFiltro == null,
                        onTap: () => ref.read(propietariosProyectoFiltroProvider.notifier).state = null,
                      ),
                      _buildProyectoChip(
                        label: 'TQI',
                        isSelected: proyectoFiltro == 'TQI',
                        onTap: () => ref.read(propietariosProyectoFiltroProvider.notifier).state = 'TQI',
                      ),
                      _buildProyectoChip(
                        label: 'TSNL',
                        isSelected: proyectoFiltro == 'TSNL',
                        onTap: () => ref.read(propietariosProyectoFiltroProvider.notifier).state = 'TSNL',
                      ),
                      _buildProyectoChip(
                        label: 'TAP',
                        isSelected: proyectoFiltro == 'TAP',
                        onTap: () => ref.read(propietariosProyectoFiltroProvider.notifier).state = 'TAP',
                      ),
                      _buildProyectoChip(
                        label: 'TQM',
                        isSelected: proyectoFiltro == 'TQM',
                        onTap: () => ref.read(propietariosProyectoFiltroProvider.notifier).state = 'TQM',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: propietariosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (propietarios) => propietarios.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: propietarios.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) =>
                          _buildPropietarioCard(propietarios[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropietarioCard(Propietario p) {
    final esMoral = p.tipoPersona == 'moral';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/propietarios/${p.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: esMoral
                    ? AppColors.secondary.withOpacity(0.15)
                    : AppColors.primary.withOpacity(0.15),
                child: Icon(
                  esMoral ? Icons.business : Icons.person,
                  color: esMoral ? AppColors.secondary : AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nombreCompleto,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (esMoral ? AppColors.secondary : AppColors.primary)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            esMoral ? 'Moral' : 'Física',
                            style: TextStyle(
                              fontSize: 11,
                              color: esMoral ? AppColors.secondary : AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (p.rfc != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            'RFC: ${p.rfc}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (p.correo != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        p.correo!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textLight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 64, color: AppColors.textLight),
          const SizedBox(height: 16),
          Text(
            AppStrings.sinRegistros,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          const Text('Registra el primer propietario con el botón +'),
        ],
      ),
    );
  }

  Widget _buildProyectoChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
