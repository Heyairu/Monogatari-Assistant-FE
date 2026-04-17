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

  int getWordCount(WordCountMode mode) {
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
    return count;
  }

  void updateCachedWordCount(int count, WordCountMode mode) {
    final key = _WordCountCacheKey(
      chapterUUID: chapterUUID,
      mode: mode,
      chapterContent: chapterContent,
    );
    _wordCountCache[key] = count;
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
