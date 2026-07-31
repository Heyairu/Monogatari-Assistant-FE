import "dart:async";

/// Raised when a background operation is explicitly superseded or cancelled.
class CancellableComputeCancelledException implements Exception {
  const CancellableComputeCancelledException();

  @override
  String toString() => "Background operation was cancelled";
}

/// Owns a background computation and can terminate or invalidate it.
class CancellableComputeOperation<T> {
  final Future<T> value;
  final void Function() _cancel;

  CancellableComputeOperation({
    required this.value,
    required void Function() cancel,
  }) : _cancel = cancel;

  void cancel() => _cancel();
}
