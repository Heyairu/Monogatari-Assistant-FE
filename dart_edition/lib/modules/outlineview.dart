import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "dart:async";

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
  static String _escapeXml(String text) {
    return text
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll("\"", "&quot;")
        .replaceAll("'", "&apos;");
  }

  static String _unescapeXml(String text) {
    return text
        .replaceAll("&lt;", "<")
        .replaceAll("&gt;", ">")
        .replaceAll("&quot;", "\"")
        .replaceAll("&apos;", "'")
        .replaceAll("&amp;", "&");
  }

  static String? saveXML(List<StorylineData> storylines) {
    if (storylines.isEmpty) return null;
    
    final buffer = StringBuffer();
    buffer.writeln("<Type>");
    buffer.writeln("  <Name>Outline</Name>");
    
    for (final sl in storylines) {
      buffer.writeln("  <Storyline Name=\"${_escapeXml(sl.storylineName)}\" Type=\"${_escapeXml(sl.storylineType)}\" UUID=\"${sl.chapterUUID}\">");
      
      if (sl.memo.isNotEmpty) {
        buffer.writeln("    <Memo>${_escapeXml(sl.memo)}</Memo>");
      }
      
      if (sl.conflictPoint.isNotEmpty) {
        buffer.writeln("    <ConflictPoint>${_escapeXml(sl.conflictPoint)}</ConflictPoint>");
      }
      
      if (sl.people.isNotEmpty) {
        buffer.writeln("    <People>");
        for (final p in sl.people) {
          buffer.writeln("      <Person>${_escapeXml(p)}</Person>");
        }
        buffer.writeln("    </People>");
      }
      
      if (sl.item.isNotEmpty) {
        buffer.writeln("    <Items>");
        for (final it in sl.item) {
          buffer.writeln("      <Item>${_escapeXml(it)}</Item>");
        }
        buffer.writeln("    </Items>");
      }
      
      for (final ev in sl.scenes) {
        buffer.writeln("    <Event Name=\"${_escapeXml(ev.storyEvent)}\" UUID=\"${ev.storyEventUUID}\">");
        
        if (ev.memo.isNotEmpty) {
          buffer.writeln("      <Memo>${_escapeXml(ev.memo)}</Memo>");
        }
        
        if (ev.conflictPoint.isNotEmpty) {
          buffer.writeln("      <ConflictPoint>${_escapeXml(ev.conflictPoint)}</ConflictPoint>");
        }
        
        if (ev.people.isNotEmpty) {
          buffer.writeln("      <People>");
          for (final p in ev.people) {
            buffer.writeln("        <Person>${_escapeXml(p)}</Person>");
          }
          buffer.writeln("      </People>");
        }
        
        if (ev.item.isNotEmpty) {
          buffer.writeln("      <Items>");
          for (final it in ev.item) {
            buffer.writeln("        <Item>${_escapeXml(it)}</Item>");
          }
          buffer.writeln("      </Items>");
        }
        
        for (final sc in ev.scenes) {
          buffer.writeln("      <Scene Name=\"${_escapeXml(sc.sceneName)}\" UUID=\"${sc.sceneUUID}\">");
          
          if (sc.time.isNotEmpty) {
            buffer.writeln("        <Time>${_escapeXml(sc.time)}</Time>");
          }
          
          if (sc.location.isNotEmpty) {
            buffer.writeln("        <Location>${_escapeXml(sc.location)}</Location>");
          }
          
          if (sc.focusPoint.isNotEmpty) {
            buffer.writeln("        <FocusPoint>${_escapeXml(sc.focusPoint)}</FocusPoint>");
          }
          
          if (sc.conflictPoint.isNotEmpty) {
            buffer.writeln("        <ConflictPoint>${_escapeXml(sc.conflictPoint)}</ConflictPoint>");
          }
          
          if (sc.people.isNotEmpty) {
            buffer.writeln("        <People>");
            for (final p in sc.people) {
              buffer.writeln("          <Person>${_escapeXml(p)}</Person>");
            }
            buffer.writeln("        </People>");
          }
          
          if (sc.item.isNotEmpty) {
            buffer.writeln("        <Items>");
            for (final it in sc.item) {
              buffer.writeln("          <Item>${_escapeXml(it)}</Item>");
            }
            buffer.writeln("        </Items>");
          }
          
          if (sc.doingThings.isNotEmpty) {
            buffer.writeln("        <Doings>");
            for (final d in sc.doingThings) {
              buffer.writeln("          <Doing>${_escapeXml(d)}</Doing>");
            }
            buffer.writeln("        </Doings>");
          }
          
          if (sc.memo.isNotEmpty) {
            buffer.writeln("        <Memo>${_escapeXml(sc.memo)}</Memo>");
          }
          
          buffer.writeln("      </Scene>");
        }
        
        buffer.writeln("    </Event>");
      }
      
      buffer.writeln("  </Storyline>");
    }
    
    buffer.writeln("</Type>");
    return buffer.toString();
  }

  static List<StorylineData>? loadXML(String xml) {
    final storylines = <StorylineData>[];
    
    try {
      // 使用正規表示式解析 Storyline 元素
      final storylineRegex = RegExp(
        r'<Storyline[^>]*Name="([^"]*)"[^>]*Type="([^"]*)"[^>]*UUID="([^"]*)"[^>]*>(.*?)</Storyline>',
        dotAll: true
      );
      
      final storylineMatches = storylineRegex.allMatches(xml);
      
      for (final storylineMatch in storylineMatches) {
        final storylineName = _unescapeXml(storylineMatch.group(1) ?? "");
        final storylineType = _unescapeXml(storylineMatch.group(2) ?? "");
        final storylineUUID = storylineMatch.group(3) ?? DateTime.now().millisecondsSinceEpoch.toString();
        final storylineContent = storylineMatch.group(4) ?? "";
        
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
        
        // 解析 Memo
        final memoMatch = RegExp(r'<Memo>(.*?)</Memo>', dotAll: true).firstMatch(storylineContent);
        if (memoMatch != null) {
          storyline.memo = _unescapeXml(memoMatch.group(1) ?? "");
        }
        
        // 解析 ConflictPoint
        final conflictPointMatch = RegExp(r'<ConflictPoint>(.*?)</ConflictPoint>', dotAll: true).firstMatch(storylineContent);
        if (conflictPointMatch != null) {
          storyline.conflictPoint = _unescapeXml(conflictPointMatch.group(1) ?? "");
        }
        
        // 解析 People
        final peopleMatch = RegExp(r'<People>(.*?)</People>', dotAll: true).firstMatch(storylineContent);
        if (peopleMatch != null) {
          final peopleContent = peopleMatch.group(1) ?? "";
          final personMatches = RegExp(r'<Person>(.*?)</Person>', dotAll: true).allMatches(peopleContent);
          for (final personMatch in personMatches) {
            final person = _unescapeXml(personMatch.group(1) ?? "");
            if (person.isNotEmpty) {
              storyline.people.add(person);
            }
          }
        }
        
        // 解析 Items
        final itemsMatch = RegExp(r'<Items>(.*?)</Items>', dotAll: true).firstMatch(storylineContent);
        if (itemsMatch != null) {
          final itemsContent = itemsMatch.group(1) ?? "";
          final itemMatches = RegExp(r'<Item>(.*?)</Item>', dotAll: true).allMatches(itemsContent);
          for (final itemMatch in itemMatches) {
            final item = _unescapeXml(itemMatch.group(1) ?? "");
            if (item.isNotEmpty) {
              storyline.item.add(item);
            }
          }
        }
        
        // 解析 Events
        final eventRegex = RegExp(
          r'<Event[^>]*Name="([^"]*)"[^>]*UUID="([^"]*)"[^>]*>(.*?)</Event>',
          dotAll: true
        );
        final eventMatches = eventRegex.allMatches(storylineContent);
        
        for (final eventMatch in eventMatches) {
          final eventName = _unescapeXml(eventMatch.group(1) ?? "");
          final eventUUID = eventMatch.group(2) ?? DateTime.now().millisecondsSinceEpoch.toString();
          final eventContent = eventMatch.group(3) ?? "";
          
          final event = StoryEventData(
            storyEvent: eventName,
            storyEventUUID: eventUUID,
            scenes: [],
            people: [],
            item: [],
            memo: "",
            conflictPoint: "",
          );
          
          // 解析 Event Memo
          final eventMemoMatch = RegExp(r'<Memo>(.*?)</Memo>', dotAll: true).firstMatch(eventContent);
          if (eventMemoMatch != null) {
            event.memo = _unescapeXml(eventMemoMatch.group(1) ?? "");
          }
          
          // 解析 Event ConflictPoint
          final eventConflictPointMatch = RegExp(r'<ConflictPoint>(.*?)</ConflictPoint>', dotAll: true).firstMatch(eventContent);
          if (eventConflictPointMatch != null) {
            event.conflictPoint = _unescapeXml(eventConflictPointMatch.group(1) ?? "");
          }
          
          // 解析 Event People
          final eventPeopleMatch = RegExp(r'<People>(.*?)</People>', dotAll: true).firstMatch(eventContent);
          if (eventPeopleMatch != null) {
            final eventPeopleContent = eventPeopleMatch.group(1) ?? "";
            final eventPersonMatches = RegExp(r'<Person>(.*?)</Person>', dotAll: true).allMatches(eventPeopleContent);
            for (final eventPersonMatch in eventPersonMatches) {
              final person = _unescapeXml(eventPersonMatch.group(1) ?? "");
              if (person.isNotEmpty) {
                event.people.add(person);
              }
            }
          }
          
          // 解析 Event Items
          final eventItemsMatch = RegExp(r'<Items>(.*?)</Items>', dotAll: true).firstMatch(eventContent);
          if (eventItemsMatch != null) {
            final eventItemsContent = eventItemsMatch.group(1) ?? "";
            final eventItemMatches = RegExp(r'<Item>(.*?)</Item>', dotAll: true).allMatches(eventItemsContent);
            for (final eventItemMatch in eventItemMatches) {
              final item = _unescapeXml(eventItemMatch.group(1) ?? "");
              if (item.isNotEmpty) {
                event.item.add(item);
              }
            }
          }
          
          // 解析 Scenes
          final sceneRegex = RegExp(
            r'<Scene[^>]*Name="([^"]*)"[^>]*UUID="([^"]*)"[^>]*>(.*?)</Scene>',
            dotAll: true
          );
          final sceneMatches = sceneRegex.allMatches(eventContent);
          
          for (final sceneMatch in sceneMatches) {
            final sceneName = _unescapeXml(sceneMatch.group(1) ?? "");
            final sceneUUID = sceneMatch.group(2) ?? DateTime.now().millisecondsSinceEpoch.toString();
            final sceneContent = sceneMatch.group(3) ?? "";
            
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
            
            // 解析 Scene Time
            final timeMatch = RegExp(r'<Time>(.*?)</Time>', dotAll: true).firstMatch(sceneContent);
            if (timeMatch != null) {
              scene.time = _unescapeXml(timeMatch.group(1) ?? "");
            }
            
            // 解析 Scene Location
            final locationMatch = RegExp(r'<Location>(.*?)</Location>', dotAll: true).firstMatch(sceneContent);
            if (locationMatch != null) {
              scene.location = _unescapeXml(locationMatch.group(1) ?? "");
            }
            
            // 解析 Scene FocusPoint
            final focusPointMatch = RegExp(r'<FocusPoint>(.*?)</FocusPoint>', dotAll: true).firstMatch(sceneContent);
            if (focusPointMatch != null) {
              scene.focusPoint = _unescapeXml(focusPointMatch.group(1) ?? "");
            }
            
            // 解析 Scene ConflictPoint
            final sceneConflictPointMatch = RegExp(r'<ConflictPoint>(.*?)</ConflictPoint>', dotAll: true).firstMatch(sceneContent);
            if (sceneConflictPointMatch != null) {
              scene.conflictPoint = _unescapeXml(sceneConflictPointMatch.group(1) ?? "");
            }
            
            // 解析 Scene People
            final scenePeopleMatch = RegExp(r'<People>(.*?)</People>', dotAll: true).firstMatch(sceneContent);
            if (scenePeopleMatch != null) {
              final scenePeopleContent = scenePeopleMatch.group(1) ?? "";
              final scenePersonMatches = RegExp(r'<Person>(.*?)</Person>', dotAll: true).allMatches(scenePeopleContent);
              for (final scenePersonMatch in scenePersonMatches) {
                final person = _unescapeXml(scenePersonMatch.group(1) ?? "");
                if (person.isNotEmpty) {
                  scene.people.add(person);
                }
              }
            }
            
            // 解析 Scene Items
            final sceneItemsMatch = RegExp(r'<Items>(.*?)</Items>', dotAll: true).firstMatch(sceneContent);
            if (sceneItemsMatch != null) {
              final sceneItemsContent = sceneItemsMatch.group(1) ?? "";
              final sceneItemMatches = RegExp(r'<Item>(.*?)</Item>', dotAll: true).allMatches(sceneItemsContent);
              for (final sceneItemMatch in sceneItemMatches) {
                final item = _unescapeXml(sceneItemMatch.group(1) ?? "");
                if (item.isNotEmpty) {
                  scene.item.add(item);
                }
              }
            }
            
            // 解析 Scene Doings
            final doingsMatch = RegExp(r'<Doings>(.*?)</Doings>', dotAll: true).firstMatch(sceneContent);
            if (doingsMatch != null) {
              final doingsContent = doingsMatch.group(1) ?? "";
              final doingMatches = RegExp(r'<Doing>(.*?)</Doing>', dotAll: true).allMatches(doingsContent);
              for (final doingMatch in doingMatches) {
                final doing = _unescapeXml(doingMatch.group(1) ?? "");
                if (doing.isNotEmpty) {
                  scene.doingThings.add(doing);
                }
              }
            }
            
            // 解析 Scene Memo
            final sceneMemoMatch = RegExp(r'<Memo>(.*?)</Memo>', dotAll: true).firstMatch(sceneContent);
            if (sceneMemoMatch != null) {
              scene.memo = _unescapeXml(sceneMemoMatch.group(1) ?? "");
            }
            
            event.scenes.add(scene);
          }
          
          storyline.scenes.add(event);
        }
        
        storylines.add(storyline);
      }
      
      return storylines.isEmpty ? null : storylines;
    } catch (e) {
      print("Error parsing Outline XML: $e");
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

  final TextEditingController newPersonController = TextEditingController();
  final TextEditingController newItemController = TextEditingController();
  final TextEditingController newDoingController = TextEditingController();

  final TextEditingController newStorylinePersonController = TextEditingController();
  final TextEditingController newStorylineItemController = TextEditingController();
  final TextEditingController newEventPersonController = TextEditingController();
  final TextEditingController newEventItemController = TextEditingController();
  
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
    newStorylineController.dispose();
    newEventController.dispose();
    newSceneController.dispose();
    newPersonController.dispose();
    newItemController.dispose();
    newDoingController.dispose();
    newStorylinePersonController.dispose();
    newStorylineItemController.dispose();
    newEventPersonController.dispose();
    newEventItemController.dispose();
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
                          : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      width: isHighlighted ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isHighlighted
                        ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1)
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: newStorylineController,
                    decoration: InputDecoration(
                      hintText: "新增故事線名稱",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                    ),
                    onSubmitted: (_) => _addStoryline(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _addStoryline,
                  label: const Text("＋"),
                ),
              ],
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
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorylineRow(StorylineData storyline, int index) {
    final isSelected = storyline.chapterUUID == selectedStorylineID;
    final isEditing = storyline.chapterUUID == editingStorylineID;
    
    return LongPressDraggable<OutlineDragData>(
      data: OutlineDragData(
        id: storyline.chapterUUID,
        type: OutlineDragType.storyline,
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
                Icons.library_books,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  storyline.storylineName.isEmpty ? "(未命名故事線)" : storyline.storylineName,
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
        child: _buildStorylineListTile(storyline, index, isSelected, isEditing),
      ),
      child: DragTarget<OutlineDragData>(
        onWillAcceptWithDetails: (details) {
          final dragData = details.data;
          if (dragData.type == OutlineDragType.storyline) {
            return dragData.currentIndex != index;
          } else if (dragData.type == OutlineDragType.event) {
            return true;
          }
          return false;
        },
        onAcceptWithDetails: (details) {
          final dragData = details.data;
          if (dragData.type == OutlineDragType.storyline) {
            _moveStorylineByDrag(dragData.currentIndex, index);
          } else if (dragData.type == OutlineDragType.event) {
            _moveEventToStoryline(dragData.id, storyline.chapterUUID);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("事件已移動到「${storyline.storylineName}」"),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isHighlighted = candidateData.isNotEmpty;
          return Container(
            key: ValueKey(storyline.chapterUUID),
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
            child: _buildStorylineListTile(storyline, index, isSelected, isEditing),
          );
        },
      ),
    );
  }
  
  Widget _buildStorylineListTile(StorylineData storyline, int index, bool isSelected, bool isEditing) {
    return ListTile(
      leading: Icon(
        Icons.library_books,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
        size: 24,
      ),
      title: isEditing
          ? TextField(
              autofocus: true,
              controller: TextEditingController(text: storylines[index].storylineName)
                ..selection = TextSelection.fromPosition(
                  TextPosition(offset: storylines[index].storylineName.length),
                ),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onSubmitted: (value) {
                setState(() {
                  storylines[index].storylineName = value.trim().isEmpty 
                      ? "(未命名故事線)" 
                      : value.trim();
                  editingStorylineID = null;
                });
                _notifyChange();
              },
              onEditingComplete: () {
                setState(() {
                  editingStorylineID = null;
                });
              },
            )
          : GestureDetector(
              onDoubleTap: () {
                setState(() {
                  editingStorylineID = storyline.chapterUUID;
                });
              },
              child: Text(
                storyline.storylineName.isEmpty ? "(未命名故事線)" : storyline.storylineName,
                style: isSelected
                    ? TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
              ),
            ),
      subtitle: Text(
        storyline.storylineType.isEmpty ? "未設定類型" : storyline.storylineType,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                editingStorylineID = storyline.chapterUUID;
              });
            },
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
      onTap: () {
        setState(() {
          selectedStorylineID = storyline.chapterUUID;
          _updateSelectionAfterStorylineChange();
        });
      },
    );
  }

  Widget _buildStorylineDetails() {
    final si = selectedStorylineIndex;
    if (si == null || si < 0 || si >= storylines.length) {
      return const SizedBox.shrink();
    }
    final storyline = storylines[si];
    
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
            
            Builder(
              builder: (context) {
                if (storylineNameController.text != storyline.storylineName) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    storylineNameController.text = storyline.storylineName;
                  });
                }
                return TextField(
                  controller: storylineNameController,
                  decoration: const InputDecoration(
                    labelText: "故事線名稱",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    setState(() {
                      storyline.storylineName = value;
                    });
                    _notifyChange();
                  },
                );
              },
            ),
            
            const SizedBox(height: 12),
            
            Builder(
              builder: (context) {
                if (storylineTypeController.text != storyline.storylineType) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    storylineTypeController.text = storyline.storylineType;
                  });
                }
                return TextField(
                  controller: storylineTypeController,
                  decoration: const InputDecoration(
                    labelText: "標記（例如：轉、衝突）",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    setState(() {
                      storyline.storylineType = value;
                    });
                    _notifyChange();
                  },
                );
              },
            ),
            
            const SizedBox(height: 12),
            
            Builder(
              builder: (context) {
                if (storylineConflictController.text != storyline.conflictPoint) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    storylineConflictController.text = storyline.conflictPoint;
                  });
                }
                return TextField(
                  controller: storylineConflictController,
                  decoration: const InputDecoration(
                    labelText: "衝突點",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    setState(() {
                      storyline.conflictPoint = value;
                    });
                    _notifyChange();
                  },
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            _buildTagListEditor(
              title: "預設人物",
              items: storyline.people,
              controller: newStorylinePersonController,
              onAdd: (item) {
                setState(() {
                  storyline.people.add(item);
                });
                _notifyChange();
              },
              onRemove: (index) {
                setState(() {
                  storyline.people.removeAt(index);
                });
                _notifyChange();
              },
            ),
            
            const SizedBox(height: 16),
            
            _buildTagListEditor(
              title: "預設物件",
              items: storyline.item,
              controller: newStorylineItemController,
              onAdd: (item) {
                setState(() {
                  storyline.item.add(item);
                });
                _notifyChange();
              },
              onRemove: (index) {
                setState(() {
                  storyline.item.removeAt(index);
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
                // 當選中的故事線改變時，同步控制器內容
                if (storylineMemoController.text != storyline.memo) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    storylineMemoController.text = storyline.memo;
                  });
                }
                return TextField(
                  controller: storylineMemoController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "輸入備註...",
                  ),
                  maxLines: 4,
                  onChanged: (value) {
                    setState(() {
                      storyline.memo = value;
                    });
                    _notifyChange();
                  },
                );
              },
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
                  final dragData = details.data;
                  if (selectedStorylineIndex != null && dragData.type == OutlineDragType.event) {
                    _moveEventToStoryline(dragData.id, storylines[selectedStorylineIndex!].chapterUUID);
                  }
                },
                builder: (context, candidateData, rejectedData) {
                  final isHighlighted = candidateData.isNotEmpty;
                  
                  return Container(
                    key: _eventListKey,
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
                    child: storylines[selectedStorylineIndex!].scenes.isEmpty
                        ? Center(
                            child: Text(
                              "暫無事件",
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _eventListScrollController,
                            itemCount: storylines[selectedStorylineIndex!].scenes.length,
                            itemBuilder: (context, index) => _buildEventRow(storylines[selectedStorylineIndex!].scenes[index], index),
                          ),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: newEventController,
                      decoration: InputDecoration(
                        hintText: "新增事件名稱",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                      ),
                      onSubmitted: (_) => _addEvent(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _addEvent,
                    label: const Text("＋"),
                  ),
                ],
              ),
              
              if (selectedEventIndex != null) ...[
                const SizedBox(height: 16),
                _buildEventDetails(),
              ],
            ] else ...[
              Container(
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    "請先選擇一個故事線",
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            Text(
              "中箱：故事的事件。",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventRow(StoryEventData event, int index) {
    final isSelected = event.storyEventUUID == selectedEventID;
    final isEditing = event.storyEventUUID == editingEventID;
    
    return LongPressDraggable<OutlineDragData>(
      data: OutlineDragData(
        id: event.storyEventUUID,
        type: OutlineDragType.event,
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
                Icons.event_note, 
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
                      event.storyEvent.isEmpty ? "(未命名事件)" : event.storyEvent,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${event.scenes.length} 個場景",
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
        child: _buildEventListTile(event, index, isSelected, isEditing),
      ),
      child: DragTarget<OutlineDragData>(
        onWillAcceptWithDetails: (details) {
          final dragData = details.data;
          if (dragData.type == OutlineDragType.event) {
            return dragData.currentIndex != index;
          } else if (dragData.type == OutlineDragType.scene) {
            return true;
          }
          return false;
        },
        onAcceptWithDetails: (details) {
          final dragData = details.data;
          if (dragData.type == OutlineDragType.event && selectedStorylineIndex != null) {
            _moveEventByDrag(selectedStorylineIndex!, dragData.currentIndex, index);
          } else if (dragData.type == OutlineDragType.scene && selectedStorylineIndex != null) {
            _moveSceneToEvent(dragData.id, selectedStorylineIndex!, index);
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isHighlighted = candidateData.isNotEmpty;
          return Container(
            key: ValueKey(event.storyEventUUID),
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
            child: _buildEventListTile(event, index, isSelected, isEditing),
          );
        },
      ),
    );
  }
  
  Widget _buildEventListTile(StoryEventData event, int index, bool isSelected, bool isEditing) {
    return ListTile(
      leading: Icon(
        Icons.event_note,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
        size: 24,
      ),
      title: isEditing
          ? TextField(
              autofocus: true,
              controller: TextEditingController(text: event.storyEvent)
                ..selection = TextSelection.fromPosition(
                  TextPosition(offset: event.storyEvent.length),
                ),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onSubmitted: (value) {
                setState(() {
                  event.storyEvent = value.trim().isEmpty 
                      ? "(未命名事件)" 
                      : value.trim();
                  editingEventID = null;
                });
                _notifyChange();
              },
              onEditingComplete: () {
                setState(() {
                  editingEventID = null;
                });
              },
            )
          : GestureDetector(
              onDoubleTap: () {
                setState(() {
                  editingEventID = event.storyEventUUID;
                });
              },
              child: Text(
                event.storyEvent.isEmpty ? "(未命名事件)" : event.storyEvent,
                style: isSelected
                    ? TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
              ),
            ),
      subtitle: Text(
        "${event.scenes.length} 個場景",
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                editingEventID = event.storyEventUUID;
              });
            },
            icon: const Icon(Icons.edit, size: 20),
            tooltip: "重新命名",
          ),
          IconButton(
            onPressed: () => _deleteEvent(event.storyEventUUID, selectedStorylineIndex!),
            icon: Icon(
              Icons.delete,
              size: 20,
              color: Theme.of(context).colorScheme.error,
            ),
            tooltip: "刪除事件",
          ),
        ],
      ),
      onTap: () {
        setState(() {
          selectedEventID = event.storyEventUUID;
          _updateSelectionAfterEventChange();
        });
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
                  onChanged: (value) {
                    setState(() {
                      event.storyEvent = value;
                    });
                    _notifyChange();
                  },
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
                  onChanged: (value) {
                    setState(() {
                      event.conflictPoint = value;
                    });
                    _notifyChange();
                  },
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            _buildTagListEditor(
              title: "預設人物",
              items: event.people,
              controller: newEventPersonController,
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
            
            _buildTagListEditor(
              title: "預設物件",
              items: event.item,
              controller: newEventItemController,
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
                  onChanged: (value) {
                    setState(() {
                      event.memo = value;
                    });
                    _notifyChange();
                  },
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
                            : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                        width: isHighlighted ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: isHighlighted
                          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1)
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
              
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: newSceneController,
                      decoration: InputDecoration(
                        hintText: "新增場景名稱",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
                      ),
                      onSubmitted: (_) => _addScene(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _addScene,
                    label: const Text("＋"),
                  ),
                ],
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
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
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
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
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
    
    return LongPressDraggable<OutlineDragData>(
      data: OutlineDragData(
        id: scene.sceneUUID,
        type: OutlineDragType.scene,
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
          width: 320,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.tertiary,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.theater_comedy,
                color: Theme.of(context).colorScheme.onTertiaryContainer,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      scene.sceneName.isEmpty ? "(未命名場景)" : scene.sceneName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                        fontSize: 16,
                      ),
                    ),
                    if (scene.time.isNotEmpty || scene.location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (scene.time.isNotEmpty) ...[
                            Icon(Icons.access_time, size: 12, color: Theme.of(context).colorScheme.onTertiaryContainer),
                            const SizedBox(width: 4),
                            Text(scene.time, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onTertiaryContainer)),
                          ],
                          if (scene.time.isNotEmpty && scene.location.isNotEmpty) 
                            Text(" • ", style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onTertiaryContainer)),
                          if (scene.location.isNotEmpty) ...[
                            Icon(Icons.location_on, size: 12, color: Theme.of(context).colorScheme.onTertiaryContainer),
                            const SizedBox(width: 4),
                            Text(scene.location, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onTertiaryContainer)),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildSceneListTile(scene, index, isSelected, isEditing),
      ),
      child: DragTarget<OutlineDragData>(
        onWillAcceptWithDetails: (details) {
          final dragData = details.data;
          if (dragData.type == OutlineDragType.scene) {
            return dragData.currentIndex != index;
          }
          return false;
        },
        onAcceptWithDetails: (details) {
          final dragData = details.data;
          if (dragData.type == OutlineDragType.scene && selectedStorylineIndex != null && selectedEventIndex != null) {
            _moveSceneByDrag(selectedStorylineIndex!, selectedEventIndex!, dragData.currentIndex, index);
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isHighlighted = candidateData.isNotEmpty;
          return Container(
            key: ValueKey(scene.sceneUUID),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                  : (isHighlighted
                      ? Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5)
                      : Colors.transparent),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                ),
              ),
              borderRadius: isHighlighted ? BorderRadius.circular(8) : null,
            ),
            child: _buildSceneListTile(scene, index, isSelected, isEditing),
          );
        },
      ),
    );
  }
  
  Widget _buildSceneListTile(SceneData scene, int index, bool isSelected, bool isEditing) {
    return ListTile(
      leading: Icon(
        Icons.theater_comedy,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
        size: 24,
      ),
      title: isEditing
          ? TextField(
              autofocus: true,
              controller: TextEditingController(text: scene.sceneName)
                ..selection = TextSelection.fromPosition(
                  TextPosition(offset: scene.sceneName.length),
                ),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onSubmitted: (value) {
                setState(() {
                  scene.sceneName = value.trim().isEmpty 
                      ? "(未命名場景)" 
                      : value.trim();
                  editingSceneID = null;
                });
                _notifyChange();
              },
              onEditingComplete: () {
                setState(() {
                  editingSceneID = null;
                });
              },
            )
          : GestureDetector(
              onDoubleTap: () {
                setState(() {
                  editingSceneID = scene.sceneUUID;
                });
              },
              child: Text(
                scene.sceneName.isEmpty ? "(未命名場景)" : scene.sceneName,
                style: isSelected
                    ? TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
              ),
            ),
      subtitle: Row(
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
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                editingSceneID = scene.sceneUUID;
              });
            },
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
      onTap: () {
        setState(() {
          selectedSceneID = scene.sceneUUID;
          _syncAllControllers();
        });
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
                  onChanged: (value) {
                    setState(() {
                      scene.sceneName = value;
                    });
                    _notifyChange();
                  },
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
                        onChanged: (value) {
                          setState(() {
                            scene.time = value;
                          });
                          _notifyChange();
                        },
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
                        onChanged: (value) {
                          setState(() {
                            scene.location = value;
                          });
                          _notifyChange();
                        },
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
                        onChanged: (value) {
                          setState(() {
                            scene.focusPoint = value;
                          });
                          _notifyChange();
                        },
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
                        onChanged: (value) {
                          setState(() {
                            scene.conflictPoint = value;
                          });
                          _notifyChange();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            _buildTagListEditor(
              title: "人物",
              items: scene.people,
              controller: newPersonController,
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
            
            _buildTagListEditor(
              title: "物件",
              items: scene.item,
              controller: newItemController,
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
            
            _buildTagListEditor(
              title: "行動",
              items: scene.doingThings,
              controller: newDoingController,
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
                  onChanged: (value) {
                    setState(() {
                      scene.memo = value;
                    });
                    _notifyChange();
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // MARK: - 小型編輯元件
  Widget _buildTagListEditor({
    required String title,
    required List<String> items,
    required TextEditingController controller,
    required ValueChanged<String> onAdd,
    required ValueChanged<int> onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        
        if (items.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Chip(
                label: Text(item),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () => onRemove(index),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
        
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: "新增$title",
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (value) {
                  final trimmed = value.trim();
                  if (trimmed.isNotEmpty) {
                    onAdd(trimmed);
                    controller.clear();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) {
                  onAdd(value);
                  controller.clear();
                }
              },
              icon: const Icon(Icons.add_circle, color: Colors.green),
              tooltip: "新增$title",
            ),
          ],
        ),
      ],
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
