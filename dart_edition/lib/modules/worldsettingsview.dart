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
import "dart:async";
import "dart:math" as math;
import "package:path_provider/path_provider.dart";
import "package:uuid/uuid.dart";
import "package:xml/xml.dart" as xml;
import "../models/codecs/xml_text_codec.dart";
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
    XmlTextCodec.writeTextElement(builder, name, value);
  }

  static String _readElementText(xml.XmlElement? element) {
    return XmlTextCodec.readElementText(element);
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
                builder.text(XmlTextCodec.encodeNewlines(kv.val));
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
      return typeElement == null ? null : loadElement(typeElement);
    } catch (e) {
      _log.severe("Error parsing WorldSettings XML: $e");
      return null;
    }
  }

  // 自已解析的 Type 區塊載入，避免專案載入時重複序列化與解析。
  static List<LocationData>? loadElement(xml.XmlElement typeElement) {
    try {
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
      _log.severe("Error parsing WorldSettings XML element: $e");
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
  const WorldSettingsView({super.key});

  @override
  ConsumerState<WorldSettingsView> createState() => _WorldSettingsViewState();
}

class _WorldSettingsViewState extends ConsumerState<WorldSettingsView> {
  List<LocationData> get _locations => ref.read(worldSettingsDataProvider);
  String? selectedNodeId;
  String? lastSelectedNodeId; // 記錄上次選取的節點
  String? editingNodeId;
  String? selectedCustomValueId;
  String? _customValueEditorLocationId;
  List<TemplatePreset> templatePresets = [];
  String selectedPresetName = "空白";
  Map<String, LocationData> _locationIndex = const <String, LocationData>{};
  Map<String, int> _locationDfsEntry = const <String, int>{};
  Map<String, int> _locationDfsExit = const <String, int>{};

  // 拖動狀態與游標資訊
  bool _isDragging = false;
  String? _draggingLocationId;

  // 控制器
  final TextEditingController tempKeyController = TextEditingController();
  final TextEditingController tempValController = TextEditingController();
  final TextEditingController locationNameController = TextEditingController();
  final TextEditingController locationTypeController = TextEditingController();
  final TextEditingController locationNoteController = TextEditingController();
  final ScrollController _pageScrollController = ScrollController();
  final ScrollController _treeScrollController = ScrollController();
  final ScrollController _detailScrollController = ScrollController();
  Timer? _detailDraftTimer;
  VoidCallback? _pendingDetailCommit;
  int _templateLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadTemplatesFromDisk();

    locationNameController.addListener(_onNameChanged);
    locationTypeController.addListener(_onTypeChanged);
    locationNoteController.addListener(_onNoteChanged);
  }

  List<_FlatNode> _buildFlatList(List<LocationData> locations) {
    final flatList = <_FlatNode>[];
    final locationIndex = <String, LocationData>{};
    final dfsEntry = <String, int>{};
    final dfsExit = <String, int>{};
    int dfsClock = 0;

    void flatten(LocationData node, int depth) {
      dfsEntry[node.id] = dfsClock++;
      flatList.add(_FlatNode(node, depth));
      locationIndex[node.id] = node;

      for (final child in node.child) {
        flatten(child, depth + 1);
      }
      dfsExit[node.id] = dfsClock++;
    }

    for (final location in locations) {
      flatten(location, 0);
    }

    _locationIndex = locationIndex;
    _locationDfsEntry = dfsEntry;
    _locationDfsExit = dfsExit;
    return flatList;
  }

  @override
  void dispose() {
    _templateLoadGeneration++;
    _detailDraftTimer?.cancel();
    _pendingDetailCommit?.call();
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
    _scheduleDetailDraft();
  }

  void _onTypeChanged() {
    _scheduleDetailDraft();
  }

  void _onNoteChanged() {
    _scheduleDetailDraft();
  }

  void _scheduleDetailDraft() {
    final nodeId = selectedNodeId ?? lastSelectedNodeId;
    if (nodeId == null) return;
    final name = locationNameController.text;
    final type = locationTypeController.text;
    final note = locationNoteController.text;
    _pendingDetailCommit = () {
      _updateLocationById(
        nodeId,
        (current) =>
            current.copyWith(localName: name, localType: type, note: note),
      );
    };
    _detailDraftTimer?.cancel();
    _detailDraftTimer = Timer(const Duration(milliseconds: 300), () {
      _detailDraftTimer = null;
      final commit = _pendingDetailCommit;
      _pendingDetailCommit = null;
      commit?.call();
    });
  }

  void _flushDetailDraft() {
    _detailDraftTimer?.cancel();
    _detailDraftTimer = null;
    final commit = _pendingDetailCommit;
    _pendingDetailCommit = null;
    commit?.call();
  }

  void _notifyChange() {
    // Dirty tracking is driven by provider listeners in coordinator.
  }

  void _updateLocationById(
    String id,
    LocationData Function(LocationData current) update,
  ) {
    final changed = ref
        .read(worldSettingsDataProvider.notifier)
        .updateLocationById(id, update);

    if (!changed) {
      return;
    }

    if (selectedNodeId == id || lastSelectedNodeId == id) {
      _syncDetailControllers();
    }
    _notifyChange();
  }

  void _refreshLocationIndex() {
    _buildFlatList(ref.read(worldSettingsDataProvider));
  }

  void _selectCustomValueForEditing(String locationId, LocationCustomize item) {
    setState(() {
      selectedCustomValueId = item.id;
      _customValueEditorLocationId = locationId;
      tempKeyController.text = item.key;
      tempValController.text = item.val;
    });
  }

  void _clearCustomValueEditor() {
    selectedCustomValueId = null;
    tempKeyController.clear();
    tempValController.clear();
  }

  void _saveCustomValue(String locationId) {
    final key = tempKeyController.text.trim();
    if (key.isEmpty) return;
    final value = tempValController.text;
    final selectedId = selectedCustomValueId;

    _updateLocationById(locationId, (current) {
      final nextCustomValues = [...current.customVal];
      final selectedIndex = selectedId == null
          ? -1
          : nextCustomValues.indexWhere((item) => item.id == selectedId);

      if (selectedIndex >= 0) {
        nextCustomValues[selectedIndex] = nextCustomValues[selectedIndex]
            .copyWith(key: key, val: value);
      } else {
        nextCustomValues.add(LocationCustomize(key: key, val: value));
      }
      return current.copyWith(customVal: nextCustomValues);
    });

    setState(_clearCustomValueEditor);
  }

  void _deleteSelectedCustomValue(String locationId) {
    final selectedId = selectedCustomValueId;
    if (selectedId == null) return;

    _updateLocationById(locationId, (current) {
      final nextCustomValues = [...current.customVal]
        ..removeWhere((item) => item.id == selectedId);
      return current.copyWith(customVal: nextCustomValues);
    });

    setState(_clearCustomValueEditor);
  }

  // MARK: - UI 介面建構
  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(worldSettingsDataProvider);
    final flatList = _buildFlatList(locations);
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

                    ResponsiveSplitView(
                      breakpoint: 980,
                      spacing: 24,
                      primary: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MediumTitle(icon: Icons.map, text: "世界結構"),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedNodeId = null;
                              });
                            },
                            child: CollectionPanel.builder(
                              title: "世界結構",
                              showSectionCard: false,
                              minHeight: listHeight,
                              maxHeight: listHeight,
                              controller: _treeScrollController,
                              showScrollbar: true,
                              itemCount: flatList.length,
                              emptyTitle: "尚無地點",
                              emptyDescription: "請新增第一個地點",
                              emptyIcon: Icons.public_off_outlined,
                              itemBuilder: (context, index) {
                                final item = flatList[index];
                                return _buildLocationRow(item.node, item.depth);
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: AddItemInput(
                              title: selectedNodeId != null ? "子地點" : "頂層地點",
                              onAdd: _addLocation,
                            ),
                          ),
                        ],
                      ),
                      secondary: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MediumTitle(icon: Icons.info_outline, text: "節點詳情"),
                          const SizedBox(height: 8),
                          Container(
                            constraints: const BoxConstraints(minHeight: 320),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.2),
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

    final titleWidget = InlineEditableText(
      key: ValueKey("location-name-editor-${location.id}"),
      value: location.localName,
      isEditing: isEditing,
      onEdit: () {
        setState(() {
          editingNodeId = location.id;
        });
      },
      onSubmitted: (value) {
        _renameNode(location.id, value);
        setState(() {
          editingNodeId = null;
        });
      },
      onCanceled: () {
        setState(() {
          editingNodeId = null;
        });
      },
      emptyText: "（未命名）",
      style: TextStyle(
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface,
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
      trailing: ItemActionBar.editDelete(
        iconSize: 18,
        onEdit: () {
          setState(() {
            editingNodeId = location.id;
          });
        },
        onDelete: () => _deleteNode(location.id),
        deleteTooltip: "刪除地點",
      ),

      // 狀態與回調
      isSelected: isSelected,
      onClicked: () {
        _flushDetailDraft();
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
        AppFeedback.success(
          context,
          message,
          duration: const Duration(seconds: 1),
        );
      },

      indent: depth * 16.0,
    );
  }

  Widget _buildDetailPanel() {
    // 如果當前沒有選中節點，使用上次選取的節點
    final displayNodeId = selectedNodeId ?? lastSelectedNodeId;

    if (displayNodeId == null) {
      return const AppEmptyState(
        title: "請選擇一個地點",
        description: "選取地點後即可編輯詳細資料",
        icon: Icons.touch_app_outlined,
        compact: true,
      );
    }

    final location = _getLocation(displayNodeId, _locations);
    if (location == null) {
      return const AppEmptyState(
        title: "找不到該地點",
        icon: Icons.location_off_outlined,
        compact: true,
      );
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
          AppTextField(
            controller: locationNameController,
            decoration: const InputDecoration(
              labelText: "名稱",
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),

          // 類型
          AppTextField(
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
          AppTwoColumnTable(
            firstHeader: "設定",
            secondHeader: "鍵值",
            bodyHeight: 200,
            emptyState: const AppEmptyState(
              title: "尚無自訂值",
              description: "在下方輸入設定與鍵值後新增",
              icon: Icons.tune_outlined,
              compact: true,
            ),
            rows: location.customVal
                .asMap()
                .entries
                .map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return AppTwoColumnTableRow(
                    key: ValueKey(item.id),
                    selected: selectedCustomValueId == item.id,
                    showDivider: index != location.customVal.length - 1,
                    firstCell: Text(item.key),
                    secondCell: Text(item.val),
                    onTap: () {
                      _selectCustomValueForEditing(location.id, item);
                    },
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 8),
          AppTwoColumnTableEditor(
            firstController: tempKeyController,
            secondController: tempValController,
            firstLabel: "設定",
            secondLabel: "鍵值",
            isEditing: selectedCustomValueId != null,
            canSubmit: (key, _) => key.trim().isNotEmpty,
            onSubmit: (_, _) => _saveCustomValue(location.id),
            onDelete: () => _deleteSelectedCustomValue(location.id),
          ),
          const SizedBox(height: 16),

          // 備註
          const Text("備註:", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          AppTextField(
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

  Future<void> _showOverwritePresetDialog(TemplatePreset preset) async {
    final confirmed = await AppDialog.confirm(
      context: context,
      title: "儲存預設模板",
      message: "同名模板已存在，是否要覆蓋？",
      confirmLabel: "覆蓋",
    );
    if (!mounted || !confirmed) return;

    final index = templatePresets.indexWhere((p) => p.name == preset.name);
    setState(() {
      templatePresets[index] = preset;
      selectedPresetName = preset.name;
    });
    _saveTemplatesToDisk();
  }

  Future<void> _showRenamePresetDialog() async {
    final newName = await AppDialog.prompt(
      context: context,
      title: "更改預設名稱",
      labelText: "新模板名稱",
      initialValue: selectedPresetName,
    );
    if (!mounted || newName == null) {
      return;
    }
    _renameSelectedPreset(newName);
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
      // 不在 saveFile 上傳遞 bytes，因為 macOS 不支援
      // 內容將由應用程式寫入檔案
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
    final generation = ++_templateLoadGeneration;
    try {
      final filePath = await _worldTemplateFilePath;
      if (!mounted || generation != _templateLoadGeneration) return;
      final file = File(filePath);

      if (!await file.exists()) {
        if (!mounted || generation != _templateLoadGeneration) return;
        setState(_ensureBlankPresetExists);
        return;
      }

      final xml = await file.readAsString();
      if (!mounted || generation != _templateLoadGeneration) return;
      final presets = _parseAllTemplatesXML(xml);

      if (presets.isEmpty) {
        _log.info("讀檔成功但解析為空，保留現有預設。");
        setState(_ensureBlankPresetExists);
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
      if (mounted && generation == _templateLoadGeneration) {
        setState(_ensureBlankPresetExists);
      }
    }
  }

  void _ensureBlankPresetExists() {
    if (!templatePresets.any((p) => p.name == "空白")) {
      templatePresets.insert(0, TemplatePreset(name: "空白", type: "", keys: []));
    }
  }

  // TreeView 操作
  void _addLocation(String name) {
    final added = ref
        .read(worldSettingsDataProvider.notifier)
        .addLocation(name: name, parentId: selectedNodeId);
    if (!added) {
      return;
    }

    _refreshLocationIndex();
    _notifyChange();
  }

  void _renameNode(String id, String newName) {
    _updateLocationById(id, (current) => current.copyWith(localName: newName));
  }

  // MARK: - 拖動相關方法

  bool _isDescendant(String sourceId, String targetId) {
    final sourceEntry = _locationDfsEntry[sourceId];
    final sourceExit = _locationDfsExit[sourceId];
    final targetEntry = _locationDfsEntry[targetId];
    final targetExit = _locationDfsExit[targetId];
    if (sourceEntry != null &&
        sourceExit != null &&
        targetEntry != null &&
        targetExit != null) {
      return sourceEntry < targetEntry && targetExit < sourceExit;
    }

    final sourceNode = _getLocation(sourceId, _locations);
    if (sourceNode == null) {
      return false;
    }

    bool walk(LocationData node) {
      if (node.id == targetId) {
        return true;
      }
      for (final child in node.child) {
        if (walk(child)) {
          return true;
        }
      }
      return false;
    }

    return walk(sourceNode);
  }

  // 移動節點到目標位置
  // position: "before" (排序至該項目上), "child" (設為副目錄), "after" (排序至該項目下)
  void _moveLocationTo(String sourceId, String targetId, String position) {
    final moved = ref
        .read(worldSettingsDataProvider.notifier)
        .moveLocation(
          sourceId: sourceId,
          targetId: targetId,
          position: position,
        );
    if (!moved) {
      AppFeedback.warning(
        context,
        "無法移動到自己或自己的後代節點",
        duration: const Duration(seconds: 1),
      );
      return;
    }

    _refreshLocationIndex();
    _notifyChange();
  }

  void _deleteNode(String id) {
    final removed = ref
        .read(worldSettingsDataProvider.notifier)
        .removeLocationById(id);
    if (!removed) {
      return;
    }

    _refreshLocationIndex();
    if (selectedNodeId == id || lastSelectedNodeId == id) {
      setState(() {
        if (selectedNodeId == id) {
          selectedNodeId = null;
        }
        if (lastSelectedNodeId == id) {
          lastSelectedNodeId = null;
        }
      });
    }

    _syncDetailControllers();
    _notifyChange();
  }

  LocationData? _getLocation(String id, [List<LocationData>? locations]) {
    final indexed = _locationIndex[id];
    if (indexed != null) {
      return indexed;
    }

    return _findLocation(id, locations ?? _locations);
  }

  LocationData? _findLocation(String id, List<LocationData> locations) {
    for (final location in locations) {
      if (location.id == id) return location;
      final found = _findLocation(id, location.child);
      if (found != null) return found;
    }
    return null;
  }

  void _syncDetailControllers() {
    final displayNodeId = selectedNodeId ?? lastSelectedNodeId;
    if (_customValueEditorLocationId != displayNodeId) {
      _customValueEditorLocationId = displayNodeId;
      _clearCustomValueEditor();
    }
    if (displayNodeId == null) {
      _setControllerTextIfChanged(locationNameController, "");
      _setControllerTextIfChanged(locationTypeController, "");
      _setControllerTextIfChanged(locationNoteController, "");
      return;
    }
    final location = _getLocation(displayNodeId, _locations);
    if (location != null) {
      _setControllerTextIfChanged(locationNameController, location.localName);
      _setControllerTextIfChanged(locationTypeController, location.localType);
      _setControllerTextIfChanged(locationNoteController, location.note);
      return;
    }

    _setControllerTextIfChanged(locationNameController, "");
    _setControllerTextIfChanged(locationTypeController, "");
    _setControllerTextIfChanged(locationNoteController, "");
  }

  void _setControllerTextIfChanged(
    TextEditingController controller,
    String text,
  ) {
    if (controller.text == text) {
      return;
    }
    controller.text = text;
  }

  void _showErrorDialog(String message) {
    AppDialog.message(
      context: context,
      title: "錯誤",
      message: message,
      closeLabel: "確定",
      tone: AppFeedbackTone.error,
    );
  }

  void _showSuccessDialog(String message) {
    AppDialog.message(
      context: context,
      title: "成功",
      message: message,
      closeLabel: "確定",
      tone: AppFeedbackTone.success,
    );
  }
}

class _FlatNode {
  final LocationData node;
  final int depth;
  _FlatNode(this.node, this.depth);
}
