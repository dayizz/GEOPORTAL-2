class BackendConfig {
  BackendConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static bool get isLocalhost {
    final normalized = baseUrl.trim().toLowerCase();
    return normalized.contains('localhost') || normalized.contains('127.0.0.1');
  }
}