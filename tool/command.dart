import 'dart:io';

String get flutterExecutable {
  final root = File(
    Platform.resolvedExecutable,
  ).parent.parent.parent.parent.parent;
  final candidate = File(
    '${root.path}/bin/flutter${Platform.isWindows ? '.bat' : ''}',
  );
  return candidate.existsSync() ? candidate.path : 'flutter';
}

Future<int> runCommand(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: Platform.isWindows,
  );
  await Future.wait([
    stdout.addStream(process.stdout),
    stderr.addStream(process.stderr),
  ]);
  return process.exitCode;
}
