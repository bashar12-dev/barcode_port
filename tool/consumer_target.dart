/// Build targets supported by the independent-consumer smoke check.
enum ConsumerTarget { android, web, windows, linux, macos, ios }

/// Validates options before creating files or launching Flutter.
ConsumerTarget parseConsumerTarget(List<String> args) {
  ConsumerTarget? target;
  for (final argument in args) {
    if (argument == '--hosted') continue;
    if (!argument.startsWith('--platform=') || target != null) {
      throw ArgumentError('Expected --hosted and one --platform=<target>.');
    }
    final name = argument.substring('--platform='.length);
    target = ConsumerTarget.values.where((t) => t.name == name).firstOrNull;
    if (target == null) {
      throw ArgumentError(
        'Unsupported platform: $name. '
        'Choose android, web, windows, linux, macos, or ios.',
      );
    }
  }
  return target ?? ConsumerTarget.android;
}

/// Flutter build arguments for the selected target and its build host.
List<String> consumerBuildArguments(ConsumerTarget target) => switch (target) {
  ConsumerTarget.android => [
    'apk',
    '--debug',
    '--no-pub',
    '--target-platform',
    'android-arm64',
  ],
  ConsumerTarget.web => ['web', '--no-pub'],
  ConsumerTarget.ios => [
    'ios',
    '--simulator',
    '--debug',
    '--no-codesign',
    '--no-pub',
  ],
  _ => [target.name, '--debug', '--no-pub'],
};
