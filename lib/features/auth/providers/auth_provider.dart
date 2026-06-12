import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/auth_local.dart';

final proyectoActivoProvider = StateProvider<String?>((ref) => null);
final localAuthSessionProvider = StateProvider<bool>((ref) => false);

final authStateProvider = StreamProvider<String?>((ref) {
  final isLoggedIn = ref.watch(localAuthSessionProvider);
  return Stream.value(isLoggedIn ? localAdminEmail : null);
});

final currentUserProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(
    data: (user) => user,
  );
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

class AuthRepository {
    Future<void> signOut() async {
      // No-op para compatibilidad con UI.
    }
  Future<void> signInWithEmail(String email, String password) async {
    if (email.trim().toLowerCase() == localAdminEmail &&
        password == localAdminPassword) {
      return;
    }
    throw Exception('Credenciales locales inválidas.');
  }
}
