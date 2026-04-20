import "package:flutter/material.dart";
import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../bin/file.dart" as file_module;
import "../../bin/file.dart";
import "../../bin/settings_manager.dart";
import "global_state_providers.dart";
import "project_io_providers.dart";
import "project_snapshot_utils.dart";
import "project_state_providers.dart";

class EditorProjectInitialState {
  final String? selectedSegID;
  final String? selectedChapID;
  final String contentText;
  final int totalWords;
  final bool hasSelection;

  const EditorProjectInitialState({
    this.selectedSegID,
    this.selectedChapID,
    required this.contentText,
    required this.totalWords,
    required this.hasSelection,
  });
}

class EditorCoordinatorState {
  final bool isLoading;
  final bool isSyncing;
  final bool isApplyingProjectData;
  final bool hasUnsavedChanges;
  final DateTime? lastSavedTime;
  final WordCountMode? wordCountMode;
  final int wordCountModeEventId;
  final int errorEventId;
  final String? errorMessage;
  final int messageEventId;
  final String? messageText;

  const EditorCoordinatorState({
    this.isLoading = false,
    this.isSyncing = false,
    this.isApplyingProjectData = false,
    this.hasUnsavedChanges = false,
    this.lastSavedTime,
    this.wordCountMode,
    this.wordCountModeEventId = 0,
    this.errorEventId = 0,
    this.errorMessage,
    this.messageEventId = 0,
    this.messageText,
  });

  EditorCoordinatorState copyWith({
    bool? isLoading,
    bool? isSyncing,
    bool? isApplyingProjectData,
    bool? hasUnsavedChanges,
    Object? lastSavedTime = _editorCoordinatorUnset,
    Object? wordCountMode = _editorCoordinatorUnset,
    int? wordCountModeEventId,
    int? errorEventId,
    Object? errorMessage = _editorCoordinatorUnset,
    int? messageEventId,
    Object? messageText = _editorCoordinatorUnset,
  }) {
    return EditorCoordinatorState(
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      isApplyingProjectData:
          isApplyingProjectData ?? this.isApplyingProjectData,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      lastSavedTime: identical(lastSavedTime, _editorCoordinatorUnset)
          ? this.lastSavedTime
          : lastSavedTime as DateTime?,
      wordCountMode: identical(wordCountMode, _editorCoordinatorUnset)
          ? this.wordCountMode
          : wordCountMode as WordCountMode?,
      wordCountModeEventId: wordCountModeEventId ?? this.wordCountModeEventId,
      errorEventId: errorEventId ?? this.errorEventId,
      errorMessage: identical(errorMessage, _editorCoordinatorUnset)
          ? this.errorMessage
          : errorMessage as String?,
      messageEventId: messageEventId ?? this.messageEventId,
      messageText: identical(messageText, _editorCoordinatorUnset)
          ? this.messageText
          : messageText as String?,
    );
  }
}

const Object _editorCoordinatorUnset = Object();

class EditorCoordinatorNotifier extends Notifier<EditorCoordinatorState> {
  bool _isSameStringList(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }

    for (int index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }

