import "dart:async";
import "dart:isolate";

import "cancellable_compute_types.dart";

typedef CancellableComputeCallback = Object? Function(Object? message);

class _WorkerRequest {
  final SendPort resultPort;
  final CancellableComputeCallback callback;
  final Object? message;

  const _WorkerRequest(this.resultPort, this.callback, this.message);
}

void _runWorker(_WorkerRequest request) {
  final Object? result = request.callback(request.message);
  Isolate.exit(request.resultPort, result);
}

CancellableComputeOperation<Object?> startCancellableCompute(
  CancellableComputeCallback callback,
  Object? message, {
  required Duration timeout,
  String? debugLabel,
}) {
  final Completer<Object?> completer = Completer<Object?>();
  final ReceivePort resultPort = ReceivePort();
  final ReceivePort errorPort = ReceivePort();

  Isolate? isolate;
  Timer? timeoutTimer;
  bool closed = false;

  void close({bool kill = false}) {
    if (closed) {
      return;
    }
    closed = true;
    timeoutTimer?.cancel();
    timeoutTimer = null;
    if (kill) {
      isolate?.kill(priority: Isolate.immediate);
    }
    resultPort.close();
    errorPort.close();
  }

  void completeTimeout() {
    if (closed) {
      return;
    }
    if (!completer.isCompleted) {
      completer.completeError(
        TimeoutException("Background operation exceeded $timeout", timeout),
      );
    }
    close(kill: true);
  }

  void cancel() {
    if (closed) {
      return;
    }
    if (!completer.isCompleted) {
      completer.completeError(const CancellableComputeCancelledException());
    }
    close(kill: true);
  }

  resultPort.listen((Object? result) {
    if (closed) {
      return;
    }
    if (!completer.isCompleted) {
      completer.complete(result);
    }
    close();
  });

  errorPort.listen((Object? errorData) {
    if (closed) {
      return;
    }
    final Object error;
    final StackTrace stackTrace;
    if (errorData is List<Object?> && errorData.length >= 2) {
      error = RemoteError(
        errorData[0]?.toString() ?? "Background operation failed",
        errorData[1]?.toString() ?? "",
      );
      stackTrace = StackTrace.fromString(errorData[1]?.toString() ?? "");
    } else {
      error = StateError(
        errorData?.toString() ?? "Background operation failed",
      );
      stackTrace = StackTrace.current;
    }
    if (!completer.isCompleted) {
      completer.completeError(error, stackTrace);
    }
    close(kill: true);
  });

  timeoutTimer = Timer(timeout.isNegative ? Duration.zero : timeout, () {
    completeTimeout();
  });

  unawaited(() async {
    try {
      final Isolate spawned = await Isolate.spawn<_WorkerRequest>(
        _runWorker,
        _WorkerRequest(resultPort.sendPort, callback, message),
        onError: errorPort.sendPort,
        errorsAreFatal: true,
        debugName: debugLabel,
      );
      if (closed) {
        spawned.kill(priority: Isolate.immediate);
        return;
      }
      isolate = spawned;
    } catch (error, stackTrace) {
      if (closed) {
        return;
      }
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      close(kill: true);
    }
  }());

  return CancellableComputeOperation<Object?>(
    value: completer.future,
    cancel: cancel,
  );
}
