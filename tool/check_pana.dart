import 'dart:io';

import 'command.dart';

Future<void> main() async {
  final temp = Directory.systemTemp.createTempSync('barcode_port_pana_');
  final archive = '${temp.path}/source.tar';
  final source = Directory('${temp.path}/source')..createSync();
  var result = await runCommand('git', [
    'archive',
    '--format=tar',
    '-o',
    archive,
    'HEAD',
  ]);
  if (result == 0) {
    result = await runCommand('tar', ['-xf', archive, '-C', source.path]);
  }
  if (result == 0) {
    stdout.writeln(
      'Pana analyzes an isolated committed snapshot: ${source.path}',
    );
    result = await runCommand(Platform.resolvedExecutable, [
      'pub',
      'global',
      'run',
      'pana',
      '--dartdoc-version',
      '9.0.11',
      '--exit-code-threshold',
      '0',
      source.path,
    ]);
  }
  // Keep this temporary report/source available for diagnosing scoring issues.
  stdout.writeln('Pana scratch directory: ${temp.path}');
  exitCode = result;
}
