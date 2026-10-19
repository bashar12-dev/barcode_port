/// Optional text policy, independent of transport and checkout business rules.
final class ScanProcessingOptions {
  const ScanProcessingOptions({
    this.normalize,
    this.accept,
    this.duplicateWindow = Duration.zero,
  });

  /// Applied before trimming and validation. No automatic GS1 mutation.
  final String Function(String)? normalize;
  final bool Function(String)? accept;

  /// Consecutive accepted repeats only; zero disables suppression.
  final Duration duplicateWindow;
}
