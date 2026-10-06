/************************************************************
 * 
 * Copyright 2025-2026 Heyairu（部屋伊琉）
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * 
 ************************************************************/

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
import "../models/location_snapshot_data.dart";
import "../models/item_snapshot_data.dart";
import "../models/item_data.dart";
import "../application/locations/location_deletion.dart";
import "../application/items/item_assignment_operations.dart";
import "../application/items/world_item_migration.dart";
import "../application/collaboration/project_collaborative_text_codec.dart";
import "../domain/collaboration/collaboration_operation.dart"
    show ProjectRecordKind;
import "../domain/collaboration/typed_operation_log.dart" show ProjectRecordKey;
import "../features/revision_tracking/presentation/revision_field_marker.dart";
import "../presentation/providers/project_state_providers.dart";
import "../presentation/providers/timeline_providers.dart";
import "../presentation/widgets/remote_text_cursor_overlay.dart";
import "../presentation/widgets/project_object_selector.dart";

export "../models/world_settings_data.dart";

final _log = Logger("WorldSettingsView");

class _LocationItemProjectionEntry {
  final String id;
  final String classId;
  final String itemId;
  final ItemReferenceKind itemKind;
  final String name;
  final String quantity;
  final String description;

  const _LocationItemProjectionEntry({
    required this.id,
    required this.classId,
    required this.itemId,
    required this.itemKind,
    required this.name,
    required this.quantity,
    required this.description,
  });
}

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
  final String? initialLocationId;
  final int selectionRequestId;
  final ValueChanged<String>? onOpenItem;

  const WorldSettingsView({
    super.key,
    this.initialLocationId,
    this.selectionRequestId = 0,
    this.onOpenItem,
  });

  @override
  ConsumerState<WorldSettingsView> createState() => _WorldSettingsViewState();
}

class _WorldSettingsViewState extends ConsumerState<WorldSettingsView> {
  static const _baselineSnapshotSelection = "__baseline__";
  List<LocationData> get _locations => ref.read(worldSettingsDataProvider);
  String? selectedNodeId;
  String? lastSelectedNodeId; // 記錄上次選取的節點
  String? editingNodeId;
  String? selectedCustomValueId;
  String? _customValueEditorLocationId;
  String? _selectedLocationSnapshotId;
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
  final FocusNode _locationNameFocusNode = FocusNode();
  final FocusNode _locationTypeFocusNode = FocusNode();
  final FocusNode _locationNoteFocusNode = FocusNode();
  final ScrollController _pageScrollController = ScrollController();
  final ScrollController _treeScrollController = ScrollController();
  final ScrollController _detailScrollController = ScrollController();
  Timer? _detailDraftTimer;
  VoidCallback? _pendingDetailCommit;
  bool _isSyncingDetailControllers = false;
  int _templateLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadTemplatesFromDisk();

