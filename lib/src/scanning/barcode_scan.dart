import 'dart:math';

/// One observed frame. Re-delivery of this event must retain [eventId].
final class BarcodeScan {
  BarcodeScan({
    required String eventId,
    required String barcode,
    required DateTime occurredAt,
  }) : eventId = _required(eventId, 'eventId'),
       barcode = _required(barcode, 'barcode'),
       occurredAt = occurredAt.toUtc();

  final String eventId;
  final String barcode;
  final DateTime occurredAt;

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
