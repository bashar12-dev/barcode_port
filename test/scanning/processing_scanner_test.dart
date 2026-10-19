import 'package:flutter_test/flutter_test.dart';
import 'package:barcode_port/barcode_port.dart';
import 'test_scanner.dart';

void main() {
  test(
    'dispose attempts owned-source disposal despite persistent stop failure',
    () async {
      final source = TestScanner();
      final scanner = ProcessingScanner(source: source);
      await scanner.start();
      source.stopping = () async => throw StateError('stop');
      await expectLater(scanner.dispose(), throwsStateError);
      final attempted = source.disposed;
      source.stopping = null;
      await scanner.dispose();
      expect(attempted, isTrue);
    },
  );

  test(
    'defaults preserve original internal-code frames and repeated identities',
    () async {
      final source = TestScanner();
      final scanner = ProcessingScanner(source: source);
      final reads = <BarcodeScan>[];
      final sub = scanner.events.listen(reads.add);
      await scanner.start();
      final first = frame('first', 'internal_code');
      final second = frame('second', 'internal_code');
      source.frames.add(first);
      source.frames.add(second);
      await Future<void>.delayed(Duration.zero);
      expect(reads, [same(first), same(second)]);
      await sub.cancel();
      await scanner.dispose();
      expect(source.disposed, isTrue);
    },
  );

  test(
    'normalization then trim precedes validation and preserves identity metadata',
    () async {
      final source = TestScanner();
      final observed = <String>[];
      final scanner = ProcessingScanner(
        source: source,
        options: ScanProcessingOptions(
          normalize: (v) => ' ${v.toUpperCase()} ',
          accept: (v) {
            observed.add(v);
            return v == 'ITEM';
          },
        ),
      );
      final reads = <BarcodeScan>[];
      final rejected = <ScannerDiagnostic>[];
      final a = scanner.events.listen(reads.add);
      final b = scanner.diagnostics.listen(rejected.add);
      await scanner.start();
      source.frames.add(frame('a', 'item'));
      source.frames.add(frame('b', 'other'));
      await Future<void>.delayed(Duration.zero);
      expect(observed, ['ITEM', 'OTHER']);
      expect(reads.single.barcode, 'ITEM');
      expect(reads.single.eventId, 'a');
      expect(reads.single.occurredAt, DateTime.utc(2026, 10, 20));
      expect(rejected.single.reason, ScannerDiagnosticReason.filtered);
      expect(rejected.single.eventId, 'b');
      await a.cancel();
      await b.cancel();
      await scanner.dispose();
    },
  );

  test('blank normalization rejects before validation', () async {
    final source = TestScanner();
    final scanner = ProcessingScanner(
      source: source,
      options: ScanProcessingOptions(
        normalize: (_) => '  ',
        accept: (_) => throw StateError('must not run'),
      ),
    );
    final reads = <BarcodeScan>[];
    final rejected = <ScannerDiagnostic>[];
    final a = scanner.events.listen(reads.add);
    final b = scanner.diagnostics.listen(rejected.add);
    await scanner.start();
    source.frames.add(frame('a', 'abc'));
    await Future<void>.delayed(Duration.zero);
    expect(reads, isEmpty);
    expect(rejected.single.reason, ScannerDiagnosticReason.normalizedEmpty);
    await a.cancel();
    await b.cancel();
    await scanner.dispose();
  });

  test(
    'duplicate boundary uses last accepted frame without extending the window',
    () async {
      final source = TestScanner();
      var elapsed = Duration.zero;
      final scanner = ProcessingScanner(
        source: source,
        elapsed: () => elapsed,
        options: const ScanProcessingOptions(
          duplicateWindow: Duration(milliseconds: 500),
        ),
      );
      final reads = <BarcodeScan>[];
      final rejected = <ScannerDiagnostic>[];
      final a = scanner.events.listen(reads.add);
      final b = scanner.diagnostics.listen(rejected.add);
      await scanner.start();
      source.frames.add(frame('a0', 'A'));
      elapsed = const Duration(milliseconds: 499);
      source.frames.add(frame('dup', 'A'));
      elapsed = const Duration(milliseconds: 500);
      source.frames.add(frame('a1', 'A'));
      elapsed = const Duration(milliseconds: 501);
      source.frames.add(frame('b', 'B'));
      elapsed = const Duration(milliseconds: 502);
      source.frames.add(frame('a2', 'A'));
      await Future<void>.delayed(Duration.zero);
      expect(reads.map((s) => s.eventId), ['a0', 'a1', 'b', 'a2']);
      expect(
        rejected.single.reason,
        ScannerDiagnosticReason.duplicateSuppressed,
      );
      expect(rejected.single.eventId, 'dup');
      await scanner.stop();
      await scanner.start();
      source.frames.add(frame('restart', 'A'));
      await Future<void>.delayed(Duration.zero);
      expect(reads.last.eventId, 'restart');
      await a.cancel();
      await b.cancel();
      await scanner.dispose();
    },
  );

  test('deduplication compares normalized text', () async {
    final source = TestScanner();
    final scanner = ProcessingScanner(
      source: source,
      options: ScanProcessingOptions(
        normalize: (v) => v.toUpperCase(),
        duplicateWindow: const Duration(seconds: 1),
      ),
      elapsed: () => Duration.zero,
    );
    final reads = <BarcodeScan>[];
    final a = scanner.events.listen(reads.add);
    await scanner.start();
    source.frames.add(frame('a', 'abc'));
    source.frames.add(frame('b', 'ABC'));
    await Future<void>.delayed(Duration.zero);
    expect(reads.map((s) => s.eventId), ['a']);
    await a.cancel();
    await scanner.dispose();
  });

  for (final normalizeThrows in [true, false]) {
    test(
      '${normalizeThrows ? "normalizer" : "validator"} errors do not stop later frames',
      () async {
        final source = TestScanner();
        final scanner = ProcessingScanner(
          source: source,
          options: ScanProcessingOptions(
            normalize: normalizeThrows
                ? (v) {
                    if (v == 'bad') throw StateError('normalize');
                    return v;
                  }
                : null,
            accept: normalizeThrows
                ? null
                : (v) {
                    if (v == 'bad') throw StateError('accept');
                    return true;
                  },
          ),
        );
        final reads = <BarcodeScan>[];
        final errors = <Object>[];
        final stacks = <StackTrace>[];
        final a = scanner.events.listen(
          reads.add,
          onError: (Object e, StackTrace s) {
            errors.add(e);
            stacks.add(s);
          },
        );
        await scanner.start();
        source.frames.add(frame('bad', 'bad'));
        source.frames.add(frame('ok', 'ok'));
        await Future<void>.delayed(Duration.zero);
        expect(errors.single, isA<StateError>());
        expect(stacks.single.toString(), isNotEmpty);
        expect(reads.single.eventId, 'ok');
        await a.cancel();
        await scanner.dispose();
      },
    );
  }

  test(
    'subscribes before synchronous startup and forwards diagnostics and errors once',
    () async {
      final source = TestScanner();
      final initial = frame('startup', 'startup');
      source.starting = () async => source.frames.add(initial);
      final scanner = ProcessingScanner(source: source);
      final reads = <BarcodeScan>[];
      final rejected = <ScannerDiagnostic>[];
      final errors = <Object>[];
      final a = scanner.events.listen(reads.add, onError: errors.add);
      final b = scanner.diagnostics.listen(rejected.add);
      await scanner.start();
      final notice = ScannerDiagnostic(
        reason: ScannerDiagnosticReason.blankFrame,
        occurredAt: DateTime.utc(2026),
        inputLength: 1,
      );
      source.notices.add(notice);
      source.frames.addError(StateError('device'));
      await Future<void>.delayed(Duration.zero);
      expect(reads.single, same(initial));
      expect(rejected, [same(notice)]);
      expect(errors.single, isA<StateError>());
      await scanner.stop();
      source.frames.add(frame('stopped', 'stopped'));
      await Future<void>.delayed(Duration.zero);
      expect(reads, hasLength(1));
      var eventClosed = false;
      var diagnosticClosed = false;
      final c = scanner.events.listen((_) {}, onDone: () => eventClosed = true);
      final d = scanner.diagnostics.listen(
        (_) {},
        onDone: () => diagnosticClosed = true,
      );
      await a.cancel();
      await b.cancel();
      await scanner.dispose();
      expect(eventClosed && diagnosticClosed, isTrue);
      await c.cancel();
      await d.cancel();
      await expectLater(scanner.start(), throwsStateError);
    },
  );

  test('rejects negative duplicate windows', () {
    final source = TestScanner();
    expect(
      () => ProcessingScanner(
        source: source,
        options: const ScanProcessingOptions(
          duplicateWindow: Duration(milliseconds: -1),
        ),
      ),
      throwsArgumentError,
    );
    addTearDown(source.dispose);
  });
}
