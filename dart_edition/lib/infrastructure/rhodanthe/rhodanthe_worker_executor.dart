import "dart:async";
import "dart:isolate";

import "rhodanthe_latest_coordinator.dart";
import "rhodanthe_native_client.dart";
import "rhodanthe_protocol.dart";

final class RhodantheWorkerException implements Exception {
  final String code;
  final String message;

  const RhodantheWorkerException({required this.code, required this.message});

  @override
  String toString() => "RhodantheWorkerException($code): $message";
}

/// A long-lived isolate that exclusively owns one native Rhodanthe engine.
///
/// Commands are ordered by one worker receive port. No raw pointer or
/// [RhodantheNativeClient] crosses the isolate boundary.
final class RhodantheWorkerExecutor implements RhodantheAsyncExecutor {
  final Isolate _isolate;
  final SendPort _commandPort;
  final ReceivePort _eventPort;
  final ReceivePort _errorPort;
  final ReceivePort _exitPort;
  final StreamSubscription<Object?> _eventSubscription;
  final StreamSubscription<Object?> _errorSubscription;
  final StreamSubscription<Object?> _exitSubscription;
  final Map<int, Completer<RhodantheResponse>> _pending =
      <int, Completer<RhodantheResponse>>{};

  int _nextOperationId = 0;
  bool _disposed = false;
  bool _exited = false;
  Completer<void>? _exitCompleter;

  RhodantheWorkerExecutor._({
    required Isolate isolate,
    required SendPort commandPort,
    required ReceivePort eventPort,
    required ReceivePort errorPort,
    required ReceivePort exitPort,
    required StreamSubscription<Object?> eventSubscription,
    required StreamSubscription<Object?> errorSubscription,
    required StreamSubscription<Object?> exitSubscription,
  }) : _isolate = isolate,
       _commandPort = commandPort,
       _eventPort = eventPort,
       _errorPort = errorPort,
       _exitPort = exitPort,
       _eventSubscription = eventSubscription,
       _errorSubscription = errorSubscription,
       _exitSubscription = exitSubscription;

  static Future<RhodantheWorkerExecutor> start({
    String? libraryPath,
    Duration startupTimeout = const Duration(seconds: 5),
  }) async {
    final eventPort = ReceivePort();
    final errorPort = ReceivePort();
    final exitPort = ReceivePort();
    final ready = Completer<SendPort>();
    RhodantheWorkerExecutor? executor;

    late final StreamSubscription<Object?> eventSubscription;
    late final StreamSubscription<Object?> errorSubscription;
    late final StreamSubscription<Object?> exitSubscription;

    eventSubscription = eventPort.listen((Object? event) {
      final message = _messageMap(event);
      final type = message["type"];
      if (type == "ready" && !ready.isCompleted) {
        final commandPort = message["commandPort"];
        if (commandPort is! SendPort) {
          ready.completeError(
            const RhodantheWorkerException(
              code: "invalidWorkerMessage",
              message: "Worker ready event has no command port",
            ),
          );
        } else {
          ready.complete(commandPort);
        }
        return;
      }
      if (type == "startupError" && !ready.isCompleted) {
        ready.completeError(
          RhodantheWorkerException(
            code: _messageString(message, "code"),
            message: _messageString(message, "message"),
          ),
        );
        return;
      }
      executor?._handleEvent(message);
    });
    errorSubscription = errorPort.listen((Object? event) {
      final error = _remoteError(event);
      if (!ready.isCompleted) {
        ready.completeError(error);
      } else {
        executor?._failAll(error);
      }
    });
    exitSubscription = exitPort.listen((Object? _) {
      if (!ready.isCompleted) {
        ready.completeError(
          const RhodantheWorkerException(
            code: "workerExited",
            message: "Rhodanthe worker exited during startup",
          ),
        );
      }
      executor?._handleExit();
    });

    final Isolate isolate;
    try {
      isolate = await Isolate.spawn<Map<String, Object?>>(
        _rhodantheWorkerMain,
        <String, Object?>{
          "eventPort": eventPort.sendPort,
          if (libraryPath != null) "libraryPath": libraryPath,
        },
        onError: errorPort.sendPort,
        onExit: exitPort.sendPort,
        errorsAreFatal: true,
        debugName: "rhodanthe-worker",
      );
    } catch (_) {
      await eventSubscription.cancel();
      await errorSubscription.cancel();
      await exitSubscription.cancel();
      eventPort.close();
      errorPort.close();
      exitPort.close();
      rethrow;
    }

    try {
      final commandPort = await ready.future.timeout(startupTimeout);
      executor = RhodantheWorkerExecutor._(
        isolate: isolate,
        commandPort: commandPort,
        eventPort: eventPort,
        errorPort: errorPort,
        exitPort: exitPort,
        eventSubscription: eventSubscription,
        errorSubscription: errorSubscription,
        exitSubscription: exitSubscription,
      );
      return executor;
    } catch (_) {
      isolate.kill(priority: Isolate.immediate);
      await eventSubscription.cancel();
      await errorSubscription.cancel();
      await exitSubscription.cancel();
      eventPort.close();
      errorPort.close();
      exitPort.close();
      rethrow;
    }
  }

