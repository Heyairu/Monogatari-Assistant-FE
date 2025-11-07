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

// MARK: - 拖放數據類型

class DragData {
  final String id;
  final DragType type;
  final int currentIndex;
  
  DragData({
    required this.id,
    required this.type,
    required this.currentIndex,
  });
}

enum DragType {
  segment,
  chapter,
}

// MARK: - 資料結構

class ChapterData {
  String chapterName;
  String chapterContent;
  String chapterUUID;
  
  ChapterData({
    this.chapterName = "",
    this.chapterContent = "",
    String? chapterUUID,
  }) : chapterUUID = chapterUUID ?? DateTime.now().millisecondsSinceEpoch.toString();
  
  int get chapterWordsCount => chapterContent.length;
  String get id => chapterUUID;
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChapterData &&
           other.chapterName == chapterName &&
           other.chapterContent == chapterContent &&
           other.chapterUUID == chapterUUID;
  }
  
  @override
  int get hashCode => Object.hash(chapterName, chapterContent, chapterUUID);
}

class SegmentData {
  String segmentName;
  List<ChapterData> chapters;
  String segmentUUID;
  
  SegmentData({
    this.segmentName = "",
    List<ChapterData>? chapters,
    String? segmentUUID,
  }) : chapters = chapters ?? [],
       segmentUUID = segmentUUID ?? DateTime.now().millisecondsSinceEpoch.toString();
  
  String get id => segmentUUID;
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SegmentData &&
           other.segmentName == segmentName &&
           _listEquals(other.chapters, chapters) &&
           other.segmentUUID == segmentUUID;
  }
  
  @override
  int get hashCode => Object.hash(segmentName, chapters, segmentUUID);
  
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// MARK: - Codec for <Type><Name>ChapterSelection</Name> ... </Type>

class ChapterSelectionCodec {
  /// 序列化成與 Qt SaveFile() 兼容的 <Type> 片段
  static String? saveXML(List<SegmentData> segments) {
    if (segments.isEmpty || !segments.any((seg) => seg.chapters.isNotEmpty)) {
      return null;
    }

    String escapeXml(String text) {
      return text
          .replaceAll("&", "&amp;")
          .replaceAll("<", "&lt;")
          .replaceAll(">", "&gt;")
          .replaceAll("\"", "&quot;")
          .replaceAll("'", "&apos;");
    }

    final buffer = StringBuffer();
    buffer.writeln("<Type>");
    buffer.writeln("  <Name>ChapterSelection</Name>");
    
    for (final seg in segments) {
      buffer.writeln("  <Segment Name=\"${escapeXml(seg.segmentName)}\" UUID=\"${seg.segmentUUID}\">");
      for (final ch in seg.chapters) {
        buffer.writeln("    <Chapter Name=\"${escapeXml(ch.chapterName)}\" UUID=\"${ch.chapterUUID}\">");
        buffer.writeln("      <Content>${escapeXml(ch.chapterContent)}</Content>");
        buffer.writeln("    </Chapter>");
      }
      buffer.writeln("  </Segment>");
    }
    
    buffer.writeln("</Type>");
    return buffer.toString();
  }

  /// 自 <Type> 區塊解析（需 <Name>ChapterSelection</Name>）
  static List<SegmentData>? loadXML(String xml) {
    // 簡化的 XML 解析實作
    // 在實際應用中，建議使用專門的 XML 解析庫
    
    if (!xml.contains("<Name>ChapterSelection</Name>")) {
      return null;
    }

    final segments = <SegmentData>[];
    
    // 提取所有 Segment 區塊
    final segmentRegex = RegExp("<Segment[^>]*Name=\"([^\"]*)\"[^>]*UUID=\"([^\"]*)\"[^>]*>(.*?)</Segment>", dotAll: true);
    final segmentMatches = segmentRegex.allMatches(xml);
    
    for (final segMatch in segmentMatches) {
      final segmentName = segMatch.group(1) ?? "";
      final segmentUUID = segMatch.group(2) ?? "";
      final segmentContent = segMatch.group(3) ?? "";
      
      final chapters = <ChapterData>[];
      
      // 提取該 Segment 中的所有 Chapter
      final chapterRegex = RegExp("<Chapter[^>]*Name=\"([^\"]*)\"[^>]*UUID=\"([^\"]*)\"[^>]*>(.*?)</Chapter>", dotAll: true);
      final chapterMatches = chapterRegex.allMatches(segmentContent);
      
      for (final chMatch in chapterMatches) {
        final chapterName = chMatch.group(1) ?? "";
        final chapterUUID = chMatch.group(2) ?? "";
        final chapterBlock = chMatch.group(3) ?? "";
        
        // 提取 Content
        final contentRegex = RegExp("<Content>(.*?)</Content>", dotAll: true);
        final contentMatch = contentRegex.firstMatch(chapterBlock);
        final chapterContent = contentMatch?.group(1) ?? "";
        
        chapters.add(ChapterData(
          chapterName: chapterName,
          chapterContent: chapterContent,
          chapterUUID: chapterUUID,
        ));
      }
      
      segments.add(SegmentData(
        segmentName: segmentName,
        chapters: chapters,
        segmentUUID: segmentUUID,
      ));
    }
    
    return segments.isNotEmpty ? segments : null;
  }
}

