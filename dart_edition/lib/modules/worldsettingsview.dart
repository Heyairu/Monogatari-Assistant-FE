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
import "package:file_picker/file_picker.dart";
import "dart:io";
import "dart:convert";
import "dart:math" as math;
import "package:path_provider/path_provider.dart";
import "package:uuid/uuid.dart";
import "package:xml/xml.dart" as xml;
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../bin/ui_library.dart";
import "package:logging/logging.dart";
import "../models/world_settings_data.dart";
import "../presentation/providers/project_state_providers.dart";

export "../models/world_settings_data.dart";

final _log = Logger("WorldSettingsView");

// MARK: - 拖放數據類型

class LocationDragData {
  final String locationId;
  final String locationName;

  LocationDragData({required this.locationId, required this.locationName});
}

extension WorldNodeTypeUiX on WorldNodeType {
  IconData get icon {
    switch (this) {
      case WorldNodeType.location:
        return Icons.location_on_outlined;
      case WorldNodeType.organization:
        return Icons.groups_outlined;
      case WorldNodeType.rule:
        return Icons.gavel_outlined;
      case WorldNodeType.item:
        return Icons.inventory_2_outlined;
    }
  }
}

class TemplatePreset {
  String id;
  String name; // == WorldType
  String type; // == WorldType
  List<String> keys;

  TemplatePreset({
    String? id,
    required this.name,
    required this.type,
    List<String>? keys,
  }) : id = id ?? Uuid().v4(),
       keys = keys ?? [];

  Map<String, dynamic> toJson() {
    return {"id": id, "name": name, "type": type, "keys": keys};
  }

