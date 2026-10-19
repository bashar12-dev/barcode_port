import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barcode_port/barcode_port.dart';

import 'package:barcode_port_example/main.dart';

void main() {
  testWidgets(
    'covered example ignores scans then resumes on return and shows rejection diagnostics',
    (tester) async {
      final scanner = HidScanner(
        options: const ScannerOptions(maxFrameLength: 2),
      );
      await tester.pumpWidget(
        MaterialApp(home: ScannerExample(scanner: scanner)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open another page'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1, character: '1');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.textContaining('Scan 1:'), findsNothing);
      for (var i = 0; i < 3; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.digit1, character: '1');
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.textContaining('frameOverflow'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2, character: '2');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Scan 1: 2'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'scanning after clicking Start is not replaced by button activation',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ScannerExample(scanner: HidScanner())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Scanning enabled.'), findsOneWidget);
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();
      expect(find.text('Stopped.'), findsOneWidget);
      // Desktop pointer interaction can focus the button before activation.
      Focus.of(tester.element(find.text('Start'))).requestFocus();
      await tester.pump();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(find.text('Scanning enabled.'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1, character: '1');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Scan 1: 1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
