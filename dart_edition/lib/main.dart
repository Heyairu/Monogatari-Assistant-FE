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
import "presentation/providers/editor_coordinator_provider.dart";
import "presentation/providers/global_state_providers.dart";
import "presentation/providers/project_io_providers.dart";
import "presentation/providers/project_history_provider.dart";
import "presentation/providers/project_state_providers.dart";
import "presentation/providers/word_count_providers.dart";
import "utils/text_change_debouncer.dart";
import "utils/text_position_index.dart";
import "services/word_count_service.dart";
import "services/project_io_session_coordinator.dart";

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
import "modules/character_relationship_graph_view.dart";
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

typedef _EditorStatusLocation = ({String chapterLabel, int cursorOffset});

final _editorStatusLocationProvider = Provider<_EditorStatusLocation>((ref) {
  final selection = ref.watch(
    editorSelectionProvider.select(
      (state) => (
        selectedSegID: state.selectedSegID,
        selectedChapID: state.selectedChapID,
        cursorOffset: state.cursorOffset,
      ),
    ),
  );
  final segments = ref.watch(segmentsDataProvider);

  String chapterLabel = "";
  for (final segment in segments) {
    if (segment.segmentUUID != selection.selectedSegID) continue;
    for (final chapter in segment.chapters) {
      if (chapter.chapterUUID == selection.selectedChapID) {
        chapterLabel = "${segment.segmentName} / ${chapter.chapterName}";
        break;
      }
    }
    break;
  }

  return (chapterLabel: chapterLabel, cursorOffset: selection.cursorOffset);
});

class _EditorStatusBar extends ConsumerStatefulWidget {
  const _EditorStatusBar({
    required this.textController,
    required this.projectName,
    required this.hasUnsavedChanges,
    required this.lastSavedTime,
    required this.iconSize,
  });

  final TextEditingController textController;
  final String projectName;
  final bool hasUnsavedChanges;
  final DateTime? lastSavedTime;
  final double iconSize;

  @override
  ConsumerState<_EditorStatusBar> createState() => _EditorStatusBarState();
}

class _EditorStatusBarState extends ConsumerState<_EditorStatusBar> {
  static const int _largeDocumentThreshold = 128 * 1024;
  static const Duration _largeDocumentDebounce = Duration(milliseconds: 160);

  late TextPositionIndex _positionIndex;
  Timer? _positionIndexTimer;

  @override
  void initState() {
    super.initState();
    _positionIndex = TextPositionIndex(widget.textController.text);
    widget.textController.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant _EditorStatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.textController, widget.textController)) return;
    oldWidget.textController.removeListener(_handleControllerChanged);
    widget.textController.addListener(_handleControllerChanged);
    _rebuildPositionIndex(widget.textController.text);
  }

  void _handleControllerChanged() {
    final nextText = widget.textController.text;
    if (nextText == _positionIndex.text) return;

    final isSmall = nextText.length < _largeDocumentThreshold;
    final looksLikeSingleEdit =
        (nextText.length - _positionIndex.text.length).abs() <= 8;
    if (isSmall || !looksLikeSingleEdit) {
      _positionIndexTimer?.cancel();
      _rebuildPositionIndex(nextText);
      return;
    }

    _positionIndexTimer?.cancel();
    _positionIndexTimer = Timer(_largeDocumentDebounce, () {
      if (!mounted) return;
      _rebuildPositionIndex(widget.textController.text);
    });
  }

  void _rebuildPositionIndex(String text) {
    if (!mounted) {
      _positionIndex = TextPositionIndex(text);
      return;
    }
    setState(() => _positionIndex = TextPositionIndex(text));
  }

  @override
  void dispose() {
    _positionIndexTimer?.cancel();
    widget.textController.removeListener(_handleControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(_editorStatusLocationProvider);
    final totalWords = ref.watch(totalWordsProvider);
    final currentWords = ref.watch(
      activeChapterWordCountProvider.select((state) => state.count),
    );

    final projectName = widget.hasUnsavedChanges
        ? "${widget.projectName}*"
        : widget.projectName;
    final displayText = status.chapterLabel.isNotEmpty
        ? "$projectName | ${status.chapterLabel}"
        : projectName;
    final saveTimeText = widget.lastSavedTime == null
        ? "--:--"
        : DateFormat("HH:mm").format(widget.lastSavedTime!);
    final cursor = _positionIndex.lineColumnFromOffset(status.cursorOffset);

    return MonogatariStatusBar(
      displayText: displayText,
      saveTimeText: saveTimeText,
      cursorLine: cursor.line,
      cursorColumn: cursor.column,
      currentWords: currentWords,
      totalWords: totalWords,
      iconSize: widget.iconSize,
    );
  }
}

