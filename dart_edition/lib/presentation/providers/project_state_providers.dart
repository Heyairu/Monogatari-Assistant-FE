import "dart:async";
import "dart:collection";
import "dart:convert";
import "dart:io";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:path_provider/path_provider.dart";

import "../../bin/settings_manager.dart";
import "../../models/character_data.dart" as character_model;
import "../../models/glossary_data.dart" as glossary_model;
import "../../models/base_info_data.dart" as base_info_module;
import "../../models/chapter_selection_data.dart" as chapter_module;
import "../../models/outline_data.dart" as outline_module;
import "../../models/plan_data.dart" as plan_module;
import "../../models/project_data.dart";
import "../../models/project_file.dart";
import "../../models/timeline_data.dart";
import "../../models/world_settings_data.dart";
import "project_snapshot_utils.dart";

const Object _editorSelectionUnset = Object();

class EditorSelectionState {
  final String? selectedSegID;
  final String? selectedChapID;
  final int cursorOffset;

  const EditorSelectionState({
    this.selectedSegID,
    this.selectedChapID,
    this.cursorOffset = 0,
  });

  EditorSelectionState copyWith({
    Object? selectedSegID = _editorSelectionUnset,
    Object? selectedChapID = _editorSelectionUnset,
    int? cursorOffset,
  }) {
    return EditorSelectionState(
      selectedSegID: selectedSegID == _editorSelectionUnset
          ? this.selectedSegID
          : selectedSegID as String?,
      selectedChapID: selectedChapID == _editorSelectionUnset
          ? this.selectedChapID
          : selectedChapID as String?,
      cursorOffset: cursorOffset ?? this.cursorOffset,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is EditorSelectionState &&
        other.selectedSegID == selectedSegID &&
        other.selectedChapID == selectedChapID &&
        other.cursorOffset == cursorOffset;
  }

  @override
  int get hashCode => Object.hash(selectedSegID, selectedChapID, cursorOffset);
}

class BaseInfoDataNotifier extends Notifier<base_info_module.BaseInfoData> {
  base_info_module.BaseInfoData _createSnapshot(
    base_info_module.BaseInfoData value,
  ) {
    return snapshotBaseInfoData(value);
  }

  void _setIfChanged(base_info_module.BaseInfoData value) {
    final snapshot = _createSnapshot(value);
    if (snapshot == state) {
      return;
    }
    state = snapshot;
  }

  @override
  base_info_module.BaseInfoData build() {
    return _createSnapshot(ProjectData.empty().baseInfoData);
  }

  void setBaseInfoData(base_info_module.BaseInfoData value) {
    _setIfChanged(value);
  }

  void updateBaseInfoData(
    base_info_module.BaseInfoData Function(
      base_info_module.BaseInfoData current,
    )
    update,
  ) {
    _setIfChanged(update(state));
  }

  void setBookName(String value) {
    updateBaseInfoData((current) => current.copyWith(bookName: value));
  }

  void setAuthor(String value) {
    updateBaseInfoData((current) => current.copyWith(author: value));
  }

  void setPurpose(String value) {
    updateBaseInfoData((current) => current.copyWith(purpose: value));
  }

  void setToRecap(String value) {
    updateBaseInfoData((current) => current.copyWith(toRecap: value));
  }

  void setStoryType(String value) {
    updateBaseInfoData((current) => current.copyWith(storyType: value));
  }

  void setIntro(String value) {
    updateBaseInfoData((current) => current.copyWith(intro: value));
  }

  void addTag(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || state.tags.contains(trimmed)) {
      return;
    }
    updateBaseInfoData(
      (current) => current.copyWith(tags: [...current.tags, trimmed]),
    );
  }

  void removeTagAt(int index) {
    if (index < 0 || index >= state.tags.length) {
      return;
    }
    final nextTags = [...state.tags]..removeAt(index);
    updateBaseInfoData((current) => current.copyWith(tags: nextTags));
  }

  void recalculateNowWords({
    required String contentText,
    required WordCountMode mode,
  }) {
    updateBaseInfoData(
      (current) => current.withRecalculatedNowWords(contentText, mode: mode),
    );
  }

  void setNowWords(int count) {
    updateBaseInfoData((current) => current.copyWith(nowWords: count));
  }
}

final baseInfoDataProvider =
    NotifierProvider<BaseInfoDataNotifier, base_info_module.BaseInfoData>(
      BaseInfoDataNotifier.new,
    );

class SegmentsDataNotifier extends Notifier<List<chapter_module.SegmentData>> {
  List<String> _withoutNode(List<String> order, String nodeID) =>
      order.where((id) => id != nodeID).toList(growable: false);

  List<String> _insertNodeRelative({
    required List<String> order,
    required String nodeID,
    required String targetID,
    required String position,
  }) {
    final next = _withoutNode(order, nodeID).toList();
    final targetIndex = next.indexOf(targetID);
    if (targetIndex < 0) return [...next, nodeID];
    next.insert(position == "before" ? targetIndex : targetIndex + 1, nodeID);
    return next;
  }

  List<chapter_module.SegmentData> _createSnapshot(
    List<chapter_module.SegmentData> source,
  ) {
    return snapshotSegmentsData(source);
  }

  void _setIfChanged(List<chapter_module.SegmentData> value) {
    final snapshot = _createSnapshot(value);
    if (snapshot == state) {
      return;
    }

    final activeChapterIds = _collectChapterIds(snapshot);
    chapter_module.ChapterData.pruneWordCountCacheToChapterIds(
      activeChapterIds,
    );
    state = snapshot;
  }

  Set<String> _collectChapterIds(List<chapter_module.SegmentData> segments) {
    return chapter_module.ChapterTree.chaptersDepthFirst(
      segments,
    ).map((location) => location.chapter.chapterUUID).toSet();
  }

  ({List<chapter_module.SegmentData> nodes, bool changed})
  _updateFolderRecursive(
    String folderID,
    List<chapter_module.SegmentData> nodes,
    chapter_module.SegmentData Function(chapter_module.SegmentData folder)
    update,
  ) {
    for (var index = 0; index < nodes.length; index++) {
      final folder = nodes[index];
      if (folder.segmentUUID == folderID) {
        final updated = update(folder);
        if (updated == folder) return (nodes: nodes, changed: false);
        final next = [...nodes];
        next[index] = updated;
        return (nodes: next, changed: true);
      }

      final childResult = _updateFolderRecursive(
        folderID,
        folder.childSegments,
        update,
      );
      if (childResult.changed) {
        final next = [...nodes];
        next[index] = folder.copyWith(childSegments: childResult.nodes);
        return (nodes: next, changed: true);
      }
    }
    return (nodes: nodes, changed: false);
  }

  ({List<chapter_module.SegmentData> nodes, bool removed})
  _removeFolderRecursive(
    String folderID,
    List<chapter_module.SegmentData> nodes,
  ) {
    for (var index = 0; index < nodes.length; index++) {
      final folder = nodes[index];
      if (folder.segmentUUID == folderID) {
        return (nodes: [...nodes]..removeAt(index), removed: true);
      }
      final childResult = _removeFolderRecursive(
        folderID,
        folder.childSegments,
      );
      if (childResult.removed) {
        final next = [...nodes];
        next[index] = folder.copyWith(
          childSegments: childResult.nodes,
          childNodeOrder: _withoutNode(folder.resolvedChildNodeOrder, folderID),
        );
        return (nodes: next, removed: true);
      }
    }
    return (nodes: nodes, removed: false);
  }

  ({List<chapter_module.SegmentData> nodes, bool inserted})
  _insertFolderByPosition({
    required List<chapter_module.SegmentData> nodes,
    required String targetFolderID,
    required String position,
    required chapter_module.SegmentData sourceFolder,
  }) {
    for (var index = 0; index < nodes.length; index++) {
      final folder = nodes[index];
      if (folder.segmentUUID == targetFolderID) {
        if (position == "child") {
          final next = [...nodes];
          next[index] = folder.copyWith(
            childSegments: [...folder.childSegments, sourceFolder],
            childNodeOrder: [
              ...folder.resolvedChildNodeOrder,
              sourceFolder.segmentUUID,
            ],
          );
          return (nodes: next, inserted: true);
        }
        if (position == "before" || position == "after") {
          final next = [...nodes]
            ..insert(position == "before" ? index : index + 1, sourceFolder);
          return (nodes: next, inserted: true);
        }
      }

      final childResult = _insertFolderByPosition(
        nodes: folder.childSegments,
        targetFolderID: targetFolderID,
        position: position,
        sourceFolder: sourceFolder,
      );
      if (childResult.inserted) {
        final next = [...nodes];
        next[index] = folder.copyWith(childSegments: childResult.nodes);
        return (nodes: next, inserted: true);
      }
    }
    return (nodes: nodes, inserted: false);
  }

