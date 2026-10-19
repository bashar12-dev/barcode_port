import '../../scanner_bridge.dart';

/// The narrow platform boundary; no generated Pigeon types are exposed.
abstract interface class ScannerPlatform {
  Stream<String> barcodes();
  Future<bool> prefersNativeBroadcast();
  Future<bool> configureBroadcastOutput();
  Future<void> startListening();
  Future<void> stopListening();
}

/// Default Android transport. Multiple instances share the bridge's ownership.
final class BridgeScannerPlatform implements ScannerPlatform {
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
