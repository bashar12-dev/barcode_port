import 'dart:convert';
import 'dart:io';

import 'command.dart';

Future<void> main(List<String> args) async {
  final source = Directory.current.absolute;
  final temp = Directory.systemTemp.createTempSync('barcode_port_consumer_');
  final app = Directory('${temp.path}/consumer');
  final version = RegExp(
    r'^version:\s*(\S+)',
    multiLine: true,
  ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1)!;
  var result = await runCommand(flutterExecutable, [
    'create',
    '--platforms=android',
    '--project-name=barcode_port_smoke',
    '--org=dev.barcodeport',
    '--empty',
    '--no-pub',
    app.path,
  ]);
  if (result != 0) {
    exitCode = result;
    return;
  }
  final pubspec = File('${app.path}/pubspec.yaml');
  final dependency = args.contains('--hosted')
      ? '  barcode_port: ^$version'
      : '  barcode_port:\n    path: ${jsonEncode(source.path.replaceAll('\\', '/'))}';
  pubspec.writeAsStringSync(
    pubspec.readAsStringSync().replaceFirst(
      RegExp(r'^dependencies:\s*$', multiLine: true),
      'dependencies:\n$dependency',
    ),
  );
  File('${app.path}/lib/main.dart').writeAsStringSync('''
import 'package:barcode_port/scanner_widgets.dart';
import 'package:flutter/material.dart';

void main() => runApp(MaterialApp(home: Scaffold(body: ScannerListener(
  createScanner: () => Scanner(),
  onScan: (scan) => debugPrint(scan.eventId),
  child: const Text('BarcodePort consumer'),
))));
''');
  // API 24 is the package's documented Android floor.
  final gradle = File('${app.path}/android/app/build.gradle.kts');
  gradle.writeAsStringSync(
    gradle.readAsStringSync().replaceFirst(
      'minSdk = flutter.minSdkVersion',
      'minSdk = 24',
    ),
  );
  result = await runCommand(flutterExecutable, [
    'pub',
    'get',
  ], workingDirectory: app.path);
  if (result == 0) {
    result = await runCommand(flutterExecutable, [
      'build',
      'apk',
      '--debug',
      '--no-pub',
      '--target-platform',
      'android-arm64',
    ], workingDirectory: app.path);
  }
  if (result == 0) {
    stdout.writeln(
      'Independent ${args.contains('--hosted') ? 'hosted' : 'path'} consumer build passed.',
    );
    // Delete only the unique temporary directory created by this invocation.
    final resolved = temp.resolveSymbolicLinksSync();
    final parent = Directory.systemTemp.resolveSymbolicLinksSync();
    if (resolved.startsWith('$parent${Platform.pathSeparator}') &&
        temp.uri.pathSegments
            .where((part) => part.isNotEmpty)
            .last
            .startsWith('barcode_port_consumer_')) {
      try {
        temp.deleteSync(recursive: true);
      } on FileSystemException {
        stdout.writeln(
          'Build passed; retained temporary files at ${temp.path}.',
        );
      }
    }
  } else {
    stderr.writeln('Consumer failed; inspect ${app.path}.');
  }
  exitCode = result;
}