  @override
  List<chapter_module.SegmentData> build() {
    return _createSnapshot(ProjectData.empty().segmentsData);
  }

  void setSegmentsData(List<chapter_module.SegmentData> value) {
    _setIfChanged(value);
  }

  void updateSegmentsData(
    List<chapter_module.SegmentData> Function(
      List<chapter_module.SegmentData> current,
    )
    update,
  ) {
    setSegmentsData(update(state));
  }

  void addSegment(chapter_module.SegmentData segment) {
    updateSegmentsData((current) => [...current, segment]);
  }

  chapter_module.SegmentData? addFolder({
    required String name,
    String? parentFolderID,
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return null;
    final folder = chapter_module.SegmentData(
      segmentName: trimmedName,
      chapters: [
        chapter_module.ChapterData(chapterName: "章節 1", chapterContent: ""),
      ],
    );
    if (parentFolderID == null) {
      addSegment(folder);
      return folder;
    }
    final result = _updateFolderRecursive(
      parentFolderID,
      state,
      (parent) => parent.copyWith(
        childSegments: [...parent.childSegments, folder],
        childNodeOrder: [...parent.resolvedChildNodeOrder, folder.segmentUUID],
      ),
    );
    if (!result.changed) return null;
    setSegmentsData(result.nodes);
    return folder;
  }

  void insertSegmentAt(int index, chapter_module.SegmentData segment) {
    updateSegmentsData((current) {
      final next = [...current];
      final insertIndex = index.clamp(0, next.length);
      next.insert(insertIndex, segment);
      return next;
    });
  }

  bool removeSegmentById(String segmentID) {
    final folder = chapter_module.ChapterTree.findFolder(state, segmentID);
    if (folder == null) return false;
    final remaining =
        chapter_module.ChapterTree.chapterCount(state) -
        chapter_module.ChapterTree.chapterCount([folder]);
    if (remaining < 1) return false;
    final result = _removeFolderRecursive(segmentID, state);
    if (!result.removed) return false;
    setSegmentsData(result.nodes);
    return true;
  }

  void renameSegment({required String segmentID, required String name}) {
    final result = _updateFolderRecursive(
      segmentID,
      state,
      (folder) => folder.copyWith(segmentName: name),
    );
    if (result.changed) setSegmentsData(result.nodes);
  }

  void moveSegment({required int fromIndex, required int toIndex}) {
    updateSegmentsData((current) {
      if (fromIndex < 0 || fromIndex >= current.length) {
        return current;
      }

      final normalizedTarget = toIndex.clamp(0, current.length - 1);
      if (fromIndex == normalizedTarget) {
        return current;
      }

      final next = [...current];
      final moving = next.removeAt(fromIndex);
      next.insert(normalizedTarget, moving);
      return next;
    });
  }

  void addChapter({
    required String segmentID,
    required chapter_module.ChapterData chapter,
  }) {
    final result = _updateFolderRecursive(
      segmentID,
      state,
      (folder) => folder.copyWith(
        chapters: [...folder.chapters, chapter],
        childNodeOrder: [...folder.resolvedChildNodeOrder, chapter.chapterUUID],
      ),
    );
    if (result.changed) setSegmentsData(result.nodes);
  }

  void insertChapter({
    required String segmentID,
    required int chapterIndex,
    required chapter_module.ChapterData chapter,
  }) {
    final result = _updateFolderRecursive(segmentID, state, (folder) {
      final chapters = [...folder.chapters];
      final insertIndex = chapterIndex.clamp(0, chapters.length);
      chapters.insert(insertIndex, chapter);
      final chapterOrder = folder.chapters
          .map((item) => item.chapterUUID)
          .toList();
      final relativeID = insertIndex < chapterOrder.length
          ? chapterOrder[insertIndex]
          : null;
      return folder.copyWith(
        chapters: chapters,
        childNodeOrder: relativeID == null
            ? [...folder.resolvedChildNodeOrder, chapter.chapterUUID]
            : _insertNodeRelative(
                order: folder.resolvedChildNodeOrder,
                nodeID: chapter.chapterUUID,
                targetID: relativeID,
                position: "before",
              ),
      );
    });
    if (result.changed) setSegmentsData(result.nodes);
  }

  void renameChapter({
    required String segmentID,
    required String chapterID,
    required String name,
  }) {
    final result = _updateFolderRecursive(segmentID, state, (folder) {
      final chapterIndex = folder.chapters.indexWhere(
        (chapter) => chapter.chapterUUID == chapterID,
      );
      if (chapterIndex < 0) return folder;
      final chapters = [...folder.chapters];
      final target = chapters[chapterIndex];
      chapters[chapterIndex] = target.copyWith(chapterName: name);
      return folder.copyWith(chapters: chapters);
    });
    if (result.changed) setSegmentsData(result.nodes);
  }

  void updateChapterContent({
    required String segmentID,
    required String chapterID,
    required String content,
  }) {
    final result = _updateFolderRecursive(segmentID, state, (folder) {
      final chapterIndex = folder.chapters.indexWhere(
        (chapter) => chapter.chapterUUID == chapterID,
      );
      if (chapterIndex < 0) return folder;
      final chapters = [...folder.chapters];
      final target = chapters[chapterIndex];
      chapters[chapterIndex] = target.copyWith(chapterContent: content);
      return folder.copyWith(chapters: chapters);
    });
    if (result.changed) setSegmentsData(result.nodes);
  }

  void removeChapter({required String segmentID, required String chapterID}) {
    final folder = chapter_module.ChapterTree.findFolder(state, segmentID);
    if (folder == null || chapter_module.ChapterTree.chapterCount(state) <= 1) {
      return;
    }
    final chapters = folder.chapters
        .where((chapter) => chapter.chapterUUID != chapterID)
        .toList();
    if (chapters.length == folder.chapters.length) return;
    if (chapters.isEmpty && folder.childSegments.isEmpty) {
      final result = _removeFolderRecursive(segmentID, state);
      if (result.removed) setSegmentsData(result.nodes);
      return;
    }
    final result = _updateFolderRecursive(
      segmentID,
      state,
      (current) => current.copyWith(
        chapters: chapters,
        childNodeOrder: _withoutNode(current.resolvedChildNodeOrder, chapterID),
      ),
    );
    if (result.changed) setSegmentsData(result.nodes);
  }

  void moveChapterWithinSegment({
    required String segmentID,
    required int fromIndex,
    required int toIndex,
  }) {
    final result = _updateFolderRecursive(segmentID, state, (folder) {
      if (fromIndex < 0 || fromIndex >= folder.chapters.length) return folder;
      final normalizedTarget = toIndex.clamp(0, folder.chapters.length - 1);
      if (fromIndex == normalizedTarget) return folder;
      final chapters = [...folder.chapters];
      final moving = chapters.removeAt(fromIndex);
      chapters.insert(normalizedTarget, moving);
      final otherChapterIDs = chapters
          .where((chapter) => chapter.chapterUUID != moving.chapterUUID)
          .map((chapter) => chapter.chapterUUID)
          .toList();
      if (otherChapterIDs.isEmpty) return folder.copyWith(chapters: chapters);
      final targetID = normalizedTarget < otherChapterIDs.length
          ? otherChapterIDs[normalizedTarget]
          : otherChapterIDs.last;
      return folder.copyWith(
        chapters: chapters,
        childNodeOrder: _insertNodeRelative(
          order: folder.resolvedChildNodeOrder,
          nodeID: moving.chapterUUID,
          targetID: targetID,
          position: normalizedTarget < otherChapterIDs.length
              ? "before"
              : "after",
        ),
      );
    });
    if (result.changed) setSegmentsData(result.nodes);
  }

  void moveChapterToSegment({
    required String chapterID,
    required String targetSegmentID,
  }) {
    final source = chapter_module.ChapterTree.findChapter(
      state,
      chapterId: chapterID,
    );
    if (source == null || source.folder.segmentUUID == targetSegmentID) return;
    if (chapter_module.ChapterTree.findFolder(state, targetSegmentID) == null) {
      return;
    }
    var next = state;
    final sourceChapters = [...source.folder.chapters]
      ..removeAt(source.chapterIndex);
    if (sourceChapters.isEmpty && source.folder.childSegments.isEmpty) {
      next = _removeFolderRecursive(source.folder.segmentUUID, next).nodes;
    } else {
      next = _updateFolderRecursive(
        source.folder.segmentUUID,
        next,
        (folder) => folder.copyWith(
          chapters: sourceChapters,
          childNodeOrder: _withoutNode(
            folder.resolvedChildNodeOrder,
            chapterID,
          ),
        ),
      ).nodes;
    }
    final targetResult = _updateFolderRecursive(
      targetSegmentID,
      next,
      (folder) => folder.copyWith(
        chapters: [...folder.chapters, source.chapter],
        childNodeOrder: [...folder.resolvedChildNodeOrder, chapterID],
      ),
    );
    if (targetResult.changed) setSegmentsData(targetResult.nodes);
  }

  List<chapter_module.SegmentData> _detachChapterForMove(
    chapter_module.ChapterLocation source,
    List<chapter_module.SegmentData> nodes,
  ) {
    final sourceChapters = [...source.folder.chapters]
      ..removeWhere(
        (chapter) => chapter.chapterUUID == source.chapter.chapterUUID,
      );
    if (sourceChapters.isEmpty && source.folder.childSegments.isEmpty) {
      return _removeFolderRecursive(source.folder.segmentUUID, nodes).nodes;
    }
    return _updateFolderRecursive(
      source.folder.segmentUUID,
      nodes,
      (folder) => folder.copyWith(
        chapters: sourceChapters,
        childNodeOrder: _withoutNode(
          folder.resolvedChildNodeOrder,
          source.chapter.chapterUUID,
        ),
      ),
    ).nodes;
  }

  bool moveChapterRelativeToChapter({
    required String chapterID,
    required String targetChapterID,
    required String position,
  }) {
    if (chapterID == targetChapterID ||
        (position != "before" && position != "after")) {
      return false;
    }
    final source = chapter_module.ChapterTree.findChapter(
      state,
      chapterId: chapterID,
    );
    final target = chapter_module.ChapterTree.findChapter(
      state,
      chapterId: targetChapterID,
    );
    if (source == null || target == null) return false;

    final detached = _detachChapterForMove(source, state);
    final currentTarget = chapter_module.ChapterTree.findChapter(
      detached,
      chapterId: targetChapterID,
    );
    if (currentTarget == null) return false;
    final result = _updateFolderRecursive(
      currentTarget.folder.segmentUUID,
      detached,
      (folder) => folder.copyWith(
        chapters:
            folder.chapters.any((chapter) => chapter.chapterUUID == chapterID)
            ? folder.chapters
            : [...folder.chapters, source.chapter],
        childNodeOrder: _insertNodeRelative(
          order: folder.resolvedChildNodeOrder,
          nodeID: chapterID,
          targetID: targetChapterID,
          position: position,
        ),
      ),
    );
    if (!result.changed) return false;
    setSegmentsData(result.nodes);
    return true;
  }

  bool moveFolderRelativeToChapter({
    required String sourceFolderID,
    required String targetChapterID,
    required String position,
  }) {
    if (position != "before" && position != "after") return false;
    final source = chapter_module.ChapterTree.findFolder(state, sourceFolderID);
    final target = chapter_module.ChapterTree.findChapter(
      state,
      chapterId: targetChapterID,
    );
    if (source == null ||
        target == null ||
        chapter_module.ChapterTree.containsFolder(
          source,
          target.folder.segmentUUID,
        )) {
      return false;
    }
    final removed = _removeFolderRecursive(sourceFolderID, state);
    if (!removed.removed) return false;
    final currentTarget = chapter_module.ChapterTree.findChapter(
      removed.nodes,
      chapterId: targetChapterID,
    );
    if (currentTarget == null) return false;
    final result = _updateFolderRecursive(
      currentTarget.folder.segmentUUID,
      removed.nodes,
      (folder) => folder.copyWith(
        childSegments: [...folder.childSegments, source],
        childNodeOrder: _insertNodeRelative(
          order: folder.resolvedChildNodeOrder,
          nodeID: sourceFolderID,
          targetID: targetChapterID,
          position: position,
        ),
      ),
    );
    if (!result.changed) return false;
    setSegmentsData(result.nodes);
    return true;
  }

  bool moveChapterRelativeToFolder({
    required String chapterID,
    required String targetFolderID,
    required String position,
  }) {
    if (position != "before" && position != "after") return false;
    final source = chapter_module.ChapterTree.findChapter(
      state,
      chapterId: chapterID,
    );
    final targetParent = chapter_module.ChapterTree.findParentFolder(
      state,
      targetFolderID,
    );
    if (source == null || targetParent == null) return false;

    final detached = _detachChapterForMove(source, state);
    final currentParent = chapter_module.ChapterTree.findParentFolder(
      detached,
      targetFolderID,
    );
    if (currentParent == null) return false;
    final result = _updateFolderRecursive(
      currentParent.segmentUUID,
      detached,
      (folder) => folder.copyWith(
        chapters: [...folder.chapters, source.chapter],
        childNodeOrder: _insertNodeRelative(
          order: folder.resolvedChildNodeOrder,
          nodeID: chapterID,
          targetID: targetFolderID,
          position: position,
        ),
      ),
    );
    if (!result.changed) return false;
    setSegmentsData(result.nodes);
    return true;
  }

  bool moveFolder({
    required String sourceFolderID,
    required String targetFolderID,
    required String position,
  }) {
    if (sourceFolderID == targetFolderID) return false;
    final source = chapter_module.ChapterTree.findFolder(state, sourceFolderID);
    final targetParent = chapter_module.ChapterTree.findParentFolder(
      state,
      targetFolderID,
    );
    if (source == null ||
        chapter_module.ChapterTree.containsFolder(source, targetFolderID)) {
      return false;
    }
    final removed = _removeFolderRecursive(sourceFolderID, state);
    if (!removed.removed) return false;
    final inserted = _insertFolderByPosition(
      nodes: removed.nodes,
      targetFolderID: targetFolderID,
      position: position,
      sourceFolder: source,
    );
    if (!inserted.inserted) return false;
    var next = inserted.nodes;
    if (position != "child" && targetParent != null) {
      final ordered = _updateFolderRecursive(
        targetParent.segmentUUID,
        next,
        (folder) => folder.copyWith(
          childNodeOrder: _insertNodeRelative(
            order: folder.resolvedChildNodeOrder,
            nodeID: sourceFolderID,
            targetID: targetFolderID,
            position: position,
          ),
        ),
      );
      next = ordered.nodes;
    }
    setSegmentsData(next);
    return true;
  }

  bool moveFolderToRoot(String folderID) {
    final source = chapter_module.ChapterTree.findFolder(state, folderID);
    if (source == null) return false;
    final removed = _removeFolderRecursive(folderID, state);
    if (!removed.removed) return false;
    setSegmentsData([...removed.nodes, source]);
    return true;
  }
}

final segmentsDataProvider =
    NotifierProvider<SegmentsDataNotifier, List<chapter_module.SegmentData>>(
      SegmentsDataNotifier.new,
    );

class OutlineDataNotifier extends Notifier<List<outline_module.StorylineData>> {
  List<outline_module.StorylineData> _createSnapshot(
    List<outline_module.StorylineData> source,
  ) {
    return snapshotOutlineData(source);
  }

