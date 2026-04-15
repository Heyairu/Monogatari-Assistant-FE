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
}

final baseInfoDataProvider = StateProvider<base_info_module.BaseInfoData>((ref) {
  return file_module.ProjectData.empty().baseInfoData;
});

final segmentsDataProvider = StateProvider<List<chapter_module.SegmentData>>((ref) {
  return file_module.ProjectData.empty().segmentsData;
});

final outlineDataProvider =
    StateProvider<List<outline_module.StorylineData>>((ref) {
      return file_module.ProjectData.empty().outlineData;
    });

final worldSettingsDataProvider = StateProvider<List<LocationData>>((ref) {
  return file_module.ProjectData.empty().worldSettingsData;
});

final characterDataProvider =
    StateProvider<Map<String, Map<String, dynamic>>>((ref) {
      return file_module.ProjectData.empty().characterData;
    });

final foreshadowDataProvider =
    StateProvider<List<plan_module.ForeshadowItem>>((ref) {
      return file_module.ProjectData.empty().foreshadowData;
    });

final updatePlanDataProvider =
    StateProvider<List<plan_module.UpdatePlanItem>>((ref) {
      return file_module.ProjectData.empty().updatePlanData;
    });

class GlossaryStateData {
  final List<glossary_module.GlossaryCategory> categoryTree;
  final Map<String, glossary_module.GlossaryEntry> entryIndex;

  const GlossaryStateData({
    required this.categoryTree,
    required this.entryIndex,
  });
}

final glossaryStateProvider = StateProvider<GlossaryStateData>((ref) {
  return GlossaryStateData(
    categoryTree: const [],
    entryIndex: const {},
  );
});

final editorContentProvider = StateProvider<String>((ref) {
  return "";
});

final editorSelectionProvider = StateProvider<EditorSelectionState>((ref) {
  return const EditorSelectionState();
});

final totalWordsProvider = StateProvider<int>((ref) {
  return 0;
});

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
