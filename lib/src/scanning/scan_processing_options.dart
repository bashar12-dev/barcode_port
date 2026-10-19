/// Optional text policy, independent of transport and checkout business rules.
final class ScanProcessingOptions {
  /// Creates an opt-in policy; defaults preserve intentional repeated reads.
  const ScanProcessingOptions({
    this.normalize,
    this.accept,
    this.duplicateWindow = Duration.zero,
  });

  /// Applied before trimming and validation. No automatic GS1 mutation.
  final String Function(String)? normalize;

  /// The optional predicate applied after normalization and trimming.
  ///
  /// Returning `false` emits a filtered diagnostic rather than an event.
  final bool Function(String)? accept;

  /// Consecutive accepted repeats only; zero disables suppression.
  final Duration duplicateWindow;
}
