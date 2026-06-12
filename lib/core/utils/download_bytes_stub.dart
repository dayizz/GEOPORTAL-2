import 'dart:typed_data';

Future<void> triggerBrowserDownload(Uint8List bytes, String fileName) async {
  // No-op on non-web platforms.
}