  factory TemplatePreset.fromJson(Map<String, dynamic> json) {
    return TemplatePreset(
      id: json["id"] as String?,
      name: json["name"] as String? ?? "",
      type: json["type"] as String? ?? "",
      keys: (json["keys"] as List<dynamic>?)?.map((e) => e.toString()).toList(),
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

  static String? saveXML(List<LocationData> locations) {
    if (locations.isEmpty) return null;

    final builder = xml.XmlBuilder();
    builder.element(
      "Type",
      nest: () {
        builder.element("Name", nest: "WorldSettings");
        for (final loc in locations) {
          _buildLocation(builder, loc);
        }
      },
    );

    return builder.buildDocument().toXmlString(pretty: true, indent: "  ");
  }

  static void _buildLocation(xml.XmlBuilder builder, LocationData loc) {
    builder.element(
      "Location",
      nest: () {
        _writeTextElement(builder, "LocalName", loc.localName);
        _writeTextElement(builder, "NodeType", loc.nodeType.xmlValue);
        if (loc.localType.isNotEmpty) {
          _writeTextElement(builder, "LocalType", loc.localType);
        }
        if (loc.customVal.isNotEmpty) {
          for (final kv in loc.customVal) {
            builder.element(
              "Key",
              attributes: {"Name": kv.key},
              nest: () {
                builder.text(_encodeNewlines(kv.val));
              },
            );
          }
        }
        if (loc.note.isNotEmpty) {
          _writeTextElement(builder, "Memo", loc.note);
        }
        if (loc.child.isNotEmpty) {
          for (final child in loc.child) {
            _buildLocation(builder, child);
          }
        }
      },
    );
  }

  static List<LocationData>? loadXML(String content) {
    try {
      final document = xml.XmlDocument.parse(content);

      final typeElement = document.findAllElements("Type").firstOrNull;
      if (typeElement == null) return null;

      final nameElement = typeElement.findAllElements("Name").firstOrNull;
      if (nameElement?.innerText != "WorldSettings") return null;

      final roots = <LocationData>[];

      // Type"s direct children that are 'Location" are roots
      // Using findElements to get only direct children, avoiding infinite recursion issues
      // if we were to use findAllElements on the root
      for (final locationNode in typeElement.findElements("Location")) {
        roots.add(_parseLocation(locationNode));
      }

      return roots;
    } catch (e) {
      _log.severe("Error parsing WorldSettings XML: $e");
      return null;
    }
  }

  static LocationData _parseLocation(xml.XmlElement node) {
    final localName = _readElementText(
      node.findAllElements("LocalName").firstOrNull,
    );
    final nodeType = parseWorldNodeType(
      _readElementText(node.findAllElements("NodeType").firstOrNull),
    );
    final localType = _readElementText(
      node.findAllElements("LocalType").firstOrNull,
    );
    final note = _readElementText(node.findAllElements("Memo").firstOrNull);
    final customVal = <LocationCustomize>[];
    final child = <LocationData>[];

    // Parse custom values (Key)
    // Keys are direct children of Location
    for (final keyNode in node.findElements("Key")) {
      final key = keyNode.getAttribute("Name") ?? "";
      final val = _readElementText(keyNode);
      customVal.add(LocationCustomize(key: key, val: val));
    }

    // Parse children locations
    // We must use findElements to only get direct children, otherwise we might grab grandchildren
    for (final childNode in node.findElements("Location")) {
      child.add(_parseLocation(childNode));
    }

    return LocationData(
      localName: localName,
      localType: localType,
      nodeType: nodeType,
      customVal: customVal,
      note: note,
      child: child,
    );
  }
}

// MARK: - 主視圖

class WorldSettingsView extends ConsumerStatefulWidget {
  final ValueChanged<List<LocationData>>? onChanged;

  const WorldSettingsView({super.key, this.onChanged});

  @override
  ConsumerState<WorldSettingsView> createState() => _WorldSettingsViewState();
}

class _WorldSettingsViewState extends ConsumerState<WorldSettingsView> {
  List<LocationData> _locations = [];
  String? selectedNodeId;
  String? lastSelectedNodeId; // 記錄上次選取的節點
  String? editingNodeId;
  String tempCustomKey = "";
  String tempCustomVal = "";
  List<TemplatePreset> templatePresets = [];
  String selectedPresetName = "空白";
  String renamePresetText = "";

  // 扁平化緩存列表
  List<_FlatNode> _flatList = [];

  // 拖動狀態與游標資訊
  bool _isDragging = false;
  String? _draggingLocationId;
  bool _isCommittingLocalChange = false;
  ProviderSubscription<List<LocationData>>? _worldSettingsSubscription;

  // 控制器
  final TextEditingController tempKeyController = TextEditingController();
  final TextEditingController tempValController = TextEditingController();
  final TextEditingController locationNameController = TextEditingController();
  final TextEditingController locationTypeController = TextEditingController();
  final TextEditingController locationNoteController = TextEditingController();
  final ScrollController _pageScrollController = ScrollController();
  final ScrollController _treeScrollController = ScrollController();
  final ScrollController _detailScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _locations = _copyLocations(ref.read(worldSettingsDataProvider));
    _rebuildFlatList();
    tempKeyController.text = tempCustomKey;
    tempValController.text = tempCustomVal;

    _loadTemplatesFromDisk();

    locationNameController.addListener(_onNameChanged);
    locationTypeController.addListener(_onTypeChanged);
    locationNoteController.addListener(_onNoteChanged);

    _worldSettingsSubscription = ref.listenManual<List<LocationData>>(
      worldSettingsDataProvider,
      (previous, next) {
        if (_isCommittingLocalChange) {
          return;
        }

        setState(() {
          _locations = _copyLocations(next);
          _rebuildFlatList();
          _syncDetailControllers();
        });
      },
    );
  }

  void _rebuildFlatList() {
    _flatList.clear();
    void flatten(List<LocationData> nodes, int depth) {
      for (var node in nodes) {
        _flatList.add(_FlatNode(node, depth));
        flatten(node.child, depth + 1);
      }
    }

    flatten(_locations, 0);
  }

  @override
  void dispose() {
    _worldSettingsSubscription?.close();
    locationNameController.removeListener(_onNameChanged);
    locationTypeController.removeListener(_onTypeChanged);
    locationNoteController.removeListener(_onNoteChanged);
    tempKeyController.dispose();
    tempValController.dispose();
    locationNameController.dispose();
    locationTypeController.dispose();
    locationNoteController.dispose();
    _pageScrollController.dispose();
    _treeScrollController.dispose();
    _detailScrollController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    final nodeId = selectedNodeId;
    if (nodeId == null) return;
    final location = _getLocation(nodeId, _locations);
    if (location == null || location.localName == locationNameController.text) {
      return;
    }

    _updateLocationById(
      nodeId,
      (current) => current.copyWith(localName: locationNameController.text),
    );
  }

  void _onTypeChanged() {
    final nodeId = selectedNodeId;
    if (nodeId == null) return;
    final location = _getLocation(nodeId, _locations);
    if (location == null || location.localType == locationTypeController.text) {
      return;
    }

    _updateLocationById(
      nodeId,
      (current) => current.copyWith(localType: locationTypeController.text),
    );
  }

  void _onNoteChanged() {
    final nodeId = selectedNodeId;
    if (nodeId == null) return;
    final location = _getLocation(nodeId, _locations);
    if (location == null || location.note == locationNoteController.text) {
      return;
    }

    _updateLocationById(
      nodeId,
      (current) => current.copyWith(note: locationNoteController.text),
    );
  }

  void _notifyChange() {
    final snapshot = _copyLocations(_locations);
    _isCommittingLocalChange = true;
    ref
        .read(worldSettingsDataProvider.notifier)
        .updateWorldSettingsData((_) => snapshot);
    widget.onChanged?.call(snapshot);
    _isCommittingLocalChange = false;
  }

  List<LocationData> _copyLocations(List<LocationData> source) {
    return source.map((location) => location.deepCopy()).toList();
  }

  void _updateLocationById(
    String id,
    LocationData Function(LocationData current) update,
  ) {
    var changed = false;
    setState(() {
      final next = _copyLocations(_locations);
      changed = _updateLocationByIdRecursive(id, next, update);
      if (changed) {
        _locations = next;
        _rebuildFlatList();
        _syncDetailControllers();
      }
    });

    if (changed) {
      _notifyChange();
    }
  }

  bool _updateLocationByIdRecursive(
    String id,
    List<LocationData> nodes,
    LocationData Function(LocationData current) update,
  ) {
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      if (node.id == id) {
        final updated = update(node);
        if (updated == node) {
          return false;
        }
        nodes[index] = updated;
        return true;
      }
      if (_updateLocationByIdRecursive(id, node.child, update)) {
        return true;
      }
    }
    return false;
  }

