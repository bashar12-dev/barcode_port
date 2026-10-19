import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_validation.dart';

Map<String, Object?> run(String transport) => {
  'transport': transport,
  'model': 'Test model',
  'androidVersion': '14',
  'firmware': 'test firmware',
  'connection': transport == 'hid' ? 'USB keyboard' : 'broadcast',
  'outputConfiguration': 'Recorded in report',
  'operator': 'Test operator',
  'testedAt': '2026-10-20T00:00:00Z',
  'testedCommit': List.filled(40, 'a').join(),
  'expectedFrames': 100,
  'receivedFrames': 100,
  'attestedPhysicalRun': true,
  'report': 'doc/hardware/$transport.md',
  'checks': {
    for (final name in [
      'exactContent',
      'distinctRepeatIds',
      'coveredRoute',
      'coveredDialog',
      'appLifecycle',
      'manualDisable',
      'startStopDispose',
      'hotRestart',
      if (transport == 'hid') ...[
        'enterSuffix',
        'tabSuffix',
        'editablePassThrough',
        'partialFrameCleared',
      ] else
        'editableFocusIndependent',
    ])
      name: true,
  },
};

Map<String, Object?> evidence() => {
  'releaseVersion': '1.0.0',
  'runs': [run('hid'), run('iminBroadcast')],
};

List<String> validate(
  Object? data, {
  bool Function(String)? sourceMatches,
  bool Function(String)? reportExists,
}) => validateHardwareEvidence(
  data,
  version: '1.0.0',
  sourceMatches: sourceMatches ?? (_) => true,
  reportExists: reportExists ?? (_) => true,
);

void main() {
  test('empty or malformed records never qualify physical transports', () {
    expect(validate(null), isNotEmpty);
    expect(validate({'releaseVersion': '1.0.0', 'runs': []}), isNotEmpty);
  });

  test('complete attested records for both transports qualify', () {
    expect(validate(evidence()), isEmpty);
  });

  test('version mismatch and a missing transport block release', () {
    expect(validate(evidence()..['releaseVersion'] = '0.0.1'), isNotEmpty);
    expect(
      validate({
        'releaseVersion': '1.0.0',
        'runs': [run('hid')],
      }),
      isNotEmpty,
    );
  });

  test('counts must match and cover at least one hundred frames', () {
    for (final counts in [(99, 99), (100, 99), (100, 101)]) {
      final hid = run('hid')
        ..['expectedFrames'] = counts.$1
        ..['receivedFrames'] = counts.$2;
      expect(
        validate({
          'releaseVersion': '1.0.0',
          'runs': [hid, run('iminBroadcast')],
        }),
        isNotEmpty,
      );
    }
  });

  test('failed checks and absent physical attestation block release', () {
    final hid = run('hid')..['attestedPhysicalRun'] = false;
    expect(
      validate({
        'releaseVersion': '1.0.0',
        'runs': [hid, run('iminBroadcast')],
      }),
      isNotEmpty,
    );
    hid['attestedPhysicalRun'] = true;
    (hid['checks'] as Map<String, bool>)['tabSuffix'] = false;
    expect(
      validate({
        'releaseVersion': '1.0.0',
        'runs': [hid, run('iminBroadcast')],
      }),
      isNotEmpty,
    );
  });

  test('unknown models or missing metadata are not qualified', () {
    final hid = run('hid')..['model'] = 'unknown';
    expect(
      validate({
        'releaseVersion': '1.0.0',
        'runs': [hid, run('iminBroadcast')],
      }),
      isNotEmpty,
    );
  });

  test('runtime source mismatch or missing report blocks release', () {
    expect(validate(evidence(), sourceMatches: (_) => false), isNotEmpty);
    expect(validate(evidence(), reportExists: (_) => false), isNotEmpty);
  });

  test('external report paths and duplicate transports are rejected', () {
    final hid = run('hid')..['report'] = '../private.md';
    expect(
      validate({
        'releaseVersion': '1.0.0',
        'runs': [hid, run('iminBroadcast')],
      }),
      isNotEmpty,
    );
    expect(
      validate({
        'releaseVersion': '1.0.0',
        'runs': [run('hid'), run('hid'), run('iminBroadcast')],
      }),
      isNotEmpty,
    );
  });
}
