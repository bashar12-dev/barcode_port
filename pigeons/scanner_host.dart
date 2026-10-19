import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    // Keep the original wire namespace compatible with the Android host.
    dartPackageName: 'scanner_bridge',
    dartOut: 'lib/src/generated/scanner_host.g.dart',
    kotlinOut:
        'android/src/main/kotlin/com/ultimate/pos/scanner_bridge/ScannerHost.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.ultimate.pos.scanner_bridge'),
  ),
)
class ScannerHostInspection {
  ScannerHostInspection({
    required this.listening,
    required this.preferNativeBroadcast,
  });
  bool listening;
  bool preferNativeBroadcast;
}

@HostApi()
abstract class ScannerHostApi {
  ScannerHostInspection inspectHost();
  void startListening();
  void stopListening();
  bool preferBroadcastOutput();
}
