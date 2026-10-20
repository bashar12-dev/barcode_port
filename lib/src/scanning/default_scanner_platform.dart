import 'package:flutter/foundation.dart';

import 'scanner_platform.dart';

/// Selects the native boundary only where the Android plugin can be available.
ScannerPlatform createDefaultScannerPlatform() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return BridgeScannerPlatform();
  }
  return const _KeyboardOnlyScannerPlatform();
}

// HID itself is implemented by HidScanner. This boundary makes the absence of
// native broadcasts explicit without probing unregistered platform channels.
final class _KeyboardOnlyScannerPlatform implements ScannerPlatform {
  const _KeyboardOnlyScannerPlatform();

  static UnsupportedError _unsupported() => UnsupportedError(
    'iMin broadcast input is available only on Android. '
    'Use ScannerMode.auto or ScannerMode.hid for keyboard-wedge input.',
  );

  @override
  Stream<String> barcodes() => const Stream<String>.empty();

  @override
  Future<bool> prefersNativeBroadcast() async => false;

  @override
  Future<bool> configureBroadcastOutput() async => throw _unsupported();

  @override
  Future<void> startListening() async => throw _unsupported();

  @override
  Future<void> stopListening() async {}
}
