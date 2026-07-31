import "dart:async";
import "dart:collection";

import "package:flutter/foundation.dart";

import "../bin/settings_manager.dart";
import "word_count_worker_pool.dart";

typedef WordCountCalculator =
    Future<int> Function(String content, WordCountMode mode);

class WordCountChapterInput {
  const WordCountChapterInput({required this.chapterId, required this.content});

  final String chapterId;
  final String content;
}

class WordCountLookup {
  const WordCountLookup({
    required this.count,
    required this.hasValue,
    required this.isPending,
  });

  final int count;
  final bool hasValue;
  final bool isPending;
}

/// The sole owner of chapter word-count computation and caching.
///
/// Cache reads are O(1). A chapter never falls back to a synchronous scan when
/// its current revision is pending. Requests for the same chapter/mode are
/// coalesced so a busy worker only receives the newest revision next.
class WordCountService extends ChangeNotifier {
  WordCountService({WordCountCalculator? calculator, int maxConcurrent = 2})
    : _maxConcurrent = maxConcurrent < 1 ? 1 : maxConcurrent,
      _pool = calculator == null
          ? WordCountWorkerPool(size: maxConcurrent)
          : null,
      _calculator = calculator;

  static final WordCountService instance = WordCountService();

  final int _maxConcurrent;
  final WordCountWorkerPool? _pool;
  final WordCountCalculator? _calculator;
  final Map<String, _ContentRevision> _chapterRevisions =
      <String, _ContentRevision>{};
  final Map<_WordCountKey, _CacheEntry> _cache = <_WordCountKey, _CacheEntry>{};
  final Map<_WordCountKey, _PendingEntry> _pending =
      <_WordCountKey, _PendingEntry>{};
  final LinkedHashSet<_WordCountKey> _queue = LinkedHashSet<_WordCountKey>();
  final Set<_WordCountKey> _runningKeys = <_WordCountKey>{};
  final Map<String, int> _activeRevisions = <String, int>{};
  WordCountMode _activeMode = WordCountMode.characters;
  int _running = 0;
  int _total = 0;
  bool _disposed = false;

  int get total => _total;
  int get debugCacheEntryCount => _cache.length;
  int get debugRunningCount => _running;
  int get debugQueuedCount => _queue.length;

  WordCountLookup lookup(String chapterId, WordCountMode mode) {
    final key = _WordCountKey(chapterId, mode);
    final revision = _chapterRevisions[chapterId]?.revision;
    final cached = _cache[key];
    final hasCurrent = revision != null && cached?.revision == revision;
    return WordCountLookup(
      count: hasCurrent ? cached!.count : 0,
      hasValue: hasCurrent,
      isPending: !hasCurrent && _pending.containsKey(key),
    );
  }

  int? cachedCount(String chapterId, WordCountMode mode) {
    final lookupResult = lookup(chapterId, mode);
    return lookupResult.hasValue ? lookupResult.count : null;
  }

  WordCountLookup observeChapter({
    required String chapterId,
    required String content,
    required WordCountMode mode,
  }) {
    if (_disposed || chapterId.isEmpty) {
      return const WordCountLookup(count: 0, hasValue: false, isPending: false);
    }
    final revision = _revisionFor(chapterId, content);
    final key = _WordCountKey(chapterId, mode);
    final cached = _cache[key];
    if (cached?.revision == revision) {
      return WordCountLookup(
        count: cached!.count,
        hasValue: true,
        isPending: false,
      );
    }
    _schedule(key, content, revision);
    return const WordCountLookup(count: 0, hasValue: false, isPending: true);
  }

  void synchronizeChapters(
    Iterable<WordCountChapterInput> chapters,
    WordCountMode mode,
  ) {
    if (_disposed) {
      return;
    }

    _activeMode = mode;
    final nextActive = <String, int>{};
    var nextTotal = 0;
    for (final chapter in chapters) {
      if (chapter.chapterId.isEmpty) {
        continue;
      }
      final revision = _revisionFor(chapter.chapterId, chapter.content);
      nextActive[chapter.chapterId] = revision;
      final key = _WordCountKey(chapter.chapterId, mode);
      final cached = _cache[key];
      if (cached?.revision == revision) {
        nextTotal += cached!.count;
      } else {
        _schedule(key, chapter.content, revision);
      }
    }

    _activeRevisions
      ..clear()
      ..addAll(nextActive);
    final activeIds = nextActive.keys.toSet();
    _chapterRevisions.removeWhere((id, _) => !activeIds.contains(id));
    _cache.removeWhere((key, _) => !activeIds.contains(key.chapterId));
    _pending.removeWhere((key, _) => !activeIds.contains(key.chapterId));
    _queue.removeWhere((key) => !activeIds.contains(key.chapterId));

    if (_total != nextTotal) {
      _total = nextTotal;
      notifyListeners();
    }
    _drain();
  }

