import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barcode_port/barcode_port.dart';
import 'widget_lifecycle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('emits one complete barcode for Enter and Tab terminators', (
    tester,
  ) async {
    var nextId = 0;
    final scanner = HidScanner(
      eventIdFactory: () => 'scan-${nextId++}',
      clock: () => DateTime.utc(2026, 9, 8, 12),
    );
    final events = <String>[];
    final subscription = scanner.events.listen(
      (event) => events.add(event.barcode),
    );
    addTearDown(subscription.cancel);
    addTearDown(() => completeLifecycle(tester, scanner.dispose()));
    await scanner.start();

    await tester.sendKeyEvent(LogicalKeyboardKey.digit1, character: '1');
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2, character: '2');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3, character: '3');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(events, ['12', '3']);
  });

  testWidgets('discards an incomplete HID frame after its timeout', (
    tester,
  ) async {
    final scanner = HidScanner(
      frameTimeout: const Duration(milliseconds: 250),
      eventIdFactory: () => 'unexpected',
    );
    final events = <String>[];
    final subscription = scanner.events.listen(
      (event) => events.add(event.barcode),
    );
    addTearDown(subscription.cancel);
    addTearDown(() => completeLifecycle(tester, scanner.dispose()));
    await scanner.start();

    await tester.sendKeyEvent(LogicalKeyboardKey.digit1, character: '1');
    await tester.pump(const Duration(milliseconds: 251));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(events, isEmpty);
  });

  testWidgets('does not consume keys while a text field is focused', (
    tester,
  ) async {
    final events = <String>[];
    final scanner = HidScanner(
      eventIdFactory: () => 'scan-hid',
      clock: () => DateTime.utc(2026, 9, 9, 8),
    );
    final subscription = scanner.events.listen(
      (event) => events.add(event.barcode),
    );
    addTearDown(subscription.cancel);
    addTearDown(() => completeLifecycle(tester, scanner.dispose()));
    await scanner.start();

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TextField(autofocus: true))),
    );
    await tester.pump();

    expect(
      await simulateKeyDownEvent(LogicalKeyboardKey.digit6, character: '6'),
      isFalse,
    );
    await simulateKeyUpEvent(LogicalKeyboardKey.digit6);
    expect(
      await simulateKeyDownEvent(LogicalKeyboardKey.digit4, character: '4'),
      isFalse,
    );
    await simulateKeyUpEvent(LogicalKeyboardKey.digit4);
    await tester.pump();

    expect(events, isEmpty);
  });

  testWidgets('consumes HID keys when no text field is focused', (
    tester,
  ) async {
    final events = <String>[];
    final scanner = HidScanner(
      eventIdFactory: () => 'scan-hid',
      clock: () => DateTime.utc(2026, 9, 9, 8),
    );
    final subscription = scanner.events.listen(
      (event) => events.add(event.barcode),
    );
    addTearDown(subscription.cancel);
    addTearDown(() => completeLifecycle(tester, scanner.dispose()));
    await scanner.start();

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.expand())),
    );
    await tester.pump();

    expect(
      await simulateKeyDownEvent(LogicalKeyboardKey.digit6, character: '6'),
      isTrue,
    );
    await simulateKeyUpEvent(LogicalKeyboardKey.digit6);
    expect(
      await simulateKeyDownEvent(LogicalKeyboardKey.digit4, character: '4'),
      isTrue,
    );
    await simulateKeyUpEvent(LogicalKeyboardKey.digit4);
    expect(await simulateKeyDownEvent(LogicalKeyboardKey.enter), isTrue);
    await simulateKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(events, ['64']);
  });
}
