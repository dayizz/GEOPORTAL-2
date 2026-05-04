// ⚠️ CONFIGURACIÓN DE SUPABASE
// Reemplaza estos valores con los de tu proyecto en https://supabase.com
// Ve a: Settings > API > Project URL y Project API Keys

class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://TU_PROJECT_ID.supabase.co';
  static const String anonKey = 'TU_ANON_KEY_AQUI';

  static bool get isConfigured {
    final normalizedUrl = url.trim().toLowerCase();
    final normalizedAnonKey = anonKey.trim().toLowerCase();

    return normalizedUrl.isNotEmpty &&
        normalizedAnonKey.isNotEmpty &&
        !normalizedUrl.contains('tu_project_id') &&
        !normalizedAnonKey.contains('tu_anon_key');
  }
}
