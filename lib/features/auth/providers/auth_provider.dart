import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';

const bool localOnlyAuthMode = true;
const String localAdminEmail = 'admin@sao.mx';
const String localAdminPassword = 'admin123';

/// Mapeo de contraseña a código de proyecto.
const Map<String, String> proyectoPasswords = {
  'TQI123': 'TQI',
  'TSNL123': 'TSNL',
  'TQM123': 'TQM',
  'TAP123': 'TAP',
};

/// Devuelve el código de proyecto si la contraseña corresponde a uno, null si es admin general.
String? extractProyectoFromPassword(String password) {
  return proyectoPasswords[password];
}

/// Proyecto activo para la sesión actual (null = acceso total / admin)
final proyectoActivoProvider = StateProvider<String?>((ref) => null);

final localAuthSessionProvider = StateProvider<bool>((ref) => false);

bool get useSupabaseAuth => !localOnlyAuthMode && SupabaseConfig.isConfigured;

// Provider del usuario autenticado
final authStateProvider = StreamProvider<User?>((ref) {
  if (!useSupabaseAuth) {
    return Stream<User?>.value(null);
  }
  return Supabase.instance.client.auth.onAuthStateChange
      .map((state) => state.session?.user);
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(
    data: (user) => user,
  );
});

// Provider para operaciones de auth
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    useSupabaseAuth ? Supabase.instance.client : null,
  ),
);

class AuthRepository {
  final SupabaseClient? _client;

  AuthRepository(this._client);

  Future<void> signInWithEmail(String email, String password) async {
    if (localOnlyAuthMode) {
      if (email.trim().toLowerCase() == localAdminEmail &&
          password == localAdminPassword) {
        return;
      }
      throw Exception('Credenciales locales inválidas.');
    }

    // Local-only fallback credentials when Supabase is not configured.
    if (email.trim().toLowerCase() == localAdminEmail &&
        password == localAdminPassword) {
      return;
    }
    final client = _client;
    if (client == null) {
      throw Exception('Autenticación cloud no configurada.');
    }
    await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signUpWithEmail(String email, String password) async {
    if (localOnlyAuthMode) {
      throw Exception('Registro deshabilitado en modo local.');
    }

    if (email.trim().toLowerCase() == localAdminEmail &&
        password == localAdminPassword) {
      return;
    }
    final client = _client;
    if (client == null) {
      throw Exception('Autenticación cloud no configurada.');
    }
    await client.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    if (localOnlyAuthMode) return;
    final client = _client;
    if (client == null) return;
    await client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    if (localOnlyAuthMode) {
      throw Exception('Reset de contrasena no disponible en modo local');
    }
    final client = _client;
    if (client == null) {
      throw Exception('Autenticación cloud no configurada.');
    }
    await client.auth.resetPasswordForEmail(email);
  }

  User? get currentUser => _client?.auth.currentUser;
}
