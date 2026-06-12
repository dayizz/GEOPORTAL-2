import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_management_provider.dart';
import '../../../shared/widgets/app_scaffold.dart';

class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAppUserProvider);

    return AppScaffold(
      currentIndex: 4,
      title: 'Perfil',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: user == null
            ? const Center(child: Text('No hay datos de cuenta disponibles.'))
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                child: Text(
                                  user.nombre.isNotEmpty
                                      ? user.nombre[0].toUpperCase()
                                      : 'U',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  user.nombre,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _ProfileRow(label: 'Nombre', value: user.nombre),
                          _ProfileRow(label: 'Correo', value: user.correo),
                          _ProfileRow(label: 'Perfil', value: user.perfil.label),
                          _ProfileRow(label: 'Proyecto', value: user.proyecto ?? 'Todos'),
                          _ProfileRow(
                            label: 'Última operación',
                            value: _formatDateTime(user.ultimaOperacion),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.logout),
                              label: const Text('Cerrar sesión'),
                              onPressed: () => _signOut(context, ref),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authRepositoryProvider).signOut();
    ref.read(localAuthSessionProvider.notifier).state = false;
    ref.read(proyectoActivoProvider.notifier).state = null;
    ref.read(userManagementProvider.notifier).clearSession();
    if (context.mounted) {
      context.go('/login');
    }
  }

  String _formatDateTime(DateTime value) {
    final d = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