// MARK: - View

class ChapterSelectionView extends StatefulWidget {
  // 綁定主程式：段落與編輯器文字
  final List<SegmentData> segments;
  final String contentText;
  // 將「目前選取的 Seg/Chapter」提升為外部綁定，方便外層存檔前回寫
  final String? selectedSegmentID;
  final String? selectedChapterID;
  final ValueChanged<List<SegmentData>>? onSegmentsChanged;
  final ValueChanged<String>? onContentChanged;
  final ValueChanged<String?>? onSelectedSegmentChanged;
  final ValueChanged<String?>? onSelectedChapterChanged;

  const ChapterSelectionView({
    super.key,
    required this.segments,
    required this.contentText,
    this.selectedSegmentID,
    this.selectedChapterID,
    this.onSegmentsChanged,
    this.onContentChanged,
    this.onSelectedSegmentChanged,
    this.onSelectedChapterChanged,
  });

  @override
  State<ChapterSelectionView> createState() => _ChapterSelectionViewState();
}

class _ChapterSelectionViewState extends State<ChapterSelectionView> {
  late List<SegmentData> _segments;
  
  // 編輯名稱（雙擊）狀態
  String? _editingSegmentID;
  String? _editingChapterID;
  
  // 新增輸入框
  String _newSegmentName = "";
  String _newChapterName = "";
  
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
  static const double _autoScrollSpeed = 10.0; // 每次滾動的像素數
  static const Duration _autoScrollInterval = Duration(milliseconds: 50); // 滾動間隔
  static const double _scrollEdgeThreshold = 100.0; // 頁面邊緣觸發閾值（從頂部/底部算起）
  static const double _listScrollEdgeThreshold = 20.0; // 列表邊緣觸發閾值（修改為 20px）
  
  // MARK: - 計算屬性
  
  int get _totalChaptersCount {
    return _segments.fold(0, (sum, seg) => sum + seg.chapters.length);
  }
  
  int? get _selectedSegmentIndex {
    if (widget.selectedSegmentID == null) return null;
    return _segments.indexWhere((seg) => seg.segmentUUID == widget.selectedSegmentID);
  }
  
  // MARK: - 生命週期方法
  
  @override
  void initState() {
    super.initState();
    _initializeSegments();
    _initializeIfEmpty();
  }

  @override
  void didUpdateWidget(ChapterSelectionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segments != widget.segments) {
      _initializeSegments();
      _initializeIfEmpty();
      
      // 當 segments 更新後，需要觸发「再讀」來同步當前選中章節的內容
      if (widget.selectedSegmentID != null && widget.selectedChapterID != null) {
        final segIdx = _segments.indexWhere((seg) => seg.segmentUUID == widget.selectedSegmentID);
        if (segIdx >= 0) {
          final chapterIdx = _segments[segIdx].chapters.indexWhere((ch) => ch.chapterUUID == widget.selectedChapterID);
          if (chapterIdx >= 0) {
            // 觸發「再讀」：載入更新後的章節內容到編輯器
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onContentChanged?.call(_segments[segIdx].chapters[chapterIdx].chapterContent);
            });
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageScrollController.dispose();
    _segmentListScrollController.dispose();
    _chapterListScrollController.dispose();
    super.dispose();
  }
  
  // MARK: - 自動滾動方法
  
  /// 處理拖動時的自動滾動（頁面級別）
  void _handleDragUpdate(DragUpdateDetails details) {
    // 如果正在拖動，優先檢查列表滾动
    if (_isDragging) {
      // 檢查是否在任一列表的邊緣 20px 內
      bool handledByList = false;
      
      // 檢查區段列表
      final segmentBox = _segmentListKey.currentContext?.findRenderObject() as RenderBox?;
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
          } else if (relativeY > segmentSize.height - _listScrollEdgeThreshold) {
            // 接近底部
            _startAutoScroll(_segmentListScrollController, scrollUp: false);
            handledByList = true;
          }
        }
      }
      
