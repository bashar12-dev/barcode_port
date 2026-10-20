import 'package:flutter_test/flutter_test.dart';

import '../../tool/consumer_target.dart';

void main() {
  test('Android remains the default for existing callers', () {
    expect(parseConsumerTarget([]), ConsumerTarget.android);
    expect(parseConsumerTarget(['--hosted']), ConsumerTarget.android);
  });

  test('selects all six explicit build targets with hosted or path input', () {
    for (final target in ConsumerTarget.values) {
      expect(parseConsumerTarget(['--platform=${target.name}']), target);
      expect(
        parseConsumerTarget(['--hosted', '--platform=${target.name}']),
        target,
      );
    }
  });

  test('rejects unsupported, empty, duplicated or misspelled options', () {
    for (final args in [
      ['--platform=fuchsia'],
      ['--platform='],
      ['--platform=web', '--platform=ios'],
      ['--platfrom=web'],
      ['web'],
    ]) {
      expect(() => parseConsumerTarget(args), throwsArgumentError);
    }
  });
}