    return true;
  }

  bool _hasPersistedBaseInfoChanged(dynamic previous, dynamic next) {
    return previous.bookName != next.bookName ||
        previous.author != next.author ||
        previous.purpose != next.purpose ||
        previous.toRecap != next.toRecap ||
        previous.storyType != next.storyType ||
        previous.intro != next.intro ||
        !_isSameStringList(
          (previous.tags as List).cast<String>(),
          (next.tags as List).cast<String>(),
        );
  }

  bool _isSameOutlineData(List<dynamic> left, List<dynamic> right) {
    if (left.length != right.length) {
      return false;
    }

    for (int index = 0; index < left.length; index++) {
      if (!_isSameStoryline(left[index], right[index])) {
        return false;
      }
    }

    return true;
  }

  bool _isSameStoryline(dynamic left, dynamic right) {
    return left.chapterUUID == right.chapterUUID &&
        left.storylineName == right.storylineName &&
        left.storylineType == right.storylineType &&
        left.memo == right.memo &&
        left.conflictPoint == right.conflictPoint &&
        listEquals(left.people, right.people) &&
        listEquals(left.item, right.item) &&
        _isSameStoryEventList(left.scenes, right.scenes);
  }

  bool _isSameStoryEventList(List<dynamic> left, List<dynamic> right) {
    if (left.length != right.length) {
      return false;
    }

    for (int index = 0; index < left.length; index++) {
      if (!_isSameStoryEvent(left[index], right[index])) {
        return false;
      }
    }

    return true;
  }

  bool _isSameStoryEvent(dynamic left, dynamic right) {
    return left.storyEventUUID == right.storyEventUUID &&
        left.storyEvent == right.storyEvent &&
        left.memo == right.memo &&
        left.conflictPoint == right.conflictPoint &&
        listEquals(left.people, right.people) &&
        listEquals(left.item, right.item) &&
        _isSameSceneList(left.scenes, right.scenes);
  }

  bool _isSameSceneList(List<dynamic> left, List<dynamic> right) {
    if (left.length != right.length) {
      return false;
    }

    for (int index = 0; index < left.length; index++) {
      if (!_isSameScene(left[index], right[index])) {
        return false;
      }
    }

    return true;
  }

  bool _isSameScene(dynamic left, dynamic right) {
    return left.sceneUUID == right.sceneUUID &&
        left.sceneName == right.sceneName &&
        left.time == right.time &&
        left.location == right.location &&
        left.focusPoint == right.focusPoint &&
        left.conflictPoint == right.conflictPoint &&
        left.memo == right.memo &&
        listEquals(left.people, right.people) &&
        listEquals(left.item, right.item) &&
        listEquals(left.doingThings, right.doingThings);
  }

  void _markProjectDataChanged() {
    if (state.isApplyingProjectData || state.isSyncing) {
      return;
    }

    markAsModified();
  }

  void _setupProjectDirtyListeners() {
    ref.listen(baseInfoDataProvider, (previous, next) {
      if (previous == null || !_hasPersistedBaseInfoChanged(previous, next)) {
        return;
      }

      _markProjectDataChanged();
    });

    ref.listen(segmentsDataProvider, (previous, next) {
      if (previous == null || listEquals(previous, next)) {
        return;
      }

      _markProjectDataChanged();
    });

    ref.listen(outlineDataProvider, (previous, next) {
      if (previous == null || _isSameOutlineData(previous, next)) {
        return;
      }

      _markProjectDataChanged();
    });

    ref.listen(worldSettingsDataProvider, (previous, next) {
      if (previous == null || listEquals(previous, next)) {
        return;
      }

      _markProjectDataChanged();
    });

    ref.listen(characterDataProvider, (previous, next) {
      if (previous == null || mapEquals(previous, next)) {
        return;
      }

      _markProjectDataChanged();
    });

    ref.listen(foreshadowDataProvider, (previous, next) {
      if (previous == null || listEquals(previous, next)) {
        return;
      }

      _markProjectDataChanged();
    });

    ref.listen(updatePlanDataProvider, (previous, next) {
      if (previous == null || listEquals(previous, next)) {
        return;
      }

      _markProjectDataChanged();
    });
  }

  @override
  EditorCoordinatorState build() {
    final bool initialLoading = ref.read(projectIoControllerProvider).isLoading;
    final WordCountMode? initialWordCountMode = ref
        .read(settingsStateProvider)
        .valueOrNull
        ?.wordCountMode;

    ref.listen<AsyncValue<ProjectIoStatus>>(projectIoControllerProvider, (
      previous,
      next,
    ) {
      setLoading(next.isLoading);
    });

    ref.listen<AsyncValue<AppSettingsStateData>>(settingsStateProvider, (
      previous,
      next,
    ) {
      final previousMode = previous?.valueOrNull?.wordCountMode;
      final nextMode = next.valueOrNull?.wordCountMode;

      if (nextMode == null) {
        return;
      }

      if (previousMode == null) {
        if (state.wordCountMode != nextMode) {
          state = state.copyWith(wordCountMode: nextMode);
        }
        return;
      }

      if (previousMode != nextMode) {
        state = state.copyWith(
          wordCountMode: nextMode,
          wordCountModeEventId: state.wordCountModeEventId + 1,
        );
      }
    });

    _setupProjectDirtyListeners();

    return EditorCoordinatorState(
      isLoading: initialLoading,
      wordCountMode: initialWordCountMode,
    );
  }

  void setLoading(bool value) {
    if (state.isLoading == value) {
      return;
    }
    state = state.copyWith(isLoading: value);
  }

  bool beginSync() {
    if (state.isSyncing) {
      return false;
    }
    state = state.copyWith(isSyncing: true);
    return true;
  }

  void endSync() {
    if (!state.isSyncing) {
      return;
    }
    state = state.copyWith(isSyncing: false);
  }

  bool beginApplyingProjectData() {
    if (state.isApplyingProjectData) {
      return false;
    }
    state = state.copyWith(isApplyingProjectData: true);
    return true;
  }

  void endApplyingProjectData() {
    if (!state.isApplyingProjectData) {
      return;
    }
    state = state.copyWith(isApplyingProjectData: false);
  }

  void markAsModified() {
    if (state.isApplyingProjectData) {
      return;
    }

    final bool nextUnsaved = ProjectManager.markAsModified();
    if (state.hasUnsavedChanges == nextUnsaved) {
      return;
    }

    state = state.copyWith(hasUnsavedChanges: nextUnsaved);
  }

  void markAsSaved() {
    final bool nextUnsaved = ProjectManager.markAsSaved();
    state = state.copyWith(
      hasUnsavedChanges: nextUnsaved,
      lastSavedTime: DateTime.now(),
    );
  }

  void resetAfterProjectLoaded() {
    final bool nextUnsaved = ProjectManager.markAsSaved();
    state = state.copyWith(hasUnsavedChanges: nextUnsaved, lastSavedTime: null);
  }

  void clearLastSavedTime() {
    state = state.copyWith(lastSavedTime: null);
  }

  void handleEditorInputChanged({
    required String nextContent,
    required int cursorOffset,
  }) {
    if (state.isSyncing) {
      return;
    }

    final currentContent = ref.read(editorContentProvider);
    if (currentContent == nextContent) {
      updateCursorOffset(cursorOffset);
      return;
    }

    ref.read(editorContentProvider.notifier).setContent(nextContent);
    ref.read(editorSelectionProvider.notifier).setCursorOffset(cursorOffset);
    markAsModified();
  }

  void updateCursorOffset(int cursorOffset) {
    final currentCursorOffset = ref.read(editorSelectionProvider).cursorOffset;
    if (currentCursorOffset == cursorOffset) {
      return;
    }
    ref.read(editorSelectionProvider.notifier).setCursorOffset(cursorOffset);
  }

  void pushError(String message) {
    state = state.copyWith(
      errorEventId: state.errorEventId + 1,
      errorMessage: message,
    );
  }

  void clearError() {
    if (state.errorMessage == null) {
      return;
    }
    state = state.copyWith(errorMessage: null);
  }

  void pushMessage(String message) {
    state = state.copyWith(
      messageEventId: state.messageEventId + 1,
      messageText: message,
    );
  }

  void clearMessage() {
    if (state.messageText == null) {
      return;
    }
    state = state.copyWith(messageText: null);
  }

  Future<void> recordRecentProject(file_module.ProjectFile projectFile) async {
    try {
      var persistedAccessToken = projectFile.uri;
      if (projectFile.filePath != null) {
        final generatedToken = await FileService.createPersistentAccessToken(
          projectFile.filePath,
        );
        if (generatedToken != null && generatedToken.trim().isNotEmpty) {
          persistedAccessToken = generatedToken;
        }
      }

      await ref
          .read(settingsStateProvider.notifier)
          .addRecentProject(
            fileName: projectFile.fullFileName,
            filePath: projectFile.filePath,
            uri: persistedAccessToken,
          );
    } catch (error) {
      debugPrint("Failed to persist recent project state: $error");
    }
  }

  bool hasUnsavedChanges() {
    return ProjectManager.hasUnsavedChanges(state.hasUnsavedChanges);
  }

  EditorProjectInitialState calculateInitialState(
    file_module.ProjectData data,
    WordCountMode mode,
  ) {
    String? segID;
    String? chapID;
    String content = "";
    int words = 0;
    bool hasSel = false;

    if (data.segmentsData.isNotEmpty &&
        data.segmentsData[0].chapters.isNotEmpty) {
      segID = data.segmentsData[0].segmentUUID;
      chapID = data.segmentsData[0].chapters[0].chapterUUID;
      content = data.segmentsData[0].chapters[0].chapterContent;
      hasSel = true;
    }

    // Keep old behavior: defer expensive full-word-count recalculation.
    words = 0;

    return EditorProjectInitialState(
      selectedSegID: segID,
      selectedChapID: chapID,
      contentText: content,
      totalWords: words,
      hasSelection: hasSel,
    );
  }

  file_module.ProjectData collectProjectData() {
    return snapshotProjectData(
      file_module.ProjectData(
        baseInfoData: ref.read(baseInfoDataProvider),
        segmentsData: ref.read(segmentsDataProvider),
        outlineData: ref.read(outlineDataProvider),
        foreshadowData: ref.read(foreshadowDataProvider),
        updatePlanData: ref.read(updatePlanDataProvider),
        worldSettingsData: ref.read(worldSettingsDataProvider),
        characterData: ref.read(characterDataProvider),
        totalWords: ref.read(totalWordsProvider),
        contentText: ref.read(editorContentProvider),
      ),
    );
  }

  void applyProjectData({
    required file_module.ProjectData data,
    required EditorProjectInitialState initialState,
  }) {
    final snapshot = snapshotProjectData(data);

    ref
        .read(baseInfoDataProvider.notifier)
        .updateBaseInfoData((_) => snapshot.baseInfoData);
    ref
        .read(segmentsDataProvider.notifier)
        .updateSegmentsData((_) => snapshot.segmentsData);
    ref
        .read(outlineDataProvider.notifier)
        .updateOutlineData((_) => snapshot.outlineData);
    ref
        .read(foreshadowDataProvider.notifier)
        .updateForeshadowData((_) => snapshot.foreshadowData);
    ref
        .read(updatePlanDataProvider.notifier)
        .updateUpdatePlanData((_) => snapshot.updatePlanData);
    ref
        .read(worldSettingsDataProvider.notifier)
        .updateWorldSettingsData((_) => snapshot.worldSettingsData);
    ref
        .read(characterDataProvider.notifier)
        .updateCharacterData((_) => snapshot.characterData);

    ref
        .read(editorSelectionProvider.notifier)
        .setSelectionAndCursor(
          selectedSegID: initialState.selectedSegID,
          selectedChapID: initialState.selectedChapID,
          cursorOffset: 0,
        );
    ref
        .read(editorContentProvider.notifier)
        .setContent(initialState.contentText);
    ref
        .read(totalWordsProvider.notifier)
        .setTotalWords(initialState.totalWords);
  }

  void syncEditorToSelectedChapter({
    required TextEditingController textController,
  }) {
    if (!beginSync()) {
      return;
    }

    try {
      final editorSelection = ref.read(editorSelectionProvider);
      final copiedSegments = snapshotSegmentsData(
        ref.read(segmentsDataProvider),
      );

      String? syncedContent;
      ProjectManager.syncEditorToSelectedChapter(
        segmentsData: copiedSegments,
        selectedSegID: editorSelection.selectedSegID,
        selectedChapID: editorSelection.selectedChapID,
        textController: textController,
        updateContentCallback: (String newContent) {
          syncedContent = newContent;
        },
      );

      ref
          .read(segmentsDataProvider.notifier)
          .updateSegmentsData((_) => copiedSegments);
      if (syncedContent != null) {
        ref.read(editorContentProvider.notifier).setContent(syncedContent!);
      }
    } finally {
      endSync();
    }
  }
}

final editorCoordinatorProvider =
    NotifierProvider<EditorCoordinatorNotifier, EditorCoordinatorState>(
      EditorCoordinatorNotifier.new,
    );
