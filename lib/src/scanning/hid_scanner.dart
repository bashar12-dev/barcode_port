import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'barcode_scan.dart';
import 'scanner_options.dart';
import 'scanner_diagnostic.dart';

/// Keyboard-wedge input. Ordinary hardware typing cannot be reliably identified
/// as a scanner; the owner decides when this input is active.
final class HidScanner implements DiagnosticBarcodeScanner {
  HidScanner({
    ScannerOptions options = const ScannerOptions(),
    Duration? frameTimeout,
    DateTime Function()? clock,
    String Function()? eventIdFactory,
  }) : _timeoutDuration = frameTimeout ?? options.frameTimeout,
       _terminators = Set.unmodifiable(options.terminators),
       _maxFrameLength = options.maxFrameLength,
       _passThroughEditableText = options.passThroughEditableText,
       _clock = clock ?? DateTime.now,
       _eventIdFactory = eventIdFactory ?? BarcodeScan.newId {
    if (_timeoutDuration <= Duration.zero) {
      throw ArgumentError.value(_timeoutDuration, 'frameTimeout');
    }
    if (_maxFrameLength < 1) {
      throw ArgumentError.value(_maxFrameLength, 'maxFrameLength');
    }
    if (_terminators.isEmpty) {
      throw ArgumentError('At least one terminator is required');
    }
  }

  // HardwareKeyboard dispatches to every handler, so prevent multiple collectors.
  static HidScanner? _owner;
  final Duration _timeoutDuration;
  final Set<LogicalKeyboardKey> _terminators;
  final int _maxFrameLength;
  final bool _passThroughEditableText;
  final DateTime Function() _clock;
  final String Function() _eventIdFactory;
  final _buffer = StringBuffer();
  Timer? _timeout;
  bool _overflow = false;
  bool _attached = false;
  bool _disposed = false;
  final _events = StreamController<BarcodeScan>.broadcast();
  final _diagnostics = StreamController<ScannerDiagnostic>.broadcast();

  @override
  Stream<BarcodeScan> get events => _events.stream;

  @override
  Stream<ScannerDiagnostic> get diagnostics => _diagnostics.stream;

  @override
  Future<void> start() async {
    if (_disposed) throw StateError('Scanner has been disposed');
    if (_attached) return;
    if (_owner != null && !identical(_owner, this)) {
      throw StateError('HID input already has an active owner');
    }
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
    _attached = true;
    _owner = this;
    if (_passThroughEditableText) {
      FocusManager.instance.addListener(_onFocusChanged);
      _onFocusChanged();
    }
  }

  @override
  Future<void> stop() async => _detach();

  void _detach() {
    if (_attached) {
      HardwareKeyboard.instance.removeHandler(_onKeyEvent);
      if (_passThroughEditableText) {
        FocusManager.instance.removeListener(_onFocusChanged);
      }
    }
    _attached = false;
    if (identical(_owner, this)) _owner = null;
    _clearFrame();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _detach();
    await Future.wait([_events.close(), _diagnostics.close()]);
  }

  bool _onKeyEvent(KeyEvent event) {
    if (!_attached || event is! KeyDownEvent) return false;
    if (_passThroughEditableText && _isEditableFocused()) {
      _clearFrame();
      return false;
    }
    if (_terminators.contains(event.logicalKey)) {
      final length = _buffer.length;
      final barcode = _overflow ? '' : _buffer.toString().trim();
      if (!_overflow && length > 0 && barcode.isEmpty) {
        _diagnose(ScannerDiagnosticReason.blankFrame, length);
      }
      _clearFrame();
      if (barcode.isNotEmpty) {
        _events.add(
          BarcodeScan(
            eventId: _eventIdFactory(),
            barcode: barcode,
            occurredAt: _clock(),
          ),
        );
      }
      return true;
    }
    final character = event.character;
    if (character == null ||
        character.isEmpty ||
        character.codeUnitAt(0) < 32) {
      return false;
    }
    if (!_overflow) {
      if (_buffer.length + character.length > _maxFrameLength) {
        _diagnose(
          ScannerDiagnosticReason.frameOverflow,
          _buffer.length + character.length,
        );
        _overflow = true;
        _buffer.clear();
      } else {
        _buffer.write(character);
      }
    }
    _timeout?.cancel();
    _timeout = Timer(_timeoutDuration, () {
      if (!_overflow && _buffer.isNotEmpty) {
        _diagnose(ScannerDiagnosticReason.incompleteFrame, _buffer.length);
      }
      _clearFrame();
    });
    return true;
  }

  void _clearFrame() {
    _timeout?.cancel();
    _timeout = null;
    _buffer.clear();
    _overflow = false;
  }

  void _onFocusChanged() {
    if (_attached && _isEditableFocused()) _clearFrame();
  }

  void _diagnose(ScannerDiagnosticReason reason, int length) {
    _diagnostics.add(
      ScannerDiagnostic(
        reason: reason,
        occurredAt: _clock(),
        inputLength: length,
      ),
    );
  }

  static bool _isEditableFocused() {
    final primary = FocusManager.instance.primaryFocus;
    final context = primary?.context;
    if (primary == null || !primary.hasFocus || context == null) return false;
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }
}
