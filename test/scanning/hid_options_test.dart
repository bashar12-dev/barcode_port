import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barcode_port/barcode_port.dart';
import 'widget_lifecycle.dart';

void main() {
  testWidgets('overflow discards the whole frame until the terminator', (
    tester,
  ) async {
    final scanner = HidScanner(
      options: const ScannerOptions(maxFrameLength: 2),
    );
    final frames = <String>[];
    final sub = scanner.events.listen((event) => frames.add(event.barcode));
    addTearDown(sub.cancel);
    addTearDown(() => completeLifecycle(tester, scanner.dispose()));
    await scanner.start();
    for (final digit in ['1', '2', '3', '4']) {
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1, character: digit);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2, character: '2');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(frames, ['2']);
  });

  testWidgets('same barcode scanned twice has distinct identities', (
    tester,
  ) async {
    final scanner = HidScanner();
    final frames = <BarcodeScan>[];
    final sub = scanner.events.listen(frames.add);
    addTearDown(sub.cancel);
    addTearDown(() => completeLifecycle(tester, scanner.dispose()));
    await scanner.start();
    for (var i = 0; i < 2; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1, character: '1');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    }
    await tester.pump();
    expect(frames.map((e) => e.barcode), ['1', '1']);
    expect(frames[0].eventId, isNot(frames[1].eventId));
  });
}
