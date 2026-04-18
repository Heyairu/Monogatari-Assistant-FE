import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../bin/file.dart" as file_module;
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

  @override
  base_info_module.BaseInfoData build() {
    return _createSnapshot(file_module.ProjectData.empty().baseInfoData);
  }

  void setBaseInfoData(base_info_module.BaseInfoData value) {
    state = _createSnapshot(value);
  }

  void updateBaseInfoData(
    base_info_module.BaseInfoData Function(
      base_info_module.BaseInfoData current,
    )
    update,
  ) {
    setBaseInfoData(update(state));
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

  @override
  List<chapter_module.SegmentData> build() {
    return _createSnapshot(file_module.ProjectData.empty().segmentsData);
  }

  void setSegmentsData(List<chapter_module.SegmentData> value) {
    state = _createSnapshot(value);
  }

  void updateSegmentsData(
    List<chapter_module.SegmentData> Function(
      List<chapter_module.SegmentData> current,
    )
    update,
  ) {
    setSegmentsData(update(state));
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

class GlossaryStateNotifier extends Notifier<GlossaryStateData> {
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

  @override
  GlossaryStateData build() {
    return _createSnapshot(
      const GlossaryStateData(categoryTree: [], entryIndex: {}),
    );
  }

  void setGlossaryState(GlossaryStateData value) {
    state = _createSnapshot(value);
  }

  void updateGlossaryState(
    GlossaryStateData Function(GlossaryStateData current) update,
  ) {
    setGlossaryState(update(state));
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
