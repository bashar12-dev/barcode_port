# Contributing

Open an issue for a bug or a concrete interoperability request before a large
change. Describe the device, Android/firmware versions, connection/output mode,
expected behavior, and a minimal example using synthetic barcode values.

## Local checks

Use Flutter 3.38.6 or newer and Java 17 for the Android example.

```sh
flutter pub get
dart run tool/check_format.dart
flutter analyze
flutter test --coverage
dart run tool/coverage_summary.dart
cd example
flutter pub get
flutter test
flutter build apk --debug
```

Generate API documentation on current stable Flutter with the fixed Dartdoc
release (SDK-bundled Dartdoc 9.0.6 has a Windows CRLF parsing defect):

```sh
dart pub global activate dartdoc 9.0.11
dart pub global run dartdoc --output .dart_tool/api
```

Generated Pigeon files are checked in. Regenerate them only when changing the
platform interface, with the pinned Pigeon version:

```sh
dart run tool/generate_bindings.dart
```

The generation command runs the pinned Pigeon generator for both languages and
then formats Dart using the package language version. Do not edit generated
files by hand. Keep Dart and Kotlin channels consistent.
Do not add manufacturer SDKs, permissions, or device settings changes implicitly.

## Changes and tests

Keep changes focused and document public APIs with Dartdoc. Add behavioral tests
for bugs and new behavior. Cover stream errors, lifecycle/cleanup, focus, frame
boundaries, intentional repeated scans, and optional processing as applicable.
Keep application business rules out of the package.

Manual device tests complement unit/widget tests. Record the actual device and
procedure in the qualification log; do not infer hardware compatibility from
mocked tests, emulator key injection, or a successful Android build.

Do not include customer data, machine paths, credentials, private application
code, or generated build artifacts in contributions. Retain third-party notices
when applicable. Contributions are distributed under the project's MIT license.

Maintainers review pull requests before merging. CI checks the minimum supported
Flutter version and the current stable channel. See [release checks](doc/releasing.md).
