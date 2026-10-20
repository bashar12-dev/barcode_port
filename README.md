# BarcodePort

Hardware barcode input for Flutter on Android, iOS, Windows, macOS, Linux, and web.

[![pub package](https://img.shields.io/pub/v/barcode_port.svg)](https://pub.dev/packages/barcode_port)
[![CI](https://github.com/bashar12-dev/barcode_port/actions/workflows/ci.yml/badge.svg)](https://github.com/bashar12-dev/barcode_port/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/bashar12-dev/barcode_port/blob/main/LICENSE)

[العربية](https://github.com/bashar12-dev/barcode_port/blob/main/README.ar.md) · [API](https://pub.dev/documentation/barcode_port/latest/) · [Example](https://github.com/bashar12-dev/barcode_port/tree/main/example) · [Device qualification](https://github.com/bashar12-dev/barcode_port/blob/main/doc/device-compatibility.md)

Receive keyboard-wedge input across platforms and Android iMin broadcasts through one API.
A focused text field is not required. Keep product lookup, inventory, and checkout
rules in your application.

- A distinct event ID and UTC timestamp for every observed scan.
- Optional screen/app lifecycle management with `ScannerListener`.
- Opt-in normalization, filtering, and consecutive-repeat suppression.
- Typed diagnostics without barcode contents or automatic barcode logging.
- One active input owner, with asynchronous start, stop, and cleanup.

![BarcodePort example displaying scan 123](https://raw.githubusercontent.com/bashar12-dev/barcode_port/main/doc/images/example.png)

## Support and requirements

| Platform | Keyboard-wedge HID | iMin broadcasts |
|---|---|---|
| Android | Supported | Supported with compatible broadcast configuration |
| iOS / iPadOS | Supported through Flutter keyboard events | Unavailable |
| Windows | Supported through Flutter keyboard events | Unavailable |
| macOS | Supported through Flutter keyboard events | Unavailable |
| Linux | Supported through Flutter keyboard events | Unavailable |
| Web | Supported through Flutter keyboard events | Unavailable |

USB or Bluetooth readers must be configured to send keyboard input, with an
Enter or Tab suffix by default. The operating system handles the connection.
The shared HID implementation uses Dart and Flutter only; no additional native
scanner plugin or manufacturer SDK is required on the new platforms.

See [platform validation](https://github.com/bashar12-dev/barcode_port/blob/main/doc/platform-validation.md)
for 1.1.0 build evidence and outstanding physical-reader checks.

See the [qualification records](https://github.com/bashar12-dev/barcode_port/blob/main/doc/device-compatibility.md) for actual tested
models and release status. An implementation is not a guarantee for every device.
Camera scanning, BLE/SPP protocols, USB serial, scanner discovery, GS1 parsing,
and background reception are outside the package's current scope.

Requires Dart **3.10.7+** and Flutter **3.38.6+**. Android additionally requires
**API 24+**, compileSdk **36**, and Java/Kotlin target **17**. Other operating
system requirements follow the selected Flutter SDK. Android is the only native
plugin registration; the other targets use the same Flutter keyboard listener.
Native iMin support is not available on web, iOS, or desktop.

## Install

```sh
flutter pub add barcode_port
```

Or add:

```yaml
dependencies:
  barcode_port: ^1.1.0
```

## Quick start

This complete example owns the scanner for the screen and handles input errors:

```dart
import 'package:barcode_port/scanner_widgets.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MaterialApp(
    home: Scaffold(
      body: ScannerListener(
        createScanner: () => Scanner(),
        onScan: (scan) => debugPrint('Read: ${scan.barcode}'),
        onError: (error, stack) => FlutterError.reportError(
          FlutterErrorDetails(exception: error, stack: stack),
        ),
        child: const Center(child: Text('Ready to scan')),
      ),
    ),
  ));
}
```

The explicit `debugPrint` is demonstration application code; remove it if barcode
contents must not be logged. The package does not log barcode values itself.

`ScannerListener` creates one source per State and owns its start/stop/dispose.
Reception requires `enabled`, the current route, and a resumed app. Covering the
screen with a page/dialog or moving the app to the background pauses reception.
Set `enabled` from tab visibility for hidden tabs and nested navigators.

Use a new widget key to supply a different source. Finish old-owner cleanup before
starting another owner; simultaneous owners fail instead of stealing reception.
The source factory is not re-run when options or callbacks change during rebuild.

## Direct lifecycle

Use the headless API when your application owns the asynchronous lifetime:

```dart
import 'package:barcode_port/barcode_port.dart';

Future<void> readUntil(Future<void> finished) async {
  final scanner = Scanner();
  final subscription = scanner.events.listen(
    (scan) => print('${scan.eventId}: ${scan.barcode}'),
    onError: (Object error, StackTrace stack) {
      // Report an operational error in your application.
    },
  );
  try {
    await scanner.start();
    await finished;
  } finally {
    await subscription.cancel();
    await scanner.dispose();
  }
}
```

Subscribe **before** start to retain startup frames. `stop` waits for pending
startup and permits a later start. `dispose` permanently releases the source and
closes its streams. Cancel or resume paused subscriptions before awaiting disposal.
Start/stop/dispose futures can fail in addition to stream errors. Retry cleanup
when it fails; ownership is retained until resources can be released safely.

## Input policy and focus

| Option | Default | Meaning |
|---|---|---|
| `mode` | `ScannerMode.auto` | Native Android prefers iMin on matching metadata; all other targets select HID directly. |
| `configureIminOutput` | `false` | Explicitly request broadcast output configuration on iMin. |
| `frameTimeout` | 2 seconds | Discard an incomplete HID frame after an inter-character gap. |
| `terminators` | Enter, Tab | Complete the current HID frame. |
| `maxFrameLength` | 4096 UTF-16 units | Discard an oversized HID frame through its boundary. |
| `passThroughEditableText` | `true` | Leave keyboard input to the focused editable field. |

HID receives keyboard events; it does not identify a USB scanner or reliably
distinguish human typing. Entering an editable field immediately clears a partial
HID frame. iMin broadcasts are independent of text-field focus. Disabling editable
pass-through does not guarantee suppression of text entry by other Flutter handlers.

The app window must receive keyboard input; on web the Flutter view/browser must
have focus. This does not require a focused text field and cannot capture input
sent to another application or browser tab. Match the scanner's keyboard layout
to the operating system. Characters depend on events delivered by Flutter;
IME composition and arbitrary binary payloads are not supported.

Use `Scanner()` unchanged on every platform, or explicitly select
`ScannerOptions(mode: ScannerMode.hid)`. With the default platform,
`ScannerMode.iminBroadcast` throws `UnsupportedError` outside native Android,
including a browser on Android. Supplying a custom `ScannerPlatform` remains
authoritative. The low-level native `ScannerBridge` is Android-only.

Auto mode selects one transport per start. It does not switch after a start error
or infer hardware failure from a quiet period. Use an explicit mode when needed.

Configuring iMin changes device output settings, and stopping does not restore
previous settings. A configuration response or registered receiver is not proof
that a physical scanner is ready. Treat scanned/broadcast text as application input
and apply your own business validation.

Text is trimmed; blanks are discarded. Byte payloads use UTF-8. This is a text
input API, not lossless arbitrary QR/binary capture. Internal codes and leading
zeros are accepted. Default repeated scans remain independent events.

## Optional processing

```dart
final scanner = Scanner(
  processing: ScanProcessingOptions(
    normalize: (text) => text.toUpperCase(),
    accept: (text) => text.startsWith('ITEM-'),
    duplicateWindow: const Duration(milliseconds: 500),
  ),
);
```

Order: normalize → trim → reject empty → filter → consecutive-repeat check →
deliver. Normalization preserves the event ID and UTC timestamp. Defaults do not
normalize/filter/suppress repeats and pass through the same event object.

Repeat suppression is **disabled by default**. When enabled, only consecutive
accepted equal values less than the window apart are suppressed. The exact time
boundary is accepted; a suppressed read does not extend the window. A/B/A stays
three accepted reads, and stop/restart resets the history. It uses monotonic time.
Two intentional scans can mean two items, so choose this policy explicitly.

Callback exceptions arrive as stream errors with their stack; later reads continue.
No symbol format is guessed from text length, and no GS1 prefix is removed.
`ProcessingScanner` can wrap a custom `BarcodeScanner` and owns its disposal.

## Diagnostics

```dart
final notices = scanner.diagnostics.listen((notice) {
  print('${notice.reason.name}, length=${notice.inputLength}');
});
// Cancel notices before disposing its scanner.
```

Reasons: `incompleteFrame`, `frameOverflow`, `blankFrame`, `filtered`,
`normalizedEmpty`, and `duplicateSuppressed`. Notices contain UTC time, input
length, and an event ID when a frame already exists; they contain no barcode text.
Operational failures remain errors on `events`. Overflow is diagnosed once per
frame; intentional focus/stop/dispose resets do not produce timeout notices.

## Example and troubleshooting

```sh
cd example
flutter pub get
flutter run
```

To explicitly configure iMin broadcast output (off by default):

```sh
flutter run --dart-define=BARCODE_PORT_CONFIGURE_IMIN_OUTPUT=true
```

For the optional processing demonstration:

```sh
flutter run --dart-define=SCANNER_EXAMPLE_POLICY=true
```

The example owns its scanner, including injected sources. Use a hot restart after
changing compile-time flags. See the [example guide](https://github.com/bashar12-dev/barcode_port/blob/main/example/README.md).

| Symptom | Check |
|---|---|
| HID read never completes | Scanner keyboard mode, Enter/Tab suffix, timeout, active screen, editable focus. |
| Web/desktop receives no input | Active application/Flutter browser view, OS reader pairing, keyboard layout, and suffix. |
| UnsupportedError in iMin mode | Use auto/HID outside native Android; iMin broadcasts require Android. |
| Ordinary typing becomes a scan | HID receives keyboard input; choose screen eligibility and device configuration deliberately. |
| Duplicate-owner error | Await the old owner's stop/dispose before starting a new owner. |
| iMin sends no reads | Mode, actual broadcast configuration/action/payload, device firmware, and diagnostics/errors. |
| Repeat policy removes intentional reads | Leave `duplicateWindow` at zero where repeated scans represent separate actions. |

## Development and support

[Contributing](https://github.com/bashar12-dev/barcode_port/blob/main/CONTRIBUTING.md) · [Support](https://github.com/bashar12-dev/barcode_port/blob/main/SUPPORT.md) ·
[Security](https://github.com/bashar12-dev/barcode_port/blob/main/SECURITY.md) · [Release checklist](https://github.com/bashar12-dev/barcode_port/blob/main/doc/releasing.md) ·
[Changelog](https://github.com/bashar12-dev/barcode_port/blob/main/CHANGELOG.md)

Report a device issue with its model, OS/browser and firmware versions, connection mode,
scanner output settings, and a minimal example using synthetic barcode text.
Use GitHub's private vulnerability reporting for security reports; do not post
credentials, customer barcodes, or payment data in public issues.

The low-level native bridge is also available through
`package:barcode_port/scanner_bridge.dart`. Advanced/custom sources implement
`BarcodeScanner` and optionally `DiagnosticBarcodeScanner`. Generated Pigeon types
are implementation details. The package uses Flutter and Dart's `meta` annotations;
no manufacturer SDK is bundled. Distributed under the [MIT license](https://github.com/bashar12-dev/barcode_port/blob/main/LICENSE).
