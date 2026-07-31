import "../bin/settings_manager.dart";
import "word_count_worker_pool_stub.dart"
    if (dart.library.io) "word_count_worker_pool_io.dart"
    as implementation;

/// A bounded, long-lived worker pool used by the word-count service.
class WordCountWorkerPool {
  WordCountWorkerPool({int size = 2})
    : _delegate = implementation.WordCountWorkerPool(size: size);

  final implementation.WordCountWorkerPool _delegate;

  Future<int> calculate(String content, WordCountMode mode) {
    return _delegate.calculate(content, mode.index);
  }

  void dispose() => _delegate.dispose();
}
