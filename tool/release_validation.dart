/// Validates recorded physical-device evidence without inferring test results.
List<String> validateHardwareEvidence(
  Object? evidence, {
  required String version,
  required bool Function(String) sourceMatches,
  required bool Function(String) reportExists,
}) {
  final errors = <String>[];
  if (evidence is! Map<String, dynamic>) {
    return ['Hardware evidence must be a JSON object.'];
  }
  if (evidence['releaseVersion'] != version) {
    errors.add('Hardware evidence must target version $version.');
  }
  final runs = evidence['runs'];
  if (runs is! List) return [...errors, 'Hardware runs must be a list.'];
  for (final transport in ['hid', 'iminBroadcast']) {
    final matching = runs
        .whereType<Map<String, dynamic>>()
        .where((run) => run['transport'] == transport)
        .toList();
    if (matching.length != 1) {
      errors.add(
        '$transport requires exactly one physical qualification record.',
      );
      continue;
    }
    final run = matching.single;
    for (final key in [
      'model',
      'androidVersion',
      'firmware',
      'connection',
      'outputConfiguration',
      'operator',
    ]) {
      final value = run[key];
      if (value is! String ||
          value.trim().isEmpty ||
          [
            'unknown',
            'not recorded',
            'pending',
          ].contains(value.trim().toLowerCase())) {
        errors.add('$transport requires recorded $key.');
      }
    }
    final testedAt = run['testedAt'];
    if (testedAt is! String ||
        !testedAt.endsWith('Z') ||
        DateTime.tryParse(testedAt) == null) {
      errors.add('$transport requires a UTC testedAt date.');
    }
    final commit = run['testedCommit'];
    if (commit is! String ||
        !RegExp(r'^[0-9a-f]{40}$').hasMatch(commit) ||
        !sourceMatches(commit)) {
      errors.add(
        '$transport tested commit must match the candidate runtime source.',
      );
    }
    final expected = run['expectedFrames'];
    final received = run['receivedFrames'];
    if (expected is! int ||
        received is! int ||
        expected < 100 ||
        received != expected) {
      errors.add(
        '$transport requires at least 100 frames with matching counts.',
      );
    }
    if (run['attestedPhysicalRun'] != true) {
      errors.add('$transport requires an attested physical run.');
    }
    final report = run['report'];
    if (report is! String ||
        !report.startsWith('doc/hardware/') ||
        !report.endsWith('.md') ||
        report.contains('..') ||
        report.contains('\\') ||
        report.contains(':') ||
        !reportExists(report)) {
      errors.add('$transport requires a local report under doc/hardware/.');
    }
    final checks = run['checks'];
    for (final check in [
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
    ]) {
      if (checks is! Map || checks[check] != true) {
        errors.add('$transport requires successful $check.');
      }
    }
  }
  return errors;
}
