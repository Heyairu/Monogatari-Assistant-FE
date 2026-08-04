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

//  Ported from the original SwiftUI ChapterSelection page.
//  Created by 部屋いる on 2025/10/1.
//  Refactored on 2025/10/2 based on Swift implementation
//  Updated on 2025/10/3 - Unified drag & drop behavior:
//    - Within List: Use default ReorderableListView drag to reorder
//    - Outside List: Long press drag to move chapter to another segment
//  Updated on 2025/10/3 - Auto scroll when dragging:
//    - Auto scroll page when dragging near top/bottom edges
//    - Auto scroll list when dragging near list top/bottom edges
//

import "package:flutter/material.dart";
import "dart:async";
import "package:xml/xml.dart" as xml;
import "../models/codecs/xml_text_codec.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../bin/ui_library.dart";
import "../bin/settings_manager.dart";
import "../models/chapter_selection_data.dart";
import "../presentation/providers/global_state_providers.dart";
import "../presentation/providers/project_state_providers.dart";

export "../models/chapter_selection_data.dart";

// MARK: - 拖放數據類型

class DragData {
  final String id;
  final DragType type;
  final int currentIndex;

  DragData({required this.id, required this.type, required this.currentIndex});
}

enum DragType { segment, chapter }

enum _CreateType { chapter, childFolder, rootFolder }

// MARK: - XML Codec

class ChapterSelectionCodec {
  static const String _schemaVersionAttribute = "ChapterTreeVersion";

  static List<SegmentData> _createSnapshot(List<SegmentData> source) {
    return ChapterTreeSchema.upgrade(
      sourceVersion: ChapterTreeSchema.currentVersion,
      segments: source,
    );
  }

  static void _writeTextElement(
    xml.XmlBuilder builder,
    String name,
    String value,
  ) {
    XmlTextCodec.writeTextElement(builder, name, value);
  }

  static String _readElementText(xml.XmlElement? element) {
    return XmlTextCodec.readElementText(element);
  }

  /// 序列化成與 Qt SaveFile() 兼容的 `<Type>` 片段
  static String? saveXML(List<SegmentData> segments) {
    final snapshot = _createSnapshot(segments);
    if (snapshot.isEmpty || ChapterTree.chapterCount(snapshot) == 0) {
      return null;
    }

    void writeFolder(xml.XmlBuilder builder, SegmentData folder) {
      builder.element(
        "Segment",
        attributes: {"Name": folder.segmentName, "UUID": folder.segmentUUID},
        nest: () {
          final childrenByID = {
            for (final child in folder.childSegments) child.segmentUUID: child,
          };
          final chaptersByID = {
            for (final chapter in folder.chapters) chapter.chapterUUID: chapter,
          };
          for (final id in folder.resolvedChildNodeOrder) {
            final child = childrenByID[id];
            if (child != null) {
              writeFolder(builder, child);
              continue;
            }
            final chapter = chaptersByID[id];
            if (chapter != null) {
              builder.element(
                "Chapter",
                attributes: {
                  "Name": chapter.chapterName,
                  "UUID": chapter.chapterUUID,
                },
                nest: () {
                  _writeTextElement(builder, "Content", chapter.chapterContent);
                },
              );
            }
          }
        },
      );
    }

    // 使用 xml package 構建 XML，自動處理 escaping
    final builder = xml.XmlBuilder();
    builder.element(
      "Type",
      nest: () {
        builder.attribute(
          _schemaVersionAttribute,
          ChapterTreeSchema.currentVersion.toString(),
        );
        builder.element("Name", nest: () => builder.text("ChapterSelection"));

        for (final folder in snapshot) {
          writeFolder(builder, folder);
        }
      },
    );

    return builder.buildDocument().toXmlString(pretty: true);
  }

  /// 自 `<Type>` 區塊解析（需 `<Name>ChapterSelection</Name>`）
  static List<SegmentData>? loadXML(String xmlContent) {
    try {
      final document = xml.XmlDocument.parse(xmlContent);
      final typeElement = document.findAllElements("Type").firstOrNull;
      return typeElement == null ? null : loadElement(typeElement);
    } catch (e) {
      debugPrint("ChapterSelection XML Parse Error: $e");
      return null;
    }
  }

  // 自已解析的 Type 區塊載入，避免專案載入時重複序列化與解析。
  static List<SegmentData>? loadElement(xml.XmlElement typeElement) {
    try {
      final nameElement = typeElement.findAllElements("Name").firstOrNull;
      if (nameElement == null || nameElement.innerText != "ChapterSelection") {
        return null;
      }

      final segments = <SegmentData>[];
      final sourceSchemaVersion =
          int.tryParse(
            typeElement.getAttribute(_schemaVersionAttribute) ?? "",
          ) ??
          0;
      SegmentData readFolder(xml.XmlElement segElement) {
        final segmentName = segElement.getAttribute("Name") ?? "";
        final segmentUUID = segElement.getAttribute("UUID") ?? "";

        final chapters = <ChapterData>[];
        final childSegments = <SegmentData>[];
        final childNodeOrder = <String>[];

        for (final childElement
            in segElement.children.whereType<xml.XmlElement>()) {
          if (childElement.name.local == "Segment") {
            final childFolder = readFolder(childElement);
            childSegments.add(childFolder);
            childNodeOrder.add(childFolder.segmentUUID);
            continue;
          }
          if (childElement.name.local != "Chapter") continue;
          final chElement = childElement;
          final chapterName = chElement.getAttribute("Name") ?? "";
          final chapterUUID = chElement.getAttribute("UUID") ?? "";

          final contentElement = chElement
              .findAllElements("Content")
              .firstOrNull;
          final chapterContent = _readElementText(contentElement);

          final chapter = ChapterData(
            chapterName: chapterName,
            chapterContent: chapterContent,
            chapterUUID: chapterUUID,
          );
          chapters.add(chapter);
          childNodeOrder.add(chapter.chapterUUID);
        }

        return SegmentData(
          segmentName: segmentName,
          chapters: chapters,
          childSegments: childSegments,
          childNodeOrder: sourceSchemaVersion >= 3
              ? childNodeOrder
              : const <String>[],
          segmentUUID: segmentUUID,
        );
      }

      segments.addAll(typeElement.findElements("Segment").map(readFolder));

      return segments.isNotEmpty
          ? ChapterTreeSchema.upgrade(
              sourceVersion: sourceSchemaVersion,
              segments: segments,
            )
          : null;
    } catch (e) {
      debugPrint("ChapterSelection XML Element Parse Error: $e");
      return null;
    }
  }
}

