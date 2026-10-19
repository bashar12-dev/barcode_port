import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:barcode_port/barcode_port.dart';
import 'package:barcode_port/src/scanning/managed_scanner.dart';

class _Scanner extends ManagedScanner {
  Future<void> Function()? starting;
  Future<void> Function()? stopping;
  var starts = 0;
  var stops = 0;
  var active = false;

  @override
  Future<void> onStart() async {
    starts++;
    await starting?.call();
    active = true;
  }

  @override
  Future<void> onStop() async {
    stops++;
    await stopping?.call();
    active = false;
  }

  void read(BarcodeScan scan) => emit(scan);
  void fail(Object error) => emitError(error, StackTrace.current);
}

void main() {
  test('a failed start releases resources and permits retry', () async {
    final scanner = _Scanner()
      ..starting = () async => throw StateError('start');
    await expectLater(scanner.start(), throwsStateError);
    expect(scanner.active, isFalse);
    expect(scanner.stops, 1);
    scanner.starting = null;
    await scanner.start();
    expect(scanner.active, isTrue);
    await scanner.dispose();
  });

  test('concurrent starts activate a single source', () async {
    final scanner = _Scanner();
    await Future.wait([scanner.start(), scanner.start(), scanner.start()]);
    expect(scanner.starts, 1);
    await scanner.dispose();
  });

  test('stop waits for pending start and leaves no active source', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final scanner = _Scanner()
      ..starting = () {
        entered.complete();
        return release.future;
      };
    final start = scanner.start();
    await entered.future;
    final stop = scanner.stop();
    release.complete();
    await Future.wait([start, stop]);
    expect(scanner.active, isFalse);
    scanner.starting = null;
    await scanner.start();
    expect(scanner.active, isTrue);
    await scanner.dispose();
  });

  test('dispose closes events and rejects further starts', () async {
    final scanner = _Scanner();
    final done = Completer<void>();
    final sub = scanner.events.listen((_) {}, onDone: done.complete);
    await scanner.start();
    await scanner.dispose();
    await done.future;
    await scanner.dispose();
    await scanner.stop();
    await expectLater(scanner.start(), throwsStateError);
    expect(scanner.active, isFalse);
    await sub.cancel();
  });

  test('all consumers receive the same identity and stream errors', () async {
    final scanner = _Scanner();
    final first = <BarcodeScan>[];
    final second = <BarcodeScan>[];
    final errors = <Object>[];
    final a = scanner.events.listen(first.add, onError: errors.add);
    final b = scanner.events.listen(second.add, onError: (Object _) {});
    await scanner.start();
    scanner.read(
      BarcodeScan(
        eventId: 'frame-1',
        barcode: '123',
        occurredAt: DateTime.utc(2026),
      ),
    );
    scanner.fail(StateError('connection lost'));
    await Future<void>.delayed(Duration.zero);
    expect(first.single.eventId, 'frame-1');
    expect(identical(first.single, second.single), isTrue);
    expect(errors.single, isA<StateError>());
    await a.cancel();
    await b.cancel();
    await scanner.dispose();
  });

  test('failed cleanup is retried before a new source can start', () async {
    final scanner = _Scanner();
    await scanner.start();
    scanner.stopping = () async => throw StateError('cleanup');
    await expectLater(scanner.stop(), throwsStateError);
    await expectLater(scanner.start(), throwsStateError);
    expect(scanner.starts, 1);
    scanner.stopping = null;
    await scanner.start();
    expect(scanner.starts, 2);
    await scanner.dispose();
  });
}
