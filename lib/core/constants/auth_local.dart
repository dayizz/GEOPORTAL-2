const bool localOnlyAuthMode = true;
const String localAdminEmail = 'admin@sao.mx';
const String localAdminPassword = 'admin123';

const Map<String, String> proyectoPasswords = {
  'TQI123': 'TQI',
  'TSNL123': 'TSNL',
  'TQM123': 'TQM',
  'TAP123': 'TAP',
};

String? extractProyectoFromPassword(String password) {
  return proyectoPasswords[password];
}