  @override
  Future<RhodantheResponse> execute(RhodantheRequest request) {
    if (_disposed) {
      return Future<RhodantheResponse>.error(
        const RhodantheWorkerException(
          code: "workerDisposed",
          message: "Rhodanthe worker is disposed",
        ),
      );
    }
    if (_exited) {
      return Future<RhodantheResponse>.error(
        const RhodantheWorkerException(
          code: "workerExited",
          message: "Rhodanthe worker is not running",
        ),
      );
    }
    final operationId = ++_nextOperationId;
    final completer = Completer<RhodantheResponse>();
    _pending[operationId] = completer;
    _commandPort.send(<String, Object?>{
      "type": "request",
      "operationId": operationId,
      "request": request.encode(),
    });
    return completer.future;
  }

  @override
  Future<void> dispose({Duration timeout = const Duration(seconds: 2)}) async {
    if (_disposed) return;
    _disposed = true;
    _failAll(
      const RhodantheWorkerException(
        code: "workerDisposed",
        message: "Rhodanthe worker was disposed",
      ),
    );
    if (!_exited) {
      _exitCompleter ??= Completer<void>();
      _commandPort.send(const <String, Object?>{"type": "dispose"});
      try {
        await _exitCompleter!.future.timeout(timeout);
      } on TimeoutException {
        _isolate.kill(priority: Isolate.immediate);
      }
    }
    await _closePorts();
  }

  void _handleEvent(Map<String, Object?> message) {
    if (message["type"] != "response") return;
    final operationId = message["operationId"];
    if (operationId is! int) return;
    final completer = _pending.remove(operationId);
    if (completer == null || completer.isCompleted) return;
    final errorCode = message["errorCode"];
    if (errorCode is String) {
      completer.completeError(
        RhodantheWorkerException(
          code: errorCode,
          message: _messageString(message, "errorMessage"),
        ),
      );
      return;
    }
    final payload = message["payload"];
    if (payload is! String) {
      completer.completeError(
        const RhodantheWorkerException(
          code: "invalidWorkerMessage",
          message: "Worker response has no JSON payload",
        ),
      );
      return;
    }
    try {
      completer.complete(RhodantheResponse.decode(payload));
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    }
  }

  void _handleExit() {
    if (_exited) return;
    _exited = true;
    _exitCompleter?.complete();
    if (!_disposed) {
      _failAll(
        const RhodantheWorkerException(
          code: "workerExited",
          message: "Rhodanthe worker exited unexpectedly",
        ),
      );
    }
  }

  void _failAll(Object error) {
    final pending = _pending.values.toList(growable: false);
    _pending.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) completer.completeError(error);
    }
  }

  Future<void> _closePorts() async {
    await _eventSubscription.cancel();
    await _errorSubscription.cancel();
    await _exitSubscription.cancel();
    _eventPort.close();
    _errorPort.close();
    _exitPort.close();
  }
}

void _rhodantheWorkerMain(Map<String, Object?> bootstrap) {
  final eventPort = bootstrap["eventPort"];
  if (eventPort is! SendPort) return;
  final libraryPath = bootstrap["libraryPath"];
  RhodantheNativeClient? client;
  ReceivePort? commandPort;
  try {
    client = RhodantheNativeClient.open(
      libraryPath: libraryPath is String ? libraryPath : null,
    );
    final handshake = client.sendSync(RhodantheRequest.handshake());
    handshake.requireResult();
    commandPort = ReceivePort();
    eventPort.send(<String, Object?>{
      "type": "ready",
      "commandPort": commandPort.sendPort,
    });
  } catch (error) {
    client?.dispose();
    eventPort.send(<String, Object?>{
      "type": "startupError",
      "code": "nativeUnavailable",
      "message": error.toString(),
    });
    return;
  }

  commandPort.listen((Object? event) {
    final message = _messageMap(event);
    if (message["type"] == "dispose") {
      client?.dispose();
      commandPort?.close();
      Isolate.exit();
    }
    if (message["type"] != "request") return;
    final operationId = message["operationId"];
    final request = message["request"];
    if (operationId is! int || request is! String) return;
    try {
      final payload = client!.sendEncodedSync(request);
      eventPort.send(<String, Object?>{
        "type": "response",
        "operationId": operationId,
        "payload": payload,
      });
    } catch (error) {
      eventPort.send(<String, Object?>{
        "type": "response",
        "operationId": operationId,
        "errorCode": "nativeRequestFailed",
        "errorMessage": error.toString(),
      });
    }
  });
}

Map<String, Object?> _messageMap(Object? value) {
  if (value is! Map) return const <String, Object?>{};
  return <String, Object?>{
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

String _messageString(Map<String, Object?> message, String key) {
  return message[key]?.toString() ?? "";
}

RhodantheWorkerException _remoteError(Object? value) {
  if (value is List && value.isNotEmpty) {
    return RhodantheWorkerException(
      code: "workerError",
      message: value.first?.toString() ?? "Worker failed",
    );
  }
  return RhodantheWorkerException(
    code: "workerError",
    message: value?.toString() ?? "Worker failed",
  );
}