  @override
  List<outline_module.StorylineData> build() {
    return _createSnapshot(ProjectData.empty().outlineData);
  }

  void setOutlineData(
    List<outline_module.StorylineData> value, {
    bool synchronizeTimeline = true,
  }) {
    state = _createSnapshot(value);
    if (!synchronizeTimeline) return;
    final timeline = ref.read(timelineDocumentProvider);
    if (!timeline.grid.autoSortOutline) return;
    final aligned = TimelineOutlineOrder.alignTimelineToOutline(
      timeline,
      state,
    );
    ref
        .read(timelineDocumentProvider.notifier)
        .setDocument(aligned, synchronizeOutline: false);
  }

  void updateOutlineData(
    List<outline_module.StorylineData> Function(
      List<outline_module.StorylineData> current,
    )
    update,
  ) {
    setOutlineData(update(state));
  }
}

final outlineDataProvider =
    NotifierProvider<OutlineDataNotifier, List<outline_module.StorylineData>>(
      OutlineDataNotifier.new,
    );

class TimelineDocumentNotifier extends Notifier<TimelineDocumentData> {
  @override
  TimelineDocumentData build() {
    return snapshotTimelineDocument(TimelineDocumentData.initial());
  }

  void setDocument(
    TimelineDocumentData value, {
    bool synchronizeOutline = true,
  }) {
    final snapshot = snapshotTimelineDocument(value);
    if (snapshot == state) return;
    state = snapshot;
    if (!synchronizeOutline || !snapshot.grid.autoSortOutline) return;
    final outline = ref.read(outlineDataProvider);
    final sorted = TimelineOutlineOrder.sortOutlineByTimeline(
      outline,
      snapshot,
    );
    if (identical(sorted, outline)) return;
    ref
        .read(outlineDataProvider.notifier)
        .setOutlineData(sorted, synchronizeTimeline: false);
  }

