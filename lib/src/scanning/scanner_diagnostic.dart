import 'barcode_scanner.dart';

/// An optional capability providing notices for discarded input.
///
/// Custom [BarcodeScanner] implementations need not provide diagnostics.
abstract interface class DiagnosticBarcodeScanner implements BarcodeScanner {
  /// The broadcast stream of discarded-input notices without barcode contents.
  Stream<ScannerDiagnostic> get diagnostics;
}

/// The reason an input frame or complete observation was not delivered.
enum ScannerDiagnosticReason {
  /// A nonempty partial HID frame expired before receiving a terminator.
  incompleteFrame,

  /// A HID frame exceeded its configured UTF-16 length limit.
  frameOverflow,

  /// A completed input contained only whitespace.
  blankFrame,

  /// The application's acceptance predicate rejected the normalized text.
  filtered,

  /// Application normalization produced empty or whitespace-only text.
  normalizedEmpty,

  /// An opt-in consecutive-repeat window suppressed this observation.
  duplicateSuppressed,
}

/// A discarded-input notice separate from operational errors on the events stream.
///
/// Contains no barcode text and does not automatically log input.
final class ScannerDiagnostic {
  /// Creates a notice, converting [occurredAt] to UTC.
  ScannerDiagnostic({
    required this.reason,
    required DateTime occurredAt,
    required this.inputLength,
    this.eventId,
  }) : occurredAt = occurredAt.toUtc();

  /// The reason the input was discarded.
  final ScannerDiagnosticReason reason;

  /// The observation or discard time in UTC.
  final DateTime occurredAt;

  /// The discarded input length measured in UTF-16 code units.
  final int inputLength;

  /// The observation identity when a complete frame already existed.
  final String? eventId;
}
