import "dart:async";

import "package:flutter/foundation.dart";

import "cancellable_compute_types.dart";

typedef CancellableComputeCallback = Object? Function(Object? message);

CancellableComputeOperation<Object?> startCancellableCompute(
  CancellableComputeCallback callback,
  Object? message, {
  required Duration timeout,
  String? debugLabel,
}) {
  final Completer<Object?> completer = Completer<Object?>();
  bool cancelled = false;

  final Future<Object?> worker = compute<Object?, Object?>(
    callback,
    message,
    debugLabel: debugLabel,
  );
  worker.then(
    (Object? result) {
      if (!cancelled && !completer.isCompleted) {
        completer.complete(result);
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      if (!cancelled && !completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    },
  );

  void cancel() {
    if (cancelled) {
      return;
    }
    cancelled = true;
    if (!completer.isCompleted) {
      completer.completeError(const CancellableComputeCancelledException());
    }
  }

  return CancellableComputeOperation<Object?>(
    value: completer.future,
    cancel: cancel,
  );
}