  void updateDocument(
    TimelineDocumentData Function(TimelineDocumentData current) update,
  ) {
    setDocument(update(state));
  }
}

final timelineDocumentProvider =
    NotifierProvider<TimelineDocumentNotifier, TimelineDocumentData>(
      TimelineDocumentNotifier.new,
    );

class OutlineChapterLinksNotifier
    extends Notifier<List<OutlineChapterLinkData>> {
  @override
  List<OutlineChapterLinkData> build() => const <OutlineChapterLinkData>[];

  void setLinks(List<OutlineChapterLinkData> value) {
    final snapshot = snapshotOutlineChapterLinks(value);
    if (snapshot == state) return;
    state = snapshot;
  }

  void updateLinks(
    List<OutlineChapterLinkData> Function(List<OutlineChapterLinkData> current)
    update,
  ) {
    setLinks(update(state));
  }
}

final outlineChapterLinksProvider =
    NotifierProvider<OutlineChapterLinksNotifier, List<OutlineChapterLinkData>>(
      OutlineChapterLinksNotifier.new,
    );

class WorldSettingsDataNotifier extends Notifier<List<LocationData>> {
  List<LocationData> _createSnapshot(List<LocationData> source) {
    return snapshotWorldSettingsData(source);
  }

  ({List<LocationData> nodes, bool changed}) _updateLocationByIdRecursive(
    String id,
    List<LocationData> nodes,
    LocationData Function(LocationData current) update,
  ) {
    for (int index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      if (node.id == id) {
        final updated = update(node);
        if (updated == node) {
          return (nodes: nodes, changed: false);
        }
        final next = [...nodes];
        next[index] = updated;
        return (nodes: next, changed: true);
      }

      final childResult = _updateLocationByIdRecursive(id, node.child, update);
      if (childResult.changed) {
        final next = [...nodes];
        next[index] = node.copyWith(child: childResult.nodes);
        return (nodes: next, changed: true);
      }
    }

    return (nodes: nodes, changed: false);
  }

  ({List<LocationData> nodes, bool changed}) _addChildRecursive(
    String parentId,
    String name,
    List<LocationData> nodes,
  ) {
    for (int index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      if (node.id == parentId) {
        final nextChildren = [...node.child, LocationData(localName: name)];
        final next = [...nodes];
        next[index] = node.copyWith(child: nextChildren);
        return (nodes: next, changed: true);
      }

      final childResult = _addChildRecursive(parentId, name, node.child);
      if (childResult.changed) {
        final next = [...nodes];
        next[index] = node.copyWith(child: childResult.nodes);
        return (nodes: next, changed: true);
      }
    }

    return (nodes: nodes, changed: false);
  }

  ({List<LocationData> nodes, bool removed}) _removeNodeRecursive(
    String id,
    List<LocationData> nodes,
  ) {
    for (int index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      if (node.id == id) {
        final next = [...nodes]..removeAt(index);
        return (nodes: next, removed: true);
      }

      final childResult = _removeNodeRecursive(id, node.child);
      if (childResult.removed) {
        final next = [...nodes];
        next[index] = node.copyWith(child: childResult.nodes);
        return (nodes: next, removed: true);
      }
    }

    return (nodes: nodes, removed: false);
  }

  LocationData? _findLocationByIdRecursive(
    String id,
    List<LocationData> nodes,
  ) {
    for (final node in nodes) {
      if (node.id == id) {
        return node;
      }

      final child = _findLocationByIdRecursive(id, node.child);
      if (child != null) {
        return child;
      }
    }

    return null;
  }

  bool _containsNodeById(LocationData node, String targetId) {
    if (node.id == targetId) {
      return true;
    }

    for (final child in node.child) {
      if (_containsNodeById(child, targetId)) {
        return true;
      }
    }

    return false;
  }

  ({List<LocationData> nodes, bool inserted}) _insertNodeByPosition({
    required List<LocationData> nodes,
    required String targetId,
    required String position,
    required LocationData sourceNode,
  }) {
    for (int index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      if (node.id == targetId) {
        if (position == "child") {
          final nextChildren = [...node.child, sourceNode];
          final next = [...nodes];
          next[index] = node.copyWith(child: nextChildren);
          return (nodes: next, inserted: true);
        }

        if (position == "before") {
          final next = [...nodes]..insert(index, sourceNode);
          return (nodes: next, inserted: true);
        }

        if (position == "after") {
          final next = [...nodes]..insert(index + 1, sourceNode);
          return (nodes: next, inserted: true);
        }

        return (nodes: nodes, inserted: false);
      }

      final childResult = _insertNodeByPosition(
        nodes: node.child,
        targetId: targetId,
        position: position,
        sourceNode: sourceNode,
      );
      if (childResult.inserted) {
        final next = [...nodes];
        next[index] = node.copyWith(child: childResult.nodes);
        return (nodes: next, inserted: true);
      }
    }

    return (nodes: nodes, inserted: false);
  }

  @override
  List<LocationData> build() {
    return _createSnapshot(ProjectData.empty().worldSettingsData);
  }

  void setWorldSettingsData(List<LocationData> value) {
    state = _createSnapshot(value);
  }

  void updateWorldSettingsData(
    List<LocationData> Function(List<LocationData> current) update,
  ) {
    setWorldSettingsData(update(state));
  }

  bool updateLocationById(
    String id,
    LocationData Function(LocationData current) update,
  ) {
    final result = _updateLocationByIdRecursive(id, state, update);
    if (!result.changed) {
      return false;
    }
    setWorldSettingsData(result.nodes);
    return true;
  }

  bool addLocation({required String name, String? parentId}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    if (parentId == null) {
      final next = [...state, LocationData(localName: trimmed)];
      setWorldSettingsData(next);
      return true;
    }

    final result = _addChildRecursive(parentId, trimmed, state);

    if (!result.changed) {
      return false;
    }

    setWorldSettingsData(result.nodes);
    return true;
  }

  bool removeLocationById(String id) {
    final result = _removeNodeRecursive(id, state);
    if (!result.removed) {
      return false;
    }

    setWorldSettingsData(result.nodes);
    return true;
  }

