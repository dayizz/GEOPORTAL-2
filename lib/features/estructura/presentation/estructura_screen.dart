import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/user_management_provider.dart';
import '../../../shared/widgets/app_scaffold.dart';

class EstructuraScreen extends ConsumerWidget {
  const EstructuraScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userManagementProvider);
    final usuarios = state.usuarios;
    final currentUserId = state.currentUserId;

    return AppScaffold(
      currentIndex: 5,
      title: 'Estructura',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Control de usuarios',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: () => _createUser(context, ref),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Nuevo usuario'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: usuarios.isEmpty
                  ? const Center(child: Text('No hay usuarios registrados.'))
                  : Card(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Nombre')),
                            DataColumn(label: Text('Correo')),
                            DataColumn(label: Text('Perfil')),
                            DataColumn(label: Text('Proyecto')),
                            DataColumn(label: Text('Acciones')),
                          ],
                          rows: usuarios
                              .map(
                                (user) => DataRow(
                                  cells: [
                                    DataCell(Text(user.nombre)),
                                    DataCell(Text(user.correo)),
                                    DataCell(Text(user.perfil.label)),
                                    DataCell(Text(user.proyecto ?? 'Todos')),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Editar usuario',
                                            icon: const Icon(Icons.edit_outlined),
                                            onPressed: () => _editUser(context, ref, user),
                                          ),
                                          IconButton(
                                            tooltip: user.id == currentUserId
                                                ? 'No puedes eliminar tu sesión actual'
                                                : 'Eliminar usuario',
                                            icon: const Icon(Icons.delete_outline),
                                            onPressed: user.id == currentUserId
                                                ? null
                                                : () => _deleteUser(context, ref, user),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createUser(BuildContext context, WidgetRef ref) async {
    final nombreCtrl = TextEditingController();
    final correoCtrl = TextEditingController();
    var perfil = UserProfile.colaborador;
    final proyectoCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('Nuevo usuario'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: correoCtrl,
                      decoration: const InputDecoration(labelText: 'Correo'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<UserProfile>(
                      initialValue: perfil,
                      decoration: const InputDecoration(labelText: 'Perfil'),
                      items: const [
                        DropdownMenuItem(
                          value: UserProfile.administrador,
                          child: Text('Administrador'),
                        ),
                        DropdownMenuItem(
                          value: UserProfile.colaborador,
                          child: Text('Colaborador'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => perfil = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: proyectoCtrl,
                      enabled: perfil == UserProfile.colaborador,
                      decoration: const InputDecoration(
                        labelText: 'Proyecto',
                        hintText: 'Ej. TQI',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final ok = ref.read(userManagementProvider.notifier).addUser(
                          nombre: nombreCtrl.text,
                          correo: correoCtrl.text,
                          perfil: perfil,
                          proyecto: proyectoCtrl.text,
                        );
                    Navigator.of(dialogCtx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Usuario creado correctamente.'
                              : 'No se pudo crear. Verifica correo y duplicados.',
                        ),
                      ),
                    );
                  },
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editUser(BuildContext context, WidgetRef ref, UserAccount user) async {
    final nombreCtrl = TextEditingController(text: user.nombre);
    final correoCtrl = TextEditingController(text: user.correo);
    var perfil = user.perfil;
    final proyectoCtrl = TextEditingController(text: user.proyecto ?? '');

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('Editar usuario'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: correoCtrl,
                      decoration: const InputDecoration(labelText: 'Correo'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<UserProfile>(
                      initialValue: perfil,
                      decoration: const InputDecoration(labelText: 'Perfil'),
                      items: const [
                        DropdownMenuItem(
                          value: UserProfile.administrador,
                          child: Text('Administrador'),
                        ),
                        DropdownMenuItem(
                          value: UserProfile.colaborador,
                          child: Text('Colaborador'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => perfil = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: proyectoCtrl,
                      enabled: perfil == UserProfile.colaborador,
                      decoration: const InputDecoration(
                        labelText: 'Proyecto',
                        hintText: 'Ej. TQI',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    ref.read(userManagementProvider.notifier).updateUser(
                          user.copyWith(
                            nombre: nombreCtrl.text.trim().isEmpty
                                ? user.nombre
                                : nombreCtrl.text.trim(),
                            correo: correoCtrl.text.trim().isEmpty
                                ? user.correo
                                : correoCtrl.text.trim().toLowerCase(),
                            perfil: perfil,
                            clearProyecto: perfil == UserProfile.administrador,
                            proyecto: perfil == UserProfile.colaborador
                                ? (proyectoCtrl.text.trim().isEmpty
                                    ? null
                                    : proyectoCtrl.text.trim().toUpperCase())
                                : null,
                            ultimaOperacion: DateTime.now(),
                          ),
                        );
                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteUser(BuildContext context, WidgetRef ref, UserAccount user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text('¿Eliminar a ${user.nombre}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final ok = ref.read(userManagementProvider.notifier).deleteUser(user.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Usuario eliminado.' : 'No fue posible eliminar el usuario.',
        ),
      ),
    );
  }
}
