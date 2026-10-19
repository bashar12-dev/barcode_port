import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barcode_port/barcode_port.dart';
import 'widget_lifecycle.dart';

class _Platform implements ScannerPlatform {
  final input = StreamController<String>.broadcast(sync: true);
  bool stopFails = false;
  @override
  Stream<String> barcodes() => input.stream;
  @override
  Future<bool> configureBroadcastOutput() async => true;
  @override
  Future<bool> prefersNativeBroadcast() async => true;
  @override
  Future<void> startListening() async => input.add('item');
  @override
  Future<void> stopListening() async {
    if (stopFails) throw StateError('native stop');
  }
}

void main() {
  test(
    'failed native disposal retains ownership and can finish on retry',
    () async {
      final platform = _Platform();
      const options = ScannerOptions(mode: ScannerMode.iminBroadcast);
      final owner = Scanner(platform: platform, options: options);
      final contender = Scanner(platform: platform, options: options);
      await owner.start();
      platform.stopFails = true;
      await expectLater(owner.dispose(), throwsStateError);
      await expectLater(contender.start(), throwsStateError);
      platform.stopFails = false;
      await owner.dispose();
      await contender.start();
      await contender.dispose();
      await platform.input.close();
    },
  );

  for (final mode in [ScannerMode.hid, ScannerMode.iminBroadcast]) {
    testWidgets(
      '$mode applies policy once including startup and retains native input during editing',
      (tester) async {
        final platform = _Platform();
        final scanner = Scanner(
          platform: platform,
          options: ScannerOptions(mode: mode),
          processing: ScanProcessingOptions(
            normalize: (v) => v.toUpperCase(),
            accept: (v) => v == 'ITEM',
            duplicateWindow: const Duration(seconds: 10),
          ),
        );
        final reads = <BarcodeScan>[];
        final notices = <ScannerDiagnostic>[];
        final a = scanner.events.listen(reads.add);
        final b = scanner.diagnostics.listen(notices.add);
        addTearDown(() async {
          await completeLifecycle(tester, scanner.dispose());
          await a.cancel();
          await b.cancel();
          await platform.input.close();
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: mode == ScannerMode.iminBroadcast
                  ? const TextField(autofocus: true)
                  : const SizedBox(),
            ),
          ),
        );
        await tester.pump();
        await completeLifecycle(tester, scanner.start());
        for (final value in ['item', 'other', '   ']) {
          if (mode == ScannerMode.hid) {
            for (final c in value.split('')) {
              await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: c);
            }
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          } else {
            platform.input.add(value);
          }
          await tester.pump();
        }
        expect(reads.map((s) => s.barcode), ['ITEM']);
        expect(reads.single.eventId, isNotEmpty);
        expect(reads.single.occurredAt.isUtc, isTrue);
        expect(notices.map((d) => d.reason), [
          if (mode == ScannerMode.iminBroadcast)
            ScannerDiagnosticReason.duplicateSuppressed,
          ScannerDiagnosticReason.filtered,
          ScannerDiagnosticReason.blankFrame,
        ]);
      },
    );
  }
}
