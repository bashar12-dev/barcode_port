import 'package:flutter/services.dart';

enum ScannerMode { auto, hid, iminBroadcast }

/// Input policy. Configuring iMin changes its device-level output settings.
final class ScannerOptions {
  const ScannerOptions({
    this.mode = ScannerMode.auto,
    this.configureIminOutput = false,
    this.frameTimeout = const Duration(seconds: 2),
    this.terminators = const [LogicalKeyboardKey.enter, LogicalKeyboardKey.tab],
    this.maxFrameLength = 4096,
    this.passThroughEditableText = true,
  });

  final ScannerMode mode;
  final bool configureIminOutput;
  final Duration frameTimeout;
  final List<LogicalKeyboardKey> terminators;
  final int maxFrameLength;

  /// Does not collect keys while an EditableText has focus.
  /// Setting false does not guarantee suppression of text entry elsewhere.
  final bool passThroughEditableText;
}
