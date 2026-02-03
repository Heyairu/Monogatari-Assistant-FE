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

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter/foundation.dart";
import "dart:ui" as ui;
import "package:intl/intl.dart"; // Add intl for date formatting
import "package:window_manager/window_manager.dart";
import "bin/file.dart";
import "bin/findreplace.dart";
import "bin/ui_library.dart";
import "bin/settings_manager.dart";

import "modules/baseinfoview.dart" as BaseInfoModule;
import "modules/chapterselectionview.dart" as ChapterModule;
import "modules/AboutView.dart" as AboutModule;
import "modules/outlineview.dart" as OutlineModule;
import "modules/worldsettingsview.dart";
import "modules/characterview.dart";
import "modules/settingview.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化 window_manager
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || 
      defaultTargetPlatform == TargetPlatform.linux || 
      defaultTargetPlatform == TargetPlatform.macOS)) {
    await windowManager.ensureInitialized();
  }
  
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final UILibrary _themeManager = UILibrary();
  final SettingsManager _settingsManager = SettingsManager();
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _themeManager.addListener(() {
      setState(() {});
    });
    _settingsManager.addListener(() {
      setState(() {});
    });
  }

  Future<void> _initializeApp() async {
    await Future.wait([
      _themeManager.initialize(),
      _settingsManager.initialize(),
    ]);
    setState(() {
      _isInitializing = false;
    });
  }

  @override
  void dispose() {
    _themeManager.dispose();
    _settingsManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 顯示載入畫面直到主題管理器初始化完成
    if (_isInitializing) {
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

    return MaterialApp(
      title: "物語Assistant",
      theme: AppTheme.getLightTheme(_settingsManager.fontSize, _themeManager.themeColor),
      darkTheme: AppTheme.getDarkTheme(_settingsManager.fontSize, _themeManager.themeColor),
      themeMode: _convertThemeMode(_themeManager.themeMode),
      home: ContentView(
        themeManager: _themeManager,
        settingsManager: _settingsManager,
      ),
    );
  }

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
}

// 自定義 TextEditingController，支持高亮顯示
class HighlightTextEditingController extends TextEditingController {
  List<TextSelection> searchMatches = [];
  int currentMatchIndex = -1;
  Color? highlightColor;
  Color? currentHighlightColor;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (searchMatches.isEmpty) {
      return TextSpan(text: text, style: style);
    }

    final List<TextSpan> spans = [];
    int lastEnd = 0;

    for (int i = 0; i < searchMatches.length; i++) {
      final match = searchMatches[i];
      
      // 添加匹配項之前的普通文本
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: style,
        ));
      }

      // 添加高亮的匹配項
      final isCurrentMatch = i == currentMatchIndex;
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: style?.copyWith(
          backgroundColor: isCurrentMatch
              ? (currentHighlightColor ?? Colors.orange.withOpacity(0.6))
              : (highlightColor ?? Colors.yellow.withOpacity(0.4)),
        ),
      ));

      lastEnd = match.end;
    }

    // 添加最後一個匹配項之後的文本
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: style,
      ));
    }

    return TextSpan(children: spans, style: style);
  }

  void updateHighlights({
    required List<TextSelection> matches,
    required int currentIndex,
    Color? highlight,
    Color? currentHighlight,
  }) {
    searchMatches = matches;
    currentMatchIndex = currentIndex;
    highlightColor = highlight;
    currentHighlightColor = currentHighlight;
    notifyListeners();
  }

  void clearHighlights() {
    searchMatches = [];
    currentMatchIndex = -1;
    notifyListeners();
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
  }) : locationUUID = locationUUID ?? DateTime.now().millisecondsSinceEpoch.toString();
}

// 主要 ContentView
class ContentView extends StatefulWidget {
  final UILibrary themeManager;
  final SettingsManager settingsManager;
  
  const ContentView({
    super.key,
    required this.themeManager,
    required this.settingsManager,
  });

  @override
  State<ContentView> createState() => _ContentViewState();
}

class _ContentViewState extends State<ContentView> with WindowListener {
  // 狀態變數
  int slidePage = 0;
  int autoSaveTime = 1;
  
  // 主編輯器文字
  String contentText = "";
  final HighlightTextEditingController textController = HighlightTextEditingController();
  
  // 浮動視窗狀態
  bool showFindReplaceWindow = false;
  final TextEditingController findController = TextEditingController();
  final TextEditingController replaceController = TextEditingController();
  final FindReplaceOptions findReplaceOptions = FindReplaceOptions();
  final FocusNode editorFocusNode = FocusNode();
  
  // 搜尋狀態
  int _currentMatchIndex = -1;
  List<TextSelection> _searchMatches = [];
  
  // 數據狀態
  BaseInfoModule.BaseInfoData baseInfoData = BaseInfoModule.BaseInfoData();
  List<ChapterModule.SegmentData> segmentsData = [
    ChapterModule.SegmentData(
      segmentName: "Seg 1",
      chapters: [ChapterModule.ChapterData(chapterName: "Chapter 1", chapterContent: "")],
    )
  ];
  