  void _removeCustomValue(String locationId, int customValueIndex) {
    _updateLocationById(locationId, (current) {
      if (customValueIndex < 0 ||
          customValueIndex >= current.customVal.length) {
        return current;
      }
      final nextCustomValues = [...current.customVal]
        ..removeAt(customValueIndex);
      return current.copyWith(customVal: nextCustomValues);
    });
  }

  void _addCustomValue(String locationId, String key, String value) {
    final trimmedKey = key.trim();
    if (trimmedKey.isEmpty) return;

    _updateLocationById(locationId, (current) {
      final nextCustomValues = [
        ...current.customVal,
        LocationCustomize(key: trimmedKey, val: value),
      ];
      return current.copyWith(customVal: nextCustomValues);
    });

    setState(() {
      tempCustomKey = "";
      tempCustomVal = "";
      tempKeyController.clear();
      tempValController.clear();
    });
  }

  void _updateCustomValueKey(
    String locationId,
    int customValueIndex,
    String key,
  ) {
    _updateLocationById(locationId, (current) {
      if (customValueIndex < 0 ||
          customValueIndex >= current.customVal.length) {
        return current;
      }
      final existing = current.customVal[customValueIndex];
      if (existing.key == key) {
        return current;
      }

      final nextCustomValues = [...current.customVal];
      nextCustomValues[customValueIndex] = existing.copyWith(key: key);
      return current.copyWith(customVal: nextCustomValues);
    });
  }

