import 'dart:convert';
import 'dart:io';

import 'release_validation.dart';

Future<void> main(List<String> args) async {
  final root = Directory.current;
  final manifest = File('pubspec.yaml').readAsStringSync();
  final version = RegExp(
    r'^version:\s*(\S+)',
    multiLine: true,
  ).firstMatch(manifest)?.group(1);
  if (version == null) throw StateError('Missing package version.');
  final index = args.indexOf('--version');
  if (index >= 0 && (index + 1 >= args.length || args[index + 1] != version)) {
    stderr.writeln('Requested version must match pubspec.yaml ($version).');
    exitCode = 1;
    return;
  }
  final tag = Platform.environment['GITHUB_REF'];
  if (tag != null &&
      tag.startsWith('refs/tags/') &&
      tag != 'refs/tags/v$version') {
    stderr.writeln('Release tag must be v$version.');
    exitCode = 1;
    return;
  }
  Object? evidence;
  try {
    evidence = jsonDecode(
      File('doc/hardware-validation.json').readAsStringSync(),
    );
  } on Object catch (error) {
    stderr.writeln('Cannot read hardware evidence: $error');
    exitCode = 1;
    return;
  }
  final errors = validateHardwareEvidence(
    evidence,
    version: version,
    sourceMatches: (commit) {
      final exists = Process.runSync('git', [
        'cat-file',
        '-e',
        '$commit^{commit}',
      ]);
      if (exists.exitCode != 0) return false;
      final diff = Process.runSync('git', [
        'diff',
        '--quiet',
        commit,
        '--',
        'lib',
        'android',
        'pigeons',
        'example/lib',
        'pubspec.yaml',
        'example/pubspec.yaml',
      ]);
      return diff.exitCode == 0;
    },
    reportExists: (path) {
      final file = File(path);
      if (!file.existsSync() || file.readAsStringSync().trim().isEmpty) {
        return false;
      }
      final resolved = file.resolveSymbolicLinksSync();
      return resolved.startsWith(
        '${root.resolveSymbolicLinksSync()}${Platform.pathSeparator}',
      );
    },
  );
  if (errors.isNotEmpty) {
    stderr.writeln('Release blocked:');
    for (final error in errors) {
      stderr.writeln('- $error');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'Physical qualification and version gates passed for $version.',
  );
}
