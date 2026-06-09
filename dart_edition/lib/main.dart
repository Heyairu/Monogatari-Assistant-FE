/*
 * ものがたり·アシスタント - Monogatari Assistant
 * Copyright (c) 2025 Heyairu（部屋伊琉）
 *
 * Licensed under the Business Source License 1.1 (Modified).
 * You may not use this file except in compliance with the License.
 * Change Date: 2030-11-04 05:14 a.m. (UTC+8)
 * Change License: Apache License 2.0
 *
 * Commercial use allowed under conditions described in Section 1;
 * Competing products (≥3 overlapping modules or similar UI structure)
 * and repackaging without permission are prohibited.
 */

import "dart:math";
import "dart:async"; // Added for Timer

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart"; // Add intl for date formatting
import "package:window_manager/window_manager.dart";
import "bin/appbar.dart";
import "bin/statusbar.dart";
import "bin/slidebar.dart";
import "bin/content.dart";
import "bin/mobile_function_page.dart";
import "bin/file.dart";
import "bin/findreplace.dart";
import "bin/punctuation_panel.dart";
import "bin/ui_library.dart";
import "bin/settings_manager.dart";
import "bin/content_manager.dart";
import "presentation/providers/editor_coordinator_provider.dart";
import "presentation/providers/global_state_providers.dart";
import "presentation/providers/project_io_providers.dart";
import "presentation/providers/project_history_provider.dart";
import "presentation/providers/project_state_providers.dart";
import "presentation/providers/word_count_providers.dart";
import "utils/text_change_debouncer.dart";
import "utils/text_position_index.dart";

import "modules/baseinfoview.dart" as BaseInfoModule;
import "modules/chapterselectionview.dart" as ChapterModule;
import "modules/AboutView.dart" as AboutModule;
import "modules/glossaryview.dart" as GlossaryModule;
import "modules/outlineview.dart" as OutlineModule;
import "modules/planview.dart" as PlanModule;
import "modules/proofreadingview.dart" as ProofReadingModule;
import "modules/copliot.dart" as copilot_module;
import "modules/WelcomeView.dart" as WelcomeModule;
import "modules/worldsettingsview.dart";
import "modules/characterview.dart";
import "modules/settingview.dart";

typedef _CoordinatorUiEventState = ({
  int messageEventId,
  String? messageText,
  int wordCountModeEventId,
  int errorEventId,
  String? errorMessage,
});

class _ProjectIoBusyIndicator extends ConsumerWidget {
  const _ProjectIoBusyIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBusy = ref.watch(
      projectIoControllerProvider.select(
        (value) => value.valueOrNull?.isBusy ?? value.isLoading,
      ),
    );

    if (!isBusy) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化 window_manager
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    await windowManager.ensureInitialized();
  }

  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  ThemeMode _convertThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(appInitializationProvider);

    if (bootstrap.isLoading) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text("正在載入..."),
              ],
            ),
          ),
        ),
      );
    }

    if (bootstrap.hasError) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text("初始化失敗：${bootstrap.error}"),
            ),
          ),
        ),
      );
    }

    final theme = ref.watch(appThemeSettingsProvider);

    return MaterialApp(
      title: "物語Assistant",
      theme: AppTheme.getLightTheme(theme.fontSize, theme.color),
      darkTheme: AppTheme.getDarkTheme(theme.fontSize, theme.color),
      themeMode: _convertThemeMode(theme.mode),
      home: const ContentView(),
    );
  }
}

// 數據模型類別（BaseInfoData, ChapterData, SegmentData 現在從模組導入）

class SimpleLocation {
  String localName;
  String description;
  String locationUUID;

  SimpleLocation({
    required this.localName,
    this.description = "",
    String? locationUUID,
  }) : locationUUID =
           locationUUID ?? DateTime.now().millisecondsSinceEpoch.toString();
}

// Intent classes for keyboard shortcuts
class NewFileIntent extends Intent {
  const NewFileIntent();
}

class OpenFileIntent extends Intent {
  const OpenFileIntent();
}

class SaveFileIntent extends Intent {
  const SaveFileIntent();
}

class FindIntent extends Intent {
  const FindIntent();
}

class UndoProjectIntent extends Intent {
  const UndoProjectIntent();
}

class RedoProjectIntent extends Intent {
  const RedoProjectIntent();
}

// 主要 ContentView
class ContentView extends ConsumerStatefulWidget {
  const ContentView({super.key});

  @override
  ConsumerState<ContentView> createState() => _ContentViewState();
}

class _ContentViewState extends ConsumerState<ContentView> with WindowListener {
  /// 全專案字數批次重算時，同時進行的 `compute` 上限（每章仍各自 isolate）。
  static const int _maxConcurrentChapterWordCounts = 6;

  // 狀態變數
  int slidePageCounts = 14;
  int slidePageIndexCurrent = 0;
  int slidePageIndexNow = 0;
  int autoSaveTime = 1;
  double _sidebarWidthRatio = 0.25; // Default sidebar width ratio (25%)

  int _allWordCountsGen = 0;

  // 主編輯器文字
  String get contentText => ref.read(editorContentProvider);
  set contentText(String value) {
    _cancelPendingContentCommit();
    ref.read(editorContentProvider.notifier).setContent(value);
  }

  final HighlightTextEditingController textController =
      HighlightTextEditingController();
  String _lastObservedEditorText = "";
  TextPositionIndex _textPositionIndex = TextPositionIndex.empty();

  // 浮動視窗狀態
  bool showFindReplaceWindow = false;
  bool showPunctuationPanel = false;
  final TextEditingController findController = TextEditingController();
  final TextEditingController replaceController = TextEditingController();
  final FindReplaceOptions findReplaceOptions = FindReplaceOptions();
  final FocusNode editorFocusNode = FocusNode();

  // 搜尋狀態
  int _currentMatchIndex = -1;
  List<TextSelection> _searchMatches = [];

  AppSettingsStateData get _settingsState =>
      ref.read(settingsStateProvider).valueOrNull ??
      const AppSettingsStateData();

  EditorCoordinatorState get _editorCoordinatorState =>
      ref.read(editorCoordinatorProvider);

  EditorCoordinatorNotifier get _editorCoordinatorNotifier =>
      ref.read(editorCoordinatorProvider.notifier);

  bool get isLoading => _editorCoordinatorState.isLoading;
  bool get _isSyncing => _editorCoordinatorState.isSyncing;
  bool get hasUnsavedChanges => _editorCoordinatorState.hasUnsavedChanges;

  final List<ProviderSubscription<Object?>> _subscriptions = [];

  late final TextChangeDebouncer _textChangeDebouncer;
  Timer? _projectHistoryRecordTimer;
  bool _isApplyingProjectHistory = false;
  static const Duration _projectHistoryRecordDelay = Duration(
    milliseconds: 500,
  );

  List<ChapterModule.SegmentData> get segmentsData =>
      ref.read(segmentsDataProvider);

  // 選取狀態
  String? get selectedSegID => ref.read(editorSelectionProvider).selectedSegID;

  String? get selectedChapID =>
      ref.read(editorSelectionProvider).selectedChapID;

  int _proofreadingChapterSwitchVersion = 0;
  int get totalWords => ref.read(totalWordsProvider);
  set totalWords(int value) {
    ref.read(totalWordsProvider.notifier).setTotalWords(value);
  }

  int get _cursorOffset => ref.read(editorSelectionProvider).cursorOffset;

  ProjectFile? get currentProject => ref.read(currentProjectFileProvider);
  set currentProject(ProjectFile? value) {
    ref.read(currentProjectFileProvider.notifier).setCurrentProjectFile(value);
  }

  // 檔案狀態

  // 追蹤最後一個焦點輸入框
  FocusNode? _lastFocusedEditableNode;
  bool _preserveEditableFocusForEditorAction = false;

  void _onFocusChange() {
    final node = WidgetsBinding.instance.focusManager.primaryFocus;
    final previousEditableNode = _lastFocusedEditableNode;
    final focusChangedFromEditable =
        previousEditableNode != null && previousEditableNode != node;

    if (focusChangedFromEditable) {
      _recordProjectHistorySnapshot();
    }

    if (node != null && _findEditableForFocusNode(node) != null) {
      // 焦點進入編輯框
      _lastFocusedEditableNode = node;
      debugPrint("[DEBUG] Focus on editable: $node");
    } else if (node != null && node.canRequestFocus) {
      // 焦點轉移到其他可請求焦點的 widget（非編輯框、非功能按鈕）
      debugPrint("[DEBUG] Focus moved away from editable to: $node");
      if (_preserveEditableFocusForEditorAction) {
        debugPrint("[DEBUG] Preserving editable focus for editor action");
        return;
      }
      _clearEditableFocus();
    }
  }

  void _prepareEditorToolbarAction() {
    _preserveEditableFocusForEditorAction = true;
  }