  void storeCount({
    required String chapterId,
    required String content,
    required WordCountMode mode,
    required int count,
  }) {
    final revision = _revisionFor(chapterId, content);
    _applyResult(_WordCountKey(chapterId, mode), revision, count);
  }

  void clearChapter(String chapterId) {
    _chapterRevisions.remove(chapterId);
    _activeRevisions.remove(chapterId);
    _cache.removeWhere((key, _) => key.chapterId == chapterId);
    _pending.removeWhere((key, _) => key.chapterId == chapterId);
    _queue.removeWhere((key) => key.chapterId == chapterId);
  }

  void pruneToChapterIds(Set<String> chapterIds) {
    _chapterRevisions.removeWhere((id, _) => !chapterIds.contains(id));
    _activeRevisions.removeWhere((id, _) => !chapterIds.contains(id));
    _cache.removeWhere((key, _) => !chapterIds.contains(key.chapterId));
    _pending.removeWhere((key, _) => !chapterIds.contains(key.chapterId));
    _queue.removeWhere((key) => !chapterIds.contains(key.chapterId));
  }

  void clear() {
    _chapterRevisions.clear();
    _activeRevisions.clear();
    _cache.clear();
    _pending.clear();
    _queue.clear();
    if (_total != 0) {
      _total = 0;
      notifyListeners();
    }
  }

  int _revisionFor(String chapterId, String content) {
    final previous = _chapterRevisions[chapterId];
    if (previous != null &&
        (identical(previous.content, content) || previous.content == content)) {
      return previous.revision;
    }
    final revision = (previous?.revision ?? 0) + 1;
    _chapterRevisions[chapterId] = _ContentRevision(content, revision);
    return revision;
  }

  void _schedule(_WordCountKey key, String content, int revision) {
    final existing = _pending[key];
    if (existing != null && existing.revision == revision) {
      return;
    }
    _pending[key] = _PendingEntry(content, revision);
    _queue.add(key);
    _drain();
  }

  void _drain() {
    while (!_disposed && _running < _maxConcurrent && _queue.isNotEmpty) {
      final key = _queue.first;
      _queue.remove(key);
      if (_runningKeys.contains(key)) {
        continue;
      }
      final pending = _pending[key];
      if (pending == null || pending.isRunning) {
        continue;
      }
      pending.isRunning = true;
      _runningKeys.add(key);
      final capturedRevision = pending.revision;
      final capturedContent = pending.content;
      _running++;
      final calculator = _calculator ?? _pool!.calculate;
      unawaited(
        calculator(capturedContent, key.mode).then(
          (count) => _complete(key, capturedRevision, count),
          onError: (Object error, StackTrace stackTrace) {
            debugPrint("Word-count worker failed: $error\n$stackTrace");
            _complete(key, capturedRevision, null);
          },
        ),
      );
    }
  }

  void _complete(_WordCountKey key, int revision, int? count) {
    _running--;
    _runningKeys.remove(key);
    final latest = _pending[key];
    if (latest != null && latest.revision == revision) {
      _pending.remove(key);
      if (count != null) {
        _applyResult(key, revision, count);
      }
    } else if (latest != null) {
      latest.isRunning = false;
      _queue.add(key);
    }
    _drain();
  }

  void _applyResult(_WordCountKey key, int revision, int count) {
    final currentRevision = _chapterRevisions[key.chapterId]?.revision;
    if (currentRevision != revision) {
      return;
    }
    final previous = _cache[key];
    _cache[key] = _CacheEntry(revision, count);

    if (key.mode == _activeMode &&
        _activeRevisions[key.chapterId] == revision) {
      final previousCount = previous?.revision == revision
          ? previous!.count
          : 0;
      _total += count - previousCount;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _pool?.dispose();
    super.dispose();
  }
}

class _WordCountKey {
  const _WordCountKey(this.chapterId, this.mode);

  final String chapterId;
  final WordCountMode mode;

  @override
  bool operator ==(Object other) =>
      other is _WordCountKey &&
      other.chapterId == chapterId &&
      other.mode == mode;

  @override
  int get hashCode => Object.hash(chapterId, mode);
}

class _ContentRevision {
  const _ContentRevision(this.content, this.revision);

  final String content;
  final int revision;
}

class _CacheEntry {
  const _CacheEntry(this.revision, this.count);

  final int revision;
  final int count;
}

class _PendingEntry {
  _PendingEntry(this.content, this.revision);

  final String content;
  final int revision;
  bool isRunning = false;
}
