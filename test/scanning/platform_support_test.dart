import 'dart:async';

import 'package:barcode_port/scanner_bridge.dart';
import 'package:barcode_port/scanner_widgets.dart';
import 'package:barcode_port/src/generated/scanner_host.g.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_lifecycle.dart';

Future<void> _complete(WidgetTester tester, Future<void> operation) async {
  var done = false;
  Object? failure;
  StackTrace? trace;
  operation.then<void>(
    (_) {
      done = true;
    },
    onError: (Object e, StackTrace s) {
      failure = e;
      trace = s;
      done = true;
    },
  );
  await pumpUntil(tester, () => done);
  if (failure != null) Error.throwWithStackTrace(failure!, trace!);
}

Future<void> _scan(WidgetTester tester, String text, {bool tab = false}) async {
  for (final character in text.split('')) {
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: character);
  }
  await tester.sendKeyEvent(
    tab ? LogicalKeyboardKey.tab : LogicalKeyboardKey.enter,
  );
  await tester.pump();
}

// A native host is deliberately available: accidentally probing it would select
// broadcasts rather than falling back to HID and hiding the routing defect.
Map<String, int> _recordNativeCalls() {
  final calls = <String, int>{};
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final method in [
    'inspectHost',
    'startListening',
    'stopListening',
    'preferBroadcastOutput',
  ]) {
    final channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.scanner_bridge.ScannerHostApi.$method',
      ScannerHostApi.pigeonChannelCodec,
    );
    messenger.setMockDecodedMessageHandler<Object?>(channel, (_) async {
      calls.update(method, (n) => n + 1, ifAbsent: () => 1);
      return [
        switch (method) {
          'inspectHost' => ScannerHostInspection(
            listening: false,
            preferNativeBroadcast: true,
          ),
          'preferBroadcastOutput' => true,
          _ => null,
        },
      ];
    });
    addTearDown(
      () => messenger.setMockDecodedMessageHandler<Object?>(channel, null),
    );
  }
  const events = MethodChannel(ScannerBridge.scansChannelName);
  messenger.setMockMethodCallHandler(events, (call) async {
    calls.update('events.${call.method}', (n) => n + 1, ifAbsent: () => 1);
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(events, null));
  return calls;
}

class _InjectedPlatform implements ScannerPlatform {
  final input = StreamController<String>.broadcast(sync: true);
  int starts = 0;
  @override
  Stream<String> barcodes() => input.stream;
  @override
  Future<bool> prefersNativeBroadcast() async => true;
  @override
  Future<bool> configureBroadcastOutput() async => true;
  @override
  Future<void> startListening() async {
    starts++;
    input.add('injected');
  }

