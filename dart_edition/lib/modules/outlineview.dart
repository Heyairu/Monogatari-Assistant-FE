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
import "dart:async";
import "package:xml/xml.dart" as xml;
import "../bin/ui_library.dart";
import "package:logging/logging.dart";

final _log = Logger("OutlineView");

// MARK: - 拖放數據類型

class OutlineDragData {
  final String id;
  final OutlineDragType type;
  final int currentIndex;
  
  OutlineDragData({
    required this.id,
    required this.type,
    required this.currentIndex,
  });
}

enum OutlineDragType {
  storyline,
  event,
  scene,
}

// MARK: - 資料結構

// 大箱（故事線）
class StorylineData {
  String storylineName;
  String storylineType;
  List<StoryEventData> scenes; // 中箱（事件序列）
  String memo;
  String conflictPoint; // 衝突點
  List<String> people; // 人物
  List<String> item;   // 物件
  String chapterUUID;

  StorylineData({
    this.storylineName = "",
    this.storylineType = "",
    List<StoryEventData>? scenes,
    this.memo = "",
    this.conflictPoint = "",
    List<String>? people,
    List<String>? item,
    String? chapterUUID,
  }) : scenes = scenes ?? [],
       people = people ?? [],
       item = item ?? [],
       chapterUUID = chapterUUID ?? DateTime.now().millisecondsSinceEpoch.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StorylineData &&
          runtimeType == other.runtimeType &&
          chapterUUID == other.chapterUUID;

  @override
  int get hashCode => chapterUUID.hashCode;
}

// 中箱（事件序列）
class StoryEventData {
  String storyEvent;
  List<SceneData> scenes; // 小箱（場景）
  String memo;
  String conflictPoint; // 衝突點
  List<String> people; // 人物
  List<String> item;   // 物件
  String storyEventUUID;

  StoryEventData({
    this.storyEvent = "",
    List<SceneData>? scenes,
    this.memo = "",
    this.conflictPoint = "",
    List<String>? people,
    List<String>? item,
    String? storyEventUUID,
  }) : scenes = scenes ?? [],
       people = people ?? [],
       item = item ?? [],
       storyEventUUID = storyEventUUID ?? DateTime.now().millisecondsSinceEpoch.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryEventData &&
          runtimeType == other.runtimeType &&
          storyEventUUID == other.storyEventUUID;

  @override
  int get hashCode => storyEventUUID.hashCode;
}

// 小箱（場景）
class SceneData {
  String sceneName;
  String time;
  String location;
  String focusPoint; // 聚焦點
  String conflictPoint; // 衝突點
  List<String> people;
  List<String> item;
  List<String> doingThings;
  String memo;
  String sceneUUID;

  SceneData({
    this.sceneName = "",
    this.time = "",
    this.location = "",
    this.focusPoint = "",
    this.conflictPoint = "",
    List<String>? people,
    List<String>? item,
    List<String>? doingThings,
    this.memo = "",
    String? sceneUUID,
  }) : people = people ?? [],
       item = item ?? [],
       doingThings = doingThings ?? [],
       sceneUUID = sceneUUID ?? DateTime.now().millisecondsSinceEpoch.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SceneData &&
          runtimeType == other.runtimeType &&
          sceneUUID == other.sceneUUID;

  @override
  int get hashCode => sceneUUID.hashCode;
}

// MARK: - 拖放識別字串
class DragPayload {
  static const String eventPrefix = "EVENT:";
  static const String scenePrefix = "SCENE:";
  
  static String eventString(String id) => eventPrefix + id;
  static String sceneString(String id) => scenePrefix + id;
}

// MARK: - XML Codec for Outline
class OutlineCodec {
  static void _writeTextElement(xml.XmlBuilder builder, String name, String value) {
    builder.element(name, nest: () {
      builder.text(_encodeNewlines(value));
    });
  }