  bool moveLocation({
    required String sourceId,
    required String targetId,
    required String position,
  }) {
    if (sourceId == targetId) {
      return false;
    }

    final next = state;
    final sourceNode = _findLocationByIdRecursive(sourceId, next);
    if (sourceNode == null) {
      return false;
    }

    if (_containsNodeById(sourceNode, targetId)) {
      return false;
    }

    final removedResult = _removeNodeRecursive(sourceId, next);
    if (!removedResult.removed) {
      return false;
    }

    final insertedResult = _insertNodeByPosition(
      nodes: removedResult.nodes,
      targetId: targetId,
      position: position,
      sourceNode: sourceNode,
    );

    final resultNodes = insertedResult.inserted
        ? insertedResult.nodes
        : [...removedResult.nodes, sourceNode];

    setWorldSettingsData(resultNodes);
    return true;
  }
}

final worldSettingsDataProvider =
    NotifierProvider<WorldSettingsDataNotifier, List<LocationData>>(
      WorldSettingsDataNotifier.new,
    );

class CharacterDataNotifier
    extends Notifier<Map<String, character_model.CharacterEntryData>> {
  Map<String, character_model.CharacterEntryData> _createSnapshot(
    Map<String, character_model.CharacterEntryData> source,
  ) {
    return snapshotCharacterData(source);
  }

  @override
  Map<String, character_model.CharacterEntryData> build() {
    return _createSnapshot(ProjectData.empty().characterData);
  }

  void setCharacterData(Map<String, character_model.CharacterEntryData> value) {
    state = _createSnapshot(value);
  }

  void updateCharacterData(
    Map<String, character_model.CharacterEntryData> Function(
      Map<String, character_model.CharacterEntryData> current,
    )
    update,
  ) {
    setCharacterData(update(state));
  }

  bool setCharacterEntry({
    required String characterId,
    required character_model.CharacterEntryData entry,
  }) {
    final normalizedId = characterId.trim();
    if (normalizedId.isEmpty) {
      return false;
    }

    final current = state[normalizedId];
    if (current == entry) {
      return false;
    }

    final next = Map<String, character_model.CharacterEntryData>.of(state);
    next[normalizedId] = entry.deepCopy();
    state = Map.unmodifiable(next);
    return true;
  }

  bool updateCharacterEntry(
    String characterId,
    character_model.CharacterEntryData Function(
      character_model.CharacterEntryData current,
    )
    update,
  ) {
    final normalizedId = characterId.trim();
    if (normalizedId.isEmpty) {
      return false;
    }

    final current = state[normalizedId];
    if (current == null) {
      return false;
    }

    final updated = update(current.deepCopy());
    if (updated == current) {
      return false;
    }

    final next = Map<String, character_model.CharacterEntryData>.of(state);
    next[normalizedId] = updated.deepCopy();
    state = Map.unmodifiable(next);
    return true;
  }

  bool removeCharacterEntry(String characterId) {
    final normalizedId = characterId.trim();
    if (normalizedId.isEmpty || !state.containsKey(normalizedId)) {
      return false;
    }

    final next = Map<String, character_model.CharacterEntryData>.of(state)
      ..remove(normalizedId);
    state = Map.unmodifiable(next);
    return true;
  }

  bool renameCharacterEntry({
    required String characterId,
    required String displayName,
  }) {
    final normalizedId = characterId.trim();
    final normalizedName = displayName.trim();
    if (normalizedId.isEmpty || normalizedName.isEmpty) {
      return false;
    }
    final entry = state[normalizedId];
    if (entry == null || entry.displayName == normalizedName) {
      return false;
    }

    final next = Map<String, character_model.CharacterEntryData>.of(state)
      ..[normalizedId] = entry.withDisplayName(normalizedName).deepCopy();
    state = Map.unmodifiable(next);
    return true;
  }
}

final characterDataProvider =
    NotifierProvider<
      CharacterDataNotifier,
      Map<String, character_model.CharacterEntryData>
    >(CharacterDataNotifier.new);

class CharacterStatesNotifier
    extends Notifier<List<character_model.CharacterState>> {
  @override
  List<character_model.CharacterState> build() => const [];

  void setCharacterStates(List<character_model.CharacterState> value) {
    state = List<character_model.CharacterState>.unmodifiable(
      value.map(
        (item) => item.copyWith(
          possessions: List<String>.unmodifiable(item.possessions),
        ),
      ),
    );
  }
}

final characterStatesProvider =
    NotifierProvider<
      CharacterStatesNotifier,
      List<character_model.CharacterState>
    >(CharacterStatesNotifier.new);

class ForeshadowDataNotifier
    extends Notifier<List<plan_module.ForeshadowItem>> {
  List<plan_module.ForeshadowItem> _createSnapshot(
    List<plan_module.ForeshadowItem> source,
  ) {
    return snapshotForeshadowData(source);
  }

  @override
  List<plan_module.ForeshadowItem> build() {
    return _createSnapshot(ProjectData.empty().foreshadowData);
  }

  void setForeshadowData(List<plan_module.ForeshadowItem> value) {
    state = _createSnapshot(value);
  }

  void updateForeshadowData(
    List<plan_module.ForeshadowItem> Function(
      List<plan_module.ForeshadowItem> current,
    )
    update,
  ) {
    setForeshadowData(update(state));
  }

  void addForeshadowItem(plan_module.ForeshadowItem item) {
    setForeshadowData([...state, item]);
  }

  bool updateForeshadowById(
    String id,
    plan_module.ForeshadowItem Function(plan_module.ForeshadowItem current)
    update,
  ) {
    final index = state.indexWhere((item) => item.id == id);
    if (index == -1) {
      return false;
    }

    final next = [...state];
    final current = next[index];
    final updated = update(current);
    if (updated == current) {
      return false;
    }

    next[index] = updated;
    setForeshadowData(next);
    return true;
  }

  bool removeForeshadowById(String id) {
    final next = state.where((item) => item.id != id).toList(growable: false);
    if (next.length == state.length) {
      return false;
    }
    setForeshadowData(next);
    return true;
  }

  bool reorderForeshadowByDrop({
    required String draggedId,
    required String targetId,
    required bool isBefore,
  }) {
    if (draggedId == targetId) {
      return false;
    }

    final next = [...state];
    final draggedIndex = next.indexWhere((item) => item.id == draggedId);
    final targetIndex = next.indexWhere((item) => item.id == targetId);
    if (draggedIndex == -1 || targetIndex == -1) {
      return false;
    }

    final draggedItem = next.removeAt(draggedIndex);
    var adjustedTarget = targetIndex;
    if (draggedIndex < targetIndex) {
      adjustedTarget -= 1;
    }

    final insertIndex = isBefore ? adjustedTarget : adjustedTarget + 1;
    if (insertIndex == draggedIndex) {
      return false;
    }

    final boundedIndex = insertIndex.clamp(0, next.length);
    next.insert(boundedIndex, draggedItem);
    setForeshadowData(next);
    return true;
  }
}

final foreshadowDataProvider =
    NotifierProvider<ForeshadowDataNotifier, List<plan_module.ForeshadowItem>>(
      ForeshadowDataNotifier.new,
    );

class UpdatePlanDataNotifier
    extends Notifier<List<plan_module.UpdatePlanItem>> {
  List<plan_module.UpdatePlanItem> _createSnapshot(
    List<plan_module.UpdatePlanItem> source,
  ) {
    return snapshotUpdatePlanData(source);
  }

  @override
  List<plan_module.UpdatePlanItem> build() {
    return _createSnapshot(ProjectData.empty().updatePlanData);
  }

  void setUpdatePlanData(List<plan_module.UpdatePlanItem> value) {
    state = _createSnapshot(value);
  }

  void updateUpdatePlanData(
    List<plan_module.UpdatePlanItem> Function(
      List<plan_module.UpdatePlanItem> current,
    )
    update,
  ) {
    setUpdatePlanData(update(state));
  }

  void addUpdatePlanItem(plan_module.UpdatePlanItem item) {
    setUpdatePlanData([...state, item]);
  }

  bool updateUpdatePlanById(
    String id,
    plan_module.UpdatePlanItem Function(plan_module.UpdatePlanItem current)
    update,
  ) {
    final index = state.indexWhere((item) => item.id == id);
    if (index == -1) {
      return false;
    }

    final next = [...state];
    final current = next[index];
    final updated = update(current);
    if (updated == current) {
      return false;
    }

    next[index] = updated;
    setUpdatePlanData(next);
    return true;
  }

  bool removeUpdatePlanById(String id) {
    final next = state.where((item) => item.id != id).toList(growable: false);
    if (next.length == state.length) {
      return false;
    }
    setUpdatePlanData(next);
    return true;
  }

  bool reorderUpdatePlanByDrop({
    required String draggedId,
    required String targetId,
    required bool isBefore,
  }) {
    if (draggedId == targetId) {
      return false;
    }

    final next = [...state];
    final draggedIndex = next.indexWhere((item) => item.id == draggedId);
    final targetIndex = next.indexWhere((item) => item.id == targetId);
    if (draggedIndex == -1 || targetIndex == -1) {
      return false;
    }

    final draggedItem = next.removeAt(draggedIndex);
    var adjustedTarget = targetIndex;
    if (draggedIndex < targetIndex) {
      adjustedTarget -= 1;
    }

    final insertIndex = isBefore ? adjustedTarget : adjustedTarget + 1;
    if (insertIndex == draggedIndex) {
      return false;
    }

    final boundedIndex = insertIndex.clamp(0, next.length);
    next.insert(boundedIndex, draggedItem);
    setUpdatePlanData(next);
    return true;
  }
}

final updatePlanDataProvider =
    NotifierProvider<UpdatePlanDataNotifier, List<plan_module.UpdatePlanItem>>(
      UpdatePlanDataNotifier.new,
    );

class GlossaryStateData {
  final List<glossary_model.GlossaryCategory> categoryTree;
  final Map<String, glossary_model.GlossaryEntry> entryIndex;

  const GlossaryStateData({
    required this.categoryTree,
    required this.entryIndex,
  });
}

enum GlossaryCategoryDropPosition { before, child, after }

class GlossaryAddEntryResult {
  final String entryId;
  final bool createdNewEntry;
  final bool linkedToCategory;

  const GlossaryAddEntryResult({
    required this.entryId,
    required this.createdNewEntry,
    required this.linkedToCategory,
  });
}

class GlossaryUpdateTermResult {
  final bool changed;
  final String entryId;
  final String? mergedIntoEntryId;

  const GlossaryUpdateTermResult({
    required this.changed,
    required this.entryId,
    this.mergedIntoEntryId,
  });
}

class GlossaryStateNotifier extends Notifier<GlossaryStateData> {
  static const Duration _persistDebounceDuration = Duration(milliseconds: 240);
  static const String _glossaryFileName = "Glossary.json";