      // 如果區段列表沒有處理，檢查章節列表
      if (!handledByList) {
        final chapterBox = _chapterListKey.currentContext?.findRenderObject() as RenderBox?;
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
            } else if (relativeY > chapterSize.height - _listScrollEdgeThreshold) {
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
          final newOffset = (currentOffset - _autoScrollSpeed).clamp(minScroll, maxScroll);
          controller.jumpTo(newOffset);
        } else {
          timer.cancel();
          _currentScrollController = null;
        }
      } else {
        // 向下滾動
        if (currentOffset < maxScroll) {
          final newOffset = (currentOffset + _autoScrollSpeed).clamp(minScroll, maxScroll);
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
  
  void _initializeSegments() {
    _segments = List.from(widget.segments.map((seg) => SegmentData(
      segmentName: seg.segmentName,
      chapters: List.from(seg.chapters.map((ch) => ChapterData(
        chapterName: ch.chapterName,
        chapterContent: ch.chapterContent,
        chapterUUID: ch.chapterUUID,
      ))),
      segmentUUID: seg.segmentUUID,
    )));
  }

  void _initializeIfEmpty() {
    if (_segments.isEmpty) {
      _segments.add(SegmentData(
        segmentName: "Seg 1",
        chapters: [ChapterData(chapterName: "Chapter 1", chapterContent: "")],
      ));
      _notifySegmentsChanged();
    } else if (_totalChaptersCount == 0) {
      _segments[0].chapters.add(ChapterData(chapterName: "Chapter 1", chapterContent: ""));
      _notifySegmentsChanged();
    }
  }
  
  // MARK: - Helper：保存/選取
  
  void _commitCurrentEditorToSelectedChapter() {
    final si = _selectedSegmentIndex;
    final cid = widget.selectedChapterID;
    if (si != null && cid != null) {
      final ci = _segments[si].chapters.indexWhere((ch) => ch.chapterUUID == cid);
      if (ci >= 0) {
        _segments[si].chapters[ci].chapterContent = widget.contentText;
      }
    }
  }
  
  void _selectSegment(String segID) {
    _commitCurrentEditorToSelectedChapter();
    widget.onSelectedSegmentChanged?.call(segID);
    
    final si = _segments.indexWhere((seg) => seg.segmentUUID == segID);
    if (si >= 0) {
      if (_segments[si].chapters.isNotEmpty) {
        final firstChapter = _segments[si].chapters.first;
        widget.onSelectedChapterChanged?.call(firstChapter.chapterUUID);
        widget.onContentChanged?.call(firstChapter.chapterContent);
      } else {
        widget.onSelectedChapterChanged?.call(null);
        widget.onContentChanged?.call("");
      }
    }
  }
  
  void _selectChapter(int segIdx, String chapterID) {
    _commitCurrentEditorToSelectedChapter();
    widget.onSelectedSegmentChanged?.call(_segments[segIdx].segmentUUID);
    widget.onSelectedChapterChanged?.call(chapterID);
    
    final chapterIdx = _segments[segIdx].chapters.indexWhere(
      (ch) => ch.chapterUUID == chapterID,
    );
    if (chapterIdx >= 0) {
      widget.onContentChanged?.call(_segments[segIdx].chapters[chapterIdx].chapterContent);
    }
  }

  void _notifySegmentsChanged() {
    widget.onSegmentsChanged?.call(_segments);
  }
  
  // MARK: - 新增方法
  
  void _addSegment() {
    _commitCurrentEditorToSelectedChapter();
    
    final name = _newSegmentName.trim();
    final finalName = name.isEmpty ? "Seg ${_segments.length + 1}" : name;
    final firstChapter = ChapterData(chapterName: "Chapter 1", chapterContent: "");
    final newSegment = SegmentData(
      segmentName: finalName,
      chapters: [firstChapter],
    );
    
    _segments.add(newSegment);
    setState(() {
      _newSegmentName = "";
    });
    _notifySegmentsChanged();
    
    _selectSegment(newSegment.segmentUUID);
  }

  void _addChapter(int segIdx) {
    _commitCurrentEditorToSelectedChapter();
    
    final name = _newChapterName.trim();
    final finalName = name.isEmpty ? "Chapter ${_segments[segIdx].chapters.length + 1}" : name;
    final newChapter = ChapterData(chapterName: finalName, chapterContent: "");
    
    _segments[segIdx].chapters.add(newChapter);
    setState(() {
      _newChapterName = "";
    });
    _notifySegmentsChanged();
    
    _selectChapter(segIdx, newChapter.chapterUUID);
  }

  // MARK: - 刪除方法
  
  void _deleteSegment(String segmentID) {
    final segIdx = _segments.indexWhere((seg) => seg.segmentUUID == segmentID);
    if (segIdx < 0 || _segments.length <= 1) return;
    
    final remainingChapters = _totalChaptersCount - _segments[segIdx].chapters.length;
    if (remainingChapters <= 0) return;
    
    // 如果要刪除的是當前選中的區段，先保存編輯器內容
    if (widget.selectedSegmentID == segmentID) {
      _commitCurrentEditorToSelectedChapter();
    }
    
    _segments.removeAt(segIdx);
    _notifySegmentsChanged();
    
    // 選擇第一個可用的區段
    if (_segments.isNotEmpty) {
      final firstSeg = _segments.first;
      widget.onSelectedSegmentChanged?.call(firstSeg.segmentUUID);
      final firstChapter = firstSeg.chapters.isNotEmpty ? firstSeg.chapters.first : null;
      if (firstChapter != null) {
        widget.onSelectedChapterChanged?.call(firstChapter.chapterUUID);
        widget.onContentChanged?.call(firstChapter.chapterContent);
      } else {
        widget.onSelectedChapterChanged?.call(null);
        widget.onContentChanged?.call("");
      }
    } else {
      widget.onSelectedSegmentChanged?.call(null);
      widget.onSelectedChapterChanged?.call(null);
      widget.onContentChanged?.call("");
    }
  }

  void _deleteChapter(int segIdx, String chapterID) {
    if (segIdx < 0 || segIdx >= _segments.length) return;
    
    final chapterIdx = _segments[segIdx].chapters.indexWhere(
      (ch) => ch.chapterUUID == chapterID,
    );
    if (chapterIdx < 0 || _totalChaptersCount <= 1) return;
    
    // 如果要刪除的是當前選中的章節，先保存編輯器內容
    if (widget.selectedChapterID == chapterID) {
      _commitCurrentEditorToSelectedChapter();
    }
    
    _segments[segIdx].chapters.removeAt(chapterIdx);
    _notifySegmentsChanged();
    
    // 選擇下一個可用章節
    if (_segments[segIdx].chapters.isNotEmpty) {
      final nextIdx = chapterIdx < _segments[segIdx].chapters.length 
          ? chapterIdx 
          : _segments[segIdx].chapters.length - 1;
      final nextChapter = _segments[segIdx].chapters[nextIdx];
      widget.onSelectedChapterChanged?.call(nextChapter.chapterUUID);
      widget.onContentChanged?.call(nextChapter.chapterContent);
    } else {
      widget.onSelectedChapterChanged?.call(null);
      widget.onContentChanged?.call("");
      
      // 如果區段為空且有多個區段，刪除該區段
      if (_segments.length > 1) {
        final removedSegID = _segments[segIdx].segmentUUID;
        _segments.removeAt(segIdx);
        _notifySegmentsChanged();
        
        if (_segments.isNotEmpty) {
          final firstSeg = _segments.first;
          widget.onSelectedSegmentChanged?.call(firstSeg.segmentUUID);
          final firstChapter = firstSeg.chapters.isNotEmpty ? firstSeg.chapters.first : null;
          if (firstChapter != null) {
            widget.onSelectedChapterChanged?.call(firstChapter.chapterUUID);
            widget.onContentChanged?.call(firstChapter.chapterContent);
          } else {
            widget.onSelectedChapterChanged?.call(null);
            widget.onContentChanged?.call("");
          }
        } else {
          widget.onSelectedSegmentChanged?.call(null);
          widget.onSelectedChapterChanged?.call(null);
          widget.onContentChanged?.call("");
        }
        
        // 如果刪除的區段是當前選中的區段，重新選擇
        if (widget.selectedSegmentID == removedSegID && _segments.isNotEmpty) {
          final firstSeg = _segments.first;
          widget.onSelectedSegmentChanged?.call(firstSeg.segmentUUID);
          final firstChapter = firstSeg.chapters.isNotEmpty ? firstSeg.chapters.first : null;
          if (firstChapter != null) {
            widget.onSelectedChapterChanged?.call(firstChapter.chapterUUID);
            widget.onContentChanged?.call(firstChapter.chapterContent);
          }
        }
      }
    }
  }

  // MARK: - 移動/拖放方法
  
  void _moveSegmentByDrag(int fromIndex, int toIndex) {
    if (fromIndex == toIndex) return;
    
    _commitCurrentEditorToSelectedChapter();
    
    final segment = _segments.removeAt(fromIndex);
    _segments.insert(toIndex, segment);
    _notifySegmentsChanged();
  }

  void _moveChapterByDrag(int segIdx, int fromIndex, int toIndex) {
    if (segIdx < 0 || segIdx >= _segments.length) return;
    if (fromIndex == toIndex) return;
    
    _commitCurrentEditorToSelectedChapter();
    
    final chapter = _segments[segIdx].chapters.removeAt(fromIndex);
    _segments[segIdx].chapters.insert(toIndex, chapter);
    _notifySegmentsChanged();
  }

  void _moveChapterToSegment(String chapterUUID, String toSegmentUUID) {
    _commitCurrentEditorToSelectedChapter();
    
    // 找到來源章節
    int? sourceSegIdx;
    int? sourceChapIdx;
    for (int si = 0; si < _segments.length; si++) {
      final ci = _segments[si].chapters.indexWhere((ch) => ch.chapterUUID == chapterUUID);
      if (ci >= 0) {
        sourceSegIdx = si;
        sourceChapIdx = ci;
        break;
      }
    }

    if (sourceSegIdx == null || sourceChapIdx == null) return;

    // 找到目標區段
    final targetSegIdx = _segments.indexWhere((seg) => seg.segmentUUID == toSegmentUUID);
    if (targetSegIdx < 0 || targetSegIdx == sourceSegIdx) return;

    final sourceSegID = _segments[sourceSegIdx].segmentUUID;

    // 執行移動
    final movingChapter = _segments[sourceSegIdx].chapters.removeAt(sourceChapIdx);
    _segments[targetSegIdx].chapters.add(movingChapter);

    // 更新選擇
    widget.onSelectedSegmentChanged?.call(_segments[targetSegIdx].segmentUUID);
    widget.onSelectedChapterChanged?.call(movingChapter.chapterUUID);
    widget.onContentChanged?.call(movingChapter.chapterContent);

    // 如果來源區段變空，刪除它（如果有多個區段）
    if (_segments[sourceSegIdx].chapters.isEmpty && _segments.length > 1) {
      _segments.removeAt(sourceSegIdx);
      
      // 如果刪除的區段是當前選中的區段，重新選擇
      if (widget.selectedSegmentID == sourceSegID) {
        final firstSeg = _segments.firstWhere(
          (seg) => seg.segmentUUID == toSegmentUUID,
          orElse: () => _segments.isNotEmpty ? _segments.first : SegmentData(),
        );
        widget.onSelectedSegmentChanged?.call(firstSeg.segmentUUID);
        widget.onSelectedChapterChanged?.call(movingChapter.chapterUUID);
        widget.onContentChanged?.call(movingChapter.chapterContent);
      }
    }

    _notifySegmentsChanged();
  }



  bool _hasPerformedInitialSetup = false;
  
  @override
  Widget build(BuildContext context) {
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
          _handleDragUpdate(DragUpdateDetails(
            globalPosition: event.position,
            localPosition: event.localPosition,
          ));
        },
        onPointerUp: (_) => _stopAutoScroll(),
        onPointerCancel: (_) => _stopAutoScroll(),
        child: SingleChildScrollView(
          controller: _pageScrollController,
          padding: const EdgeInsets.all(24.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標題
            Row(
              children: [
                Icon(
                  Icons.menu_book,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  "章節選擇",
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
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
                _buildSegmentsList(),
                const SizedBox(height: 24),
                
                // 下方：章節列表
                _buildChaptersList(),
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
    if (_segments.isEmpty) {
      _segments.add(
        SegmentData(
          segmentName: "Seg 1",
          chapters: [ChapterData(chapterName: "Chapter 1", chapterContent: "")],
        ),
      );
    } else if (_totalChaptersCount == 0) {
      _segments[0].chapters.add(ChapterData(chapterName: "Chapter 1", chapterContent: ""));
    }
    
    if (widget.selectedSegmentID == null && _segments.isNotEmpty) {
      widget.onSelectedSegmentChanged?.call(_segments.first.segmentUUID);
    }
    
    if (widget.selectedChapterID == null) {
      final si = _selectedSegmentIndex;
      if (si != null && _segments[si].chapters.isNotEmpty) {
        widget.onSelectedChapterChanged?.call(_segments[si].chapters.first.chapterUUID);
      }
    }
    
    final si = _selectedSegmentIndex;
    final cid = widget.selectedChapterID;
    if (si != null && cid != null) {
      final ci = _segments[si].chapters.indexWhere((ch) => ch.chapterUUID == cid);
      if (ci >= 0) {
        widget.onContentChanged?.call(_segments[si].chapters[ci].chapterContent);
      }
    }
  }

  Widget _buildSegmentsList() {
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
                Icon(
                  Icons.folder_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  "區段選擇",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
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
                  setState(() {
                    final fromIndex = dragData.currentIndex;
                    final toIndex = _segments.length - 1; // 移動到最後
                    
                    if (fromIndex >= 0 && fromIndex < _segments.length && fromIndex != toIndex) {
                      final movedSegment = _segments.removeAt(fromIndex);
                      _segments.insert(toIndex, movedSegment);
                      
                      // 如果移動的區段是當前選中的，更新選中狀態
                      if (widget.selectedSegmentID == movedSegment.segmentUUID) {
                        // selectedSegmentID 不變，因為移動的就是當前選中的區段
                        // 索引會自動通過 getter 重新計算
                      }
                      
                      _notifySegmentsChanged();
                    }
                  });
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
                          : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      width: isHighlighted ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isHighlighted
                        ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1)
                        : null,
                  ),
                  child: ListView.builder(
                    controller: _segmentListScrollController,
                    itemCount: _segments.length,
                    itemBuilder: (context, index) => _buildSegmentItem(_segments[index], index),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            
            // 新增區段
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: _newSegmentName)
                      ..selection = TextSelection.fromPosition(
                        TextPosition(offset: _newSegmentName.length),
                      ),
                    decoration: InputDecoration(
                      hintText: "新增區段名稱",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _newSegmentName = value;
                      });
                    },
                    onSubmitted: (_) => _addSegment(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _addSegment,
                  label: const Text("＋"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChaptersList() {
    final selectedSegIdx = _selectedSegmentIndex;
    
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
                Icon(
                  Icons.article_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  "章節選擇",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
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
                if (selectedSegIdx != null && dragData.type == DragType.chapter) {
                  setState(() {
                    // 找到來源章節
                    ChapterData? draggedChapter;
                    int sourceSegIdx = -1;
                    int sourceChapterIdx = -1;
                    
                    for (int i = 0; i < _segments.length; i++) {
                      final idx = _segments[i].chapters.indexWhere((ch) => ch.chapterUUID == dragData.id);
                      if (idx >= 0) {
                        draggedChapter = _segments[i].chapters[idx];
                        sourceSegIdx = i;
                        sourceChapterIdx = idx;
                        break;
                      }
                    }
                    
                    if (draggedChapter != null) {
                      // 移除來源章節
                      _segments[sourceSegIdx].chapters.removeAt(sourceChapterIdx);
                      
                      // 添加到目標區段的最後
                      _segments[selectedSegIdx].chapters.add(draggedChapter);
                      
                      // 更新選中章節
                      widget.onSelectedChapterChanged?.call(draggedChapter.chapterUUID);
                      _notifySegmentsChanged();
                    }
                  });
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
                          : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      width: isHighlighted ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isHighlighted
                        ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1)
                        : null,
                  ),
                  child: selectedSegIdx != null && selectedSegIdx >= 0
                      ? ListView.builder(
                          controller: _chapterListScrollController,
                          itemCount: _segments[selectedSegIdx].chapters.length,
                          itemBuilder: (context, index) => _buildChapterItem(
                            _segments[selectedSegIdx].chapters[index],
                            selectedSegIdx,
                            index,
                          ),
                        )
                      : Center(
                          child: Text(
                            "請先選擇一個區段",
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                );
              },
            ),
            const SizedBox(height: 16),
            
            // 新增章節
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: _newChapterName)
                      ..selection = TextSelection.fromPosition(
                        TextPosition(offset: _newChapterName.length),
                      ),
                    decoration: InputDecoration(
                      hintText: selectedSegIdx != null ? "新增章節名稱" : "請先選擇區段",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                    ),
                    enabled: selectedSegIdx != null,
                    onChanged: (value) {
                      setState(() {
                        _newChapterName = value;
                      });
                    },
                    onSubmitted: (_) => selectedSegIdx != null ? _addChapter(selectedSegIdx) : null,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: selectedSegIdx != null ? () => _addChapter(selectedSegIdx) : null,
                  label: const Text("＋"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // MARK: - Row builders
  
  Widget _buildSegmentItem(SegmentData segment, int index) {
    final isSelected = widget.selectedSegmentID == segment.segmentUUID;
    final isEditing = _editingSegmentID == segment.segmentUUID;
    
    return LongPressDraggable<DragData>(
      data: DragData(
        id: segment.segmentUUID,
        type: DragType.segment,
        currentIndex: index,
      ),
      onDragStarted: () {
        setState(() {
          _isDragging = true;
        });
      },
      onDragEnd: (_) {
        setState(() {
          _isDragging = false;
        });
        _stopAutoScroll();
      },
      onDraggableCanceled: (_, __) {
        setState(() {
          _isDragging = false;
        });
        _stopAutoScroll();
      },
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.secondary,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.folder_outlined,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  segment.segmentName.isEmpty ? "(未命名 Seg)" : segment.segmentName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildSegmentListTile(segment, index, isSelected, isEditing),
      ),
      child: DragTarget<DragData>(
        onWillAcceptWithDetails: (details) {
          final dragData = details.data;
          if (dragData.type == DragType.segment) {
            // 區段排序：不能拖到自己上面
            return dragData.currentIndex != index;
          } else {
            // 章節移動：總是接受
            return true;
          }
        },
        onAcceptWithDetails: (details) {
          final dragData = details.data;
          if (dragData.type == DragType.segment) {
            // 區段排序
            _moveSegmentByDrag(dragData.currentIndex, index);
          } else {
            // 章節移動到此區段
            _moveChapterToSegment(dragData.id, segment.segmentUUID);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("章節已移動到「${segment.segmentName}」"),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isHighlighted = candidateData.isNotEmpty;
          return Container(
            key: ValueKey(segment.segmentUUID),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                  : (isHighlighted 
                      ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)
                      : Colors.transparent),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                ),
              ),
              borderRadius: isHighlighted ? BorderRadius.circular(8) : null,
            ),
            child: _buildSegmentListTile(segment, index, isSelected, isEditing),
          );
        },
      ),
    );
  }
  
  Widget _buildSegmentListTile(SegmentData segment, int index, bool isSelected, bool isEditing) {
    return ListTile(
      title: isEditing
          ? TextField(
              controller: TextEditingController(text: segment.segmentName)
                ..selection = TextSelection.fromPosition(
                  TextPosition(offset: segment.segmentName.length),
                ),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onSubmitted: (value) {
                setState(() {
                  _segments[index].segmentName = value.trim().isEmpty 
                      ? "(未命名 Seg)" 
                      : value.trim();
                  _editingSegmentID = null;
                });
                _notifySegmentsChanged();
              },
              onEditingComplete: () {
                setState(() {
                  _editingSegmentID = null;
                });
              },
            )
          : GestureDetector(
              onDoubleTap: () {
                setState(() {
                  _editingSegmentID = segment.segmentUUID;
                });
              },
              child: Text(
                segment.segmentName.isEmpty ? "(未命名 Seg)" : segment.segmentName,
                style: isSelected
                    ? TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
              ),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: () {
              setState(() {
                _editingSegmentID = segment.segmentUUID;
              });
            },
            tooltip: "重新命名",
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 20),
            color: Theme.of(context).colorScheme.error,
            onPressed: _segments.length > 1 ? () => _deleteSegment(segment.segmentUUID) : null,
            tooltip: "刪除此 Seg",
          ),
        ],
      ),
      onTap: () => _selectSegment(segment.segmentUUID),
    );
  }

  Widget _buildChapterItem(ChapterData chapter, int segIdx, int chapterIdx) {
    final isSelected = widget.selectedChapterID == chapter.chapterUUID;
    final isEditing = _editingChapterID == chapter.chapterUUID;
    
    return LongPressDraggable<DragData>(
      // 使用 LongPressDraggable 統一處理拖放
      data: DragData(
        id: chapter.chapterUUID,
        type: DragType.chapter,
        currentIndex: chapterIdx,
      ),
      onDragStarted: () {
        setState(() {
          _isDragging = true;
        });
      },
      onDragEnd: (_) {
        setState(() {
          _isDragging = false;
        });
        _stopAutoScroll();
      },
      onDraggableCanceled: (_, __) {
        setState(() {
          _isDragging = false;
        });
        _stopAutoScroll();
      },
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.article_outlined, 
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      chapter.chapterName.isEmpty ? "(未命名 Chapter)" : chapter.chapterName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${chapter.chapterWordsCount} 字",
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildChapterListTile(chapter, segIdx, chapterIdx, isSelected, isEditing),
      ),
      child: DragTarget<DragData>(
        onWillAcceptWithDetails: (details) {
          final dragData = details.data;
          if (dragData.type == DragType.chapter) {
            // 章節排序：不能拖到自己上面
            return dragData.currentIndex != chapterIdx;
          }
          return false; // 不接受區段拖到章節上
        },
        onAcceptWithDetails: (details) {
          final dragData = details.data;
          if (dragData.type == DragType.chapter) {
            // 章節排序 - 在同一區段內移動
            _moveChapterByDrag(segIdx, dragData.currentIndex, chapterIdx);
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isHighlighted = candidateData.isNotEmpty;
          return Container(
            key: ValueKey(chapter.chapterUUID),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                  : (isHighlighted
                      ? Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.5)
                      : Colors.transparent),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                ),
              ),
              borderRadius: isHighlighted ? BorderRadius.circular(8) : null,
            ),
            child: _buildChapterListTile(chapter, segIdx, chapterIdx, isSelected, isEditing),
          );
        },
      ),
    );
  }
  
  Widget _buildChapterListTile(ChapterData chapter, int segIdx, int chapterIdx, bool isSelected, bool isEditing) {
    return ListTile(
      title: isEditing
          ? TextField(
              controller: TextEditingController(text: chapter.chapterName)
                ..selection = TextSelection.fromPosition(
                  TextPosition(offset: chapter.chapterName.length),
                ),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onSubmitted: (value) {
                setState(() {
                  _segments[segIdx].chapters[chapterIdx].chapterName = value.trim().isEmpty 
                      ? "(未命名 Chapter)" 
                      : value.trim();
                  _editingChapterID = null;
                });
                _notifySegmentsChanged();
              },
              onEditingComplete: () {
                setState(() {
                  _editingChapterID = null;
                });
              },
            )
          : GestureDetector(
              onDoubleTap: () {
                setState(() {
                  _editingChapterID = chapter.chapterUUID;
                });
              },
              child: Text(
                chapter.chapterName.isEmpty ? "(未命名 Chapter)" : chapter.chapterName,
                style: isSelected
                    ? TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
              ),
            ),
      subtitle: Text(
        "${chapter.chapterWordsCount} 字",
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: () {
              setState(() {
                _editingChapterID = chapter.chapterUUID;
              });
            },
            tooltip: "重新命名",
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 20),
            color: Theme.of(context).colorScheme.error,
            onPressed: _totalChaptersCount > 1 ? () => _deleteChapter(segIdx, chapter.chapterUUID) : null,
            tooltip: "刪除此章節",
          ),
        ],
      ),
      onTap: () => _selectChapter(segIdx, chapter.chapterUUID),
    );
  }
}