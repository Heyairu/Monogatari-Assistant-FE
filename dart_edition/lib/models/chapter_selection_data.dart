import "package:freezed_annotation/freezed_annotation.dart";

import "../bin/settings_manager.dart";
import "../services/word_count_service.dart";

part "chapter_selection_data.freezed.dart";

/// Chapter folders are stored as the direct children of this synthetic root.
/// The root is deliberately not shown in the UI or persisted as a user folder.
abstract final class ChapterTreeSchema {
  static const int currentVersion = 3;
  static const String hiddenRootId = "chapter-tree-root";

  /// Central upgrade seam for future chapter-tree formats.
  ///
  /// Version 0 is the historical flat Segment/Chapter representation. Version
  /// 1 treats segments as folders below a hidden root. Version 2 adds recursive
  /// child folders. Version 3 preserves a mixed chapter/folder order per folder.
  static List<SegmentData> upgrade({
    required int sourceVersion,
    required List<SegmentData> segments,
  }) {
    switch (sourceVersion) {
      case 0:
      case 1:
      case 2:
      case currentVersion:
        return _snapshot(segments);
      default:
        // Preserve data from newer schemas. A future migration can be inserted
        // here without coupling the chapter tree to the project-file version.
        return _snapshot(segments);
    }
  }

  static List<SegmentData> _snapshot(List<SegmentData> segments) {
    return List<SegmentData>.unmodifiable(
      segments
          .map(
            (segment) => segment.copyWith(
              chapters: List<ChapterData>.unmodifiable(segment.chapters),
              childSegments: _snapshot(segment.childSegments),
              childNodeOrder: List<String>.unmodifiable(
                segment.resolvedChildNodeOrder,
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class ChapterLocation {
  final SegmentData folder;
  final ChapterData chapter;
  final int chapterIndex;

  const ChapterLocation({
    required this.folder,
    required this.chapter,
    required this.chapterIndex,
  });
}

/// Read-only traversal helpers shared by the editor, persistence and UI layers.
abstract final class ChapterTree {
  static Iterable<SegmentData> foldersDepthFirst(
    Iterable<SegmentData> roots,
  ) sync* {
    for (final folder in roots) {
      yield folder;
      yield* foldersDepthFirst(folder.childSegments);
    }
  }

  static Iterable<ChapterLocation> chaptersDepthFirst(
    Iterable<SegmentData> roots,
  ) sync* {
    for (final folder in roots) {
      final chapterIndexes = {
        for (var index = 0; index < folder.chapters.length; index++)
          folder.chapters[index].chapterUUID: index,
      };
      final childrenByID = {
        for (final child in folder.childSegments) child.segmentUUID: child,
      };
      for (final id in folder.resolvedChildNodeOrder) {
        final chapterIndex = chapterIndexes[id];
        if (chapterIndex != null) {
          yield ChapterLocation(
            folder: folder,
            chapter: folder.chapters[chapterIndex],
            chapterIndex: chapterIndex,
          );
          continue;
        }
        final child = childrenByID[id];
        if (child != null) yield* chaptersDepthFirst([child]);
      }
    }
  }

  static int chapterCount(Iterable<SegmentData> roots) {
    return chaptersDepthFirst(roots).length;
  }

  static SegmentData? findFolder(Iterable<SegmentData> roots, String folderId) {
    for (final folder in foldersDepthFirst(roots)) {
      if (folder.segmentUUID == folderId) return folder;
    }
    return null;
  }

  static SegmentData? findParentFolder(
    Iterable<SegmentData> roots,
    String folderId,
  ) {
    for (final folder in roots) {
      if (folder.childSegments.any((child) => child.segmentUUID == folderId)) {
        return folder;
      }
      final parent = findParentFolder(folder.childSegments, folderId);
      if (parent != null) return parent;
    }
    return null;
  }

  static ChapterLocation? findChapter(
    Iterable<SegmentData> roots, {
    String? folderId,
    required String chapterId,
  }) {
    for (final location in chaptersDepthFirst(roots)) {
      if (folderId != null && location.folder.segmentUUID != folderId) {
        continue;
      }
      if (location.chapter.chapterUUID == chapterId) return location;
    }
    return null;
  }

  static ChapterLocation? firstChapter(Iterable<SegmentData> roots) {
    final iterator = chaptersDepthFirst(roots).iterator;
    return iterator.moveNext() ? iterator.current : null;
  }

  static bool containsFolder(SegmentData source, String targetFolderId) {
    if (source.segmentUUID == targetFolderId) return true;
    return source.childSegments.any(
      (child) => containsFolder(child, targetFolderId),
    );
  }
}

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
    @Default(<SegmentData>[]) List<SegmentData> childSegments,
    @Default(<String>[]) List<String> childNodeOrder,
    required String segmentUUID,
  }) = _SegmentData;

  factory SegmentData({
    String segmentName = "",
    List<ChapterData>? chapters,
    List<SegmentData>? childSegments,
    List<String>? childNodeOrder,
    String? segmentUUID,
  }) {
    final resolvedUUID = segmentUUID?.trim().isNotEmpty == true
        ? segmentUUID!.trim()
        : _generateChapterSelectionId().toString();

    return SegmentData.raw(
      segmentName: segmentName,
      chapters: chapters ?? const <ChapterData>[],
      childSegments: childSegments ?? const <SegmentData>[],
      childNodeOrder: childNodeOrder ?? const <String>[],
      segmentUUID: resolvedUUID,
    );
  }

  String get id => segmentUUID;

  /// Returns a complete, duplicate-free order of this folder's direct items.
  /// Older files have no explicit order, so chapters retain their historical
  /// position before child folders until the project is saved in schema v3.
  List<String> get resolvedChildNodeOrder {
    final validIDs = <String>{
      ...chapters.map((chapter) => chapter.chapterUUID),
      ...childSegments.map((folder) => folder.segmentUUID),
    };
    final seen = <String>{};
    final result = <String>[];
    for (final id in childNodeOrder) {
      if (validIDs.contains(id) && seen.add(id)) result.add(id);
    }
    for (final chapter in chapters) {
      if (seen.add(chapter.chapterUUID)) result.add(chapter.chapterUUID);
    }
    for (final folder in childSegments) {
      if (seen.add(folder.segmentUUID)) result.add(folder.segmentUUID);
    }
    return List<String>.unmodifiable(result);
  }
}
