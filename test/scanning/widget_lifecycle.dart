import 'package:flutter_test/flutter_test.dart';

Future<void> pumpUntil(WidgetTester tester, bool Function() completed) async {
  for (var turn = 0; !completed() && turn < 100; turn++) {
    // Subscription cancellation can complete in the framework's real zone.
    // Yield that event loop too; pumping only the fake clock cannot finish it.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(Duration.zero);
  }
  expect(
    completed(),
    isTrue,
    reason: 'Asynchronous scanner cleanup must complete',
  );
}

/// Drain lifecycle microtasks inside the widget binding's fake clock.
Future<void> completeLifecycle(
  WidgetTester tester,
  Future<void> operation,
) async {
  var completed = false;
  Object? failure;
  StackTrace? trace;
  operation.then(
    (_) {
      completed = true;
    },
    onError: (Object error, StackTrace stack) {
      failure = error;
      trace = stack;
      completed = true;
    },
  );
  // Nested decorators can close several asynchronous streams in sequence.
  // Drain until the operation completes, with a bounded failure condition.
  for (var turn = 0; !completed && turn < 100; turn++) {
    await tester.pump(Duration.zero);
  }
  expect(
    completed,
    isTrue,
    reason: 'Lifecycle operation must finish after draining microtasks',
  );
  if (failure != null) Error.throwWithStackTrace(failure!, trace!);
}
