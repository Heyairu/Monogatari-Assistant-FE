import "dart:async";
import "dart:collection";
import "dart:convert";
import "dart:io";

import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:path_provider/path_provider.dart";

import "../../bin/file.dart" as file_module;
import "../../bin/settings_manager.dart";
import "../../models/character_data.dart" as character_model;
import "../../models/glossary_data.dart" as glossary_model;
import "../../modules/baseinfoview.dart" as base_info_module;
import "../../modules/chapterselectionview.dart" as chapter_module;
import "../../modules/outlineview.dart" as outline_module;
import "../../modules/planview.dart" as plan_module;
import "../../modules/worldsettingsview.dart";

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
    return value.copyWith(tags: [...value.tags]);
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
    return _createSnapshot(file_module.ProjectData.empty().baseInfoData);
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
}

final baseInfoDataProvider =
    NotifierProvider<BaseInfoDataNotifier, base_info_module.BaseInfoData>(
      BaseInfoDataNotifier.new,
    );

class SegmentsDataNotifier extends Notifier<List<chapter_module.SegmentData>> {
  List<chapter_module.SegmentData> _createSnapshot(
    List<chapter_module.SegmentData> source,
  ) {
    return List<chapter_module.SegmentData>.unmodifiable(
      source
          .map(
            (segment) => segment.copyWith(
              chapters: segment.chapters
                  .map((chapter) => chapter.copyWith())
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
  }

  void _setIfChanged(List<chapter_module.SegmentData> value) {
    final snapshot = _createSnapshot(value);
    if (snapshot == state) {
      return;
    }
    state = snapshot;
  }

  int _segmentIndexById(
    String segmentID,
    List<chapter_module.SegmentData> segments,
  ) {
    return segments.indexWhere((segment) => segment.segmentUUID == segmentID);
  }

  int _chapterIndexById(
    String chapterID,
    List<chapter_module.ChapterData> chapters,
  ) {
    return chapters.indexWhere((chapter) => chapter.chapterUUID == chapterID);
  }

  @override
  List<chapter_module.SegmentData> build() {
    return _createSnapshot(file_module.ProjectData.empty().segmentsData);
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

  void insertSegmentAt(int index, chapter_module.SegmentData segment) {
    updateSegmentsData((current) {
      final next = [...current];
      final insertIndex = index.clamp(0, next.length);
      next.insert(insertIndex, segment);
      return next;
    });
  }

  void removeSegmentById(String segmentID) {
    updateSegmentsData(
      (current) =>
          current.where((segment) => segment.segmentUUID != segmentID).toList(),
    );
  }

  void renameSegment({required String segmentID, required String name}) {
    updateSegmentsData((current) {
      final index = _segmentIndexById(segmentID, current);
      if (index < 0) {
        return current;
      }

      final next = [...current];
      final target = next[index];
      next[index] = target.copyWith(segmentName: name);
      return next;
    });
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
    updateSegmentsData((current) {
      final segmentIndex = _segmentIndexById(segmentID, current);
      if (segmentIndex < 0) {
        return current;
      }

      final next = [...current];
      final segment = next[segmentIndex];
      next[segmentIndex] = segment.copyWith(
        chapters: [...segment.chapters, chapter],
      );
      return next;
    });
  }

  void insertChapter({
    required String segmentID,
    required int chapterIndex,
    required chapter_module.ChapterData chapter,
  }) {
    updateSegmentsData((current) {
      final segmentIndex = _segmentIndexById(segmentID, current);
      if (segmentIndex < 0) {
        return current;
      }

      final next = [...current];
      final segment = next[segmentIndex];
      final chapters = [...segment.chapters];
      final insertIndex = chapterIndex.clamp(0, chapters.length);
      chapters.insert(insertIndex, chapter);
      next[segmentIndex] = segment.copyWith(chapters: chapters);
      return next;
    });
  }

  void renameChapter({
    required String segmentID,
    required String chapterID,
    required String name,
  }) {
    updateSegmentsData((current) {
      final segmentIndex = _segmentIndexById(segmentID, current);
      if (segmentIndex < 0) {
        return current;
      }

      final segment = current[segmentIndex];
      final chapterIndex = _chapterIndexById(chapterID, segment.chapters);
      if (chapterIndex < 0) {
        return current;
      }

      final next = [...current];
      final chapters = [...segment.chapters];
      final target = chapters[chapterIndex];
      chapters[chapterIndex] = target.copyWith(chapterName: name);
      next[segmentIndex] = segment.copyWith(chapters: chapters);
      return next;
    });
  }

  void updateChapterContent({
    required String segmentID,
    required String chapterID,
    required String content,
  }) {
    updateSegmentsData((current) {
      final segmentIndex = _segmentIndexById(segmentID, current);
      if (segmentIndex < 0) {
        return current;
      }

      final segment = current[segmentIndex];
      final chapterIndex = _chapterIndexById(chapterID, segment.chapters);
      if (chapterIndex < 0) {
        return current;
      }

      final next = [...current];
      final chapters = [...segment.chapters];
      final target = chapters[chapterIndex];
      chapters[chapterIndex] = target.copyWith(chapterContent: content);
      next[segmentIndex] = segment.copyWith(chapters: chapters);
      return next;
    });
  }

  void removeChapter({required String segmentID, required String chapterID}) {
    updateSegmentsData((current) {
      final segmentIndex = _segmentIndexById(segmentID, current);
      if (segmentIndex < 0) {
        return current;
      }

      final segment = current[segmentIndex];
      final chapters = segment.chapters
          .where((chapter) => chapter.chapterUUID != chapterID)
          .toList();

      if (chapters.length == segment.chapters.length) {
        return current;
      }

      final next = [...current];
      next[segmentIndex] = segment.copyWith(chapters: chapters);
      return next;
    });
  }

  void moveChapterWithinSegment({
    required String segmentID,
    required int fromIndex,
    required int toIndex,
  }) {
    updateSegmentsData((current) {
      final segmentIndex = _segmentIndexById(segmentID, current);
      if (segmentIndex < 0) {
        return current;
      }

      final segment = current[segmentIndex];
      if (fromIndex < 0 || fromIndex >= segment.chapters.length) {
        return current;
      }

      final normalizedTarget = toIndex.clamp(0, segment.chapters.length - 1);
      if (fromIndex == normalizedTarget) {
        return current;
      }

      final chapters = [...segment.chapters];
      final moving = chapters.removeAt(fromIndex);
      chapters.insert(normalizedTarget, moving);

      final next = [...current];
      next[segmentIndex] = segment.copyWith(chapters: chapters);
      return next;
    });
  }

  void moveChapterToSegment({
    required String chapterID,
    required String targetSegmentID,
  }) {
    updateSegmentsData((current) {
      int sourceSegmentIndex = -1;
      int sourceChapterIndex = -1;

      for (
        int segmentIndex = 0;
        segmentIndex < current.length;
        segmentIndex++
      ) {
        final chapterIndex = _chapterIndexById(
          chapterID,
          current[segmentIndex].chapters,
        );
        if (chapterIndex >= 0) {
          sourceSegmentIndex = segmentIndex;
          sourceChapterIndex = chapterIndex;
          break;
        }
      }

      final targetSegmentIndex = _segmentIndexById(targetSegmentID, current);
      if (sourceSegmentIndex < 0 ||
          sourceChapterIndex < 0 ||
          targetSegmentIndex < 0 ||
          sourceSegmentIndex == targetSegmentIndex) {
        return current;
      }

      final next = [...current];
      final sourceSegment = next[sourceSegmentIndex];
      final targetSegment = next[targetSegmentIndex];

      final sourceChapters = [...sourceSegment.chapters];
      final movingChapter = sourceChapters.removeAt(sourceChapterIndex);
      final targetChapters = [...targetSegment.chapters, movingChapter];

      next[sourceSegmentIndex] = sourceSegment.copyWith(
        chapters: sourceChapters,
      );
      next[targetSegmentIndex] = targetSegment.copyWith(
        chapters: targetChapters,
      );
      return next;
    });
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
    return List<outline_module.StorylineData>.unmodifiable(
      source
          .map(
            (storyline) => storyline.copyWith(
              people: [...storyline.people],
              item: [...storyline.item],
              scenes: storyline.scenes
                  .map(
                    (event) => event.copyWith(
                      people: [...event.people],
                      item: [...event.item],
                      scenes: event.scenes
                          .map(
                            (scene) => scene.copyWith(
                              people: [...scene.people],
                              item: [...scene.item],
                              doingThings: [...scene.doingThings],
                            ),
                          )
                          .toList(growable: false),
                    ),
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  List<outline_module.StorylineData> build() {
    return _createSnapshot(file_module.ProjectData.empty().outlineData);
  }

  void setOutlineData(List<outline_module.StorylineData> value) {
    state = _createSnapshot(value);
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

class WorldSettingsDataNotifier extends Notifier<List<LocationData>> {
  List<LocationData> _createSnapshot(List<LocationData> source) {
    return List<LocationData>.unmodifiable(
      source.map((location) => location.deepCopy()).toList(growable: false),
    );
  }

  List<LocationData> _copyLocations(List<LocationData> source) {
    return source.map((location) => location.deepCopy()).toList();
  }

  bool _updateLocationByIdRecursive(
    String id,
    List<LocationData> nodes,
    LocationData Function(LocationData current) update,
  ) {
    for (int index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      if (node.id == id) {
        final updated = update(node);
        if (updated == node) {
          return false;
        }
        nodes[index] = updated;
        return true;
      }

      if (_updateLocationByIdRecursive(id, node.child, update)) {
        return true;
      }
    }

    return false;
  }

  bool _addChildRecursive(
    String parentId,
    String name,
    List<LocationData> nodes,
  ) {
    for (final node in nodes) {
      if (node.id == parentId) {
        node.child.add(LocationData(localName: name));
        return true;
      }

      if (_addChildRecursive(parentId, name, node.child)) {
        return true;
      }
    }

    return false;
  }

  bool _removeNodeRecursive(String id, List<LocationData> nodes) {
    for (int index = 0; index < nodes.length; index++) {
      if (nodes[index].id == id) {
        nodes.removeAt(index);
        return true;
      }

      if (_removeNodeRecursive(id, nodes[index].child)) {
        return true;
      }
    }

    return false;
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

  bool _insertNodeByPosition({
    required List<LocationData> nodes,
    required String targetId,
    required String position,
    required LocationData sourceNode,
  }) {
    if (position == "child") {
      for (final node in nodes) {
        if (node.id == targetId) {
          node.child.add(sourceNode);
          return true;
        }
        if (_insertNodeByPosition(
          nodes: node.child,
          targetId: targetId,
          position: position,
          sourceNode: sourceNode,
        )) {
          return true;
        }
      }

      return false;
    }

    for (int index = 0; index < nodes.length; index++) {
      if (nodes[index].id == targetId) {
        if (position == "before") {
          nodes.insert(index, sourceNode);
          return true;
        }
        if (position == "after") {
          nodes.insert(index + 1, sourceNode);
          return true;
        }
        return false;
      }

      if (_insertNodeByPosition(
        nodes: nodes[index].child,
        targetId: targetId,
        position: position,
        sourceNode: sourceNode,
      )) {
        return true;
      }
    }

    return false;
  }

  @override
  List<LocationData> build() {
    return _createSnapshot(file_module.ProjectData.empty().worldSettingsData);
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
    final next = _copyLocations(state);
    final changed = _updateLocationByIdRecursive(id, next, update);
    if (!changed) {
      return false;
    }
    setWorldSettingsData(next);
    return true;
  }

  bool addLocation({required String name, String? parentId}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    final next = _copyLocations(state);
    final changed = parentId == null
        ? () {
            next.add(LocationData(localName: trimmed));
            return true;
          }()
        : _addChildRecursive(parentId, trimmed, next);

    if (!changed) {
      return false;
    }

    setWorldSettingsData(next);
    return true;
  }

  bool removeLocationById(String id) {
    final next = _copyLocations(state);
    final removed = _removeNodeRecursive(id, next);
    if (!removed) {
      return false;
    }

    setWorldSettingsData(next);
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

    final next = _copyLocations(state);
    final sourceNode = _findLocationByIdRecursive(sourceId, next);
    if (sourceNode == null) {
      return false;
    }

    if (_containsNodeById(sourceNode, targetId)) {
      return false;
    }

    final removed = _removeNodeRecursive(sourceId, next);
    if (!removed) {
      return false;
    }

    final inserted = _insertNodeByPosition(
      nodes: next,
      targetId: targetId,
      position: position,
      sourceNode: sourceNode,
    );
    if (!inserted) {
      next.add(sourceNode);
    }

    setWorldSettingsData(next);
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
    final copied = character_model.copyCharacterDataMap(source);
    return Map<String, character_model.CharacterEntryData>.unmodifiable(copied);
  }

  @override
  Map<String, character_model.CharacterEntryData> build() {
    return _createSnapshot(file_module.ProjectData.empty().characterData);
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
    required String name,
    required character_model.CharacterEntryData entry,
  }) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      return false;
    }

    final current = state[normalizedName];
    if (current == entry) {
      return false;
    }

    final next = character_model.copyCharacterDataMap(state);
    next[normalizedName] = entry.deepCopy();
    setCharacterData(next);
    return true;
  }

  bool updateCharacterEntry(
    String name,
    character_model.CharacterEntryData Function(
      character_model.CharacterEntryData current,
    )
    update,
  ) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      return false;
    }

    final current = state[normalizedName];
    if (current == null) {
      return false;
    }

    final updated = update(current.deepCopy());
    if (updated == current) {
      return false;
    }

    final next = character_model.copyCharacterDataMap(state);
    next[normalizedName] = updated.deepCopy();
    setCharacterData(next);
    return true;
  }

  bool removeCharacterEntry(String name) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty || !state.containsKey(normalizedName)) {
      return false;
    }

    final next = character_model.copyCharacterDataMap(state)
      ..remove(normalizedName);
    setCharacterData(next);
    return true;
  }

  bool renameCharacterEntry({
    required String oldName,
    required String newName,
  }) {
    final normalizedOldName = oldName.trim();
    final normalizedNewName = newName.trim();
    if (normalizedOldName.isEmpty || normalizedNewName.isEmpty) {
      return false;
    }
    if (normalizedOldName == normalizedNewName) {
      return false;
    }

    final entry = state[normalizedOldName];
    if (entry == null || state.containsKey(normalizedNewName)) {
      return false;
    }

    final next = character_model.copyCharacterDataMap(state)
      ..remove(normalizedOldName)
      ..[normalizedNewName] = entry.deepCopy();
    setCharacterData(next);
    return true;
  }
}

final characterDataProvider =
    NotifierProvider<
      CharacterDataNotifier,
      Map<String, character_model.CharacterEntryData>
    >(CharacterDataNotifier.new);

class ForeshadowDataNotifier
    extends Notifier<List<plan_module.ForeshadowItem>> {
  List<plan_module.ForeshadowItem> _createSnapshot(
    List<plan_module.ForeshadowItem> source,
  ) {
    return List<plan_module.ForeshadowItem>.unmodifiable(
      source.map((item) => item.copyWith()).toList(growable: false),
    );
  }

  @override
  List<plan_module.ForeshadowItem> build() {
    return _createSnapshot(file_module.ProjectData.empty().foreshadowData);
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
    return List<plan_module.UpdatePlanItem>.unmodifiable(
      source.map((item) => item.copyWith()).toList(growable: false),
    );
  }

  @override
  List<plan_module.UpdatePlanItem> build() {
    return _createSnapshot(file_module.ProjectData.empty().updatePlanData);
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
    final snapshot = _createSnapshot(value);
    state = snapshot;
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
        _copyEntryIndex(state.entryIndex);
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
        categoryTree: _copyCategoryTree(state.categoryTree),
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
    final GlossaryStateData snapshot = _createSnapshot(state);
    _persistDebounce = Timer(_persistDebounceDuration, () {
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
    _setIfChanged(value, schedulePersist: persist);
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

class CurrentProjectFileNotifier extends Notifier<file_module.ProjectFile?> {
  @override
  file_module.ProjectFile? build() {
    return null;
  }

  void setCurrentProjectFile(file_module.ProjectFile? value) {
    state = value;
  }
}

final currentProjectFileProvider =
    NotifierProvider<CurrentProjectFileNotifier, file_module.ProjectFile?>(
      CurrentProjectFileNotifier.new,
    );

final projectDataProvider = Provider<file_module.ProjectData>((ref) {
  return file_module.ProjectData(
    baseInfoData: ref.watch(baseInfoDataProvider),
    segmentsData: ref.watch(segmentsDataProvider),
    outlineData: ref.watch(outlineDataProvider),
    foreshadowData: ref.watch(foreshadowDataProvider),
    updatePlanData: ref.watch(updatePlanDataProvider),
    worldSettingsData: ref.watch(worldSettingsDataProvider),
    characterData: ref.watch(characterDataProvider),
    totalWords: ref.watch(totalWordsProvider),
    contentText: ref.watch(editorContentProvider),
  );
});
