import 'package:flutter/services.dart';

/// The input transport selected for a reception session.
enum ScannerMode {
  /// Uses HID outside native Android; otherwise inspects host metadata and
  /// falls back to HID if inspection fails.
  auto,

  /// Receives keyboard-wedge input without native host inspection.
  hid,

  /// Receives Android iMin broadcasts without automatic HID fallback.
  ///
  /// The default platform throws [UnsupportedError] outside native Android.
  iminBroadcast,
}

/// Transport and keyboard framing policy for one scanner owner.
final class ScannerOptions {
  /// Creates a policy with no device output configuration by default.
  const ScannerOptions({
    this.mode = ScannerMode.auto,
    this.configureIminOutput = false,
    this.frameTimeout = const Duration(seconds: 2),
    this.terminators = const [LogicalKeyboardKey.enter, LogicalKeyboardKey.tab],
    this.maxFrameLength = 4096,
    this.passThroughEditableText = true,
  });

  /// The transport selection policy applied at each start.
  final ScannerMode mode;

  /// Whether starting iMin input requests device-level broadcast output settings.
  ///
  /// Disabled by default. Stopping does not restore previous device settings.
  final bool configureIminOutput;

  /// The maximum inter-character gap before an incomplete HID frame is discarded.
  final Duration frameTimeout;

  /// The keyboard keys that complete a HID frame, snapshotted at construction.
  final List<LogicalKeyboardKey> terminators;

  /// The maximum number of UTF-16 code units in a HID frame.
  final int maxFrameLength;

  /// Whether HID leaves input to the currently focused editable field.
  ///
  /// Disabling this does not guarantee suppression of text entry elsewhere.
  final bool passThroughEditableText;
}
