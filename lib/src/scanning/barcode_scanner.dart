import 'barcode_scan.dart';

/// Owns an input source and exposes its observed frames.
///
/// Multiple event listeners share each observed frame.
abstract interface class BarcodeScanner {
  /// The broadcast stream of observations and operational errors.
  ///
  /// Subscribe before [start] to retain frames delivered during startup.
  Stream<BarcodeScan> get events;

  /// Starts reception or reports an acquisition/configuration failure.
  ///
  /// Already running sources ignore repeated starts. A disposed source throws
  /// [StateError]. Await the previous owner's [stop] before starting another.
  Future<void> start();

  /// Stops input and waits for any pending start. A later start is allowed.
  Future<void> stop();

  /// Permanently releases resources and closes events. May retry failed cleanup.
  Future<void> dispose();
}