  static String _readElementText(xml.XmlElement? element) {
    if (element == null) return "";
    if (element.children.isEmpty) {
      return _decodeNewlines(element.innerText);
    }
    final cdataBuffer = StringBuffer();
    for (final node in element.children) {
      if (node is xml.XmlCDATA) {
        cdataBuffer.write(node.value);
      }
    }
    final cdataText = cdataBuffer.toString();
    if (cdataText.isNotEmpty) {
      return _decodeNewlines(cdataText);
    }
    final buffer = StringBuffer();
    for (final node in element.children) {
      if (node is xml.XmlText || node is xml.XmlCDATA) {
        buffer.write(node.value);
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

  static String? saveXML(List<StorylineData> storylines) {
    if (storylines.isEmpty) return null;
    
    final builder = xml.XmlBuilder();
    builder.element("Type", nest: () {
      builder.element("Name", nest: "Outline");
      
      for (final sl in storylines) {
        builder.element("Storyline", attributes: {
          "Name": sl.storylineName,
          "Type": sl.storylineType,
          "UUID": sl.chapterUUID,
        }, nest: () {
          if (sl.memo.isNotEmpty) {
            _writeTextElement(builder, "Memo", sl.memo);
          }
          if (sl.conflictPoint.isNotEmpty) {
            _writeTextElement(builder, "ConflictPoint", sl.conflictPoint);
          }
          if (sl.people.isNotEmpty) {
            builder.element("People", nest: () {
              for (final p in sl.people) {
                _writeTextElement(builder, "Person", p);
              }
            });
          }
          if (sl.item.isNotEmpty) {
            builder.element("Items", nest: () {
              for (final it in sl.item) {
                _writeTextElement(builder, "Item", it);
              }
            });
          }
          
          for (final ev in sl.scenes) {
            builder.element("Event", attributes: {
              "Name": ev.storyEvent,
              "UUID": ev.storyEventUUID,
            }, nest: () {
              if (ev.memo.isNotEmpty) {
                _writeTextElement(builder, "Memo", ev.memo);
              }
              if (ev.conflictPoint.isNotEmpty) {
                _writeTextElement(builder, "ConflictPoint", ev.conflictPoint);
              }
              if (ev.people.isNotEmpty) {
                builder.element("People", nest: () {
                  for (final p in ev.people) {
                    _writeTextElement(builder, "Person", p);
                  }
                });
              }
              if (ev.item.isNotEmpty) {
                builder.element("Items", nest: () {
                  for (final it in ev.item) {
                    _writeTextElement(builder, "Item", it);
                  }
                });
              }
              
              for (final sc in ev.scenes) {
                builder.element("Scene", attributes: {
                  "Name": sc.sceneName,
                  "UUID": sc.sceneUUID,
                }, nest: () {
                  if (sc.time.isNotEmpty) {
                    _writeTextElement(builder, "Time", sc.time);
                  }
                  if (sc.location.isNotEmpty) {
                    _writeTextElement(builder, "Location", sc.location);
                  }
                  if (sc.focusPoint.isNotEmpty) {
                    _writeTextElement(builder, "FocusPoint", sc.focusPoint);
                  }
                  if (sc.conflictPoint.isNotEmpty) {
                    _writeTextElement(builder, "ConflictPoint", sc.conflictPoint);
                  }
                  if (sc.people.isNotEmpty) {
                    builder.element("People", nest: () {
                      for (final p in sc.people) {
                        _writeTextElement(builder, "Person", p);
                      }
                    });
                  }
                  if (sc.item.isNotEmpty) {
                    builder.element("Items", nest: () {
                      for (final it in sc.item) {
                        _writeTextElement(builder, "Item", it);
                      }
                    });
                  }
                  if (sc.doingThings.isNotEmpty) {
                    builder.element("Doings", nest: () {
                      for (final d in sc.doingThings) {
                        _writeTextElement(builder, "Doing", d);
                      }
                    });
                  }
                  if (sc.memo.isNotEmpty) {
                    _writeTextElement(builder, "Memo", sc.memo);
                  }
                });
              }
            });
          }
        });
      }
    });

    return builder.buildDocument().toXmlString(pretty: true, indent: "  ");
  }

  static List<StorylineData>? loadXML(String content) {
    try {
      final document = xml.XmlDocument.parse(content);
      
      final typeElement = document.findAllElements("Type").firstOrNull;
      if (typeElement == null) return null;

      final nameElement = typeElement.findAllElements("Name").firstOrNull;
      if (nameElement?.innerText != "Outline") return null;
      
      final storylines = <StorylineData>[];
      
      for (final storylineNode in typeElement.findAllElements("Storyline")) {
        final storylineName = storylineNode.getAttribute("Name") ?? "";
        final storylineType = storylineNode.getAttribute("Type") ?? "";
        final storylineUUID = storylineNode.getAttribute("UUID") ?? DateTime.now().millisecondsSinceEpoch.toString();
        
        final storyline = StorylineData(
          storylineName: storylineName,
          storylineType: storylineType,
          chapterUUID: storylineUUID,
          scenes: [],
          people: [],
          item: [],
          memo: "",
          conflictPoint: "",
        );
        
        // Parse Memo
        storyline.memo = _readElementText(storylineNode.findAllElements("Memo").firstOrNull);
        
        // Parse ConflictPoint
        storyline.conflictPoint = _readElementText(storylineNode.findAllElements("ConflictPoint").firstOrNull);
        
        // Parse People
        final peopleNode = storylineNode.findAllElements("People").firstOrNull;
        if (peopleNode != null) {
          for (final personNode in peopleNode.findAllElements("Person")) {
            final person = _readElementText(personNode).trim();
            if (person.isNotEmpty) storyline.people.add(person);
          }
        }
        
        // Parse Items
        final itemsNode = storylineNode.findAllElements("Items").firstOrNull;
        if (itemsNode != null) {
          for (final itemNode in itemsNode.findAllElements("Item")) {
            final item = _readElementText(itemNode).trim();
            if (item.isNotEmpty) storyline.item.add(item);
          }
        }
        
        // Parse Events (direct children with name "Event")
        // We use .children instead of .findAllElements to detect direct structure if hierarchy matters
        // But here simpler find works as Event is inside Storyline
        
        // Be careful not to find nested Events if they existed (not in this schema)
        // findAllElements finds descendants. We should use .findElements for direct children if appropriate.
        // In the builder structure: Type -> Storyline -> Event -> Scene
        // So safe to use findAllElements inside storylineNode but "Event" is also a common word.
        // It is safer to use direct child iteration or ensure scope.
        // storylineNode.findElements("Event") is safer.
        
        for (final eventNode in storylineNode.findElements("Event")) {
          final eventName = eventNode.getAttribute("Name") ?? "";
          final eventUUID = eventNode.getAttribute("UUID") ?? DateTime.now().millisecondsSinceEpoch.toString();
          
          final event = StoryEventData(
            storyEvent: eventName,
            storyEventUUID: eventUUID,
            scenes: [],
            people: [],
            item: [],
            memo: "",
            conflictPoint: "",
          );
          
          event.memo = _readElementText(eventNode.findAllElements("Memo").firstOrNull);
          event.conflictPoint = _readElementText(eventNode.findAllElements("ConflictPoint").firstOrNull);
          
          final eventPeopleNode = eventNode.findAllElements("People").firstOrNull;
          if (eventPeopleNode != null) {
            for (final p in eventPeopleNode.findAllElements("Person")) {
              final person = _readElementText(p).trim();
              if (person.isNotEmpty) event.people.add(person);
            }
          }
          
          final eventItemsNode = eventNode.findAllElements("Items").firstOrNull;
          if (eventItemsNode != null) {
            for (final it in eventItemsNode.findAllElements("Item")) {
              final item = _readElementText(it).trim();
              if (item.isNotEmpty) event.item.add(item);
            }
          }
          
          // Parse Scenes
          for (final sceneNode in eventNode.findElements("Scene")) {
            final sceneName = sceneNode.getAttribute("Name") ?? "";
            final sceneUUID = sceneNode.getAttribute("UUID") ?? DateTime.now().millisecondsSinceEpoch.toString();
            
            final scene = SceneData(
              sceneName: sceneName,
              sceneUUID: sceneUUID,
              people: [],
              item: [],
              doingThings: [],
              time: "",
              location: "",
              focusPoint: "",
              conflictPoint: "",
              memo: "",
            );
            
            scene.time = _readElementText(sceneNode.findAllElements("Time").firstOrNull);
            scene.location = _readElementText(sceneNode.findAllElements("Location").firstOrNull);
            scene.focusPoint = _readElementText(sceneNode.findAllElements("FocusPoint").firstOrNull);
            scene.conflictPoint = _readElementText(sceneNode.findAllElements("ConflictPoint").firstOrNull);
            scene.memo = _readElementText(sceneNode.findAllElements("Memo").firstOrNull);
            
            final scenePeopleNode = sceneNode.findAllElements("People").firstOrNull;
            if (scenePeopleNode != null) {
              for (final p in scenePeopleNode.findAllElements("Person")) {
                final person = _readElementText(p).trim();
                if (person.isNotEmpty) scene.people.add(person);
              }
            }
            
            final sceneItemsNode = sceneNode.findAllElements("Items").firstOrNull;
            if (sceneItemsNode != null) {
              for (final it in sceneItemsNode.findAllElements("Item")) {
                final item = _readElementText(it).trim();
                if (item.isNotEmpty) scene.item.add(item);
              }
            }
            
            final doingsNode = sceneNode.findAllElements("Doings").firstOrNull;
            if (doingsNode != null) {
              for (final d in doingsNode.findAllElements("Doing")) {
                final doing = _readElementText(d).trim();
                if (doing.isNotEmpty) scene.doingThings.add(doing);
              }
            }
            
            event.scenes.add(scene);
          }
          
          storyline.scenes.add(event);
        }
        
        storylines.add(storyline);
      }
      
      return storylines.isEmpty ? null : storylines;
    } catch (e) {
      _log.severe("Error parsing Outline XML: $e");
      return null;
    }
  }
}

// MARK: - OutlineAdjustView
class OutlineAdjustView extends StatefulWidget {
  final List<StorylineData> storylines;
  final ValueChanged<List<StorylineData>> onStorylineChanged;

  const OutlineAdjustView({
    super.key,
    required this.storylines,
    required this.onStorylineChanged,
  });

  @override
  State<OutlineAdjustView> createState() => _OutlineAdjustViewState();
}

class _OutlineAdjustViewState extends State<OutlineAdjustView> {
  String? selectedStorylineID;
  String? selectedEventID;
  String? selectedSceneID;

  String? editingStorylineID;
  String? editingEventID;
  String? editingSceneID;

  final TextEditingController newStorylineController = TextEditingController();
  final TextEditingController newEventController = TextEditingController();
  final TextEditingController newSceneController = TextEditingController();
  
  // 備註欄位控制器
  final TextEditingController storylineMemoController = TextEditingController();
  final TextEditingController eventMemoController = TextEditingController();
  final TextEditingController sceneMemoController = TextEditingController();
  
  // 故事線細節編輯控制器
  final TextEditingController storylineNameController = TextEditingController();
  final TextEditingController storylineTypeController = TextEditingController();
  final TextEditingController storylineConflictController = TextEditingController();
  
  // 事件細節編輯控制器
  final TextEditingController eventNameController = TextEditingController();
  final TextEditingController eventConflictController = TextEditingController();
  
  // 場景細節編輯控制器
  final TextEditingController sceneNameController = TextEditingController();
  final TextEditingController sceneTimeController = TextEditingController();
  final TextEditingController sceneLocationController = TextEditingController();
  final TextEditingController sceneFocusController = TextEditingController();
  final TextEditingController sceneConflictController = TextEditingController();

  // 拖動相關狀態
  bool _isDragging = false;
  OutlineDragData? _currentDragData; // 新增
  TextEditingController? _renameListController; // 新增
  Timer? _autoScrollTimer;
  ScrollController? _currentScrollController;
  final ScrollController _pageScrollController = ScrollController();
  final ScrollController _storylineListScrollController = ScrollController();
  final ScrollController _eventListScrollController = ScrollController();
  final ScrollController _sceneListScrollController = ScrollController();
  
  // 列表容器的 GlobalKey
  final GlobalKey _storylineListKey = GlobalKey();
  final GlobalKey _eventListKey = GlobalKey();
  final GlobalKey _sceneListKey = GlobalKey();
  
  // 自動滾動相關常數
  static const double _autoScrollSpeed = 10.0;
  static const Duration _autoScrollInterval = Duration(milliseconds: 50);
  static const double _scrollEdgeThreshold = 100.0;
  static const double _listScrollEdgeThreshold = 20.0;

  List<StorylineData> get storylines => widget.storylines;

  int? get selectedStorylineIndex {
    if (selectedStorylineID == null) return null;
    return storylines.indexWhere((sl) => sl.chapterUUID == selectedStorylineID);
  }

  int? get selectedEventIndex {
    final si = selectedStorylineIndex;
    if (si == null || selectedEventID == null) return null;
    return storylines[si].scenes.indexWhere((ev) => ev.storyEventUUID == selectedEventID);
  }

  int? get selectedSceneIndex {
    final si = selectedStorylineIndex;
    final ei = selectedEventIndex;
    if (si == null || ei == null || selectedSceneID == null) return null;
    return storylines[si].scenes[ei].scenes.indexWhere((sc) => sc.sceneUUID == selectedSceneID);
  }

  @override
  void initState() {
    super.initState();
    _initializeSelection();
    
    // Add listeners
    storylineNameController.addListener(_onStorylineNameChanged);
    storylineTypeController.addListener(_onStorylineTypeChanged);
    storylineConflictController.addListener(_onStorylineConflictChanged);
    storylineMemoController.addListener(_onStorylineMemoChanged);
    
    eventNameController.addListener(_onEventNameChanged);
    eventConflictController.addListener(_onEventConflictChanged);
    eventMemoController.addListener(_onEventMemoChanged);
    
    sceneNameController.addListener(_onSceneNameChanged);
    sceneTimeController.addListener(_onSceneTimeChanged);
    sceneLocationController.addListener(_onSceneLocationChanged);
    sceneFocusController.addListener(_onSceneFocusChanged);
    sceneConflictController.addListener(_onSceneConflictChanged);
    sceneMemoController.addListener(_onSceneMemoChanged);
  }
  
  void _onStorylineNameChanged() {
    final si = selectedStorylineIndex;
    if (si != null && si >= 0 && si < storylines.length) {
      final storyline = storylines[si];
      if (storyline.storylineName != storylineNameController.text) {
        storyline.storylineName = storylineNameController.text;
        _notifyChange();
        setState(() {}); // Trigger rebuild to update list item title
      }
    }
  }

  void _onStorylineTypeChanged() {
    final si = selectedStorylineIndex;
    if (si != null) {
      if (storylines[si].storylineType != storylineTypeController.text) {
        storylines[si].storylineType = storylineTypeController.text;
        _notifyChange();
      }
    }
  }

  void _onStorylineConflictChanged() {
    final si = selectedStorylineIndex;
    if (si != null) {
      if (storylines[si].conflictPoint != storylineConflictController.text) {
        storylines[si].conflictPoint = storylineConflictController.text;
        _notifyChange();
      }
    }
  }

  void _onStorylineMemoChanged() {
    final si = selectedStorylineIndex;
    if (si != null) {
      if (storylines[si].memo != storylineMemoController.text) {
        storylines[si].memo = storylineMemoController.text;
        _notifyChange();
      }
    }
  }

  void _onEventNameChanged() {
    final si = selectedStorylineIndex;
    final ei = selectedEventIndex;
    if (si != null && ei != null) {
      final event = storylines[si].scenes[ei];
      if (event.storyEvent != eventNameController.text) {
        event.storyEvent = eventNameController.text;
        _notifyChange();
        setState(() {});
      }
    }
  }

  void _onEventConflictChanged() {
    final si = selectedStorylineIndex;
    final ei = selectedEventIndex;
    if (si != null && ei != null) {
      if (storylines[si].scenes[ei].conflictPoint != eventConflictController.text) {
        storylines[si].scenes[ei].conflictPoint = eventConflictController.text;
        _notifyChange();
      }
    }
  }

  void _onEventMemoChanged() {
    final si = selectedStorylineIndex;
    final ei = selectedEventIndex;
    if (si != null && ei != null) {
      if (storylines[si].scenes[ei].memo != eventMemoController.text) {
        storylines[si].scenes[ei].memo = eventMemoController.text;
        _notifyChange();
      }
    }
  }

  void _onSceneNameChanged() {
    final si = selectedStorylineIndex;
    final ei = selectedEventIndex;
    final ci = selectedSceneIndex;
    if (si != null && ei != null && ci != null) {
      final scene = storylines[si].scenes[ei].scenes[ci];
      if (scene.sceneName != sceneNameController.text) {
        scene.sceneName = sceneNameController.text;
        _notifyChange();
        setState(() {});
      }
    }
  }

  void _onSceneTimeChanged() {
    final si = selectedStorylineIndex;
    final ei = selectedEventIndex;
    final ci = selectedSceneIndex;
    if (si != null && ei != null && ci != null) {
      if (storylines[si].scenes[ei].scenes[ci].time != sceneTimeController.text) {
        storylines[si].scenes[ei].scenes[ci].time = sceneTimeController.text;
        _notifyChange();
      }
    }
  }

  void _onSceneLocationChanged() {
    final si = selectedStorylineIndex;
    final ei = selectedEventIndex;
    final ci = selectedSceneIndex;
    if (si != null && ei != null && ci != null) {
      if (storylines[si].scenes[ei].scenes[ci].location != sceneLocationController.text) {
        storylines[si].scenes[ei].scenes[ci].location = sceneLocationController.text;
        _notifyChange();
      }
    }
  }

  void _onSceneFocusChanged() {
    final si = selectedStorylineIndex;
    final ei = selectedEventIndex;
    final ci = selectedSceneIndex;
    if (si != null && ei != null && ci != null) {
      if (storylines[si].scenes[ei].scenes[ci].focusPoint != sceneFocusController.text) {
        storylines[si].scenes[ei].scenes[ci].focusPoint = sceneFocusController.text;
        _notifyChange();
      }
    }
  }

  void _onSceneConflictChanged() {
    final si = selectedStorylineIndex;
    final ei = selectedEventIndex;
    final ci = selectedSceneIndex;
    if (si != null && ei != null && ci != null) {
      if (storylines[si].scenes[ei].scenes[ci].conflictPoint != sceneConflictController.text) {
        storylines[si].scenes[ei].scenes[ci].conflictPoint = sceneConflictController.text;
        _notifyChange();
      }
    }
  }

  void _onSceneMemoChanged() {
    final si = selectedStorylineIndex;
    final ei = selectedEventIndex;
    final ci = selectedSceneIndex;
    if (si != null && ei != null && ci != null) {
      if (storylines[si].scenes[ei].scenes[ci].memo != sceneMemoController.text) {
        storylines[si].scenes[ei].scenes[ci].memo = sceneMemoController.text;
        _notifyChange();
      }
    }
  }

  @override
  void didUpdateWidget(OutlineAdjustView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 當外部數據更新時，重新初始化選擇
    if (widget.storylines != oldWidget.storylines) {
      _initializeSelection();
    }
  }

  @override
  void dispose() {
    storylineNameController.removeListener(_onStorylineNameChanged);
    storylineTypeController.removeListener(_onStorylineTypeChanged);
    storylineConflictController.removeListener(_onStorylineConflictChanged);
    storylineMemoController.removeListener(_onStorylineMemoChanged);
    eventNameController.removeListener(_onEventNameChanged);
    eventConflictController.removeListener(_onEventConflictChanged);
    eventMemoController.removeListener(_onEventMemoChanged);
    sceneNameController.removeListener(_onSceneNameChanged);
    sceneTimeController.removeListener(_onSceneTimeChanged);
    sceneLocationController.removeListener(_onSceneLocationChanged);
    sceneFocusController.removeListener(_onSceneFocusChanged);
    sceneConflictController.removeListener(_onSceneConflictChanged);
    sceneMemoController.removeListener(_onSceneMemoChanged);

    newStorylineController.dispose();
    newEventController.dispose();
    newSceneController.dispose();
    storylineMemoController.dispose();
    eventMemoController.dispose();
    sceneMemoController.dispose();
    storylineNameController.dispose();
    storylineTypeController.dispose();
    storylineConflictController.dispose();
    eventNameController.dispose();
    eventConflictController.dispose();
    sceneNameController.dispose();
    sceneTimeController.dispose();
    sceneLocationController.dispose();
    sceneFocusController.dispose();
    sceneConflictController.dispose();
    
    // 釋放拖動相關控制器
    _autoScrollTimer?.cancel();
    _pageScrollController.dispose();
    _storylineListScrollController.dispose();
    _eventListScrollController.dispose();
    _sceneListScrollController.dispose();
    super.dispose();
  }

  void _initializeSelection() {
    // 清空無效的選擇
    if (storylines.isEmpty) {
      selectedStorylineID = null;
      selectedEventID = null;
      selectedSceneID = null;
      _syncAllControllers();
      return;
    }
    
    // 如果當前選擇的故事線不存在，選擇第一個
    if (selectedStorylineID == null || !storylines.any((sl) => sl.chapterUUID == selectedStorylineID)) {
      selectedStorylineID = storylines.first.chapterUUID;
      selectedEventID = null;
      selectedSceneID = null;
    }
    
    final si = selectedStorylineIndex;
    if (si != null && si >= 0 && si < storylines.length) {
      // 檢查選擇的事件是否還存在
      if (selectedEventID == null || !storylines[si].scenes.any((ev) => ev.storyEventUUID == selectedEventID)) {
        selectedEventID = storylines[si].scenes.isNotEmpty ? storylines[si].scenes.first.storyEventUUID : null;
        selectedSceneID = null;
      }
      
      final ei = selectedEventIndex;
      if (ei != null && ei >= 0 && ei < storylines[si].scenes.length) {
        // 檢查選擇的場景是否還存在
        if (selectedSceneID == null || !storylines[si].scenes[ei].scenes.any((sc) => sc.sceneUUID == selectedSceneID)) {
          selectedSceneID = storylines[si].scenes[ei].scenes.isNotEmpty ? storylines[si].scenes[ei].scenes.first.sceneUUID : null;
        }
      } else {
        selectedSceneID = null;
      }
    } else {
      selectedEventID = null;
      selectedSceneID = null;
    }
    
    _syncAllControllers();
  }
  
  void _syncAllControllers() {
    final si = selectedStorylineIndex;
    if (si != null && si >= 0 && si < storylines.length) {
      final storyline = storylines[si];
      storylineMemoController.text = storyline.memo;
      storylineNameController.text = storyline.storylineName;
      storylineTypeController.text = storyline.storylineType;
      storylineConflictController.text = storyline.conflictPoint;
      
      final ei = selectedEventIndex;
      if (ei != null && ei >= 0 && ei < storylines[si].scenes.length) {
        final event = storylines[si].scenes[ei];
        eventMemoController.text = event.memo;
        eventNameController.text = event.storyEvent;
        eventConflictController.text = event.conflictPoint;
        
        final ci = selectedSceneIndex;
        if (ci != null && ci >= 0 && ci < storylines[si].scenes[ei].scenes.length) {
          final scene = storylines[si].scenes[ei].scenes[ci];
          sceneMemoController.text = scene.memo;
          sceneNameController.text = scene.sceneName;
          sceneTimeController.text = scene.time;
          sceneLocationController.text = scene.location;
          sceneFocusController.text = scene.focusPoint;
          sceneConflictController.text = scene.conflictPoint;
        } else {
          sceneMemoController.clear();
          sceneNameController.clear();
          sceneTimeController.clear();
          sceneLocationController.clear();
          sceneFocusController.clear();
          sceneConflictController.clear();
        }
      } else {
        eventMemoController.clear();
        eventNameController.clear();
        eventConflictController.clear();
        sceneMemoController.clear();
        sceneNameController.clear();
        sceneTimeController.clear();
        sceneLocationController.clear();
        sceneFocusController.clear();
        sceneConflictController.clear();
      }
    } else {
      storylineMemoController.clear();
      storylineNameController.clear();
      storylineTypeController.clear();
      storylineConflictController.clear();
      eventMemoController.clear();
      eventNameController.clear();
      eventConflictController.clear();
      sceneMemoController.clear();
      sceneNameController.clear();
      sceneTimeController.clear();
      sceneLocationController.clear();
      sceneFocusController.clear();
      sceneConflictController.clear();
    }
  }

  void _notifyChange() {
    widget.onStorylineChanged(storylines);
  }

  // MARK: - 自動滾動方法
  
  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isDragging) {
      bool handledByList = false;
      
      // 檢查故事線列表
      final storylineBox = _storylineListKey.currentContext?.findRenderObject() as RenderBox?;
      if (storylineBox != null) {
        final storylinePosition = storylineBox.localToGlobal(Offset.zero);
        final storylineSize = storylineBox.size;
        final relativeY = details.globalPosition.dy - storylinePosition.dy;
        
        if (relativeY >= 0 && relativeY <= storylineSize.height) {
          if (relativeY < _listScrollEdgeThreshold) {
            _startAutoScroll(_storylineListScrollController, scrollUp: true);
            handledByList = true;
          } else if (relativeY > storylineSize.height - _listScrollEdgeThreshold) {
            _startAutoScroll(_storylineListScrollController, scrollUp: false);
            handledByList = true;
          }
        }
      }
      
      // 檢查事件列表
      if (!handledByList) {
        final eventBox = _eventListKey.currentContext?.findRenderObject() as RenderBox?;
        if (eventBox != null) {
          final eventPosition = eventBox.localToGlobal(Offset.zero);
          final eventSize = eventBox.size;
          final relativeY = details.globalPosition.dy - eventPosition.dy;
          
          if (relativeY >= 0 && relativeY <= eventSize.height) {
            if (relativeY < _listScrollEdgeThreshold) {
              _startAutoScroll(_eventListScrollController, scrollUp: true);
              handledByList = true;
            } else if (relativeY > eventSize.height - _listScrollEdgeThreshold) {
              _startAutoScroll(_eventListScrollController, scrollUp: false);
              handledByList = true;
            }
          }
        }
      }
      
      // 檢查場景列表
      if (!handledByList) {
        final sceneBox = _sceneListKey.currentContext?.findRenderObject() as RenderBox?;
        if (sceneBox != null) {
          final scenePosition = sceneBox.localToGlobal(Offset.zero);
          final sceneSize = sceneBox.size;
          final relativeY = details.globalPosition.dy - scenePosition.dy;
          
          if (relativeY >= 0 && relativeY <= sceneSize.height) {
            if (relativeY < _listScrollEdgeThreshold) {
              _startAutoScroll(_sceneListScrollController, scrollUp: true);
              handledByList = true;
            } else if (relativeY > sceneSize.height - _listScrollEdgeThreshold) {
              _startAutoScroll(_sceneListScrollController, scrollUp: false);
              handledByList = true;
            }
          }
        }
      }
      
      if (handledByList) return;
      
      if (_currentScrollController == _storylineListScrollController || 
          _currentScrollController == _eventListScrollController ||
          _currentScrollController == _sceneListScrollController) {
        _stopAutoScroll();
      }
    }
    
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final localPosition = details.localPosition;
    final screenHeight = MediaQuery.of(context).size.height;
    
    if (localPosition.dy < _scrollEdgeThreshold) {
      _startAutoScroll(_pageScrollController, scrollUp: true);
    } else if (localPosition.dy > screenHeight - _scrollEdgeThreshold) {
      _startAutoScroll(_pageScrollController, scrollUp: false);
    } else {
      if (_currentScrollController != _storylineListScrollController && 
          _currentScrollController != _eventListScrollController &&
          _currentScrollController != _sceneListScrollController) {
        _stopAutoScroll();
      }
    }
  }
  
  void _startAutoScroll(ScrollController controller, {required bool scrollUp}) {
    if (_currentScrollController == controller && _autoScrollTimer != null) {
      return;
    }
    
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
        if (currentOffset > minScroll) {
          final newOffset = (currentOffset - _autoScrollSpeed).clamp(minScroll, maxScroll);
          controller.jumpTo(newOffset);
        } else {
          timer.cancel();
          _currentScrollController = null;
        }
      } else {
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
  
  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _currentScrollController = null;
  }

  // MARK: - UI 介面建構
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Listener(
        onPointerMove: (event) {
          _handleDragUpdate(DragUpdateDetails(
            globalPosition: event.position,
            localPosition: event.localPosition,
          ));
        },
        onPointerUp: (_) => _stopAutoScroll(),
        onPointerCancel: (_) => _stopAutoScroll(),
        child: SingleChildScrollView(
          controller: _pageScrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // 標題
            Row(
              children: [
                Icon(
                  Icons.account_tree,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  "大綱調整",
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            _buildStorylineSection(),
            const SizedBox(height: 24),
            _buildEventSection(),
            const SizedBox(height: 24),
            _buildSceneSection(),
          ],
        ),
        ),
      ),
    );
  }

