import 'package:flutter/services.dart';
import 'package:barcode_port/src/generated/scanner_host.g.dart';
import 'package:barcode_port/src/serial_operations.dart';

/// Host metadata describing receiver registration and transport preference.
final class ScannerHostInspectionView {
  /// Creates inspection metadata without asserting physical scanner readiness.
  const ScannerHostInspectionView({
    required this.listening,
    required this.preferNativeBroadcast,
  });

  /// Whether the native receiver is registered.
  final bool listening;

  /// Whether host metadata suggests using iMin broadcast input.
  final bool preferNativeBroadcast;
}

/// Low-level owner of the Android receiver and shared native input stream.
final class ScannerBridge {
  /// The native event channel carrying decoded scan payloads.
  static const scansChannelName = 'com.ultimate.pos/scanner_scans';
  static ScannerBridge? _listenerOwner;
  static final Stream<String> _defaultBarcodes = _decode(
    const EventChannel(scansChannelName),
  );

  /// Creates a bridge with optional injected host and event channel for tests.
  ScannerBridge({ScannerHostApi? host, EventChannel? scans})
    : _host = host ?? ScannerHostApi(),
      _scans = scans;

  final ScannerHostApi _host;
  final _operations = SerialOperations();
  final EventChannel? _scans;
  late final Stream<String> _injectedBarcodes = _decode(_scans!);

  /// Returns a shared broadcast stream of trimmed, nonblank native text.
  Stream<String> barcodes() {
    return _scans == null ? _defaultBarcodes : _injectedBarcodes;
  }

  static Stream<String> _decode(EventChannel channel) {
    return channel
        .receiveBroadcastStream()
        .map(_readBarcode)
        .where((value) => value != null)
        .cast<String>();
  }

  static String? _readBarcode(Object? event) {
    if (event is Map) {
      final barcode = event['barcode'];
      if (barcode is String && barcode.trim().isNotEmpty) {
        return barcode.trim();
      }
      return null;
    }
    if (event is String && event.trim().isNotEmpty) {
      return event.trim();
    }
    return null;
  }

  /// Inspects host flags without acquiring the receiver.
  Future<ScannerHostInspectionView> inspectHost() async {
    final result = await _host.inspectHost();
    return ScannerHostInspectionView(
      listening: result.listening,
      preferNativeBroadcast: result.preferNativeBroadcast,
    );
  }

  /// Acquires native input for this owner through a serialized operation.
  ///
  /// Throws [StateError] for a competing owner. A failed acquisition retains
  /// this owner's lease until [stopListening] succeeds.
  Future<void> startListening() => _operations.run(() async {
    if (_listenerOwner != null && !identical(_listenerOwner, this)) {
      throw StateError('Native scanner already has an active owner');
    }
    // Retain the lease on a failed start until stopListening cleans it up.
    _listenerOwner = this;
    await _host.startListening();
  });

  /// Releases this owner's native input, permitting cleanup retries on failure.
  Future<void> stopListening() => _operations.run(() async {
    if (!identical(_listenerOwner, this)) return;
    await _host.stopListening();
    _listenerOwner = null;
  });

  /// Requests broadcast device output settings without restoring them on stop.
  Future<bool> preferBroadcastOutput() => _host.preferBroadcastOutput();
}
