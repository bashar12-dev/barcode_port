import 'dart:async';

import 'barcode_scan.dart';
import 'barcode_scanner.dart';
import 'managed_scanner.dart';
import 'scanner_options.dart';
import 'scanner_platform.dart';
import 'scanner_diagnostic.dart';

/// Selects and owns one transport per start according to host metadata.
///
/// Auto mode falls back to HID if inspection fails; a selected transport
/// failure is reported instead of triggering a silent transport switch.
class ResolvingScanner extends ManagedScanner {
  static ResolvingScanner? _owner;

  /// Creates an owner of both [broadcast] and [hid], disposing both on release.
  ///
  /// [platform] supplies host inspection and optional output configuration.
  ResolvingScanner({
    required BarcodeScanner broadcast,
    required BarcodeScanner hid,
    required ScannerPlatform platform,
    ScannerOptions options = const ScannerOptions(),
  }) : _broadcast = broadcast,
       _hid = hid,
       _platform = platform,
       _options = options;

  final BarcodeScanner _broadcast;
  final BarcodeScanner _hid;
  final ScannerPlatform _platform;
  final ScannerOptions _options;
  BarcodeScanner? _active;
  StreamSubscription<BarcodeScan>? _subscription;
  StreamSubscription<ScannerDiagnostic>? _diagnosticSubscription;

  @override
  Future<void> onStart() async {
    if (_owner != null && !identical(_owner, this)) {
      throw StateError('Scanner input already has an active owner');
    }
    _owner = this;
    bool useBroadcast;
    switch (_options.mode) {
      case ScannerMode.hid:
        useBroadcast = false;
      case ScannerMode.iminBroadcast:
        useBroadcast = true;
      case ScannerMode.auto:
        try {
          useBroadcast = await _platform.prefersNativeBroadcast();
        } on Object {
          useBroadcast = false;
        }
    }
    final active = useBroadcast ? _broadcast : _hid;
    _active = active;
    _subscription = active.events.listen(emit, onError: emitError);
    if (active is DiagnosticBarcodeScanner) {
      _diagnosticSubscription = active.diagnostics.listen(
        emitDiagnostic,
        onError: emitError,
      );
    }
    await active.start();
    if (useBroadcast && _options.configureIminOutput) {
      await _platform.configureBroadcastOutput();
    }
  }

  @override
  Future<void> onStop() async {
    if (!identical(_owner, this)) return;
    try {
      await Future.wait([
        if (_subscription != null) _subscription!.cancel(),
        if (_diagnosticSubscription != null) _diagnosticSubscription!.cancel(),
      ]);
      _subscription = null;
      _diagnosticSubscription = null;
    } finally {
      await _active?.stop();
      _active = null;
    }
    _owner = null;
  }

  @override
  Future<void> onDispose() async {
    // Try both even if one child's cleanup fails; callers can retry dispose.
    try {
      await _broadcast.dispose();
    } finally {
      await _hid.dispose();
    }
  }
}
