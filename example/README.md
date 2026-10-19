# BarcodePort example

A standalone Android host for BarcodePort, with a web host for keyboard
input smoke checks. It has no dependency on Self-Checkout.

```powershell
flutter pub get
flutter test
flutter run
flutter build apk --debug
```

Read the package README for input policy and hardware limitations. This example
opts in to configuring iMin output. Start/Stop clear Flutter focus so Enter from
a keyboard-wedge scanner does not reactivate the focused control. The optional
BarcodeScanner constructor argument demonstrates dependency injection; the
example owns and disposes the supplied scanner too.

The example uses ScannerListener. Open another page/dialog to verify that
reception pauses while covered and resumes on return; Stop remains disabled
across those transitions. Moving the app to the background also pauses input.
The discarded-input line shows diagnostic reasons without logging barcode text.

Default processing accepts internal codes and repeated scans. To run the
explicit demonstration policy (uppercase, letters/digits/_/-, 500 ms consecutive
repeat suppression):

```powershell
flutter run -d chrome --dart-define=SCANNER_EXAMPLE_POLICY=true
```

This demo is not a production checkout policy: two intentional scans of the
same product can represent two items. The widget's source factory runs once
per State; use a new key and finish old-owner cleanup before replacing it.
