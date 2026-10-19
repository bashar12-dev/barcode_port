import 'dart:io';

import 'command.dart';

/// Regenerates both bindings and applies the package's Dart formatting policy.
Future<void> main() async {
  var result = await runCommand(Platform.resolvedExecutable, [
    'run',
    'pigeon',
    '--input',
    'pigeons/scanner_host.dart',
  ]);
  if (result == 0) {
    result = await runCommand(Platform.resolvedExecutable, [
      'format',
      'lib/src/generated/scanner_host.g.dart',
    ]);
  }
  exitCode = result;
}
