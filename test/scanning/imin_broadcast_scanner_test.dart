import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:barcode_port/barcode_port.dart';

class _FakeBridge implements ScannerPlatform {
  final StreamController<String> controller =
      StreamController<String>.broadcast();
  var startCount = 0;
  var stopCount = 0;
  Completer<void>? startGate;
  Completer<void>? startEntered;

  @override
  Future<bool> prefersNativeBroadcast() async => true;

  @override
  Future<bool> configureBroadcastOutput() async => true;

  @override
  Stream<String> barcodes() => controller.stream;

  @override
  Future<void> startListening() async {
    startCount += 1;
    startEntered?.complete();
    await startGate?.future;
  }

  @override
  Future<void> stopListening() async {
    stopCount += 1;
  }
}

void main() {
  test(
    'resolver forwards one blank native diagnostic without interrupting reads',
    () async {
      final platform = _FakeBridge();
      final scanner = Scanner(
        platform: platform,
        options: const ScannerOptions(mode: ScannerMode.iminBroadcast),
      );
      final diagnostics = <ScannerDiagnostic>[];
      final reads = <BarcodeScan>[];
      final a = scanner.diagnostics.listen(diagnostics.add);
      final b = scanner.events.listen(reads.add);
      addTearDown(() async {
        await a.cancel();
        await b.cancel();
        await scanner.dispose();
        await platform.controller.close();
      });
      await scanner.start();
      platform.controller.add('   ');
      platform.controller.add('internal_code');
      await Future<void>.delayed(Duration.zero);
      expect(diagnostics.map((d) => d.reason), [
        ScannerDiagnosticReason.blankFrame,
      ]);
      expect(diagnostics.single.inputLength, 3);
      expect(reads.single.barcode, 'internal_code');
    },
  );

  test('retains a frame received before native startup response', () async {
    final bridge = _FakeBridge()
      ..startGate = Completer<void>()
      ..startEntered = Completer<void>();
    final scanner = IminBroadcastScanner(platform: bridge);
    final reads = <String>[];
    final sub = scanner.events.listen((scan) => reads.add(scan.barcode));
    addTearDown(() async {
      if (!bridge.startGate!.isCompleted) bridge.startGate!.complete();
      await sub.cancel();
      await scanner.dispose();
    });
    final starting = scanner.start();
    await bridge.startEntered!.future;
    bridge.controller.add('first-frame');
    await Future<void>.delayed(Duration.zero);
    expect(reads, ['first-frame']);
    bridge.startGate!.complete();
    await starting;
  });

  test(
    'shared platform rejects another scanner without stopping owner',
    () async {
      final platform = _FakeBridge();
      const options = ScannerOptions(mode: ScannerMode.iminBroadcast);
      final owner = Scanner(options: options, platform: platform);
      final contender = Scanner(options: options, platform: platform);
      final reads = <String>[];
      final sub = owner.events.listen((scan) => reads.add(scan.barcode));
      addTearDown(() async {
        await sub.cancel();
        await contender.dispose();
        await owner.dispose();
      });
      await owner.start();
      await expectLater(contender.start(), throwsStateError);
      await contender.dispose();
      platform.controller.add('owner-still-listening');
      await Future<void>.delayed(Duration.zero);
      expect(reads, ['owner-still-listening']);
      expect(platform.stopCount, 0);
    },
  );

  test('maps each native barcode to a fresh BarcodeScan', () async {
    final bridge = _FakeBridge();
    var nextId = 0;
    final port = IminBroadcastScanner(
      platform: bridge,
      eventIdFactory: () => 'scan-${nextId++}',
      clock: () => DateTime.utc(2026, 9, 9, 8),
    );
    final events = <BarcodeScan>[];
    final subscription = port.events.listen(events.add);
    addTearDown(subscription.cancel);
    addTearDown(port.stop);

    await port.start();
    bridge.controller.add(' 646446464 ');
    await Future<void>.delayed(Duration.zero);

    expect(bridge.startCount, 1);
    expect(events, hasLength(1));
    expect(events.single.eventId, 'scan-0');
    expect(events.single.barcode, '646446464');
    expect(events.single.occurredAt, DateTime.utc(2026, 9, 9, 8));

    await port.stop();
    expect(bridge.stopCount, 1);
  });

  test('ignores blank native frames', () async {
    final bridge = _FakeBridge();
    final port = IminBroadcastScanner(
      platform: bridge,
      eventIdFactory: () => 'unexpected',
    );
    final events = <BarcodeScan>[];
    final subscription = port.events.listen(events.add);
    addTearDown(subscription.cancel);
    addTearDown(port.stop);

    await port.start();
    bridge.controller.add('   ');
    await Future<void>.delayed(Duration.zero);

    expect(events, isEmpty);
  });
}
