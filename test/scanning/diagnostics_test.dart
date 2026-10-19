import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barcode_port/barcode_port.dart';

import 'widget_lifecycle.dart';

Future<void> _type(WidgetTester tester, String value) async {
  for (final c in value.split('')) {
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: c);
  }
}

void main() {
  testWidgets('timeout diagnoses partial input, overflow reports only once', (
    tester,
  ) async {
    final scanner = HidScanner(
      options: const ScannerOptions(
        maxFrameLength: 2,
        frameTimeout: Duration(milliseconds: 100),
      ),
    );
    final diagnostics = <ScannerDiagnostic>[];
    final reads = <BarcodeScan>[];
    final a = scanner.diagnostics.listen(diagnostics.add);
    final b = scanner.events.listen(reads.add);
    addTearDown(a.cancel);
    addTearDown(b.cancel);
    addTearDown(() => completeLifecycle(tester, scanner.dispose()));
    await scanner.start();
    await _type(tester, '1');
    await tester.pump(const Duration(milliseconds: 101));
    await _type(tester, '12345');
    await tester.pump(const Duration(milliseconds: 101));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _type(tester, '2');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(diagnostics.map((d) => d.reason), [
      ScannerDiagnosticReason.incompleteFrame,
      ScannerDiagnosticReason.frameOverflow,
    ]);
    expect(diagnostics.map((d) => d.inputLength), [1, 3]);
    expect(diagnostics.every((d) => d.occurredAt.isUtc), isTrue);
    expect(reads.map((s) => s.barcode), ['2']);
  });

  testWidgets('overflow suffix is discarded through terminator', (
    tester,
  ) async {
    final scanner = HidScanner(
      options: const ScannerOptions(maxFrameLength: 2),
    );
    final diagnostics = <ScannerDiagnostic>[];
    final reads = <BarcodeScan>[];
    final a = scanner.diagnostics.listen(diagnostics.add);
    final b = scanner.events.listen(reads.add);
    addTearDown(a.cancel);
    addTearDown(b.cancel);
    addTearDown(() => completeLifecycle(tester, scanner.dispose()));
    await scanner.start();
    await _type(tester, '123456');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _type(tester, ' ');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(reads, isEmpty);
    expect(diagnostics.map((d) => d.reason), [
      ScannerDiagnosticReason.frameOverflow,
      ScannerDiagnosticReason.blankFrame,
    ]);
  });

  testWidgets('entering editable focus clears partial frame without a key', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TextField(focusNode: focus)),
      ),
    );
    final scanner = HidScanner();
    final reads = <BarcodeScan>[];
    final sub = scanner.events.listen(reads.add);
    addTearDown(sub.cancel);
    addTearDown(() => completeLifecycle(tester, scanner.dispose()));
    await scanner.start();
    await _type(tester, 'old');
    focus.requestFocus();
    await tester.pump();
    focus.unfocus();
    await tester.pump();
    await _type(tester, 'new');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(reads.map((s) => s.barcode), ['new']);
  });

  testWidgets('starting focused and stopping intentionally are silent', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TextField(focusNode: focus, autofocus: true)),
      ),
    );
    await tester.pump();
    final scanner = HidScanner();
    final reads = <BarcodeScan>[];
    final diagnostics = <ScannerDiagnostic>[];
    final a = scanner.events.listen(reads.add);
    final b = scanner.diagnostics.listen(diagnostics.add);
    addTearDown(a.cancel);
    addTearDown(b.cancel);
    addTearDown(() => completeLifecycle(tester, scanner.dispose()));
    await scanner.start();
    await _type(tester, 'ignored');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    focus.unfocus();
    await tester.pump();
    await _type(tester, 'partial');
    await scanner.stop();
    await scanner.start();
    await _type(tester, 'next');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(reads.map((s) => s.barcode), ['next']);
    expect(diagnostics, isEmpty);
  });
}
