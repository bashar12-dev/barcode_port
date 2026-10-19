import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barcode_port/scanner_bridge.dart';
import 'package:barcode_port/src/generated/scanner_host.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const start = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.scanner_bridge.ScannerHostApi.startListening',
    ScannerHostApi.pigeonChannelCodec,
  );
  const stop = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.scanner_bridge.ScannerHostApi.stopListening',
    ScannerHostApi.pigeonChannelCodec,
  );

  test('a rejected contender cannot stop the active native receiver', () async {
    var stops = 0;
    messenger.setMockDecodedMessageHandler<Object?>(start, (_) async => [null]);
    messenger.setMockDecodedMessageHandler<Object?>(stop, (_) async {
      stops++;
      return [null];
    });
    final owner = ScannerBridge();
    final contender = ScannerBridge();
    addTearDown(() async {
      await owner.stopListening();
      await contender.stopListening();
      messenger.setMockDecodedMessageHandler<Object?>(start, null);
      messenger.setMockDecodedMessageHandler<Object?>(stop, null);
    });
    await owner.startListening();
    await expectLater(contender.startListening(), throwsStateError);
    await contender.stopListening();
    expect(stops, 0);
    await owner.stopListening();
    await contender.startListening();
    await contender.stopListening();
    expect(stops, 2);
  });

  test(
    'native cleanup failure retains ownership until cleanup succeeds',
    () async {
      var failStop = true;
      messenger.setMockDecodedMessageHandler<Object?>(
        start,
        (_) async => [null],
      );
      messenger.setMockDecodedMessageHandler<Object?>(
        stop,
        (_) async => failStop ? ['stop-failed', 'busy', null] : [null],
      );
      final owner = ScannerBridge();
      final contender = ScannerBridge();
      addTearDown(() async {
        failStop = false;
        await owner.stopListening();
        await contender.stopListening();
        messenger.setMockDecodedMessageHandler<Object?>(start, null);
        messenger.setMockDecodedMessageHandler<Object?>(stop, null);
      });
      await owner.startListening();
      await expectLater(
        owner.stopListening(),
        throwsA(isA<PlatformException>()),
      );
      await expectLater(contender.startListening(), throwsStateError);
      failStop = false;
      await owner.stopListening();
      await contender.startListening();
    },
  );

  test('default consumers share the same native barcode stream', () {
    final first = ScannerBridge();
    final second = ScannerBridge();
    expect(identical(first.barcodes(), first.barcodes()), isTrue);
    expect(identical(first.barcodes(), second.barcodes()), isTrue);
  });
}
