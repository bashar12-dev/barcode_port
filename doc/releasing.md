# Release checklist

Release owner: Bashar Alhammadi (`bashar12-dev`). First public version: **1.0.0**.
The approved documentation patch is **1.0.1**.
The standalone repository is the source of releases. Review the exact candidate
commit and archive before uploading; package versions cannot be overwritten.

## Automated checks

- [ ] Minimum Flutter 3.38.6 and current stable CI are green.
- [ ] Handwritten code formatting, analysis, package/example tests, and Dartdoc pass.
- [ ] Handwritten-code coverage is recorded with generated code excluded.
- [ ] Example and fresh external consumer build on Android on both SDK endpoints.
- [ ] Web demonstration builds; this does not qualify an additional platform.
- [ ] Pana runs on a temporary copy; investigate its report and fix actionable issues.
- [ ] `flutter pub publish --dry-run` passes from a clean candidate; inspect every archive path.
- [ ] Archive includes LICENSE, public docs, example, native and generated source; no secrets or parent application files.
- [ ] Repository, issue tracker, documentation, image, and license URLs resolve publicly.

Pana requires the full available score for the declared platform scope. Formatting
checks include generated Dart bindings. Use the documented generation command
to keep the generator output consistent with the package's formatter; do not
relax score checks or override Flutter SDK dependency pins to hide a deduction.

## Physical device gate

Complete real Android runs for **both** `hid` and `iminBroadcast`. Record device
model, Android/firmware version, connection, output configuration, operator, UTC
date, tested source commit, and the report path in `hardware-validation.json`.

- [ ] 100 known frames per transport: correct text/count, including internal codes and leading zeros.
- [ ] Intentional repeated values retain distinct event IDs with default processing.
- [ ] HID Enter and Tab suffix configurations complete frames.
- [ ] HID editable focus passes through and discards partial input; iMin reception is independent of focus.
- [ ] Covering page/dialog pauses input and returning resumes it when enabled.
- [ ] Background/resume pauses and restores eligible reception.
- [ ] Manual disable remains effective across navigation and lifecycle changes.
- [ ] Stop/start/dispose and hot restart do not duplicate reads or leave an owner/receiver behind.

The gate checks records and report references; the maintainer must attest that
the described interactions actually took place. A build, synthetic key injection,
or an unspecified successful-use report is not a replacement for these runs.

```sh
dart run tool/verify_release.dart --version 1.0.1
```

Automated releases require this command to pass. Releases after 1.0.1 require
completed physical qualification before tagging or publishing. Update the
compatibility table with actual qualified models only after these runs pass.

### First manual release decision: 1.0.0

On 2026-10-20 the maintainer explicitly approved publishing 1.0.0 based on his
reported successful use, while disclosing that the device models, Android
versions, transport coverage and detailed qualification results are unknown.
This is a documented exception for the first manual release only; it is not
evidence that the physical qualification gate passed. No model is certified.
The automated physical gate remains strict and no test results are fabricated.

The maintainer also explicitly approved the documentation-only 1.0.1 patch on
2026-10-20 to correct README text encoding. Its scanner implementation is
identical to 1.0.0 and retains the same disclosed verification limits. This
second manual publication does not add physical qualification evidence.

## First publication and manual documentation patch

- [ ] Set the GitHub default branch to `main`, enable private vulnerability reporting, and protect release tags if available.
- [ ] Verify the MIT notice and third-party provenance; no manufacturer SDK is bundled.
- [ ] Keep `PUB_PUBLISH_ENABLED` unset/false until the first manual publication succeeds.
- [ ] Commit the complete candidate, check a clean Git status, and verify all automated quality checks and the first-release decision above.
- [ ] Create the version tag matching `pubspec.yaml`: `v1.0.0` initially, `v1.0.1` for the documentation patch.
- [ ] Sign in with the owner's Google account and run `flutter pub publish` from the tagged package root.
- [ ] Verify the pub.dev page, API docs, example, license, and scores.
- [ ] In a new consumer use hosted `barcode_port: ^1.0.1` without overrides and verify Android registration/build.
- [ ] Publish GitHub release notes only after the package upload is confirmed.

After pub.dev confirms the upload, run the **Verify hosted package** workflow
against the release tag. It creates a fresh Flutter Android application with a
hosted dependency, without a local package path or dependency overrides, and
builds it. The equivalent local command is
`dart run tool/smoke_consumer.dart --hosted`.

Never work around failed checks with `--skip-validation`. Resolve a published
problem using a new patch version; do not re-use a published version number.

## Subsequent releases

Configure pub.dev automated publication for `bashar12-dev/barcode_port` and the
exact pattern `v{{version}}`. Create a GitHub `pub.dev` environment and require
maintainer approval where the account supports it. Protect matching release tags.
Complete the physical qualification records before enabling repository variable
`PUB_PUBLISH_ENABLED=true`. While this variable is false, the tag workflow skips
its jobs; the first release is published manually.

The release workflow requires successful CI, matching tag/version, and passing
hardware records before its publish job runs. OIDC grants a short-lived credential
with `id-token: write` only to the publish job. Do not store a long-lived pub token.
The official Dart reusable publishing workflow installs Flutter before publishing.
Hardware records must apply to the candidate's identical runtime source; repeat
qualification when runtime/native behavior changes.
