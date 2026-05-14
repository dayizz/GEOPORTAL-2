import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/estructura_users_repository.dart';
import '../data/local_users_repository.dart';
import 'auth_provider.dart';

enum UserProfile { administrador, colaborador }

extension UserProfileLabel on UserProfile {
  String get label {
    switch (this) {
      case UserProfile.administrador:
        return 'Administrador';
      case UserProfile.colaborador:
        return 'Colaborador';
    }
  }
}

class UserAccount {
  final String id;
  final String nombre;
  final String correo;
  final UserProfile perfil;
  final String? proyecto;
  final DateTime ultimaOperacion;

  const UserAccount({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.perfil,
    this.proyecto,
    required this.ultimaOperacion,
  });

  UserAccount copyWith({
    String? id,
    String? nombre,
    String? correo,
    UserProfile? perfil,
    String? proyecto,
    bool clearProyecto = false,
    DateTime? ultimaOperacion,
  }) {
    return UserAccount(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      correo: correo ?? this.correo,
      perfil: perfil ?? this.perfil,
      proyecto: clearProyecto ? null : (proyecto ?? this.proyecto),
      ultimaOperacion: ultimaOperacion ?? this.ultimaOperacion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'correo': correo,
      'perfil': perfil.name,
      'proyecto': proyecto,
      'ultima_operacion': ultimaOperacion.toIso8601String(),
    };
  }

  factory UserAccount.fromMap(Map<String, dynamic> map) {
    final rawPerfil = (map['perfil'] as String?)?.trim().toLowerCase();
    final perfil = rawPerfil == UserProfile.administrador.name
        ? UserProfile.administrador
        : UserProfile.colaborador;
    final fecha = DateTime.tryParse((map['ultima_operacion'] ?? '').toString());
    return UserAccount(
      id: (map['id'] ?? '').toString(),
      nombre: (map['nombre'] ?? '').toString(),
      correo: (map['correo'] ?? '').toString().toLowerCase(),
      perfil: perfil,
      proyecto: map['proyecto']?.toString(),
      ultimaOperacion: fecha ?? DateTime.now(),
    );
  }
}

class UserManagementState {
  final List<UserAccount> usuarios;
  final String? currentUserId;

  const UserManagementState({
    required this.usuarios,
    this.currentUserId,
  });

  UserAccount? get currentUser {
    if (currentUserId == null) return null;
    for (final user in usuarios) {
      if (user.id == currentUserId) return user;
    }
    return null;
  }

  UserManagementState copyWith({
    List<UserAccount>? usuarios,
    String? currentUserId,
    bool clearCurrentUser = false,
  }) {
    return UserManagementState(
      usuarios: usuarios ?? this.usuarios,
      currentUserId: clearCurrentUser ? null : (currentUserId ?? this.currentUserId),
    );
  }
}

class UserManagementNotifier extends StateNotifier<UserManagementState> {
  UserManagementNotifier(this._localRepository, this._remoteRepository)
      : super(
          UserManagementState(
            usuarios: [
              UserAccount(
                id: 'admin-global',
                nombre: 'Administrador General',
                correo: localAdminEmail,
                perfil: UserProfile.administrador,
                proyecto: null,
                ultimaOperacion: DateTime.now(),
              ),
            ],
            currentUserId: null,
          ),
        ) {
    _hydrate();
  }

  final LocalUsersRepository _localRepository;
  final EstructuraUsersRepository _remoteRepository;

  String _buildId({
    required String correo,
    required UserProfile perfil,
    String? proyecto,
  }) {
    final keyProyecto = (proyecto ?? 'global').toUpperCase();
    return '${correo.toLowerCase()}|${perfil.name}|$keyProyecto';
  }

  Future<void> _hydrate() async {
    final remoteUsers = await _safeRemoteLoad();
    if (remoteUsers.isNotEmpty) {
      if (!mounted) return;
      state = state.copyWith(usuarios: remoteUsers);
      await _persistLocal();
      return;
    }

    final loaded = await _localRepository.loadUsers();
    if (loaded.isEmpty) {
      await _persistLocal();
      return;
    }

    final users = loaded
        .map((e) => UserAccount.fromMap(e))
        .where((u) => u.id.isNotEmpty && u.correo.isNotEmpty)
        .toList(growable: false);
    if (users.isEmpty) return;

    if (!mounted) return;
    state = state.copyWith(usuarios: users);
    unawaited(_syncAllRemote());
  }

