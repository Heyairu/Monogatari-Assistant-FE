import "dart:async";
import "dart:collection";
import "dart:isolate";

import "../bin/content_manager.dart";
import "../bin/settings_manager.dart";

class WordCountWorkerPool {
  WordCountWorkerPool({int size = 2}) : _size = size < 1 ? 1 : size;

  final int _size;
  final List<_WorkerHandle> _workers = <_WorkerHandle>[];
  final Queue<_QueuedJob> _jobs = Queue<_QueuedJob>();
  Completer<void>? _startCompleter;
  int _nextJobId = 0;
  bool _disposed = false;

  Future<int> calculate(String content, int modeIndex) async {
    if (_disposed) {
      throw StateError("Word-count worker pool has been disposed.");
    }
    if (content.isEmpty) {
      return 0;
    }

    await _ensureStarted();
    final completer = Completer<int>();
    _jobs.add(
      _QueuedJob(
        id: ++_nextJobId,
        content: content,
        modeIndex: modeIndex,
        completer: completer,
      ),
    );
    _drain();
    return completer.future;
  }

  Future<void> _ensureStarted() {
    if (_workers.length == _size) {
      return Future<void>.value();
    }
    final existing = _startCompleter;
    if (existing != null) {
      return existing.future;
    }

    final completer = Completer<void>();
    _startCompleter = completer;
    Future.wait(List<Future<_WorkerHandle>>.generate(_size, (_) => _spawn()))
        .then((workers) {
          if (_disposed) {
            for (final worker in workers) {
              worker.dispose();
            }
            throw StateError("Word-count worker pool has been disposed.");
          }
          _workers.addAll(workers);
          _startCompleter = null;
          completer.complete();
        })
        .catchError((Object error, StackTrace stackTrace) {
          _startCompleter = null;
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        });
    return completer.future;
  }

  Future<_WorkerHandle> _spawn() async {
    final readyPort = ReceivePort();
    final errorPort = ReceivePort();
    final isolate = await Isolate.spawn<SendPort>(
      _wordCountWorkerEntryPoint,
      readyPort.sendPort,
      onError: errorPort.sendPort,
      errorsAreFatal: true,
      debugName: "word-count-worker",
    );
    final sendPort = await readyPort.first as SendPort;
    readyPort.close();
    return _WorkerHandle(
      isolate: isolate,
      sendPort: sendPort,
      errorPort: errorPort,
    );
  }

  void _drain() {
    if (_disposed) {
      return;
    }
    for (final worker in _workers) {
      if (worker.isBusy || _jobs.isEmpty) {
        continue;
      }
      final job = _jobs.removeFirst();
      worker.isBusy = true;
      final responsePort = ReceivePort();
      worker.responsePort = responsePort;
      responsePort.first.then((dynamic message) {
        responsePort.close();
        worker.responsePort = null;
        worker.isBusy = false;
        if (message is List<Object?> && message.length >= 2) {
          final Object? error = message[1];
          if (error == null) {
            job.completer.complete(message[0] as int);
          } else {
            job.completer.completeError(StateError(error.toString()));
          }
        } else {
          job.completer.completeError(
            StateError("Invalid response from word-count worker."),
          );
        }
        _drain();
      });
      worker.sendPort.send(<Object?>[
        responsePort.sendPort,
        job.id,
        job.content,
        job.modeIndex,
      ]);
    }
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    final error = StateError("Word-count worker pool has been disposed.");
    while (_jobs.isNotEmpty) {
      final job = _jobs.removeFirst();
      if (!job.completer.isCompleted) {
        job.completer.completeError(error);
      }
    }
    for (final worker in _workers) {
      worker.dispose();
    }
    _workers.clear();
  }
}

void _wordCountWorkerEntryPoint(SendPort readyPort) {
  final requestPort = ReceivePort();
  readyPort.send(requestPort.sendPort);
  requestPort.listen((dynamic message) {
    if (message is! List<Object?> || message.length < 4) {
      return;
    }
    final responsePort = message[0] as SendPort;
    try {
      final content = message[2] as String;
      final mode = WordCountMode.values[message[3] as int];
      final count = ContentManager.calculateWordCount(content, mode: mode);
      responsePort.send(<Object?>[count, null]);
    } catch (error) {
      responsePort.send(<Object?>[null, error.toString()]);
    }
  });
}

class _QueuedJob {
  const _QueuedJob({
    required this.id,
    required this.content,
    required this.modeIndex,
    required this.completer,
  });

  final int id;
  final String content;
  final int modeIndex;
  final Completer<int> completer;
}

class _WorkerHandle {
  _WorkerHandle({
    required this.isolate,
    required this.sendPort,
    required this.errorPort,
  });

  final Isolate isolate;
  final SendPort sendPort;
  final ReceivePort errorPort;
  ReceivePort? responsePort;
  bool isBusy = false;

  void dispose() {
    responsePort?.close();
    errorPort.close();
    isolate.kill(priority: Isolate.immediate);
  }
}
