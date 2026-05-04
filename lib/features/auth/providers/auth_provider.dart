import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

// Provider del usuario autenticado
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(
    data: (state) => state.session?.user,
  );
});

// Provider para operaciones de auth
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(Supabase.instance.client),
);

class AuthRepository {
  final SupabaseClient _client;

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
    await _client.auth.signInWithPassword(
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
    await _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    if (localOnlyAuthMode) return;
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    if (localOnlyAuthMode) {
      throw Exception('Reset de contrasena no disponible en modo local');
    }
    await _client.auth.resetPasswordForEmail(email);
  }

  User? get currentUser => _client.auth.currentUser;
}
