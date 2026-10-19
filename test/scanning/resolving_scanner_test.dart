import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:barcode_port/barcode_port.dart';
import 'package:barcode_port/src/scanning/managed_scanner.dart';

class _Source extends ManagedScanner {
  var active = false;
  @override
  Future<void> onStart() async {
    active = true;
  }

  @override
  Future<void> onStop() async {
    active = false;
  }

  void read(String barcode) => emit(
    BarcodeScan(
      eventId: barcode,
      barcode: barcode,
      occurredAt: DateTime.utc(2026),
    ),
  );
}

class _Platform implements ScannerPlatform {
  bool preferred = true;
  bool inspectionFails = false;
  var inspections = 0;
  var configurations = 0;
  @override
  Future<bool> prefersNativeBroadcast() async {
    inspections++;
    if (inspectionFails) throw StateError('host unavailable');
    return preferred;
  }

  @override
  Future<bool> configureBroadcastOutput() async {
    configurations++;
    return true;
  }

  @override
  Stream<String> barcodes() => const Stream.empty();
  @override
  Future<void> startListening() async {}
  @override
  Future<void> stopListening() async {}
}

void main() {
  test(
    'two high-level owners cannot activate different transports together',
    () async {
      final platform = _Platform();
      final ownerHid = _Source();
      final rejectedBroadcast = _Source();
      final owner = ResolvingScanner(
        broadcast: _Source(),
        hid: ownerHid,
        platform: platform,
        options: const ScannerOptions(mode: ScannerMode.hid),
      );
      final contender = ResolvingScanner(
        broadcast: rejectedBroadcast,
        hid: _Source(),
        platform: platform,
        options: const ScannerOptions(mode: ScannerMode.iminBroadcast),
      );
      addTearDown(owner.dispose);
      addTearDown(contender.dispose);
      await owner.start();
      await expectLater(contender.start(), throwsStateError);
      await contender.dispose();
      expect(ownerHid.active, isTrue);
      expect(rejectedBroadcast.active, isFalse);
    },
  );

  for (final preferred in [true, false]) {
    test('auto activates only ${preferred ? "broadcast" : "HID"}', () async {
      final platform = _Platform()..preferred = preferred;
      final native = _Source();
      final hid = _Source();
      final scanner = ResolvingScanner(
        broadcast: native,
        hid: hid,
        platform: platform,
      );
      final reads = <String>[];
      final sub = scanner.events.listen((event) => reads.add(event.barcode));
      await scanner.start();
      expect(native.active, preferred);
      expect(hid.active, !preferred);
      native.read('111');
      hid.read('222');
      await Future<void>.delayed(Duration.zero);
      expect(reads, [preferred ? '111' : '222']);
      await sub.cancel();
      await scanner.dispose();
      expect(native.active || hid.active, isFalse);
      expect(platform.configurations, 0);
    });
  }

  test('inspection failure chooses HID', () async {
    final platform = _Platform()..inspectionFails = true;
    final hid = _Source();
    final scanner = ResolvingScanner(
      broadcast: _Source(),
      hid: hid,
      platform: platform,
    );
    await scanner.start();
    expect(hid.active, isTrue);
    await scanner.dispose();
  });

  for (final mode in [ScannerMode.hid, ScannerMode.iminBroadcast]) {
    test('$mode bypasses device heuristics', () async {
      final platform = _Platform()..inspectionFails = true;
      final native = _Source();
      final hid = _Source();
      final scanner = ResolvingScanner(
        broadcast: native,
        hid: hid,
        platform: platform,
        options: ScannerOptions(mode: mode, configureIminOutput: true),
      );
      await scanner.start();
      expect(platform.inspections, 0);
      expect(native.active, mode == ScannerMode.iminBroadcast);
      expect(hid.active, mode == ScannerMode.hid);
      expect(
        platform.configurations,
        mode == ScannerMode.iminBroadcast ? 1 : 0,
      );
      await scanner.dispose();
    });
  }
}