  @override
  Future<void> stopListening() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final target in TargetPlatform.values.where(
    (p) => p != TargetPlatform.fuchsia,
  )) {
    group(target.name, () {
      final keyboardOnly = kIsWeb || target != TargetPlatform.android;

      void platformTest(String name, WidgetTesterCallback callback) {
        testWidgets(name, callback, variant: TargetPlatformVariant({target}));
      }

      if (keyboardOnly) {
        platformTest('$target auto uses HID without native channel calls', (
          tester,
        ) async {
          final calls = _recordNativeCalls();
          final scanner = Scanner(
            options: const ScannerOptions(configureIminOutput: true),
          );
          final reads = <BarcodeScan>[];
          final subscription = scanner.events.listen(reads.add);
          addTearDown(() => _complete(tester, scanner.dispose()));
          addTearDown(subscription.cancel);
          await tester.pumpWidget(const MaterialApp(home: SizedBox()));
          await _complete(tester, scanner.start());
          await _scan(tester, '00123');
          await _scan(tester, '00123', tab: true);
          expect(reads.map((s) => s.barcode), ['00123', '00123']);
          expect(reads.map((s) => s.eventId).toSet(), hasLength(2));
          expect(reads.every((s) => s.occurredAt.isUtc), isTrue);
          await _complete(tester, scanner.stop());
          await _scan(tester, 'ignored');
          expect(reads, hasLength(2));
          await _complete(tester, scanner.start());
          await _scan(tester, 'again');
          expect(reads.last.barcode, 'again');
          await _complete(tester, scanner.dispose());
          expect(calls, isEmpty);
        });

        platformTest('$target rejects native mode and releases ownership', (
          tester,
        ) async {
          final calls = _recordNativeCalls();
          final native = Scanner(
            options: const ScannerOptions(mode: ScannerMode.iminBroadcast),
          );
          final hid = Scanner();
          addTearDown(() => _complete(tester, native.dispose()));
          addTearDown(() => _complete(tester, hid.dispose()));
          await _complete(
            tester,
            expectLater(
              native.start(),
              throwsA(
                isA<UnsupportedError>().having(
                  (e) => e.message,
                  'actionable message',
                  contains('Android'),
                ),
              ),
            ),
          );
          await _complete(tester, hid.start());
          await _complete(tester, hid.dispose());
          await _complete(tester, native.dispose());
          expect(calls, isEmpty);
        });

        platformTest('$target listener respects focus, enable and app state', (
          tester,
        ) async {
          final calls = _recordNativeCalls();
          final scanner = Scanner();
          final focus = FocusNode();
          addTearDown(() => _complete(tester, scanner.dispose()));
          addTearDown(focus.dispose);
          final reads = <String>[];
          final errors = <Object>[];
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          Widget view({bool enabled = true}) => MaterialApp(
            home: Scaffold(
              body: ScannerListener(
                createScanner: () => scanner,
                enabled: enabled,
                onScan: (scan) => reads.add(scan.barcode),
                onError: (error, _) => errors.add(error),
                child: TextField(focusNode: focus),
              ),
            ),
          );
          await tester.pumpWidget(view());
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.digit9, character: '9');
          focus.requestFocus();
          await tester.pump();
          await _scan(tester, 'ignored');
          focus.unfocus();
          await tester.pump();
          await _scan(tester, '00123');
          expect(reads, ['00123']);
          await tester.pumpWidget(view(enabled: false));
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pumpAndSettle();
          await _scan(tester, 'disabled');
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pumpAndSettle();
          await _scan(tester, 'still disabled');
          expect(reads, ['00123']);
          await tester.pumpWidget(view());
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pumpAndSettle();
          await _scan(tester, 'resumed');
          expect(reads, ['00123', 'resumed']);
          await tester.pumpWidget(const SizedBox());
          await _complete(tester, scanner.dispose());
          expect(errors, isEmpty);
          expect(calls, isEmpty);
        });
      } else {
        platformTest(
          'native Android keeps bridge inspection and configuration',
          (tester) async {
            final calls = _recordNativeCalls();
            final scanner = Scanner(
              options: const ScannerOptions(configureIminOutput: true),
            );
            await _complete(tester, scanner.start());
            await _complete(tester, scanner.dispose());
            expect(calls['inspectHost'], 1);
            expect(calls['startListening'], 1);
            expect(calls['preferBroadcastOutput'], 1);
            expect(calls['stopListening'], 1);
            expect(calls['events.listen'], 1);
            expect(calls['events.cancel'], 1);
          },
        );
      }

      platformTest('$target keeps explicit platform injection authoritative', (
        tester,
      ) async {
        final platform = _InjectedPlatform();
        final scanner = Scanner(platform: platform);
        final reads = <String>[];
        final subscription = scanner.events.listen((s) => reads.add(s.barcode));
        await _complete(tester, scanner.start());
        expect(reads, ['injected']);
        expect(platform.starts, 1);
        await _complete(tester, scanner.dispose());
        await _complete(tester, subscription.cancel());
        await _complete(tester, platform.input.close());
      });
    });
  }
}
