import 'dart:async';

/// A failed operation releases the queue but still fails its caller's future.
final class SerialOperations {
  Future<void> _tail = Future<void>.value();

  /// Runs [operation] after the previous operation and propagates its failure.
  Future<void> run(Future<void> Function() operation) async {
    final previous = _tail;
    final completed = Completer<void>();
    _tail = completed.future;
    try {
      await previous;
      await operation();
    } finally {
      completed.complete();
    }
  }
}
