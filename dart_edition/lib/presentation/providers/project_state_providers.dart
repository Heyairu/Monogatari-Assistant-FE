import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../bin/file.dart" as file_module;
import "../../modules/baseinfoview.dart" as base_info_module;
import "../../modules/chapterselectionview.dart" as chapter_module;
import "../../modules/glossaryview.dart" as glossary_module;
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
  @override
  base_info_module.BaseInfoData build() {
    return file_module.ProjectData.empty().baseInfoData;
  }

  void setBaseInfoData(base_info_module.BaseInfoData value) {
    state = value;
  }
}

final baseInfoDataProvider =
    NotifierProvider<BaseInfoDataNotifier, base_info_module.BaseInfoData>(
      BaseInfoDataNotifier.new,
    );

class SegmentsDataNotifier extends Notifier<List<chapter_module.SegmentData>> {
  @override
  List<chapter_module.SegmentData> build() {
    return file_module.ProjectData.empty().segmentsData;
  }

  void setSegmentsData(List<chapter_module.SegmentData> value) {
    state = value;
  }
}

final segmentsDataProvider =
    NotifierProvider<SegmentsDataNotifier, List<chapter_module.SegmentData>>(
      SegmentsDataNotifier.new,
    );

class OutlineDataNotifier extends Notifier<List<outline_module.StorylineData>> {
  @override
  List<outline_module.StorylineData> build() {
    return file_module.ProjectData.empty().outlineData;
  }

  void setOutlineData(List<outline_module.StorylineData> value) {
    state = value;
  }
}

final outlineDataProvider =
    NotifierProvider<OutlineDataNotifier, List<outline_module.StorylineData>>(
      OutlineDataNotifier.new,
    );

class WorldSettingsDataNotifier extends Notifier<List<LocationData>> {
  @override
  List<LocationData> build() {
    return file_module.ProjectData.empty().worldSettingsData;
  }

  void setWorldSettingsData(List<LocationData> value) {
    state = value;
  }
}

final worldSettingsDataProvider =
    NotifierProvider<WorldSettingsDataNotifier, List<LocationData>>(
      WorldSettingsDataNotifier.new,
    );

class CharacterDataNotifier
    extends Notifier<Map<String, Map<String, dynamic>>> {
  @override
  Map<String, Map<String, dynamic>> build() {
    return file_module.ProjectData.empty().characterData;
  }

  void setCharacterData(Map<String, Map<String, dynamic>> value) {
    state = value;
  }
}

final characterDataProvider =
    NotifierProvider<CharacterDataNotifier, Map<String, Map<String, dynamic>>>(
      CharacterDataNotifier.new,
    );

class ForeshadowDataNotifier extends Notifier<List<plan_module.ForeshadowItem>> {
  @override
  List<plan_module.ForeshadowItem> build() {
    return file_module.ProjectData.empty().foreshadowData;
  }

  void setForeshadowData(List<plan_module.ForeshadowItem> value) {
    state = value;
  }
}

final foreshadowDataProvider = NotifierProvider<ForeshadowDataNotifier,
    List<plan_module.ForeshadowItem>>(
  ForeshadowDataNotifier.new,
);

class UpdatePlanDataNotifier extends Notifier<List<plan_module.UpdatePlanItem>> {
  @override
  List<plan_module.UpdatePlanItem> build() {
    return file_module.ProjectData.empty().updatePlanData;
  }

  void setUpdatePlanData(List<plan_module.UpdatePlanItem> value) {
    state = value;
  }
}

final updatePlanDataProvider = NotifierProvider<UpdatePlanDataNotifier,
    List<plan_module.UpdatePlanItem>>(
  UpdatePlanDataNotifier.new,
);

class GlossaryStateData {
  final List<glossary_module.GlossaryCategory> categoryTree;
  final Map<String, glossary_module.GlossaryEntry> entryIndex;

  const GlossaryStateData({
    required this.categoryTree,
    required this.entryIndex,
  });
}

class GlossaryStateNotifier extends Notifier<GlossaryStateData> {
  @override
  GlossaryStateData build() {
    return const GlossaryStateData(
      categoryTree: [],
      entryIndex: {},
    );
  }

  void setGlossaryState(GlossaryStateData value) {
    state = value;
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
