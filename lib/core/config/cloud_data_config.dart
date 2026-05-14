import '../supabase/supabase_config.dart';

enum CloudBackend {
  none,
  firestore,
  supabase,
}

class CloudDataConfig {
  CloudDataConfig._();

  static const String _backendValue = String.fromEnvironment(
    'CLOUD_BACKEND',
    defaultValue: 'none',
  );

  static CloudBackend get backend {
    switch (_backendValue.trim().toLowerCase()) {
      case 'firestore':
        return CloudBackend.firestore;
      case 'supabase':
        return CloudBackend.supabase;
      default:
        return CloudBackend.none;
    }
  }

  static bool get isRemoteDataEnabled {
    switch (backend) {
      case CloudBackend.supabase:
        return SupabaseConfig.isConfigured;
      case CloudBackend.firestore:
        return false;
      case CloudBackend.none:
        return false;
    }
  }

  static bool get isFirestoreTarget => backend == CloudBackend.firestore;

  static String get targetLabel {
    switch (backend) {
      case CloudBackend.firestore:
        return 'Firestore';
      case CloudBackend.supabase:
        return 'Supabase';
      case CloudBackend.none:
        return 'sin backend cloud';
    }
  }

  static String get setupHint {
    switch (backend) {
      case CloudBackend.firestore:
        return 'Firestore será el backend cloud objetivo. La integración aún no está conectada en esta etapa local-first.';
      case CloudBackend.supabase:
        return 'Supabase no está configurado. Reemplaza la URL y la anon key reales en lib/core/supabase/supabase_config.dart.';
      case CloudBackend.none:
        return 'La app está operando en modo local-first sin backend cloud activo.';
    }
  }
}