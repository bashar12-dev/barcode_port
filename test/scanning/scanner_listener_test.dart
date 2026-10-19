import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barcode_port/scanner_widgets.dart';
import 'test_scanner.dart';
import 'widget_lifecycle.dart';

Widget _view(
  TestScanner scanner, {
  bool enabled = true,
  ValueChanged<BarcodeScan>? onScan,
  void Function(Object, StackTrace)? onError,
  ValueChanged<ScannerDiagnostic>? onDiagnostic,
}) => MaterialApp(
  home: Scaffold(
    body: ScannerListener(
      createScanner: () => scanner,
      enabled: enabled,
      onScan: onScan ?? (_) {},
      onError: onError,
      onDiagnostic: onDiagnostic,
      child: const Text('scan area'),
    ),
  ),
);

void main() {
  testWidgets(
    'eligibility cycle during startup clears the old session before delivering',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final gate = Completer<void>();
      final source = TestScanner()..starting = () => gate.future;
      final reads = <BarcodeScan>[];
      await tester.pumpWidget(_view(source, onScan: reads.add));
      await tester.pump();
      await tester.pumpWidget(_view(source, enabled: false, onScan: reads.add));
      await tester.pumpWidget(_view(source, onScan: reads.add));
      source.frames.add(frame('old', 'old'));
      expect(reads, isEmpty);
      gate.complete();
      await tester.pumpAndSettle();
      expect(source.starts, 2);
      expect(source.stops, 1);
      source.frames.add(frame('fresh', 'fresh'));
      expect(reads.single.eventId, 'fresh');
      await tester.pumpWidget(const SizedBox());
      await pumpUntil(tester, () => source.disposed);
    },
  );

  testWidgets('a competing listener cannot take or stop the active HID owner', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final owner = HidScanner();
    final contender = HidScanner();
    final reads = <String>[];
    final errors = <Object>[];
    Widget view(bool showContender) => MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ScannerListener(
              key: const ValueKey('owner'),
              createScanner: () => owner,
              onScan: (s) => reads.add(s.barcode),
              child: const Text('owner'),
            ),
            if (showContender)
              ScannerListener(
                key: const ValueKey('contender'),
                createScanner: () => contender,
                onScan: (_) => fail('contender received input'),
                onError: (e, _) => errors.add(e),
                child: const Text('contender'),
              ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(view(true));
    await tester.pumpAndSettle();
    expect(errors.single, isA<StateError>());
    await tester.pumpWidget(view(false));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1, character: '1');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(reads, ['1']);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'factory is stable, latest callbacks receive startup frames and diagnostics',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final source = TestScanner();
      source.starting = () async =>
          source.frames.add(frame('initial', 'initial'));
      var created = 0;
      final first = <String>[];
      final second = <String>[];
      final notices = <ScannerDiagnostic>[];
      Widget view(ValueChanged<BarcodeScan> callback) => MaterialApp(
        home: ScannerListener(
          createScanner: () {
            created++;
            return source;
          },
          onScan: callback,
          onDiagnostic: notices.add,
          child: const SizedBox(),
        ),
      );
      await tester.pumpWidget(view((s) => first.add(s.eventId)));
      await tester.pumpAndSettle();
      expect(first, ['initial']);
      await tester.pumpWidget(view((s) => second.add(s.eventId)));
      source.frames.add(frame('later', 'later'));
      source.notices.add(
        ScannerDiagnostic(
          reason: ScannerDiagnosticReason.filtered,
          occurredAt: DateTime.utc(2026),
          inputLength: 5,
        ),
      );
      expect(created, 1);
      expect(second, ['later']);
      expect(notices, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await pumpUntil(tester, () => source.disposed);
      expect(source.disposed, isTrue);
    },
  );

  testWidgets(
    'enabled and app lifecycle combine without resuming a disabled scanner',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final source = TestScanner();
      final reads = <String>[];
      await tester.pumpWidget(
        _view(source, onScan: (s) => reads.add(s.eventId)),
      );
      await tester.pumpAndSettle();
      expect(source.active, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      source.frames.add(frame('late', 'late'));
      await tester.pumpAndSettle();
      expect(source.active, isFalse);
      expect(reads, isEmpty);
      await tester.pumpWidget(
        _view(source, enabled: false, onScan: (s) => reads.add(s.eventId)),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(source.active, isFalse);
      await tester.pumpWidget(
        _view(source, onScan: (s) => reads.add(s.eventId)),
      );
      await tester.pumpAndSettle();
      source.frames.add(frame('ok', 'ok'));
      expect(reads, ['ok']);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  for (final dialog in [false, true]) {
    testWidgets(
      '${dialog ? "dialog" : "route"} coverage stops and restores eligible input',
      (tester) async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        final source = TestScanner();
        final reads = <String>[];
        await tester.pumpWidget(
          _view(source, onScan: (s) => reads.add(s.eventId)),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.text('scan area'));
        if (dialog) {
          unawaited(
            showDialog<void>(
              context: context,
              builder: (_) => const AlertDialog(content: Text('covered')),
            ),
          );
        } else {
          unawaited(
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('covered')),
              ),
            ),
          );
        }
        await tester.pumpAndSettle();
        expect(source.active, isFalse);
        source.frames.add(frame('covered', 'covered'));
        expect(reads, isEmpty);
        // Focus changes and app resume must not bypass the covered-route gate.
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(source.active, isFalse);
        Navigator.of(tester.element(find.text('covered'))).pop();
        await tester.pumpAndSettle();
        expect(source.active, isTrue);
        source.frames.add(frame('visible', 'visible'));
        expect(reads, ['visible']);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'disabled gate drops delivery immediately while native stop is pending',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final source = TestScanner();
      final reads = <BarcodeScan>[];
      final notices = <ScannerDiagnostic>[];
      await tester.pumpWidget(
        _view(source, onScan: reads.add, onDiagnostic: notices.add),
      );
      await tester.pumpAndSettle();
      final stopGate = Completer<void>();
      source.stopping = () => stopGate.future;
      await tester.pumpWidget(
        _view(
          source,
          enabled: false,
          onScan: reads.add,
          onDiagnostic: notices.add,
        ),
      );
      source.frames.add(frame('late', 'late'));
      source.notices.add(
        ScannerDiagnostic(
          reason: ScannerDiagnosticReason.filtered,
          occurredAt: DateTime.utc(2026),
          inputLength: 4,
        ),
      );
      expect(reads, isEmpty);
      expect(notices, isEmpty);
      stopGate.complete();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'failed startup has no retry loop and retries after eligibility cycles',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final source = TestScanner()
        ..starting = () async => throw StateError('device');
      final errors = <Object>[];
      void error(Object e, StackTrace _) => errors.add(e);
      await tester.pumpWidget(_view(source, onError: error));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_view(source, onError: error));
      await tester.pumpAndSettle();
      expect(source.starts, 1);
      expect(errors, hasLength(1));
      await tester.pumpWidget(_view(source, enabled: false, onError: error));
      await tester.pumpAndSettle();
      source.starting = null;
      await tester.pumpWidget(_view(source, onError: error));
      await tester.pumpAndSettle();
      expect(source.active, isTrue);
      expect(source.starts, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'unmount during pending start waits to dispose and never delivers late frames',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final gate = Completer<void>();
      final source = TestScanner()..starting = () => gate.future;
      final reads = <BarcodeScan>[];
      await tester.pumpWidget(_view(source, onScan: reads.add));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      source.frames.add(frame('late', 'late'));
      expect(reads, isEmpty);
      gate.complete();
      await tester.pumpAndSettle();
      await pumpUntil(tester, () => source.disposed);
      expect(source.disposed, isTrue);
      expect(source.active, isFalse);
      expect(source.frames.hasListener || source.notices.hasListener, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(source.starts, 1);
    },
  );

  testWidgets(
    'cleanup attempts dispose even if stop fails and reports final dispose failure',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final source = TestScanner();
      var triedDispose = false;
      final reported = <FlutterErrorDetails>[];
      final originalErrorHandler = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = originalErrorHandler);
      await tester.pumpWidget(_view(source));
      await tester.pumpAndSettle();
      source.stopping = () async => throw StateError('stop');
      source.disposing = () async {
        triedDispose = true;
        throw StateError('dispose');
      };
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await pumpUntil(tester, () => reported.isNotEmpty);
      expect(triedDispose, isTrue);
      expect(reported.single.exception, isA<StateError>());
      expect(source.frames.hasListener || source.notices.hasListener, isFalse);
      source.stopping = null;
      source.disposing = null;
      await completeLifecycle(tester, source.dispose());
    },
  );

  testWidgets('initial background and lifecycle opt-out are honored', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final source = TestScanner();
    await tester.pumpWidget(_view(source));
    await tester.pumpAndSettle();
    expect(source.active, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(source.active, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScannerListener(
            createScanner: () => source,
            pauseWhenAppInactive: false,
            onScan: (_) {},
            child: const Text('scan area'),
          ),
        ),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(source.active, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}
