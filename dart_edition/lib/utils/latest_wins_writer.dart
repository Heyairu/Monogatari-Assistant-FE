import "dart:async";
import "dart:io";

typedef AsyncTextWrite = Future<void> Function(String content);

/// Debounces snapshots and serializes writes so an older payload can never
/// finish after (and overwrite) a newer payload.
class LatestWinsWriter {
  LatestWinsWriter({
    required AsyncTextWrite write,
    this.debounce = const Duration(milliseconds: 600),
  }) : _write = write;

  final AsyncTextWrite _write;
  final Duration debounce;
  Timer? _timer;
  String Function()? _latestSnapshot;
  Future<void>? _drainFuture;
  int _requestedRevision = 0;
  int _writtenRevision = 0;
  bool _closed = false;

  void schedule(String Function() createSnapshot, {bool immediate = false}) {
    if (_closed) {
      return;
    }
    _latestSnapshot = createSnapshot;
    _requestedRevision++;
    _timer?.cancel();
    _timer = null;
    if (immediate) {
      unawaited(flush());
    } else {
      _timer = Timer(debounce, () {
        _timer = null;
        unawaited(flush());
      });
    }
  }

  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    final running = _drainFuture;
    if (running != null) {
      return running.then((_) {
        if (_writtenRevision < _requestedRevision) {
          return flush();
        }
      });
    }
    if (_latestSnapshot == null || _writtenRevision >= _requestedRevision) {
      return Future<void>.value();
    }

    final future = _drain();
    _drainFuture = future;
    return future.whenComplete(() {
      if (identical(_drainFuture, future)) {
        _drainFuture = null;
      }
    });
  }

  Future<void> _drain() async {
    while (_writtenRevision < _requestedRevision) {
      final revision = _requestedRevision;
      final snapshot = _latestSnapshot!();
      await _write(snapshot);
      _writtenRevision = revision;
    }
  }

  Future<void> close() {
    _closed = true;
    return flush();
  }
}

/// Writes a complete file through a sibling temporary file and atomic rename.
Future<void> writeTextAtomically(File target, String content) async {
  await target.parent.create(recursive: true);
  final temp = File("${target.path}.tmp");
  try {
    await temp.writeAsString(content, flush: true);
    await temp.rename(target.path);
  } catch (_) {
    if (await temp.exists()) {
      await temp.delete();
    }
    rethrow;
  }
}