  Timer? _persistDebounce;

  GlossaryStateData _createSnapshot(GlossaryStateData value) {
    final categoryTree = List<glossary_model.GlossaryCategory>.unmodifiable(
      glossary_model.copyGlossaryCategoryTree(value.categoryTree),
    );
    final entryIndex = Map<String, glossary_model.GlossaryEntry>.unmodifiable(
      glossary_model.copyGlossaryEntryIndex(value.entryIndex),
    );

    return GlossaryStateData(
      categoryTree: categoryTree,
      entryIndex: entryIndex,
    );
  }

  void _setIfChanged(GlossaryStateData value, {required bool schedulePersist}) {
    state = GlossaryStateData(
      categoryTree: List.unmodifiable(value.categoryTree),
      entryIndex: Map.unmodifiable(value.entryIndex),
    );
    if (schedulePersist) {
      _schedulePersist();
    }
  }

  HashMap<String, glossary_model.GlossaryEntry> _copyEntryIndex(
    Map<String, glossary_model.GlossaryEntry> source,
  ) {
    return glossary_model.copyGlossaryEntryIndex(source);
  }

  List<glossary_model.GlossaryCategory> _copyCategoryTree(
    List<glossary_model.GlossaryCategory> source,
  ) {
    return glossary_model.copyGlossaryCategoryTree(source);
  }

  String _normalizeTerm(String value) {
    return value.trim().toLowerCase();
  }

  glossary_model.GlossaryCategory? _findCategoryById(
    String id,
    List<glossary_model.GlossaryCategory> nodes,
  ) {
    for (final glossary_model.GlossaryCategory node in nodes) {
      if (node.id == id) {
        return node;
      }

      final glossary_model.GlossaryCategory? child = _findCategoryById(
        id,
        node.children,
      );
      if (child != null) {
        return child;
      }
    }

    return null;
  }

  bool _isDescendantCategory(
    String sourceId,
    String targetId,
    List<glossary_model.GlossaryCategory> tree,
  ) {
    final glossary_model.GlossaryCategory? source = _findCategoryById(
      sourceId,
      tree,
    );
    if (source == null) {
      return false;
    }

    bool walk(glossary_model.GlossaryCategory node) {
      if (node.id == targetId) {
        return true;
      }

      for (final glossary_model.GlossaryCategory child in node.children) {
        if (walk(child)) {
          return true;
        }
      }

      return false;
    }

    return walk(source);
  }

  Set<String> _collectReferencedEntryIdsFromTree(
    List<glossary_model.GlossaryCategory> tree,
  ) {
    final Set<String> refs = <String>{};

    void walk(List<glossary_model.GlossaryCategory> nodes) {
      for (final glossary_model.GlossaryCategory node in nodes) {
        refs.addAll(node.entryIds);
        walk(node.children);
      }
    }

    walk(tree);
    return refs;
  }

  String? _findEntryIdByTerm(
    String term,
    Map<String, glossary_model.GlossaryEntry> entryIndex, {
    String? excludeEntryId,
  }) {
    final String normalizedTerm = _normalizeTerm(term);
    if (normalizedTerm.isEmpty) {
      return null;
    }

    for (final MapEntry<String, glossary_model.GlossaryEntry> item
        in entryIndex.entries) {
      if (item.key != item.value.id) {
        continue;
      }
      if (excludeEntryId != null && item.value.id == excludeEntryId) {
        continue;
      }
      if (_normalizeTerm(item.value.term) == normalizedTerm) {
        return item.value.id;
      }
    }

    return null;
  }

  void _rewriteCategoryEntryReferences(
    List<glossary_model.GlossaryCategory> categoryTree,
    Map<String, String> replacements,
  ) {
    if (replacements.isEmpty) {
      return;
    }

    void walk(List<glossary_model.GlossaryCategory> nodes) {
      for (final glossary_model.GlossaryCategory node in nodes) {
        final List<String> rewrittenIds = [];
        final Set<String> seen = <String>{};

        for (final String entryId in node.entryIds) {
          final String resolvedId = replacements[entryId] ?? entryId;
          if (seen.add(resolvedId)) {
            rewrittenIds.add(resolvedId);
          }
        }

        node.entryIds = rewrittenIds;
        walk(node.children);
      }
    }

    walk(categoryTree);
  }

  bool _replaceEntryInIndex({
    required String entryId,
    required HashMap<String, glossary_model.GlossaryEntry> entryIndex,
    required glossary_model.GlossaryEntry updated,
  }) {
    bool replaced = false;
    for (final String key in entryIndex.keys.toList(growable: false)) {
      final glossary_model.GlossaryEntry? current = entryIndex[key];
      if (current != null && current.id == entryId) {
        entryIndex[key] = updated.deepCopy();
        replaced = true;
      }
    }

    if (!replaced) {
      entryIndex[entryId] = updated.deepCopy();
      replaced = true;
    }

    return replaced;
  }

  bool _updateEntry(
    String entryId,
    glossary_model.GlossaryEntry Function(glossary_model.GlossaryEntry current)
    transform,
  ) {
    final glossary_model.GlossaryEntry? current = state.entryIndex[entryId];
    if (current == null) {
      return false;
    }

    final glossary_model.GlossaryEntry updated = transform(current.deepCopy());
    if (updated == current) {
      return false;
    }

    final HashMap<String, glossary_model.GlossaryEntry> nextEntryIndex =
        HashMap<String, glossary_model.GlossaryEntry>.of(state.entryIndex);
    final bool replaced = _replaceEntryInIndex(
      entryId: entryId,
      entryIndex: nextEntryIndex,
      updated: updated,
    );
    if (!replaced) {
      return false;
    }

    _setIfChanged(
      GlossaryStateData(
        categoryTree: state.categoryTree,
        entryIndex: nextEntryIndex,
      ),
      schedulePersist: true,
    );
    return true;
  }

