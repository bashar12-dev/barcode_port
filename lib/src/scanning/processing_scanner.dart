import 'dart:async';

import 'barcode_scan.dart';
import 'barcode_scanner.dart';
import 'managed_scanner.dart';
import 'scan_processing_options.dart';
import 'scanner_diagnostic.dart';

/// Owns a source and applies optional policy once per observed frame.
///
/// Consumers must not also manage the source's lifecycle directly.
final class ProcessingScanner extends ManagedScanner {
  /// Creates a decorator that owns [source], including final disposal.
  ///
  /// [elapsed] supplies monotonic time for deterministic tests; otherwise a
  /// stopwatch measures intervals. Throws [ArgumentError] for a negative
  /// duplicate window. Callback errors reach the events stream with a stack.
  ProcessingScanner({
    required BarcodeScanner source,
    ScanProcessingOptions options = const ScanProcessingOptions(),
    Duration Function()? elapsed,
  }) : _source = source,
       _options = options,
       _elapsed = elapsed {
    if (options.duplicateWindow < Duration.zero) {
      throw ArgumentError.value(options.duplicateWindow, 'duplicateWindow');
    }
  }

  final BarcodeScanner _source;
  final ScanProcessingOptions _options;
  final Duration Function()? _elapsed;
  final _stopwatch = Stopwatch()..start();
  StreamSubscription<BarcodeScan>? _subscription;
  StreamSubscription<ScannerDiagnostic>? _diagnosticSubscription;
  String? _lastValue;
  Duration? _lastAccepted;

  @override
  Future<void> onStart() async {
    _lastValue = null;
    _lastAccepted = null;
    // Attach before starting: native sources can emit during startup.
    _subscription = _source.events.listen(_process, onError: emitError);
    final source = _source;
    if (source is DiagnosticBarcodeScanner) {
      _diagnosticSubscription = source.diagnostics.listen(
        emitDiagnostic,
        onError: emitError,
      );
    }
    await _source.start();
  }

  void _process(BarcodeScan scan) {
    try {
      final value = (_options.normalize?.call(scan.barcode) ?? scan.barcode)
          .trim();
      if (value.isEmpty) {
        _reject(scan, ScannerDiagnosticReason.normalizedEmpty);
        return;
      }
      if (!(_options.accept?.call(value) ?? true)) {
        _reject(scan, ScannerDiagnosticReason.filtered);
        return;
      }
      final now = _elapsed?.call() ?? _stopwatch.elapsed;
      if (_options.duplicateWindow > Duration.zero &&
          _lastValue == value &&
          _lastAccepted != null &&
          now - _lastAccepted! < _options.duplicateWindow) {
        _reject(scan, ScannerDiagnosticReason.duplicateSuppressed);
        return;
      }
      _lastValue = value;
      _lastAccepted = now;
      emit(
        value == scan.barcode
            ? scan
            : BarcodeScan(
                eventId: scan.eventId,
                barcode: value,
                occurredAt: scan.occurredAt,
              ),
      );
    } on Object catch (error, stack) {
      emitError(error, stack);
    }
  }

  void _reject(BarcodeScan scan, ScannerDiagnosticReason reason) {
    emitDiagnostic(
      ScannerDiagnostic(
        reason: reason,
        occurredAt: scan.occurredAt,
        inputLength: scan.barcode.length,
        eventId: scan.eventId,
      ),
    );
  }

  @override
  Future<void> onStop() async {
    _lastValue = null;
    _lastAccepted = null;
    try {
      await Future.wait([
        if (_subscription != null) _subscription!.cancel(),
        if (_diagnosticSubscription != null) _diagnosticSubscription!.cancel(),
      ]);
      _subscription = null;
      _diagnosticSubscription = null;
    } finally {
      await _source.stop();
    }
  }

  @override
  Future<void> onDispose() async {
    _stopwatch.stop();
    await _source.dispose();
  }
}
