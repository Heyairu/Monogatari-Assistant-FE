import "dart:async";

import "rhodanthe_protocol.dart";

abstract interface class RhodantheAsyncExecutor {
  Future<RhodantheResponse> execute(RhodantheRequest request);

  Future<void> dispose();
}

enum RhodantheExecutionStatus { applied, stale, fallback, timedOut }

final class RhodantheExecutionResult {
  final RhodantheExecutionStatus status;
  final int generation;
  final RhodantheResponse? response;
  final RhodantheFailure? failure;

  const RhodantheExecutionResult._({
    required this.status,
    required this.generation,
    this.response,
    this.failure,
  });

  bool get shouldApply => status == RhodantheExecutionStatus.applied;
}

typedef RhodantheFallbackCallback = void Function(RhodantheFailure failure);

/// Applies latest-only and timeout policy to a non-blocking executor.
///
/// The executor must perform native work outside the UI isolate. A raw
/// `RhodantheNativeClient.sendSync` call must therefore not be wrapped directly
/// here; the worker adapter owns that integration boundary.
final class RhodantheLatestCoordinator {
  final RhodantheAsyncExecutor _executor;
  final Duration timeout;
  final RhodantheFallbackCallback? onFallback;

  int _generation = 0;
  bool _disposed = false;
  Completer<void>? _activeInvalidation;

  RhodantheLatestCoordinator({
    required RhodantheAsyncExecutor executor,
    this.timeout = const Duration(seconds: 2),
    this.onFallback,
  }) : _executor = executor;

  int get generation => _generation;

  Future<RhodantheExecutionResult> run(RhodantheRequest request) async {
    if (_disposed) throw StateError("Rhodanthe coordinator is disposed");
    final generation = ++_generation;
    _invalidateActive();
    final invalidation = Completer<void>();
    _activeInvalidation = invalidation;
    try {
      final event = await Future.any<Object>(<Future<Object>>[
        _executor.execute(request),
        invalidation.future.then<Object>((_) => const _Invalidated()),
      ]).timeout(timeout);
      if (event is _Invalidated) {
        return RhodantheExecutionResult._(
          status: RhodantheExecutionStatus.stale,
          generation: generation,
        );
      }
      final response = event as RhodantheResponse;
      if (_disposed || generation != _generation) {
        return RhodantheExecutionResult._(
          status: RhodantheExecutionStatus.stale,
          generation: generation,
          response: response,
        );
      }
      if (!response.ok) {
        final failure = response.error!;
        onFallback?.call(failure);
        return RhodantheExecutionResult._(
          status: RhodantheExecutionStatus.fallback,
          generation: generation,
          response: response,
          failure: failure,
        );
      }
      return RhodantheExecutionResult._(
        status: RhodantheExecutionStatus.applied,
        generation: generation,
        response: response,
      );
    } on TimeoutException {
      if (_disposed || generation != _generation) {
        return RhodantheExecutionResult._(
          status: RhodantheExecutionStatus.stale,
          generation: generation,
        );
      }
      final failure = RhodantheFailure(
        code: "timeout",
        message: "Rhodanthe request exceeded $timeout",
      );
      onFallback?.call(failure);
      return RhodantheExecutionResult._(
        status: RhodantheExecutionStatus.timedOut,
        generation: generation,
        failure: failure,
      );
    } catch (error) {
      if (_disposed || generation != _generation) {
        return RhodantheExecutionResult._(
          status: RhodantheExecutionStatus.stale,
          generation: generation,
        );
      }
      final failure = RhodantheFailure(
        code: "unavailable",
        message: error.toString(),
      );
      onFallback?.call(failure);
      return RhodantheExecutionResult._(
        status: RhodantheExecutionStatus.fallback,
        generation: generation,
        failure: failure,
      );
    } finally {
      if (identical(_activeInvalidation, invalidation)) {
        _activeInvalidation = null;
      }
    }
  }

  void invalidate() {
    if (_disposed) return;
    ++_generation;
    _invalidateActive();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    _invalidateActive();
    await _executor.dispose();
  }

  void _invalidateActive() {
    final active = _activeInvalidation;
    _activeInvalidation = null;
    if (active != null && !active.isCompleted) active.complete();
  }
}

final class _Invalidated {
  const _Invalidated();
}
