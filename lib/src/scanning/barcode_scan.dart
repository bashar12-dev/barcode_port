import 'dart:math';

/// One observed barcode frame with a stable identity and UTC observation time.
///
/// Re-delivery of this event must retain [eventId].
final class BarcodeScan {
  /// Creates an event, trimming text and converting [occurredAt] to UTC.
  ///
  /// Throws [ArgumentError] if [eventId] or [barcode] is blank.
  BarcodeScan({
    required String eventId,
    required String barcode,
    required DateTime occurredAt,
  }) : eventId = _required(eventId, 'eventId'),
       barcode = _required(barcode, 'barcode'),
       occurredAt = occurredAt.toUtc();

  /// The identity of this observation, independent of the barcode value.
  final String eventId;

  /// The trimmed, nonempty barcode text, including any leading zeros.
  final String barcode;

  /// The observation time in UTC.
  final DateTime occurredAt;

  /// Generates an independent identity using cryptographically secure entropy.
  static String newId() {
    final random = Random.secure();
    final entropy = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return 'scan-$entropy';
  }

  static String _required(String value, String name) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, name, 'must not be blank');
    }
    return normalized;
  }
}
