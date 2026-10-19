import 'dart:async';
import 'package:barcode_port/barcode_port.dart';

/// A controllable device boundary; production processing/lifecycle remain real.
class TestScanner implements DiagnosticBarcodeScanner {
  final frames = StreamController<BarcodeScan>.broadcast(sync: true);
  final notices = StreamController<ScannerDiagnostic>.broadcast(sync: true);
  Future<void> Function()? starting;
  Future<void> Function()? stopping;
  Future<void> Function()? disposing;
  bool active = false;
  bool disposed = false;
  int starts = 0;
  int stops = 0;
  @override
  Stream<BarcodeScan> get events => frames.stream;
  @override
  Stream<ScannerDiagnostic> get diagnostics => notices.stream;
  @override
  Future<void> start() async {
    starts++;
    await starting?.call();
    active = true;
  }

  @override
  Future<void> stop() async {
    stops++;
    await stopping?.call();
    active = false;
  }

  @override
  Future<void> dispose() async {
    await disposing?.call();
    active = false;
    disposed = true;
    await Future.wait([frames.close(), notices.close()]);
  }
}

BarcodeScan frame(String id, String value) => BarcodeScan(
  eventId: id,
  barcode: value,
  occurredAt: DateTime.utc(2026, 10, 20),
);
