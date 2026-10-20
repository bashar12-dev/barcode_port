# BarcodePort example

An independent Flutter application for exercising BarcodePort. Keyboard input
uses the same Dart/Flutter code on every supported platform; native iMin input
is available only on Android. Builds and synthetic events are separate from
physical-reader qualification.

```sh
flutter pub get
flutter test
flutter run
flutter build apk --debug
```

The checked-in hosts are Android and web (`flutter run -d chrome`). To run the
same example on another target, generate its standard Flutter application host
on the appropriate development machine, then run it:

```sh
flutter create --platforms=windows .
flutter run -d windows
```

Replace `windows` with `linux` or `macos` as appropriate. On macOS use
`flutter create --platforms=ios .` and select an iOS device or simulator with
`flutter run -d <device-id>`. These generated application runners contain no
BarcodePort scanner integration. Keep native Android/web files when generating
other hosts. A reader must present keyboard input to the OS and the app must
have foreground focus. Browser input requires focus in the Flutter view.

CI generates fresh consumers for every target, independent of these hosts:
`dart run tool/smoke_consumer.dart --platform=windows` from the package root.
See [platform validation](../doc/platform-validation.md) for evidence and limits.

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
