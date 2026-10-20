# BarcodePort: shared Flutter keyboard input across platforms

Status: proposed for maintainer approval; implementation has not started.

## Intent and agreed constraint

Extend the current external-scanner workflow to Windows, macOS, Linux, web,
and iOS using Dart and Flutter keyboard events only. The maintainer explicitly
requests the approach used by a Flutter HID listener, without new native scanner
implementations like the Android integration. A scanner must already present its
output to the operating system as keyboard input.

The existing Android iMin integration remains in place. This is the author's
interpretation of extending the other platforms, not approval to remove or
replace existing Android functionality. Android HID also keeps its behavior.

## Scope and support contract

| Platform | Keyboard-wedge input | iMin broadcast input |
|---|---|---|
| Android | Existing Flutter implementation | Existing Android implementation |
| Windows | Shared Flutter implementation | Unsupported |
| macOS | Shared Flutter implementation | Unsupported |
| Linux | Shared Flutter implementation | Unsupported |
| Web | Shared Flutter implementation | Unsupported |
| iOS / iPadOS | Shared Flutter implementation | Unsupported |

Support means receiving the character events Flutter delivers to the active
application. USB or Bluetooth is the scanner's connection to the operating
system; the library neither discovers nor connects to hardware itself. On web
the Flutter view/browser must receive keyboard focus. This is keyboard input,
not the browser WebHID API. No focused text field is required, but an inactive
application or another focused browser page cannot deliver its input here.

Do not promise every reader, keyboard layout, browser, or firmware. Physical
qualification and automated build/event checks are separate evidence. iOS in
particular needs a compatible external reader and an actual device run to
qualify a configuration. Do not add hidden text fields or claim that a simulator
run proves external-reader behavior.

Out of scope: camera decoding, BLE GATT, Bluetooth SPP, serial USB, raw HID
reports, manufacturer SDKs, OS-wide hooks, background capture, scanner discovery,
and moving Android native integration into a separate package.

## Implementation decisions proposed by the author

1. Reuse `HidScanner` and all existing processing, diagnostics, ownership,
   framing, and widget lifecycle code. Do not add Swift, Objective-C, Kotlin,
   Java, C/C++, native channels, or external dependencies for new platforms.
2. Change only the default platform selection used by `Scanner`: on native
   Android use the current `BridgeScannerPlatform`; on web and other targets use
   an internal keyboard-only boundary. Detect web before checking the target
   platform so a browser running on Android cannot select Android channels.
3. That internal boundary reports no native preference, exposes an empty native
   stream, rejects native start/configuration with an actionable
   `UnsupportedError`, and makes native stop a safe no-op. Auto mode therefore
   selects HID directly without probing a missing plugin. Explicit
   `iminBroadcast` fails clearly, with cleanup releasing ownership. Do not
   silently turn an explicit iMin request into HID.
4. Keep explicit `ScannerPlatform` injection authoritative, including in tests.
   Do not add members to this public interface or change custom integrations.
   The low-level `ScannerBridge` and explicit `BridgeScannerPlatform` remain
   documented as Android-only, with their current APIs.
5. Keep plugin registration Android-only. Add the supported platforms at the
   top level of `pubspec.yaml`, which Dart explicitly supports for a Flutter
   plugin whose shared Dart code works on additional targets. No empty native
   plugins, registration stubs, or platform packages are needed.
6. Keep Dart/Flutter minimum versions and existing default input policy. Preserve
   event identity, leading zeros, optional repeat suppression, editable-field
   pass-through, and the single-owner rule on every target. Exclude synthesized
   or layout behavior changes from this work unless validation exposes a defect
   directly preventing the new support; document any such finding first.

## Example and developer experience

Update English and Arabic documentation with the platform/transport matrix,
the same `Scanner()`/`ScannerListener` usage on every platform, and explicit HID
configuration as an option. Explain active-window/browser focus and reader
keyboard-layout/suffix configuration. Document iMin errors outside Android.

Provide commands for running the shared example on new targets. Generate
standard Flutter application runners only where required to build/run the
example; these are host application scaffolding, not new native scanner code.
Preserve existing Android and web customizations. Prefer generating runners in
a temporary example copy or fresh consumer for CI over committing unused runner
files. The builder may choose which runner files to retain for an immediately
runnable example; do not handwrite platform integrations.

## Validation and acceptance

- Add meaningful local unit/widget tests under the maintainer's existing
  authorization to test without ARTEMIS. Test auto/HID selection, native-mode
  rejection, cleanup/restart, and custom-platform injection for every target.
- Cover web-on-Android separately. Assert no Android method/event channels are
  contacted by the default cross-platform paths, including failed native starts.
- Exercise representative keyboard frames on target overrides: leading zeros,
  Enter/Tab, repeats with independent identities, focus protection, stop/start,
  and listener lifecycle. These are synthetic events, not hardware results.
- Preserve all existing Android bridge, processing, and example tests. Run
  formatting, analysis, API documentation, package dry-run, and package scoring.
- Retain minimum Flutter 3.38.6 and latest stable checks. Build fresh consumers
  for Android and web on Ubuntu, Windows on Windows, Linux on Ubuntu, and macOS
  and unsigned iOS simulator on macOS. Test both supported SDK endpoints for
  new targets, reusing matrix jobs where sensible. Do not weaken checks to make
  platform badges appear. Use hosted CI where the local OS cannot build a target.
- Run the example locally on an available supported target and perform a hot
  restart. Describe synthetic reception separately from a physical reader run.
- Record actual outcomes in a platform validation document. Keep unperformed
  hardware checks explicitly pending; never infer a device pass from a build.

## Release and repository boundaries

Work in the independent BarcodePort repository on `codex/flutter-platform-support`.
Do not modify checkout/invoice behavior or unrelated application files. Mirror
the validated package back to its existing local consumers only with a targeted
comparison that preserves unrelated changes.

Prepare an additive 1.1.0 candidate and changelog; this version is the author's
proposal. Do not overwrite published 1.0.1 or create a release tag/upload as part
of design approval. Publication requires reviewing the concrete validation
results and applying the existing release gates; the earlier manual release
exceptions do not automatically qualify new platforms.

## Primary references

- [Dart pubspec platforms](https://dart.dev/tools/pub/pubspec#platforms): the
  top-level declaration takes precedence over plugin declarations for reported
  platform support; it does not register native implementations.
- [Flutter HardwareKeyboard](https://api.flutter.dev/flutter/services/HardwareKeyboard-class.html):
  shared keyboard event model and handler lifetime.
- [KeyEvent.character](https://api.flutter.dev/flutter/services/KeyEvent/character.html):
  generated characters, combining keys, and IME limitations.
- [Flutter platform development](https://docs.flutter.dev/platform-integration):
  build-host requirements for Windows, Linux, macOS, and iOS.

Builder discretion: test file organization, CI job factoring, temporary runner
generation, and wording that preserves this support contract. No new native
scanner implementation or new transport is delegated to the builder.
