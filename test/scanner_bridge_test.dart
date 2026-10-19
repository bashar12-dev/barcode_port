import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:barcode_port/scanner_bridge.dart';
import 'package:barcode_port/src/generated/scanner_host.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const inspect = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.scanner_bridge.ScannerHostApi.inspectHost',
    ScannerHostApi.pigeonChannelCodec,
  );

  tearDown(() {
    messenger.setMockDecodedMessageHandler<Object?>(inspect, null);
  });

  test('Pigeon inspect preserves flags without inventing a live listener', () async {
    messenger.setMockDecodedMessageHandler<Object?>(inspect, (_) async {
      return [
        ScannerHostInspection(
          listening: false,
          preferNativeBroadcast: true,
        ),
      ];
    });
    final result = await ScannerBridge().inspectHost();
    expect(result.listening, isFalse);
    expect(result.preferNativeBroadcast, isTrue);
  });

  test('missing host fails instead of fabricating inspection', () async {
    await expectLater(
      ScannerBridge().inspectHost(),
      throwsA(isA<PlatformException>()),
    );
  });

  test('barcodes() reads decode maps and rejects blanks', () async {
    const channel = EventChannel(ScannerBridge.scansChannelName);
    messenger.setMockStreamHandler(
      channel,
      MockStreamHandler.inline(
        onListen: (Object? _, MockStreamHandlerEventSink sink) {
          sink.success(<String, Object?>{'barcode': ' 12345 '});
          sink.success(<String, Object?>{'barcode': '   '});
          sink.success('67890');
        },
      ),
    );
    addTearDown(() => messenger.setMockStreamHandler(channel, null));

    final values = await ScannerBridge().barcodes().take(2).toList();
    expect(values, ['12345', '67890']);
  });

  test('preferBroadcastOutput uses the host bool and does not default true', () async {
    const channel = BasicMessageChannel<Object?>(
      'dev.flutter.pigeon.scanner_bridge.ScannerHostApi.preferBroadcastOutput',
      ScannerHostApi.pigeonChannelCodec,
    );
    messenger.setMockDecodedMessageHandler<Object?>(channel, (_) async => [true]);
    addTearDown(() => messenger.setMockDecodedMessageHandler<Object?>(channel, null));
    expect(await ScannerBridge().preferBroadcastOutput(), isTrue);
  });
}
