class GoogleSheetsConfig {
  GoogleSheetsConfig._();

  /// Activa el uso de Google Sheets como base de datos principal.
    static const bool enabled = false;

  /// URL del Web App desplegado en Apps Script.
  static const String webAppUrl =
      'https://script.google.com/macros/s/AKfycbwbTUDVObvIjp0bYC7Q0TUMquMG7vO4CKVh6lFPMOmUKPlu8uCSU8ydkZD_WkABmseC/exec';

  /// Script ID (opcional en algunas implementaciones, se envía por compatibilidad).
  static const String scriptId =
      'AKfycbwbTUDVObvIjp0bYC7Q0TUMquMG7vO4CKVh6lFPMOmUKPlu8uCSU8ydkZD_WkABmseC';
}