  // MARK: - 大箱（故事線）區段
  Widget _buildStorylineSection() {
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
                  Icons.library_books,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  "大箱（故事線）",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 故事線列表
            DragTarget<OutlineDragData>(
              onWillAcceptWithDetails: (details) {
                return details.data.type == OutlineDragType.storyline;
              },
              onAcceptWithDetails: (details) {
                setState(() {
                  _isDragging = false;
                });
                _stopAutoScroll();
                final dragData = details.data;
                if (dragData.type == OutlineDragType.storyline) {
                  setState(() {
                    final fromIndex = dragData.currentIndex;
                    final toIndex = storylines.length - 1;
                    
                    if (fromIndex >= 0 && fromIndex < storylines.length && fromIndex != toIndex) {
                      final movedStoryline = storylines.removeAt(fromIndex);
                      storylines.insert(toIndex, movedStoryline);
                      _notifyChange();
                    }
                  });
                }
              },
              builder: (context, candidateData, rejectedData) {
                final isHighlighted = candidateData.isNotEmpty;
                
                return Container(
                  key: _storylineListKey,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isHighlighted
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                      width: isHighlighted ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isHighlighted
                        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1)
                        : null,
                  ),
                  child: storylines.isEmpty
                      ? Center(
                          child: Text(
                            "暫無故事線",
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _storylineListScrollController,
                          itemCount: storylines.length,
                          itemBuilder: (context, index) => _buildStorylineRow(storylines[index], index),
                        ),
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            // 新增故事線
            AddItemInput(
              title: "故事線名稱",
              controller: newStorylineController,
              onAdd: (_) => _addStoryline(),
              allowEmpty: true,
            ),
            
            // 故事線詳細編輯
            if (selectedStorylineIndex != null) ...[
              const SizedBox(height: 16),
              _buildStorylineDetails(),
            ],
            
            const SizedBox(height: 12),
            Text(
              "大箱：故事的大致走向。標記可以使用「三幕劇」、「起承轉合」、「故事七步驟」等結構",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // MARK: - 列表內直接改名 Helpers

  void _startRenamingStoryline(StorylineData data) {
    setState(() {
      editingStorylineID = data.chapterUUID;
      editingEventID = null;
      editingSceneID = null;
      _renameListController?.dispose();
      _renameListController = TextEditingController(text: data.storylineName);
    });
  }

  void _submitRenamingStoryline(int index) {
      if (editingStorylineID != null && _renameListController != null) {
          final val = _renameListController!.text.trim();
          storylines[index].storylineName = val.isEmpty ? "(未命名故事線)" : val;
          _notifyChange();
      }
      _cancelRenaming();
  }

  void _startRenamingEvent(StoryEventData data) {
    setState(() {
      editingEventID = data.storyEventUUID;
      editingStorylineID = null;
      editingSceneID = null;
      _renameListController?.dispose();
      _renameListController = TextEditingController(text: data.storyEvent);
    });
  }

  void _submitRenamingEvent(int slIdx, int evIdx) {
      if (editingEventID != null && _renameListController != null) {
          final val = _renameListController!.text.trim();
          storylines[slIdx].scenes[evIdx].storyEvent = val.isEmpty ? "(未命名事件)" : val;
          _notifyChange();
      }
      _cancelRenaming();
  }
  
  void _startRenamingScene(SceneData data) {
    setState(() {
      editingSceneID = data.sceneUUID;
      editingStorylineID = null;
      editingEventID = null;
      _renameListController?.dispose();
      _renameListController = TextEditingController(text: data.sceneName);
    });
  }

  void _submitRenamingScene(int slIdx, int evIdx, int scIdx) {
      if (editingSceneID != null && _renameListController != null) {
          final val = _renameListController!.text.trim();
          storylines[slIdx].scenes[evIdx].scenes[scIdx].sceneName = val.isEmpty ? "(未命名場景)" : val;
          _notifyChange();
      }
      _cancelRenaming();
  }

  void _cancelRenaming() {
      setState(() {
          editingStorylineID = null;
          editingEventID = null;
          editingSceneID = null;
          _renameListController?.dispose();
          _renameListController = null;
      });
  }

  Widget _buildStorylineDetails() {
    final si = selectedStorylineIndex;
    if (si == null || si < 0 || si >= storylines.length) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "大箱內容（故事線細節）",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: storylineNameController,
               decoration: const InputDecoration(
                labelText: "故事線名稱",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
               controller: storylineTypeController,
               decoration: const InputDecoration(
                labelText: "類型 (如：懸疑、愛情)",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
               controller: storylineConflictController,
               decoration: const InputDecoration(
                labelText: "主要衝突",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            Text("備註", style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: storylineMemoController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "輸入備註...",
              ),
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  // MARK: - 中箱（事件）區段
  Widget _buildEventSection() {
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
                  Icons.event_note,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  "中箱（事件）",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (selectedStorylineIndex != null) ...[
              DragTarget<OutlineDragData>(
                onWillAcceptWithDetails: (details) {
                  return details.data.type == OutlineDragType.event;
                },
                onAcceptWithDetails: (details) {
                  setState(() {
                    _isDragging = false;
                  });
                  _stopAutoScroll();
                },
                builder: (context, candidateData, rejectedData) {
                  final isHighlighted = candidateData.isNotEmpty;
                  final si = selectedStorylineIndex!;
                  final events = storylines[si].scenes;
                  
                  return Container(
                    key: _eventListKey,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isHighlighted
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                        width: isHighlighted ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: isHighlighted
                          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1)
                          : null,
                    ),
                    child: events.isEmpty
                        ? Center(
                            child: Text(
                              "此故事線暫無事件",
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _eventListScrollController,
                            itemCount: events.length,
                            itemBuilder: (context, index) => _buildEventRow(events[index], index),
                          ),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              AddItemInput(
                title: "事件名稱",
                controller: newEventController,
                onAdd: (_) => _addEvent(),
                allowEmpty: true,
              ),
              
              if (selectedEventIndex != null) ...[
                const SizedBox(height: 16),
                _buildEventDetails(),
              ],
            ] else ...[
               Container(
                  height: 250,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      "請先選擇故事線",
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                         color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
               ),
            ],
            
            const SizedBox(height: 12),
            Text(
              "中箱：具體發生的事件。",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // MARK: - 故事線 Row
  Widget _buildStorylineRow(StorylineData storyline, int index) {
    final isSelected = storyline.chapterUUID == selectedStorylineID;
    final isEditing = storyline.chapterUUID == editingStorylineID;
    
    return DraggableCardNode<OutlineDragData>(
      key: ValueKey(storyline.chapterUUID),
      dragData: OutlineDragData(
        id: storyline.chapterUUID,
        type: OutlineDragType.storyline,
        currentIndex: index,
      ),
      nodeId: storyline.chapterUUID,
      nodeType: NodeType.folder,
      
      isDragging: _isDragging,
      isThisDragging: _currentDragData?.id == storyline.chapterUUID,
      isSelected: isSelected,
      
      title: isEditing
          ? TextField(
              controller: _renameListController,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onSubmitted: (_) => _submitRenamingStoryline(index),
            )
          : GestureDetector(
              onDoubleTap: () => _startRenamingStoryline(storyline),
              child: Text(
                storyline.storylineName.isEmpty ? "(未命名故事線)" : storyline.storylineName,
                style: isSelected
                    ? TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      )
                    : null,
              ),
            ),
      subtitle: Text(
        storyline.storylineType.isEmpty ? "未設定類型" : storyline.storylineType,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      leading: Icon(
        Icons.library_books,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
        size: 24,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _startRenamingStoryline(storyline),
            icon: const Icon(Icons.edit, size: 20),
            tooltip: "重新命名",
          ),
          IconButton(
            onPressed: storylines.length > 1 ? () => _deleteStoryline(storyline.chapterUUID) : null,
            icon: Icon(
              Icons.delete,
              size: 20,
              color: storylines.length > 1 ? Theme.of(context).colorScheme.error : null,
            ),
            tooltip: "刪除故事線",
          ),
        ],
      ),
      onClicked: () {
            setState(() {
              selectedStorylineID = storyline.chapterUUID;
              _updateSelectionAfterStorylineChange();
            });
      },
      
      onDragStarted: () {
        setState(() {
          _isDragging = true;
          _currentDragData = OutlineDragData(
             id: storyline.chapterUUID,
             type: OutlineDragType.storyline,
             currentIndex: index
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
         
         if (_currentDragData!.type == OutlineDragType.storyline) {
             // Reorder Storyline (Same level)
             return pos == DropPosition.child ? 0.0 : 0.5;
         } else if (_currentDragData!.type == OutlineDragType.event) {
             // Drop Event into Storyline (Child to Parent)
             return pos == DropPosition.child ? 1.0 : 0.0;
         }
         return 0.0;
      },
      
      onAccept: (data, pos) {
          if (data.type == OutlineDragType.storyline) {
             int toIndex = index;
             if (pos == DropPosition.after) toIndex++;
             
             final fromIndex = data.currentIndex;
             if (fromIndex < toIndex) toIndex--;
             
             _moveStorylineByDrag(fromIndex, toIndex);
          } else if (data.type == OutlineDragType.event && pos == DropPosition.child) {
             _moveEventToStoryline(data.id, storyline.chapterUUID);
             ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("事件已移動到「${storyline.storylineName}」"),
                duration: const Duration(seconds: 2),
              ),
            );
          }
      },
    );
  }

  // MARK: - 事件 Row
  Widget _buildEventRow(StoryEventData event, int index) {
    final isSelected = event.storyEventUUID == selectedEventID;
    final isEditing = event.storyEventUUID == editingEventID;
    final slIdx = selectedStorylineIndex!;
    
    return DraggableCardNode<OutlineDragData>(
      key: ValueKey(event.storyEventUUID),
      dragData: OutlineDragData(
        id: event.storyEventUUID,
        type: OutlineDragType.event,
        currentIndex: index,
      ),
      nodeId: event.storyEventUUID,
      nodeType: NodeType.folder,
      
      isDragging: _isDragging,
      isThisDragging: _currentDragData?.id == event.storyEventUUID,
      isSelected: isSelected,
      
      title: isEditing
          ? TextField(
              controller: _renameListController,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onSubmitted: (_) => _submitRenamingEvent(slIdx, index),
            )
          : GestureDetector(
              onDoubleTap: () => _startRenamingEvent(event),
              child: Text(
                event.storyEvent.isEmpty ? "(未命名事件)" : event.storyEvent,
                style: isSelected
                    ? TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      )
                    : null,
              ),
            ),
      subtitle: Text(
        "${event.scenes.length} 個場景",
        style: Theme.of(context).textTheme.bodySmall,
      ),
      leading: Icon(
        Icons.event_note,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
        size: 24,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _startRenamingEvent(event),
            icon: const Icon(Icons.edit, size: 20),
            tooltip: "重新命名",
          ),
          IconButton(
            onPressed: () => _deleteEvent(event.storyEventUUID, slIdx),
            icon: Icon(
               Icons.delete,
               size: 20,
               color: Theme.of(context).colorScheme.error,
            ),
            tooltip: "刪除事件",
          ),
        ],
      ),
      onClicked: () {
            setState(() {
              selectedEventID = event.storyEventUUID;
              _updateSelectionAfterEventChange();
            });
      },
      
      onDragStarted: () {
        setState(() {
          _isDragging = true;
          _currentDragData = OutlineDragData(
             id: event.storyEventUUID,
             type: OutlineDragType.event,
             currentIndex: index
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
         
         if (_currentDragData!.type == OutlineDragType.event) {
             // Reorder Event (Same level)
             return pos == DropPosition.child ? 0.0 : 0.5;
         } else if (_currentDragData!.type == OutlineDragType.scene) {
             // Drop Scene into Event (Child to Parent)
             return pos == DropPosition.child ? 1.0 : 0.0;
         }
         return 0.0;
      },
      
      onAccept: (data, pos) {
         if (data.type == OutlineDragType.event) {
             int toIndex = index;
             if (pos == DropPosition.after) toIndex++;
             
             final fromIndex = data.currentIndex;
             if (fromIndex < toIndex) toIndex--;
             
             _moveEventByDrag(slIdx, fromIndex, toIndex);
         } else if (data.type == OutlineDragType.scene && pos == DropPosition.child) {
             // Need original indices of Scene. 
             // _moveSceneToEvent uses sceneId to find it.
             _moveSceneToEvent(data.id, slIdx, index);
         }
      },
    );
  }


  Widget _buildEventDetails() {
    final si = selectedStorylineIndex;
    final ei = selectedEventIndex;
    if (si == null || ei == null || si < 0 || ei < 0 || 
        si >= storylines.length || ei >= storylines[si].scenes.length) {
      return const SizedBox.shrink();
    }
    final event = storylines[si].scenes[ei];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "中箱內容（事件細節）",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Builder(
              builder: (context) {
                if (eventNameController.text != event.storyEvent) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    eventNameController.text = event.storyEvent;
                  });
                }
                return TextField(
                  controller: eventNameController,
                  decoration: const InputDecoration(
                    labelText: "事件名稱",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                );
              },
            ),
            
            const SizedBox(height: 12),
            
            Builder(
              builder: (context) {
                if (eventConflictController.text != event.conflictPoint) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    eventConflictController.text = event.conflictPoint;
                  });
                }
                return TextField(
                  controller: eventConflictController,
                  decoration: const InputDecoration(
                    labelText: "衝突點",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            CardList(
              title: "預設人物",
              icon: Icons.person,
              items: event.people,
              onAdd: (item) {
                setState(() {
                  event.people.add(item);
                });
                _notifyChange();
              },
              onRemove: (index) {
                setState(() {
                  event.people.removeAt(index);
                });
                _notifyChange();
              },
            ),
            
            const SizedBox(height: 16),
            
            CardList(
              title: "預設物件",
              icon: Icons.category,
              items: event.item,
              onAdd: (item) {
                setState(() {
                  event.item.add(item);
                });
                _notifyChange();
              },
              onRemove: (index) {
                setState(() {
                  event.item.removeAt(index);
                });
                _notifyChange();
              },
            ),
            
            const SizedBox(height: 16),
            
            Text(
              "備註",
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                // 當選中的事件改變時，同步控制器內容
                if (eventMemoController.text != event.memo) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    eventMemoController.text = event.memo;
                  });
                }
                return TextField(
                  controller: eventMemoController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "輸入備註...",
                  ),
                  maxLines: 4,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // MARK: - 小箱（場景）區段
  Widget _buildSceneSection() {
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
                  Icons.theater_comedy,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  "小箱（場景）",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (selectedStorylineIndex != null && selectedEventIndex != null) ...[
              DragTarget<OutlineDragData>(
                onWillAcceptWithDetails: (details) {
                  return details.data.type == OutlineDragType.scene;
                },
                onAcceptWithDetails: (details) {
                  setState(() {
                    _isDragging = false;
                  });
                  _stopAutoScroll();
                  final dragData = details.data;
                  if (selectedStorylineIndex != null && selectedEventIndex != null && dragData.type == OutlineDragType.scene) {
                    _moveSceneToEvent(dragData.id, selectedStorylineIndex!, selectedEventIndex!);
                  }
                },
                builder: (context, candidateData, rejectedData) {
                  final isHighlighted = candidateData.isNotEmpty;
                  
                  return Container(
                    key: _sceneListKey,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isHighlighted
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                        width: isHighlighted ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: isHighlighted
                          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1)
                          : null,
                    ),
                    child: storylines[selectedStorylineIndex!].scenes[selectedEventIndex!].scenes.isEmpty
                        ? Center(
                            child: Text(
                              "暫無場景",
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _sceneListScrollController,
                            itemCount: storylines[selectedStorylineIndex!].scenes[selectedEventIndex!].scenes.length,
                            itemBuilder: (context, index) => _buildSceneRow(storylines[selectedStorylineIndex!].scenes[selectedEventIndex!].scenes[index], index),
                          ),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              AddItemInput(
                title: "場景名稱",
                controller: newSceneController,
                onAdd: (_) => _addScene(),
                allowEmpty: true,
              ),
              
              if (selectedSceneIndex != null) ...[
                const SizedBox(height: 16),
                _buildSceneDetails(),
              ],
            ] else ...[
              Container(
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    "請先選擇一個事件",
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            Text(
              "小箱：事件的詳細場景。",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSceneRow(SceneData scene, int index) {
    final isSelected = scene.sceneUUID == selectedSceneID;
    final isEditing = scene.sceneUUID == editingSceneID;
    
    return DraggableCardNode<OutlineDragData>(
      key: ValueKey(scene.sceneUUID),
      dragData: OutlineDragData(
        id: scene.sceneUUID,
        type: OutlineDragType.scene,
        currentIndex: index,
      ),
      nodeId: scene.sceneUUID,
      nodeType: NodeType.leaf,
      
      isDragging: _isDragging,
      isThisDragging: _currentDragData?.id == scene.sceneUUID,
      isSelected: isSelected,
      
      title: isEditing
          ? TextField(
              controller: _renameListController,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onSubmitted: (_) => _submitRenamingScene(selectedStorylineIndex!, selectedEventIndex!, index),
            )
          : GestureDetector(
              onDoubleTap: () => _startRenamingScene(scene),
              child: Text(
                scene.sceneName.isEmpty ? "(未命名場景)" : scene.sceneName,
                style: isSelected
                    ? TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      )
                    : null,
              ),
            ),
      subtitle: (scene.time.isNotEmpty || scene.location.isNotEmpty) ? Row(
        children: [
          if (scene.time.isNotEmpty) ...[
            Icon(Icons.access_time, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(scene.time, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (scene.time.isNotEmpty && scene.location.isNotEmpty) 
            Text(" • ", style: Theme.of(context).textTheme.bodySmall),
          if (scene.location.isNotEmpty) ...[
            Icon(Icons.location_on, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(scene.location, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ) : null,
      leading: Icon(
        Icons.theater_comedy,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
        size: 24,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _startRenamingScene(scene),
            icon: const Icon(Icons.edit, size: 20),
            tooltip: "重新命名",
          ),
          IconButton(
            onPressed: () => _deleteScene(scene.sceneUUID, selectedStorylineIndex!, selectedEventIndex!),
            icon: Icon(
               Icons.delete,
               size: 20,
               color: Theme.of(context).colorScheme.error,
            ),
            tooltip: "刪除場景",
          ),
        ],
      ),
      onClicked: () {
            setState(() {
              selectedSceneID = scene.sceneUUID;
              _syncAllControllers();
            });
      },
      
      onDragStarted: () {
        setState(() {
          _isDragging = true;
          _currentDragData = OutlineDragData(
             id: scene.sceneUUID,
             type: OutlineDragType.scene,
             currentIndex: index
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
         
         if (_currentDragData!.type == OutlineDragType.scene) {
             // Reorder Scene (Same level)
             return pos == DropPosition.child ? 0.0 : 0.5;
         }
         return 0.0;
      },
      
      onAccept: (data, pos) {
         if (data.type == OutlineDragType.scene) {
             final slIdx = selectedStorylineIndex;
             final evIdx = selectedEventIndex;
             if (slIdx != null && evIdx != null) {
                int toIndex = index;
                if (pos == DropPosition.after) toIndex++;
                
                final fromIndex = data.currentIndex;
                if (fromIndex < toIndex) toIndex--;
                
                _moveSceneByDrag(slIdx, evIdx, fromIndex, toIndex);
             }
         }
      },
    );
  }

  Widget _buildSceneDetails() {
    final si = selectedStorylineIndex;
    final ei = selectedEventIndex;
    final ci = selectedSceneIndex;
    if (si == null || ei == null || ci == null || si < 0 || ei < 0 || ci < 0 ||
        si >= storylines.length || ei >= storylines[si].scenes.length || 
        ci >= storylines[si].scenes[ei].scenes.length) {
      return const SizedBox.shrink();
    }
    final scene = storylines[si].scenes[ei].scenes[ci];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "小箱內容（場景細節）",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Builder(
              builder: (context) {
                if (sceneNameController.text != scene.sceneName) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    sceneNameController.text = scene.sceneName;
                  });
                }
                return TextField(
                  controller: sceneNameController,
                  decoration: const InputDecoration(
                    labelText: "場景名稱",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                );
              },
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (sceneTimeController.text != scene.time) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          sceneTimeController.text = scene.time;
                        });
                      }
                      return TextField(
                        controller: sceneTimeController,
                        decoration: const InputDecoration(
                          labelText: "時間",
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (sceneLocationController.text != scene.location) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          sceneLocationController.text = scene.location;
                        });
                      }
                      return TextField(
                        controller: sceneLocationController,
                        decoration: const InputDecoration(
                          labelText: "地點",
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (sceneFocusController.text != scene.focusPoint) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          sceneFocusController.text = scene.focusPoint;
                        });
                      }
                      return TextField(
                        controller: sceneFocusController,
                        decoration: const InputDecoration(
                          labelText: "聚焦點",
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (sceneConflictController.text != scene.conflictPoint) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          sceneConflictController.text = scene.conflictPoint;
                        });
                      }
                      return TextField(
                        controller: sceneConflictController,
                        decoration: const InputDecoration(
                          labelText: "衝突點",
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            CardList(
              title: "人物",
              icon: Icons.person,
              items: scene.people,
              onAdd: (item) {
                setState(() {
                  scene.people.add(item);
                });
                _notifyChange();
              },
              onRemove: (index) {
                setState(() {
                  scene.people.removeAt(index);
                });
                _notifyChange();
              },
            ),
            
            const SizedBox(height: 16),
            
            CardList(
              title: "物件",
              icon: Icons.category,
              items: scene.item,
              onAdd: (item) {
                setState(() {
                  scene.item.add(item);
                });
                _notifyChange();
              },
              onRemove: (index) {
                setState(() {
                  scene.item.removeAt(index);
                });
                _notifyChange();
              },
            ),
            
            const SizedBox(height: 16),
            
            CardList(
              title: "行動",
              icon: Icons.directions_run,
              items: scene.doingThings,
              onAdd: (item) {
                setState(() {
                  scene.doingThings.add(item);
                });
                _notifyChange();
              },
              onRemove: (index) {
                setState(() {
                  scene.doingThings.removeAt(index);
                });
                _notifyChange();
              },
            ),
            
            const SizedBox(height: 16),
            
            Text(
              "備註",
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                // 當選中的場景改變時，同步控制器內容
                if (sceneMemoController.text != scene.memo) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    sceneMemoController.text = scene.memo;
                  });
                }
                return TextField(
                  controller: sceneMemoController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "輸入備註...",
                  ),
                  maxLines: 4,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // MARK: - 新增方法
  void _addStoryline() {
    final name = newStorylineController.text.trim();
    final finalName = name.isEmpty ? "故事線 ${storylines.length + 1}" : name;
    
    final newStoryline = StorylineData(
      storylineName: finalName,
      storylineType: "",
      scenes: [],
      memo: "",
      conflictPoint: "",
      people: [],
      item: [],
    );
    
    setState(() {
      storylines.add(newStoryline);
      selectedStorylineID = newStoryline.chapterUUID;
      selectedEventID = null;
      selectedSceneID = null;
      newStorylineController.clear();
    });
    
    _notifyChange();
  }

  void _addEvent() {
    final si = selectedStorylineIndex;
    if (si == null) return;
    
    final name = newEventController.text.trim();
    final finalName = name.isEmpty ? "事件 ${storylines[si].scenes.length + 1}" : name;
    
    final newEvent = StoryEventData(
      storyEvent: finalName,
      scenes: [],
      memo: "",
      conflictPoint: "",
      people: List.from(storylines[si].people), // 繼承大箱
      item: List.from(storylines[si].item),     // 繼承大箱
    );
    
    setState(() {
      storylines[si].scenes.add(newEvent);
      selectedStorylineID = storylines[si].chapterUUID;
      selectedEventID = newEvent.storyEventUUID;
      selectedSceneID = null;
      newEventController.clear();
    });
    
    _notifyChange();
  }

  void _addScene() {
    final si = selectedStorylineIndex;
    final ei = selectedEventIndex;
    if (si == null || ei == null) return;
    
    final name = newSceneController.text.trim();
    final finalName = name.isEmpty ? "場景 ${storylines[si].scenes[ei].scenes.length + 1}" : name;
    
    final newScene = SceneData(
      sceneName: finalName,
      focusPoint: "",
      conflictPoint: "",
      people: List.from(storylines[si].scenes[ei].people), // 繼承中箱
      item: List.from(storylines[si].scenes[ei].item),     // 繼承中箱
    );
    
    setState(() {
      storylines[si].scenes[ei].scenes.add(newScene);
      selectedStorylineID = storylines[si].chapterUUID;
      selectedEventID = storylines[si].scenes[ei].storyEventUUID;
      selectedSceneID = newScene.sceneUUID;
      newSceneController.clear();
    });
    
    _notifyChange();
  }

  // MARK: - 刪除方法
  void _deleteStoryline(String id) {
    final index = storylines.indexWhere((sl) => sl.chapterUUID == id);
    if (index == -1) return;
    
    setState(() {
      storylines.removeAt(index);
      selectedStorylineID = storylines.isNotEmpty ? storylines.first.chapterUUID : null;
      _updateSelectionAfterStorylineChange();
    });
    
    _notifyChange();
  }

  void _deleteEvent(String id, int storylineIndex) {
    final eventIndex = storylines[storylineIndex].scenes.indexWhere((ev) => ev.storyEventUUID == id);
    if (eventIndex == -1) return;
    
    setState(() {
      storylines[storylineIndex].scenes.removeAt(eventIndex);
      selectedStorylineID = storylines[storylineIndex].chapterUUID;
      selectedEventID = storylines[storylineIndex].scenes.isNotEmpty 
        ? storylines[storylineIndex].scenes.first.storyEventUUID 
        : null;
      _updateSelectionAfterEventChange();
    });
    
    _notifyChange();
  }

  void _deleteScene(String id, int storylineIndex, int eventIndex) {
    final sceneIndex = storylines[storylineIndex].scenes[eventIndex].scenes.indexWhere((sc) => sc.sceneUUID == id);
    if (sceneIndex == -1) return;
    
    setState(() {
      storylines[storylineIndex].scenes[eventIndex].scenes.removeAt(sceneIndex);
      selectedStorylineID = storylines[storylineIndex].chapterUUID;
      selectedEventID = storylines[storylineIndex].scenes[eventIndex].storyEventUUID;
      selectedSceneID = storylines[storylineIndex].scenes[eventIndex].scenes.isNotEmpty
        ? storylines[storylineIndex].scenes[eventIndex].scenes.first.sceneUUID
        : null;
    });
    
    _notifyChange();
  }

  // MARK: - 拖動處理方法
  
  void _moveStorylineByDrag(int fromIndex, int toIndex) {
    if (fromIndex == toIndex) return;
    
    setState(() {
      final storyline = storylines.removeAt(fromIndex);
      storylines.insert(toIndex, storyline);
    });
    
    _notifyChange();
  }
  
  void _moveEventToStoryline(String eventId, String toStorylineId) {
    // 找到來源事件
    int? sourceStorylineIdx;
    int? sourceEventIdx;
    for (int si = 0; si < storylines.length; si++) {
      final ei = storylines[si].scenes.indexWhere((ev) => ev.storyEventUUID == eventId);
      if (ei >= 0) {
        sourceStorylineIdx = si;
        sourceEventIdx = ei;
        break;
      }
    }

    if (sourceStorylineIdx == null || sourceEventIdx == null) return;

    // 找到目標故事線
    final targetStorylineIdx = storylines.indexWhere((sl) => sl.chapterUUID == toStorylineId);
    if (targetStorylineIdx < 0 || targetStorylineIdx == sourceStorylineIdx) return;

    // 執行移動
    final movingEvent = storylines[sourceStorylineIdx].scenes.removeAt(sourceEventIdx);
    storylines[targetStorylineIdx].scenes.add(movingEvent);

    // 更新選擇
    setState(() {
      selectedStorylineID = storylines[targetStorylineIdx].chapterUUID;
      selectedEventID = movingEvent.storyEventUUID;
      selectedSceneID = movingEvent.scenes.isNotEmpty ? movingEvent.scenes.first.sceneUUID : null;
    });

    _notifyChange();
  }
  
  void _moveSceneToEvent(String sceneId, int targetStorylineIdx, int targetEventIdx) {
    // 找到來源場景
    int? sourceStorylineIdx;
    int? sourceEventIdx; 
    int? sourceSceneIdx;
    for (int si = 0; si < storylines.length; si++) {
      for (int ei = 0; ei < storylines[si].scenes.length; ei++) {
        final ci = storylines[si].scenes[ei].scenes.indexWhere((sc) => sc.sceneUUID == sceneId);
        if (ci >= 0) {
          sourceStorylineIdx = si;
          sourceEventIdx = ei;
          sourceSceneIdx = ci;
          break;
        }
      }
      if (sourceSceneIdx != null) break;
    }

    if (sourceStorylineIdx == null || sourceEventIdx == null || sourceSceneIdx == null) return;
    if (sourceStorylineIdx == targetStorylineIdx && sourceEventIdx == targetEventIdx) return;

    // 執行移動
    final movingScene = storylines[sourceStorylineIdx].scenes[sourceEventIdx].scenes.removeAt(sourceSceneIdx);
    storylines[targetStorylineIdx].scenes[targetEventIdx].scenes.add(movingScene);

    // 更新選擇
    setState(() {
      selectedStorylineID = storylines[targetStorylineIdx].chapterUUID;
      selectedEventID = storylines[targetStorylineIdx].scenes[targetEventIdx].storyEventUUID;
      selectedSceneID = movingScene.sceneUUID;
    });

    _notifyChange();
  }
  
  void _moveEventByDrag(int storylineIndex, int fromIndex, int toIndex) {
    if (fromIndex == toIndex) return;
    
    setState(() {
      final event = storylines[storylineIndex].scenes.removeAt(fromIndex);
      storylines[storylineIndex].scenes.insert(toIndex, event);
    });
    
    _notifyChange();
  }
  
  void _moveSceneByDrag(int storylineIndex, int eventIndex, int fromIndex, int toIndex) {
    if (fromIndex == toIndex) return;
    
    setState(() {
      final scene = storylines[storylineIndex].scenes[eventIndex].scenes.removeAt(fromIndex);
      storylines[storylineIndex].scenes[eventIndex].scenes.insert(toIndex, scene);
    });
    
    _notifyChange();
  }

  // MARK: - 選擇更新方法
  void _updateSelectionAfterStorylineChange() {
    final si = selectedStorylineIndex;
    if (si != null) {
      selectedEventID = storylines[si].scenes.isNotEmpty 
        ? storylines[si].scenes.first.storyEventUUID 
        : null;
      _updateSelectionAfterEventChange();
    } else {
      selectedEventID = null;
      selectedSceneID = null;
    }
    _syncAllControllers();
  }

  void _updateSelectionAfterEventChange() {
    final si = selectedStorylineIndex;
    final ei = selectedEventIndex;
    if (si != null && ei != null) {
      selectedSceneID = storylines[si].scenes[ei].scenes.isNotEmpty
        ? storylines[si].scenes[ei].scenes.first.sceneUUID
        : null;
    } else {
      selectedSceneID = null;
    }
    _syncAllControllers();
  }
}

