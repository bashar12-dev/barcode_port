import '../../scanner_bridge.dart';

/// The narrow platform boundary; no generated Pigeon types are exposed.
abstract interface class ScannerPlatform {
  /// The decoded native barcode stream and any native stream errors.
  Stream<String> barcodes();

  /// Inspects whether host metadata prefers Android iMin broadcasts.
  Future<bool> prefersNativeBroadcast();

  /// Requests device broadcast output settings and returns a host heuristic.
  ///
  /// A successful response is not a physical scanner acknowledgment, and stop
  /// does not restore previous device output settings.
  Future<bool> configureBroadcastOutput();

  /// Acquires the native receiver, failing if another owner holds it.
  Future<void> startListening();

  /// Releases this owner's receiver, retaining ownership on cleanup failure.
  Future<void> stopListening();
}

/// Default Android transport. Multiple instances share the bridge's ownership.
final class BridgeScannerPlatform implements ScannerPlatform {
  /// Creates a boundary over [bridge] or the default Android bridge.
  BridgeScannerPlatform({ScannerBridge? bridge})
    : _bridge = bridge ?? ScannerBridge();
  final ScannerBridge _bridge;

  @override
  Stream<String> barcodes() => _bridge.barcodes();
  @override
  Future<bool> prefersNativeBroadcast() async =>
      (await _bridge.inspectHost()).preferNativeBroadcast;
  @override
  Future<bool> configureBroadcastOutput() => _bridge.preferBroadcastOutput();
  @override
  Future<void> startListening() => _bridge.startListening();
  @override
  Future<void> stopListening() => _bridge.stopListening();
}
