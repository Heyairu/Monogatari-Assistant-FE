import "dart:async";

import "package:flutter_test/flutter_test.dart";

import "package:monogatari_assistant/utils/cancellable_compute.dart";

Object? _busyWorker(Object? milliseconds) {
  final int durationMilliseconds = milliseconds! as int;
  final Stopwatch stopwatch = Stopwatch()..start();
  while (stopwatch.elapsedMilliseconds < durationMilliseconds) {
    // Intentionally keep the isolate busy so the test can verify that the
    // owner terminates it rather than merely ignoring a late result.
  }
  return "completed";
}

void main() {
  test("native worker timeout terminates a busy isolate", () async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final CancellableComputeOperation<Object?> operation =
        startCancellableCompute(
          _busyWorker,
          5000,
          timeout: const Duration(milliseconds: 50),
          debugLabel: "timeout-test",
        );

    await expectLater(operation.value, throwsA(isA<TimeoutException>()));
    stopwatch.stop();
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
  });

  test("explicit cancellation completes promptly", () async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final CancellableComputeOperation<Object?> operation =
        startCancellableCompute(
          _busyWorker,
          5000,
          timeout: const Duration(seconds: 10),
          debugLabel: "cancel-test",
        );

    final Future<void> expectation = expectLater(
      operation.value,
      throwsA(isA<CancellableComputeCancelledException>()),
    );
    operation.cancel();
    await expectation;
    stopwatch.stop();
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
  });
}
