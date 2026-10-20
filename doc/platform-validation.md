# Platform validation — 1.1.0 candidate

This candidate is not published. Version 1.0.1 remains the published release
until a new version is explicitly released. Updated on 2026-10-20.

## Implementation

Keyboard-wedge input on all six Flutter platforms uses the same Dart/Flutter
`HardwareKeyboard` implementation. No native scanner code, channel, registration
stub, or runtime dependency was added for iOS, Windows, macOS, Linux, or web.
Android's existing native iMin implementation and protocol remain unchanged.

Auto selects HID directly outside native Android; explicit default iMin mode
fails with `UnsupportedError` and releases ownership. Explicit injected platform
implementations remain authoritative. Web is detected before the target OS.

## Evidence

| Check | Result |
|---|---|
| Existing package baseline | 66 tests passed before implementation |
| Native target routing/keyboard/widget matrix | 18 tests passed locally, including Android bridge regression |
| Package and consumer option tests | 87 tests passed locally |
| Browser routing, including Android target | Pending execution |
| Minimum/stable Android and web builds | Pending CI |
| Minimum/stable Windows/Linux/macOS/iOS consumer builds | Pending CI |
| Local example and hot restart | Pending execution |
| Physical reader qualification for new platforms | Not performed |

Target overrides and injected keys exercise shared code; they do not boot the
target operating systems or prove physical scanner compatibility. CI builds
fresh consumers on native hosts. The iOS build targets an unsigned simulator,
which does not establish Bluetooth/USB reader support on a physical iPhone/iPad.

The operating system must pair/recognize the external reader as a keyboard.
The application window must be active; web additionally needs keyboard focus
inside the Flutter view. Match scanner and OS keyboard layouts and use a
configured terminator. No focused text field or hidden input is installed.

## Reproduce

```sh
flutter pub get
flutter test
flutter test --platform chrome test/scanning/platform_support_test.dart
dart run tool/smoke_consumer.dart --platform=web
```

Run the consumer script with `android`, `windows`, `linux`, `macos`, or `ios` on
the corresponding build host. The default remains Android; `--hosted` installs
the exact version in `pubspec.yaml` and is meaningful only after publication.
Flutter 3.38.6 and latest stable are both checked by CI.

Record actual reader model, OS/browser version, connection mode, keyboard layout,
suffix, tested commit, and lifecycle/content results before qualifying a new
configuration. No named hardware is newly certified by this candidate. Existing
release hardware gates and the disabled automated publisher remain in force.
