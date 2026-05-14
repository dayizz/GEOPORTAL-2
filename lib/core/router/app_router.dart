import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/providers/user_management_provider.dart';
import '../../features/estructura/presentation/estructura_screen.dart';
import '../../features/mapa/presentation/mapa_screen.dart';
import '../../features/perfil/presentation/perfil_screen.dart';
import '../../features/predios/presentation/predios_list_screen.dart';
import '../../features/predios/presentation/predio_detail_screen.dart';
import '../../features/predios/presentation/predio_form_screen.dart';
import '../../features/predios/presentation/proyectos_screen.dart';
import '../../features/propietarios/presentation/propietarios_list_screen.dart';
import '../../features/propietarios/presentation/propietario_form_screen.dart';
import '../../features/propietarios/presentation/propietario_detail_screen.dart';
import '../../features/reportes/presentation/reportes_screen.dart';
import '../../features/carga/presentation/carga_archivo_screen.dart';
import '../../features/tabla/presentation/tabla_screen.dart';
import '../../features/tabla/presentation/gestion_predio_detail_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Observar cambios de auth para refrescar el redirect
  ref.watch(authStateProvider);
  final user = ref.watch(currentUserProvider);
  final localSession = ref.watch(localAuthSessionProvider);
  final canAccessEstructura = ref.watch(canAccessEstructuraProvider);

  return GoRouter(
    initialLocation: '/mapa',
    redirect: (context, state) {
      final isLoggedIn = user != null || localSession;
      final isLoginRoute = state.matchedLocation == '/login';
      final isEstructuraRoute = state.matchedLocation.startsWith('/estructura');

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/mapa';
      if (isEstructuraRoute && !canAccessEstructura) return '/mapa';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        redirect: (_, __) => '/mapa',
      ),
      GoRoute(
        path: '/mapa',
        pageBuilder: (_, __) => const NoTransitionPage(
          child: MapaScreen(),
        ),
      ),
      GoRoute(
        path: '/predios',
        builder: (_, __) => const PrediosListScreen(),
        routes: [
          GoRoute(
            path: 'nuevo',
            builder: (_, __) => const PredioFormScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) => PredioDetailScreen(id: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'editar',
                builder: (_, state) => PredioFormScreen(
                  id: state.pathParameters['id'],
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/propietarios',
        builder: (_, __) => const PropietariosListScreen(),
        routes: [
          GoRoute(
            path: 'nuevo',
            builder: (_, __) => const PropietarioFormScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                PropietarioDetailScreen(id: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'editar',
                builder: (_, state) => PropietarioFormScreen(
                  id: state.pathParameters['id'],
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/reportes',
        pageBuilder: (_, __) => const NoTransitionPage(
          child: ReportesScreen(),
        ),
      ),
      GoRoute(
        path: '/carga',
        pageBuilder: (_, __) => const NoTransitionPage(
          child: CargaArchivoScreen(),
        ),
      ),
      GoRoute(
        path: '/tabla',
        pageBuilder: (_, __) => const NoTransitionPage(
          child: TablaScreen(),
        ),
        routes: [
          GoRoute(
            path: 'predio/:id',
            builder: (_, state) => GestionPredioDetailScreen(
              id: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/proyectos',
        builder: (_, __) => const ProyectosScreen(),
      ),
      GoRoute(
        path: '/perfil',
        pageBuilder: (_, __) => const NoTransitionPage(
          child: PerfilScreen(),
        ),
      ),
      GoRoute(
        path: '/estructura',
        pageBuilder: (_, __) => const NoTransitionPage(
          child: EstructuraScreen(),
        ),
      ),
    ],
  );
});
