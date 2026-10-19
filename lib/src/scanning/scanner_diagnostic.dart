import 'barcode_scanner.dart';

/// An optional capability; custom [BarcodeScanner] implementations need not
/// provide diagnostics to remain compatible.
abstract interface class DiagnosticBarcodeScanner implements BarcodeScanner {
  Stream<ScannerDiagnostic> get diagnostics;
}

enum ScannerDiagnosticReason {
  incompleteFrame,
  frameOverflow,
  blankFrame,
  filtered,
  normalizedEmpty,
  duplicateSuppressed,
}

/// A discarded input, separate from operational errors on the events stream.
/// Does not contain barcode text or log it automatically.
final class ScannerDiagnostic {
  ScannerDiagnostic({
    required this.reason,
    required DateTime occurredAt,
    required this.inputLength,
    this.eventId,
  }) : occurredAt = occurredAt.toUtc();

  final ScannerDiagnosticReason reason;
  final DateTime occurredAt;
  final int inputLength;
  final String? eventId;
}