  void _updateCustomValueVal(
    String locationId,
    int customValueIndex,
    String value,
  ) {
    _updateLocationById(locationId, (current) {
      if (customValueIndex < 0 ||
          customValueIndex >= current.customVal.length) {
        return current;
      }
      final existing = current.customVal[customValueIndex];
      if (existing.val == value) {
        return current;
      }

      final nextCustomValues = [...current.customVal];
      nextCustomValues[customValueIndex] = existing.copyWith(val: value);
      return current.copyWith(customVal: nextCustomValues);
    });
  }

  // MARK: - UI 介面建構
  @override
  Widget build(BuildContext context) {
    ref.watch(worldSettingsDataProvider);
    final viewportHeight = MediaQuery.sizeOf(context).height;
    const listMinHeight = 320.0;
    final listHeight = math.max(viewportHeight * 0.4, listMinHeight);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: _pageScrollController,
            primary: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Row(
                      children: [
                        const LargeTitle(icon: Icons.public, text: "世界設定"),
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
                              enabled:
                                  _selectedPreset != null &&
                                  _selectedPreset!.name != "空白",
                              child: const Text("刪除選取預設"),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // 上方樹狀列表區域
                    MediumTitle(icon: Icons.map, text: "世界結構"),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: listHeight,
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
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withOpacity(0.2),
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLowest,
                          ),
                          child: Builder(
                            builder: (context) {
                              if (_locations.isEmpty) {
                                return Center(
                                  child: Text(
                                    "尚無地點，請新增第一個地點",
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelLarge,
                                  ),
                                );
                              }

                              return ListView.builder(
                                controller: _treeScrollController,
                                primary: false,
                                padding: const EdgeInsets.all(8),
                                itemCount: _flatList.length,
                                itemBuilder: (context, index) {
                                  final item = _flatList[index];
                                  return _buildLocationRow(
                                    item.node,
                                    item.depth,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    // 新增地點輸入框
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: AddItemInput(
                        title: selectedNodeId != null ? "子地點" : "頂層地點",
                        onAdd: _addLocation,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 下方詳情面板
                    MediumTitle(icon: Icons.info_outline, text: "節點詳情"),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(minHeight: 320),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withOpacity(0.2),
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLowest,
                      ),
                      padding: const EdgeInsets.all(16),
                      child: _buildDetailPanel(),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLocationRow(LocationData location, int depth) {
    final isSelected = selectedNodeId == location.id;
    final isEditing = editingNodeId == location.id;

    // 標題組件
    Widget titleWidget = isEditing
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
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          );

    return DraggableCardNode<LocationDragData>(
      key: ValueKey(location.id),
      dragData: LocationDragData(
        locationId: location.id,
        locationName: location.localName,
      ),
      nodeId: location.id,
      nodeType: location.child.isEmpty ? NodeType.item : NodeType.folder,

      // 內容
      leading: Icon(
        location.nodeType.icon,
        size: 20,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: titleWidget,
      subtitle: Text(
        "${location.nodeType.label} • ${location.child.length} 個子節點",
        style: Theme.of(context).textTheme.bodySmall,
      ),
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

      // 狀態與回調
      isSelected: isSelected,
      onClicked: () {
        setState(() {
          selectedNodeId = location.id;
          lastSelectedNodeId = location.id;
          _syncDetailControllers();
        });
      },

      // 拖放
      isDragging: _isDragging,
      isThisDragging: _draggingLocationId == location.id,
      isDragForbidden:
          _isDragging &&
          _draggingLocationId != null &&
          _isDescendant(_draggingLocationId!, location.id),

      onDragStarted: () {
        setState(() {
          _isDragging = true;
          _draggingLocationId = location.id;
        });
      },
      onDragEnd: () {
        setState(() {
          _isDragging = false;
          _draggingLocationId = null;
        });
      },

      getDropZoneSize: (pos) {
        switch (pos) {
          case DropPosition.before:
            return 0.3;
          case DropPosition.child:
            return 0.4;
          case DropPosition.after:
            return 0.3;
        }
      },

      onWillAccept: (data, pos) {
        if (data.locationId == location.id) return false;
        return true;
      },

      onAccept: (data, pos) {
        String positionStr;
        String messageKey;

        switch (pos) {
          case DropPosition.before:
            positionStr = "before";
            messageKey = "之前";
            break;
          case DropPosition.child:
            positionStr = "child";
            messageKey = "的子地點";
            break;
          case DropPosition.after:
            positionStr = "after";
            messageKey = "之後";
            break;
        }

        final message = pos == DropPosition.child
            ? "「${data.locationName}」已成為「${location.localName}」$messageKey"
            : "「${data.locationName}」已移動到「${location.localName}」$messageKey";

        _moveLocationTo(data.locationId, location.id, positionStr);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 1),
          ),
        );
      },

      indent: depth * 16.0,
    );
  }

  Widget _buildDetailPanel() {
    // 如果當前沒有選中節點，使用上次選取的節點
    final displayNodeId = selectedNodeId ?? lastSelectedNodeId;

    if (displayNodeId == null) {
      return const Center(child: Text("請選擇一個地點來編輯詳情"));
    }

    final location = _getLocation(displayNodeId, _locations);
    if (location == null) {
      return const Center(child: Text("找不到該地點"));
    }

    return SingleChildScrollView(
      controller: _detailScrollController,
      primary: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 應用模板
          Row(
            children: [
              const Text("應用模板: "),
              Expanded(
                child: AppDropdownField<String>(
                  value: selectedPresetName,
                  options: templatePresets
                      .map(
                        (preset) => DropdownOption<String>(
                          value: preset.name,
                          label: preset.name,
                        ),
                      )
                      .toList(),
                  hintText: "選擇模板",
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
                  _applyTemplateTo(location.id, preset);
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
          ),
          const SizedBox(height: 16),

          AppDropdownField<WorldNodeType>(
            value: location.nodeType,
            labelText: "節點類別",
            options: WorldNodeType.values
                .map(
                  (type) => DropdownOption<WorldNodeType>(
                    value: type,
                    label: type.label,
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null || value == location.nodeType) return;
              _updateLocationById(
                location.id,
                (current) => current.copyWith(nodeType: value),
              );
            },
          ),
          const SizedBox(height: 16),

          // 自訂值表
          Text("自訂值表:", style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          ...location.customVal.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _CustomValueRow(
              key: ValueKey(item.id),
              item: item,
              onKeyChanged: (value) {
                _updateCustomValueKey(location.id, index, value);
              },
              onValChanged: (value) {
                _updateCustomValueVal(location.id, index, value);
              },
              onRemove: () {
                _removeCustomValue(location.id, index);
              },
            );
          }),

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
                onPressed: tempCustomKey.isEmpty
                    ? null
                    : () {
                        _addCustomValue(
                          location.id,
                          tempCustomKey,
                          tempCustomVal,
                        );
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
          ),
        ],
      ),
    );
  }

  // 模板管理相關方法
  TemplatePreset? get _selectedPreset {
    return templatePresets
        .where((p) => p.name == selectedPresetName)
        .firstOrNull;
  }

  void _applyTemplateTo(String locationId, TemplatePreset preset) {
    _updateLocationById(locationId, (current) {
      final nextCustomValues = preset.keys
          .map((key) => LocationCustomize(key: key, val: ""))
          .toList();

      return current.copyWith(
        localType: preset.type,
        localName: preset.name,
        customVal: nextCustomValues,
      );
    });
  }

  void _saveCurrentAsPreset() {
    if (selectedNodeId == null) return;
    final location = _getLocation(selectedNodeId!, _locations);
    if (location == null) return;

    final worldType = location.localType.trim();
    if (worldType.isEmpty) return;

    final preset = TemplatePreset(
      name: worldType,
      type: worldType,
      keys: location.customVal.map((cv) => cv.key).toList(),
    );

    final existingIndex = templatePresets.indexWhere(
      (p) => p.name == preset.name,
    );
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
              final index = templatePresets.indexWhere(
                (p) => p.name == preset.name,
              );
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
    final index = templatePresets.indexWhere(
      (p) => p.name == selectedPresetName,
    );
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
    final index = templatePresets.indexWhere(
      (p) => p.name == selectedPresetName && p.name != "空白",
    );
    if (index != -1) {
      setState(() {
        templatePresets.removeAt(index);
        selectedPresetName = templatePresets.isNotEmpty
            ? templatePresets.first.name
            : "";
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
              final index = templatePresets.indexWhere(
                (p) => p.name == preset.name,
              );
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
      bytes: utf8.encode(content),
    );

    if (result != null) {
      try {
        // 在桌面平台上仍需要寫入檔案
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          final file = File(result);
          await file.writeAsString(content);
        }
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
    final worldTypeMatch = RegExp(
      r"<WorldType>(.*?)</WorldType>",
      dotAll: true,
    ).firstMatch(xml);
    final worldType = worldTypeMatch?.group(1)?.trim() ?? "";
    if (worldType.isEmpty) return null;

    final keyMatches = RegExp(
      r"<Key>(.*?)</Key>",
      dotAll: true,
    ).allMatches(xml);
    final keys = keyMatches.map((m) => m.group(1)?.trim() ?? "").toList();

    return TemplatePreset(name: worldType, type: worldType, keys: keys);
  }

  List<TemplatePreset> _parseAllTemplatesXML(String xml) {
    final typeMatches = RegExp(
      r"<Type>([\s\S]*?)</Type>",
      dotAll: true,
    ).allMatches(xml);
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
      _log.warning("儲存模板失敗：${e.toString()}");
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
        _log.info("讀檔成功但解析為空，保留現有預設。");
        _ensureBlankPresetExists();
        return;
      }

      setState(() {
        templatePresets = presets;
        _ensureBlankPresetExists();
        selectedPresetName = templatePresets.isNotEmpty
            ? templatePresets.first.name
            : "空白";
      });
    } catch (e) {
      _log.warning("讀取模板失敗：${e.toString()}");
      _ensureBlankPresetExists();
    }
  }

  void _ensureBlankPresetExists() {
    if (!templatePresets.any((p) => p.name == "空白")) {
      templatePresets.insert(0, TemplatePreset(name: "空白", type: "", keys: []));
    }
  }

  // TreeView 操作
  void _addLocation(String name) {
    name = name.trim();
    if (name.isEmpty) return;

    final parentId = selectedNodeId;
    setState(() {
      final next = _copyLocations(_locations);
      if (parentId != null) {
        _addChildRecursive(parentId, name, next);
      } else {
        next.add(LocationData(localName: name));
      }

      _locations = next;
      _rebuildFlatList();
    });
    _notifyChange();
  }

  void _addChild(String parentId, String name) {
    setState(() {
      final next = _copyLocations(_locations);
      _addChildRecursive(parentId, name, next);
      _locations = next;
      _rebuildFlatList();
    });
    _notifyChange();
  }

  void _addChildRecursive(
    String parentId,
    String name,
    List<LocationData> locations,
  ) {
    for (final location in locations) {
      if (location.id == parentId) {
        location.child.add(LocationData(localName: name));
        return;
      }
      _addChildRecursive(parentId, name, location.child);
    }
  }

  void _renameNode(String id, String newName) {
    setState(() {
      final next = _copyLocations(_locations);
      _renameNodeRecursive(id, newName, next);
      _locations = next;
      _rebuildFlatList();
      _syncDetailControllers();
    });
    _notifyChange();
  }

  void _renameNodeRecursive(
    String id,
    String newName,
    List<LocationData> locations,
  ) {
    for (var index = 0; index < locations.length; index++) {
      final location = locations[index];
      if (location.id == id) {
        locations[index] = location.copyWith(localName: newName);
        return;
      }
      _renameNodeRecursive(id, newName, location.child);
    }
  }

  // MARK: - 拖動相關方法

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

    return search(_locations);
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
      final next = _copyLocations(_locations);

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

      removeFromTree(next);

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

        success = addAsChild(next);
      } else {
        // before 或 after: 在同級列表中插入
        bool insertInList(List<LocationData> nodes) {
          for (int i = 0; i < nodes.length; i++) {
            if (nodes[i].id == targetId) {
              if (position == "before") {
                nodes.insert(i, sourceNode!);
              } else {
                // after
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

        success = insertInList(next);
      }

      if (!success) {
        // 如果沒找到目標，恢復原節點
        next.add(sourceNode!);
      }

      _locations = next;
      _rebuildFlatList();
    });
    _notifyChange();
  }

  void _deleteNode(String id) {
    var removed = false;
    setState(() {
      final next = _copyLocations(_locations);
      removed = _removeNodeRecursive(id, next);
      if (!removed) {
        return;
      }

      _locations = next;
      if (selectedNodeId == id) {
        selectedNodeId = null;
      }
      _rebuildFlatList();
      _syncDetailControllers();
    });

    if (removed) {
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
    final location = _getLocation(selectedNodeId!, _locations);
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

class _FlatNode {
  final LocationData node;
  final int depth;
  _FlatNode(this.node, this.depth);
}

class _CustomValueRow extends StatefulWidget {
  final LocationCustomize item;
  final VoidCallback onRemove;
  final ValueChanged<String> onKeyChanged;
  final ValueChanged<String> onValChanged;

  const _CustomValueRow({
    super.key,
    required this.item,
    required this.onRemove,
    required this.onKeyChanged,
    required this.onValChanged,
  });

  @override
  State<_CustomValueRow> createState() => _CustomValueRowState();
}

class _CustomValueRowState extends State<_CustomValueRow> {
  late TextEditingController keyController;
  late TextEditingController valController;

  @override
  void initState() {
    super.initState();
    keyController = TextEditingController(text: widget.item.key);
    valController = TextEditingController(text: widget.item.val);
    keyController.addListener(_onKeyChanged);
    valController.addListener(_onValChanged);
  }

  void _onKeyChanged() {
    if (widget.item.key == keyController.text) return;
    widget.onKeyChanged(keyController.text);
  }

  void _onValChanged() {
    if (widget.item.val == valController.text) return;
    widget.onValChanged(valController.text);
  }

  @override
  void didUpdateWidget(_CustomValueRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.key != keyController.text) {
      keyController.text = widget.item.key;
    }
    if (widget.item.val != valController.text) {
      valController.text = widget.item.val;
    }
  }

  @override
  void dispose() {
    keyController.removeListener(_onKeyChanged);
    valController.removeListener(_onValChanged);
    keyController.dispose();
    valController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: keyController,
              decoration: const InputDecoration(
                labelText: "設定",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text("="),
          ),
          Expanded(
            child: TextField(
              controller: valController,
              decoration: const InputDecoration(
                labelText: "鍵值",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          IconButton(
            onPressed: widget.onRemove,
            icon: const Icon(Icons.remove_circle, color: Colors.red),
          ),
        ],
      ),
    );
  }
}
