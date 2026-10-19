# Recording physical evidence

Use synthetic labels. Document the setup, observed behavior, and tested source
commit in a Markdown report in this directory. Use the check names below in
`doc/hardware-validation.json`; set a check to `true` only after verifying it.

Each element in `runs` uses this shape (fill actual values; do not copy nulls as
successful evidence):

```json
{
  "transport": "hid",
  "model": null,
  "androidVersion": null,
  "firmware": null,
  "connection": null,
  "outputConfiguration": null,
  "operator": null,
  "testedAt": null,
  "testedCommit": null,
  "expectedFrames": 100,
  "receivedFrames": null,
  "attestedPhysicalRun": false,
  "report": "doc/hardware/hid.md",
  "checks": {
    "exactContent": false,
    "distinctRepeatIds": false,
    "coveredRoute": false,
    "coveredDialog": false,
    "appLifecycle": false,
    "manualDisable": false,
    "startStopDispose": false,
    "hotRestart": false,
    "enterSuffix": false,
    "tabSuffix": false,
    "editablePassThrough": false,
    "partialFrameCleared": false
  }
}
```

For the second record set `transport` to `iminBroadcast` and use its own report.
Replace the four HID-specific checks (`enterSuffix`, `tabSuffix`,
`editablePassThrough`, `partialFrameCleared`) with `editableFocusIndependent`.
Use an ISO-8601 UTC date ending in `Z` and the full 40-character Git commit.
Count at least 100 frames, require received count to match the expected count,
and compare their exact contents. Include leading zeros and intentional repeats.

The tested commit must exist locally and its runtime, native, Pigeon, example,
and dependency sources must match the release candidate. Later documentation
changes alone do not invalidate a run. The validator rejects missing records,
unknown model placeholders, count mismatches, failed checks, missing reports,
and source mismatches. Human attestation remains necessary; JSON cannot prove
that physical interactions occurred.