// MARK: - View

class ChapterSelectionView extends ConsumerStatefulWidget {
  const ChapterSelectionView({super.key});

  @override
  ConsumerState<ChapterSelectionView> createState() =>
      _ChapterSelectionViewState();
}

class _SelectionSnapshot {
  final String? segmentID;
  final String? chapterID;
  final SegmentData? folder;

  const _SelectionSnapshot({
    required this.segmentID,
    required this.chapterID,
    required this.folder,
  });
}

class _ChapterTreeRow {
  final SegmentData folder;
  final int depth;
  final int? chapterIndex;

  const _ChapterTreeRow.folder(this.folder, this.depth) : chapterIndex = null;

  const _ChapterTreeRow.chapter(this.folder, this.depth, int this.chapterIndex);

  bool get isFolder => chapterIndex == null;
}

class _ChapterSelectionViewState extends ConsumerState<ChapterSelectionView> {
  List<SegmentData> get _segments => ref.read(segmentsDataProvider);
  SegmentsDataNotifier get _segmentsNotifier =>
      ref.read(segmentsDataProvider.notifier);

  bool _hasPerformedInitialSetup = false;

  // 編輯名稱（雙擊）狀態
  String? _editingSegmentID;
  String? _editingChapterID;

  // 滾動控制器
  final ScrollController _pageScrollController = ScrollController();
  final ScrollController _treeScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // 列表容器的 GlobalKey，用於獲取邊界
  final GlobalKey _treeListKey = GlobalKey();
  final Set<String> _expandedSegmentIDs = <String>{};
  final Set<String> _knownSegmentIDs = <String>{};
  String? _selectedFolderID;
  String _searchQuery = "";
  _CreateType _createType = _CreateType.chapter;

  // 自動滾動相關
  Timer? _autoScrollTimer;
  ScrollController? _currentScrollController; // 新增：追蹤當前正在滾動的控制器
  double? _pendingTreeScrollOffset;
  double? _pendingPageScrollOffset;
  bool _isDragging = false; // 新增：追蹤拖動狀態
  DragData? _currentDragData; // 新增：追蹤當前拖動的數據
  TextEditingController? _renameController; // 新增：重新命名控制器

  static const double _autoScrollSpeed = 10.0; // 每次滾動的像素數
  static const Duration _autoScrollInterval = Duration(
    milliseconds: 50,
  ); // 滾動間隔
  static const double _scrollEdgeThreshold = 100.0; // 頁面邊緣觸發閾值（從頂部/底部算起）
  static const double _listScrollEdgeThreshold = 20.0; // 列表邊緣觸發閾值（修改為 20px）

  // MARK: - 計算屬性

  int get _totalChaptersCount {
    return ChapterTree.chapterCount(_segments);
  }

  String get _contentText => ref.read(editorContentProvider);

  _SelectionSnapshot _selectionSnapshotFromValues({
    required List<SegmentData> segments,
    required String? segmentID,
    required String? chapterID,
  }) {
    if (segmentID == null) {
      return _SelectionSnapshot(
        segmentID: segmentID,
        chapterID: chapterID,
        folder: null,
      );
    }

    return _SelectionSnapshot(
      segmentID: segmentID,
      chapterID: chapterID,
      folder: ChapterTree.findFolder(segments, segmentID),
    );
  }

  _SelectionSnapshot _readSelectionSnapshot([List<SegmentData>? segments]) {
    final selectionState = ref.read(editorSelectionProvider);
    return _selectionSnapshotFromValues(
      segments: segments ?? _segments,
      segmentID: selectionState.selectedSegID,
      chapterID: selectionState.selectedChapID,
    );
  }

  // MARK: - 生命週期方法

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _renameController?.dispose();
    _pageScrollController.dispose();
    _treeScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // MARK: - 自動滾動方法

