import "cancellable_compute_stub.dart"
    if (dart.library.io) "cancellable_compute_io.dart"
    as implementation;
import "cancellable_compute_types.dart";

export "cancellable_compute_types.dart"
    show CancellableComputeCancelledException, CancellableComputeOperation;

typedef CancellableComputeCallback = Object? Function(Object? message);

/// Starts a computation whose native isolate is owned by the returned handle.
///
/// On native platforms, cancelling the returned handle or reaching [timeout]
/// kills the isolate immediately.
/// Web has no equivalent isolate primitive, so cancellation can only discard
/// a result before or after the synchronous callback runs.
CancellableComputeOperation<Object?> startCancellableCompute(
  CancellableComputeCallback callback,
  Object? message, {
  required Duration timeout,
  String? debugLabel,
}) {
  return implementation.startCancellableCompute(
    callback,
    message,
    timeout: timeout,
    debugLabel: debugLabel,
  );
}