    locationNameController.addListener(_onNameChanged);
    locationTypeController.addListener(_onTypeChanged);
    locationNoteController.addListener(_onNoteChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyRequestedLocation();
    });
  }

  @override
  void didUpdateWidget(covariant WorldSettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectionRequestId != widget.selectionRequestId ||
        oldWidget.initialLocationId != widget.initialLocationId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyRequestedLocation();
      });
    }
  }

  void _applyRequestedLocation() {
    final id = widget.initialLocationId;
    if (id == null) return;
    _refreshLocationIndex();
    if (!_locationIndex.containsKey(id)) return;
    _flushDetailDraft();
    setState(() {
      selectedNodeId = id;
      lastSelectedNodeId = id;
      _selectedLocationSnapshotId = null;
      _syncDetailControllers();
    });
  }

  List<_FlatNode> _buildFlatList(
    List<LocationData> locations, {
    required int tick,
  }) {
    final flatList = <_FlatNode>[];
    final locationIndex = <String, LocationData>{};
    final dfsEntry = <String, int>{};
    final dfsExit = <String, int>{};
    final workspace = ref.watch(itemWorkspaceProvider);
    final timeline = ref.watch(timelineDocumentProvider);
    final changesByLocation = <String, List<LocationStateChange>>{};
    for (final change in workspace.locationStateChanges) {
      changesByLocation.putIfAbsent(change.locationId, () => []).add(change);
    }
    final states = <String, LocationSnapshotState>{};
    int dfsClock = 0;

    bool resolveSubtree(LocationData node) {
      var containsExistingLocation = false;
      if (node.nodeType == WorldNodeType.location) {
        final state = resolveLocationSnapshot(
          locationId: node.id,
          defaultState: LocationSnapshotState(
            name: node.localName,
            description: node.note,
            properties: {
              for (final value in node.customVal) value.key: value.val,
            },
          ),
          changes: changesByLocation[node.id] ?? const [],
          timeline: timeline,
          atTick: tick,
        );
        states[node.id] = state;
        containsExistingLocation = state.exists;
      }
      for (final child in node.child) {
        containsExistingLocation =
            resolveSubtree(child) || containsExistingLocation;
      }
      return containsExistingLocation;
    }

    bool subtreeContainsExistingLocation(LocationData node) {
      if (states[node.id]?.exists == true) return true;
      return node.child.any(subtreeContainsExistingLocation);
    }

    void flatten(LocationData node, int depth, bool unavailableAncestor) {
      dfsEntry[node.id] = dfsClock++;
      final state = states[node.id];
      final nodeUnavailable = state?.exists == false;
      final retainedShell =
          nodeUnavailable && node.child.any(subtreeContainsExistingLocation);
      flatList.add(
        _FlatNode(
          node,
          depth,
          snapshot: state,
          unavailableAncestor: unavailableAncestor,
          retainedShell: retainedShell,
        ),
      );
      locationIndex[node.id] = node;

      for (final child in node.child) {
        flatten(child, depth + 1, unavailableAncestor || nodeUnavailable);
      }
      dfsExit[node.id] = dfsClock++;
    }

    for (final location in locations) {
      resolveSubtree(location);
    }
    for (final location in locations) {
      flatten(location, 0, false);
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
    _locationNameFocusNode.dispose();
    _locationTypeFocusNode.dispose();
    _locationNoteFocusNode.dispose();
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
    if (_isSyncingDetailControllers) return;
    if (_hasActiveDetailComposition) {
      _detailDraftTimer?.cancel();
      _detailDraftTimer = null;
      _pendingDetailCommit = null;
      return;
    }
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

  bool get _hasActiveDetailComposition =>
      _isComposing(locationNameController) ||
      _isComposing(locationTypeController) ||
      _isComposing(locationNoteController);

  bool _isComposing(TextEditingController controller) {
    final composing = controller.value.composing;
    return composing.isValid && !composing.isCollapsed;
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
    final locationIndex = <String, LocationData>{};
    final dfsEntry = <String, int>{};
    final dfsExit = <String, int>{};
    var dfsClock = 0;
    void visit(LocationData node) {
      dfsEntry[node.id] = dfsClock++;
      locationIndex[node.id] = node;
      for (final child in node.child) {
        visit(child);
      }
      dfsExit[node.id] = dfsClock++;
    }

    for (final location in ref.read(worldSettingsDataProvider)) {
      visit(location);
    }
    _locationIndex = locationIndex;
    _locationDfsEntry = dfsEntry;
    _locationDfsExit = dfsExit;
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

  void _clearCustomValueSelection() {
    if (selectedCustomValueId == null) return;
    setState(_clearCustomValueEditor);
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

  void _updateCustomValueCell(
    String locationId,
    String itemId, {
    String? key,
    String? value,
  }) {
    final nextKey = key?.trim();
    if (nextKey != null && nextKey.isEmpty) return;
    _updateLocationById(locationId, (current) {
      final nextCustomValues = current.customVal
          .map((item) {
            if (item.id != itemId) return item;
            return item.copyWith(
              key: nextKey ?? item.key,
              val: value ?? item.val,
            );
          })
          .toList(growable: false);
      return current.copyWith(customVal: nextCustomValues);
    });

    if (selectedCustomValueId == itemId) {
      setState(() {
        if (nextKey != null) tempKeyController.text = nextKey;
        if (value != null) tempValController.text = value;
      });
    }
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

  List<({String sceneId, String placementId, int startTick, String label})>
  _placedScenes() {
    final sceneIndex = ref.read(timelineSceneIndexProvider);
    final scenes = ref
        .read(timelineDocumentProvider)
        .placements
        .where(
          (placement) =>
              placement.sceneUUID != null &&
              sceneIndex.containsKey(placement.sceneUUID),
        )
        .map((placement) {
          final reference = sceneIndex[placement.sceneUUID]!;
          return (
            sceneId: placement.sceneUUID!,
            placementId: placement.placementUUID,
            startTick: placement.startTick,
            label:
                "${reference.storyline.storylineName} / ${reference.event.storyEvent} / ${reference.scene.sceneName}",
          );
        })
        .toList(growable: false);
    scenes.sort((a, b) {
      final byTime = a.startTick.compareTo(b.startTick);
      return byTime != 0 ? byTime : a.placementId.compareTo(b.placementId);
    });
    return scenes;
  }

  Future<void> _addLocationSnapshot(LocationData location) async {
    final scenes = _placedScenes();
    if (scenes.isEmpty) {
      AppFeedback.error(context, "請先將 Scene 放入時間軸，再新增地點快照。");
      return;
    }
    final currentTick = ref.read(timelineViewProvider).currentTick;
    final currentState = ref.read(
      locationSnapshotProvider((id: location.id, tick: currentTick)),
    );
    var placementId = scenes.first.placementId;
    var exists = currentState?.exists ?? true;
    var accessible = currentState?.accessible ?? true;
    var includeDescendants = false;
    var snapshotName = currentState?.name.isNotEmpty == true
        ? currentState!.name
        : location.localName;
    var snapshotDescription = currentState?.description ?? location.note;
    var snapshotStatus = currentState?.status ?? "";
    String? propertyValidationError;
    var snapshotProperties =
        (currentState?.properties ?? const <String, String>{}).entries
            .map((entry) => (key: entry.key, value: entry.value))
            .toList();
    final characters = ref.read(characterDataProvider).entries.toList();
    var controllerCharacterId = currentState?.controllerCharacterId;
    final subtreeLocations = <LocationData>[];
    void collectLocations(LocationData node) {
      if (node.nodeType == WorldNodeType.location) subtreeLocations.add(node);
      for (final child in node.child) {
        collectLocations(child);
      }
    }

    collectLocations(location);
    List<String> batchPreviewLines() {
      final selectedScene = scenes.firstWhere(
        (scene) => scene.placementId == placementId,
      );
      String controllerLabel(String? id) {
        if (id == null || id.isEmpty) return "未設定";
        return characters
                .where((entry) => entry.key == id)
                .firstOrNull
                ?.value
                .displayName ??
            "找不到：$id";
      }

      return subtreeLocations
          .map((target) {
            final before = ref.read(
              locationSnapshotProvider((
                id: target.id,
                tick: selectedScene.startTick,
              )),
            );
            final differences = <String>[];
            if (before?.exists != exists) {
              differences.add(
                "存在 ${(before?.exists ?? true) ? '是' : '否'} → ${exists ? '是' : '否'}",
              );
            }
            if (before?.accessible != accessible) {
              differences.add(
                "可進入 ${(before?.accessible ?? true) ? '是' : '否'} → ${accessible ? '是' : '否'}",
              );
            }
            if ((before?.status ?? "") != snapshotStatus.trim()) {
              differences.add(
                "狀態「${before?.status.isNotEmpty == true ? before!.status : '未設定'}」"
                " → 「${snapshotStatus.trim().isEmpty ? '未設定' : snapshotStatus.trim()}」",
              );
            }
            if (before?.controllerCharacterId != controllerCharacterId) {
              differences.add(
                "控制者 ${controllerLabel(before?.controllerCharacterId)}"
                " → ${controllerLabel(controllerCharacterId)}",
              );
            }
            return "${target.localName}：${differences.isEmpty ? '無變更' : differences.join('；')}";
          })
          .toList(growable: false);
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("新增「${location.localName}」場景快照"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppDropdownField<String>(
                  value: placementId,
                  labelText: "綁定 Scene",
                  options: scenes
                      .map(
                        (scene) => DropdownOption(
                          value: scene.placementId,
                          label: scene.label,
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => placementId = value);
                    }
                  },
                ),
                if (subtreeLocations.length > 1)
                  SwitchListTile(
                    key: const Key("location-snapshot-include-descendants"),
                    contentPadding: EdgeInsets.zero,
                    title: const Text("套用至所有子地點"),
                    subtitle: Text(
                      includeDescendants
                          ? "將建立 ${subtreeLocations.length} 筆獨立快照"
                          : "目前只會修改「${location.localName}」",
                      style: Theme.of(context).textTheme.labelTiny,
                    ),
                    value: includeDescendants,
                    onChanged: (value) =>
                        setDialogState(() => includeDescendants = value),
                  ),
                if (!includeDescendants) ...[
                  TextFormField(
                    key: const Key("location-snapshot-name"),
                    initialValue: snapshotName,
                    onChanged: (value) => snapshotName = value,
                    decoration: appFieldDecoration(
                      context,
                      decoration: const InputDecoration(labelText: "當時名稱"),
                    ),
                  ),
                  TextFormField(
                    key: const Key("location-snapshot-description"),
                    initialValue: snapshotDescription,
                    onChanged: (value) => snapshotDescription = value,
                    decoration: appFieldDecoration(
                      context,
                      decoration: const InputDecoration(labelText: "當時描述"),
                    ),
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("當時自訂屬性"),
                  ),
                  for (final entry in snapshotProperties.indexed)
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: ValueKey(
                              "location-snapshot-property-key-${entry.$1}",
                            ),
                            initialValue: entry.$2.key,
                            decoration: appFieldDecoration(
                              context,
                              decoration: const InputDecoration(
                                labelText: "設定",
                              ),
                            ),
                            onChanged: (value) {
                              snapshotProperties[entry.$1] = (
                                key: value,
                                value: snapshotProperties[entry.$1].value,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            key: ValueKey(
                              "location-snapshot-property-value-${entry.$1}",
                            ),
                            initialValue: entry.$2.value,
                            decoration: appFieldDecoration(
                              context,
                              decoration: const InputDecoration(
                                labelText: "鍵值",
                              ),
                            ),
                            onChanged: (value) {
                              snapshotProperties[entry.$1] = (
                                key: snapshotProperties[entry.$1].key,
                                value: value,
                              );
                            },
                          ),
                        ),
                        IconButton(
                          key: ValueKey(
                            "location-snapshot-property-remove-${entry.$1}",
                          ),
                          tooltip: "移除屬性",
                          onPressed: () => setDialogState(
                            () => snapshotProperties.removeAt(entry.$1),
                          ),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key("location-snapshot-property-add"),
                      onPressed: () => setDialogState(
                        () => snapshotProperties = [
                          ...snapshotProperties,
                          (key: "", value: ""),
                        ],
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text("新增屬性"),
                    ),
                  ),
                  if (propertyValidationError != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        propertyValidationError!,
                        key: const Key("location-snapshot-property-error"),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ] else
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("批次套用會保留各子地點原有的名稱、描述與自訂屬性。"),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("此時已存在"),
                  value: exists,
                  onChanged: (value) => setDialogState(() => exists = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("此時可進入"),
                  value: accessible,
                  onChanged: (value) =>
                      setDialogState(() => accessible = value),
                ),
                TextFormField(
                  key: const Key("location-snapshot-status"),
                  initialValue: snapshotStatus,
                  onChanged: (value) =>
                      setDialogState(() => snapshotStatus = value),
                  decoration: appFieldDecoration(
                    context,
                    decoration: const InputDecoration(labelText: "狀態"),
                  ),
                ),
                DropdownButtonFormField<String>(
                  style: appDropdownTextStyle(context),
                  isDense: true,
                  isExpanded: true,
                  iconSize: AppControlSize.smallIcon,
                  itemHeight: appDropdownItemHeight(context),
                  menuMaxHeight: AppControlSize.menuMaxHeight,
                  key: const Key("location-snapshot-controller"),
                  initialValue: controllerCharacterId ?? "",
                  decoration: appDropdownFieldDecoration(
                    context,
                    decoration: const InputDecoration(labelText: "控制者"),
                  ),
                  items: [
                    const DropdownMenuItem(value: "", child: Text("未設定")),
                    if (controllerCharacterId != null &&
                        !characters.any(
                          (entry) => entry.key == controllerCharacterId,
                        ))
                      DropdownMenuItem(
                        value: controllerCharacterId,
                        child: Text("找不到：$controllerCharacterId"),
                      ),
                    for (final entry in characters)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value.displayName),
                      ),
                  ],
                  onChanged: (value) => setDialogState(
                    () => controllerCharacterId = value?.isEmpty == true
                        ? null
                        : value,
                  ),
                ),
                if (includeDescendants) ...[
                  const SizedBox(height: 12),
                  Container(
                    key: const Key("location-snapshot-batch-preview"),
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: AppSurfaceShape.borderRadius,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "批次差異預覽",
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        for (final line in batchPreviewLines()) Text(line),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("取消"),
            ),
            FilledButton(
              key: const Key("location-snapshot-confirm"),
              onPressed: () {
                if (!includeDescendants) {
                  final keys = snapshotProperties
                      .map((entry) => entry.key.trim())
                      .where((key) => key.isNotEmpty)
                      .toList(growable: false);
                  final hasValueWithoutKey = snapshotProperties.any(
                    (entry) =>
                        entry.key.trim().isEmpty &&
                        entry.value.trim().isNotEmpty,
                  );
                  if (hasValueWithoutKey ||
                      keys.toSet().length != keys.length) {
                    setDialogState(
                      () => propertyValidationError = hasValueWithoutKey
                          ? "屬性有鍵值時必須填寫設定名稱。"
                          : "自訂屬性的設定名稱不可重複。",
                    );
                    return;
                  }
                }
                Navigator.pop(context, true);
              },
              child: const Text("新增快照"),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    snapshotName = snapshotName.trim();
    snapshotDescription = snapshotDescription.trim();
    snapshotStatus = snapshotStatus.trim();
    final properties = <String, String>{};
    for (final entry in snapshotProperties) {
      final key = entry.key.trim();
      if (key.isNotEmpty) properties[key] = entry.value.trim();
    }
    final selectedScene = scenes.firstWhere(
      (scene) => scene.placementId == placementId,
    );
    final targets = includeDescendants ? subtreeLocations : [location];
    final transactionId = targets.length > 1 ? const Uuid().v4() : null;
    final changes = targets
        .map(
          (target) => LocationStateChange(
            locationId: target.id,
            sceneUUID: selectedScene.sceneId,
            sourcePlacementUUID: selectedScene.placementId,
            fallbackTick: selectedScene.startTick,
            transactionId: transactionId,
            patch: LocationStatePatch(
              exists: StateValue.set(exists),
              name: includeDescendants ? null : StateValue.set(snapshotName),
              description: includeDescendants
                  ? null
                  : StateValue.set(snapshotDescription),
              properties: includeDescendants
                  ? null
                  : StateValue.set(properties),
              accessible: StateValue.set(accessible),
              status: StateValue.set(snapshotStatus),
              controllerCharacterId: StateValue<String?>.set(
                controllerCharacterId,
              ),
            ),
          ),
        )
        .toList(growable: false);
    ref.read(itemWorkspaceProvider.notifier).putLocationStateChanges(changes);
    final selectedChange = changes.firstWhere(
      (change) => change.locationId == location.id,
    );
    setState(() => _selectedLocationSnapshotId = selectedChange.stateChangeId);
    ref
        .read(timelineViewProvider.notifier)
        .setCurrentTick(selectedScene.startTick);
    AppFeedback.success(
      context,
      targets.length == 1 ? "已新增地點快照" : "已新增 ${targets.length} 筆地點快照",
    );
  }

  Future<void> _removeLocationSnapshot(LocationStateChange change) async {
    final workspace = ref.read(itemWorkspaceProvider);
    final transactionId = change.transactionId;
    final removedIds = workspace.locationStateChanges
        .where(
          (candidate) => transactionId == null
              ? candidate.stateChangeId == change.stateChangeId
              : candidate.transactionId == transactionId,
        )
        .map((candidate) => candidate.stateChangeId)
        .toSet();
    if (removedIds.length > 1) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("刪除整批地點快照？"),
          content: Text("這筆快照與其他子地點屬於同一次批次操作，將一併刪除 ${removedIds.length} 筆快照。"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("取消"),
            ),
            FilledButton(
              key: const Key("location-snapshot-delete-batch-confirm"),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("整批刪除"),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    ref
        .read(itemWorkspaceProvider.notifier)
        .removeLocationStateChange(change.stateChangeId);
    if (removedIds.contains(_selectedLocationSnapshotId) && mounted) {
      setState(() => _selectedLocationSnapshotId = null);
    }
    AppFeedback.success(
      context,
      removedIds.length > 1 ? "已刪除 ${removedIds.length} 筆地點快照" : "已刪除地點快照",
    );
  }

  Map<String, String> _sceneLabels() {
    final labels = <String, String>{};
    for (final storyline in ref.read(outlineDataProvider)) {
      for (final event in storyline.scenes) {
        for (final scene in event.scenes) {
          labels[scene.sceneUUID] = "${event.storyEvent} / ${scene.sceneName}";
        }
      }
    }
    return labels;
  }

  Widget _buildLocationItemProjection(String locationId, int tick) {
    final workspace = ref.watch(itemWorkspaceProvider);
    final relatedEntries =
        workspace.itemRelations
            .where(
              (relation) =>
                  relation.targetKind == ItemRelationTargetKind.location &&
                  relation.targetId == locationId,
            )
            .map((relation) {
              final instance = relation.itemKind == ItemReferenceKind.instance
                  ? workspace.itemInstances[relation.itemId]
                  : null;
              final classId = relation.itemKind == ItemReferenceKind.itemClass
                  ? relation.itemId
                  : instance?.classId;
              final label = relation.itemKind == ItemReferenceKind.itemClass
                  ? workspace.itemClasses[classId]?.name
                  : instance?.name;
              return (
                relation: relation,
                classId: classId,
                label: label?.isNotEmpty == true ? label! : relation.itemId,
              );
            })
            .where((entry) => entry.classId != null)
            .toList(growable: false)
          ..sort((a, b) => a.label.compareTo(b.label));
    final entries = <_LocationItemProjectionEntry>[];
    for (final itemClass in workspace.itemClasses.values) {
      final unit = itemClass.unit.trim();
      final state = ref.watch(
        itemClassSnapshotProvider((id: itemClass.classId, tick: tick)),
      );
      if (state?.exists == true && state!.allocations.isNotEmpty) {
        for (final allocation in state.allocations.where(
          (value) => value.locationId == locationId,
        )) {
          entries.add(
            _LocationItemProjectionEntry(
              id: allocation.allocationId,
              classId: itemClass.classId,
              itemId: itemClass.classId,
              itemKind: ItemReferenceKind.itemClass,
              name: state.name.isEmpty ? itemClass.name : state.name,
              quantity: allocation.quantity == null
                  ? "未知"
                  : "${allocation.quantity}${unit.isEmpty ? "" : " $unit"}",
              description: allocation.note.isNotEmpty
                  ? allocation.note
                  : state.status,
            ),
          );
        }
      }
      if (itemClass.mode == ItemMode.generic) continue;
      for (final instance in workspace.itemInstances.values.where(
        (value) => value.classId == itemClass.classId,
      )) {
        final state = ref.watch(
          itemInstanceSnapshotProvider((id: instance.instanceId, tick: tick)),
        );
        if (state == null || !state.exists || state.locationId != locationId) {
          continue;
        }
        entries.add(
          _LocationItemProjectionEntry(
            id: instance.instanceId,
            classId: itemClass.classId,
            itemId: instance.instanceId,
            itemKind: ItemReferenceKind.instance,
            name: state.name.isEmpty
                ? (instance.name.isEmpty ? itemClass.name : instance.name)
                : state.name,
            quantity: "1${unit.isEmpty ? "" : " $unit"}",
            description: state.status,
          ),
        );
      }
    }
    entries.sort((a, b) => a.name.compareTo(b.name));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: SmallTitle(icon: Icons.link_outlined, text: "一般關聯物品"),
            ),
            FilledButton.tonalIcon(
              key: const Key("location-link-item"),
              onPressed: () => _linkItemToLocation(locationId),
              icon: const Icon(Icons.add_link),
              label: const Text("連結物品"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (relatedEntries.isEmpty)
          const Text("尚未設定一般物品關聯。")
        else
          ...relatedEntries.map(
            (entry) => ListTile(
              dense: true,
              key: ValueKey(
                "location-related-item-${entry.relation.relationId}",
              ),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link),
              title: Text(entry.label),
              subtitle: Text(
                [
                  if (entry.relation.role.isNotEmpty) entry.relation.role,
                  if (entry.relation.note.isNotEmpty) entry.relation.note,
                ].join("・"),
              ),
              trailing: Wrap(
                children: [
                  if (widget.onOpenItem != null)
                    IconButton(
                      key: ValueKey(
                        "location-open-related-item-${entry.relation.relationId}",
                      ),
                      tooltip: "開啟物品頁",
                      onPressed: () => widget.onOpenItem!(entry.classId!),
                      icon: const Icon(Icons.open_in_new),
                    ),
                  IconButton(
                    key: ValueKey(
                      "location-unlink-item-${entry.relation.relationId}",
                    ),
                    tooltip: "解除關聯",
                    onPressed: () => ref
                        .read(itemWorkspaceProvider.notifier)
                        .removeRelation(entry.relation.relationId),
                    icon: const Icon(Icons.link_off),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: SmallTitle(
                icon: Icons.inventory_2_outlined,
                text: "目前位於本地點的物品",
              ),
            ),
            FilledButton.tonalIcon(
              key: const Key("location-assign-item"),
              onPressed: () => _assignItemToLocation(locationId),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text("分配物品"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          const AppEmptyState(
            title: "目前沒有物品",
            description: "按「分配物品」即可在此頁設定所在地或聚合數量",
            icon: Icons.inventory_2_outlined,
            compact: true,
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              key: const ValueKey("location-items-table"),
              columns: const [
                DataColumn(label: Text("物品")),
                DataColumn(label: Text("數量"), numeric: true),
                DataColumn(label: Text("狀態／備註")),
                DataColumn(label: Text("操作")),
              ],
              rows: entries
                  .map(
                    (entry) => DataRow(
                      key: ValueKey("location-item-${entry.id}"),
                      cells: [
                        DataCell(
                          TextButton.icon(
                            key: ValueKey("location-open-item-${entry.id}"),
                            onPressed: widget.onOpenItem == null
                                ? null
                                : () => widget.onOpenItem!(entry.classId),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: Text(entry.name),
                          ),
                        ),
                        DataCell(Text(entry.quantity)),
                        DataCell(Text(entry.description)),
                        DataCell(
                          IconButton(
                            key: ValueKey("location-unassign-item-${entry.id}"),
                            tooltip: "清除預設分配",
                            onPressed: () =>
                                _clearLocationItemAssignment(locationId, entry),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
      ],
    );
  }

  Future<void> _linkItemToLocation(String locationId) async {
    final workspace = ref.read(itemWorkspaceProvider);
    final excluded = workspace.itemRelations
        .where(
          (relation) =>
              relation.targetKind == ItemRelationTargetKind.location &&
              relation.targetId == locationId,
        )
        .map(
          (relation) =>
              "${relation.itemKind == ItemReferenceKind.itemClass ? ProjectObjectKind.itemClass.name : ProjectObjectKind.itemInstance.name}:${relation.itemId}",
        )
        .toSet();
    final selected = await showProjectObjectSelector(
      context: context,
      title: "選擇要連結的地點物品",
      allowedKinds: const {
        ProjectObjectKind.itemClass,
        ProjectObjectKind.itemInstance,
      },
      excludedKeys: excluded,
    );
    final itemKind = selected?.itemReferenceKind;
    if (!mounted || selected == null || itemKind == null) return;
    ref
        .read(itemWorkspaceProvider.notifier)
        .putRelation(
          ItemRelationData(
            relationId: const Uuid().v4(),
            itemId: selected.id,
            itemKind: itemKind,
            targetId: locationId,
            targetKind: ItemRelationTargetKind.location,
            role: "相關",
          ),
        );
  }

  Future<void> _assignItemToLocation(String locationId) async {
    final selected = await showProjectObjectSelector(
      context: context,
      title: "選擇要放在本地點的物品",
      allowedKinds: const {
        ProjectObjectKind.itemClass,
        ProjectObjectKind.itemInstance,
      },
    );
    final itemKind = selected?.itemReferenceKind;
    if (!mounted || selected == null || itemKind == null) return;
    int? quantity = 1;
    final workspace = ref.read(itemWorkspaceProvider);
    final itemClass = workspace.itemClasses[selected.classId ?? selected.id];
    if (itemKind == ItemReferenceKind.itemClass &&
        itemClass != null &&
        itemClass.mode != ItemMode.dedicated) {
      var quantityText = "1";
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("分配「${selected.label}」"),
          content: TextFormField(
            key: const Key("location-assignment-quantity"),
            autofocus: true,
            keyboardType: TextInputType.number,
            initialValue: quantityText,
            decoration: appFieldDecoration(
              context,
              decoration: const InputDecoration(
                labelText: "數量",
                helperText: "留空代表數量未知",
              ),
            ),
            onChanged: (value) => quantityText = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("取消"),
            ),
            FilledButton(
              key: const Key("location-assignment-confirm"),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("分配"),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      quantity = quantityText.trim().isEmpty
          ? null
          : int.tryParse(quantityText.trim());
      if (quantityText.trim().isNotEmpty &&
          (quantity == null || quantity < 0)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("數量必須是零或正整數。")));
        return;
      }
    }
    try {
      final current = ref.read(itemWorkspaceProvider);
      final result = assignItemDefault(
        itemClasses: current.itemClasses,
        itemInstances: current.itemInstances,
        itemKind: itemKind,
        itemId: selected.id,
        targetKind: ItemRelationTargetKind.location,
        targetId: locationId,
        allocationId: const Uuid().v4(),
        quantity: quantity,
      );
      ref
          .read(itemWorkspaceProvider.notifier)
          .setWorkspace(
            current.copyWith(
              itemClasses: result.itemClasses,
              itemInstances: result.itemInstances,
            ),
          );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("無法分配物品：$error")));
      }
    }
  }

  void _clearLocationItemAssignment(
    String locationId,
    _LocationItemProjectionEntry entry,
  ) {
    final current = ref.read(itemWorkspaceProvider);
    final result = clearItemDefaultAssignment(
      itemClasses: current.itemClasses,
      itemInstances: current.itemInstances,
      itemKind: entry.itemKind,
      itemId: entry.itemId,
      targetKind: ItemRelationTargetKind.location,
      targetId: locationId,
    );
    ref
        .read(itemWorkspaceProvider.notifier)
        .setWorkspace(
          current.copyWith(
            itemClasses: result.itemClasses,
            itemInstances: result.itemInstances,
          ),
        );
  }

  Future<void> _migrateLegacyWorldItems() async {
    final worldNodes = ref.read(worldSettingsDataProvider);
    final count = countWorldItemNodes(worldNodes);
    if (count == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("搬移舊版世界物品"),
        content: Text("將 $count 筆物品子節點搬到新版物品管理；原 ID、內容與來源路徑會保留。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("取消"),
          ),
          FilledButton(
            key: const Key("world-migrate-items-confirm"),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("搬移"),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _flushDetailDraft();
    final latestWorldNodes = ref.read(worldSettingsDataProvider);
    final workspace = ref.read(itemWorkspaceProvider);
    final result = migrateWorldItems(
      worldNodes: latestWorldNodes,
      existingClasses: workspace.itemClasses,
      existingInstances: workspace.itemInstances,
    );
    ref
        .read(worldSettingsDataProvider.notifier)
        .setWorldSettingsData(result.worldNodes);
    ref
        .read(itemWorkspaceProvider.notifier)
        .setWorkspace(
          workspace.copyWith(
            itemClasses: result.itemClasses,
            itemInstances: result.itemInstances,
          ),
        );
    setState(() {
      selectedNodeId = null;
      lastSelectedNodeId = null;
      _selectedLocationSnapshotId = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("已搬移 ${result.migratedCount} 筆物品到新版物品管理。")),
      );
    }
  }

  // MARK: - UI 介面建構
  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(worldSettingsDataProvider);
    final tick = ref.watch(timelineViewProvider).currentTick;
    final flatList = _buildFlatList(locations, tick: tick);
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final menuIconColor = Theme.of(context).colorScheme.onSurface;
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
                padding: AppLayoutSpacing.pageForWidth(constraints.maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Row(
                      children: [
                        const LargeTitle(icon: Icons.public, text: "世界設定"),
                        const Spacer(),
                        PopupMenuButton<String>(
                          icon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.grid_view, color: menuIconColor),
                              const SizedBox(width: 4),
                              const Text("模板管理"),
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
                                return _buildLocationRow(item);
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
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
                              borderRadius: AppSurfaceShape.borderRadius,
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerLowest,
                            ),
                            padding: const EdgeInsets.all(AppSpacing.lg),
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

  Widget _buildLocationRow(_FlatNode item) {
    final location = item.node;
    final depth = item.depth;
    final snapshot = item.snapshot;
    final isSelected = selectedNodeId == location.id;
    final isEditing = editingNodeId == location.id;
    final isUnavailable = snapshot?.exists == false;

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
            : isUnavailable
            ? Theme.of(context).colorScheme.onSurfaceVariant
            : Theme.of(context).colorScheme.onSurface,
        decoration: isUnavailable ? TextDecoration.lineThrough : null,
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
        isUnavailable ? Icons.location_off_outlined : location.nodeType.icon,
        size: 20,
        color: isUnavailable
            ? Theme.of(context).colorScheme.onSurfaceVariant
            : Theme.of(context).colorScheme.primary,
      ),
      title: Row(
        children: [
          Flexible(child: titleWidget),
          RevisionRecordMarker(
            recordKey: ProjectRecordKey(
              kind: ProjectRecordKind.worldNode,
              recordId: location.id,
            ),
          ),
        ],
      ),
      subtitle: Text(
        [
          "${location.nodeType.label} • ${location.child.length} 個子節點",
          if (isUnavailable) "此 Tick 尚未存在",
          if (item.retainedShell) "保留樹殼：仍有存在的子地點",
          if (item.unavailableAncestor && !isUnavailable)
            "父層在此 Tick 不存在；此節點仍獨立存在",
          if (snapshot != null &&
              snapshot.name.isNotEmpty &&
              snapshot.name != location.localName)
            "當時名稱：${snapshot.name}",
        ].join("\n"),
        key: ValueKey("location-timeline-status-${location.id}"),
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
          _selectedLocationSnapshotId = null;
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
    final tick = ref.watch(timelineViewProvider).currentTick;
    final snapshot = location.nodeType == WorldNodeType.location
        ? ref.watch(locationSnapshotProvider((id: location.id, tick: tick)))
        : null;
    final sceneLabels = _sceneLabels();
    final characterLabels = {
      for (final entry in ref.watch(characterDataProvider).entries)
        entry.key: entry.value.displayName,
    };
    final locationChanges =
        ref
            .watch(itemWorkspaceProvider)
            .locationStateChanges
            .where((value) => value.locationId == location.id)
            .toList(growable: false)
          ..sort((a, b) {
            final tickOrder = b.fallbackTick.compareTo(a.fallbackTick);
            return tickOrder != 0
                ? tickOrder
                : b.sequence.compareTo(a.sequence);
          });
    final selectedSnapshotChange = locationChanges
        .where((change) => change.stateChangeId == _selectedLocationSnapshotId)
        .firstOrNull;
    final snapshotSelection =
        selectedSnapshotChange?.stateChangeId ?? _baselineSnapshotSelection;

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
          Row(
            children: [
              Expanded(
                child: CollaborativeProjectTextFieldRegion(
                  key: ValueKey("world-name-${location.id}"),
                  fieldId: ProjectCollaborativeTextCodec.worldNodeFieldId(
                    location.id,
                    "localName",
                  ),
                  crdtDocumentId:
                      ProjectCollaborativeTextCodec.worldNodeFieldId(
                        location.id,
                        "localName",
                      ),
                  controller: locationNameController,
                  focusNode: _locationNameFocusNode,
                  shouldPublishTextChanges: () => !_isSyncingDetailControllers,
                  child: AppTextField(
                    controller: locationNameController,
                    focusNode: _locationNameFocusNode,
                    decoration: const InputDecoration(
                      labelText: "名稱",
                      isDense: true,
                    ),
                  ),
                ),
              ),
              RevisionFieldMarker(
                recordKey: ProjectRecordKey(
                  kind: ProjectRecordKind.worldNode,
                  recordId: location.id,
                ),
                field: 'name',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 類型
          Row(
            children: [
              Expanded(
                child: CollaborativeProjectTextFieldRegion(
                  key: ValueKey("world-type-${location.id}"),
                  fieldId: ProjectCollaborativeTextCodec.worldNodeFieldId(
                    location.id,
                    "localType",
                  ),
                  crdtDocumentId:
                      ProjectCollaborativeTextCodec.worldNodeFieldId(
                        location.id,
                        "localType",
                      ),
                  controller: locationTypeController,
                  focusNode: _locationTypeFocusNode,
                  shouldPublishTextChanges: () => !_isSyncingDetailControllers,
                  child: AppTextField(
                    controller: locationTypeController,
                    focusNode: _locationTypeFocusNode,
                    decoration: const InputDecoration(
                      labelText: "類型",
                      isDense: true,
                    ),
                  ),
                ),
              ),
              RevisionFieldMarker(
                recordKey: ProjectRecordKey(
                  kind: ProjectRecordKind.worldNode,
                  recordId: location.id,
                ),
                field: 'localType',
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (location.nodeType == WorldNodeType.item)
            AppNoticeBanner(
              message: "這是舊版物品子節點。新版物品不再存放於世界設定樹，請搬移後在本頁地點區直接管理分配。",
              icon: Icons.move_down_outlined,
              tone: AppFeedbackTone.warning,
              action: TextButton.icon(
                key: const Key("world-migrate-items"),
                onPressed: _migrateLegacyWorldItems,
                icon: const Icon(Icons.move_down_outlined),
                label: const Text("搬移全部物品"),
              ),
            )
          else
            AppDropdownField<WorldNodeType>(
              value: location.nodeType,
              labelText: "節點類別",
              options: WorldNodeType.values
                  .where((type) => type != WorldNodeType.item)
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

          if (location.nodeType == WorldNodeType.location) ...[
            Row(
              children: [
                Expanded(
                  child: AppDropdownField<String>(
                    key: ValueKey(
                      "location-snapshot-selector-${location.id}-$snapshotSelection",
                    ),
                    value: snapshotSelection,
                    labelText: "地點快照",
                    options: [
                      const DropdownOption(
                        value: _baselineSnapshotSelection,
                        label: "預設",
                      ),
                      for (final change in locationChanges.reversed)
                        DropdownOption(
                          value: change.stateChangeId,
                          label:
                              sceneLabels[change.sceneUUID] ?? change.sceneUUID,
                        ),
                    ],
                    onChanged: (value) {
                      final selectedId = value == _baselineSnapshotSelection
                          ? null
                          : value;
                      setState(() => _selectedLocationSnapshotId = selectedId);
                      if (selectedId == null) return;
                      final change = locationChanges.firstWhere(
                        (entry) => entry.stateChangeId == selectedId,
                      );
                      final resolved = resolveLocationStateChangeTime(
                        change,
                        ref.read(timelineDocumentProvider),
                      );
                      ref
                          .read(timelineViewProvider.notifier)
                          .setCurrentTick(resolved.resolvedTick);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: ValueKey("location-add-snapshot-${location.id}"),
                  tooltip: "新增 Scene 快照",
                  onPressed: () => _addLocationSnapshot(location),
                  style: IconButton.styleFrom(foregroundColor: Colors.green),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                ),
                IconButton(
                  key: ValueKey(
                    "location-delete-selected-snapshot-${location.id}",
                  ),
                  tooltip: "刪除目前快照",
                  onPressed: selectedSnapshotChange == null
                      ? null
                      : () => _removeLocationSnapshot(selectedSnapshotChange),
                  style: IconButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.movie_outlined),
                title: const Text("目前故事狀態"),
                subtitle: Text(
                  snapshot == null
                      ? "無快照"
                      : [
                          if (snapshot.name.isNotEmpty) "名稱：${snapshot.name}",
                          if (snapshot.description.isNotEmpty)
                            "描述：${snapshot.description}",
                          if (snapshot.properties.isNotEmpty)
                            "屬性：${snapshot.properties.entries.map((entry) => "${entry.key}=${entry.value}").join("、")}",
                          snapshot.exists ? "存在" : "尚未存在",
                          snapshot.accessible ? "可進入" : "不可進入",
                          if (snapshot.status.isNotEmpty) snapshot.status,
                          if (snapshot.controllerCharacterId != null)
                            "控制者：${characterLabels[snapshot.controllerCharacterId] ?? snapshot.controllerCharacterId}",
                        ].join("・"),
                ),
              ),
            ),
            if (locationChanges.isNotEmpty)
              Material(
                color: Colors.transparent,
                child: ExpansionTile(
                  key: ValueKey("location-snapshot-history-${location.id}"),
                  leading: const Icon(Icons.history),
                  title: Text("地點快照歷程（${locationChanges.length}）"),
                  children: locationChanges
                      .map(
                        (change) => ListTile(
                          key: ValueKey(
                            "location-snapshot-${change.stateChangeId}",
                          ),
                          title: Text(
                            sceneLabels[change.sceneUUID] ?? change.sceneUUID,
                          ),
                          subtitle: Text(
                            change.patch.status?.value?.isNotEmpty == true
                                ? change.patch.status!.value!
                                : "連結此 Scene",
                          ),
                          trailing: IconButton(
                            tooltip: "移除地點快照",
                            onPressed: () => _removeLocationSnapshot(change),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            _buildLocationItemProjection(location.id, tick),
            const SizedBox(height: 16),
          ],

          // 自訂值表
          Text("自訂值表:", style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          AppTwoColumnTable(
            firstHeader: "設定",
            secondHeader: "鍵值",
            bodyHeight: 200,
            onSelectionCleared: _clearCustomValueSelection,
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
                    firstCell: AppEditableTableCell(
                      key: ValueKey("custom-key-${item.id}"),
                      value: item.key,
                      selected: selectedCustomValueId == item.id,
                      onEditStarted: () =>
                          _selectCustomValueForEditing(location.id, item),
                      onEditCanceled: _clearCustomValueSelection,
                      onSubmitted: (value) => _updateCustomValueCell(
                        location.id,
                        item.id,
                        key: value,
                      ),
                    ),
                    secondCell: AppEditableTableCell(
                      key: ValueKey("custom-value-${item.id}"),
                      value: item.val,
                      selected: selectedCustomValueId == item.id,
                      onEditStarted: () =>
                          _selectCustomValueForEditing(location.id, item),
                      onEditCanceled: _clearCustomValueSelection,
                      onSubmitted: (value) => _updateCustomValueCell(
                        location.id,
                        item.id,
                        value: value,
                      ),
                    ),
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
          Row(
            children: [
              Expanded(
                child: CollaborativeProjectTextFieldRegion(
                  key: ValueKey("world-note-${location.id}"),
                  fieldId: ProjectCollaborativeTextCodec.worldNodeFieldId(
                    location.id,
                    "note",
                  ),
                  crdtDocumentId:
                      ProjectCollaborativeTextCodec.worldNodeFieldId(
                        location.id,
                        "note",
                      ),
                  controller: locationNoteController,
                  focusNode: _locationNoteFocusNode,
                  shouldPublishTextChanges: () => !_isSyncingDetailControllers,
                  child: AppTextField(
                    controller: locationNoteController,
                    focusNode: _locationNoteFocusNode,
                    decoration: const InputDecoration(isDense: true),
                    maxLines: 4,
                  ),
                ),
              ),
              RevisionFieldMarker(
                recordKey: ProjectRecordKey(
                  kind: ProjectRecordKind.worldNode,
                  recordId: location.id,
                ),
                field: 'note',
              ),
            ],
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

  Future<void> _deleteNode(String id) async {
    final location = _getLocation(id, _locations);
    if (location == null) return;
    final workspace = ref.read(itemWorkspaceProvider);
    final locationIds = LocationDeletionPlanner.collectSubtreeIds(location);
    final impact = LocationDeletionPlanner.inspect(
      locationIds: locationIds,
      itemClasses: workspace.itemClasses,
      itemInstances: workspace.itemInstances,
      itemRelations: workspace.itemRelations,
      itemClassStateChanges: workspace.itemClassStateChanges,
      itemInstanceStateChanges: workspace.itemInstanceStateChanges,
      locationStateChanges: workspace.locationStateChanges,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("永久刪除「${location.localName}」？"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("若只是讓地點在故事中消失，請新增 Scene 快照並關閉「此時已存在」。"),
            const SizedBox(height: 12),
            Text("將永久刪除 ${impact.locationCount} 個地點節點"),
            Text("移除 ${impact.snapshotCount} 筆地點快照"),
            Text("移除 ${impact.relationCount} 筆物品關聯"),
            Text("清除 ${impact.itemPlacementCount} 筆物品地點記錄"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("取消"),
          ),
          FilledButton(
            key: const Key("location-permanent-delete-confirm"),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("永久刪除"),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final cleanup = LocationDeletionPlanner.cleanup(
      locationIds: locationIds,
      itemClasses: workspace.itemClasses,
      itemInstances: workspace.itemInstances,
      itemRelations: workspace.itemRelations,
      itemClassStateChanges: workspace.itemClassStateChanges,
      itemInstanceStateChanges: workspace.itemInstanceStateChanges,
      locationStateChanges: workspace.locationStateChanges,
    );
    final removed = ref
        .read(worldSettingsDataProvider.notifier)
        .removeLocationById(id);
    if (!removed) {
      return;
    }
    ref
        .read(itemWorkspaceProvider.notifier)
        .setWorkspace(
          ItemWorkspaceData(
            itemClasses: cleanup.itemClasses,
            itemInstances: cleanup.itemInstances,
            itemRelations: cleanup.itemRelations,
            itemClassStateChanges: cleanup.itemClassStateChanges,
            itemInstanceStateChanges: cleanup.itemInstanceStateChanges,
            locationStateChanges: cleanup.locationStateChanges,
          ),
        );

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
    _isSyncingDetailControllers = true;
    try {
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
    } finally {
      _isSyncingDetailControllers = false;
    }
  }

  void _setControllerTextIfChanged(
    TextEditingController controller,
    String text,
  ) {
    if (controller.text == text || _isComposing(controller)) {
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
  final LocationSnapshotState? snapshot;
  final bool unavailableAncestor;
  final bool retainedShell;

  const _FlatNode(
    this.node,
    this.depth, {
    this.snapshot,
    this.unavailableAncestor = false,
    this.retainedShell = false,
  });
}
