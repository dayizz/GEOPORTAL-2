import 'dart:typed_data';

import '../../../shared/services/backend_service.dart';

class ReporteService {
  const ReporteService();

  Future<ReportePdfResponse?> generarReporte(Map<String, dynamic> payload) async {
    return BackendService.generarReporte(payload);
  }
}