  List<OutlineModule.StorylineData> outlineData = [
    OutlineModule.StorylineData(
      storylineName: "主線 1",
      storylineType: "起",
      scenes: [
        OutlineModule.StoryEventData(
          storyEvent: "事件 1",
          scenes: [OutlineModule.SceneData(sceneName: "場景 A")],
          memo: "",
          conflictPoint: ""
        )
      ],
      memo: "",
      conflictPoint: ""
    )
  ];
  
  List<LocationData> worldSettingsData = [];
  Map<String, Map<String, dynamic>> characterData = {};
  
  // 選取狀態
  String? selectedSegID;
  String? selectedChapID;
  int totalWords = 0;
  
  // 檔案狀態
  ProjectFile? currentProject;
  bool showingError = false;
  String errorMessage = "";
  bool isLoading = false;
  bool hasUnsavedChanges = false;
  DateTime? _lastSavedTime; // Track last saved time
  
  // 同步狀態標記 - 防止在同步期間觸發循環更新
  bool _isSyncing = false;
  
  @override
  void initState() {
    super.initState();
    
    // 註冊視窗監聽器並設置視窗選項
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || 
        defaultTargetPlatform == TargetPlatform.linux || 
        defaultTargetPlatform == TargetPlatform.macOS)) {
      windowManager.addListener(this);
      _initWindowManager();
    }
    
    // 初始化選取項目和編輯器內容
    if (segmentsData.isNotEmpty && segmentsData[0].chapters.isNotEmpty) {
      selectedSegID = segmentsData[0].segmentUUID;
      selectedChapID = segmentsData[0].chapters[0].chapterUUID;
      contentText = segmentsData[0].chapters[0].chapterContent;
    }
    
    textController.text = contentText;
    
    // 監聽文字變化
    textController.addListener(() {
      // 只有當文字真的改變且不在同步狀態時才更新
      if (!_isSyncing && contentText != textController.text) {
        setState(() {
          contentText = textController.text;
          totalWords = contentText.split(RegExp(r"\s+")).where((word) => word.isNotEmpty).length;
          
          // 標記有未儲存的變更
          _markAsModified();
          
          // 當文字內容變化時，清除所有高亮和搜尋狀態
          _searchMatches = [];
          _currentMatchIndex = -1;
          textController.clearHighlights();
        });
      }
    });
    
    // 應用程式啟動時自動創建新專案
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _newProject();
    });
  }
  
  @override
  void dispose() {
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || 
        defaultTargetPlatform == TargetPlatform.linux || 
        defaultTargetPlatform == TargetPlatform.macOS)) {
      windowManager.removeListener(this);
    }
    textController.dispose();
    findController.dispose();
    replaceController.dispose();
    editorFocusNode.dispose();
    super.dispose();
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
  
  // 搜尋與取代功能實作
  
  /// 執行搜尋
  void _performFind(String findText, FindReplaceOptions options, {bool forward = true}) {
    if (findText.isEmpty) {
      return;
    }
    
    final text = textController.text;
    if (text.isEmpty) {
      return;
    }
    
    // 找出所有匹配項（使用 findreplace.dart 的函數）
    _searchMatches = findAllMatches(text, findText, options);
    
    if (_searchMatches.isEmpty) {
      _currentMatchIndex = -1;
      textController.updateHighlights(
        matches: [],
        currentIndex: -1,
      );
      setState(() {}); // 更新 UI 以顯示 0 個匹配
      return;
    }
    
    // 取得當前光標位置
    final currentOffset = textController.selection.baseOffset;
    
    // 如果是第一次搜尋（_currentMatchIndex == -1），從當前光標位置開始搜尋
    if (_currentMatchIndex == -1) {
      if (forward) {
        // 向下搜尋：找到第一個在光標位置之後的匹配項
        _currentMatchIndex = _searchMatches.indexWhere((match) => match.start >= currentOffset);
        // 如果沒找到，從頭開始
        if (_currentMatchIndex == -1) {
          _currentMatchIndex = 0;
        }
      } else {
        // 向上搜尋：找到最後一個在光標位置之前的匹配項
        _currentMatchIndex = _searchMatches.lastIndexWhere((match) => match.end <= currentOffset);
        // 如果沒找到，從最後一個開始
        if (_currentMatchIndex == -1) {
          _currentMatchIndex = _searchMatches.length - 1;
        }
      }
    } else {
      // 移動到下一個/上一個匹配項
      if (forward) {
        _currentMatchIndex = (_currentMatchIndex + 1) % _searchMatches.length;
      } else {
        _currentMatchIndex = (_currentMatchIndex - 1 + _searchMatches.length) % _searchMatches.length;
      }
    }
    
    // 更新高亮顯示
    textController.updateHighlights(
      matches: _searchMatches,
      currentIndex: _currentMatchIndex,
    );
    
    // 選中當前匹配項
    final match = _searchMatches[_currentMatchIndex];
    textController.selection = match;
    
    // 請求焦點以顯示選取效果
    editorFocusNode.requestFocus();
    
    setState(() {}); // 更新 UI 以顯示當前匹配數
  }
  
  /// 執行取代（取代當前選中的項目）
  void _performReplace(String findText, String replaceText, FindReplaceOptions options) {
    if (findText.isEmpty) {
      return;
    }
    
    final selection = textController.selection;
    if (!selection.isValid || selection.isCollapsed) {
      // 如果沒有選取，先搜尋
      _performFind(findText, options, forward: true);
      return;
    }
    
    // 檢查當前選取是否對應當前匹配項
    if (_currentMatchIndex >= 0 && _currentMatchIndex < _searchMatches.length) {
      final currentMatch = _searchMatches[_currentMatchIndex];
      
      // 確認選取範圍與當前匹配項一致
      if (selection.start == currentMatch.start && selection.end == currentMatch.end) {
        String actualReplaceText = replaceText;
        
        // 如果是正則表達式模式，處理捕獲組
        if (options.useRegexp) {
          try {
            // 正則表達式模式固定啟用大小寫相符
            final regex = RegExp(findText, caseSensitive: true);
            final text = textController.text;
            final matchText = text.substring(selection.start, selection.end);
            final regexMatch = regex.firstMatch(matchText);
            
            if (regexMatch != null) {
              actualReplaceText = replaceText;
              // 替換捕獲組引用 $1, $2, ... 和 \1, \2, ...
              for (int i = 0; i <= regexMatch.groupCount; i++) {
                final groupValue = regexMatch.group(i) ?? "";
                // 支援 $0, $1, $2, ... 語法
                actualReplaceText = actualReplaceText.replaceAll("\$$i", groupValue);
                // 支援 \0, \1, \2, ... 反向引用語法
                actualReplaceText = actualReplaceText.replaceAll("\\$i", groupValue);
              }
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("正則表達式錯誤: $e")),
            );
            return;
          }
        }
        
        // 執行取代
        final newText = textController.text.replaceRange(
          selection.start,
          selection.end,
          actualReplaceText,
        );
        
        setState(() {
          textController.text = newText;
          textController.selection = TextSelection.collapsed(
            offset: selection.start + actualReplaceText.length,
          );
          contentText = newText;
          totalWords = contentText.split(RegExp(r"\s+")).where((word) => word.isNotEmpty).length;
          
          // 清除搜尋狀態，因為文本已改變
          _searchMatches = [];
          _currentMatchIndex = -1;
          textController.clearHighlights();
        });
        
        // 自動尋找下一個
        _performFind(findText, options, forward: true);
        return;
      }
    }
    
    // 如果不匹配，嘗試先搜尋
    _performFind(findText, options, forward: true);
  }
  
  /// 執行全部取代
  void _performReplaceAll(String findText, String replaceText, FindReplaceOptions options) {
    if (findText.isEmpty) {
      return;
    }
    
    final text = textController.text;
    if (text.isEmpty) {
      return;
    }
    
    // 找出所有匹配項（使用 findreplace.dart 的函數）
    final matches = findAllMatches(text, findText, options);
    
    if (matches.isEmpty) {
      return;
    }
    
    String newText = text;
    
    // 如果是正則表達式模式，使用正則表達式替換來支援捕獲組
    if (options.useRegexp) {
      try {
        // 正則表達式模式固定啟用大小寫相符
        final regex = RegExp(findText, caseSensitive: true);
        newText = newText.replaceAllMapped(regex, (match) {
          String replacement = replaceText;
          // 替換捕獲組引用 $1, $2, ... 和 \1, \2, ...
          for (int i = 0; i <= match.groupCount; i++) {
            final groupValue = match.group(i) ?? "";
            // 支援 $0, $1, $2, ... 語法
            replacement = replacement.replaceAll("\$$i", groupValue);
            // 支援 \0, \1, \2, ... 反向引用語法
            replacement = replacement.replaceAll("\\$i", groupValue);
          }
          return replacement;
        });
      } catch (e) {
        // 如果正則表達式無效，顯示錯誤並返回
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("正則表達式錯誤: $e")),
        );
        return;
      }
    } else {
      // 非正則表達式模式，從後往前取代，避免位置偏移問題
      for (int i = matches.length - 1; i >= 0; i--) {
        final match = matches[i];
        newText = newText.replaceRange(match.start, match.end, replaceText);
      }
    }
    
    setState(() {
      textController.text = newText;
      textController.selection = TextSelection.collapsed(offset: 0);
      contentText = newText;
      totalWords = contentText.split(RegExp(r"\s+")).where((word) => word.isNotEmpty).length;
      _currentMatchIndex = -1;
      _searchMatches = [];
      textController.clearHighlights();
    });
  }

  // MARK: 主體建構方法
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        
        final shouldPop = await _handleExit();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: LayoutBuilder(
          builder: (context, constraints) {
            // 響應式佈局：根據螢幕寬度決定使用堆疊還是分割佈局
            if (constraints.maxWidth < 800) {
              return _buildMobileLayout();
            } else {
              return _buildDesktopLayout();
            }
          },
        ),
      ),
    );
  }
  
  // AppBar 建構方法
  PreferredSizeWidget _buildAppBar() {
    final double iconSize = widget.settingsManager.fontSize + 10;

    return AppBar(
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Image.asset(
          "assets/icon/app_icon.png",
          errorBuilder: (context, error, stackTrace) {
            return Icon(Icons.auto_stories, size: iconSize + 8);
          },
        ),
      ),
      titleSpacing: 0,
      title: Align(
        alignment: Alignment.centerRight,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            
              // 檔案選單
              PopupMenuButton<String>(
                icon: const Icon(Icons.folder),
                iconSize: iconSize,
                tooltip: "檔案",
                onSelected: _handleFileAction,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: "new",
                    child: ListTile(
                      leading: Icon(Icons.note_add),
                      title: Text("新建檔案"),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: "open",
                    child: ListTile(
                      leading: Icon(Icons.folder_open),
                      title: Text("開啟檔案"),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: "save",
                    child: ListTile(
                      leading: Icon(Icons.save),
                      title: Text("儲存檔案"),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: "saveAs",
                    child: ListTile(
                      leading: Icon(Icons.save_as),
                      title: Text("另存新檔"),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              
              // 編輯工具
              IconButton(
                iconSize: iconSize,
                icon: const Icon(Icons.select_all),
                onPressed: () => _performEditorAction("selectAll"),
                tooltip: "Select All",
              ),
              IconButton(
                iconSize: iconSize,
                icon: const Icon(Icons.content_cut),
                onPressed: () => _performEditorAction("cut"),
                tooltip: "Cut",
              ),
              IconButton(
                iconSize: iconSize,
                icon: const Icon(Icons.content_copy),
                onPressed: () => _performEditorAction("copy"),
                tooltip: "Copy",
              ),
              IconButton(
                iconSize: iconSize,
                icon: const Icon(Icons.content_paste),
                onPressed: () => _performEditorAction("paste"),
                tooltip: "Paste",
              ),
              
              IconButton(
                iconSize: iconSize,
                icon: const Icon(Icons.undo),
                onPressed: () => _performEditorAction("undo"),
                tooltip: "Undo",
              ),
              IconButton(
                iconSize: iconSize,
                icon: const Icon(Icons.redo),
                onPressed: () => _performEditorAction("redo"),
                tooltip: "Redo",
              ),
              Container(
                decoration: showFindReplaceWindow
                    ? BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                child: IconButton(
                  iconSize: iconSize,
                  icon: Icon(
                    showFindReplaceWindow ? Icons.search_off : Icons.search,
                  ),
                  color: showFindReplaceWindow
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : null,
                  onPressed: () {
                    // 切換到編輯器頁面並顯示/隱藏浮動視窗
                    setState(() {
                      // 如果當前不在編輯器頁面，切換到編輯器頁面並顯示浮動視窗
                      if (slidePage < 10) {
                        slidePage = 10;
                        showFindReplaceWindow = true;
                      } else {
                        // 如果已經在編輯器頁面，切換浮動視窗的顯示狀態
                        if (!showFindReplaceWindow) {
                          // 打開搜尋窗口時，重置搜尋狀態但保留編輯器的光標位置
                          _currentMatchIndex = -1;
                        }
                        showFindReplaceWindow = !showFindReplaceWindow;
                      }
                    });
                  },
                  tooltip: showFindReplaceWindow ? "關閉搜尋" : "搜尋",
                ),
              ),
              
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      elevation: 0,
    );
  }

  // 手機佈局（使用 BottomNavigationBar）
  Widget _buildMobileLayout() {
    // 檢查是否在編輯器頁面（slidePage > 9 表示編輯器）
    bool isEditorMode = slidePage > 9;
    
    return Scaffold(
      body: IndexedStack(
        index: isEditorMode ? 1 : 0,  // 0: 功能頁面, 1: 編輯器
        children: [
          _buildMobileFunctionPage(),
          _buildEditor(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMobileStatusBar(),
          NavigationBar(
            selectedIndex: isEditorMode ? 1 : 0,
            onDestinationSelected: (index) {
              // 在切換前同步編輯器內容
              _syncEditorToSelectedChapter();
              
              setState(() {
                if (index == 0) {
                  // 切換到功能頁面，保持當前的功能選項
                  if (slidePage > 9) slidePage = 0; // 如果在編輯器，切回第一個功能
                } else {
                  // 切換到編輯器
                  slidePage = 10; // 使用 10 作為編輯器的標識
                }
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard),
                label: "功能",
              ),
              NavigationDestination(
                icon: Icon(Icons.edit_note),
                label: "編輯器",
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // 手機狀態列 - 顯示專案資訊
  Widget _buildMobileStatusBar() {
    String projectName = currentProject?.nameWithoutExtension ?? "未命名專案";
    if (hasUnsavedChanges) projectName += "*";
    
    String currentPosition = "";
    if (selectedSegID != null && selectedChapID != null) {
      for (final seg in segmentsData) {
        if (seg.segmentUUID == selectedSegID) {
          for (final chap in seg.chapters) {
            if (chap.chapterUUID == selectedChapID) {
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
    
    String saveTimeStr = _lastSavedTime != null 
        ? DateFormat("HH:mm").format(_lastSavedTime!) 
        : "--:--";
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.description, 
                  size: widget.settingsManager.fontSize, 
                  color: Theme.of(context).colorScheme.primary
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _ScrollingText(
                    text: displayText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.access_time, 
            size: widget.settingsManager.fontSize, 
            color: Theme.of(context).colorScheme.onSurfaceVariant
          ),
          const SizedBox(width: 4),
          Text(
            saveTimeStr,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              "$totalWords 字",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 手機功能頁面（包含功能切換和內容）
  Widget _buildMobileFunctionPage() {
    return Column(
      children: [
        // 功能頁面導航
        Container(
          height: 60,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                for (int i = 0; i < 9; i++)
                  _buildMobileNavigationChip(i),
              ],
            ),
          ),
        ),
        
        // 功能頁面內容 - 使用 IndexedStack 保持狀態
        Expanded(
          child: IndexedStack(
            index: slidePage.clamp(0, 8),
            children: [
              for (int i = 0; i < 9; i++)
                _buildSpecificPageContent(i),
            ],
          ),
        ),
      ],
    );
  }
  
  // 手機導航晶片
  Widget _buildMobileNavigationChip(int index) {
    final List<Map<String, dynamic>> functions = [
      {"icon": Icons.book, "label": "故事設定"},
      {"icon": Icons.menu_book, "label": "章節選擇"},
      {"icon": Icons.list, "label": "大綱調整"},
      {"icon": Icons.public, "label": "世界設定"},
      {"icon": Icons.person, "label": "角色設定"},
      {"icon": Icons.library_books, "label": "詞語參考"},
      {"icon": Icons.spellcheck, "label": "文本校正"},
      {"icon": Icons.auto_awesome, "label": "Copilot"},
      {"icon": Icons.settings, "label": "設定"},
      {"icon": Icons.info, "label": "關於"},
    ];
    
    final function = functions[index];
    final isSelected = slidePage == index;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: FilterChip(
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            // 在切換前同步編輯器內容
            _syncEditorToSelectedChapter();
            
            setState(() {
              slidePage = index;
            });
          }
        },
        avatar: Icon(
          function["icon"],
          size: widget.settingsManager.fontSize + 4,
          color: isSelected 
            ? Theme.of(context).colorScheme.onSecondaryContainer
            : Theme.of(context).colorScheme.onSurface,
        ),
        label: Text(
          function["label"],
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        backgroundColor: isSelected 
          ? Theme.of(context).colorScheme.secondaryContainer
          : null,
        selectedColor: Theme.of(context).colorScheme.secondaryContainer,
        checkmarkColor: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    );
  }

  // 特定頁面內容建構（用於 IndexedStack）
  Widget _buildSpecificPageContent(int pageIndex) {
    switch (pageIndex) {
      case 0:
        return _buildBaseInfoView();
      case 1:
        return _buildChapterSelectionView();
      case 2:
        return _buildOutlineView();
      case 3:
        return _buildWorldSettingsView();
      case 4:
        return _buildCharacterSettingsView();
      case 5:
        return _buildGlossaryView();
      case 6:
        return _buildProofreadingView();
      case 7:
        return _buildCopilotView();
      case 8:
        return _buildSettingView();
      case 9:
        return _buildAboutView();
      default:
        return Center(child: Text("Page ${pageIndex + 1}"));
    }
  }

  // 桌面佈局（使用 NavigationRail）
  Widget _buildDesktopLayout() {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // NavigationRail - 包裝在可滾动容器中
              SingleChildScrollView(
                child: IntrinsicHeight(
                  child: NavigationRail(
                    selectedIndex: _getNavigationIndex(),
                    onDestinationSelected: (index) {
                      // 在切換前同步編輯器內容
                      _syncEditorToSelectedChapter();
                      
                      setState(() {
                        slidePage = index;
                      });
                    },
                    labelType: NavigationRailLabelType.all,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.book),
                        label: Text("故事設定"),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.menu_book),
                        label: Text("章節選擇"),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.list),
                        label: Text("大綱調整"),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.public),
                        label: Text("世界設定"),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.person),
                        label: Text("角色設定"),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.library_books),
                        label: Text("詞語參考"),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.spellcheck),
                        label: Text("文本校正"),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.auto_awesome),
                        label: Text("Copilot"),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.settings),
                        label: Text("設定"),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.info),
                        label: Text("關於"),
                      ),
                    ],
                  ),
                ),
              ),
              
              // 垂直分隔線
              const VerticalDivider(thickness: 1, width: 1),
              
              // 主要內容區域
              Expanded(
                child: Row(
                  children: [
                    // 左側內容區域
                    Expanded(
                      flex: 2,
                      child: Container(
                        color: Theme.of(context).colorScheme.surfaceContainerLowest,
                        child: _buildPageContent(),
                      ),
                    ),
                    
                    // 垂直分隔線
                    const VerticalDivider(thickness: 1, width: 1),
                    
                    // 右側編輯器
                    Expanded(
                      flex: 3,
                      child: _buildEditor(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // 桌面狀態列
        _buildDesktopStatusBar(),
      ],
    );
  }
  
  // 桌面狀態列
  Widget _buildDesktopStatusBar() {
    // 復用手機版的狀態列邏輯，但為了程式碼清晰，獨立出一個方法
    // 在未來可以在這裡添加桌面版特有的資訊（如編碼格式、游標位置等）
    return _buildMobileStatusBar();
  }
  
  // 獲取 NavigationRail 的選中索引
  int _getNavigationIndex() {
    return slidePage > 8 ? 0 : slidePage.clamp(0, 8);
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
    int pageIndex = slidePage > 9 ? 0 : slidePage; // 如果在編輯器模式，預設顯示第一頁
    
    switch (pageIndex) {
      case 0:
        return _buildBaseInfoView();
      case 1:
        return _buildChapterSelectionView();
      case 2:
        return _buildOutlineView();
      case 3:
        return _buildWorldSettingsView();
      case 4:
        return _buildCharacterSettingsView();
      case 5:
        return _buildGlossaryView();
      case 6:
        return _buildProofreadingView();
      case 7:
        return _buildCopilotView();
      case 8:
        return _buildSettingView();
      case 9:
        return _buildAboutView();
      default:
        return Center(child: Text("Page ${pageIndex + 1}"));
    }
  }
  
  // 編輯器
  Widget _buildEditor() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: CustomScrollView(
        slivers: [
          // 搜尋列（當開啟時）
          if (showFindReplaceWindow)
            SliverToBoxAdapter(
              child: FindReplaceBar(
                findController: findController,
                replaceController: replaceController,
                options: findReplaceOptions,
                currentMatchIndex: _searchMatches.isNotEmpty ? _currentMatchIndex : null,
                totalMatches: _searchMatches.length,
                onFindNext: (findText, replaceText, options) {
                  _performFind(findText, options, forward: true);
                },
                onFindPrevious: (findText, replaceText, options) {
                  _performFind(findText, options, forward: false);
                },
                onReplace: (findText, replaceText, options) {
                  _performReplace(findText, replaceText, options);
                },
                onReplaceAll: (findText, replaceText, options) {
                  _performReplaceAll(findText, replaceText, options);
                },
                onSearchChanged: (findText, options) {
                  // 當搜尋內容或選項變化時，重新搜尋所有匹配項（但不移動光標）
                  if (findText.isNotEmpty) {
                    final text = textController.text;
                    if (text.isNotEmpty) {
                      setState(() {
                        _searchMatches = findAllMatches(text, findText, options);
                        // 如果當前選中的匹配項仍然有效，保持它
                        if (_currentMatchIndex >= _searchMatches.length) {
                          _currentMatchIndex = _searchMatches.isEmpty ? -1 : 0;
                        }
                        // 更新高亮顯示
                        textController.updateHighlights(
                          matches: _searchMatches,
                          currentIndex: _currentMatchIndex,
                        );
                      });
                    }
                  } else {
                    setState(() {
                      _searchMatches = [];
                      _currentMatchIndex = -1;
                      textController.clearHighlights();
                    });
                  }
                },
                onClose: () {
                  setState(() {
                    showFindReplaceWindow = false;
                    // 清除搜尋高亮，但保留編輯器的光標位置和選擇狀態
                    _searchMatches = [];
                    _currentMatchIndex = -1;
                    textController.clearHighlights();
                    // 不清除編輯器的選擇，讓用戶可以繼續從當前位置編輯
                  });
                },
              ),
            ),
          

          // 文本編輯器 - 使用 SliverFillRemaining 確保填滿剩餘空間
          SliverFillRemaining(
            hasScrollBody: false,
            child: Container(
              margin: const EdgeInsets.all(16),
              child: TextField(
                controller: textController,
                focusNode: editorFocusNode,
                maxLines: null,
                expands: true,
                decoration: InputDecoration(
                  hintText: "在此輸入您的故事內容...",
                  hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 各個頁面的建構方法（符合 Material Design）
  Widget _buildBaseInfoView() {
    return BaseInfoModule.BaseInfoView(
      data: baseInfoData,
      contentText: contentText,
      totalWords: totalWords,
      onDataChanged: (updatedData) {
        setState(() {
          baseInfoData = updatedData;
        });
        _markAsModified();
      },
    );
  }
  
  Widget _buildChapterSelectionView() {
    return ChapterModule.ChapterSelectionView(
      segments: segmentsData,
      contentText: contentText,
      selectedSegmentID: selectedSegID,
      selectedChapterID: selectedChapID,
      onSegmentsChanged: (updatedSegments) {
        // 先存：總是嘗試保存當前編輯器內容（如果有選中的章節）
        _syncEditorToSelectedChapter();
        
        // 然後更新 segmentsData
        setState(() {
          segmentsData = updatedSegments;
        });
        
        _markAsModified();
        
        // 再讀：這會透過 onContentChanged 自動發生
      },
      onContentChanged: (newContent) {
        // 這是「再讀」的部分：載入選中章節的內容到編輯器
        // 只在內容真的不同時才更新，避免不必要的重建
        if (contentText != newContent) {
          _isSyncing = true;
          setState(() {
            contentText = newContent;
            textController.text = contentText;
            // 重新計算字數
            totalWords = contentText.split(RegExp(r"\s+")).where((word) => word.isNotEmpty).length;
          });
          _isSyncing = false;
        }
      },
      onSelectedSegmentChanged: (segmentID) {
        // 先存：無論如何都先保存當前編輯器內容
        _syncEditorToSelectedChapter();
        
        setState(() {
          selectedSegID = segmentID;
        });
      },
      onSelectedChapterChanged: (chapterID) {
        // 先存：無論如何都先保存當前編輯器內容  
        _syncEditorToSelectedChapter();
        
        setState(() {
          selectedChapID = chapterID;
        });
      },
    );
  }
  
  Widget _buildOutlineView() {
    return OutlineModule.OutlineAdjustView(
      storylines: outlineData,
      onStorylineChanged: (updatedOutlines) {
        setState(() {
          outlineData = updatedOutlines;
        });
        _markAsModified();
      },
    );
  }
  
  Widget _buildWorldSettingsView() {
    return WorldSettingsView(
      locations: worldSettingsData,
      onChanged: (newLocations) {
        setState(() {
          worldSettingsData = newLocations;
        });
        _markAsModified();
      },
    );
  }
  
  Widget _buildCharacterSettingsView() {
    return CharacterView(
      initialData: characterData,
      onDataChanged: (updatedData) {
        setState(() {
          characterData = updatedData;
        });
        _markAsModified();
      },
    );
  }
  
  Widget _buildGlossaryView() {
    return _buildPlaceholderPage(
      icon: Icons.library_books,
      title: "詞語參考",
      description: "詞語參考功能開發中...",
      color: Colors.teal,
    );
  }
  
  
  Widget _buildProofreadingView() {
    return _buildPlaceholderPage(
      icon: Icons.spellcheck,
      title: "文本校正",
      description: "文本校正功能開發中...",
      color: Colors.red,
    );
  }
  
  Widget _buildCopilotView() {
    return _buildPlaceholderPage(
      icon: Icons.auto_awesome,
      title: "Copilot",
      description: "Copilot 功能開發中...",
      color: Colors.deepPurple,
    );
  }

  Widget _buildSettingView() {
    return SettingView(
      themeManager: widget.themeManager,
      settingsManager: widget.settingsManager,
    );
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
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                size: 64,
                color: color,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("$title 功能即將推出！"),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
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
      case "export_txt":
        _exportAs("txt");
        break;
      case "export_md":
        _exportAs("md");
        break;
    }
  }
  
  // 編輯器操作
  void _performEditorAction(String action) {
    // 這裡可以實作編輯器的 undo, redo, copy, paste 等功能
    // Flutter 的 TextField 已經內建了大部分功能
    switch (action) {
      case "undo":
        // 實作 undo 功能
        break;
      case "redo":
        // 實作 redo 功能
        break;
      case "selectAll":
        textController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: textController.text.length,
        );
        break;
      case "cut":
        if (textController.selection.isValid) {
          final selectedText = textController.selection.textInside(textController.text);
          Clipboard.setData(ClipboardData(text: selectedText));
          textController.text = textController.selection.textBefore(textController.text) +
              textController.selection.textAfter(textController.text);
        }
        break;
      case "copy":
        if (textController.selection.isValid) {
          final selectedText = textController.selection.textInside(textController.text);
          Clipboard.setData(ClipboardData(text: selectedText));
        }
        break;
      case "paste":
        Clipboard.getData("text/plain").then((value) {
          if (value?.text != null) {
            final text = textController.text;
            final selection = textController.selection;
            final newText = text.replaceRange(selection.start, selection.end, value!.text!);
            textController.text = newText;
            textController.selection = TextSelection.collapsed(
              offset: selection.start + value.text!.length,
            );
          }
        });
        break;
      case "find":
        // 實作搜尋功能
        break;
    }
  }
  
  // MARK: - 檔案操作

  // 變更追蹤和退出處理
  
  /// 標記內容已修改
  void _markAsModified() {
    setState(() => hasUnsavedChanges = ProjectManager.markAsModified());
  }
  
  /// 標記內容已儲存
  void _markAsSaved() {
    setState(() {
      hasUnsavedChanges = ProjectManager.markAsSaved();
      _lastSavedTime = DateTime.now();
    });
  }
  
  /// 檢查是否有未儲存的變更
  bool _hasUnsavedChanges() {
    _syncEditorToSelectedChapter();
    return ProjectManager.hasUnsavedChanges(hasUnsavedChanges, currentProject);
  }
  
  /// 處理退出請求
  Future<bool> _handleExit() async {
    return ProjectManager.handleExit(
      context,
      showExitWarning: widget.settingsManager.showExitWarning,
      hasUnsavedChanges: _hasUnsavedChanges(),
      onDontShowAgainChanged: (val) async => await widget.settingsManager.setShowExitWarning(!val),
      onSave: () async {
        await _saveProject();
        // Check if save successful (dirty flag cleared)
        if (_hasUnsavedChanges()) throw Exception("Save cancelled or failed");
      }
    );
  }
  
  // 檔案操作方法
  Future<void> _newProject() async {
    await ProjectManager.newProject(
      context,
      hasUnsavedChanges: _hasUnsavedChanges(),
      setLoading: (loading) => setState(() => isLoading = loading),
      onSuccess: _showMessage,
      onError: _showError,
      onProjectLoaded: (newProject, newData) {
        setState(() {
          currentProject = newProject;
          _applyProjectData(newData);
        });
        _markAsSaved();
        setState(() => _lastSavedTime = null);
      },
      onSave: _saveProject,
    );
  }
  
  Future<void> _openProject() async {
    await ProjectManager.openProject(
      context,
      hasUnsavedChanges: _hasUnsavedChanges(),
      setLoading: (loading) => setState(() => isLoading = loading),
      onSuccess: _showMessage,
      onError: _showError,
      onProjectLoaded: (projectFile, data) {
        setState(() {
          currentProject = projectFile;
          _applyProjectData(data);
        });
        _markAsSaved();
        setState(() => _lastSavedTime = null);
      },
      onSave: _saveProject,
    );
  }
  
  Future<void> _saveProject() async {
    _syncEditorToSelectedChapter();
    final currentData = _collectProjectData();
    
    await ProjectManager.saveProject(
      context,
      currentProject: currentProject,
      currentData: currentData,
      setLoading: (loading) => setState(() => isLoading = loading),
      onSuccess: _showMessage,
      onError: _showError,
      onProjectSaved: (savedProject) {
        setState(() => currentProject = savedProject);
        _markAsSaved();
      },
    );
  }
  
  Future<void> _saveProjectAs() async {
    _syncEditorToSelectedChapter();
    final currentData = _collectProjectData();
    
    await ProjectManager.saveProjectAs(
      context,
      currentProject: currentProject,
      currentData: currentData,
      setLoading: (loading) => setState(() => isLoading = loading),
      onSuccess: _showMessage,
      onError: _showError,
      onProjectSaved: (savedProject) {
        setState(() => currentProject = savedProject);
        _markAsSaved();
      },
    );
  }
  
  Future<void> _exportAs(String extension) async {
    _syncEditorToSelectedChapter();
    final currentData = _collectProjectData();
    final defaultName = currentProject?.nameWithoutExtension ?? "MonogatariExport";
    
    await ProjectManager.exportAs(
      context,
      extension: extension,
      currentData: currentData,
      defaultFileName: defaultName,
      setLoading: (loading) => setState(() => isLoading = loading),
      onSuccess: _showMessage,
      onError: _showError,
    );
  }
  
  // 同步編輯器內容到選中的章節（先存的部分）
  void _syncEditorToSelectedChapter() {
    if (_isSyncing) return;
    _isSyncing = true;
    ProjectManager.syncEditorToSelectedChapter(
      segmentsData: segmentsData,
      selectedSegID: selectedSegID,
      selectedChapID: selectedChapID,
      textController: textController,
      updateContentCallback: (newContent) {
        contentText = newContent;
        // 觸發 segmentsData 更新通知
        setState(() {}); 
      }
    );
    _isSyncing = false;
  }

  // 輔助方法：收集當前專案數據
  ProjectData _collectProjectData() {
    return ProjectData(
      baseInfoData: baseInfoData,
      segmentsData: segmentsData,
      outlineData: outlineData,
      worldSettingsData: worldSettingsData,
      characterData: characterData,
      totalWords: totalWords,
      contentText: contentText,
    );
  }
  
  // 輔助方法：應用專案數據到狀態
  void _applyProjectData(ProjectData data) {
    baseInfoData = data.baseInfoData;
    segmentsData = data.segmentsData;
    outlineData = data.outlineData;
    worldSettingsData = data.worldSettingsData;
    characterData = data.characterData;
    
    // 設定初始選擇
    if (segmentsData.isNotEmpty && segmentsData[0].chapters.isNotEmpty) {
      selectedSegID = segmentsData[0].segmentUUID;
      selectedChapID = segmentsData[0].chapters[0].chapterUUID;
      contentText = segmentsData[0].chapters[0].chapterContent;
      _isSyncing = true;
      textController.text = contentText;
      _isSyncing = false;
      totalWords = data.totalWords;
    } else {
      selectedSegID = null;
      selectedChapID = null;
      contentText = "";
      _isSyncing = true;
      textController.text = "";
      _isSyncing = false;
      totalWords = 0;
    }
  }
  
  // 訊息處理
  void _showError(String message) {
    setState(() {
      errorMessage = message;
      showingError = true;
    });
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("錯誤"),
        content: Text(errorMessage),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => showingError = false);
            },
            child: const Text("確定"),
          ),
        ],
      ),
    );
  }
  
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class _ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const _ScrollingText({
    required this.text,
    this.style,
  });

  @override
  State<_ScrollingText> createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<_ScrollingText> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  bool _shouldScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10), // Adjust speed here
    );
    
    // Check if scrolling is needed after layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScroll();
    });
  }

  @override
  void didUpdateWidget(_ScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _animationController.reset();
      _shouldScroll = false;
      // Re-check scrolling
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkScroll();
      });
    }
  }

  void _checkScroll() {
    if (!mounted) return;
    
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 0 && !_shouldScroll) {
        setState(() {
          _shouldScroll = true;
        });
        _startScrolling();
      } else if (maxScroll <= 0 && _shouldScroll) {
        _animationController.stop();
        setState(() {
          _shouldScroll = false;
        });
      }
    }
  }

  void _startScrolling() {
    if (!mounted || !_shouldScroll) return;
    
    // Simple scrolling animation
    // Scroll to end
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: Duration(milliseconds: (widget.text.length * 200).clamp(2000, 30000)),
      curve: Curves.linear,
    ).then((_) async {
      if (!mounted) return;
      // Wait a bit
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      // Scroll back
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOut,
      ).then((_) async {
        if (!mounted) return;
        // Wait a bit
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        // Loop
        _startScrolling();
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // MARK: - Build

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate text width to see if it overflows
        final textSpan = TextSpan(text: widget.text, style: widget.style);
        final textPainter = TextPainter(
          text: textSpan,
          maxLines: 1,
          textDirection: ui.TextDirection.ltr,
        )..layout();

        // If it fits, just return Text
        if (textPainter.size.width <= constraints.maxWidth) {
           return Text(
            widget.text,
            style: widget.style,
            overflow: TextOverflow.visible,
          );
        }

        // Otherwise use ListView for scrolling
        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(), // Disable user scrolling
          child: Text(
            widget.text,
            style: widget.style,
          ),
        );
      },
    );
  }
}