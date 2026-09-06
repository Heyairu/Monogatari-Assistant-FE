import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_latest_coordinator.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_protocol.dart";

void main() {
  test("newer generation makes an older response stale", () async {
    final executor = _ControlledExecutor();
    final coordinator = RhodantheLatestCoordinator(executor: executor);
    final first = coordinator.run(RhodantheRequest.handshake(requestId: 1));
    final second = coordinator.run(RhodantheRequest.handshake(requestId: 2));

    executor.complete(1, _success(2));
    expect((await second).status, RhodantheExecutionStatus.applied);
    executor.complete(0, _success(1));
    expect((await first).status, RhodantheExecutionStatus.stale);

    await coordinator.dispose();
  });

  test(
    "structured engine errors select fallback only for latest request",
    () async {
      final failures = <RhodantheFailure>[];
      final executor = _ControlledExecutor();
      final coordinator = RhodantheLatestCoordinator(
        executor: executor,
        onFallback: failures.add,
      );
      final operation = coordinator.run(
        RhodantheRequest.handshake(requestId: 3),
      );
      executor.complete(0, _failure("regexRejected"));

      final result = await operation;
      expect(result.status, RhodantheExecutionStatus.fallback);
      expect(result.failure?.code, "regexRejected");
      expect(failures.single.code, "regexRejected");

      await coordinator.dispose();
    },
  );

  test("deadline returns a non-throwing timeout fallback", () async {
    final failures = <RhodantheFailure>[];
    final executor = _ControlledExecutor();
    final coordinator = RhodantheLatestCoordinator(
      executor: executor,
      timeout: const Duration(milliseconds: 10),
      onFallback: failures.add,
    );

    final result = await coordinator.run(RhodantheRequest.handshake());

    expect(result.status, RhodantheExecutionStatus.timedOut);
    expect(result.failure?.code, "timeout");
    expect(failures.single.code, "timeout");

    await coordinator.dispose();
  });

  test("invalidate discards an in-flight response without fallback", () async {
    final failures = <RhodantheFailure>[];
    final executor = _ControlledExecutor();
    final coordinator = RhodantheLatestCoordinator(
      executor: executor,
      onFallback: failures.add,
    );
    final operation = coordinator.run(RhodantheRequest.handshake());
    coordinator.invalidate();

    expect((await operation).status, RhodantheExecutionStatus.stale);
    expect(failures, isEmpty);
    executor.complete(0, _failure("internal"));

    await coordinator.dispose();
    expect(executor.disposed, isTrue);
  });
}

final class _ControlledExecutor implements RhodantheAsyncExecutor {
  final List<Completer<RhodantheResponse>> _requests =
      <Completer<RhodantheResponse>>[];
  bool disposed = false;

  @override
  Future<RhodantheResponse> execute(RhodantheRequest request) {
    final completer = Completer<RhodantheResponse>();
    _requests.add(completer);
    return completer.future;
  }

  void complete(int index, RhodantheResponse response) {
    _requests[index].complete(response);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

RhodantheResponse _success(int requestId) =>
    RhodantheResponse.fromJson(<String, Object?>{
      "ok": true,
      "contractVersion": 1,
      "requestId": requestId,
      "result": <String, Object?>{"kind": "handshake"},
    });

RhodantheResponse _failure(String code) =>
    RhodantheResponse.fromJson(<String, Object?>{
      "ok": false,
      "contractVersion": 1,
      "requestId": 1,
      "error": <String, Object?>{"code": code, "message": "failed"},
    });
