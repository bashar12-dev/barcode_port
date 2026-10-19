import 'hid_scanner.dart';
import 'imin_broadcast_scanner.dart';
import 'resolving_scanner.dart';
import 'scanner_options.dart';
import 'scanner_platform.dart';
import 'processing_scanner.dart';
import 'scan_processing_options.dart';

/// Convenient owner of a single active scanner transport.
final class Scanner extends ResolvingScanner {
  /// Creates an owner with optional platform injection and text processing.
  ///
  /// [options] selects transport and input policy. [processing] is disabled by
  /// default. Configuring device output requires an explicit opt-in in options.
  factory Scanner({
    ScannerOptions options = const ScannerOptions(),
    ScannerPlatform? platform,
    ScanProcessingOptions processing = const ScanProcessingOptions(),
  }) {
    final host = platform ?? BridgeScannerPlatform();
    return Scanner._(options, host, processing);
  }

  Scanner._(
    ScannerOptions options,
    ScannerPlatform host,
    ScanProcessingOptions processing,
  ) : super(
        broadcast: ProcessingScanner(
          source: IminBroadcastScanner(platform: host),
          options: processing,
        ),
        hid: ProcessingScanner(
          source: HidScanner(options: options),
          options: processing,
        ),
        platform: host,
        options: options,
      );
}