  Future<String> _glossaryFilePath() async {
    final Directory appDir = await getApplicationSupportDirectory();
    final Directory dataDir = Directory("${appDir.path}/Data");
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }
    return "${dataDir.path}/$_glossaryFileName";
  }

  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(_persistDebounceDuration, () {
      final GlossaryStateData snapshot = _createSnapshot(state);
      unawaited(_persistGlossaryNow(snapshot));
    });
  }

  Future<void> _persistGlossaryNow(GlossaryStateData snapshot) async {
    final String filePath = await _glossaryFilePath();
    final File file = File(filePath);
    final Map<String, dynamic> payload = {
      "version": 1,
      "categoryTree": snapshot.categoryTree
          .map((category) => category.toJson())
          .toList(growable: false),
      "entries": {
        for (final MapEntry<String, glossary_model.GlossaryEntry> entry
            in snapshot.entryIndex.entries)
          entry.key: entry.value.toJson(),
      },
    };
    await file.writeAsString(jsonEncode(payload));
  }

  @override
  GlossaryStateData build() {
    ref.onDispose(() {
      _persistDebounce?.cancel();
      _persistDebounce = null;
    });

    return _createSnapshot(
      const GlossaryStateData(categoryTree: [], entryIndex: {}),
    );
  }

  void setGlossaryState(GlossaryStateData value, {bool persist = true}) {
    _setIfChanged(_createSnapshot(value), schedulePersist: persist);
  }

  void hydrateFromStorage(GlossaryStateData value) {
    setGlossaryState(value, persist: false);
  }

  void updateGlossaryState(
    GlossaryStateData Function(GlossaryStateData current) update, {
    bool persist = true,
  }) {
    setGlossaryState(update(state), persist: persist);
  }

  bool addCategory({
    required glossary_model.GlossaryCategory category,
    String? parentCategoryId,
  }) {
    final List<glossary_model.GlossaryCategory> nextTree = _copyCategoryTree(
      state.categoryTree,
    );

    if (parentCategoryId == null) {
      nextTree.add(category);
    } else {
      final glossary_model.GlossaryCategory? parent = _findCategoryById(
        parentCategoryId,
        nextTree,
      );
      if (parent == null) {
        return false;
      }
      parent.children.add(category);
    }

    _setIfChanged(
      GlossaryStateData(categoryTree: nextTree, entryIndex: state.entryIndex),
      schedulePersist: true,
    );
    return true;
  }

  bool renameCategory({required String categoryId, required String name}) {
    final String nextName = name.trim();
    if (nextName.isEmpty) {
      return false;
    }

    final List<glossary_model.GlossaryCategory> nextTree = _copyCategoryTree(
      state.categoryTree,
    );
    final glossary_model.GlossaryCategory? category = _findCategoryById(
      categoryId,
      nextTree,
    );
    if (category == null || category.name == nextName) {
      return false;
    }

    category.name = nextName;
    _setIfChanged(
      GlossaryStateData(categoryTree: nextTree, entryIndex: state.entryIndex),
      schedulePersist: true,
    );
    return true;
  }

  bool deleteCategory(String categoryId) {
    final List<glossary_model.GlossaryCategory> nextTree = _copyCategoryTree(
      state.categoryTree,
    );
    final HashMap<String, glossary_model.GlossaryEntry> nextEntryIndex =
        _copyEntryIndex(state.entryIndex);

    bool removed = false;

    bool removeNode(List<glossary_model.GlossaryCategory> nodes) {
      for (int i = 0; i < nodes.length; i++) {
        if (nodes[i].id == categoryId) {
          nodes.removeAt(i);
          removed = true;
          return true;
        }

        if (removeNode(nodes[i].children)) {
          return true;
        }
      }
      return false;
    }

    removeNode(nextTree);
    if (!removed) {
      return false;
    }

    final Set<String> refs = _collectReferencedEntryIdsFromTree(nextTree);
    nextEntryIndex.removeWhere((_, entry) => !refs.contains(entry.id));

    _setIfChanged(
      GlossaryStateData(categoryTree: nextTree, entryIndex: nextEntryIndex),
      schedulePersist: true,
    );
    return true;
  }

  bool moveCategoryTo({
    required String sourceId,
    required String targetId,
    required GlossaryCategoryDropPosition position,
  }) {
    if (sourceId == targetId) {
      return false;
    }

    final List<glossary_model.GlossaryCategory> nextTree = _copyCategoryTree(
      state.categoryTree,
    );
    if (_isDescendantCategory(sourceId, targetId, nextTree)) {
      return false;
    }

    glossary_model.GlossaryCategory? sourceNode;

    bool removeNode(List<glossary_model.GlossaryCategory> nodes) {
      for (int i = 0; i < nodes.length; i++) {
        if (nodes[i].id == sourceId) {
          sourceNode = nodes[i];
          nodes.removeAt(i);
          return true;
        }
        if (removeNode(nodes[i].children)) {
          return true;
        }
      }
      return false;
    }

    final bool removed = removeNode(nextTree);
    if (!removed || sourceNode == null) {
      return false;
    }

    bool inserted = false;

    if (position == GlossaryCategoryDropPosition.child) {
      bool insertAsChild(List<glossary_model.GlossaryCategory> nodes) {
        for (final glossary_model.GlossaryCategory node in nodes) {
          if (node.id == targetId) {
            node.children.add(sourceNode!);
            return true;
          }
          if (insertAsChild(node.children)) {
            return true;
          }
        }
        return false;
      }

      inserted = insertAsChild(nextTree);
    } else {
      bool insertAsSibling(List<glossary_model.GlossaryCategory> nodes) {
        for (int i = 0; i < nodes.length; i++) {
          if (nodes[i].id == targetId) {
            final int targetIndex =
                position == GlossaryCategoryDropPosition.before ? i : i + 1;
            nodes.insert(targetIndex, sourceNode!);
            return true;
          }
          if (insertAsSibling(nodes[i].children)) {
            return true;
          }
        }
        return false;
      }

      inserted = insertAsSibling(nextTree);
    }

    if (!inserted) {
      nextTree.add(sourceNode!);
    }

    _setIfChanged(
      GlossaryStateData(categoryTree: nextTree, entryIndex: state.entryIndex),
      schedulePersist: true,
    );
    return true;
  }

  GlossaryAddEntryResult? addEntryByTermToCategory({
    required String categoryId,
    required String term,
    required String newEntryId,
  }) {
    final String trimmedTerm = term.trim();
    if (trimmedTerm.isEmpty) {
      return null;
    }

    final List<glossary_model.GlossaryCategory> nextTree = _copyCategoryTree(
      state.categoryTree,
    );
    final HashMap<String, glossary_model.GlossaryEntry> nextEntryIndex =
        _copyEntryIndex(state.entryIndex);

    final glossary_model.GlossaryCategory? category = _findCategoryById(
      categoryId,
      nextTree,
    );
    if (category == null) {
      return null;
    }

    final String? existingEntryId = _findEntryIdByTerm(
      trimmedTerm,
      nextEntryIndex,
    );
    if (existingEntryId != null) {
      final bool linked = !category.entryIds.contains(existingEntryId);
      if (linked) {
        category.entryIds.add(existingEntryId);
        _setIfChanged(
          GlossaryStateData(categoryTree: nextTree, entryIndex: nextEntryIndex),
          schedulePersist: true,
        );
      }

      return GlossaryAddEntryResult(
        entryId: existingEntryId,
        createdNewEntry: false,
        linkedToCategory: linked,
      );
    }

    final glossary_model.GlossaryEntry entry = glossary_model.GlossaryEntry(
      id: newEntryId,
      term: trimmedTerm,
      partOfSpeech: glossary_model.GlossaryPartOfSpeech.unspecified,
      customPartOfSpeech: "",
      polarity: glossary_model.GlossaryPolarity.neutral,
      pairs: [glossary_model.GlossaryPair()],
    );

    nextEntryIndex[newEntryId] = entry;
    category.entryIds.add(newEntryId);

    _setIfChanged(
      GlossaryStateData(categoryTree: nextTree, entryIndex: nextEntryIndex),
      schedulePersist: true,
    );

    return GlossaryAddEntryResult(
      entryId: newEntryId,
      createdNewEntry: true,
      linkedToCategory: true,
    );
  }

  bool removeEntryFromCategory({
    required String sourceCategoryId,
    required String entryId,
  }) {
    final List<glossary_model.GlossaryCategory> nextTree = _copyCategoryTree(
      state.categoryTree,
    );
    final HashMap<String, glossary_model.GlossaryEntry> nextEntryIndex =
        _copyEntryIndex(state.entryIndex);

    final glossary_model.GlossaryCategory? source = _findCategoryById(
      sourceCategoryId,
      nextTree,
    );
    if (source == null) {
      return false;
    }

    final bool removed = source.entryIds.remove(entryId);
    if (!removed) {
      return false;
    }

    final Set<String> allRefs = _collectReferencedEntryIdsFromTree(nextTree);
    if (!allRefs.contains(entryId)) {
      nextEntryIndex.removeWhere((_, entry) => entry.id == entryId);
    }

    _setIfChanged(
      GlossaryStateData(categoryTree: nextTree, entryIndex: nextEntryIndex),
      schedulePersist: true,
    );
    return true;
  }

  bool moveEntryToCategory({
    required String entryId,
    required String sourceCategoryId,
    required String targetCategoryId,
    int? targetInsertIndex,
  }) {
    final List<glossary_model.GlossaryCategory> nextTree = _copyCategoryTree(
      state.categoryTree,
    );
    final glossary_model.GlossaryCategory? source = _findCategoryById(
      sourceCategoryId,
      nextTree,
    );
    final glossary_model.GlossaryCategory? target = _findCategoryById(
      targetCategoryId,
      nextTree,
    );
    if (source == null || target == null) {
      return false;
    }

    final int fromIndex = source.entryIds.indexOf(entryId);
    if (fromIndex < 0) {
      return false;
    }

    bool changed = false;
    if (sourceCategoryId == targetCategoryId) {
      if (targetInsertIndex == null) {
        return false;
      }

      int insertIndex = targetInsertIndex;
      if (insertIndex < 0) {
        insertIndex = 0;
      }
      if (insertIndex > source.entryIds.length) {
        insertIndex = source.entryIds.length;
      }

      if (insertIndex == fromIndex || insertIndex == fromIndex + 1) {
        return false;
      }

      source.entryIds.removeAt(fromIndex);
      if (insertIndex > fromIndex) {
        insertIndex -= 1;
      }
      source.entryIds.insert(insertIndex, entryId);
      changed = true;
    } else {
      final bool removed = source.entryIds.remove(entryId);
      if (!removed) {
        return false;
      }

      if (!target.entryIds.contains(entryId)) {
        int insertIndex = targetInsertIndex ?? target.entryIds.length;
        if (insertIndex < 0) {
          insertIndex = 0;
        }
        if (insertIndex > target.entryIds.length) {
          insertIndex = target.entryIds.length;
        }
        target.entryIds.insert(insertIndex, entryId);
      }
      changed = true;
    }

    if (!changed) {
      return false;
    }

    _setIfChanged(
      GlossaryStateData(categoryTree: nextTree, entryIndex: state.entryIndex),
      schedulePersist: true,
    );
    return true;
  }

  GlossaryUpdateTermResult updateEntryTerm({
    required String entryId,
    required String term,
  }) {
    final glossary_model.GlossaryEntry? current = state.entryIndex[entryId];
    if (current == null || current.term == term) {
      return GlossaryUpdateTermResult(changed: false, entryId: entryId);
    }

    final String? mergeTargetId = _findEntryIdByTerm(
      term,
      state.entryIndex,
      excludeEntryId: entryId,
    );

    if (mergeTargetId != null) {
      final List<glossary_model.GlossaryCategory> nextTree = _copyCategoryTree(
        state.categoryTree,
      );
      final HashMap<String, glossary_model.GlossaryEntry> nextEntryIndex =
          _copyEntryIndex(state.entryIndex);

      _rewriteCategoryEntryReferences(nextTree, {entryId: mergeTargetId});
      nextEntryIndex.removeWhere(
        (key, item) => key == entryId || item.id == entryId,
      );

      _setIfChanged(
        GlossaryStateData(categoryTree: nextTree, entryIndex: nextEntryIndex),
        schedulePersist: true,
      );

      return GlossaryUpdateTermResult(
        changed: true,
        entryId: entryId,
        mergedIntoEntryId: mergeTargetId,
      );
    }

    final bool changed = _updateEntry(
      entryId,
      (entry) => entry.copyWith(term: term),
    );
    return GlossaryUpdateTermResult(changed: changed, entryId: entryId);
  }

  bool setEntryPolarity({
    required String entryId,
    required glossary_model.GlossaryPolarity polarity,
  }) {
    return _updateEntry(entryId, (entry) => entry.copyWith(polarity: polarity));
  }

  bool setEntryPartOfSpeech({
    required String entryId,
    required glossary_model.GlossaryPartOfSpeech partOfSpeech,
  }) {
    return _updateEntry(
      entryId,
      (entry) => entry.copyWith(partOfSpeech: partOfSpeech),
    );
  }

  bool setEntryCustomPartOfSpeech({
    required String entryId,
    required String customPartOfSpeech,
  }) {
    return _updateEntry(
      entryId,
      (entry) => entry.copyWith(customPartOfSpeech: customPartOfSpeech),
    );
  }

  bool updateEntryPairMeaning({
    required String entryId,
    required int pairIndex,
    required String meaning,
  }) {
    return _updateEntry(entryId, (entry) {
      if (pairIndex < 0 || pairIndex >= entry.pairs.length) {
        return entry;
      }

      final List<glossary_model.GlossaryPair> pairs = entry.pairs
          .map((pair) => pair.deepCopy())
          .toList(growable: false);
      pairs[pairIndex] = pairs[pairIndex].copyWith(meaning: meaning);
      return entry.copyWith(pairs: pairs);
    });
  }

  bool updateEntryPairExample({
    required String entryId,
    required int pairIndex,
    required String example,
  }) {
    return _updateEntry(entryId, (entry) {
      if (pairIndex < 0 || pairIndex >= entry.pairs.length) {
        return entry;
      }

      final List<glossary_model.GlossaryPair> pairs = entry.pairs
          .map((pair) => pair.deepCopy())
          .toList(growable: false);
      pairs[pairIndex] = pairs[pairIndex].copyWith(example: example);
      return entry.copyWith(pairs: pairs);
    });
  }

  bool addEntryPair(String entryId) {
    return _updateEntry(entryId, (entry) {
      final List<glossary_model.GlossaryPair> pairs = entry.pairs
          .map((pair) => pair.deepCopy())
          .toList();
      pairs.add(glossary_model.GlossaryPair());
      return entry.copyWith(pairs: pairs);
    });
  }

  bool removeEntryPair({required String entryId, required int pairIndex}) {
    return _updateEntry(entryId, (entry) {
      if (pairIndex < 0 || pairIndex >= entry.pairs.length) {
        return entry;
      }
      if (entry.pairs.length <= 1) {
        return entry;
      }

      final List<glossary_model.GlossaryPair> pairs = entry.pairs
          .map((pair) => pair.deepCopy())
          .toList();
      pairs.removeAt(pairIndex);
      return entry.copyWith(pairs: pairs);
    });
  }

  Future<void> flushGlossaryPersistence() async {
    final Timer? timer = _persistDebounce;
    if (timer != null) {
      timer.cancel();
      _persistDebounce = null;
    }
    await _persistGlossaryNow(_createSnapshot(state));
  }
}

