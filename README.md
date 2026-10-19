# BarcodePort

Hardware barcode input for Flutter.

واجهة موحّدة لاستقبال قراءات أجهزة الباركود في تطبيقات Flutter.

Reusable Flutter barcode input with keyboard-wedge HID and Android iMin
broadcasts. No checkout models, Riverpod, database, ECR, or payment dependencies.

## Use

Add this package as a path or Git dependency and import the high-level API:

```yaml
dependencies:
  barcode_port:
    path: packages/barcode_port
```

```dart
import 'package:barcode_port/barcode_port.dart';

final scanner = Scanner(
  options: const ScannerOptions(
    mode: ScannerMode.auto,
    configureIminOutput: true,
  ),
);

final subscription = scanner.events.listen(
  (scan) {
    // eventId, barcode, occurredAt (UTC).
    // Map this reading into your application's own model here.
    print(scan.barcode);
  },
  onError: (Object error, StackTrace stack) {
    // Present or log an input error in your application.
  },
);

await scanner.start();
// Later: await scanner.stop(); await scanner.start();
// When this owner is permanently finished:
await subscription.cancel();
await scanner.dispose();
```

Handle failures of start/stop/dispose as well as stream errors. A failed start
cleans up acquired resources and permits retry. If cleanup itself fails, retry
stop/dispose; another owner must not take the native receiver before cleanup
succeeds. Lifecycle operations are serialized; stop waits for pending startup
and leaves no active input when it completes. Dispose prevents future starts,
releases owned input, and closes events. Cancel or resume paused event
subscriptions before awaiting disposal, since paused listeners can delay stream
completion.

Use one Scanner owner for the application's active scan area. Multiple listeners
on its events are supported; each observes the same scan identity. The package
rejects competing Scanner/ResolvingScanner owners across transports within the
Dart isolate. Direct HID and iMin transports also guard their respective input
resources. Engines have their own plugin instances; coordinating several engines
or simultaneous physical scanners is outside the current ownership contract.

See [the standalone example](example/lib/main.dart). It has its own Android host
and depends only on this package. It is not wired to the checkout project.

## Input policy

| Option | Default | Meaning |
|---|---|---|
| mode | auto | Prefer iMin broadcasts when host metadata looks like iMin; use HID when inspection fails or does not prefer iMin |
| configureIminOutput | false | Explicitly request broadcast output and disable analog keyboard output when using the iMin transport |
| frameTimeout | 2 seconds | Discard an incomplete HID frame after an inter-character gap |
| terminators | Enter, Tab | Complete the current HID frame |
| maxFrameLength | 4096 UTF-16 code units | Discard an oversized HID frame through its terminator or idle timeout |
| passThroughEditableText | true | Leave hardware keys to an editable field while it has focus |

Use ScannerMode.hid or ScannerMode.iminBroadcast to bypass host heuristics. Auto
selects one transport per start; it does not silently switch after a start error
or infer hardware failure from a period without scans. Setting
configureIminOutput changes device output settings and stop does not restore the
previous settings. The configuration response is a host heuristic, not a device
acknowledgment. A registered Android receiver is not proof of scanner readiness.

HID is keyboard input, not USB-device discovery: ordinary hardware typing can
also form a frame. A visible/hidden TextField is not required to collect HID
outside editable focus. While a field is focused, the default policy leaves its
input alone. Setting passThroughEditableText false does not guarantee suppression
of text entry: HardwareKeyboard handlers also run alongside other Flutter
handlers. Applications needing capture while editing must design and verify
their focus/input integration. Custom terminator lists are snapshotted by the
HID collector when it is constructed.

Barcode text is trimmed and blanks are discarded, preserving the existing
kiosk behavior. Android byte payloads are decoded as UTF-8. This is not a
lossless arbitrary QR/binary-data API. Every new frame gets a new eventId, even
when its barcode repeats. There is no time-based deduplication; replaying an
existing event in application code should retain its ID. Device broadcasts do
not include a reliable frame ID, so duplicate native broadcasts cannot be
distinguished from deliberate repeated scans by this package alone.

## Optional processing (0.3.0)

Defaults continue to accept internal codes and consecutive intentional scans.
No format is inferred from text length and no GS1 prefix is removed.

```dart
final scanner = Scanner(
  processing: ScanProcessingOptions(
    normalize: (value) => value.toUpperCase(), // explicit application policy
    accept: (value) => value.startsWith('ITEM-'),
    // Only opt in where repeated scans do not represent additional items:
    duplicateWindow: const Duration(milliseconds: 500),
  ),
);
```

Processing order is normalize, trim, reject empty, filter, suppress consecutive
accepted repeats, deliver. Identity and UTC observation time are retained after
normalization. With defaults the original event object is passed through.
The duplicate window defaults to zero (disabled), uses a monotonic clock, and
rejects only intervals strictly less than the window. Rejected repeats do not
extend it; A/B/A are separate accepted frames. Stop/restart resets the window.
Callback exceptions arrive on events as errors with their stack, without
preventing subsequent frames from being processed. Negative windows are invalid.

