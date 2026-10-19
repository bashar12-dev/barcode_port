# BarcodePort example

An independent Android application for exercising BarcodePort. The web host is a
keyboard-input demonstration, not a native iMin implementation or additional
platform qualification.

```sh
flutter pub get
flutter test
flutter run
flutter build apk --debug
```

The example starts with default processing and does not change iMin output
settings. To explicitly request broadcast output configuration:

```sh
flutter run --dart-define=BARCODE_PORT_CONFIGURE_IMIN_OUTPUT=true
```

This changes the device's output settings; stop/dispose does not restore the old
settings. Use a hot restart when changing compile-time flags.

To enable the demonstration policy (uppercase, letters/digits/_/-, and a 500 ms
consecutive-repeat window):

```sh
flutter run --dart-define=SCANNER_EXAMPLE_POLICY=true
```

The policy is opt-in: two scans can represent two independent items. Start/Stop
clear Flutter focus so Enter from a keyboard-wedge reader does not reactivate a
focused button. Focus the manual input to exercise editable HID pass-through.

Open the page/dialog controls to verify that covered screens pause reception and
returning resumes it. Manual Stop remains in effect across those transitions.
Backgrounding also pauses reception. The discarded-input line contains diagnostic
reasons and lengths without logging barcode text.

The example owns the supplied scanner, including injected test sources, and
releases it when removed. Its source factory runs once per State. Use a new key
and finish the old owner's cleanup before replacing the source.

See [device qualification](../doc/device-compatibility.md) before making hardware
compatibility claims. Keep demonstration inputs synthetic.