  Future<List<UserAccount>> _safeRemoteLoad() async {
    try {
      final rows = await _remoteRepository.getUsers();
      return rows
          .map((e) => UserAccount.fromMap(e))
          .where((u) => u.id.isNotEmpty && u.correo.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persistLocal() async {
    await _localRepository.saveUsers(
      state.usuarios.map((u) => u.toMap()).toList(growable: false),
    );
  }

  Future<void> _syncAllRemote() async {
    for (final user in state.usuarios) {
      await _safeRemoteUpsert(user);
    }
  }

  Future<void> _safeRemoteUpsert(UserAccount user) async {
    try {
      await _remoteRepository.upsertUser(user.toMap());
    } catch (_) {
      // Ignorar para mantener funcionamiento local sin bloquear UI.
    }
  }

  Future<void> _safeRemoteDelete(String id) async {
    try {
      await _remoteRepository.deleteUser(id);
    } catch (_) {
      // Ignorar para mantener funcionamiento local sin bloquear UI.
    }
  }

  void setCurrentSessionUser({
    required String correo,
    required String nombre,
    required UserProfile perfil,
    String? proyecto,
  }) {
    final now = DateTime.now();
    final id = _buildId(correo: correo, perfil: perfil, proyecto: proyecto);
    final nuevo = UserAccount(
      id: id,
      nombre: nombre,
      correo: correo.toLowerCase(),
      perfil: perfil,
      proyecto: perfil == UserProfile.administrador ? null : proyecto,
      ultimaOperacion: now,
    );

    final usuarios = List<UserAccount>.from(state.usuarios);
    final index = usuarios.indexWhere((u) => u.id == id);
    if (index >= 0) {
      usuarios[index] = nuevo;
    } else {
      usuarios.insert(0, nuevo);
    }

    state = state.copyWith(usuarios: usuarios, currentUserId: id);
    unawaited(_persistLocal());
    unawaited(_safeRemoteUpsert(nuevo));
  }

  void updateUser(UserAccount updated) {
    final usuarios = state.usuarios
        .map(
          (u) => u.id == updated.id
              ? updated.copyWith(
                  proyecto: updated.perfil == UserProfile.administrador
                      ? null
                      : updated.proyecto,
                )
              : u,
        )
        .toList(growable: false);
    state = state.copyWith(usuarios: usuarios);
      unawaited(_persistLocal());
      unawaited(_safeRemoteUpsert(updated));
  }

  bool addUser({
    required String nombre,
    required String correo,
    required UserProfile perfil,
    String? proyecto,
  }) {
    final cleanCorreo = correo.trim().toLowerCase();
    if (cleanCorreo.isEmpty) return false;
    final cleanNombre = nombre.trim().isEmpty ? cleanCorreo : nombre.trim();
    final cleanProyecto = proyecto?.trim().toUpperCase();
    final id = _buildId(correo: cleanCorreo, perfil: perfil, proyecto: cleanProyecto);
    final exists = state.usuarios.any((u) => u.id == id || u.correo == cleanCorreo);
    if (exists) return false;

    final nuevo = UserAccount(
      id: id,
      nombre: cleanNombre,
      correo: cleanCorreo,
      perfil: perfil,
      proyecto: perfil == UserProfile.administrador ? null : cleanProyecto,
      ultimaOperacion: DateTime.now(),
    );
    state = state.copyWith(usuarios: [nuevo, ...state.usuarios]);
    unawaited(_persistLocal());
    unawaited(_safeRemoteUpsert(nuevo));
    return true;
  }

  bool deleteUser(String id) {
    if (state.currentUserId == id) return false;
    final next = state.usuarios.where((u) => u.id != id).toList(growable: false);
    if (next.length == state.usuarios.length) return false;
    state = state.copyWith(usuarios: next);
    unawaited(_persistLocal());
    unawaited(_safeRemoteDelete(id));
    return true;
  }

  void markCurrentUserOperation() {
    final current = state.currentUser;
    if (current == null) return;
    updateUser(current.copyWith(ultimaOperacion: DateTime.now()));
  }

  void clearSession() {
    state = state.copyWith(clearCurrentUser: true);
  }
}

final userManagementProvider =
    StateNotifierProvider<UserManagementNotifier, UserManagementState>(
  (ref) => UserManagementNotifier(
    ref.watch(localUsersRepositoryProvider),
    ref.watch(estructuraUsersRepositoryProvider),
  ),
);

final currentAppUserProvider = Provider<UserAccount?>((ref) {
  return ref.watch(userManagementProvider).currentUser;
});

final canAccessEstructuraProvider = Provider<bool>((ref) {
  final current = ref.watch(currentAppUserProvider);
  return current?.perfil == UserProfile.administrador;
});
