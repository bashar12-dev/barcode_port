import 'dart:io';

import 'command.dart';

Future<void> main() async {
  final files = <String>[];
  for (final path in [
    'lib',
    'test',
    'tool',
    'pigeons',
    'example/lib',
    'example/test',
  ]) {
    for (final file in Directory(
      path,
    ).listSync(recursive: true, followLinks: false)) {
      final name = file.path.replaceAll('\\', '/');
      if (file is File &&
          name.endsWith('.dart') &&
          !name.contains('/generated/')) {
        files.add(file.path);
      }
    }
  }
  exitCode = await runCommand(Platform.resolvedExecutable, [
    'format',
    '--output=none',
    '--set-exit-if-changed',
    ...files,
  ]);
}
