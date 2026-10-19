# Changelog

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
