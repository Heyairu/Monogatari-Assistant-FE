import "package:flutter/material.dart";
import "package:file_picker/file_picker.dart";
import "dart:io";
import "package:path_provider/path_provider.dart";
import "package:uuid/uuid.dart";

// MARK: - 拖放數據類型

class LocationDragData {
  final String locationId;
  final String locationName;
  
  LocationDragData({
    required this.locationId,
    required this.locationName,
  });
}

// MARK: - 資料結構

class LocationCustomize {
  String id;
  String key;
  String val;

  LocationCustomize({
    String? id,
    this.key = "",
    this.val = "",
  }) : id = id ?? Uuid().v4();

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "key": key,
      "val": val,
    };
  }

  factory LocationCustomize.fromJson(Map<String, dynamic> json) {
    return LocationCustomize(
      id: json["id"] as String?,
      key: json["key"] as String? ?? "",
      val: json["val"] as String? ?? "",
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationCustomize &&
        other.id == id &&
        other.key == key &&
        other.val == val;
  }

  @override
  int get hashCode => id.hashCode ^ key.hashCode ^ val.hashCode;
}

class LocationData {
  String id;
  String localName;
  String localType;
  List<LocationCustomize> customVal;
  String note;
  List<LocationData> child;

  LocationData({
    String? id,
    this.localName = "",
    this.localType = "",
    List<LocationCustomize>? customVal,
    this.note = "",
    List<LocationData>? child,
  }) : id = id ?? Uuid().v4(),
        customVal = customVal ?? [],
        child = child ?? [];

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "localName": localName,
      "localType": localType,
      "customVal": customVal.map((e) => e.toJson()).toList(),
      "note": note,
      "child": child.map((e) => e.toJson()).toList(),
    };
  }

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      id: json["id"] as String?,
      localName: json["localName"] as String? ?? "",
      localType: json["localType"] as String? ?? "",
      customVal: (json["customVal"] as List<dynamic>?)
          ?.map((e) => LocationCustomize.fromJson(e as Map<String, dynamic>))
          .toList(),
      note: json["note"] as String? ?? "",
      child: (json["child"] as List<dynamic>?)
          ?.map((e) => LocationData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationData &&
        other.id == id &&
        other.localName == localName &&
        other.localType == localType &&
        _listEquals(other.customVal, customVal) &&
        other.note == note &&
        _listEquals(other.child, child);
  }

  @override
  int get hashCode {
    return id.hashCode ^
        localName.hashCode ^
        localType.hashCode ^
        customVal.hashCode ^
        note.hashCode ^
        child.hashCode;
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class TemplatePreset {
  String id;
  String name;    // == WorldType
  String type;    // == WorldType
  List<String> keys;

  TemplatePreset({
    String? id,
    required this.name,
    required this.type,
    List<String>? keys,
  }) : id = id ?? Uuid().v4(),
        keys = keys ?? [];

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "type": type,
      "keys": keys,
    };
  }

  factory TemplatePreset.fromJson(Map<String, dynamic> json) {
    return TemplatePreset(
      id: json["id"] as String?,
      name: json["name"] as String? ?? "",
      type: json["type"] as String? ?? "",
      keys: (json["keys"] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TemplatePreset &&
        other.id == id &&
        other.name == name &&
        other.type == type &&
        _listEquals(other.keys, keys);
  }

  @override
  int get hashCode {
    return id.hashCode ^ name.hashCode ^ type.hashCode ^ keys.hashCode;
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// MARK: - XML Codec（WorldSettings）
class WorldSettingsCodec {
  static String _escape(String s) {
    return s
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll("'", "&apos;")
        .replaceAll("\"", "&quot;");
  }

  static String _unescape(String s) {
    return s
        .replaceAll("&apos;", "'")
        .replaceAll("&quot;", "\"")
        .replaceAll("&gt;", ">")
        .replaceAll("&lt;", "<")
        .replaceAll("&amp;", "&");
  }

  static String? saveXML(List<LocationData> locations) {
    // 取得需要輸出的前（忽略「全部」）
    final roots = <LocationData>[];
    for (final loc in locations) {
      if (loc.localName == "全部") {
        roots.addAll(loc.child);
      } else {
        roots.add(loc);
      }
    }
    
    if (roots.isEmpty) return null;

    var xml = "";
    xml += "<Type>\n";
    xml += "  <Name>WorldSettings</Name>\n";
    for (final root in roots) {
      xml += _xmlLocation(root, "  ");
    }
    xml += "</Type>\n";
    return xml;
  }

  static String _xmlLocation(LocationData loc, String indent) {
    var xml = "";
    xml += "$indent<Location>\n";
    xml += "$indent  <LocalName>${_escape(loc.localName)}</LocalName>\n";
    if (loc.localType.isNotEmpty) {
      xml += "$indent  <LocalType>${_escape(loc.localType)}</LocalType>\n";
    }
    if (loc.customVal.isNotEmpty) {
      for (final kv in loc.customVal) {
        final k = _escape(kv.key);
        final v = _escape(kv.val);
        xml += "$indent  <Key Name=\"$k\">$v</Key>\n";
      }
    }
    if (loc.note.isNotEmpty) {
      xml += "$indent  <Memo>${_escape(loc.note)}</Memo>\n";
    }
    if (loc.child.isNotEmpty) {
      for (final child in loc.child) {
        xml += _xmlLocation(child, "$indent  ");
      }
    }
    xml += "$indent</Location>\n";
    return xml;
  }

  static List<LocationData>? loadXML(String xml) {
    final roots = <LocationData>[];
    final stack = <LocationData>[];
    var currentKeyName = "";
    var text = "";
    var path = <String>[];
    var isWorldBlock = false;

    // 簡單的XML解析
    final tagPattern = RegExp(r"<(/?)([^>]+)>");
    final matches = tagPattern.allMatches(xml);
    var lastEnd = 0;

    for (final match in matches) {
      // 處理標籤間的文字內容
      if (match.start > lastEnd) {
        text += xml.substring(lastEnd, match.start);
      }

      final isClosing = match.group(1) == "/";
      final tagContent = match.group(2)!;
      final tagName = tagContent.split(" ")[0];

      if (!isClosing) {
        // 開始標籤
        path.add(tagName);
        text = "";

        if (tagName == "Location") {
          stack.add(LocationData());
        } else if (tagName == "Key") {
          // 解析屬性
          final nameMatch = RegExp(r'Name="([^"]*)"').firstMatch(tagContent);
          currentKeyName = nameMatch?.group(1) ?? "";
        }
      } else {
        // 結束標籤
        final trimmed = _unescape(text.trim());
        final joinedPath = path.join("/");

        switch (tagName) {
          case "Name":
            if (joinedPath == "Type/Name") {
              isWorldBlock = (trimmed == "WorldSettings");
            }
            break;

          case "LocalName":
            if (stack.isNotEmpty) {
              stack.last.localName = trimmed;
            }
            break;

          case "LocalType":
            if (stack.isNotEmpty) {
              stack.last.localType = trimmed;
            }
            break;

          case "Key":
            if (stack.isNotEmpty) {
              stack.last.customVal.add(LocationCustomize(
                key: currentKeyName,
                val: trimmed,
              ));
            }
            currentKeyName = "";
            break;

          case "Memo":
            if (stack.isNotEmpty) {
              stack.last.note = trimmed;
            }
            break;

          case "Location":
            if (stack.isNotEmpty) {
              final finished = stack.removeLast();
              if (stack.isEmpty) {
                roots.add(finished);
              } else {
                stack.last.child.add(finished);
              }
            }
            break;
        }

        path.removeLast();
        text = "";
      }

      lastEnd = match.end;
    }

    // 處理剩餘文字
    if (lastEnd < xml.length) {
      text += xml.substring(lastEnd);
    }

    if (isWorldBlock) {
      // 包一層「全部」根
      return [LocationData(localName: "全部", child: roots)];
    }
    return null;
  }
}

// MARK: - 主視圖

class WorldSettingsView extends StatefulWidget {
  final List<LocationData> locations;
  final Function(List<LocationData>) onChanged;

  const WorldSettingsView({
    super.key,
    required this.locations,
    required this.onChanged,
  });

  @override
  State<WorldSettingsView> createState() => _WorldSettingsViewState();
}

class _WorldSettingsViewState extends State<WorldSettingsView> {
  String? selectedNodeId;
  String? lastSelectedNodeId; // 記錄上次選取的節點
  String? editingNodeId;
  String newName = "";
  String tempCustomKey = "";
  String tempCustomVal = "";
  List<TemplatePreset> templatePresets = [];
  String selectedPresetName = "空白";
  String renamePresetText = "";
  
  // 拖動狀態與游標資訊
  bool _isDragging = false;
  String? _draggingLocationId;
  double? _currentCursorY;
  final Map<String, GlobalKey> _itemKeys = {};
  
  // 控制器
  final TextEditingController newNameController = TextEditingController();
  final TextEditingController tempKeyController = TextEditingController();
  final TextEditingController tempValController = TextEditingController();
  final TextEditingController locationNameController = TextEditingController();
  final TextEditingController locationTypeController = TextEditingController();
  final TextEditingController locationNoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    newNameController.text = newName;
    tempKeyController.text = tempCustomKey;
    tempValController.text = tempCustomVal;
    
    // 移除自動添加「全部」的邏輯
    // 因為 main.dart 已經在初始化和讀檔時處理了
    
    _loadTemplatesFromDisk();
  }

  @override
  void dispose() {
    newNameController.dispose();
    tempKeyController.dispose();
    tempValController.dispose();
    locationNameController.dispose();
    locationTypeController.dispose();
    locationNoteController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    widget.onChanged(widget.locations);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 標題列
            Row(
              children: [
                Text(
                  "世界設定",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.grid_view),
                      SizedBox(width: 4),
                      Text("模板管理"),
                    ],
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case "import":
                        _importTemplate();
                        break;
                      case "exportSelected":
                        _exportSelectedTemplate();
                        break;
                      case "exportAll":
                        _exportAllTemplates();
                        break;
                      case "save":
                        _saveCurrentAsPreset();
                        break;
                      case "rename":
                        _showRenamePresetDialog();
                        break;
                      case "delete":
                        _deleteSelectedPreset();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: "import",
                      child: Text("匯入模板檔案…"),
                    ),
                    PopupMenuItem(
                      value: "exportSelected",
                      enabled: _selectedPreset != null,
                      child: const Text("匯出選取模板…"),
                    ),
                    PopupMenuItem(
                      value: "exportAll",
                      enabled: templatePresets.isNotEmpty,
                      child: const Text("匯出全部模板…"),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: "save",
                      child: Text("儲存預設模板…"),
                    ),
                    PopupMenuItem(
                      value: "rename",
                      enabled: _selectedPreset != null,
                      child: const Text("更改預設名稱…"),
                    ),
                    PopupMenuItem(
                      value: "delete",
                      enabled: _selectedPreset != null && _selectedPreset!.name != "空白",
                      child: const Text("刪除選取預設"),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 上方樹狀列表區域
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "地點結構",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              // 點擊容器空白區域時取消選取
                              setState(() {
                                selectedNodeId = null;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                ),
                                borderRadius: BorderRadius.circular(8),
                                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                              ),
                              child: widget.locations.isEmpty
                                  ? Center(
                                      child: Text(
                                        "尚無地點，請新增第一個地點",
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          fontSize: 14,
                                        ),
                                      ),
                                    )
                                  : ListView(
                                      padding: EdgeInsets.all(8),
                                      children: widget.locations
                                          .map((location) => _buildLocationTreeItem(location, 0))
                                          .toList(),
                                    ),
                            ),
                          ),
                        ),
                        // 新增地點輸入框
                        Expanded(
                          flex: 0,
                          child: SizedBox(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: newNameController,
                                      decoration: InputDecoration(
                                        labelText: "新地點名稱",
                                        hintText: selectedNodeId != null ? "作為子地點添加" : "作為頂層地點添加",
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          newName = value;
                                        });
                                      },
                                      onSubmitted: (_) {
                                        if (newName.trim().isNotEmpty) {
                                          _addLocation();
                                        }
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: newName.trim().isEmpty ? null : _addLocation,
                                    icon: Icon(
                                      Icons.add_circle,
                                      color: newName.trim().isEmpty ? Colors.grey : Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // 下方詳情面板
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "地點詳情",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: Theme.of(context).colorScheme.surfaceContainerLowest,
                            ),
                            padding: const EdgeInsets.all(16),
                            child: _buildDetailPanel(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationTreeItem(LocationData location, int depth) {
    final isSelected = selectedNodeId == location.id;
    final isEditing = editingNodeId == location.id;
    
    // 所有節點都可以拖動和編輯
    Widget cardWidget = Card(
      elevation: 0,
      color: isSelected 
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
          : Theme.of(context).colorScheme.surfaceContainerLowest,
      child: ListTile(
        dense: true,
        leading: Icon(
          Icons.location_on_outlined,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: isEditing
            ? TextField(
                autofocus: true,
                controller: TextEditingController(text: location.localName),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                onSubmitted: (value) {
                  _renameNode(location.id, value);
                  setState(() {
                    editingNodeId = null;
                  });
                },
                onEditingComplete: () {
                  setState(() {
                    editingNodeId = null;
                  });
                },
              )
            : GestureDetector(
                onDoubleTap: () {
                  setState(() {
                    editingNodeId = location.id;
                  });
                },
                child: Text(
                  location.localName.isEmpty ? "（未命名）" : location.localName,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected 
                        ? Theme.of(context).colorScheme.primary 
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
        subtitle: Text(
          "${location.child.length} 個子節點",
          style: Theme.of(context).textTheme.bodySmall,
        ),
        onTap: () {
          setState(() {
            selectedNodeId = location.id;
            lastSelectedNodeId = location.id; // 記錄上次選取
            _syncDetailControllers();
          });
        },
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.edit_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: () {
                setState(() {
                  editingNodeId = location.id;
                });
              },
              tooltip: "重新命名",
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 18,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => _deleteNode(location.id),
              tooltip: "刪除地點",
            ),
          ],
        ),
      ),
    );
    
    // 所有節點都可拖動
    Widget draggableWidget = LongPressDraggable<LocationDragData>(
      data: LocationDragData(
        locationId: location.id,
        locationName: location.localName,
      ),
      onDragStarted: () {
        setState(() {
          _isDragging = true;
          _draggingLocationId = location.id;
          _currentCursorY = null;
        });
      },
      onDragUpdate: (details) {
        setState(() {
          _currentCursorY = details.globalPosition.dy;
        });
      },
      onDragEnd: (_) {
          setState(() {
            _isDragging = false;
            _draggingLocationId = null;
            _currentCursorY = null;
          });
        },
        onDraggableCanceled: (_, __) {
          setState(() {
            _isDragging = false;
            _draggingLocationId = null;
            _currentCursorY = null;
          });
        },
        feedback: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 280,
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
                  Icons.location_on_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    location.localName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
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
          child: cardWidget,
        ),
        child: cardWidget,
      );
    
    final itemKey = _itemKeys.putIfAbsent(location.id, () => GlobalKey());

    // 包裝拖放目標
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          key: itemKey,
          margin: EdgeInsets.only(left: depth * 16.0, bottom: 4.0),
          child: DragTarget<LocationDragData>(
            onWillAcceptWithDetails: (details) {
              final dragData = details.data;
              // 不能拖到自己，不能拖到自己的後代
              if (dragData.locationId == location.id) return false;
              if (_isDescendant(dragData.locationId, location.id)) return false;
              return true;
            },
            onAcceptWithDetails: (details) {
              final dragData = details.data;
              final hoverZone = _getHoverZoneFor(location.id);
              String position;
              String message;
              if (hoverZone == "before") {
                position = "before";
                message = "「${dragData.locationName}」已移動到「${location.localName}」之前";
              } else if (hoverZone == "after") {
                position = "after";
                message = "「${dragData.locationName}」已移動到「${location.localName}」之後";
              } else {
                position = "child";
                message = "「${dragData.locationName}」已成為「${location.localName}」的子地點";
              }
              _moveLocationTo(dragData.locationId, location.id, position);
              setState(() {
                _currentCursorY = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            onLeave: (_) {
              setState(() {
                _currentCursorY = null;
              });
            },
            builder: (context, candidateData, rejectedData) {
              final hoverZone = _getHoverZoneFor(location.id);
              final isDraggingValid = _isDragging &&
                  _draggingLocationId != null &&
                  _draggingLocationId != location.id &&
                  !_isDescendant(_draggingLocationId!, location.id);
              final isHighlighted = hoverZone != null && isDraggingValid;

              // 根據當前 hoverZone 顯示分區
              Widget highlightOverlay = const SizedBox.shrink();
              if (isHighlighted) {
                highlightOverlay = LayoutBuilder(
                  builder: (context, constraints) {
                    final isBeforeActive = hoverZone == "before";
                    final isChildActive = hoverZone == "child";
                    final isAfterActive = hoverZone == "after";

                    final beforeColor = isBeforeActive
                        ? Theme.of(context).colorScheme.tertiary.withOpacity(0.4)
                        : Theme.of(context).colorScheme.tertiary.withOpacity(0.12);
                    final childColor = isChildActive
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.4)
                        : Theme.of(context).colorScheme.primary.withOpacity(0.12);
                    final afterColor = isAfterActive
                        ? Theme.of(context).colorScheme.secondary.withOpacity(0.4)
                        : Theme.of(context).colorScheme.secondary.withOpacity(0.12);

                    return Column(
                      children: [
                        // 上方區域 (30%) - 插入前
                        Container(
                          height: constraints.maxHeight * 0.3,
                          decoration: BoxDecoration(
                            color: beforeColor,
                            border: Border(
                              top: BorderSide(
                                color: Theme.of(context).colorScheme.tertiary,
                                width: isBeforeActive ? 3 : 1,
                              ),
                              bottom: BorderSide(
                                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Center(
                            child: isBeforeActive
                                ? Icon(
                                    Icons.arrow_upward,
                                    color: Theme.of(context).colorScheme.tertiary,
                                    size: 20,
                                  )
                                : null,
                          ),
                        ),
                        // 中間區域 (40%) - 成為子節點
                        Container(
                          height: constraints.maxHeight * 0.4,
                          decoration: BoxDecoration(
                            color: childColor,
                            border: Border.symmetric(
                              horizontal: BorderSide(
                                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Center(
                            child: isChildActive
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.subdirectory_arrow_right,
                                        color: Theme.of(context).colorScheme.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "成為子節點",
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        ),
                        // 下方區域 (30%) - 插入後
                        Container(
                          height: constraints.maxHeight * 0.3,
                          decoration: BoxDecoration(
                            color: afterColor,
                            border: Border(
                              top: BorderSide(
                                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                                width: 1,
                              ),
                              bottom: BorderSide(
                                color: Theme.of(context).colorScheme.secondary,
                                width: isAfterActive ? 3 : 1,
                              ),
                            ),
                          ),
                          child: Center(
                            child: isAfterActive
                                ? Icon(
                                    Icons.arrow_downward,
                                    color: Theme.of(context).colorScheme.secondary,
                                    size: 20,
                                  )
                                : null,
                          ),
                        ),
                      ],
                    );
                  },
                );
              }

              return Stack(
                children: [
                  draggableWidget,
                  if (isHighlighted)
                    Positioned.fill(child: highlightOverlay),
                ],
              );
            },
          ),
        ),
        
        // 子節點
        ...location.child.map((child) => _buildLocationTreeItem(child, depth + 1)),
      ],
    );
  }

  Widget _buildDetailPanel() {
    // 如果當前沒有選中節點，使用上次選取的節點
    final displayNodeId = selectedNodeId ?? lastSelectedNodeId;
    
    if (displayNodeId == null) {
      return const Center(
        child: Text("請選擇一個地點來編輯詳情"),
      );
    }

    final location = _getLocation(displayNodeId, widget.locations);
    if (location == null) {
      return const Center(
        child: Text("找不到該地點"),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 應用模板
          Row(
            children: [
              const Text("應用模板: "),
              Expanded(
                child: DropdownButton<String>(
                  value: selectedPresetName,
                  isExpanded: true,
                  items: templatePresets.map((preset) {
                    return DropdownMenuItem<String>(
                      value: preset.name,
                      child: Text(preset.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedPresetName = value ?? "空白";
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final preset = templatePresets.firstWhere(
                    (p) => p.name == selectedPresetName,
                    orElse: () => templatePresets.first,
                  );
                  _applyTemplateTo(location, preset);
                },
                child: const Text("確定"),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 名稱
          TextField(
            controller: locationNameController,
            decoration: const InputDecoration(
              labelText: "名稱",
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              location.localName = value;
              _notifyChange();
              setState(() {});
            },
          ),
          const SizedBox(height: 12),

          // 類型
          TextField(
            controller: locationTypeController,
            decoration: const InputDecoration(
              labelText: "類型",
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              location.localType = value;
              _notifyChange();
            },
          ),
          const SizedBox(height: 16),

          // 自訂值表
          const Text("自訂值表:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...location.customVal.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: item.key),
                      decoration: const InputDecoration(
                        labelText: "設定",
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        item.key = value;
                        _notifyChange();
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text("="),
                  ),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: item.val),
                      decoration: const InputDecoration(
                        labelText: "鍵值",
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        item.val = value;
                        _notifyChange();
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        location.customVal.removeAt(index);
                      });
                      _notifyChange();
                    },
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                  ),
                ],
              ),
            );
          }).toList(),

          // 新增自訂值
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: tempKeyController,
                  decoration: const InputDecoration(
                    labelText: "設定",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    setState(() {
                      tempCustomKey = value;
                    });
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text("="),
              ),
              Expanded(
                child: TextField(
                  controller: tempValController,
                  decoration: const InputDecoration(
                    labelText: "鍵值",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    setState(() {
                      tempCustomVal = value;
                    });
                  },
                ),
              ),
              IconButton(
                onPressed: tempCustomKey.isEmpty ? null : () {
                  setState(() {
                    location.customVal.add(LocationCustomize(
                      key: tempCustomKey,
                      val: tempCustomVal,
                    ));
                    tempCustomKey = "";
                    tempCustomVal = "";
                    tempKeyController.clear();
                    tempValController.clear();
                  });
                  _notifyChange();
                },
                icon: Icon(
                  Icons.add_circle,
                  color: tempCustomKey.isEmpty ? Colors.grey : Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 備註
          const Text("備註:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: locationNoteController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: 4,
            onChanged: (value) {
              location.note = value;
              _notifyChange();
            },
          ),
        ],
      ),
    );
  }

  // 模板管理相關方法
  TemplatePreset? get _selectedPreset {
    return templatePresets.where((p) => p.name == selectedPresetName).firstOrNull;
  }

  void _applyTemplateTo(LocationData location, TemplatePreset preset) {
    setState(() {
      location.localType = preset.type;
      location.localName = preset.name;
      location.customVal = preset.keys.map((key) => LocationCustomize(key: key, val: "")).toList();
      _syncDetailControllers();
    });
    _notifyChange();
  }

  void _saveCurrentAsPreset() {
    if (selectedNodeId == null) return;
    final location = _getLocation(selectedNodeId!, widget.locations);
    if (location == null) return;
    
    final worldType = location.localType.trim();
    if (worldType.isEmpty) return;
    
    final preset = TemplatePreset(
      name: worldType,
      type: worldType,
      keys: location.customVal.map((cv) => cv.key).toList(),
    );
    
    final existingIndex = templatePresets.indexWhere((p) => p.name == preset.name);
    if (existingIndex != -1) {
      _showOverwritePresetDialog(preset);
    } else {
      setState(() {
        templatePresets.add(preset);
        selectedPresetName = preset.name;
      });
      _saveTemplatesToDisk();
    }
  }

  void _showOverwritePresetDialog(TemplatePreset preset) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("儲存預設模板"),
        content: const Text("同名模板已存在，是否要覆蓋？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              final index = templatePresets.indexWhere((p) => p.name == preset.name);
              setState(() {
                templatePresets[index] = preset;
                selectedPresetName = preset.name;
              });
              _saveTemplatesToDisk();
            },
            child: const Text("覆蓋"),
          ),
        ],
      ),
    );
  }

  void _showRenamePresetDialog() {
    renamePresetText = selectedPresetName;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("更改預設名稱"),
        content: TextField(
          controller: TextEditingController(text: renamePresetText),
          decoration: const InputDecoration(labelText: "新模板名稱"),
          onChanged: (value) {
            renamePresetText = value;
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("取消"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _renameSelectedPreset(renamePresetText);
            },
            child: const Text("確定"),
          ),
        ],
      ),
    );
  }

  void _renameSelectedPreset(String newName) {
    final index = templatePresets.indexWhere((p) => p.name == selectedPresetName);
    if (index != -1) {
      setState(() {
        templatePresets[index].name = newName;
        templatePresets[index].type = newName;
        selectedPresetName = newName;
      });
      _saveTemplatesToDisk();
    }
  }

  void _deleteSelectedPreset() {
    final index = templatePresets.indexWhere((p) => p.name == selectedPresetName && p.name != "空白");
    if (index != -1) {
      setState(() {
        templatePresets.removeAt(index);
        selectedPresetName = templatePresets.isNotEmpty ? templatePresets.first.name : "";
      });
      _saveTemplatesToDisk();
    }
  }

  void _importTemplate() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["xml", "txt"],
    );
    
    if (result != null && result.files.single.path != null) {
      try {
        final file = File(result.files.single.path!);
        final xml = await file.readAsString();
        final presets = _parseAllTemplatesXML(xml);
        
        if (presets.isEmpty) {
          _showErrorDialog("匯入失敗：檔案中沒有找到任何 <Type> 節點。");
        } else {
          setState(() {
            // 合併：同名覆蓋
            for (final preset in presets) {
              final index = templatePresets.indexWhere((p) => p.name == preset.name);
              if (index != -1) {
                templatePresets[index] = preset;
              } else {
                templatePresets.add(preset);
              }
            }
            _ensureBlankPresetExists();
            if (presets.isNotEmpty) {
              selectedPresetName = presets.last.name;
            }
          });
          _saveTemplatesToDisk();
        }
      } catch (e) {
        _showErrorDialog("讀取檔案失敗：${e.toString()}");
      }
    }
  }

  void _exportSelectedTemplate() async {
    final preset = _selectedPreset;
    if (preset == null) return;
    
    final xml = _toXML(preset);
    await _exportToFile(xml, "${preset.name}.xml");
  }

  void _exportAllTemplates() async {
    final xml = templatePresets.map(_toXML).join("\n");
    await _exportToFile(xml, "AllTemplates.xml");
  }

  Future<void> _exportToFile(String content, String fileName) async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: "匯出檔案",
      fileName: fileName,
    );
    
    if (result != null) {
      try {
        final file = File(result);
        await file.writeAsString(content);
        _showSuccessDialog("檔案已匯出至：$result");
      } catch (e) {
        _showErrorDialog("匯出失敗：${e.toString()}");
      }
    }
  }

  // XML/Parse（模板檔案，與專案無關）
  String _toXML(TemplatePreset preset) {
    var xml = "<Type>\n";
    xml += "  <WorldType>${preset.type}</WorldType>\n";
    for (final key in preset.keys) {
      xml += "  <Key>$key</Key>\n";
    }
    xml += "</Type>";
    return xml;
  }

  TemplatePreset? _parseTemplateXML(String xml) {
    final worldTypeMatch = RegExp(r"<WorldType>(.*?)</WorldType>", dotAll: true).firstMatch(xml);
    final worldType = worldTypeMatch?.group(1)?.trim() ?? "";
    if (worldType.isEmpty) return null;

    final keyMatches = RegExp(r"<Key>(.*?)</Key>", dotAll: true).allMatches(xml);
    final keys = keyMatches.map((m) => m.group(1)?.trim() ?? "").toList();

    return TemplatePreset(name: worldType, type: worldType, keys: keys);
  }

  List<TemplatePreset> _parseAllTemplatesXML(String xml) {
    final typeMatches = RegExp(r"<Type>([\s\S]*?)</Type>", dotAll: true).allMatches(xml);
    return typeMatches
        .map((match) => _parseTemplateXML("<Type>${match.group(1)}</Type>"))
        .where((preset) => preset != null)
        .cast<TemplatePreset>()
        .toList();
  }

  // 持久化（沙盒 Application Support/Data/WorldTemplate.xml）
  Future<String> _getDataDirectoryPath() async {
    final appDir = await getApplicationSupportDirectory();
    final dataDir = Directory("${appDir.path}/Data");
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }
    return dataDir.path;
  }

  Future<String> get _worldTemplateFilePath async {
    final dataPath = await _getDataDirectoryPath();
    return "$dataPath/WorldTemplate.xml";
  }

  Future<void> _saveTemplatesToDisk() async {
    try {
      final xml = templatePresets.map(_toXML).join("\n");
      final filePath = await _worldTemplateFilePath;
      final file = File(filePath);
      await file.writeAsString(xml);
    } catch (e) {
      print("儲存模板失敗：${e.toString()}");
    }
  }

  Future<void> _loadTemplatesFromDisk() async {
    try {
      final filePath = await _worldTemplateFilePath;
      final file = File(filePath);
      
      if (!await file.exists()) {
        _ensureBlankPresetExists();
        return;
      }
      
      final xml = await file.readAsString();
      final presets = _parseAllTemplatesXML(xml);
      
      if (presets.isEmpty) {
        print("讀檔成功但解析為空，保留現有預設。");
        _ensureBlankPresetExists();
        return;
      }
      
      setState(() {
        templatePresets = presets;
        _ensureBlankPresetExists();
        selectedPresetName = templatePresets.isNotEmpty ? templatePresets.first.name : "空白";
      });
    } catch (e) {
      print("讀取模板失敗：${e.toString()}");
      _ensureBlankPresetExists();
    }
  }

  void _ensureBlankPresetExists() {
    if (!templatePresets.any((p) => p.name == "空白")) {
      templatePresets.insert(0, TemplatePreset(name: "空白", type: "", keys: []));
    }
  }

  // TreeView 操作
  void _addLocation() {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    
    // 根據是否有選中節點來決定添加位置
    if (selectedNodeId != null) {
      // 有選中節點：作為選中節點的子節點添加
      _addChild(selectedNodeId!, trimmed);
    } else {
      // 沒有選中節點：作為頂層節點添加
      setState(() {
        widget.locations.add(LocationData(localName: trimmed));
        newName = "";
        newNameController.clear();
      });
      _notifyChange();
    }
  }

  void _addChild(String parentId, String name) {
    _addChildRecursive(parentId, name, widget.locations);
    setState(() {
      newName = "";
      newNameController.clear();
    });
    _notifyChange();
  }

  void _addChildRecursive(String parentId, String name, List<LocationData> locations) {
    for (final location in locations) {
      if (location.id == parentId) {
        location.child.add(LocationData(localName: name));
        return;
      }
      _addChildRecursive(parentId, name, location.child);
    }
  }

  void _renameNode(String id, String newName) {
    _renameNodeRecursive(id, newName, widget.locations);
    _notifyChange();
    setState(() {});
  }

  void _renameNodeRecursive(String id, String newName, List<LocationData> locations) {
    for (final location in locations) {
      if (location.id == id) {
        location.localName = newName;
        return;
      }
      _renameNodeRecursive(id, newName, location.child);
    }
  }

  // MARK: - 拖動相關方法
  
  String? _getHoverZoneFor(String locationId) {
    if (!_isDragging || _currentCursorY == null) return null;
    final key = _itemKeys[locationId];
    final context = key?.currentContext;
    if (context == null) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return null;
    if (!renderObject.hasSize) return null;

    final box = renderObject;
    final topLeft = box.localToGlobal(Offset.zero);
    final top = topLeft.dy;
    final height = box.size.height;
    final bottom = top + height;
    final cursorY = _currentCursorY!;

    if (cursorY < top || cursorY > bottom) return null;

    double relativeY = (cursorY - top) / height;
    if (relativeY < 0) {
      relativeY = 0;
    } else if (relativeY > 1) {
      relativeY = 1;
    }
    if (relativeY < 0.3) {
      return "before";
    }
    if (relativeY > 0.7) {
      return "after";
    }
    return "child";
  }

  // 檢查 targetId 是否為 sourceId 的後代
  bool _isDescendant(String sourceId, String targetId) {
    bool checkDescendant(LocationData node) {
      if (node.id == targetId) {
        return true;
      }
      for (var child in node.child) {
        if (checkDescendant(child)) {
          return true;
        }
      }
      return false;
    }
    
    LocationData? sourceNode = _findLocationById(sourceId);
    if (sourceNode == null) return false;
    
    return checkDescendant(sourceNode);
  }
  
  // 查找節點
  LocationData? _findLocationById(String id) {
    LocationData? search(List<LocationData> nodes) {
      for (var node in nodes) {
        if (node.id == id) return node;
        var found = search(node.child);
        if (found != null) return found;
      }
      return null;
    }
    return search(widget.locations);
  }
  
  // 移動節點到目標位置
  // position: "before" (排序至該項目上), "child" (設為副目錄), "after" (排序至該項目下)
  void _moveLocationTo(String sourceId, String targetId, String position) {
    // 防止拖到自己或自己的後代
    if (sourceId == targetId || _isDescendant(sourceId, targetId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("無法移動到自己或自己的後代節點"),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    setState(() {
      // 1. 找到並移除源節點
      LocationData? sourceNode;
      
      bool removeFromTree(List<LocationData> nodes) {
        for (int i = 0; i < nodes.length; i++) {
          if (nodes[i].id == sourceId) {
            sourceNode = nodes[i];
            nodes.removeAt(i);
            return true;
          }
          if (removeFromTree(nodes[i].child)) {
            return true;
          }
        }
        return false;
      }
      removeFromTree(widget.locations);
      
      if (sourceNode == null) return;
      
      // 2. 根據 position 添加到目標位置
      bool success = false;
      
      if (position == "child") {
        // 作為子節點添加
        bool addAsChild(List<LocationData> nodes) {
          for (var node in nodes) {
            if (node.id == targetId) {
              node.child.add(sourceNode!);
              return true;
            }
            if (addAsChild(node.child)) {
              return true;
            }
          }
          return false;
        }
        success = addAsChild(widget.locations);
      } else {
        // before 或 after: 在同級列表中插入
        bool insertInList(List<LocationData> nodes) {
          for (int i = 0; i < nodes.length; i++) {
            if (nodes[i].id == targetId) {
              if (position == "before") {
                nodes.insert(i, sourceNode!);
              } else { // after
                nodes.insert(i + 1, sourceNode!);
              }
              return true;
            }
            if (insertInList(nodes[i].child)) {
              return true;
            }
          }
          return false;
        }
        success = insertInList(widget.locations);
      }
      
      if (!success) {
        // 如果沒找到目標，恢復原節點
        widget.locations.add(sourceNode!);
      }
      
      _notifyChange();
    });
  }

  void _deleteNode(String id) {
    if (_removeNodeRecursive(id, widget.locations)) {
      setState(() {
        if (selectedNodeId == id) {
          selectedNodeId = null;
        }
      });
      _notifyChange();
    }
  }

  bool _removeNodeRecursive(String id, List<LocationData> locations) {
    for (int i = 0; i < locations.length; i++) {
      if (locations[i].id == id) {
        locations.removeAt(i);
        return true;
      }
      if (_removeNodeRecursive(id, locations[i].child)) {
        return true;
      }
    }
    return false;
  }

  LocationData? _getLocation(String id, List<LocationData> locations) {
    for (final location in locations) {
      if (location.id == id) return location;
      final found = _getLocation(id, location.child);
      if (found != null) return found;
    }
    return null;
  }

  void _syncDetailControllers() {
    if (selectedNodeId == null) return;
    final location = _getLocation(selectedNodeId!, widget.locations);
    if (location != null) {
      locationNameController.text = location.localName;
      locationTypeController.text = location.localType;
      locationNoteController.text = location.note;
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("錯誤"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("確定"),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("成功"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("確定"),
          ),
        ],
      ),
    );
  }
}
