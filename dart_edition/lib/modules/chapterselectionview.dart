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

// MARK: - XML Codec

class ChapterSelectionCodec {
  static List<SegmentData> _createSnapshot(List<SegmentData> source) {
    return List<SegmentData>.unmodifiable(
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

  static void _writeTextElement(
    xml.XmlBuilder builder,
    String name,
    String value,
  ) {
    builder.element(
      name,
      nest: () {
        builder.text(_encodeNewlines(value));
      },
    );
  }

  static String _readElementText(xml.XmlElement? element) {
    if (element == null) return "";
    if (element.children.isEmpty) {
      return _decodeNewlines(element.innerText);
    }
    final cdataBuffer = StringBuffer();
    for (final node in element.children) {
      if (node is xml.XmlCDATA) {
        cdataBuffer.write(node.text);
      }
    }
    final cdataText = cdataBuffer.toString();
    if (cdataText.isNotEmpty) {
      return _decodeNewlines(cdataText);
    }
    final buffer = StringBuffer();
    for (final node in element.children) {
      if (node is xml.XmlText || node is xml.XmlCDATA) {
        buffer.write(node.text);
      }
    }
    final text = buffer.toString();
    return _decodeNewlines(text.isNotEmpty ? text : element.innerText);
  }

  static String _encodeNewlines(String value) {
    if (value.isEmpty) return value;
    final normalized = value.replaceAll("\r\n", "\n").replaceAll("\r", "\n");
    final buffer = StringBuffer();
    for (final codeUnit in normalized.codeUnits) {
      switch (codeUnit) {
        case 10: // \n
          buffer.write("&#10;");
          break;
        case 35: // #
          buffer.write("&#35;");
          break;
        case 59: // ;
          buffer.write("&#59;");
          break;
        default:
          buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }

  static String _decodeNewlines(String value) {
    return value
        .replaceAll("&#13;", "")
        .replaceAll("&#10;", "\n")
        .replaceAll("&#35;", "#")
        .replaceAll("&#59;", ";");
  }

  /// 序列化成與 Qt SaveFile() 兼容的 <Type> 片段
  static String? saveXML(List<SegmentData> segments) {
    final snapshot = _createSnapshot(segments);
    if (snapshot.isEmpty || !snapshot.any((seg) => seg.chapters.isNotEmpty)) {
      return null;
    }

    // 使用 xml package 構建 XML，自動處理 escaping
    final builder = xml.XmlBuilder();
    builder.element(
      "Type",
      nest: () {
        builder.element(
          "Name",
          nest: () {
            builder.text("ChapterSelection");
          },
        );

        for (final seg in snapshot) {
          builder.element(
            "Segment",
            attributes: {"Name": seg.segmentName, "UUID": seg.segmentUUID},
            nest: () {
              for (final ch in seg.chapters) {
                builder.element(
                  "Chapter",
                  attributes: {"Name": ch.chapterName, "UUID": ch.chapterUUID},
                  nest: () {
                    _writeTextElement(builder, "Content", ch.chapterContent);
                  },
                );
              }
            },
          );
        }
      },
    );

    return builder.buildDocument().toXmlString(pretty: true);
  }

  /// 自 <Type> 區塊解析（需 <Name>ChapterSelection</Name>）
  static List<SegmentData>? loadXML(String xmlContent) {
    try {
      final document = xml.XmlDocument.parse(xmlContent);
      final typeElement = document.findAllElements("Type").firstOrNull;

      if (typeElement == null) return null;

      final nameElement = typeElement.findAllElements("Name").firstOrNull;
      if (nameElement == null || nameElement.innerText != "ChapterSelection") {
        return null;
      }

      final segments = <SegmentData>[];
      final segmentElements = typeElement.findAllElements("Segment");

      for (final segElement in segmentElements) {
        final segmentName = segElement.getAttribute("Name") ?? "";
        final segmentUUID = segElement.getAttribute("UUID") ?? "";

        final chapters = <ChapterData>[];
        final chapterElements = segElement.findAllElements("Chapter");

        for (final chElement in chapterElements) {
          final chapterName = chElement.getAttribute("Name") ?? "";
          final chapterUUID = chElement.getAttribute("UUID") ?? "";

          final contentElement = chElement
              .findAllElements("Content")
              .firstOrNull;
          final chapterContent = _readElementText(contentElement);

          chapters.add(
            ChapterData(
              chapterName: chapterName,
              chapterContent: chapterContent,
              chapterUUID: chapterUUID,
            ),
          );
        }

        segments.add(
          SegmentData(
            segmentName: segmentName,
            chapters: chapters,
            segmentUUID: segmentUUID,
          ),
        );
      }

      return segments.isNotEmpty ? _createSnapshot(segments) : null;
    } catch (e) {
      debugPrint("ChapterSelection XML Parse Error: $e");
      return null;
    }
  }
}

// MARK: - View

class ChapterSelectionView extends ConsumerStatefulWidget {
  final VoidCallback? onChanged;

  const ChapterSelectionView({super.key, this.onChanged});

  @override
  ConsumerState<ChapterSelectionView> createState() =>
      _ChapterSelectionViewState();
}

class _SelectionSnapshot {
  final String? segmentID;
  final String? chapterID;
  final int? segmentIndex;

  const _SelectionSnapshot({
    required this.segmentID,
    required this.chapterID,
    required this.segmentIndex,
  });
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
  final ScrollController _segmentListScrollController = ScrollController();
  final ScrollController _chapterListScrollController = ScrollController();

  // 列表容器的 GlobalKey，用於獲取邊界
  final GlobalKey _segmentListKey = GlobalKey();
  final GlobalKey _chapterListKey = GlobalKey();

  // 自動滾動相關
  Timer? _autoScrollTimer;
  ScrollController? _currentScrollController; // 新增：追蹤當前正在滾動的控制器
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
    return _segments.fold(0, (sum, seg) => sum + seg.chapters.length);
  }

  int _totalWordCountForMode(
    List<SegmentData> segments,
    WordCountMode wordCountMode,
  ) {
    return segments.fold(
      0,
      (sum, seg) =>
          sum +
          seg.chapters.fold(0, (s, c) => s + c.getWordCount(wordCountMode)),
    );
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
        segmentIndex: null,
      );
    }

    final int idx = segments.indexWhere((seg) => seg.segmentUUID == segmentID);
    return _SelectionSnapshot(
      segmentID: segmentID,
      chapterID: chapterID,
      segmentIndex: idx >= 0 ? idx : null,
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
    _segmentListScrollController.dispose();
    _chapterListScrollController.dispose();
    super.dispose();
  }

  // MARK: - 自動滾動方法

  /// 處理拖動時的自動滾動（頁面級別）
  void _handleDragUpdate(DragUpdateDetails details) {
    // 如果正在拖動，優先檢查列表滾動
    if (_isDragging) {
      // 檢查是否在任一列表的邊緣 20px 內
      bool handledByList = false;

      // 檢查區段列表
      final segmentBox =
          _segmentListKey.currentContext?.findRenderObject() as RenderBox?;
      if (segmentBox != null) {
        final segmentPosition = segmentBox.localToGlobal(Offset.zero);
        final segmentSize = segmentBox.size;
        final relativeY = details.globalPosition.dy - segmentPosition.dy;

        // 在區段列表範圍內
        if (relativeY >= 0 && relativeY <= segmentSize.height) {
          if (relativeY < _listScrollEdgeThreshold) {
            // 接近頂部
            _startAutoScroll(_segmentListScrollController, scrollUp: true);
            handledByList = true;
          } else if (relativeY >
              segmentSize.height - _listScrollEdgeThreshold) {
            // 接近底部
            _startAutoScroll(_segmentListScrollController, scrollUp: false);
            handledByList = true;
          }
        }
      }

      // 如果區段列表沒有處理，檢查章節列表
      if (!handledByList) {
        final chapterBox =
            _chapterListKey.currentContext?.findRenderObject() as RenderBox?;
        if (chapterBox != null) {
          final chapterPosition = chapterBox.localToGlobal(Offset.zero);
          final chapterSize = chapterBox.size;
          final relativeY = details.globalPosition.dy - chapterPosition.dy;

          // 在章節列表範圍內
          if (relativeY >= 0 && relativeY <= chapterSize.height) {
            if (relativeY < _listScrollEdgeThreshold) {
              // 接近頂部
              _startAutoScroll(_chapterListScrollController, scrollUp: true);
              handledByList = true;
            } else if (relativeY >
                chapterSize.height - _listScrollEdgeThreshold) {
              // 接近底部
              _startAutoScroll(_chapterListScrollController, scrollUp: false);
              handledByList = true;
            }
          }
        }
      }

      // 如果列表處理了滾動，就不處理頁面滾動
      if (handledByList) {
        return;
      }

      // 如果不在列表邊緣，停止列表滾動
      if (_currentScrollController == _segmentListScrollController ||
          _currentScrollController == _chapterListScrollController) {
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
      // 只在不是列表控制器時才停止
      if (_currentScrollController != _segmentListScrollController &&
          _currentScrollController != _chapterListScrollController) {
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

  // MARK: - Helper 方法

  void _appendChapterToSegment(int segmentIndex, ChapterData chapter) {
    if (segmentIndex < 0 || segmentIndex >= _segments.length) {
      return;
    }

    final segmentID = _segments[segmentIndex].segmentUUID;
    _segmentsNotifier.addChapter(segmentID: segmentID, chapter: chapter);
  }

  void _appendSegment(SegmentData segment) {
    _segmentsNotifier.addSegment(segment);
  }

  SegmentData _removeSegmentAt(int segmentIndex) {
    final removed = _segments[segmentIndex];
    _segmentsNotifier.removeSegmentById(removed.segmentUUID);
    return removed;
  }

  ChapterData _removeChapterFromSegment(int segmentIndex, int chapterIndex) {
    final segment = _segments[segmentIndex];
    final removed = segment.chapters[chapterIndex];
    _segmentsNotifier.removeChapter(
      segmentID: segment.segmentUUID,
      chapterID: removed.chapterUUID,
    );
    return removed;
  }

  void _initializeIfEmpty() {
    if (_segments.isEmpty) {
      _appendSegment(
        SegmentData(
          segmentName: "Seg 1",
          chapters: [ChapterData(chapterName: "Chapter 1", chapterContent: "")],
        ),
      );
    } else if (_totalChaptersCount == 0) {
      _appendChapterToSegment(
        0,
        ChapterData(chapterName: "Chapter 1", chapterContent: ""),
      );
    }
  }

  // MARK: - Helper：保存/選取

  void _commitCurrentEditorToSelectedChapter(_SelectionSnapshot selection) {
    final si = selection.segmentIndex;
    final cid = selection.chapterID;
    if (si != null && cid != null) {
      _segmentsNotifier.updateChapterContent(
        segmentID: _segments[si].segmentUUID,
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

  void _applySegmentSelection(String segID, {required String? previousChapterID}) {
    _setSelection(segmentID: segID, chapterID: previousChapterID);

    final si = _segments.indexWhere((seg) => seg.segmentUUID == segID);
    if (si >= 0) {
      if (_segments[si].chapters.isNotEmpty) {
        final firstChapter = _segments[si].chapters.first;
        _setSelection(segmentID: segID, chapterID: firstChapter.chapterUUID);
        _setEditorContent(firstChapter.chapterContent);
      } else {
        _setSelection(segmentID: segID, chapterID: null);
        _setEditorContent("");
      }
    }
  }

  void _applyChapterSelection(int segIdx, String chapterID) {
    _setSelection(
      segmentID: _segments[segIdx].segmentUUID,
      chapterID: chapterID,
    );

    final chapterIdx = _segments[segIdx].chapters.indexWhere(
      (ch) => ch.chapterUUID == chapterID,
    );
    if (chapterIdx >= 0) {
      _setEditorContent(_segments[segIdx].chapters[chapterIdx].chapterContent);
    }
  }

  void _selectSegment(String segID, _SelectionSnapshot selection) {
    _commitCurrentEditorToSelectedChapter(selection);
    _applySegmentSelection(segID, previousChapterID: selection.chapterID);
  }

  void _selectChapter(
    int segIdx,
    String chapterID,
    _SelectionSnapshot selection,
  ) {
    _commitCurrentEditorToSelectedChapter(selection);
    _applyChapterSelection(segIdx, chapterID);
  }

  void _notifySegmentsChanged() {
    widget.onChanged?.call();
  }

  // MARK: - 新增方法

  void _addSegment(String name, _SelectionSnapshot selection) {
    _commitCurrentEditorToSelectedChapter(selection);

    name = name.trim();
    final finalName = name.isEmpty ? "Seg ${_segments.length + 1}" : name;
    final firstChapter = ChapterData(
      chapterName: "Chapter 1",
      chapterContent: "",
    );
    final newSegment = SegmentData(
      segmentName: finalName,
      chapters: [firstChapter],
    );

    _appendSegment(newSegment);
    _notifySegmentsChanged();

    _applySegmentSelection(
      newSegment.segmentUUID,
      previousChapterID: selection.chapterID,
    );
  }

  void _addChapter(int segIdx, String name, _SelectionSnapshot selection) {
    _commitCurrentEditorToSelectedChapter(selection);

    name = name.trim();
    final finalName = name.isEmpty
        ? "Chapter ${_segments[segIdx].chapters.length + 1}"
        : name;
    final newChapter = ChapterData(chapterName: finalName, chapterContent: "");

    _appendChapterToSegment(segIdx, newChapter);
    _notifySegmentsChanged();

    _applyChapterSelection(segIdx, newChapter.chapterUUID);
  }

  // MARK: - 刪除方法

  void _deleteSegment(String segmentID, _SelectionSnapshot selection) {
    final segIdx = _segments.indexWhere((seg) => seg.segmentUUID == segmentID);
    if (segIdx < 0 || _segments.length <= 1) return;

    final remainingChapters =
        _totalChaptersCount - _segments[segIdx].chapters.length;
    if (remainingChapters <= 0) return;

    // 如果要刪除的是當前選中的區段，先保存編輯器內容
    if (selection.segmentID == segmentID) {
      _commitCurrentEditorToSelectedChapter(selection);
    }

    _removeSegmentAt(segIdx);
    _notifySegmentsChanged();

    // 選擇第一個可用的區段
    if (_segments.isNotEmpty) {
      final firstSeg = _segments.first;
      _setSelection(
        segmentID: firstSeg.segmentUUID,
        chapterID: selection.chapterID,
      );
      final firstChapter = firstSeg.chapters.isNotEmpty
          ? firstSeg.chapters.first
          : null;
      if (firstChapter != null) {
        _setSelection(
          segmentID: firstSeg.segmentUUID,
          chapterID: firstChapter.chapterUUID,
        );
        _setEditorContent(firstChapter.chapterContent);
      } else {
        _setSelection(segmentID: firstSeg.segmentUUID, chapterID: null);
        _setEditorContent("");
      }
    } else {
      _setSelection(segmentID: null, chapterID: null);
      _setEditorContent("");
    }
  }

  void _deleteChapter(
    int segIdx,
    String chapterID,
    _SelectionSnapshot selection,
  ) {
    if (segIdx < 0 || segIdx >= _segments.length) return;

    final chapterIdx = _segments[segIdx].chapters.indexWhere(
      (ch) => ch.chapterUUID == chapterID,
    );
    if (chapterIdx < 0 || _totalChaptersCount <= 1) return;

    // 如果要刪除的是當前選中的章節，先保存編輯器內容
    if (selection.chapterID == chapterID) {
      _commitCurrentEditorToSelectedChapter(selection);
    }

    _removeChapterFromSegment(segIdx, chapterIdx);

    // 選擇下一個可用章節
    if (_segments[segIdx].chapters.isNotEmpty) {
      final nextIdx = chapterIdx < _segments[segIdx].chapters.length
          ? chapterIdx
          : _segments[segIdx].chapters.length - 1;
      final nextChapter = _segments[segIdx].chapters[nextIdx];
      _setSelection(
        segmentID: _segments[segIdx].segmentUUID,
        chapterID: nextChapter.chapterUUID,
      );
      _setEditorContent(nextChapter.chapterContent);
    } else {
      _setSelection(segmentID: _segments[segIdx].segmentUUID, chapterID: null);
      _setEditorContent("");

      // 如果區段為空且有多個區段，刪除該區段
      if (_segments.length > 1) {
        final removedSegID = _segments[segIdx].segmentUUID;
        _removeSegmentAt(segIdx);

        if (_segments.isNotEmpty) {
          final firstSeg = _segments.first;
          _setSelection(
            segmentID: firstSeg.segmentUUID,
            chapterID: selection.chapterID,
          );
          final firstChapter = firstSeg.chapters.isNotEmpty
              ? firstSeg.chapters.first
              : null;
          if (firstChapter != null) {
            _setSelection(
              segmentID: firstSeg.segmentUUID,
              chapterID: firstChapter.chapterUUID,
            );
            _setEditorContent(firstChapter.chapterContent);
          } else {
            _setSelection(segmentID: firstSeg.segmentUUID, chapterID: null);
            _setEditorContent("");
          }
        } else {
          _setSelection(segmentID: null, chapterID: null);
          _setEditorContent("");
        }

        // 如果刪除的區段是當前選中的區段，重新選擇
        if (selection.segmentID == removedSegID && _segments.isNotEmpty) {
          final firstSeg = _segments.first;
          _setSelection(
            segmentID: firstSeg.segmentUUID,
            chapterID: selection.chapterID,
          );
          final firstChapter = firstSeg.chapters.isNotEmpty
              ? firstSeg.chapters.first
              : null;
          if (firstChapter != null) {
            _setSelection(
              segmentID: firstSeg.segmentUUID,
              chapterID: firstChapter.chapterUUID,
            );
            _setEditorContent(firstChapter.chapterContent);
          }
        }
      }
    }

    _notifySegmentsChanged();
  }

  // MARK: - 移動/拖放方法

  void _moveSegmentByDrag(
    int fromIndex,
    int toIndex,
    _SelectionSnapshot selection,
  ) {
    if (fromIndex == toIndex) return;

    _commitCurrentEditorToSelectedChapter(selection);

    _segmentsNotifier.moveSegment(fromIndex: fromIndex, toIndex: toIndex);
    _notifySegmentsChanged();
  }

  void _moveChapterByDrag(
    int segIdx,
    int fromIndex,
    int toIndex,
    _SelectionSnapshot selection,
  ) {
    if (segIdx < 0 || segIdx >= _segments.length) return;
    if (fromIndex == toIndex) return;

    _commitCurrentEditorToSelectedChapter(selection);

    _segmentsNotifier.moveChapterWithinSegment(
      segmentID: _segments[segIdx].segmentUUID,
      fromIndex: fromIndex,
      toIndex: toIndex,
    );
    _notifySegmentsChanged();
  }

  void _moveChapterToSegment(
    String chapterUUID,
    String toSegmentUUID,
    _SelectionSnapshot selection,
  ) {
    _commitCurrentEditorToSelectedChapter(selection);

    // 找到來源章節
    int? sourceSegIdx;
    int? sourceChapIdx;
    for (int si = 0; si < _segments.length; si++) {
      final ci = _segments[si].chapters.indexWhere(
        (ch) => ch.chapterUUID == chapterUUID,
      );
      if (ci >= 0) {
        sourceSegIdx = si;
        sourceChapIdx = ci;
        break;
      }
    }

    if (sourceSegIdx == null || sourceChapIdx == null) return;

    // 找到目標區段
    final targetSegIdx = _segments.indexWhere(
      (seg) => seg.segmentUUID == toSegmentUUID,
    );
    if (targetSegIdx < 0 || targetSegIdx == sourceSegIdx) return;

    final sourceSegID = _segments[sourceSegIdx].segmentUUID;
    final movingChapter = _segments[sourceSegIdx].chapters[sourceChapIdx];

    // 執行移動
    _segmentsNotifier.moveChapterToSegment(
      chapterID: chapterUUID,
      targetSegmentID: toSegmentUUID,
    );

    final sourceSegAfterMoveIdx = _segments.indexWhere(
      (seg) => seg.segmentUUID == sourceSegID,
    );

    // 更新選擇
    _setSelection(
      segmentID: toSegmentUUID,
      chapterID: movingChapter.chapterUUID,
    );
    _setEditorContent(movingChapter.chapterContent);

    // 如果來源區段變空，刪除它（如果有多個區段）
    if (sourceSegAfterMoveIdx >= 0 &&
        _segments[sourceSegAfterMoveIdx].chapters.isEmpty &&
        _segments.length > 1) {
      _segmentsNotifier.removeSegmentById(sourceSegID);

      // 如果刪除的區段是當前選中的區段，重新選擇
      if (selection.segmentID == sourceSegID) {
        final firstSeg = _segments.firstWhere(
          (seg) => seg.segmentUUID == toSegmentUUID,
          orElse: () => _segments.isNotEmpty ? _segments.first : SegmentData(),
        );
        _setSelection(
          segmentID: firstSeg.segmentUUID,
          chapterID: movingChapter.chapterUUID,
        );
        _setEditorContent(movingChapter.chapterContent);
      }
    }

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
                          "全書共 ${_totalWordCountForMode(segments, wordCountMode)} 字",
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // 主要內容區域 - 直排佈局
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 上方：區段列表
                  _buildSegmentsList(
                    segments,
                    wordCountMode,
                    selectionSnapshot,
                  ),
                  const SizedBox(height: 24),

                  // 下方：章節列表
                  _buildChaptersList(
                    segments,
                    wordCountMode,
                    selectionSnapshot,
                  ),
                ],
              ),
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

    var selection = _readSelectionSnapshot(_segments);

    if ((selection.segmentID == null || selection.segmentIndex == null) &&
        _segments.isNotEmpty) {
      _setSelection(
        segmentID: _segments.first.segmentUUID,
        chapterID: selection.chapterID,
      );
      selection = _SelectionSnapshot(
        segmentID: _segments.first.segmentUUID,
        chapterID: selection.chapterID,
        segmentIndex: 0,
      );
    }

    if (selection.chapterID == null) {
      final si = selection.segmentIndex;
      if (si != null && _segments[si].chapters.isNotEmpty) {
        _setSelection(
          segmentID: _segments[si].segmentUUID,
          chapterID: _segments[si].chapters.first.chapterUUID,
        );
        selection = _SelectionSnapshot(
          segmentID: _segments[si].segmentUUID,
          chapterID: _segments[si].chapters.first.chapterUUID,
          segmentIndex: si,
        );
      }
    }

    final resolvedSelection = _readSelectionSnapshot(_segments);
    final si = resolvedSelection.segmentIndex;
    final cid = resolvedSelection.chapterID;
    if (si != null && cid != null) {
      final ci = _segments[si].chapters.indexWhere(
        (ch) => ch.chapterUUID == cid,
      );
      if (ci >= 0) {
        _setEditorContent(_segments[si].chapters[ci].chapterContent);
      }
    }

    final hasInitializedDefaultData =
        beforeSegmentsCount != _segments.length ||
        beforeChaptersCount != _totalChaptersCount;
    if (hasInitializedDefaultData) {
      _notifySegmentsChanged();
    }
  }

  Widget _buildSegmentsList(
    List<SegmentData> segments,
    WordCountMode wordCountMode,
    _SelectionSnapshot selection,
  ) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MediumTitle(icon: Icons.folder_outlined, text: "區段選擇"),
            const SizedBox(height: 16),

            // 區段列表 - 使用 DragTarget 包裝以支援排序
            DragTarget<DragData>(
              onWillAcceptWithDetails: (details) {
                // 只接受區段類型的拖動
                return details.data.type == DragType.segment;
              },
              onAcceptWithDetails: (details) {
                setState(() {
                  _isDragging = false;
                });
                _stopAutoScroll(); // 停止自動滾動
                // 拖放到空白區域時，移動到列表最後
                final dragData = details.data;
                if (dragData.type == DragType.segment) {
                  final fromIndex = dragData.currentIndex;
                  final toIndex = segments.length - 1; // 移動到最後
                  if (fromIndex >= 0 &&
                      fromIndex < segments.length &&
                      fromIndex != toIndex) {
                    _moveSegmentByDrag(fromIndex, toIndex, selection);
                  }
                }
              },
              builder: (context, candidateData, rejectedData) {
                final isHighlighted = candidateData.isNotEmpty;

                return Container(
                  key: _segmentListKey,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isHighlighted
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.outline.withOpacity(0.2),
                      width: isHighlighted ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isHighlighted
                        ? Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withOpacity(0.1)
                        : null,
                  ),
                  child: ListView.builder(
                    controller: _segmentListScrollController,
                    itemCount: segments.length,
                    itemBuilder: (context, index) => _buildSegmentItem(
                      segments[index],
                      index,
                      wordCountMode,
                      selection,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // 新增區段
            AddItemInput(
              title: "區段",
              onAdd: (name) => _addSegment(name, selection),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChaptersList(
    List<SegmentData> segments,
    WordCountMode wordCountMode,
    _SelectionSnapshot selection,
  ) {
    final selectedSegIdx = selection.segmentIndex;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: MediumTitle(
                    icon: Icons.article_outlined,
                    text: "章節選擇",
                  ),
                ),
                Tooltip(
                  message: "拖動章節排序 | 長按拖動至其他區段",
                  child: Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 章節列表 - 使用 DragTarget 包裝以支援拖放排序
            DragTarget<DragData>(
              onWillAcceptWithDetails: (details) {
                // 只接受章節類型的拖動
                return details.data.type == DragType.chapter;
              },
              onAcceptWithDetails: (details) {
                setState(() {
                  _isDragging = false;
                });
                _stopAutoScroll(); // 停止自動滾動
                // 拖放到空白區域時，移動到列表最後
                final dragData = details.data;
                if (selectedSegIdx != null &&
                    dragData.type == DragType.chapter) {
                  _moveChapterToSegment(
                    dragData.id,
                    segments[selectedSegIdx].segmentUUID,
                    selection,
                  );
                }
              },
              builder: (context, candidateData, rejectedData) {
                final isHighlighted = candidateData.isNotEmpty;

                return Container(
                  key: _chapterListKey,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isHighlighted
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.outline.withOpacity(0.2),
                      width: isHighlighted ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isHighlighted
                        ? Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withOpacity(0.1)
                        : null,
                  ),
                  child: selectedSegIdx != null && selectedSegIdx >= 0
                      ? ListView.builder(
                          controller: _chapterListScrollController,
                          itemCount: segments[selectedSegIdx].chapters.length,
                          itemBuilder: (context, index) => _buildChapterItem(
                            segments[selectedSegIdx].chapters[index],
                            selectedSegIdx,
                            index,
                            wordCountMode,
                            selection,
                          ),
                        )
                      : Center(
                          child: Text(
                            "請先選擇一個區段",
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                );
              },
            ),
            const SizedBox(height: 16),

            // 新增章節
            AddItemInput(
              title: selectedSegIdx != null ? "章節名稱" : "請先選擇區段",
              enabled: selectedSegIdx != null,
              onAdd: (val) {
                if (selectedSegIdx != null) {
                  _addChapter(selectedSegIdx, val, selection);
                }
              },
            ),
          ],
        ),
      ),
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
        name: value.isEmpty ? "(未命名 Seg)" : value,
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

  void _submitEditingChapter(int segIdx) {
    if (_editingChapterID != null && _renameController != null) {
      final chapterIdx = _segments[segIdx].chapters.indexWhere(
        (c) => c.chapterUUID == _editingChapterID,
      );
      if (chapterIdx >= 0) {
        final value = _renameController!.text.trim();
        _segmentsNotifier.renameChapter(
          segmentID: _segments[segIdx].segmentUUID,
          chapterID: _editingChapterID!,
          name: value.isEmpty ? "(未命名 Chapter)" : value,
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
    int index,
    WordCountMode wordCountMode,
    _SelectionSnapshot selection,
  ) {
    final isSelected = selection.segmentID == segment.segmentUUID;
    final isEditing = _editingSegmentID == segment.segmentUUID;

    return DraggableCardNode<DragData>(
      key: ValueKey(segment.segmentUUID),
      dragData: DragData(
        id: segment.segmentUUID,
        type: DragType.segment,
        currentIndex: index,
      ),
      nodeId: segment.segmentUUID,
      nodeType: NodeType.folder,

      isDragging: _isDragging,
      isThisDragging: _currentDragData?.id == segment.segmentUUID,
      isSelected: isSelected,

      title: isEditing
          ? TextField(
              controller: _renameController,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
              ),
              onSubmitted: (_) => _submitEditingSegment(),
            )
          : GestureDetector(
              onDoubleTap: () => _startEditingSegment(segment),
              child: Text(
                segment.segmentName.isEmpty ? "(未命名 Seg)" : segment.segmentName,
                style: isSelected
                    ? TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 16,
                      )
                    : const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
              ),
            ),
      subtitle: Text(
        "${segment.chapters.fold(0, (sum, ch) => sum + ch.getWordCount(wordCountMode))} 字",
        style: Theme.of(context).textTheme.bodySmall,
      ),
      leading: Icon(
        Icons.folder_outlined,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _startEditingSegment(segment),
            tooltip: "重新命名",
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            color: Theme.of(context).colorScheme.error,
            onPressed: () {
              if (_segments.length > 1) {
                _deleteSegment(segment.segmentUUID, selection);
              }
            },
            tooltip: "刪除此 Seg",
          ),
        ],
      ),
      onClicked: () => _selectSegment(segment.segmentUUID, selection),

      onDragStarted: () {
        setState(() {
          _isDragging = true;
          _currentDragData = DragData(
            id: segment.segmentUUID,
            type: DragType.segment,
            currentIndex: index,
          );
        });
      },
      onDragEnd: () {
        setState(() {
          _isDragging = false;
          _currentDragData = null;
        });
        _stopAutoScroll();
      },

      getDropZoneSize: (pos) {
        if (_currentDragData == null) return 0.0;

        if (_currentDragData!.type == DragType.segment) {
          // 同層級拖動 (Before/After 50%)
          return pos == DropPosition.child ? 0.0 : 0.5;
        } else if (_currentDragData!.type == DragType.chapter) {
          // 子層級拖動到母層級 (改變子層級所在項目)
          return pos == DropPosition.child ? 1.0 : 0.0;
        }
        return 0.0;
      },

      onAccept: (data, pos) {
        if (data.type == DragType.segment) {
          int toIndex = index;
          if (pos == DropPosition.after) toIndex++;

          final fromIndex = data.currentIndex;
          if (fromIndex < toIndex) toIndex--;

          _moveSegmentByDrag(fromIndex, toIndex, selection);
        } else if (data.type == DragType.chapter && pos == DropPosition.child) {
          _moveChapterToSegment(data.id, segment.segmentUUID, selection);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("章節已移動到「${segment.segmentName}」"),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }

  Widget _buildChapterItem(
    ChapterData chapter,
    int segIdx,
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

      title: isEditing
          ? TextField(
              controller: _renameController,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
              ),
              onSubmitted: (_) => _submitEditingChapter(segIdx),
            )
          : GestureDetector(
              onDoubleTap: () => _startEditingChapter(chapter),
              child: Text(
                chapter.chapterName.isEmpty
                    ? "(未命名 Chapter)"
                    : chapter.chapterName,
                style: isSelected
                    ? TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 16,
                      )
                    : const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: null, // Use default
                        fontSize: 16,
                      ),
              ),
            ),
      subtitle: Text(
        "${chapter.getWordCount(wordCountMode)} 字",
        style: Theme.of(context).textTheme.bodySmall,
      ),
      leading: Icon(
        Icons.article_outlined,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.primary,
        size: 24,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _startEditingChapter(chapter),
            tooltip: "重新命名",
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            color: Theme.of(context).colorScheme.error,
            onPressed: () {
              if (_totalChaptersCount > 1) {
                _deleteChapter(segIdx, chapter.chapterUUID, selection);
              }
            },
            tooltip: "刪除此章節",
          ),
        ],
      ),
      onClicked: () => _selectChapter(segIdx, chapter.chapterUUID, selection),

      onDragStarted: () {
        setState(() {
          _isDragging = true;
          _currentDragData = DragData(
            id: chapter.chapterUUID,
            type: DragType.chapter,
            currentIndex: chapterIdx,
          );
        });
      },
      onDragEnd: () {
        setState(() {
          _isDragging = false;
          _currentDragData = null;
        });
        _stopAutoScroll();
      },

      getDropZoneSize: (pos) {
        if (_currentDragData == null) return 0.0;

        if (_currentDragData!.type == DragType.chapter) {
          // 同層級拖動 (Before/After 50%)
          return pos == DropPosition.child ? 0.0 : 0.5;
        }
        // 爺孫層級不可拖動 (DragType.segment cannot be dropped here)
        return 0.0;
      },

      onAccept: (data, pos) {
        if (data.type == DragType.chapter) {
          int toIndex = chapterIdx;
          if (pos == DropPosition.after) toIndex++;

          final fromIndex = data.currentIndex;
          if (fromIndex < toIndex) toIndex--;

          _moveChapterByDrag(segIdx, fromIndex, toIndex, selection);
        }
      },
    );
  }
}
