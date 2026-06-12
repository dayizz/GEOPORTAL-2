import 'package:flutter_riverpod/flutter_riverpod.dart';

// Credenciales de prueba demo
const String demoEmail = 'demo@geoportal.mx';
const String demoPassword = 'demo1234';

final demoModeProvider = StateProvider<bool>((ref) => false);
