import 'dart:async';

import 'package:flutter/widgets.dart';

import '../scanning/barcode_scan.dart';
import '../scanning/barcode_scanner.dart';
import '../scanning/scanner_diagnostic.dart';
import '../serial_operations.dart';

/// Owns one scanner for a widget lifetime and follows reception eligibility.
///
/// The factory is called exactly once;
/// use a new key to replace the scanner/configuration. Do not manage the same
/// source's lifecycle elsewhere while this widget is mounted.
///
/// Hidden tabs and nested navigators must supply their visibility via [enabled].
/// This widget does not arbitrate handoff between competing scanner owners.
class ScannerListener extends StatefulWidget {
  /// Creates a screen owner with route and application pausing enabled.
  ///
  /// The source returned by [createScanner] belongs to this widget, including
  /// disposal. [onError] handles operational errors; omitted handlers report
  /// through FlutterError. Final cleanup failures always use FlutterError.
  const ScannerListener({
    super.key,
    required this.createScanner,
    required this.child,
    required this.onScan,
    this.onDiagnostic,
    this.onError,
    this.enabled = true,
    this.pauseWhenRouteCovered = true,
    this.pauseWhenAppInactive = true,
  });

  /// The source factory, called once per State and not on ordinary rebuilds.
  final BarcodeScanner Function() createScanner;

  /// The screen subtree whose lifetime contains the reception owner.
  final Widget child;

  /// The callback for observations while reception is eligible.
  final ValueChanged<BarcodeScan> onScan;

  /// The optional callback for discarded-input diagnostics.
  final ValueChanged<ScannerDiagnostic>? onDiagnostic;

  /// The optional operational error callback with the original stack.
  final void Function(Object error, StackTrace stack)? onError;

  /// Whether reception is manually enabled, including hidden-tab visibility.
  final bool enabled;

  /// Whether a covering page or dialog pauses reception.
  final bool pauseWhenRouteCovered;

  /// Whether an explicitly non-resumed application state pauses reception.
  final bool pauseWhenAppInactive;

  @override
  State<ScannerListener> createState() => _ScannerListenerState();
}

class _ScannerListenerState extends State<ScannerListener>
    with WidgetsBindingObserver {
  late final BarcodeScanner _scanner;
  late final StreamSubscription<BarcodeScan> _subscription;
  StreamSubscription<ScannerDiagnostic>? _diagnosticSubscription;
  final _operations = SerialOperations();
  bool _routeCurrent = true;
  bool _eligible = false;
  bool _closing = false;
  bool _active = false;
  bool _mayOwnInput = false;
  int _epoch = 0;
  int _attemptedEpoch = -1;
  int _activeEpoch = -1;
  int _startingEpoch = -1;

  bool get _canDeliver =>
      !_closing &&
      _eligible &&
      ((_active && _activeEpoch == _epoch) || _startingEpoch == _epoch);

  @override
  void initState() {
    super.initState();
    _scanner = widget.createScanner();
    _subscription = _scanner.events.listen(
      (scan) {
        if (_canDeliver) widget.onScan(scan);
      },
      onError: (Object error, StackTrace stack) {
        if (_canDeliver) _report(error, stack);
      },
    );
    final scanner = _scanner;
    if (scanner is DiagnosticBarcodeScanner) {
      _diagnosticSubscription = scanner.diagnostics.listen(
        (diagnostic) {
          if (_canDeliver) widget.onDiagnostic?.call(diagnostic);
        },
        onError: (Object error, StackTrace stack) {
          if (_canDeliver) _report(error, stack);
        },
      );
    }
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeCurrent = ModalRoute.isCurrentOf(context) ?? true;
    _refresh();
  }

  @override
  void didUpdateWidget(ScannerListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _refresh();

  void _refresh() {
    if (_closing) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final next =
        widget.enabled &&
        (!widget.pauseWhenRouteCovered || _routeCurrent) &&
        (!widget.pauseWhenAppInactive ||
            lifecycle == null ||
            lifecycle == AppLifecycleState.resumed);
    if (next == _eligible) return;
    _eligible = next;
    if (next) _epoch++;
    unawaited(_operations.run(_reconcile));
  }

  Future<void> _stop() async {
    _active = false;
    await _scanner.stop();
    _mayOwnInput = false;
  }

  Future<void> _reconcile() async {
    if (_closing) return;
    if (!_eligible) {
      if (_mayOwnInput) {
        try {
          await _stop();
        } on Object catch (error, stack) {
          _report(error, stack);
        }
      }
      return;
    }
    if ((_active && _activeEpoch == _epoch) || _attemptedEpoch == _epoch) {
      return;
    }
    final attempt = _epoch;
    _attemptedEpoch = attempt;
    try {
      if (_mayOwnInput) await _stop();
      if (_closing || !_eligible || attempt != _epoch) return;
      _mayOwnInput = true;
      _startingEpoch = attempt;
      await _scanner.start();
      _active = true;
      _activeEpoch = attempt;
    } on Object catch (error, stack) {
      _active = false;
      _report(error, stack);
    } finally {
      _startingEpoch = -1;
    }
  }

  void _report(Object error, StackTrace stack) {
    final callback = widget.onError;
    if (!_closing && mounted && callback != null) {
      try {
        callback(error, stack);
      } on Object catch (callbackError, callbackStack) {
        _reportToFlutter(callbackError, callbackStack);
      }
    } else {
      _reportToFlutter(error, stack);
    }
  }

  void _reportToFlutter(Object error, StackTrace stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'barcode_port',
        context: ErrorDescription('while managing a ScannerListener'),
      ),
    );
  }

  Future<void> _finalize() async {
    try {
      await Future.wait([
        _subscription.cancel(),
        if (_diagnosticSubscription != null) _diagnosticSubscription!.cancel(),
      ]);
    } on Object catch (error, stack) {
      _reportToFlutter(error, stack);
    }
    try {
      await _scanner.stop();
    } on Object {
      // dispose retries cleanup for built-in scanners. Report final failure below.
    } finally {
      try {
        await _scanner.dispose();
      } on Object catch (error, stack) {
        _reportToFlutter(error, stack);
      }
    }
  }

  @override
  void dispose() {
    _closing = true;
    _eligible = false;
    WidgetsBinding.instance.removeObserver(this);
    // State.dispose is synchronous; this handled finalizer follows pending work.
    unawaited(_operations.run(_finalize));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
