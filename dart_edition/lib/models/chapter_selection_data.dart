import "package:freezed_annotation/freezed_annotation.dart";

import "../bin/content_manager.dart";
import "../bin/settings_manager.dart";

part "chapter_selection_data.freezed.dart";

int _generateChapterSelectionId() {
  return DateTime.now().microsecondsSinceEpoch;
}

class _WordCountCacheKey {
  final String chapterUUID;
  final WordCountMode mode;
  final String chapterContent;

  const _WordCountCacheKey({
    required this.chapterUUID,
    required this.mode,
    required this.chapterContent,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _WordCountCacheKey &&
            other.chapterUUID == chapterUUID &&
            other.mode == mode &&
            other.chapterContent == chapterContent;
  }

  @override
  int get hashCode => Object.hash(chapterUUID, mode, chapterContent);
}

final Map<_WordCountCacheKey, int> _wordCountCache =
    <_WordCountCacheKey, int>{};

const int _maxWordCountCacheEntries = 4096;

void _removeChapterModeCacheEntries({
  required String chapterUUID,
  required WordCountMode mode,
  String? keepContent,
}) {
  _wordCountCache.removeWhere((key, _) {
    if (key.chapterUUID != chapterUUID || key.mode != mode) {
      return false;
    }
    if (keepContent != null && key.chapterContent == keepContent) {
      return false;
    }
    return true;
  });
}

void _removeChapterCacheEntries(String chapterUUID) {
  _wordCountCache.removeWhere((key, _) => key.chapterUUID == chapterUUID);
}

void _pruneWordCountCacheToChapterIds(Set<String> activeChapterIds) {
  if (activeChapterIds.isEmpty) {
    _wordCountCache.clear();
    return;
  }

  _wordCountCache.removeWhere(
    (key, _) => !activeChapterIds.contains(key.chapterUUID),
  );
}

void _enforceWordCountCacheLimit() {
  while (_wordCountCache.length > _maxWordCountCacheEntries) {
    final firstKey = _wordCountCache.keys.first;
    _wordCountCache.remove(firstKey);
  }
}

@freezed
class ChapterData with _$ChapterData {
  const ChapterData._();

  const factory ChapterData.raw({
    @Default("") String chapterName,
    @Default("") String chapterContent,
    required String chapterUUID,
  }) = _ChapterData;

  factory ChapterData({
    String chapterName = "",
    String chapterContent = "",
    String? chapterUUID,
  }) {
    final resolvedUUID = chapterUUID?.trim().isNotEmpty == true
        ? chapterUUID!.trim()
        : _generateChapterSelectionId().toString();

    return ChapterData.raw(
      chapterName: chapterName,
      chapterContent: chapterContent,
      chapterUUID: resolvedUUID,
    );
  }

  String get id => chapterUUID;

  static void clearWordCountCacheForChapter(String chapterUUID) {
    _removeChapterCacheEntries(chapterUUID);
  }

  static void pruneWordCountCacheToChapterIds(Set<String> activeChapterIds) {
    _pruneWordCountCacheToChapterIds(activeChapterIds);
    _enforceWordCountCacheLimit();
  }

  static void clearAllWordCountCache() {
    _wordCountCache.clear();
  }

  static int get debugWordCountCacheEntryCount => _wordCountCache.length;

  int getWordCount(WordCountMode mode) {
    // Keep only one cache entry per chapter+mode to avoid unbounded growth
    // when content changes repeatedly.
    _removeChapterModeCacheEntries(
      chapterUUID: chapterUUID,
      mode: mode,
      keepContent: chapterContent,
    );

    final key = _WordCountCacheKey(
      chapterUUID: chapterUUID,
      mode: mode,
      chapterContent: chapterContent,
    );
    final cached = _wordCountCache[key];
    if (cached != null) {
      return cached;
    }

    final count = ContentManager.calculateWordCount(chapterContent, mode: mode);
    _wordCountCache[key] = count;
    _enforceWordCountCacheLimit();
    return count;
  }

  void updateCachedWordCount(int count, WordCountMode mode) {
    _removeChapterModeCacheEntries(
      chapterUUID: chapterUUID,
      mode: mode,
      keepContent: chapterContent,
    );

    final key = _WordCountCacheKey(
      chapterUUID: chapterUUID,
      mode: mode,
      chapterContent: chapterContent,
    );
    _wordCountCache[key] = count;
    _enforceWordCountCacheLimit();
  }
}

@freezed
class SegmentData with _$SegmentData {
  const SegmentData._();

  const factory SegmentData.raw({
    @Default("") String segmentName,
    @Default(<ChapterData>[]) List<ChapterData> chapters,
    required String segmentUUID,
  }) = _SegmentData;

  factory SegmentData({
    String segmentName = "",
    List<ChapterData>? chapters,
    String? segmentUUID,
  }) {
    final resolvedUUID = segmentUUID?.trim().isNotEmpty == true
        ? segmentUUID!.trim()
        : _generateChapterSelectionId().toString();

    return SegmentData.raw(
      segmentName: segmentName,
      chapters: chapters ?? const <ChapterData>[],
      segmentUUID: resolvedUUID,
    );
  }

  String get id => segmentUUID;
}
