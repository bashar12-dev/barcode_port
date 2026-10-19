# Device qualification

## Implementation and verified hardware

Android HID keyboard-wedge input and iMin broadcast input are implemented.
A model is listed as verified only when an actual device qualification record
covers both the input behavior and lifecycle checks in the release checklist.

| Model | Android | Firmware | Connection | Output settings | Date | Result |
|---|---|---|---|---|---|---|
| Not yet documented | Not recorded | Not recorded | Not recorded | Not recorded | Not recorded | Pending qualification record |

The maintainer reported successful use, but the device model, Android version,
and transport were not available. This is a user report, not a documented test
of either transport or a certification for a named device.

The web example verifies keyboard-event handling only. Unit/widget tests and
Android builds do not establish physical HID or iMin compatibility. Do not infer
support for camera decoding, serial, BLE/SPP, discovery, or background scanning.

## Recording a run

Complete `hardware-validation.json` after the actual run. Never populate a result
by inference. Retain an accompanying Markdown report in `doc/hardware/` containing
setup, sequence, synthetic test values or their specification, observed counts,
failures, and the tested commit. Do not include device serial numbers or customer
data. Both `hid` and `iminBroadcast` records are required before release.

Each run needs the model, Android/firmware versions, connection, output settings,
operator, UTC date, tested commit, 100 expected and 100 received frames with exact
contents, independent identities for intentional repeated reads, and all checks
in [the release checklist](releasing.md). These results qualify the recorded
configuration, not every device from the same manufacturer.
