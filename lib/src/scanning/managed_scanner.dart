import 'dart:async';

import '../serial_operations.dart';
import 'barcode_scan.dart';
import 'scanner_diagnostic.dart';

/// Serializes resource transitions, including rollback after a failed start.
abstract class ManagedScanner implements DiagnosticBarcodeScanner {
  final _events = StreamController<BarcodeScan>.broadcast();
  final _diagnostics = StreamController<ScannerDiagnostic>.broadcast();
  final _operations = SerialOperations();
  bool _running = false;
  bool _needsStop = false;
  bool _disposed = false;
  bool _closed = false;

  @override
  Stream<BarcodeScan> get events => _events.stream;

  @override
  Stream<ScannerDiagnostic> get diagnostics => _diagnostics.stream;

  @override
  Future<void> start() => _operations.run(() async {
    if (_disposed) throw StateError('Scanner has been disposed');
    if (_needsStop && !_running) await _stop();
    if (_running) return;
    _needsStop = true;
    try {
      await onStart();
      _running = true;
    } catch (error, stack) {
      await _stop();
      Error.throwWithStackTrace(error, stack);
    }
  });

  Future<void> _stop() async {
    if (!_needsStop) return;
    _running = false;
    await onStop();
    _needsStop = false;
  }

  @override
  Future<void> stop() => _operations.run(_stop);

  @override
  Future<void> dispose() {
    _disposed = true;
    return _operations.run(() async {
      if (_closed) return;
      try {
        await _stop();
      } finally {
        // Owned children must get a cleanup attempt even if stop keeps failing.
        // Do not close our streams/forget pending cleanup unless both succeed.
        await onDispose();
      }
      _closed = true;
      await Future.wait([_events.close(), _diagnostics.close()]);
    });
  }

  /// Delivers [scan] unless this owner is disposed or its streams are closed.
  void emit(BarcodeScan scan) {
    if (!_disposed && !_closed) _events.add(scan);
  }

  /// Delivers an operational [error] and its original [stack].
  void emitError(Object error, StackTrace stack) {
    if (!_disposed && !_closed) _events.addError(error, stack);
  }

  /// Delivers a discarded-input notice without barcode contents.
  void emitDiagnostic(ScannerDiagnostic diagnostic) {
    if (!_disposed && !_closed) _diagnostics.add(diagnostic);
  }

  /// Acquires reception resources for the serialized start operation.
  Future<void> onStart();

  /// Releases reception resources, allowing retries when cleanup fails.
  Future<void> onStop();

  /// Releases owned children even when the preceding stop attempt failed.
  Future<void> onDispose() async {}
}
