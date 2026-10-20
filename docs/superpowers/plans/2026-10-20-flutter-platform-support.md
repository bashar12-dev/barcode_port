# Shared Flutter Platform Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Support keyboard-wedge input on all six Flutter platforms without new native scanner code, retaining Android behavior.

**Architecture:** Select the existing Android bridge only on native Android. Other targets use an internal keyboard-only platform boundary and the existing HID, processing, and lifecycle implementation. Explicit custom platform injection remains authoritative.

**Tech Stack:** Dart, Flutter HardwareKeyboard, Flutter tests, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-20-flutter-platform-support-design.md`

## Global Constraints

- Dart ^3.10.7; Flutter >=3.38.6; no new runtime dependencies.
- Preserve native Android HID/iMin, generated bindings, processing defaults, and public interfaces.
- No new native scanner code, hidden text fields, or native registration stubs.
- No camera, serial, BLE/SPP, discovery, raw HID, or background reception.
- Local unit/widget testing without ARTEMIS is already authorized; never invent hardware results.
- Work only in the independent repository; targeted consumer synchronization after validation.
- Prepare 1.1.0, without publishing or tagging.

## Review Focus

- Web on an Android browser must never contact Android channels: actual browser test.
- Unsupported native start must release ownership for another scanner: failure/cleanup test.
- An injected native platform on any target must still work: injected startup-frame test.
- Focus entry and disabled/lifecycle states must not deliver unintended frames: target-matrix widget test.
- Fresh consumers must not depend on the example's host settings: all-target consumer builds.

### Task 1: Default transport selection and regression coverage

**Files:** Create `lib/src/scanning/default_scanner_platform.dart`, `test/scanning/platform_support_test.dart`; modify `lib/src/scanning/scanner.dart` and Dartdoc in `scanner_options.dart`.

**Interfaces:** Consumes existing `ScannerPlatform`; produces internal `ScannerPlatform createDefaultScannerPlatform()` using `kIsWeb` before `defaultTargetPlatform`. No new exported API.

- [x] Write tests capturing Android method/event channel calls on default non-Android auto and explicit iMin starts; assert zero calls, UnsupportedError for iMin, cleanup and subsequent HID success.
- [x] Run `flutter test test/scanning/platform_support_test.dart`; expect RED because default uses bridge everywhere.
- [x] Implement internal keyboard-only boundary: empty stream, false preference, unsupported start/configure, harmless stop. Keep injected platform precedence.
- [x] Test default HID frames, leading zeros, Enter/Tab, repeated identity, focus resets, stop/restart and actual ScannerListener enable/lifecycle over TargetPlatform values; verify injected broadcast behavior separately. Browser run checks kIsWeb even with Android target override.
- [x] Run package tests and actual Chrome tests; expect all pass. Commit runtime and regression tests.

### Task 2: Portable consumer validation and CI

**Files:** Modify `tool/smoke_consumer.dart`, `.github/workflows/ci.yml`, `.github/workflows/verify-hosted.yml` only if its interface needs adaptation; add focused tool tests if command logic becomes nontrivial.

**Interfaces:** Extend existing script compatibly with `--platform=android|web|windows|linux|macos|ios`; preserve `--hosted` and Android default. Build fresh app using the package path unless hosted explicitly selected.

- [x] Add invalid-platform validation test before mutation; watch it fail, then implement argument handling. Preserve unique temporary-directory containment safeguards.
- [x] Generate only the selected standard Flutter runner in a fresh consumer; Android API 24 adjustment only for Android. Build debug desktop, Android arm64, web release, or unsigned iOS simulator as appropriate.
- [x] Add stable/minimum Windows/Linux/macOS/iOS fresh builds, reusing existing Android quality jobs and adding minimum web build plus Chrome event tests. Do not add native scanner implementations or unused committed runners.
- [x] Run local tool tests and web consumer build. Run hosted CI from feature branch for targets unavailable locally; retain outcomes/log links. Commit tooling/CI.

### Task 3: Distribution, documentation, validation, and synchronization

**Files:** Modify `pubspec.yaml`, `CHANGELOG.md`, `README.md`, `README.ar.md`, `example/README.md`, `doc/device-compatibility.md`, `doc/releasing.md`; create `doc/platform-validation.md`.

**Interfaces:** Top-level `platforms` reports all six targets; Android plugin registration unchanged. Candidate version 1.1.0. Document consumer script and standard example runner generation commands.

- [x] Update support matrix, installation version, native errors, foreground/browser focus, keyboard layout, and separate physical vs synthetic evidence in both languages.
- [x] Run format, analysis, full tests/coverage, example tests, Dartdoc, package dry-run and Pana. Inspect archive and diff to ensure Android/native files unchanged.
- [x] Launch the example on an available target and perform hot restart. Record actual results, CI links, and pending hardware qualification without certification claims.
- [x] Commit candidate. Request fresh whole-branch review with spec/plan and ledger rulings; fix material findings with targeted RED/GREEN regression and suite run.
- [x] Synchronize validated package to existing local mirrors only after verifying their baseline; preserve unrelated application/index changes and adjust only barcode_port root-lock version. Finish with exact state and remaining release gates.

## Execution decisions

The maintainer approved the full design and instructed execution. Use native inline execution in this session, with one economical fresh reviewer at the end. The dedicated independent repository and its feature branch isolate this work from the dirty application checkout; no additional checkout is needed.

## Completion evidence

CI run 39406435327 passed all eleven jobs at 3d6660d: six-target consumers on minimum/stable, Chrome routing, package/example tests, Dartdoc, dry-run, and Pana 160/160. Local adapter and invoice identity tests also passed. Android native/generated sources are unchanged. Physical qualification and publication remain outside this completed implementation.