// 主要 ContentView
class ContentView extends ConsumerStatefulWidget {
  const ContentView({super.key});

  @override
  ConsumerState<ContentView> createState() => _ContentViewState();
}

class _ContentViewState extends ConsumerState<ContentView> with WindowListener {
  // 狀態變數
  int slidePageCounts = 14;
  int slidePageIndexCurrent = 0;
  int slidePageIndexNow = 0;
  int _projectSessionVersion = 0;
  String? _requestedCharacterId;
  int _characterSelectionRequestId = 0;
  double _sidebarWidthRatio = 0.25; // Default sidebar width ratio (25%)

  final WordCountService _wordCountService = WordCountService.instance;

  // 主編輯器文字
  String get contentText => ref.read(editorContentProvider);
  set contentText(String value) {
    _cancelPendingContentCommit();
    ref.read(editorContentProvider.notifier).setContent(value);
  }

  final HighlightTextEditingController textController =
      HighlightTextEditingController();
  String _lastObservedEditorText = "";

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
  int _projectDataRevision = 0;
  int? _lastRecordedProjectDataRevision;
  int? _pendingProjectHistoryRevision;
  Timer? _autoSaveTimer;
  Timer? _autoBackupTimer;
  bool _isWritingAutoSave = false;
  bool _isWritingAutoBackup = false;
  int? _lastAutoBackupRevision;
  final ProjectIoSessionCoordinator _projectIoCoordinator =
      ProjectIoSessionCoordinator();
  late ProjectIoSessionToken _projectIoSession;
  bool _isProjectSwitching = false;
  bool _isApplyingProjectHistory = false;
  static const Duration _projectHistoryRecordDelay = Duration(
    milliseconds: 500,
  );
  static const Set<int> _ignoredPageTransitionIndexes = {
    0, // Welcome
    9, // Glossary
    10, // Proofreading
    13, // About
  };
  static const Set<int> _projectBackedPageIndexes = {
    1, // Base info
    2, // Chapters
    3, // Outline
    4, // World settings
    5, // Characters
    7, // Character relationships
    8, // Plans
  };

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

