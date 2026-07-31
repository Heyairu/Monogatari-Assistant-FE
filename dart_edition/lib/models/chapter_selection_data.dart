import "package:freezed_annotation/freezed_annotation.dart";

import "../bin/settings_manager.dart";
import "../services/word_count_service.dart";

part "chapter_selection_data.freezed.dart";

int _generateChapterSelectionId() {
  return DateTime.now().microsecondsSinceEpoch;
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
    WordCountService.instance.clearChapter(chapterUUID);
  }

  static void pruneWordCountCacheToChapterIds(Set<String> activeChapterIds) {
    WordCountService.instance.pruneToChapterIds(activeChapterIds);
  }

  static void clearAllWordCountCache() {
    WordCountService.instance.clear();
  }

  static int get debugWordCountCacheEntryCount =>
      WordCountService.instance.debugCacheEntryCount;

  /// Returns only a current cached value. Missing/pending revisions never scan
  /// chapter content synchronously on the UI isolate.
  int getWordCount(WordCountMode mode) {
    return WordCountService.instance.cachedCount(chapterUUID, mode) ?? 0;
  }

  void updateCachedWordCount(int count, WordCountMode mode) {
    WordCountService.instance.storeCount(
      chapterId: chapterUUID,
      content: chapterContent,
      mode: mode,
      count: count,
    );
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
