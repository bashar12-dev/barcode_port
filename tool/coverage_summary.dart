import 'dart:io';

void main() {
  final lines = File('coverage/lcov.info').readAsLinesSync();
  var include = false;
  var hit = 0;
  var total = 0;
  final filtered = <String>[];
  for (final line in lines) {
    if (line.startsWith('SF:')) {
      final path = line.substring(3).replaceAll('\\', '/');
      include =
          (path.startsWith('lib/') || path.contains('/lib/')) &&
          !path.contains('/generated/') &&
          !path.endsWith('.g.dart');
    }
    if (!include) continue;
    filtered.add(line);
    if (line.startsWith('DA:')) {
      final fields = line.substring(3).split(',');
      total++;
      if (int.parse(fields[1]) > 0) hit++;
    }
  }
  if (total == 0) {
    throw StateError('No handwritten library coverage was recorded.');
  }
  File(
    'coverage/handwritten.info',
  ).writeAsStringSync('${filtered.join('\n')}\n');
  final summary =
      'Handwritten library lines: $hit/$total '
      '(${(hit * 100 / total).toStringAsFixed(1)}%).';
  File('coverage/summary.txt').writeAsStringSync('$summary\n');
  stdout.writeln(summary);
}