  void _finishEditorToolbarAction() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preserveEditableFocusForEditorAction = false;
    });
  }

  void _clearEditableFocus() {
    debugPrint("[DEBUG] Clearing editable focus");

    final lastFocusedEditableNode = _lastFocusedEditableNode;
    _lastFocusedEditableNode = null;

    if (lastFocusedEditableNode != null && lastFocusedEditableNode.hasFocus) {
      lastFocusedEditableNode.unfocus();
    }

    _clearAllSelections();
  }

  void _clearAllSelections() {
    debugPrint("[DEBUG] Clearing all selections");

    // 清除主編輯器的選取
    if (textController.selection.isValid &&
        !textController.selection.isCollapsed) {
      textController.selection = TextSelection.collapsed(
        offset: textController.selection.baseOffset,
      );
    }

    // 清除搜尋欄的選取
    if (findController.selection.isValid &&
        !findController.selection.isCollapsed) {
      findController.selection = TextSelection.collapsed(
        offset: findController.selection.baseOffset,
      );
    }

    if (replaceController.selection.isValid &&
        !replaceController.selection.isCollapsed) {
      replaceController.selection = TextSelection.collapsed(
        offset: replaceController.selection.baseOffset,
      );
    }
  }

  int _clampOffset(int offset, int textLength) {
    if (offset < 0) {
      return 0;
    }
    return offset.clamp(0, textLength);
  }

  TextSelection _clampSelection(TextSelection selection, String text) {
    final int textLength = text.length;
    if (!selection.isValid) {
      return const TextSelection.collapsed(offset: 0);
    }

    final int base = _clampOffset(selection.baseOffset, textLength);
    final int extent = _clampOffset(selection.extentOffset, textLength);

    return TextSelection(
      baseOffset: base,
      extentOffset: extent,
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );
  }

  void _bootstrapEditorSelectionFromProviderState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final selectionState = ref.read(editorSelectionProvider);
      final segments = ref.read(segmentsDataProvider);

      String? selectedSegID = selectionState.selectedSegID;
      String? selectedChapID = selectionState.selectedChapID;
      String initialContent = ref.read(editorContentProvider);

      if ((selectedSegID == null || selectedChapID == null) &&
          segments.isNotEmpty &&
          segments[0].chapters.isNotEmpty) {
        selectedSegID = segments[0].segmentUUID;
        selectedChapID = segments[0].chapters[0].chapterUUID;
        initialContent = segments[0].chapters[0].chapterContent;
      }

      final int cursorOffset = _clampOffset(
        selectionState.cursorOffset,
        initialContent.length,
      );

      final editorSelectionNotifier = ref.read(
        editorSelectionProvider.notifier,
      );
      editorSelectionNotifier.setSelectionAndCursor(
        selectedSegID: selectedSegID,
        selectedChapID: selectedChapID,
        cursorOffset: cursorOffset,
      );

      final editorContentNotifier = ref.read(editorContentProvider.notifier);
      if (ref.read(editorContentProvider) != initialContent) {
        editorContentNotifier.setContent(initialContent);
      }

      if (textController.text != initialContent) {
        textController.text = initialContent;
      }
      _lastObservedEditorText = textController.text;
      _textPositionIndex = _textPositionIndex.rebuildIfTextChanged(
        textController.text,
      );

      _refreshActiveChapterWordCount();
    });
  }

  void _refreshActiveChapterWordCount() {
    final String? activeChapterId = selectedChapID;
    final activeWordCountNotifier = ref.read(
      activeChapterWordCountProvider.notifier,
    );
    if (activeChapterId == null) {
      activeWordCountNotifier.reset();
      return;
    }

    final WordCountMode mode = _settingsState.wordCountMode;
    final String activeText = textController.text;
    final ChapterModule.ChapterData? activeChapter = _findChapterById(
      selectedSegID,
      activeChapterId,
    );
    final int count = activeChapter?.chapterContent == activeText
        ? activeChapter!.getWordCount(mode)
        : ContentManager.calculateWordCount(activeText, mode: mode);

    activeWordCountNotifier.refreshFromCount(
      chapterId: activeChapterId,
      count: count,
    );
  }

  ChapterModule.ChapterData? _findChapterById(
    String? segmentId,
    String chapterId,
  ) {
    for (final seg in segmentsData) {
      if (segmentId != null && seg.segmentUUID != segmentId) {
        continue;
      }
      for (final chap in seg.chapters) {
        if (chap.chapterUUID == chapterId) {
          return chap;
        }
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();

    _textChangeDebouncer = TextChangeDebouncer(
      onWordCountTrigger: (nextContent) {
        _flushPendingEditorContent();
        final int gen = ++_activeWordCountGen;
        final String? selectedSegIDSnapshot = selectedSegID;
        final String? selectedChapIDSnapshot = selectedChapID;
        final WordCountMode modeSnapshot = _settingsState.wordCountMode;

        _updateActiveWordCountAsync(
          gen: gen,
          selectedSegIDSnapshot: selectedSegIDSnapshot,
          selectedChapIDSnapshot: selectedChapIDSnapshot,
          textSnapshot: nextContent,
          modeSnapshot: modeSnapshot,
        );
        _recordProjectHistorySnapshot();
      },
      onContentCommitTrigger: (nextContent) {
        if (!mounted) return;
        if (ref.read(editorContentProvider) == nextContent) return;
        ref.read(editorContentProvider.notifier).setContent(nextContent);
      },
    );

    // 註冊視窗監聽器並設置視窗選項
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      windowManager.addListener(this);
      _initWindowManager();
    }

    _bootstrapEditorSelectionFromProviderState();

    // 監聽文字變化
    textController.addListener(() {
      final int selectionOffset = textController.selection.baseOffset;
      final int normalizedOffset = _clampOffset(
        selectionOffset,
        textController.text.length,
      );
      final String currentText = textController.text;
      _textPositionIndex = _textPositionIndex.rebuildIfTextChanged(currentText);
      final bool textChanged =
          !_isSyncing && _lastObservedEditorText != currentText;

      // 將輸入事件轉交 coordinator，UI listener 僅保留畫面刷新職責。
      if (textChanged) {
        _lastObservedEditorText = currentText;
        _editorCoordinatorNotifier.updateCursorOffset(normalizedOffset);
        _editorCoordinatorNotifier.markAsModified();

        _textChangeDebouncer.onTextChanged(currentText);

        // 當文字內容變化時，清除所有高亮和搜尋狀態
        if (_searchMatches.isNotEmpty || _currentMatchIndex != -1) {
          setState(() {
            _searchMatches = [];
            _currentMatchIndex = -1;
            textController.clearAllHighlights();
          });
        }
      } else if (_cursorOffset != normalizedOffset) {
        _editorCoordinatorNotifier.updateCursorOffset(normalizedOffset);
      }
    });

    // 啟動時不自動建立新專案，避免與使用者手動開檔流程競態。

    _subscriptions.add(
      ref.listenManual<String>(editorContentProvider, (previous, next) {
        if (!mounted || _isSyncing || textController.text == next) {
          return;
        }

        final currentSelection = _clampSelection(
          textController.selection,
          next,
        );

        final coordinatorNotifier = ref.read(
          editorCoordinatorProvider.notifier,
        );
        final beganSync = coordinatorNotifier.beginSync();
        try {
          textController.value = textController.value.copyWith(
            text: next,
            selection: currentSelection,
            composing: TextRange.empty,
          );
          _lastObservedEditorText = next;
          _textPositionIndex = _textPositionIndex.rebuildIfTextChanged(next);
        } finally {
          if (beganSync) {
            coordinatorNotifier.endSync();
          }
        }

        _refreshActiveChapterWordCount();
      }),
    );

    _subscriptions.add(
      ref.listenManual<EditorSelectionState>(editorSelectionProvider, (
        previous,
        next,
      ) {
        if (!mounted) {
          return;
        }
        if (previous?.selectedChapID == next.selectedChapID &&
            previous?.selectedSegID == next.selectedSegID) {
          return;
        }
        _refreshActiveChapterWordCount();
      }),
    );

    _subscriptions.add(
      ref.listenManual<List<ChapterModule.SegmentData>>(segmentsDataProvider, (
        previous,
        next,
      ) {
        if (!mounted || previous == null || previous == next) {
          return;
        }

        if (ref.read(editorCoordinatorProvider).isApplyingProjectData) {
          return;
        }

        setState(() {
          totalWords = _recalculateSumFast();
        });
      }),
    );

    _subscriptions.add(
      ref.listenManual<int>(projectDataAggregateProvider, (previous, next) {
        if (!mounted ||
            previous == null ||
            previous == next ||
            _isApplyingProjectHistory ||
            ref.read(editorCoordinatorProvider).isApplyingProjectData) {
          return;
        }

        _scheduleProjectHistoryRecord();
      }),
    );

    _subscriptions.add(
      ref.listenManual<_CoordinatorUiEventState>(
        editorCoordinatorProvider.select(
          (state) => (
            messageEventId: state.messageEventId,
            messageText: state.messageText,
            wordCountModeEventId: state.wordCountModeEventId,
            errorEventId: state.errorEventId,
            errorMessage: state.errorMessage,
          ),
        ),
        (previous, next) {
          if (!mounted) {
            return;
          }

          if (previous?.messageEventId != next.messageEventId &&
              next.messageText != null &&
              next.messageText!.isNotEmpty) {
            final int messageEventId = next.messageEventId;
            final snackMessage = next.messageText!;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(snackMessage),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                ),
              );
              if (mounted &&
                  ref.read(editorCoordinatorProvider).messageEventId ==
                      messageEventId) {
                _editorCoordinatorNotifier.clearMessage();
              }
            });
          }

          if (previous?.wordCountModeEventId != next.wordCountModeEventId) {
            _onSettingsChanged();
          }

          if (previous?.errorEventId != next.errorEventId &&
              next.errorMessage != null &&
              next.errorMessage!.isNotEmpty) {
            final int errorEventId = next.errorEventId;
            final dialogMessage = next.errorMessage!;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) {
                return;
              }
              await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("錯誤"),
                  content: Text(dialogMessage),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("確定"),
                    ),
                  ],
                ),
              );

              if (mounted &&
                  ref.read(editorCoordinatorProvider).errorEventId ==
                      errorEventId) {
                _editorCoordinatorNotifier.clearError();
              }
            });
          }
        },
      ),
    );

    // 監聽焦點變化
    WidgetsBinding.instance.focusManager.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _cancelPendingContentCommit();
    _projectHistoryRecordTimer?.cancel();
    _projectHistoryRecordTimer = null;
    _activeWordCountGen++;
    _allWordCountsGen++;
    _closeProviderSubscriptions();
    WidgetsBinding.instance.focusManager.removeListener(_onFocusChange);
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      windowManager.removeListener(this);
    }
    _textChangeDebouncer.cancelAll();
    textController.dispose();
    findController.dispose();
    replaceController.dispose();
    editorFocusNode.dispose();
    super.dispose();
  }

  void _closeProviderSubscriptions() {
    for (final subscription in List<ProviderSubscription<Object?>>.of(
      _subscriptions,
    )) {
      try {
        subscription.close();
      } catch (error, stackTrace) {
        debugPrint(
          'Failed to close provider subscription: $error\n$stackTrace',
        );
      }
    }
    _subscriptions.clear();
  }

  int _activeWordCountGen = 0;

  void _flushPendingEditorContent() {
    _textChangeDebouncer.flushPendingContentCommit();
  }

  void _cancelPendingContentCommit() {
    _textChangeDebouncer.cancelAll();
  }

  void _scheduleProjectHistoryRecord() {
    if (_isApplyingProjectHistory) {
      return;
    }

    _projectHistoryRecordTimer?.cancel();
    _projectHistoryRecordTimer = Timer(_projectHistoryRecordDelay, () {
      _projectHistoryRecordTimer = null;
      _recordProjectHistorySnapshot();
    });
  }

  ProjectHistoryEntry _createProjectHistoryEntry(ProjectData data) {
    final selection = ref.read(editorSelectionProvider);
    final int cursorOffset = textController.selection.isValid
        ? _clampOffset(
            textController.selection.baseOffset,
            textController.text.length,
          )
        : selection.cursorOffset;

    return ProjectHistoryEntry(
      data: data,
      pageIndex: slidePageIndexNow,
      selectedSegID: selection.selectedSegID,
      selectedChapID: selection.selectedChapID,
      cursorOffset: cursorOffset,
    );
  }

  void _recordProjectHistorySnapshot({bool reset = false}) {
    if (!mounted || _isApplyingProjectHistory) {
      return;
    }

    _projectHistoryRecordTimer?.cancel();
    _projectHistoryRecordTimer = null;
    _syncEditorToSelectedChapter();

    final entry = _createProjectHistoryEntry(_collectProjectData());
    final historyNotifier = ref.read(projectHistoryProvider.notifier);
    if (reset) {
      historyNotifier.reset(entry);
    } else {
      historyNotifier.record(entry);
    }
  }

  void _resetProjectHistory() {
    _recordProjectHistorySnapshot(reset: true);
  }

  EditorProjectInitialState _initialStateForHistoryEntry(
    ProjectHistoryEntry entry,
  ) {
    final fallback = ref
        .read(editorCoordinatorProvider.notifier)
        .calculateInitialState(entry.data, _settingsState.wordCountMode);

    final String? targetSegID = entry.selectedSegID ?? fallback.selectedSegID;
    final String? targetChapID =
        entry.selectedChapID ?? fallback.selectedChapID;
    String content = fallback.contentText;
    bool hasSelection = fallback.hasSelection;
    bool foundTargetChapter = false;

    if (targetChapID != null) {
      for (final segment in entry.data.segmentsData) {
        if (targetSegID != null && segment.segmentUUID != targetSegID) {
          continue;
        }
        for (final chapter in segment.chapters) {
          if (chapter.chapterUUID == targetChapID) {
            content = chapter.chapterContent;
            hasSelection = true;
            foundTargetChapter = true;
            break;
          }
        }
        if (foundTargetChapter) {
          break;
        }
      }
    }

    return EditorProjectInitialState(
      selectedSegID: targetSegID,
      selectedChapID: targetChapID,
      contentText: content,
      totalWords: entry.data.totalWords,
      hasSelection: hasSelection,
      cursorOffset: _clampOffset(entry.cursorOffset, content.length),
    );
  }

  void _applyProjectHistoryEntry(ProjectHistoryEntry entry) {
    if (!mounted) {
      return;
    }

    _projectHistoryRecordTimer?.cancel();
    _projectHistoryRecordTimer = null;
    _isApplyingProjectHistory = true;
    final initialState = _initialStateForHistoryEntry(entry);

    setState(() {
      slidePageIndexNow = entry.pageIndex < 0 ? 0 : entry.pageIndex;
      _applyProjectData(entry.data, initialState);
    });

    _updateAllWordCounts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _isApplyingProjectHistory = false;
      _editorCoordinatorNotifier.markAsModified();
    });
  }

  void _undoProjectHistory() {
    if (_isApplyingProjectHistory) {
      return;
    }

    _syncEditorToSelectedChapter();
    final currentEntry = _createProjectHistoryEntry(_collectProjectData());
    final target = ref.read(projectHistoryProvider.notifier).undo(currentEntry);
    if (target == null) {
      return;
    }

    _applyProjectHistoryEntry(target);
  }

  void _redoProjectHistory() {
    if (_isApplyingProjectHistory) {
      return;
    }

    _syncEditorToSelectedChapter();
    final currentEntry = _createProjectHistoryEntry(_collectProjectData());
    final target = ref.read(projectHistoryProvider.notifier).redo(currentEntry);
    if (target == null) {
      return;
    }

    _applyProjectHistoryEntry(target);
  }

  Future<void> _updateActiveWordCountAsync({
    required int gen,
    required String? selectedSegIDSnapshot,
    required String? selectedChapIDSnapshot,
    required String textSnapshot,
    required WordCountMode modeSnapshot,
  }) async {
    if (selectedSegIDSnapshot == null || selectedChapIDSnapshot == null) {
      return;
    }

    // Use Isolate to calculate word count for active chapter only
    final count = await ContentManager.calculateWordCountAsync(
      textSnapshot,
      mode: modeSnapshot,
    );

    if (!mounted || gen != _activeWordCountGen) return;
    if (selectedSegID != selectedSegIDSnapshot ||
        selectedChapID != selectedChapIDSnapshot) {
      return;
    }
    if (textController.text != textSnapshot ||
        _settingsState.wordCountMode != modeSnapshot) {
      return;
    }

    setState(() {
      // Update cache for the active chapter
      for (final seg in segmentsData) {
        if (seg.segmentUUID == selectedSegIDSnapshot) {
          for (final chap in seg.chapters) {
            if (chap.chapterUUID == selectedChapIDSnapshot) {
              // Update the cached value in ChapterData
              // Note: We are updating the cache associated with the object which might have stale content string
              // but this is the correct "current" count for the UI.
              chap.updateCachedWordCount(count, modeSnapshot);
              break;
            }
          }
        }
      }

      // Re-sum using cached values (Fast)
      totalWords = _recalculateSumFast();
    });

    ref
        .read(activeChapterWordCountProvider.notifier)
        .refreshFromCount(chapterId: selectedChapIDSnapshot, count: count);
  }

  Future<void> _updateAllWordCounts() async {
    final int gen = ++_allWordCountsGen;
    final WordCountMode mode = _settingsState.wordCountMode;

    final List<
      ({
        ChapterModule.ChapterData chap,
        String snapshotContent,
        WordCountMode snapshotMode,
      })
    >
    jobs = [];

    for (final ChapterModule.SegmentData seg in segmentsData) {
      for (final ChapterModule.ChapterData chap in seg.chapters) {
        jobs.add((
          chap: chap,
          snapshotContent: chap.chapterContent,
          snapshotMode: mode,
        ));
      }
    }

    for (
      var start = 0;
      start < jobs.length;
      start += _maxConcurrentChapterWordCounts
    ) {
      if (!mounted || gen != _allWordCountsGen) {
        return;
      }

      final int end = (start + _maxConcurrentChapterWordCounts)
          .clamp(0, jobs.length)
          .toInt();
      final slice = jobs.sublist(start, end);

      await Future.wait(
        slice.map((job) async {
          if (!mounted || gen != _allWordCountsGen) {
            return;
          }

          if (job.snapshotContent.isEmpty) {
            job.chap.updateCachedWordCount(0, job.snapshotMode);
            return;
          }

          final int count = await ContentManager.calculateWordCountAsync(
            job.snapshotContent,
            mode: job.snapshotMode,
          );

          if (!mounted || gen != _allWordCountsGen) {
            return;
          }

          if (job.snapshotMode != _settingsState.wordCountMode) {
            return;
          }

          if (job.chap.chapterContent != job.snapshotContent) {
            return;
          }

          job.chap.updateCachedWordCount(count, job.snapshotMode);
        }),
      );
    }

    if (mounted && gen == _allWordCountsGen) {
      setState(() {
        totalWords = _recalculateSumFast();
      });
    }
  }

  int _recalculateSumFast() {
    int sum = 0;
    for (final seg in segmentsData) {
      for (final chap in seg.chapters) {
        // use getWordCount for reading. It will use cache if available.
        // If cache is null (first load and async hasn't finished), it might calc sync.
        // But we try to rely on async updates.
        sum += chap.getWordCount(_settingsState.wordCountMode);
      }
    }
    return sum;
  }

  void _onSettingsChanged() {
    // When settings change (e.g. counting mode), recalculate all
    _updateAllWordCounts();
    _refreshActiveChapterWordCount();
  }

  // WindowListener 實作

  /// 初始化視窗管理器
  Future<void> _initWindowManager() async {
    // 設置視窗為可以被攔截關閉
    await windowManager.setPreventClose(true);
  }

  @override
  void onWindowClose() async {
    // 處理視窗關閉事件
    final shouldClose = await _handleExit();
    if (shouldClose) {
      await windowManager.destroy();
    }
  }

  @override
  void onWindowFocus() {
    // 視窗獲得焦點時可以做一些事情（暫時不需要）
  }

  @override
  void onWindowBlur() {
    // 視窗失去焦點時可以做一些事情（暫時不需要）
  }

  @override
  void onWindowMaximize() {}

  @override
  void onWindowUnmaximize() {}

  @override
  void onWindowMinimize() {}

  @override
  void onWindowRestore() {}

  @override
  void onWindowResize() {}

  @override
  void onWindowMove() {}

  @override
  void onWindowEnterFullScreen() {}

  @override
  void onWindowLeaveFullScreen() {}

  @override
  void onWindowEvent(String eventName) {}

  @override
  void onWindowDocked() {}

  @override
  void onWindowUndocked() {}

  // MARK: 主體建構方法
  @override
  Widget build(BuildContext context) {
    final fontSize = ref.watch(
      settingsStateProvider.select(
        (state) => state.valueOrNull?.fontSize ?? 12.0,
      ),
    );
    final wordCountMode = ref.watch(
      settingsStateProvider.select(
        (state) =>
            state.valueOrNull?.wordCountMode ??
            WordCountMode.wordsAndCharacters,
      ),
    );
    final hasUnsavedChanges = ref.watch(
      editorCoordinatorProvider.select((state) => state.hasUnsavedChanges),
    );
    final lastSavedTime = ref.watch(
      editorCoordinatorProvider.select((state) => state.lastSavedTime),
    );

    // 根據平台判斷快捷鍵修飾符 (Apple 設備使用 Command，其他使用 Control)
    final bool isApple =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.iOS);

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        SingleActivator(
          LogicalKeyboardKey.keyN,
          control: !isApple,
          meta: isApple,
        ): const NewFileIntent(),
        SingleActivator(
          LogicalKeyboardKey.keyO,
          control: !isApple,
          meta: isApple,
        ): const OpenFileIntent(),
        SingleActivator(
          LogicalKeyboardKey.keyS,
          control: !isApple,
          meta: isApple,
        ): const SaveFileIntent(),
        SingleActivator(
          LogicalKeyboardKey.keyF,
          control: !isApple,
          meta: isApple,
        ): const FindIntent(),
        SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: !isApple,
          meta: isApple,
        ): const UndoProjectIntent(),
        SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: !isApple,
          meta: isApple,
          shift: true,
        ): const RedoProjectIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          NewFileIntent: CallbackAction<NewFileIntent>(
            onInvoke: (intent) => _newProject(),
          ),
          OpenFileIntent: CallbackAction<OpenFileIntent>(
            onInvoke: (intent) => _openProject(),
          ),
          SaveFileIntent: CallbackAction<SaveFileIntent>(
            onInvoke: (intent) => _saveProject(),
          ),
          FindIntent: CallbackAction<FindIntent>(
            onInvoke: (intent) {
              _toggleFindReplaceWindow();
              return null;
            },
          ),
          UndoProjectIntent: CallbackAction<UndoProjectIntent>(
            onInvoke: (intent) {
              _undoProjectHistory();
              return null;
            },
          ),
          RedoProjectIntent: CallbackAction<RedoProjectIntent>(
            onInvoke: (intent) {
              _redoProjectHistory();
              return null;
            },
          ),
        },
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, dynamic result) async {
            if (didPop) return;

            final shouldPop = await _handleExit();
            if (shouldPop && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            appBar: MonogatariTopAppBar(
              iconSize: fontSize + 8,
              statusIndicator: const _ProjectIoBusyIndicator(),
              showPunctuationPanel: showPunctuationPanel,
              showFindReplaceWindow: showFindReplaceWindow,
              onFileAction: _handleFileAction,
              onEditorAction: _performEditorAction,
              onEditorActionPointerDown: _prepareEditorToolbarAction,
              onTogglePunctuationPanel: _togglePunctuationPanel,
              onToggleFindReplaceWindow: _toggleFindReplaceWindow,
            ),
            body: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _clearEditableFocus,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 響應式佈局：根據螢幕寬度決定使用堆疊還是分割佈局
                  if (constraints.maxWidth < 800) {
                    return _buildMobileLayout(
                      fontSize: fontSize,
                      wordCountMode: wordCountMode,
                      hasUnsavedChanges: hasUnsavedChanges,
                      lastSavedTime: lastSavedTime,
                    );
                  } else {
                    return _buildDesktopLayout(
                      fontSize: fontSize,
                      wordCountMode: wordCountMode,
                      hasUnsavedChanges: hasUnsavedChanges,
                      lastSavedTime: lastSavedTime,
                    );
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _togglePunctuationPanel() {
    setState(() {
      showPunctuationPanel = !showPunctuationPanel;
    });
  }

  void _toggleFindReplaceWindow() {
    setState(() {
      if (slidePageIndexNow < slidePageCounts) {
        slidePageIndexNow = 114514;
        showFindReplaceWindow = true;
      } else {
        if (!showFindReplaceWindow) {
          _currentMatchIndex = -1;
        }
        showFindReplaceWindow = !showFindReplaceWindow;
      }
    });
  }

  // 手機佈局（使用 BottomNavigationBar）
  Widget _buildMobileLayout({
    required double fontSize,
    required WordCountMode wordCountMode,
    required bool hasUnsavedChanges,
    required DateTime? lastSavedTime,
  }) {
    // 檢查是否在編輯器頁面（slidePageIndexNow > (slidePageCounts - 1) 表示編輯器）
    bool isEditorMode = slidePageIndexNow > (slidePageCounts - 1);

    return MonogatariMobileLayout(
      isEditorMode: isEditorMode,
      functionPage: _buildMobileFunctionPage(fontSize: fontSize),
      editorPage: _buildEditor(),
      statusBar: _buildMobileStatusBar(
        fontSize: fontSize,
        wordCountMode: wordCountMode,
        hasUnsavedChanges: hasUnsavedChanges,
        lastSavedTime: lastSavedTime,
      ),
      onDestinationSelected: (index) {
        _syncEditorToSelectedChapter();

        setState(() {
          if (index == 0) {
            if (slidePageIndexNow > (slidePageCounts - 1)) {
              slidePageIndexNow = 0;
            }
          } else {
            slidePageIndexNow = 114514;
          }
        });
      },
    );
  }

  // 手機狀態列 - 顯示專案資訊
  Widget _buildMobileStatusBar({
    required double fontSize,
    required WordCountMode wordCountMode,
    required bool hasUnsavedChanges,
    required DateTime? lastSavedTime,
  }) {
    final statusSelection = ref.watch(
      editorSelectionProvider.select(
        (state) => (
          selectedSegID: state.selectedSegID,
          selectedChapID: state.selectedChapID,
          cursorOffset: state.cursorOffset,
        ),
      ),
    );
    final statusSegments = ref.watch(
      segmentsDataProvider.select((segments) => segments),
    );
    final statusTotalWords = ref.watch(totalWordsProvider);

    String projectName = currentProject?.nameWithoutExtension ?? "未命名專案";
    if (hasUnsavedChanges) projectName += "*";

    String currentPosition = "";
    if (statusSelection.selectedSegID != null &&
        statusSelection.selectedChapID != null) {
      for (final seg in statusSegments) {
        if (seg.segmentUUID == statusSelection.selectedSegID) {
          for (final chap in seg.chapters) {
            if (chap.chapterUUID == statusSelection.selectedChapID) {
              currentPosition = "${seg.segmentName} / ${chap.chapterName}";
              break;
            }
          }
          break;
        }
      }
    }

    final displayText = currentPosition.isNotEmpty
        ? "$projectName | $currentPosition"
        : projectName;

    String saveTimeStr = lastSavedTime != null
        ? DateFormat("HH:mm").format(lastSavedTime)
        : "--:--";

    final ({int line, int column}) cursorPos = _textPositionIndex
        .lineColumnFromOffset(statusSelection.cursorOffset);

    final int currentWords = ref.watch(
      activeChapterWordCountProvider.select((state) => state.count),
    );

    return MonogatariStatusBar(
      displayText: displayText,
      saveTimeText: saveTimeStr,
      cursorLine: cursorPos.line,
      cursorColumn: cursorPos.column,
      currentWords: currentWords,
      totalWords: statusTotalWords,
      iconSize: fontSize,
    );
  }

  // 手機功能頁面（包含功能切換和內容）
  Widget _buildMobileFunctionPage({required double fontSize}) {
    return MonogatariMobileFunctionPage(
      showPunctuationPanel: showPunctuationPanel,
      onInsertPunctuation: _insertText,
      onClosePunctuationPanel: () {
        setState(() {
          showPunctuationPanel = false;
        });
      },
      pageCount: slidePageCounts,
      selectedIndex: slidePageIndexNow,
      fontSize: fontSize,
      onBeforePageSwitch: _syncEditorToSelectedChapter,
      onPageSelected: (index) {
        _recordProjectHistorySnapshot();
        setState(() {
          slidePageIndexNow = index;
        });
      },
      pageBuilder: _buildSpecificPageContent,
    );
  }

  // 特定頁面內容建構（用於 IndexedStack）
  Widget _buildSpecificPageContent(int pageIndex) {
    switch (pageIndex) {
      case 0:
        return _buildWelcomeView();
      case 1:
        return _buildBaseInfoView();
      case 2:
        return _buildChapterSelectionView();
      case 3:
        return _buildOutlineView();
      case 4:
        return _buildWorldSettingsView();
      case 5:
        return _buildCharacterSettingsView();
      case 6:
        return _buildTimelineView();
      case 7:
        return _buildRelationView();
      case 8:
        return _buildPlanView();
      case 9:
        return _buildGlossaryView();
      case 10:
        return _buildProofreadingView();
      case 11:
        return _buildCopilotView();
      case 12:
        return _buildSettingView();
      case 13:
        return _buildAboutView();
      default:
        return Center(child: Text("Page ${pageIndex + 1}"));
    }
  }

  // 桌面佈局（使用 NavigationRail）
  Widget _buildDesktopLayout({
    required double fontSize,
    required WordCountMode wordCountMode,
    required bool hasUnsavedChanges,
    required DateTime? lastSavedTime,
  }) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              MonogatariRailSection(
                selectedIndex: _getNavigationIndex(),
                onDestinationSelected: (index) {
                  _syncEditorToSelectedChapter();
                  _recordProjectHistorySnapshot();
                  setState(() {
                    slidePageIndexNow = index;
                  });
                },
                selectedLabelTextStyle: Theme.of(
                  context,
                ).textTheme.displaySmall,
                unselectedLabelTextStyle: Theme.of(
                  context,
                ).textTheme.displaySmall,
              ),

              // 主要內容區域
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double maxWidth = constraints.maxWidth;
                    // 計算側邊欄寬度，並限制在 400px - 40% 之間
                    final double minSidebarWidth = max(maxWidth * 0.2, 400);
                    final double maxSidebarWidth = max(maxWidth * 0.4, 400);
                    // 確保最大寬度至少能容納最小寬度
                    final double effectiveMaxWidth =
                        maxSidebarWidth < minSidebarWidth
                        ? minSidebarWidth
                        : maxSidebarWidth;

                    final double sidebarWidth = (maxWidth * _sidebarWidthRatio)
                        .clamp(minSidebarWidth, effectiveMaxWidth);

                    return Row(
                      children: [
                        // 左側內容區域
                        SizedBox(
                          width: sidebarWidth,
                          child: Container(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLowest,
                            child: _buildPageContent(),
                          ),
                        ),

                        MonogatariResizeDivider(
                          onPanUpdate: (details) {
                            setState(() {
                              double currentWidth = sidebarWidth;
                              double newWidth = currentWidth + details.delta.dx;

                              double newRatio = newWidth / maxWidth;
                              double minRatio = minSidebarWidth / maxWidth;
                              double maxRatio = effectiveMaxWidth / maxWidth;

                              _sidebarWidthRatio = newRatio.clamp(
                                minRatio,
                                maxRatio,
                              );
                            });
                          },
                        ),

                        // 右側編輯器
                        Expanded(child: _buildEditor()),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // 桌面狀態列
        _buildDesktopStatusBar(
          fontSize: fontSize,
          wordCountMode: wordCountMode,
          hasUnsavedChanges: hasUnsavedChanges,
          lastSavedTime: lastSavedTime,
        ),
      ],
    );
  }

  // 桌面狀態列
  Widget _buildDesktopStatusBar({
    required double fontSize,
    required WordCountMode wordCountMode,
    required bool hasUnsavedChanges,
    required DateTime? lastSavedTime,
  }) {
    // 復用手機版的狀態列邏輯，但為了程式碼清晰，獨立出一個方法
    // 在未來可以在這裡添加桌面版特有的資訊（如編碼格式、游標位置等）
    return _buildMobileStatusBar(
      fontSize: fontSize,
      wordCountMode: wordCountMode,
      hasUnsavedChanges: hasUnsavedChanges,
      lastSavedTime: lastSavedTime,
    );
  }

  // 獲取 NavigationRail 的選中索引
  int _getNavigationIndex() {
    return slidePageIndexNow > (slidePageCounts - 1)
        ? 0
        : slidePageIndexNow.clamp(0, (slidePageCounts - 1));
  }

  // 頁面內容
  Widget _buildPageContent() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: _buildPageView(),
    );
  }

  // 頁面視圖
  Widget _buildPageView() {
    final int pageIndex = slidePageIndexNow > (slidePageCounts - 1)
        ? 0
        : slidePageIndexNow; // 如果在編輯器模式，預設顯示第一頁

    return IndexedStack(
      index: pageIndex.clamp(0, slidePageCounts - 1),
      children: [
        for (int i = 0; i < slidePageCounts; i++) _buildSpecificPageContent(i),
      ],
    );
  }

  // 編輯器
  Widget _buildEditor() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // 標點符號列（當開啟時）- 放在最上方
          if (showPunctuationPanel)
            PunctuationPanel(
              onInsert: _insertText,
              onClose: () {
                setState(() {
                  showPunctuationPanel = false;
                });
              },
            ),

          // 搜尋列（當開啟時）- 放在標點符號列下方
          if (showFindReplaceWindow)
            FindReplaceBar(
              findController: findController,
              replaceController: replaceController,
              options: findReplaceOptions,
              currentMatchIndex: _searchMatches.isNotEmpty
                  ? _currentMatchIndex
                  : null,
              totalMatches: _searchMatches.length,
              onFindNext: (findText, replaceText, options) async {
                await performFind(
                  textController,
                  findText,
                  options,
                  editorFocusNode,
                  _searchMatches,
                  _currentMatchIndex,
                  (matches, index) {
                    setState(() {
                      _searchMatches = matches;
                      _currentMatchIndex = index;
                    });
                  },
                  forward: true,
                );
              },
              onFindPrevious: (findText, replaceText, options) async {
                await performFind(
                  textController,
                  findText,
                  options,
                  editorFocusNode,
                  _searchMatches,
                  _currentMatchIndex,
                  (matches, index) {
                    setState(() {
                      _searchMatches = matches;
                      _currentMatchIndex = index;
                    });
                  },
                  forward: false,
                );
              },
              onReplace: (findText, replaceText, options) async {
                await performReplace(
                  context,
                  textController,
                  findText,
                  replaceText,
                  options,
                  editorFocusNode,
                  _searchMatches,
                  _currentMatchIndex,
                  (matches, index) {
                    setState(() {
                      _searchMatches = matches;
                      _currentMatchIndex = index;
                    });
                  },
                  (newText) {
                    setState(() {
                      contentText = newText;
                      _textChangeDebouncer.onTextChanged(newText);
                    });
                  },
                );
              },
              onReplaceAll: (findText, replaceText, options) async {
                await performReplaceAll(
                  context,
                  textController,
                  findText,
                  replaceText,
                  options,
                  (matches, index) {
                    setState(() {
                      _searchMatches = matches;
                      _currentMatchIndex = index;
                    });
                  },
                  (newText) {
                    setState(() {
                      contentText = newText;
                      _textChangeDebouncer.onTextChanged(newText);
                    });
                  },
                );
              },
              onSearchChanged: (findText, options) async {
                // 當搜尋內容或選項變化時，重新搜尋所有匹配項（但不移動光標）
                if (findText.isNotEmpty) {
                  final text = textController.text;
                  if (text.isNotEmpty) {
                    // Async search (background isolate + precomputed index)
                    final highlightUpdate = await findAllMatchesAsync(
                      text,
                      findText,
                      options,
                      maxResults:
                          HighlightTextEditingController.maxSearchResults,
                    );
                    if (!mounted) return;

                    setState(() {
                      // 更新高亮顯示（使用預編譯的索引）
                      textController.updateSearchHighlights(
                        matches: highlightUpdate.matches,
                        currentIndex: _currentMatchIndex,
                        precomputedIndex: highlightUpdate.buildSearchIndex(),
                      );
                      _searchMatches = textController.searchMatches;
                      // 如果當前選中的匹配項仍然有效，保持它
                      if (_currentMatchIndex >= _searchMatches.length) {
                        _currentMatchIndex = _searchMatches.isEmpty ? -1 : 0;
                        textController.updateCurrentSearchMatchIndex(
                          _currentMatchIndex,
                        );
                      }
                    });
                  }
                } else {
                  setState(() {
                    _searchMatches = [];
                    _currentMatchIndex = -1;
                    textController.clearAllHighlights();
                  });
                }
              },
              onClose: () {
                setState(() {
                  showFindReplaceWindow = false;
                  // 清除搜尋高亮，但保留編輯器的光標位置和選擇狀態
                  _searchMatches = [];
                  _currentMatchIndex = -1;
                  textController.clearAllHighlights();
                  // 不清除編輯器的選擇，讓用戶可以繼續從當前位置編輯
                });
              },
            ),

          // 文本編輯器 - 使用 Expanded 填充剩餘空間
          Expanded(
            child: EditorTextBox(
              controller: textController,
              focusNode: editorFocusNode,
              onUndo: _undoProjectHistory,
              onRedo: _redoProjectHistory,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeView() {
    return WelcomeModule.WelcomeView(
      onNewProject: _newProject,
      onOpenProject: _openProject,
      onOpenRecentProject: _openRecentProject,
      onDeleteRecentProject: _deleteRecentProject,
    );
  }

  // 各個頁面的建構方法（符合 Material Design）
  Widget _buildBaseInfoView() {
    return const BaseInfoModule.BaseInfoView();
  }

  Widget _buildChapterSelectionView() {
    return const ChapterModule.ChapterSelectionView();
  }

  Widget _buildOutlineView() {
    return const OutlineModule.OutlineAdjustView();
  }

  Widget _buildWorldSettingsView() {
    return const WorldSettingsView();
  }

  Widget _buildCharacterSettingsView() {
    return const CharacterView();
  }

  Widget _buildTimelineView() {
    return _buildPlaceholderPage(
      icon: Icons.view_timeline_outlined,
      title: "時間軸",
      description: "時間軸功能開發中...",
      color: Colors.teal,
    );
  }

  Widget _buildRelationView() {
    return _buildPlaceholderPage(
      icon: Icons.group,
      title: "人物關係圖",
      description: "關係圖功能開發中...",
      color: Colors.amber,
    );
  }

  Widget _buildPlanView() {
    return const PlanModule.PlanView();
  }

  Widget _buildGlossaryView() {
    return const GlossaryModule.GlossaryView();
  }

  Widget _buildProofreadingView() {
    return ProofReadingModule.ProofReadingView(
      textController: textController,
      chapterSwitchVersion: _proofreadingChapterSwitchVersion,
      onRequestFocusEditor: _focusEditorForProofreading,
    );
  }

  void _focusEditorForProofreading() {
    final bool isMobileLayout = MediaQuery.of(context).size.width < 800;
    if (isMobileLayout && slidePageIndexNow < slidePageCounts) {
      setState(() {
        slidePageIndexNow = 114514;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      editorFocusNode.requestFocus();
    });
  }

  Widget _buildCopilotView() {
    return const copilot_module.CopilotView();
  }

  Widget _buildSettingView() {
    return const SettingView();
  }

  Widget _buildAboutView() {
    return const AboutModule.AboutView();
  }

  // 通用的佔位頁面
  Widget _buildPlaceholderPage({
    required IconData icon,
    required String title,
    required String description,
    required MaterialColor color,
  }) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 64, color: color),
            ),
            const SizedBox(height: 24),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              description,
              style: Theme.of(context).textTheme.labelLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                _showMessage("$title 功能即將推出！");
              },
              icon: const Icon(Icons.construction),
              label: const Text("即將推出"),
            ),
          ],
        ),
      ),
    );
  }

  // 檔案操作處理
  void _handleFileAction(String action) {
    switch (action) {
      case "new":
        _newProject();
        break;
      case "open":
        _openProject();
        break;
      case "save":
        _saveProject();
        break;
      case "saveAs":
        _saveProjectAs();
        break;
      case "export_selective":
        _showExportDialog();
        break;
      case "export_txt":
        _exportAs("txt");
        break;
      case "export_md":
        _exportAs("md");
        break;
    }
  }

  Future<void> _showExportDialog() async {
    final Set<String> selectedModules = {
      "BaseInfo",
      "Chapters",
      "Outline",
      "WorldSettings",
      "Characters",
    };
    String selectedFormat = "xml";

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("匯出選項"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "選擇匯出格式：",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Radio<String>(
                          value: "xml",
                          groupValue: selectedFormat,
                          onChanged: (val) =>
                              setDialogState(() => selectedFormat = val!),
                        ),
                        const Text("XML"),
                        const SizedBox(width: 16),
                        Radio<String>(
                          value: "md",
                          groupValue: selectedFormat,
                          onChanged: (val) =>
                              setDialogState(() => selectedFormat = val!),
                        ),
                        const Text("Markdown"),
                      ],
                    ),
                    const Divider(),
                    const Text(
                      "選擇匯出模組：",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    // Modules checkboxes
                    ...[
                      "BaseInfo",
                      "Chapters",
                      "Outline",
                      "WorldSettings",
                      "Characters",
                    ].map((module) {
                      final displayNames = {
                        "BaseInfo": "故事設定",
                        "Chapters": "章節內容",
                        "Outline": "大綱",
                        "WorldSettings": "世界設定",
                        "Characters": "角色設定",
                      };
                      return CheckboxListTile(
                        title: Text(displayNames[module] ?? module),
                        value: selectedModules.contains(module),
                        onChanged: (bool? value) {
                          setDialogState(() {
                            if (value == true) {
                              selectedModules.add(module);
                            } else {
                              if (selectedModules.length > 1) {
                                selectedModules.remove(module);
                              }
                            }
                          });
                        },
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("取消"),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _exportSelective(selectedModules, selectedFormat);
                  },
                  child: const Text("匯出"),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) {
      return;
    }
  }

  Future<void> _exportSelective(Set<String> modules, String format) async {
    _syncEditorToSelectedChapter();
    final currentData = _collectProjectData();
    final defaultName =
        currentProject?.nameWithoutExtension ?? "MonogatariExport";

    try {
      await ref
          .read(projectIoControllerProvider.notifier)
          .exportSelective(
            currentData: currentData,
            defaultFileName: defaultName,
            selectedModules: modules,
            format: format,
          );
      _showMessage("匯出成功！");
    } catch (e) {
      _showError("匯出檔案失敗：${e.toString()}");
    }
  }

  // 插入文字到編輯器當前位置 (支援所有輸入框)
  void _insertText(String textToInsert) {
    var targetNode = WidgetsBinding.instance.focusManager.primaryFocus;
    EditableTextState? editable;

    // 1. 嘗試獲取當前焦點的 EditableTextState
    if (targetNode != null && targetNode.context != null) {
      editable = targetNode.context!
          .findAncestorStateOfType<EditableTextState>();
    }

    // 2. 如果當前焦點無效，嘗試使用最後一次的焦點
    if (editable == null) {
      if (_lastFocusedEditableNode != null &&
          _lastFocusedEditableNode!.context != null &&
          _lastFocusedEditableNode!.context!.mounted) {
        targetNode = _lastFocusedEditableNode;
        targetNode!.requestFocus();
        editable = targetNode.context!
            .findAncestorStateOfType<EditableTextState>();
      }
    }

    // 3. 執行插入
    if (editable != null) {
      final oldValue = editable.textEditingValue;
      final text = oldValue.text;
      final selection = oldValue.selection;

      String newText;
      int newSelectionIndex;

      if (selection.isValid && selection.start >= 0) {
        newText = text.replaceRange(
          selection.start,
          selection.end,
          textToInsert,
        );
        newSelectionIndex = selection.start + textToInsert.length;
      } else {
        newText = text + textToInsert;
        newSelectionIndex = newText.length;
      }

      editable.updateEditingValue(
        TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newSelectionIndex),
          composing: TextRange.empty,
        ),
      );

      // 確保焦點回到該輸入框
      if (targetNode != WidgetsBinding.instance.focusManager.primaryFocus) {
        targetNode!.requestFocus();
      }
    }
  }

  EditableTextState? _findEditableForFocusNode(FocusNode node) {
    final context = node.context;
    if (context == null || !context.mounted) {
      return null;
    }

    final ancestor = context.findAncestorStateOfType<EditableTextState>();
    if (ancestor != null && ancestor.widget.focusNode == node) {
      return ancestor;
    }

    EditableTextState? result;
    void visit(Element element) {
      if (result != null) {
        return;
      }

      if (element is StatefulElement) {
        final state = element.state;
        if (state is EditableTextState && state.widget.focusNode == node) {
          result = state;
          return;
        }
      }

      element.visitChildElements(visit);
    }

    (context as Element).visitChildElements(visit);
    return result;
  }

  EditableTextState? _getPrimaryFocusedEditable() {
    // 使用追蹤的最後一個有焦點的編輯框
    // 當按鈕被點擊時，焦點會移到按鈕，但我們需要操作在它之前有焦點的編輯框

    if (_lastFocusedEditableNode != null &&
        _lastFocusedEditableNode!.context != null &&
        _lastFocusedEditableNode!.context!.mounted) {
      debugPrint(
        "[DEBUG] Using last focused editable node: $_lastFocusedEditableNode",
      );
      final editable = _findEditableForFocusNode(_lastFocusedEditableNode!);
      if (editable != null) {
        return editable;
      }
    }

    debugPrint("[DEBUG] No last focused editable found");
    return null;
  }

  // 編輯器操作
  Future<void> _performEditorAction(String action) async {
    try {
      if (action == "undo") {
        _undoProjectHistory();
        return;
      }
      if (action == "redo") {
        _redoProjectHistory();
        return;
      }

      final editable = _getPrimaryFocusedEditable();

      // Copy/Cut/Paste/Select All 只作用在目前取得焦點的輸入框。
      if (editable == null) {
        debugPrint("[DEBUG] No focused editable found");
        return;
      }

      final controller = editable.widget.controller;

      debugPrint("[DEBUG]: Performing action $action on controller");

      switch (action) {
        case "selectAll":
          _handleSelectAll(controller);
          break;
        case "cut":
          await _handleCut(controller, editable);
          break;
        case "copy":
          _handleCopy(controller);
          break;
        case "paste":
          await _handlePaste(controller, editable);
          break;
        case "find":
          // 實作搜尋功能
          break;
      }

      // 操作完後恢復焦點到編輯框
      final focusNode = editable.widget.focusNode;
      if (!focusNode.hasFocus) {
        debugPrint("[DEBUG] Restoring focus to editable after action");
        focusNode.requestFocus();
      }
    } finally {
      _finishEditorToolbarAction();
    }
  }

  /// 選擇所有文本
  void _handleSelectAll(TextEditingController controller) {
    final editable = _getPrimaryFocusedEditable();
    if (editable != null && editable.widget.controller == controller) {
      // 使用 updateEditingValue 確保 UI 正確更新
      editable.updateEditingValue(
        TextEditingValue(
          text: controller.text,
          selection: TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          ),
          composing: TextRange.empty,
        ),
      );
    } else {
      // 備用方案
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
    }
  }

  /// 複製選定的文本到剪貼簿
  void _handleCopy(TextEditingController controller) {
    final selection = controller.selection;
    debugPrint(
      "[DEBUG] Copy selection=$selection, isValid=${selection.isValid}, isCollapsed=${selection.isCollapsed}",
    );

    if (!selection.isValid || selection.isCollapsed) {
      debugPrint("[DEBUG] Copy No selection to copy");
      return; // 沒有選定任何文本
    }

    final selectedText = controller.text.substring(
      selection.start,
      selection.end,
    );
    debugPrint("[DEBUG] Copy: Copying text '$selectedText'");
    Clipboard.setData(ClipboardData(text: selectedText));
  }

  /// 剪切選定的文本到剪貼簿
  Future<void> _handleCut(
    TextEditingController controller,
    EditableTextState editable,
  ) async {
    final selection = controller.selection;
    debugPrint(
      "[DEBUG] Cut selection=$selection, isValid=${selection.isValid}, isCollapsed=${selection.isCollapsed}",
    );

    if (!selection.isValid || selection.isCollapsed) {
      debugPrint("[DEBUG] Cut No selection to cut");
      return; // 沒有選定任何文本
    }

    final selectedText = controller.text.substring(
      selection.start,
      selection.end,
    );
    debugPrint("[DEBUG] Cut: Cutting text '$selectedText'");
    await Clipboard.setData(ClipboardData(text: selectedText));

    // 刪除選定的文本
    final newText = controller.text.replaceRange(
      selection.start,
      selection.end,
      '',
    );

    // 使用 updateEditingValue 更新，確保 UI 正確更新
    editable.updateEditingValue(
      TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start),
        composing: TextRange.empty,
      ),
    );
    debugPrint("[DEBUG] Cut: Text after cut '$newText'");
  }

  /// 從剪貼簿貼上文本
  Future<void> _handlePaste(
    TextEditingController controller,
    EditableTextState editable,
  ) async {
    debugPrint("[DEBUG] Paste Starting paste operation");
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      final pastedText = clipboardData?.text ?? '';

      debugPrint("[DEBUG] Paste: Clipboard data '$pastedText'");

      if (pastedText.isEmpty) {
        debugPrint("[DEBUG] Paste Clipboard is empty");
        return; // 剪貼簿為空
      }

      final selection = controller.selection;
      debugPrint("[DEBUG] Paste: Current selection $selection");

      String newText;
      int newCursorPos;

      if (selection.isValid && !selection.isCollapsed) {
        // 如果有選定的文本，先替換它
        debugPrint("[DEBUG] Paste Replacing selected text");
        newText = controller.text.replaceRange(
          selection.start,
          selection.end,
          pastedText,
        );
        newCursorPos = selection.start + pastedText.length;
      } else {
        // 在游標位置插入文本
        debugPrint("[DEBUG] Paste Inserting at cursor position");
        final offset = selection.isValid
            ? _clampOffset(selection.baseOffset, controller.text.length)
            : controller.text.length;
        newText = controller.text.replaceRange(offset, offset, pastedText);
        newCursorPos = offset + pastedText.length;
      }

      // 使用 updateEditingValue 更新，確保 UI 正確更新
      editable.updateEditingValue(
        TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newCursorPos),
          composing: TextRange.empty,
        ),
      );
      debugPrint("[DEBUG] Paste: Text after paste '$newText'");
    } catch (e) {
      debugPrint("[DEBUG] Paste Error - $e");
    }
  }

  // MARK: - 檔案操作

  // 變更追蹤和退出處理

  /// 標記內容已儲存
  void _markAsSaved() {
    _editorCoordinatorNotifier.markAsSaved();
  }

  /// 檢查是否有未儲存的變更
  bool _hasUnsavedChanges() {
    _syncEditorToSelectedChapter();
    return _editorCoordinatorNotifier.hasUnsavedChanges();
  }

  /// 處理退出請求
  Future<bool> _handleExit() async {
    return ProjectManager.handleExit(
      context,
      showExitWarning: _settingsState.showExitWarning,
      hasUnsavedChanges: _hasUnsavedChanges(),
      onDontShowAgainChanged: (val) async => await ref
          .read(settingsStateProvider.notifier)
          .setShowExitWarning(!val),
      onSave: () async {
        await _saveProject();
        // Check if save successful (dirty flag cleared)
        if (_hasUnsavedChanges()) throw Exception("Save cancelled or failed");
      },
    );
  }

  // 檔案操作方法
  Future<void> _newProject() async {
    if (_hasUnsavedChanges()) {
      final shouldProceed = await ProjectManager.showSaveConfirmDialog(
        context,
        title: "建立新專案",
        message: "您有未儲存的變更，是否要在建立新專案前儲存？",
        onDontShowAgainChanged: (_) async {},
        onSave: _saveProject,
      );

      if (shouldProceed == null) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    try {
      final result = await ref
          .read(projectIoControllerProvider.notifier)
          .createNewProject();

      final initialState = ref
          .read(editorCoordinatorProvider.notifier)
          .calculateInitialState(result.data, _settingsState.wordCountMode);

      setState(() {
        currentProject = result.projectFile;
        _applyProjectData(result.data, initialState);
      });
      _editorCoordinatorNotifier.resetAfterProjectLoaded();
      _resetProjectHistory();
      if (!mounted) {
        return;
      }
      _showMessage("新專案建立成功！");

      _updateAllWordCounts();
    } catch (e) {
      _showError("建立新專案失敗：${e.toString()}");
    }
  }

  Future<void> _openProject() async {
    if (_hasUnsavedChanges()) {
      final shouldProceed = await ProjectManager.showSaveConfirmDialog(
        context,
        title: "開啟專案",
        message: "您有未儲存的變更，是否要在開啟新專案前儲存？",
        onDontShowAgainChanged: (_) async {},
        onSave: _saveProject,
      );
      if (shouldProceed == null) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    try {
      final projectFile = await ref
          .read(projectIoControllerProvider.notifier)
          .pickProjectFile();
      if (projectFile == null) {
        return;
      }

      final loadResult = await ref
          .read(projectIoControllerProvider.notifier)
          .loadProject(projectFile);
      final openedVersion = loadResult.projectVersion;
      final hasNewerVersion = FileService.isProjectVersionNewerThanSupported(
        openedVersion,
      );

      if (hasNewerVersion) {
        if (!mounted) {
          return;
        }
        final shouldContinue =
            await ProjectManager.showVersionCompatibilityDialog(
              context,
              fileVersion: openedVersion ?? "unknown",
              supportedVersion: FileService.projectVersion,
            );
        if (!mounted) {
          return;
        }
        if (!shouldContinue) {
          _showError("已取消開啟較新版本檔案。");
          return;
        }
      }

      final data = loadResult.data;

      final initialState = ref
          .read(editorCoordinatorProvider.notifier)
          .calculateInitialState(data, _settingsState.wordCountMode);

      setState(() {
        currentProject = projectFile;
        _applyProjectData(data, initialState);
      });
      _editorCoordinatorNotifier.resetAfterProjectLoaded();
      _resetProjectHistory();

      await _editorCoordinatorNotifier.recordRecentProject(projectFile);
      if (!mounted) {
        return;
      }
      _showMessage("專案開啟成功：${projectFile.nameWithoutExtension}");

      _updateAllWordCounts();
    } catch (e) {
      _showError("開啟專案失敗：${e.toString()}");
    }
  }

  Future<void> _openRecentProject(RecentProjectEntry entry) async {
    if (!entry.canReopen || entry.filePath == null) {
      _showError("此最近檔案沒有可用的本機路徑，請改用一般「開啟檔案」。");
      return;
    }

    if (_hasUnsavedChanges()) {
      final shouldProceed = await ProjectManager.showSaveConfirmDialog(
        context,
        title: "開啟最近專案",
        message: "您有未儲存的變更，是否要在開啟最近專案前儲存？",
        onDontShowAgainChanged: (_) async {},
        onSave: _saveProject,
      );
      if (shouldProceed == null) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    try {
      final projectFile = await ref
          .read(projectIoControllerProvider.notifier)
          .openProjectFromPath(entry.filePath!, accessToken: entry.uri);

      final loadResult = await ref
          .read(projectIoControllerProvider.notifier)
          .loadProject(projectFile);
      final openedVersion = loadResult.projectVersion;
      final hasNewerVersion = FileService.isProjectVersionNewerThanSupported(
        openedVersion,
      );

      if (hasNewerVersion) {
        if (!mounted) {
          return;
        }
        final shouldContinue =
            await ProjectManager.showVersionCompatibilityDialog(
              context,
              fileVersion: openedVersion ?? "unknown",
              supportedVersion: FileService.projectVersion,
            );
        if (!mounted) {
          return;
        }
        if (!shouldContinue) {
          _showError("已取消開啟較新版本檔案。");
          return;
        }
      }

      final data = loadResult.data;

      final initialState = ref
          .read(editorCoordinatorProvider.notifier)
          .calculateInitialState(data, _settingsState.wordCountMode);

      setState(() {
        currentProject = projectFile;
        _applyProjectData(data, initialState);
      });
      _editorCoordinatorNotifier.resetAfterProjectLoaded();
      _resetProjectHistory();

      await _editorCoordinatorNotifier.recordRecentProject(projectFile);
      if (!mounted) {
        return;
      }
      _showMessage("專案開啟成功：${projectFile.nameWithoutExtension}");

      _updateAllWordCounts();
    } catch (e) {
      final message = e.toString();
      _showError("開啟最近專案失敗：$message");
      if (message.contains("檔案不存在")) {
        unawaited(
          ref.read(settingsStateProvider.notifier).removeRecentProject(entry),
        );
      }
    }
  }

  Future<void> _deleteRecentProject(RecentProjectEntry entry) async {
    await ref.read(settingsStateProvider.notifier).removeRecentProject(entry);
    _showMessage("已從最近清單移除：${entry.fileName}");
  }

  Future<void> _saveProject() async {
    _syncEditorToSelectedChapter();
    final currentData = _collectProjectData();

    try {
      final savedProject = await ref
          .read(projectIoControllerProvider.notifier)
          .saveProject(
            currentProject: currentProject,
            currentData: currentData,
            forceSaveAs: false,
          );
      if (!mounted) {
        return;
      }
      setState(() => currentProject = savedProject);
      _markAsSaved();
      await _editorCoordinatorNotifier.recordRecentProject(savedProject);
      if (!mounted) {
        return;
      }
      _showMessage("專案儲存成功！");
    } catch (e) {
      _showError("儲存專案失敗：${e.toString()}");
    }
  }

  Future<void> _saveProjectAs() async {
    _syncEditorToSelectedChapter();
    final currentData = _collectProjectData();

    try {
      final savedProject = await ref
          .read(projectIoControllerProvider.notifier)
          .saveProject(
            currentProject: currentProject,
            currentData: currentData,
            forceSaveAs: true,
          );
      if (!mounted) {
        return;
      }
      setState(() => currentProject = savedProject);
      _markAsSaved();
      await _editorCoordinatorNotifier.recordRecentProject(savedProject);
      if (!mounted) {
        return;
      }
      _showMessage("專案另存成功：${savedProject.nameWithoutExtension}");
    } catch (e) {
      _showError("另存專案失敗：${e.toString()}");
    }
  }

  Future<void> _exportAs(String extension) async {
    _syncEditorToSelectedChapter();
    final currentData = _collectProjectData();
    final defaultName =
        currentProject?.nameWithoutExtension ?? "MonogatariExport";

    try {
      await ref
          .read(projectIoControllerProvider.notifier)
          .exportAs(
            extension: extension,
            currentData: currentData,
            defaultFileName: defaultName,
          );
      _showMessage("匯出 $extension 檔案成功！");
    } catch (e) {
      _showError("匯出檔案失敗：${e.toString()}");
    }
  }

  // 同步編輯器內容到選中的章節（先存的部分）
  void _syncEditorToSelectedChapter() {
    _flushPendingEditorContent();
    ref
        .read(editorCoordinatorProvider.notifier)
        .syncEditorToSelectedChapter(textController: textController);
  }

  // 輔助方法：收集當前專案數據
  ProjectData _collectProjectData() {
    _flushPendingEditorContent();
    return ref.read(editorCoordinatorProvider.notifier).collectProjectData();
  }

  // 輔助方法：應用專案數據到狀態 (改為接收預先計算的狀態)
  void _applyProjectData(
    ProjectData data,
    EditorProjectInitialState initialState,
  ) {
    _cancelPendingContentCommit();
    final coordinatorNotifier = ref.read(editorCoordinatorProvider.notifier);
    final beganApplying = coordinatorNotifier.beginApplyingProjectData();
    final String? previousSelectedChapID = selectedChapID;

    coordinatorNotifier.applyProjectData(
      data: data,
      initialState: initialState,
    );

    if (previousSelectedChapID != selectedChapID) {
      _proofreadingChapterSwitchVersion++;
    }

    final bool beganSync = coordinatorNotifier.beginSync();
    try {
      if (initialState.hasSelection) {
        textController.text = contentText;
      } else {
        textController.text = "";
      }
      textController.selection = TextSelection.collapsed(
        offset: _clampOffset(
          initialState.cursorOffset,
          textController.text.length,
        ),
      );
      _lastObservedEditorText = textController.text;
      _textPositionIndex = _textPositionIndex.rebuildIfTextChanged(
        textController.text,
      );
    } finally {
      if (beganSync) {
        coordinatorNotifier.endSync();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (beganApplying) {
        coordinatorNotifier.endApplyingProjectData();
      }
    });

    _refreshActiveChapterWordCount();

    // Force rebuild of all modules by using keys or ensuring state update
    // Note: Since we are replacing the data objects, didUpdateWidget in children should trigger
  }

  // 訊息處理
  void _showError(String message) {
    _editorCoordinatorNotifier.pushError(message);
  }

  void _showMessage(String message) {
    _editorCoordinatorNotifier.pushMessage(message);
  }
}