      _refreshActiveChapterWordCount();
    });
  }

  void _refreshActiveChapterWordCount({String? contentOverride}) {
    final String? activeChapterId = selectedChapID;
    final activeWordCountNotifier = ref.read(
      activeChapterWordCountProvider.notifier,
    );
    if (activeChapterId == null) {
      activeWordCountNotifier.reset();
      return;
    }

    final WordCountMode mode = _settingsState.wordCountMode;
    final String activeText = contentOverride ?? textController.text;
    final lookup = _wordCountService.observeChapter(
      chapterId: activeChapterId,
      content: activeText,
      mode: mode,
    );
    if (lookup.isPending) {
      activeWordCountNotifier.markComputing(chapterId: activeChapterId);
    } else {
      activeWordCountNotifier.refreshFromCount(
        chapterId: activeChapterId,
        count: lookup.count,
      );
    }
  }

  void _handleWordCountServiceChanged() {
    if (!mounted) {
      return;
    }
    totalWords = _wordCountService.total;
    final chapterId = selectedChapID;
    if (chapterId == null) {
      return;
    }
    final lookup = _wordCountService.lookup(
      chapterId,
      _settingsState.wordCountMode,
    );
    final notifier = ref.read(activeChapterWordCountProvider.notifier);
    if (lookup.isPending) {
      notifier.markComputing(chapterId: chapterId);
    } else {
      notifier.refreshFromCount(chapterId: chapterId, count: lookup.count);
    }
  }

  @override
  void initState() {
    super.initState();
    _projectIoSession = _projectIoCoordinator.beginSession("");
    _wordCountService.addListener(_handleWordCountServiceChanged);

    _textChangeDebouncer = TextChangeDebouncer(
      onWordCountTrigger: (nextContent) {
        _flushPendingEditorContent();
        _refreshActiveChapterWordCount();
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
    _configureAutoSaveTimer(_settingsState);
    _configureAutoBackupTimer(_settingsState);

    // 監聽文字變化
    textController.addListener(() {
      final int selectionOffset = textController.selection.baseOffset;
      final int normalizedOffset = _clampOffset(
        selectionOffset,
        textController.text.length,
      );
      final String currentText = textController.text;
      final bool textChanged =
          !_isSyncing && _lastObservedEditorText != currentText;

      // 將輸入事件轉交 coordinator，UI listener 僅保留畫面刷新職責。
      if (textChanged) {
        cancelFindAllMatches(textController);
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
      ref.listenManual<AppSettingsStateData>(
        settingsStateProvider.select(
          (state) => state.valueOrNull ?? const AppSettingsStateData(),
        ),
        (previous, next) {
          if (!mounted) {
            return;
          }
          if (previous?.autoSaveEnabled != next.autoSaveEnabled ||
              previous?.autoSaveIntervalMinutes !=
                  next.autoSaveIntervalMinutes) {
            _configureAutoSaveTimer(next);
          }
          if (previous?.autoBackupEnabled != next.autoBackupEnabled ||
              previous?.autoBackupIntervalMinutes !=
                  next.autoBackupIntervalMinutes) {
            _configureAutoBackupTimer(next);
          }
        },
      ),
    );

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
        // Selection and editor content are separate provider updates. Resolve
        // the newly selected chapter directly from the project model so the
        // word-count cache never sees the new id paired with the old editor
        // text during that brief transition.
        _refreshActiveChapterWordCount(
          contentOverride: ref.read(selectedChapterStoredContentProvider) ?? "",
        );
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

        _updateAllWordCounts();
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

        _projectDataRevision++;
        _scheduleProjectHistoryRecord(_projectDataRevision);
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
              AppFeedback.info(
                context,
                snackMessage,
                duration: const Duration(seconds: 3),
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
              await AppDialog.message(
                context: context,
                title: "錯誤",
                message: dialogMessage,
                closeLabel: "確定",
                tone: AppFeedbackTone.error,
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateAllWordCounts();
      }
    });
  }

  @override
  void dispose() {
    CharacterDraftSessionCoordinator.instance.flushAndClose(
      _projectSessionVersion,
    );
    _cancelPendingContentCommit();
    _projectHistoryRecordTimer?.cancel();
    _projectHistoryRecordTimer = null;
    _pendingProjectHistoryRevision = null;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    _autoBackupTimer?.cancel();
    _autoBackupTimer = null;
    _wordCountService.removeListener(_handleWordCountServiceChanged);
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

  void _flushPendingEditorContent() {
    _textChangeDebouncer.flushPendingContentCommit();
  }

  bool _canAutoSaveToKnownLocation(ProjectFile? projectFile) {
    if (projectFile == null) {
      return false;
    }
    final hasPath = projectFile.filePath?.trim().isNotEmpty == true;
    final hasUri = projectFile.uri?.trim().isNotEmpty == true;
    return hasPath || hasUri;
  }

  String _projectIdentity(ProjectFile? project) {
    if (project == null) return "unsaved";
    return project.uri?.trim().isNotEmpty == true
        ? "uri:${project.uri!.trim()}"
        : project.filePath?.trim().isNotEmpty == true
        ? "path:${project.filePath!.trim()}"
        : "name:${project.fileName}";
  }

  ProjectIoSessionToken _beginProjectIoSession(ProjectFile? project) {
    final token = _projectIoCoordinator.beginSession(_projectIdentity(project));
    _projectIoSession = token;
    return token;
  }

  Future<ProjectIoPayload> _sharedProjectIoPayload({
    required ProjectIoSessionToken session,
    required int revision,
    required ProjectData data,
  }) {
    return _projectIoCoordinator.sharedPayload<ProjectIoPayload>(
      token: session,
      revision: revision,
      create: () => ref
          .read(projectIoControllerProvider.notifier)
          .prepareProjectPayload(data),
    );
  }

  void _configureAutoSaveTimer(AppSettingsStateData settings) {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;

    if (!settings.autoSaveEnabled) {
      return;
    }

    final intervalMinutes = settings.autoSaveIntervalMinutes.clamp(1, 120);
    _autoSaveTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => unawaited(_performAutoSave()),
    );
  }

  Future<void> _performAutoSave() async {
    final project = currentProject;
    if (!mounted ||
        _isWritingAutoSave ||
        _isProjectSwitching ||
        !_settingsState.autoSaveEnabled ||
        !_canAutoSaveToKnownLocation(project)) {
      return;
    }

    _syncEditorToSelectedChapter();
    if (!hasUnsavedChanges) {
      return;
    }

    _isWritingAutoSave = true;
    try {
      final session = _projectIoSession;
      final revision = _projectDataRevision;
      final currentData = _collectProjectData();
      final runResult = await _projectIoCoordinator.run(session, () async {
        final payload = await _sharedProjectIoPayload(
          session: session,
          revision: revision,
          data: currentData,
        );
        return ref
            .read(projectIoControllerProvider.notifier)
            .saveProjectAutoSave(
              currentProject: project!,
              currentData: currentData,
              preparedPayload: payload,
            );
      });
      final savedProject = runResult.value;
      if (!mounted ||
          savedProject == null ||
          !_projectIoCoordinator.isCurrent(session)) {
        return;
      }
      setState(() => currentProject = savedProject);
      if (_projectDataRevision == revision) {
        _markAsSaved();
      }
      await _editorCoordinatorNotifier.recordRecentProject(savedProject);
    } catch (error, stackTrace) {
      debugPrint("AutoSave failed: $error\n$stackTrace");
    } finally {
      _isWritingAutoSave = false;
    }
  }

  void _configureAutoBackupTimer(AppSettingsStateData settings) {
    _autoBackupTimer?.cancel();
    _autoBackupTimer = null;

    if (!settings.autoBackupEnabled) {
      _resetAutoBackupBaseline();
      return;
    }

    final intervalMinutes = settings.autoBackupIntervalMinutes.clamp(1, 120);
    _autoBackupTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => unawaited(_performAutoBackup()),
    );
  }

  Future<void> _performAutoBackup() async {
    if (!mounted ||
        _isWritingAutoBackup ||
        _isProjectSwitching ||
        !_settingsState.autoBackupEnabled) {
      return;
    }

    _syncEditorToSelectedChapter();
    final revision = _projectDataRevision;
    if (_lastAutoBackupRevision == revision) return;

    _isWritingAutoBackup = true;
    try {
      final session = _projectIoSession;
      final currentData = _collectProjectData();
      final runResult = await _projectIoCoordinator.run(session, () async {
        final payload = await _sharedProjectIoPayload(
          session: session,
          revision: revision,
          data: currentData,
        );
        return ref
            .read(projectIoControllerProvider.notifier)
            .saveProjectAutoBackup(
              currentProject: currentProject,
              currentData: currentData,
              maxTotalBytes: _settingsState.autoBackupMaxSizeMb * 1024 * 1024,
              preparedPayload: payload,
            );
      });
      final result = runResult.value;
      if (result == null || !_projectIoCoordinator.isCurrent(session)) return;
      _lastAutoBackupRevision = revision;
    } catch (error, stackTrace) {
      debugPrint("AutoBackup failed: $error\n$stackTrace");
    } finally {
      _isWritingAutoBackup = false;
    }
  }

  void _resetAutoBackupBaseline() {
    _lastAutoBackupRevision = null;
  }

  void _cancelPendingContentCommit() {
    _textChangeDebouncer.cancelAll();
  }

  void _scheduleProjectHistoryRecord(int revision) {
    if (_isApplyingProjectHistory ||
        revision == _lastRecordedProjectDataRevision) {
      return;
    }

    _pendingProjectHistoryRevision = revision;
    _projectHistoryRecordTimer?.cancel();
    _projectHistoryRecordTimer = Timer(_projectHistoryRecordDelay, () {
      _projectHistoryRecordTimer = null;
      final int? pendingRevision = _pendingProjectHistoryRevision;
      _pendingProjectHistoryRevision = null;
      if (pendingRevision == null ||
          pendingRevision == _lastRecordedProjectDataRevision) {
        return;
      }
      _recordProjectHistorySnapshot();
    });
  }

  ProjectHistoryEntry _createProjectHistoryEntry(
    ProjectData data, {
    bool isPageTransition = false,
  }) {
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
      isPageTransition: isPageTransition,
    );
  }

  void _recordProjectHistorySnapshot({
    bool reset = false,
    bool isPageTransition = false,
  }) {
    if (!mounted || _isApplyingProjectHistory) {
      return;
    }

    _projectHistoryRecordTimer?.cancel();
    _projectHistoryRecordTimer = null;
    _pendingProjectHistoryRevision = null;
    _syncEditorToSelectedChapter();

    // Syncing editor text may publish a new aggregate provider state and
    // schedule another timer synchronously. Consume that revision here so the
    // duplicate callback cannot perform a second full snapshot/serialization.
    _projectHistoryRecordTimer?.cancel();
    _projectHistoryRecordTimer = null;
    _pendingProjectHistoryRevision = null;
    final int currentRevision = _projectDataRevision;
    if (!reset &&
        !isPageTransition &&
        currentRevision == _lastRecordedProjectDataRevision) {
      return;
    }

    final entry = _createProjectHistoryEntry(
      _collectProjectData(),
      isPageTransition: isPageTransition,
    );
    final historyNotifier = ref.read(projectHistoryProvider.notifier);
    if (reset) {
      historyNotifier.reset(entry);
    } else {
      historyNotifier.record(entry);
    }
    _lastRecordedProjectDataRevision = currentRevision;
  }

  void _resetProjectHistory() {
    _recordProjectHistorySnapshot(reset: true);
  }

  bool _shouldRecordPageTransition(int fromIndex, int toIndex) {
    return !_ignoredPageTransitionIndexes.contains(fromIndex) &&
        !_ignoredPageTransitionIndexes.contains(toIndex);
  }

  void _recordPageTransitionIfNeeded(int nextPageIndex) {
    if (!_shouldRecordPageTransition(slidePageIndexNow, nextPageIndex)) {
      return;
    }

    _recordProjectHistorySnapshot(isPageTransition: true);
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
    _projectDataRevision++;
    _lastRecordedProjectDataRevision = _projectDataRevision;

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

  void _updateAllWordCounts() {
    _wordCountService.synchronizeChapters(
      segmentsData.expand(
        (segment) => segment.chapters.map(
          (chapter) => WordCountChapterInput(
            chapterId: chapter.chapterUUID,
            content: chapter.chapterContent,
          ),
        ),
      ),
      _settingsState.wordCountMode,
    );
    totalWords = _wordCountService.total;
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
    if (showFindReplaceWindow) {
      cancelFindAllMatches(textController);
      cancelReplaceAll(textController);
    }
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
    return _EditorStatusBar(
      textController: textController,
      projectName: currentProject?.nameWithoutExtension ?? "Untitled",
      hasUnsavedChanges: hasUnsavedChanges,
      lastSavedTime: lastSavedTime,
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
        _recordPageTransitionIfNeeded(index);
        setState(() {
          slidePageIndexNow = index;
        });
      },
      pageBuilder: _buildSpecificPageContent,
    );
  }

  // 特定頁面內容建構（用於 IndexedStack）
  Widget _buildSpecificPageContent(int pageIndex) {
    late final Widget page;
    switch (pageIndex) {
      case 0:
        page = _buildWelcomeView();
        break;
      case 1:
        page = _buildBaseInfoView();
        break;
      case 2:
        page = _buildChapterSelectionView();
        break;
      case 3:
        page = _buildOutlineView();
        break;
      case 4:
        page = _buildWorldSettingsView();
        break;
      case 5:
        page = _buildCharacterSettingsView();
        break;
      case 6:
        page = _buildTimelineView();
        break;
      case 7:
        page = _buildRelationView();
        break;
      case 8:
        page = _buildPlanView();
        break;
      case 9:
        page = _buildGlossaryView();
        break;
      case 10:
        page = _buildProofreadingView();
        break;
      case 11:
        page = _buildCopilotView();
        break;
      case 12:
        page = _buildSettingView();
        break;
      case 13:
        page = _buildAboutView();
        break;
      default:
        page = Center(child: Text("Page ${pageIndex + 1}"));
    }

    if (!_projectBackedPageIndexes.contains(pageIndex)) {
      return page;
    }

    // IndexedStack normally preserves every project page's State. Use a new
    // session key after switching projects so controllers and selections cannot
    // keep values that belong to the previous project.
    return KeyedSubtree(
      key: ValueKey("project-$_projectSessionVersion-page-$pageIndex"),
      child: page,
    );
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
                  _recordPageTransitionIfNeeded(index);
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
                  if (textController.text.isNotEmpty) {
                    // Async search (background isolate + precomputed index)
                    final searchResult = await findAllMatchesLatest(
                      textController,
                      findText,
                      options,
                      maxResults:
                          HighlightTextEditingController.maxSearchResults,
                    );
                    if (!mounted ||
                        searchResult == null ||
                        !searchResult.isCurrent(
                          textController,
                          findController.text,
                          findReplaceOptions,
                          maxResults:
                              HighlightTextEditingController.maxSearchResults,
                        )) {
                      return;
                    }

                    setState(() {
                      // 更新高亮顯示（使用預編譯的索引）
                      searchResult.applyHighlights(
                        textController,
                        currentIndex: _currentMatchIndex,
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
                  cancelFindAllMatches(textController);
                  setState(() {
                    _searchMatches = [];
                    _currentMatchIndex = -1;
                    textController.clearAllHighlights();
                  });
                }
              },
              onClose: () {
                cancelFindAllMatches(textController);
                cancelReplaceAll(textController);
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
    return CharacterView(
      projectSessionId: _projectSessionVersion,
      initialCharacterId: _requestedCharacterId,
      selectionRequestId: _characterSelectionRequestId,
    );
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
    return CharacterRelationshipGraphView(
      projectSessionId: _projectSessionVersion,
      onOpenCharacter: (characterId) {
        _syncEditorToSelectedChapter();
        _recordPageTransitionIfNeeded(5);
        setState(() {
          _requestedCharacterId = characterId;
          _characterSelectionRequestId++;
          slidePageIndexNow = 5;
        });
      },
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

    await AppDialog.showCustom(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AppDialog(
              title: "匯出選項",
              icon: Icons.ios_share_outlined,
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
    CharacterDraftSessionCoordinator.instance.flush(_projectSessionVersion);
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
  void _resetProjectSessionUiState() {
    CharacterDraftSessionCoordinator.instance.flushAndClose(
      _projectSessionVersion,
    );
    _projectSessionVersion++;
    _requestedCharacterId = null;
    _characterSelectionRequestId = 0;
    _lastFocusedEditableNode = null;
    _preserveEditableFocusForEditorAction = false;

    cancelFindAllMatches(textController);
    cancelReplaceAll(textController);
    findController.clear();
    replaceController.clear();
    _searchMatches = const <TextSelection>[];
    _currentMatchIndex = -1;
    textController.clearAllHighlights(notify: false);
    showFindReplaceWindow = false;
  }

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

    _isProjectSwitching = true;
    final switchSession = _projectIoCoordinator.beginSession("switch:new");
    _projectIoSession = switchSession;
    try {
      final runResult = await _projectIoCoordinator.run(
        switchSession,
        () => ref.read(projectIoControllerProvider.notifier).createNewProject(),
      );
      final result = runResult.value;
      if (!mounted ||
          result == null ||
          !_projectIoCoordinator.isCurrent(switchSession)) {
        return;
      }

      final initialState = ref
          .read(editorCoordinatorProvider.notifier)
          .calculateInitialState(result.data, _settingsState.wordCountMode);

      setState(() {
        _resetProjectSessionUiState();
        currentProject = result.projectFile;
        _resetAutoBackupBaseline();
        _applyProjectData(result.data, initialState);
      });
      _beginProjectIoSession(result.projectFile);
      _editorCoordinatorNotifier.resetAfterProjectLoaded();
      _resetProjectHistory();
      if (!mounted) {
        return;
      }
      _showMessage("新專案建立成功！");

      _updateAllWordCounts();
    } catch (e) {
      if (mounted && _projectIoCoordinator.isCurrent(switchSession)) {
        _showError("建立新專案失敗：${e.toString()}");
        _beginProjectIoSession(currentProject);
      }
    } finally {
      if (_projectIoCoordinator.isCurrent(switchSession)) {
        _beginProjectIoSession(currentProject);
      }
      _isProjectSwitching = false;
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

    _isProjectSwitching = true;
    final switchSession = _projectIoCoordinator.beginSession("switch:open");
    _projectIoSession = switchSession;
    try {
      final runResult = await _projectIoCoordinator.run(
        switchSession,
        () async {
          final controller = ref.read(projectIoControllerProvider.notifier);
          final projectFile = await controller.pickProjectFile();
          return projectFile == null
              ? null
              : controller.loadProject(projectFile);
        },
      );
      final loadResult = runResult.value;
      if (!mounted || !_projectIoCoordinator.isCurrent(switchSession)) {
        return;
      }
      if (loadResult == null) {
        _beginProjectIoSession(currentProject);
        return;
      }
      final projectFile = loadResult.projectFile;
      final openedVersion = loadResult.projectVersion;
      final hasNewerVersion = FileService.isProjectVersionNewerThanSupported(
        openedVersion,
      );

      if (hasNewerVersion) {
        if (!mounted || !_projectIoCoordinator.isCurrent(switchSession)) {
          return;
        }
        final shouldContinue =
            await ProjectManager.showVersionCompatibilityDialog(
              context,
              fileVersion: openedVersion ?? "unknown",
              supportedVersion: FileService.projectVersion,
            );
        if (!mounted || !_projectIoCoordinator.isCurrent(switchSession)) {
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
        _resetProjectSessionUiState();
        currentProject = projectFile;
        _resetAutoBackupBaseline();
        _applyProjectData(data, initialState);
      });
      _beginProjectIoSession(projectFile);
      _editorCoordinatorNotifier.resetAfterProjectLoaded();
      _resetProjectHistory();

      // Start the background count immediately after applying the project.
      // Persisting the recent-project entry can involve platform storage and
      // must not delay the visible total word count.
      _updateAllWordCounts();

      await _editorCoordinatorNotifier.recordRecentProject(projectFile);
      if (!mounted || !_projectIoCoordinator.isCurrent(switchSession)) {
        return;
      }
      final migrationSuffix = loadResult.wasMigrated
          ? "（已在記憶體升級至 ${FileService.projectVersion}，${loadResult.migrationWarnings.length} 項警告）"
          : "";
      for (final warning in loadResult.migrationWarnings) {
        debugPrint(
          "Project migration warning [${warning.code}]: ${warning.message}",
        );
      }
      _showMessage(
        "專案開啟成功：${projectFile.nameWithoutExtension}$migrationSuffix",
      );
    } catch (e) {
      if (mounted && _projectIoCoordinator.isCurrent(switchSession)) {
        _showError("開啟專案失敗：${e.toString()}");
        _beginProjectIoSession(currentProject);
      }
    } finally {
      if (_projectIoCoordinator.isCurrent(switchSession)) {
        _beginProjectIoSession(currentProject);
      }
      _isProjectSwitching = false;
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

    _isProjectSwitching = true;
    final switchSession = _projectIoCoordinator.beginSession("switch:recent");
    _projectIoSession = switchSession;
    try {
      final runResult = await _projectIoCoordinator.run(
        switchSession,
        () async {
          final controller = ref.read(projectIoControllerProvider.notifier);
          final projectFile = await controller.openProjectFromPath(
            entry.filePath!,
            accessToken: entry.uri,
          );
          return controller.loadProject(projectFile);
        },
      );
      final loadResult = runResult.value;
      if (!mounted ||
          loadResult == null ||
          !_projectIoCoordinator.isCurrent(switchSession)) {
        return;
      }
      final projectFile = loadResult.projectFile;
      final openedVersion = loadResult.projectVersion;
      final hasNewerVersion = FileService.isProjectVersionNewerThanSupported(
        openedVersion,
      );

      if (hasNewerVersion) {
        if (!mounted || !_projectIoCoordinator.isCurrent(switchSession)) {
          return;
        }
        final shouldContinue =
            await ProjectManager.showVersionCompatibilityDialog(
              context,
              fileVersion: openedVersion ?? "unknown",
              supportedVersion: FileService.projectVersion,
            );
        if (!mounted || !_projectIoCoordinator.isCurrent(switchSession)) {
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
        _resetProjectSessionUiState();
        currentProject = projectFile;
        _resetAutoBackupBaseline();
        _applyProjectData(data, initialState);
      });
      _beginProjectIoSession(projectFile);
      _editorCoordinatorNotifier.resetAfterProjectLoaded();
      _resetProjectHistory();

      // Keep word-count refresh independent from recent-project persistence.
      _updateAllWordCounts();

      await _editorCoordinatorNotifier.recordRecentProject(projectFile);
      if (!mounted || !_projectIoCoordinator.isCurrent(switchSession)) {
        return;
      }
      final migrationSuffix = loadResult.wasMigrated
          ? "（已在記憶體升級至 ${FileService.projectVersion}，${loadResult.migrationWarnings.length} 項警告）"
          : "";
      for (final warning in loadResult.migrationWarnings) {
        debugPrint(
          "Project migration warning [${warning.code}]: ${warning.message}",
        );
      }
      _showMessage(
        "專案開啟成功：${projectFile.nameWithoutExtension}$migrationSuffix",
      );
    } catch (e) {
      if (mounted && _projectIoCoordinator.isCurrent(switchSession)) {
        final message = e.toString();
        _showError("開啟最近專案失敗：$message");
        if (message.contains("檔案不存在")) {
          unawaited(
            ref.read(settingsStateProvider.notifier).removeRecentProject(entry),
          );
        }
        _beginProjectIoSession(currentProject);
      }
    } finally {
      if (_projectIoCoordinator.isCurrent(switchSession)) {
        _beginProjectIoSession(currentProject);
      }
      _isProjectSwitching = false;
    }
  }

  Future<void> _deleteRecentProject(RecentProjectEntry entry) async {
    await ref.read(settingsStateProvider.notifier).removeRecentProject(entry);
    if (!mounted) return;
    _showMessage("已從最近清單移除：${entry.fileName}");
  }

  Future<void> _saveProject() async {
    if (_isProjectSwitching) return;
    _syncEditorToSelectedChapter();
    final session = _projectIoSession;
    final revision = _projectDataRevision;
    final currentData = _collectProjectData();

    try {
      final runResult = await _projectIoCoordinator.run(session, () async {
        final payload = await _sharedProjectIoPayload(
          session: session,
          revision: revision,
          data: currentData,
        );
        return ref
            .read(projectIoControllerProvider.notifier)
            .saveProject(
              currentProject: currentProject,
              currentData: currentData,
              forceSaveAs: false,
              preparedPayload: payload,
            );
      });
      final savedProject = runResult.value;
      if (!mounted ||
          savedProject == null ||
          !_projectIoCoordinator.isCurrent(session)) {
        return;
      }
      setState(() => currentProject = savedProject);
      if (_projectDataRevision == revision) {
        _markAsSaved();
      }
      if (_projectIdentity(savedProject) != session.projectIdentity) {
        _beginProjectIoSession(savedProject);
      }
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
    if (_isProjectSwitching) return;
    _syncEditorToSelectedChapter();
    final session = _projectIoSession;
    final revision = _projectDataRevision;
    final currentData = _collectProjectData();

    try {
      final runResult = await _projectIoCoordinator.run(session, () async {
        final payload = await _sharedProjectIoPayload(
          session: session,
          revision: revision,
          data: currentData,
        );
        return ref
            .read(projectIoControllerProvider.notifier)
            .saveProject(
              currentProject: currentProject,
              currentData: currentData,
              forceSaveAs: true,
              preparedPayload: payload,
            );
      });
      final savedProject = runResult.value;
      if (!mounted ||
          savedProject == null ||
          !_projectIoCoordinator.isCurrent(session)) {
        return;
      }
      setState(() => currentProject = savedProject);
      if (_projectDataRevision == revision) {
        _markAsSaved();
      }
      _beginProjectIoSession(savedProject);
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
    CharacterDraftSessionCoordinator.instance.flush(_projectSessionVersion);
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

/************************************************
誰偷了我的芳文人生==

為什麼我已經17歲了，
還沒有加入輕音部，
沒有轉學到天宮女學院，也沒有加入漫畫咖啡廳「刺蝟」，
沒有加入情報處理部，
沒有從英國來的金髮蘿莉來我們學校交換，
沒有在轉學後在路邊睡著遇到同校的露營專家，
沒有來到RPG不動產，
沒有考上天之御船學園幸福班，
沒有遇到對夜來舞有興趣的如妖精般的外國人，
沒有去Rabbit House打工，
沒有人跟我約定一起找小行星，也沒有加入地學部，
沒有遇見自稱外星人的神秘新生，
沒有在因緣際會下去角色扮演咖啡廳當抖S，
沒有考上美術班，
沒有在文芳社當4コマ家，
進了板中資訊社發現這裡沒有做同人遊戲的SNS部==
************************************************/