For a custom source use ProcessingScanner(source: source, options: options).
The decorator owns the source, including disposal. Do not wrap an already
configured Scanner with the same policy a second time. Direct HidScanner and
IminBroadcastScanner are unprocessed unless explicitly wrapped.

## Diagnostics (0.3.0)

Built-in scanners implement the additive DiagnosticBarcodeScanner capability;
third-party implementations of BarcodeScanner need not implement it.

```dart
final diagnosticSubscription = scanner.diagnostics.listen((notice) {
  print('${notice.reason.name}, length=${notice.inputLength}');
});
```

Reasons: incompleteFrame (a nonempty frame expired), frameOverflow,
blankFrame, filtered, normalizedEmpty, duplicateSuppressed. Diagnostic time is
UTC; eventId is present when a complete frame already exists. No barcode text
is included or automatically logged. Operational errors remain on events.
Overflow reports once and discards through the terminator or idle timeout;
empty terminators and intentional focus/stop/dispose resets are silent.
Dispose closes both streams. Cancel/resume paused subscriptions before awaiting
disposal because paused listeners can delay stream completion.

## Optional screen lifecycle (0.3.0)

```dart
import 'package:barcode_port/scanner_widgets.dart';

ScannerListener(
  createScanner: () => Scanner(),
  enabled: isScanTabVisible,
  onScan: (scan) => handleBarcode(scan.barcode),
  onDiagnostic: (notice) => handleDiscard(notice.reason),
  onError: (error, stack) => handleInputError(error, stack),
  child: scanScreen,
);
```

The widget creates one scanner per State and owns its start/stop/dispose.
Changing the factory or options during rebuild does not replace that source;
use a new key when replacing it, and explicitly await old-source cleanup before
starting a different owner. Simultaneous owners still fail instead of stealing
input. For applications needing explicit asynchronous handoff use the headless
API and await stop before starting the next owner.

Reception requires enabled=true, the current route, and a resumed app.
pauseWhenRouteCovered and pauseWhenAppInactive default true and can be opted out
independently. A null initial lifecycle is treated as foreground; explicit
inactive/hidden/paused/detached states pause reception. ModalRoute.isCurrentOf
tracks covering pages/dialogs. Hidden tabs and nested navigators must explicitly
provide visibility through enabled; the nearest route cannot determine that.

Scan/diagnostic callbacks stop immediately when ineligible, even while an
asynchronous stop is pending. Startup frames are retained for the eligible
session. Failed transitions report through onError (or FlutterError if omitted)
and are retried only after eligibility becomes false then true. Latest callback
references are used without recreating the source.

State.dispose is synchronous: it disables delivery and removes observers first,
then schedules handled serialized cleanup after pending work. It cancels
subscriptions, attempts stop, and always attempts dispose. Final cleanup failures
are reported via FlutterError rather than calling an unmounted widget. Persistent
native cleanup failures retain the existing ownership lease; retain a reference
to your factory's source if explicit cleanup retries are required.

HID continues to leave focused editable fields alone by default and clears
partial frames as soon as an editable field gains focus. iMin broadcasts remain
independent of editable focus. Lifecycle management does not add background
scanning or change device-level output settings.

## Application integration

Keep application-specific ports/models in your domain when isolation matters.
Implement a thin data-layer adapter that maps BarcodeScan to that model without
changing eventId or occurredAt. Decide when to start and release the scanner in
your application (route lifetime, background policy, permissions and UI).
Product lookup, quantity changes, business validation and processed-event
persistence belong in the consuming application.

For custom composition/testing, BarcodeScanner, HidScanner,
IminBroadcastScanner, ResolvingScanner and ScannerPlatform are public. The
default BridgeScannerPlatform wraps the native bridge; custom platform
implementations must define their own resource ownership. Ordinary consumers
only need Scanner and ScannerOptions.

## Compatibility

- Dart ^3.10.7, Flutter >=3.38.6.
- Native plugin: Android only, minSdk 24, compileSdk 36, Java/Kotlin target 17.
- Android example uses AGP 8.11.1, Kotlin 2.2.20 and Gradle 8.14, matching this
  integration's existing toolchain. Newer Flutter releases may warn about these
  versions; do not treat this as a claim of AGP 9 compatibility.
- HID is implemented in Flutter. The web example is useful for exercising
  keyboard input, but it does not add native iMin support to web or certify all
  desktop platforms/devices.
- Camera, Bluetooth-specific protocols, USB serial, device discovery and
  persistent background scanning are not implemented.

The low-level API is available through
`package:barcode_port/scanner_bridge.dart`. Default barcodes() calls
share one EventChannel stream. A ScannerBridge that starts the native listener
owns it until its stopListening succeeds; competing starts fail instead of
overwriting the owner. Direct low-level callers must clean up after failed
starts too. Generated Pigeon types are outside the high-level API.

## Develop

```powershell
flutter pub get
flutter test
flutter analyze
dart run pigeon --input pigeons/scanner_host.dart
```

Regenerate Pigeon only when changing its source interface; do not edit generated
files manually. From example/, use flutter run or flutter build apk --debug.
Local mocked platform tests do not replace testing iMin broadcasts and actual
HID hardware on the intended device.
