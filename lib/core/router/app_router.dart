import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/providers/demo_provider.dart';
import '../../features/mapa/presentation/mapa_screen.dart';
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

final routerProvider = Provider<GoRouter>((ref) {
  // Observar cambios de auth para refrescar el redirect
  ref.watch(authStateProvider);
  final isDemo = ref.watch(demoModeProvider);

  return GoRouter(
    initialLocation: '/mapa',
    redirect: (context, state) {
      final user = Supabase.instance.client.auth.currentUser;
      final isLoggedIn = user != null || isDemo;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/mapa';
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
        builder: (_, __) => const MapaScreen(),
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
        builder: (_, __) => const ReportesScreen(),
      ),
      GoRoute(
        path: '/carga',
        builder: (_, __) => const CargaArchivoScreen(),
      ),
      GoRoute(
        path: '/tabla',
        builder: (_, __) => const TablaScreen(),
      ),
      GoRoute(
        path: '/proyectos',
        builder: (_, __) => const ProyectosScreen(),
      ),
    ],
  );
});
