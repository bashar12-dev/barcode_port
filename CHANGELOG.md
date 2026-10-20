# Changelog

## 1.1.0 (unreleased)

- Support keyboard-wedge input through shared Dart/Flutter code on Windows,
  macOS, Linux, web, and iOS, without new native scanner implementations.
- Select HID directly outside native Android, including Android browsers.
- Report UnsupportedError for explicit default iMin mode outside Android;
  preserve custom ScannerPlatform injection and cleanup after failed starts.
- Keep Android bridge, iMin protocol, HID defaults, and public APIs unchanged.
- Add all-platform consumer builds, browser routing tests, and support guidance.

## 1.0.1

- Correct the Arabic link label, separators, and processing arrows in the English README.
- Refresh documentation installation examples for the patch release.
- Keep scanner behavior, public Dart APIs, and native channel protocols unchanged.

## 1.0.0

- Receive keyboard-wedge HID and Android iMin broadcast input through one API.
- Preserve a distinct event identity and UTC timestamp for each observed frame.
- Manage screen and application eligibility with the optional ScannerListener.
- Offer opt-in normalization, filtering, and consecutive-repeat suppression.
- Report discarded input without including barcode text in diagnostics.
- Document lifecycle ownership, focus behavior, and device qualification.
- Include an independent Android example, bilingual guides, and release checks.

## 0.3.0

- Provide barcode_port.dart as the entry point for the high-level API.
- Add typed diagnostics for discarded frames, without changing BarcodeScanner or BarcodeScan.
- Add ProcessingScanner and optional normalization, filtering and repeat suppression, disabled by default.
- Clear partial HID frames immediately when editable focus is gained; retain exclusive ownership.
- Add ScannerListener screen/app lifecycle management via scanner_widgets.dart.
- Extend the example with navigation, dialogs, diagnostics and an opt-in processing demo.
- Keep native protocol, Pigeon and checkout behavior unchanged.

## 0.2.0

- Add generic BarcodeScan/BarcodeScanner contracts and a high-level Scanner API.
- Move HID framing, iMin event handling and transport selection into the package.
- Add explicit transport/output configuration and bounded HID frames.
- Serialize asynchronous lifecycle transitions, clean up failed starts and add
  final disposal; prevent competing native/HID owners.
- Share default EventChannel subscriptions while retaining the low-level API.
- Add standalone Android/web example and package-owned behavioral tests.

## 0.1.0

- Internal Android iMin broadcast bridge using Pigeon and EventChannel.
