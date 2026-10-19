import 'barcode_scan.dart';

/// Owns its input source. Multiple event listeners share each observed frame.
abstract interface class BarcodeScanner {
  Stream<BarcodeScan> get events;

  Future<void> start();

  /// Stops input and waits for any pending start. A later start is allowed.
  Future<void> stop();

  /// Permanently releases resources and closes events. May retry failed cleanup.
  Future<void> dispose();
}
