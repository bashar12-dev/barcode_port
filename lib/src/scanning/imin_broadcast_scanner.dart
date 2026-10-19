import 'dart:async';

import 'barcode_scan.dart';
import 'managed_scanner.dart';
import 'scanner_platform.dart';
import 'scanner_diagnostic.dart';

/// Receives decoded Android iMin broadcasts through a platform boundary.
final class IminBroadcastScanner extends ManagedScanner {
  /// Creates a source using [platform] for native reception.
  ///
  /// Optional [clock] and [eventIdFactory] make observations deterministic in
  /// tests. This source is independent of editable focus.
  IminBroadcastScanner({
    required ScannerPlatform platform,
    DateTime Function()? clock,
    String Function()? eventIdFactory,
  }) : _platform = platform,
       _clock = clock ?? DateTime.now,
       _eventIdFactory = eventIdFactory ?? BarcodeScan.newId;

  final ScannerPlatform _platform;
  final DateTime Function() _clock;
  final String Function() _eventIdFactory;
  // There is one active native input owner per Dart isolate. This also protects
  // clients that inject the same platform/bridge instance into two scanners.
  static IminBroadcastScanner? _owner;
  StreamSubscription<String>? _subscription;
  bool _accepting = false;

  @override
  Future<void> onStart() async {
    if (_owner != null && !identical(_owner, this)) {
      throw StateError('Native input already has an active scanner owner');
    }
    _owner = this;
    _accepting = true;
    // The default platform shares one EventChannel stream; canceling a failed
    // contender's subscription cannot remove the active owner's subscription.
    _subscription = _platform.barcodes().listen((raw) {
      if (!_accepting) return;
      final barcode = raw.trim();
      if (barcode.isNotEmpty) {
        emit(
          BarcodeScan(
            eventId: _eventIdFactory(),
            barcode: barcode,
            occurredAt: _clock(),
          ),
        );
      } else {
        emitDiagnostic(
          ScannerDiagnostic(
            reason: ScannerDiagnosticReason.blankFrame,
            occurredAt: _clock(),
            inputLength: raw.length,
          ),
        );
      }
    }, onError: emitError);
    await _platform.startListening();
  }

  @override
  Future<void> onStop() async {
    if (!identical(_owner, this)) return;
    _accepting = false;
    try {
      await _subscription?.cancel();
      _subscription = null;
    } finally {
      await _platform.stopListening();
    }
    // A failed stop must retain ownership until cleanup is retried.
    _owner = null;
  }
}
