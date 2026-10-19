import 'package:flutter/services.dart';
import 'package:barcode_port/src/generated/scanner_host.g.dart';
import 'package:barcode_port/src/serial_operations.dart';

final class ScannerHostInspectionView {
  const ScannerHostInspectionView({
    required this.listening,
    required this.preferNativeBroadcast,
  });
  final bool listening;
  final bool preferNativeBroadcast;
}

final class ScannerBridge {
  static const scansChannelName = 'com.ultimate.pos/scanner_scans';
  static ScannerBridge? _listenerOwner;
  static final Stream<String> _defaultBarcodes = _decode(
    const EventChannel(scansChannelName),
  );

  ScannerBridge({ScannerHostApi? host, EventChannel? scans})
    : _host = host ?? ScannerHostApi(),
      _scans = scans;

  final ScannerHostApi _host;
  final _operations = SerialOperations();
  final EventChannel? _scans;
  late final Stream<String> _injectedBarcodes = _decode(_scans!);

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

  Future<ScannerHostInspectionView> inspectHost() async {
    final result = await _host.inspectHost();
    return ScannerHostInspectionView(
      listening: result.listening,
      preferNativeBroadcast: result.preferNativeBroadcast,
    );
  }

  Future<void> startListening() => _operations.run(() async {
    if (_listenerOwner != null && !identical(_listenerOwner, this)) {
      throw StateError('Native scanner already has an active owner');
    }
    // Retain the lease on a failed start until stopListening cleans it up.
    _listenerOwner = this;
    await _host.startListening();
  });

  Future<void> stopListening() => _operations.run(() async {
    if (!identical(_listenerOwner, this)) return;
    await _host.stopListening();
    _listenerOwner = null;
  });

  Future<bool> preferBroadcastOutput() => _host.preferBroadcastOutput();
}
