import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/pdf_ocr_service.dart';

/// Provider para acceder al servicio de OCR del PDF
final pdfOcrServiceProvider = Provider<PdfOcrService>(
  (ref) => PdfOcrService(),
);

/// Estado de extracción de datos del PDF
class OcrExtractionState {
  final bool isLoading;
  final PdfOcrData? data;
  final String? error;

  OcrExtractionState({
    this.isLoading = false,
    this.data,
    this.error,
  });

  OcrExtractionState copyWith({
    bool? isLoading,
    PdfOcrData? data,
    String? error,
  }) {
    return OcrExtractionState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error ?? this.error,
    );
  }
}

class OcrExtractionNotifier extends StateNotifier<OcrExtractionState> {
  final PdfOcrService _service;

  OcrExtractionNotifier(this._service)
      : super(OcrExtractionState());

  Future<void> extractFromGoogleDriveUrl(String url) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _service.extractFromGoogleDriveUrl(url);
      state = state.copyWith(
        isLoading: false,
        data: data,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void reset() {
    state = OcrExtractionState();
  }
}

/// Provider para el estado de extracción de OCR
final ocrExtractionProvider =
    StateNotifierProvider<OcrExtractionNotifier, OcrExtractionState>(
  (ref) {
    final service = ref.watch(pdfOcrServiceProvider);
    return OcrExtractionNotifier(service);
  },
);