  /// 處理拖動時的自動滾動（頁面級別）
  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isDragging) {
      bool handledByList = false;
      final treeBox =
          _treeListKey.currentContext?.findRenderObject() as RenderBox?;
      if (treeBox != null) {
        final treePosition = treeBox.localToGlobal(Offset.zero);
        final relativeY = details.globalPosition.dy - treePosition.dy;
        if (relativeY >= 0 && relativeY <= treeBox.size.height) {
          if (relativeY < _listScrollEdgeThreshold) {
            _startAutoScroll(_treeScrollController, scrollUp: true);
            handledByList = true;
          } else if (relativeY >
              treeBox.size.height - _listScrollEdgeThreshold) {
            _startAutoScroll(_treeScrollController, scrollUp: false);
            handledByList = true;
          }
        }
      }

      // 如果列表處理了滾動，就不處理頁面滾動
      if (handledByList) {
        return;
      }

      // 如果不在列表邊緣，停止列表滾動
      if (_currentScrollController == _treeScrollController) {
        _stopAutoScroll();
      }
    }

    // 頁面級別滾動（作為後備）
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPosition = details.localPosition;
    final screenHeight = MediaQuery.of(context).size.height;

    if (localPosition.dy < _scrollEdgeThreshold) {
      _startAutoScroll(_pageScrollController, scrollUp: true);
    } else if (localPosition.dy > screenHeight - _scrollEdgeThreshold) {
      _startAutoScroll(_pageScrollController, scrollUp: false);
    } else {
      if (_currentScrollController != _treeScrollController) {
        _stopAutoScroll();
      }
    }
  }

  /// 開始自動滾動
  void _startAutoScroll(ScrollController controller, {required bool scrollUp}) {
    // 如果已經在滾動同一個控制器和方向，不需要重新啟動
    if (_currentScrollController == controller && _autoScrollTimer != null) {
      return;
    }

    // 停止之前的滾動
    _autoScrollTimer?.cancel();
    _currentScrollController = controller;

    _autoScrollTimer = Timer.periodic(_autoScrollInterval, (timer) {
      if (!controller.hasClients) {
        timer.cancel();
        _currentScrollController = null;
        return;
      }

      final currentOffset = controller.offset;
      final maxScroll = controller.position.maxScrollExtent;
      final minScroll = controller.position.minScrollExtent;

      if (scrollUp) {
        // 向上滾動
        if (currentOffset > minScroll) {
          final newOffset = (currentOffset - _autoScrollSpeed).clamp(
            minScroll,
            maxScroll,
          );
          controller.jumpTo(newOffset);
          _rememberDragScrollOffset(controller, newOffset);
        } else {
          timer.cancel();
          _currentScrollController = null;
        }
      } else {
        // 向下滾動
        if (currentOffset < maxScroll) {
          final newOffset = (currentOffset + _autoScrollSpeed).clamp(
            minScroll,
            maxScroll,
          );
          controller.jumpTo(newOffset);
          _rememberDragScrollOffset(controller, newOffset);
        } else {
          timer.cancel();
          _currentScrollController = null;
        }
      }
    });
  }

  /// 停止自動滾動
  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _currentScrollController = null;
  }

  void _beginDrag(DragData data) {
    _pendingTreeScrollOffset = _treeScrollController.hasClients
        ? _treeScrollController.offset
        : null;
    _pendingPageScrollOffset = _pageScrollController.hasClients
        ? _pageScrollController.offset
        : null;
    setState(() {
      _isDragging = true;
      _currentDragData = data;
    });
  }

  void _finishDrag() {
    if (_isDragging || _currentDragData != null) {
      setState(() {
        _isDragging = false;
        _currentDragData = null;
      });
    }
    _stopAutoScroll();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _restoreScrollOffset(_treeScrollController, _pendingTreeScrollOffset);
      _restoreScrollOffset(_pageScrollController, _pendingPageScrollOffset);
      _pendingTreeScrollOffset = null;
      _pendingPageScrollOffset = null;
    });
  }

  void _rememberDragScrollOffset(ScrollController controller, double offset) {
    if (controller == _treeScrollController) {
      _pendingTreeScrollOffset = offset;
    } else if (controller == _pageScrollController) {
      _pendingPageScrollOffset = offset;
    }
  }

  void _restoreScrollOffset(
    ScrollController controller,
    double? requestedOffset,
  ) {
    if (requestedOffset == null || !controller.hasClients) return;
    final position = controller.position;
    final target = requestedOffset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((controller.offset - target).abs() > 0.5) controller.jumpTo(target);
  }

  // MARK: - Helper 方法

  void _appendChapterToSegment(String segmentID, ChapterData chapter) {
    _segmentsNotifier.addChapter(segmentID: segmentID, chapter: chapter);
  }

  void _appendSegment(SegmentData segment) {
    _segmentsNotifier.addSegment(segment);
  }

  void _removeChapterFromSegment(SegmentData segment, String chapterID) {
    _segmentsNotifier.removeChapter(
      segmentID: segment.segmentUUID,
      chapterID: chapterID,
    );
  }

  void _initializeIfEmpty() {
    if (_segments.isEmpty) {
      _appendSegment(
        SegmentData(
          segmentName: "Folder 1",
          chapters: [ChapterData(chapterName: "Chapter 1", chapterContent: "")],
        ),
      );
    } else if (_totalChaptersCount == 0) {
      final firstFolder = ChapterTree.foldersDepthFirst(_segments).first;
      _appendChapterToSegment(
        firstFolder.segmentUUID,
        ChapterData(chapterName: "Untitled", chapterContent: ""),
      );
    }
  }

  List<_ChapterTreeRow> _buildVisibleTreeRows(List<SegmentData> segments) {
    final rows = <_ChapterTreeRow>[];
    final query = _searchQuery.trim().toLowerCase();

    bool subtreeMatches(SegmentData folder) {
      if (query.isEmpty || folder.segmentName.toLowerCase().contains(query)) {
        return true;
      }
      if (folder.chapters.any(
        (chapter) => chapter.chapterName.toLowerCase().contains(query),
      )) {
        return true;
      }
      return folder.childSegments.any(subtreeMatches);
    }

    void flatten(
      SegmentData folder,
      int depth, {
      bool ancestorMatched = false,
    }) {
      final folderMatches =
          query.isNotEmpty && folder.segmentName.toLowerCase().contains(query);
      if (query.isNotEmpty && !ancestorMatched && !subtreeMatches(folder)) {
        return;
      }

      rows.add(_ChapterTreeRow.folder(folder, depth));
      final showChildren =
          query.isNotEmpty || _expandedSegmentIDs.contains(folder.segmentUUID);
      if (!showChildren) return;

      final includeSubtree = ancestorMatched || folderMatches;
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
          final chapter = folder.chapters[chapterIndex];
          if (query.isEmpty ||
              includeSubtree ||
              chapter.chapterName.toLowerCase().contains(query)) {
            rows.add(_ChapterTreeRow.chapter(folder, depth + 1, chapterIndex));
          }
          continue;
        }
        final child = childrenByID[id];
        if (child != null) {
          flatten(child, depth + 1, ancestorMatched: includeSubtree);
        }
      }
    }

    for (final root in segments) {
      flatten(root, 0);
    }
    return rows;
  }

  void _synchronizeTreeExpansion(List<SegmentData> segments) {
    final currentIDs = ChapterTree.foldersDepthFirst(
      segments,
    ).map((segment) => segment.segmentUUID).toSet();
    _expandedSegmentIDs.removeWhere((id) => !currentIDs.contains(id));
    _expandedSegmentIDs.addAll(currentIDs.difference(_knownSegmentIDs));
    _knownSegmentIDs
      ..clear()
      ..addAll(currentIDs);
  }

  // MARK: - Helper：保存/選取

  void _commitCurrentEditorToSelectedChapter(_SelectionSnapshot selection) {
    final folder = selection.folder;
    final cid = selection.chapterID;
    if (folder != null && cid != null) {
      _segmentsNotifier.updateChapterContent(
        segmentID: folder.segmentUUID,
        chapterID: cid,
        content: _contentText,
      );
    }
  }

  void _setSelection({String? segmentID, String? chapterID}) {
    ref
        .read(editorSelectionProvider.notifier)
        .setSelection(selectedSegID: segmentID, selectedChapID: chapterID);
  }

  void _setEditorContent(String value) {
    ref.read(editorContentProvider.notifier).setContent(value);
  }

  void _applySegmentSelection(
    String segID, {
    required String? previousChapterID,
  }) {
    final folder = ChapterTree.findFolder(_segments, segID);
    if (folder == null) return;
    final firstChapter = ChapterTree.firstChapter([folder]);
    if (firstChapter == null) {
      _setSelection(segmentID: segID, chapterID: null);
      _setEditorContent("");
      return;
    }
    _setSelection(
      segmentID: firstChapter.folder.segmentUUID,
      chapterID: firstChapter.chapter.chapterUUID,
    );
    _setEditorContent(firstChapter.chapter.chapterContent);
  }

  void _applyChapterSelection(String folderID, String chapterID) {
    final location = ChapterTree.findChapter(
      _segments,
      folderId: folderID,
      chapterId: chapterID,
    );
    if (location == null) return;
    _setSelection(segmentID: folderID, chapterID: chapterID);
    _setEditorContent(location.chapter.chapterContent);
  }

  void _selectSegment(String segID, _SelectionSnapshot selection) {
    _commitCurrentEditorToSelectedChapter(selection);
    setState(() {
      _selectedFolderID = segID;
      _expandedSegmentIDs.add(segID);
    });
    _applySegmentSelection(segID, previousChapterID: selection.chapterID);
  }

  void _selectChapter(
    String folderID,
    String chapterID,
    _SelectionSnapshot selection,
  ) {
    _commitCurrentEditorToSelectedChapter(selection);
    setState(() {
      _selectedFolderID = folderID;
    });
    _applyChapterSelection(folderID, chapterID);
  }

  void _notifySegmentsChanged() {
    // Dirty tracking is driven by provider listeners in coordinator.
  }

  // MARK: - 新增方法

  void _addSegment(
    String name,
    _SelectionSnapshot selection, {
    String? parentFolderID,
  }) {
    _commitCurrentEditorToSelectedChapter(selection);

    name = name.trim();
    final folderCount = ChapterTree.foldersDepthFirst(_segments).length;
    final finalName = name.isEmpty ? "資料夾 ${folderCount + 1}" : name;
    final newSegment = _segmentsNotifier.addFolder(
      name: finalName,
      parentFolderID: parentFolderID,
    );
    if (newSegment == null) return;

    setState(() {
      _expandedSegmentIDs.add(newSegment.segmentUUID);
      if (parentFolderID != null) _expandedSegmentIDs.add(parentFolderID);
      _selectedFolderID = newSegment.segmentUUID;
    });
    _notifySegmentsChanged();

    _applySegmentSelection(
      newSegment.segmentUUID,
      previousChapterID: selection.chapterID,
    );
  }

  void _addChapter(String folderID, String name, _SelectionSnapshot selection) {
    _commitCurrentEditorToSelectedChapter(selection);

    final folder = ChapterTree.findFolder(_segments, folderID);
    if (folder == null) return;
    name = name.trim();
    final finalName = name.isEmpty
        ? "Chapter ${folder.chapters.length + 1}"
        : name;
    final newChapter = ChapterData(chapterName: finalName, chapterContent: "");

    _appendChapterToSegment(folderID, newChapter);
    setState(() {
      _expandedSegmentIDs.add(folderID);
      _selectedFolderID = folderID;
    });
    _notifySegmentsChanged();

    _applyChapterSelection(folderID, newChapter.chapterUUID);
  }

  // MARK: - 刪除方法

  void _selectFirstAvailableChapter() {
    final location = ChapterTree.firstChapter(_segments);
    if (location == null) {
      _setSelection(segmentID: null, chapterID: null);
      _setEditorContent("");
      return;
    }
    _setSelection(
      segmentID: location.folder.segmentUUID,
      chapterID: location.chapter.chapterUUID,
    );
    _setEditorContent(location.chapter.chapterContent);
    setState(() {
      _selectedFolderID = location.folder.segmentUUID;
      _expandedSegmentIDs.add(location.folder.segmentUUID);
    });
  }

  void _deleteSegment(String segmentID, _SelectionSnapshot selection) {
    final folder = ChapterTree.findFolder(_segments, segmentID);
    if (folder == null) return;
    final remainingChapters =
        _totalChaptersCount - ChapterTree.chapterCount([folder]);
    if (remainingChapters <= 0) return;

    final deletesSelection =
        selection.folder != null &&
        ChapterTree.containsFolder(folder, selection.folder!.segmentUUID);
    if (deletesSelection) {
      _commitCurrentEditorToSelectedChapter(selection);
    }

    if (!_segmentsNotifier.removeSegmentById(segmentID)) return;
    setState(() {
      _expandedSegmentIDs.remove(segmentID);
      if (_selectedFolderID != null &&
          ChapterTree.containsFolder(folder, _selectedFolderID!)) {
        _selectedFolderID = null;
      }
    });
    _notifySegmentsChanged();

    if (deletesSelection) _selectFirstAvailableChapter();
  }

  void _deleteChapter(
    SegmentData folder,
    String chapterID,
    _SelectionSnapshot selection,
  ) {
    if (_totalChaptersCount <= 1 ||
        !folder.chapters.any((chapter) => chapter.chapterUUID == chapterID)) {
      return;
    }

    final wasSelected = selection.chapterID == chapterID;
    if (selection.chapterID == chapterID) {
      _commitCurrentEditorToSelectedChapter(selection);
    }

    final sourceSegmentID = folder.segmentUUID;
    _removeChapterFromSegment(folder, chapterID);
    final sourceFolderStillExists =
        ChapterTree.findFolder(_segments, sourceSegmentID) != null;
    if (!sourceFolderStillExists) {
      setState(() {
        _expandedSegmentIDs.remove(sourceSegmentID);
      });
    }
    if (wasSelected) {
      _selectFirstAvailableChapter();
    }

    _notifySegmentsChanged();
  }

  // MARK: - 移動/拖放方法

  void _moveFolderByDrag(
    String sourceFolderID,
    String targetFolderID,
    DropPosition position,
    _SelectionSnapshot selection,
  ) {
    _commitCurrentEditorToSelectedChapter(selection);
    final moved = _segmentsNotifier.moveFolder(
      sourceFolderID: sourceFolderID,
      targetFolderID: targetFolderID,
      position: switch (position) {
        DropPosition.before => "before",
        DropPosition.child => "child",
        DropPosition.after => "after",
      },
    );
    if (moved && position == DropPosition.child) {
      setState(() => _expandedSegmentIDs.add(targetFolderID));
    }
    _notifySegmentsChanged();
  }

  String _dropPositionName(DropPosition position) => switch (position) {
    DropPosition.before => "before",
    DropPosition.child => "child",
    DropPosition.after => "after",
  };

  void _moveFolderRelativeToChapter(
    String folderID,
    String chapterID,
    DropPosition position,
    _SelectionSnapshot selection,
  ) {
    if (position == DropPosition.child) return;
    _commitCurrentEditorToSelectedChapter(selection);
    _segmentsNotifier.moveFolderRelativeToChapter(
      sourceFolderID: folderID,
      targetChapterID: chapterID,
      position: _dropPositionName(position),
    );
    _notifySegmentsChanged();
  }

  void _moveChapterRelativeToChapter(
    String chapterID,
    String targetChapterID,
    DropPosition position,
    _SelectionSnapshot selection,
  ) {
    if (position == DropPosition.child) return;
    _commitCurrentEditorToSelectedChapter(selection);
    final moved = _segmentsNotifier.moveChapterRelativeToChapter(
      chapterID: chapterID,
      targetChapterID: targetChapterID,
      position: _dropPositionName(position),
    );
    if (moved) _syncSelectionAfterChapterMove(chapterID);
    _notifySegmentsChanged();
  }

  void _moveChapterRelativeToFolder(
    String chapterID,
    String targetFolderID,
    DropPosition position,
    _SelectionSnapshot selection,
  ) {
    if (position == DropPosition.child) return;
    _commitCurrentEditorToSelectedChapter(selection);
    final moved = _segmentsNotifier.moveChapterRelativeToFolder(
      chapterID: chapterID,
      targetFolderID: targetFolderID,
      position: _dropPositionName(position),
    );
    if (moved) _syncSelectionAfterChapterMove(chapterID);
    _notifySegmentsChanged();
  }

  void _syncSelectionAfterChapterMove(String chapterID) {
    final location = ChapterTree.findChapter(_segments, chapterId: chapterID);
    if (location == null) return;
    setState(() {
      _expandedSegmentIDs.add(location.folder.segmentUUID);
      _selectedFolderID = location.folder.segmentUUID;
    });
    _setSelection(
      segmentID: location.folder.segmentUUID,
      chapterID: location.chapter.chapterUUID,
    );
    _setEditorContent(location.chapter.chapterContent);
  }

  void _moveChapterToSegment(
    String chapterUUID,
    String toSegmentUUID,
    _SelectionSnapshot selection, {
    int? targetChapterIndex,
  }) {
    _commitCurrentEditorToSelectedChapter(selection);

    final source = ChapterTree.findChapter(_segments, chapterId: chapterUUID);
    final target = ChapterTree.findFolder(_segments, toSegmentUUID);
    if (source == null ||
        target == null ||
        source.folder.segmentUUID == toSegmentUUID) {
      return;
    }
    final sourceSegID = source.folder.segmentUUID;
    final movingChapter = source.chapter;

    // 執行移動
    _segmentsNotifier.moveChapterToSegment(
      chapterID: chapterUUID,
      targetSegmentID: toSegmentUUID,
    );

    if (targetChapterIndex != null) {
      final movedTarget = ChapterTree.findFolder(_segments, toSegmentUUID);
      if (movedTarget != null) {
        final targetChapters = movedTarget.chapters;
        final movedChapterIndex = targetChapters.indexWhere(
          (chapter) => chapter.chapterUUID == chapterUUID,
        );
        final normalizedTarget = targetChapterIndex.clamp(
          0,
          targetChapters.length - 1,
        );
        if (movedChapterIndex >= 0 && movedChapterIndex != normalizedTarget) {
          _segmentsNotifier.moveChapterWithinSegment(
            segmentID: toSegmentUUID,
            fromIndex: movedChapterIndex,
            toIndex: normalizedTarget,
          );
        }
      }
    }

    setState(() {
      _expandedSegmentIDs.add(toSegmentUUID);
      if (ChapterTree.findFolder(_segments, sourceSegID) == null) {
        _expandedSegmentIDs.remove(sourceSegID);
      }
      _selectedFolderID = toSegmentUUID;
    });

    // 更新選擇
    _setSelection(
      segmentID: toSegmentUUID,
      chapterID: movingChapter.chapterUUID,
    );
    _setEditorContent(movingChapter.chapterContent);

    _notifySegmentsChanged();
  }

  // MARK: - UI 介面構建

  @override
  Widget build(BuildContext context) {
    final wordCountMode = ref.watch(
      settingsStateProvider.select(
        (settingsState) =>
            settingsState.valueOrNull?.wordCountMode ??
            WordCountMode.wordsAndCharacters,
      ),
    );
    final totalWordCount = ref.watch(totalWordsProvider);
    final selectedSegmentID = ref.watch(
      editorSelectionProvider.select(
        (selectionState) => selectionState.selectedSegID,
      ),
    );
    final selectedChapterID = ref.watch(
      editorSelectionProvider.select(
        (selectionState) => selectionState.selectedChapID,
      ),
    );
    final segments = ref.watch(
      segmentsDataProvider.select((segmentsState) => segmentsState),
    );
    final selectionSnapshot = _selectionSnapshotFromValues(
      segments: segments,
      segmentID: selectedSegmentID,
      chapterID: selectedChapterID,
    );

    // 初始化檢查（類似 SwiftUI 的 onAppear），但只執行一次
    if (!_hasPerformedInitialSetup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performInitialSetup();
        _hasPerformedInitialSetup = true;
      });
    }

    return Scaffold(
      body: Listener(
        onPointerMove: (event) {
          // 全局監聽拖動來處理頁面級別的自動滾動
          _handleDragUpdate(
            DragUpdateDetails(
              globalPosition: event.position,
              localPosition: event.localPosition,
            ),
          );
        },
        onPointerUp: (_) => _stopAutoScroll(),
        onPointerCancel: (_) => _stopAutoScroll(),
        child: SingleChildScrollView(
          controller: _pageScrollController,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 標題
              Row(
                children: [
                  LargeTitle(icon: Icons.menu_book, text: "章節選擇"),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.onetwothree,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "全書共 $totalWordCount 字",
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              _buildChapterTree(segments, wordCountMode, selectionSnapshot),
            ],
          ),
        ),
      ),
    );
  }

  // MARK: - 初始化邏輯（類似 SwiftUI 的 onAppear）

  void _performInitialSetup() {
    final beforeSegmentsCount = _segments.length;
    final beforeChaptersCount = _totalChaptersCount;

    _initializeIfEmpty();
    _expandedSegmentIDs.addAll(
      ChapterTree.foldersDepthFirst(
        _segments,
      ).map((folder) => folder.segmentUUID),
    );

    final selection = _readSelectionSnapshot(_segments);
    final selectedLocation = selection.chapterID == null
        ? null
        : ChapterTree.findChapter(
            _segments,
            folderId: selection.segmentID,
            chapterId: selection.chapterID!,
          );
    final location = selectedLocation ?? ChapterTree.firstChapter(_segments);
    if (location != null) {
      _setSelection(
        segmentID: location.folder.segmentUUID,
        chapterID: location.chapter.chapterUUID,
      );
      _setEditorContent(location.chapter.chapterContent);
      _selectedFolderID = location.folder.segmentUUID;
    }

    final hasInitializedDefaultData =
        beforeSegmentsCount != _segments.length ||
        beforeChaptersCount != _totalChaptersCount;
    if (hasInitializedDefaultData) {
      _notifySegmentsChanged();
    }
  }

  Widget _buildCreateTypeButton({
    required _CreateType type,
    required IconData icon,
    required String tooltip,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = _createType == type;
    return IconButton(
      key: ValueKey("chapter-create-type-${type.name}"),
      tooltip: tooltip,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      visualDensity: VisualDensity.compact,
      onPressed: () => setState(() => _createType = type),
      style: IconButton.styleFrom(
        foregroundColor: isSelected ? Colors.blue : scheme.onSurfaceVariant,
      ),
      icon: Icon(icon),
    );
  }

  Widget _buildChapterTree(
    List<SegmentData> segments,
    WordCountMode wordCountMode,
    _SelectionSnapshot selection,
  ) {
    _synchronizeTreeExpansion(segments);
    if (_selectedFolderID == null ||
        ChapterTree.findFolder(segments, _selectedFolderID!) == null) {
      _selectedFolderID = selection.folder?.segmentUUID;
    }
    final rows = _buildVisibleTreeRows(segments);
    final selectedFolder = _selectedFolderID == null
        ? selection.folder
        : ChapterTree.findFolder(segments, _selectedFolderID!);
    final canAddToSelectedFolder = selectedFolder != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "資料夾與章節位於同一清單；移除資料夾會一併移除其中章節。",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const Tooltip(
              message: "長按拖曳排序；章節可拖入其他資料夾。根目錄固定隱藏。",
              child: Icon(Icons.info_outline, size: 16),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _searchController,
          hintText: "搜尋資料夾或章節名稱",
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  tooltip: "清除搜尋",
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = "");
                  },
                  icon: const Icon(Icons.clear),
                ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        const SizedBox(height: 12),
        DragTarget<DragData>(
          onWillAcceptWithDetails: (details) {
            return details.data.type == DragType.segment;
          },
          onAcceptWithDetails: (details) {
            _finishDrag();
            final dragData = details.data;
            if (dragData.type == DragType.segment) {
              _commitCurrentEditorToSelectedChapter(selection);
              _segmentsNotifier.moveFolderToRoot(dragData.id);
              _notifySegmentsChanged();
            }
          },
          builder: (context, candidateData, rejectedData) {
            return Container(
              key: _treeListKey,
              decoration: candidateData.isNotEmpty
                  ? BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    )
                  : null,
              child: CollectionPanel.builder(
                title: "章節樹",
                showSectionCard: false,
                minHeight: 320,
                maxHeight: 560,
                controller: _treeScrollController,
                showScrollbar: true,
                listPadding: const EdgeInsets.all(8),
                itemCount: rows.length,
                emptyTitle: "尚無章節",
                emptyDescription: "請新增第一個資料夾",
                emptyIcon: Icons.create_new_folder_outlined,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  if (row.isFolder) {
                    return _buildSegmentItem(
                      row.folder,
                      row.depth,
                      wordCountMode,
                      selection,
                    );
                  }
                  final chapterIndex = row.chapterIndex!;
                  return _buildChapterItem(
                    row.folder.chapters[chapterIndex],
                    row.folder,
                    row.depth,
                    chapterIndex,
                    wordCountMode,
                    selection,
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AddItemInput(
                title: switch (_createType) {
                  _CreateType.chapter =>
                    canAddToSelectedFolder ? "章節名稱" : "請先選擇資料夾",
                  _CreateType.childFolder =>
                    canAddToSelectedFolder ? "子資料夾" : "請先選擇父資料夾",
                  _CreateType.rootFolder => "根資料夾",
                },
                enabled:
                    _createType == _CreateType.rootFolder ||
                    canAddToSelectedFolder,
                onAdd: (name) {
                  switch (_createType) {
                    case _CreateType.chapter:
                      _addChapter(selectedFolder!.segmentUUID, name, selection);
                    case _CreateType.childFolder:
                      _addSegment(
                        name,
                        selection,
                        parentFolderID: selectedFolder!.segmentUUID,
                      );
                    case _CreateType.rootFolder:
                      _addSegment(name, selection);
                  }
                },
              ),
            ),
            SizedBox(
              width: 128,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCreateTypeButton(
                    type: _CreateType.chapter,
                    icon: Icons.article_outlined,
                    tooltip: "新增章節",
                  ),
                  _buildCreateTypeButton(
                    type: _CreateType.childFolder,
                    icon: Icons.folder_copy_outlined,
                    tooltip: "新增子資料夾",
                  ),
                  _buildCreateTypeButton(
                    type: _CreateType.rootFolder,
                    icon: Icons.folder_outlined,
                    tooltip: "新增根資料夾",
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // MARK: - 編輯 Helper 方法

  void _startEditingSegment(SegmentData segment) {
    setState(() {
      _editingSegmentID = segment.segmentUUID;
      _editingChapterID = null;
      _renameController?.dispose();
      _renameController = TextEditingController(text: segment.segmentName);
    });
  }

  void _submitEditingSegment() {
    if (_editingSegmentID != null && _renameController != null) {
      final value = _renameController!.text.trim();
      _segmentsNotifier.renameSegment(
        segmentID: _editingSegmentID!,
        name: value.isEmpty ? "（未命名資料夾）" : value,
      );
      _notifySegmentsChanged();
    }
    _cancelEditing();
  }

  void _startEditingChapter(ChapterData chapter) {
    setState(() {
      _editingChapterID = chapter.chapterUUID;
      _editingSegmentID = null;
      _renameController?.dispose();
      _renameController = TextEditingController(text: chapter.chapterName);
    });
  }

  void _submitEditingChapter(String folderID) {
    if (_editingChapterID != null && _renameController != null) {
      final location = ChapterTree.findChapter(
        _segments,
        folderId: folderID,
        chapterId: _editingChapterID!,
      );
      if (location != null) {
        final value = _renameController!.text.trim();
        _segmentsNotifier.renameChapter(
          segmentID: folderID,
          chapterID: _editingChapterID!,
          name: value.isEmpty ? "（Untitled）" : value,
        );
        _notifySegmentsChanged();
      }
    }
    _cancelEditing();
  }

  void _cancelEditing() {
    setState(() {
      _editingSegmentID = null;
      _editingChapterID = null;
      _renameController?.dispose();
      _renameController = null;
    });
  }

  // MARK: - Row builders

  Widget _buildSegmentItem(
    SegmentData segment,
    int depth,
    WordCountMode wordCountMode,
    _SelectionSnapshot selection,
  ) {
    final isSelected = _selectedFolderID == segment.segmentUUID;
    final isEditing = _editingSegmentID == segment.segmentUUID;
    final isExpanded = _expandedSegmentIDs.contains(segment.segmentUUID);
    final subtreeChapters = ChapterTree.chaptersDepthFirst([segment]).toList();
    final segmentWordCount = subtreeChapters.fold<int>(
      0,
      (sum, location) => sum + location.chapter.getWordCount(wordCountMode),
    );
    final canDelete = _totalChaptersCount - subtreeChapters.length >= 1;

    return DraggableCardNode<DragData>(
      key: ValueKey(segment.segmentUUID),
      dragData: DragData(
        id: segment.segmentUUID,
        type: DragType.segment,
        currentIndex: 0,
      ),
      nodeId: segment.segmentUUID,
      nodeType: NodeType.folder,

      isDragging: _isDragging,
      isThisDragging: _currentDragData?.id == segment.segmentUUID,
      isDragForbidden:
          _currentDragData?.type == DragType.segment &&
          _currentDragData?.id != null &&
          ChapterTree.containsFolder(
            ChapterTree.findFolder(_segments, _currentDragData!.id) ?? segment,
            segment.segmentUUID,
          ),
      isSelected: isSelected,
      indent: depth * 24.0,

      title: InlineEditableText(
        value: segment.segmentName,
        controller: _renameController,
        isEditing: isEditing,
        onEdit: () => _startEditingSegment(segment),
        onSubmitted: (_) => _submitEditingSegment(),
        onCanceled: _cancelEditing,
        emptyText: "（未命名資料夾）",
        style: isSelected
            ? TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontSize: 16,
              )
            : const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(
        "${subtreeChapters.length} 章 • ${segment.childSegments.length} 個子資料夾 • $segmentWordCount 字",
        style: Theme.of(context).textTheme.bodySmall,
      ),
      leading: SizedBox(
        width: 48,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: isExpanded ? "收合資料夾" : "展開資料夾",
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedSegmentIDs.remove(segment.segmentUUID);
                    } else {
                      _expandedSegmentIDs.add(segment.segmentUUID);
                    }
                  });
                },
                child: SizedBox(
                  width: 24,
                  height: 32,
                  child: Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    size: 18,
                  ),
                ),
              ),
            ),
            Icon(
              isExpanded ? Icons.folder_open_outlined : Icons.folder_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
          ],
        ),
      ),
      trailing: ItemActionBar.editDelete(
        onEdit: () => _startEditingSegment(segment),
        onDelete: canDelete
            ? () => _deleteSegment(segment.segmentUUID, selection)
            : null,
        deleteTooltip: canDelete ? "刪除此資料夾與其中章節" : "至少須保留一章",
      ),
      onClicked: () {
        setState(() {
          _expandedSegmentIDs.add(segment.segmentUUID);
        });
        _selectSegment(segment.segmentUUID, selection);
      },

      onDragStarted: () {
        _beginDrag(
          DragData(
            id: segment.segmentUUID,
            type: DragType.segment,
            currentIndex: 0,
          ),
        );
      },
      onDragEnd: _finishDrag,

      getDropZoneSize: (pos) {
        if (_currentDragData == null) return 0.0;

        if (_currentDragData!.type == DragType.segment) {
          return switch (pos) {
            DropPosition.before => 0.3,
            DropPosition.child => 0.4,
            DropPosition.after => 0.3,
          };
        } else if (_currentDragData!.type == DragType.chapter) {
          final isRootFolder =
              ChapterTree.findParentFolder(_segments, segment.segmentUUID) ==
              null;
          if (isRootFolder) {
            return pos == DropPosition.child ? 1.0 : 0.0;
          }
          return switch (pos) {
            DropPosition.before => 0.3,
            DropPosition.child => 0.4,
            DropPosition.after => 0.3,
          };
        }
        return 0.0;
      },

      onAccept: (data, pos) {
        _finishDrag();
        if (data.type == DragType.segment) {
          _moveFolderByDrag(data.id, segment.segmentUUID, pos, selection);
        } else if (data.type == DragType.chapter) {
          if (pos == DropPosition.child) {
            _moveChapterToSegment(data.id, segment.segmentUUID, selection);
            AppFeedback.success(
              context,
              "章節已移動到「${segment.segmentName}」",
              duration: const Duration(seconds: 2),
            );
          } else {
            _moveChapterRelativeToFolder(
              data.id,
              segment.segmentUUID,
              pos,
              selection,
            );
          }
        }
      },
    );
  }

  Widget _buildChapterItem(
    ChapterData chapter,
    SegmentData folder,
    int depth,
    int chapterIdx,
    WordCountMode wordCountMode,
    _SelectionSnapshot selection,
  ) {
    final isSelected = selection.chapterID == chapter.chapterUUID;
    final isEditing = _editingChapterID == chapter.chapterUUID;

    return DraggableCardNode<DragData>(
      key: ValueKey(chapter.chapterUUID),
      dragData: DragData(
        id: chapter.chapterUUID,
        type: DragType.chapter,
        currentIndex: chapterIdx,
      ),
      nodeId: chapter.chapterUUID,
      nodeType: NodeType.item,

      isDragging: _isDragging,
      isThisDragging: _currentDragData?.id == chapter.chapterUUID,
      isSelected: isSelected,

      title: InlineEditableText(
        value: chapter.chapterName,
        controller: _renameController,
        isEditing: isEditing,
        onEdit: () => _startEditingChapter(chapter),
        onSubmitted: (_) => _submitEditingChapter(folder.segmentUUID),
        onCanceled: _cancelEditing,
        emptyText: "（Untitled）",
        style: isSelected
            ? TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontSize: 16,
              )
            : const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(
        "${chapter.getWordCount(wordCountMode)} 字",
        style: Theme.of(context).textTheme.bodySmall,
      ),
      leading: SizedBox(
        width: 48,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 24),
            Icon(
              Icons.article_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
          ],
        ),
      ),
      trailing: ItemActionBar.editDelete(
        onEdit: () => _startEditingChapter(chapter),
        onDelete: _totalChaptersCount > 1
            ? () => _deleteChapter(folder, chapter.chapterUUID, selection)
            : null,
        deleteTooltip: _totalChaptersCount > 1 ? "刪除此章節" : "至少須保留一章",
      ),
      onClicked: () =>
          _selectChapter(folder.segmentUUID, chapter.chapterUUID, selection),
      indent: depth * 24.0,

      onDragStarted: () {
        _beginDrag(
          DragData(
            id: chapter.chapterUUID,
            type: DragType.chapter,
            currentIndex: chapterIdx,
          ),
        );
      },
      onDragEnd: _finishDrag,

      getDropZoneSize: (pos) {
        if (_currentDragData == null) return 0.0;

        if (_currentDragData!.type == DragType.chapter) {
          // 同層級拖動 (Before/After 50%)
          return pos == DropPosition.child ? 0.0 : 0.5;
        }
        if (_currentDragData!.type == DragType.segment) {
          return pos == DropPosition.child ? 0.0 : 0.5;
        }
        return 0.0;
      },

      onAccept: (data, pos) {
        _finishDrag();
        if (data.type == DragType.chapter) {
          _moveChapterRelativeToChapter(
            data.id,
            chapter.chapterUUID,
            pos,
            selection,
          );
        } else if (data.type == DragType.segment) {
          _moveFolderRelativeToChapter(
            data.id,
            chapter.chapterUUID,
            pos,
            selection,
          );
        }
      },
    );
  }
}
