# Platform validation — 1.1.0

The maintainer instructed manual publication of 1.1.0 on 2026-10-20 after delivery
of this validation report. See [release authorization](releasing.md#manual-release-authorization-110)
for the decision and the verification limits, which remain unchanged.

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
| Browser routing, including Android target | Passed in Chrome on minimum/stable CI |
| Minimum/stable Android and web builds | Example and fresh consumers passed |
| Minimum/stable Windows/Linux/macOS/iOS consumer builds | All eight jobs passed; iOS uses an unsigned simulator build |
| Analysis, formatting, API documentation | Passed; Dartdoc has zero warnings/errors |
| Package publish dry-run | Passed with zero warnings |
| Pana package assessment | 160/160; reports support for all six platforms |
| Local example | Received `00123` twice with no focused text field |
| Local hot restart | Completed through Dart tooling; see SDK diagnostic below |
| Physical reader qualification for new platforms | Not performed |

Build and browser evidence: [CI run 39406435327](https://github.com/bashar12-dev/barcode_port/actions/runs/39406435327)
at source commit `3d6660d89ce7e5da6a7b80d5fcad57a575cad42a`, on Flutter
3.38.6 and stable 3.47.7. All eleven jobs passed, including Pana at 160/160.
Coverage of handwritten
library code was 387/402 lines (96.3%). An independent source review found no
actionable findings. Subsequent documentation updates do not change runtime code.

### Local development diagnostic

On the local Flutter 3.47.2 SDK, Chrome hot restart completed but emitted a
transient engine assertion, `Trying to render a disposed EngineFlutterView`.
The same assertion was reproduced by hot restarting a minimal Flutter app with
no BarcodePort dependency. The package example rendered its scanner UI after
restart and a subsequent runtime-error query was empty. This result is recorded
as a development-tool diagnostic, not a clean cross-device restart qualification.

The local Chrome `flutter test` harness also stalled while loading both the new
matrix and unchanged HID tests. Those tests passed in Chrome on both CI SDKs;
local browser interaction separately verified the visible example. No SDK files
or package behavior were modified to hide either diagnostic.

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
configuration. No named hardware is newly certified by this release. The physical
validator and disabled automated publisher remain in force; the maintainer's
specific manual authorization does not supply missing hardware evidence.