final glossaryStateProvider =
    NotifierProvider<GlossaryStateNotifier, GlossaryStateData>(
      GlossaryStateNotifier.new,
    );

class EditorContentNotifier extends Notifier<String> {
  @override
  String build() {
    return "";
  }

  void setContent(String value) {
    if (state == value) {
      return;
    }
    state = value;
  }
}

final editorContentProvider = NotifierProvider<EditorContentNotifier, String>(
  EditorContentNotifier.new,
);

class EditorSelectionNotifier extends Notifier<EditorSelectionState> {
  @override
  EditorSelectionState build() {
    return const EditorSelectionState();
  }

  void setEditorSelection(EditorSelectionState value) {
    if (state == value) {
      return;
    }
    state = value;
  }

  void setSelection({
    required String? selectedSegID,
    required String? selectedChapID,
  }) {
    if (state.selectedSegID == selectedSegID &&
        state.selectedChapID == selectedChapID) {
      return;
    }
    state = state.copyWith(
      selectedSegID: selectedSegID,
      selectedChapID: selectedChapID,
    );
  }

  void setSelectionAndCursor({
    required String? selectedSegID,
    required String? selectedChapID,
    required int cursorOffset,
  }) {
    final nextState = state.copyWith(
      selectedSegID: selectedSegID,
      selectedChapID: selectedChapID,
      cursorOffset: cursorOffset,
    );
    if (nextState == state) {
      return;
    }
    state = nextState;
  }

  void setSelectedSegID(String? value) {
    if (state.selectedSegID == value) {
      return;
    }
    state = state.copyWith(selectedSegID: value);
  }

  void setSelectedChapID(String? value) {
    if (state.selectedChapID == value) {
      return;
    }
    state = state.copyWith(selectedChapID: value);
  }

  void setCursorOffset(int value) {
    if (state.cursorOffset == value) {
      return;
    }
    state = state.copyWith(cursorOffset: value);
  }
}

final editorSelectionProvider =
    NotifierProvider<EditorSelectionNotifier, EditorSelectionState>(
      EditorSelectionNotifier.new,
    );

/// The persisted content for the currently selected chapter.
///
/// Selection and editor content are stored in separate providers. During a
/// chapter switch they therefore cannot be published in the same notification.
/// Consumers that react to the selection change must read the chapter model,
/// instead of temporarily pairing the new chapter id with the previous
/// editor's text.
final selectedChapterStoredContentProvider = Provider<String?>((ref) {
  final selection = ref.watch(editorSelectionProvider);
  final segmentID = selection.selectedSegID;
  final chapterID = selection.selectedChapID;
  if (segmentID == null || chapterID == null) {
    return null;
  }

  final segments = ref.watch(segmentsDataProvider);
  return chapter_module.ChapterTree.findChapter(
    segments,
    folderId: segmentID,
    chapterId: chapterID,
  )?.chapter.chapterContent;
});

class TotalWordsNotifier extends Notifier<int> {
  @override
  int build() {
    return 0;
  }

  void setTotalWords(int value) {
    state = value;
  }
}

final totalWordsProvider = NotifierProvider<TotalWordsNotifier, int>(
  TotalWordsNotifier.new,
);

class CurrentProjectFileNotifier extends Notifier<ProjectFile?> {
  @override
  ProjectFile? build() {
    return null;
  }

  void setCurrentProjectFile(ProjectFile? value) {
    state = value;
  }
}

final currentProjectFileProvider =
    NotifierProvider<CurrentProjectFileNotifier, ProjectFile?>(
      CurrentProjectFileNotifier.new,
    );

final projectDataProvider = Provider<ProjectData>((ref) {
  return ProjectData(
    baseInfoData: ref.watch(baseInfoDataProvider),
    segmentsData: ref.watch(segmentsDataProvider),
    outlineData: ref.watch(outlineDataProvider),
    foreshadowData: ref.watch(foreshadowDataProvider),
    updatePlanData: ref.watch(updatePlanDataProvider),
    worldSettingsData: ref.watch(worldSettingsDataProvider),
    characterData: ref.watch(characterDataProvider),
    characterStates: ref.watch(characterStatesProvider),
    timelineDocument: ref.watch(timelineDocumentProvider),
    outlineChapterLinks: ref.watch(outlineChapterLinksProvider),
    totalWords: ref.watch(totalWordsProvider),
    contentText: ref.watch(editorContentProvider),
  );
});
