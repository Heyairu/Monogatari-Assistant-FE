import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:uuid/uuid.dart";

import "../bin/ui_library.dart";
import "../application/items/world_item_migration.dart";
import "../application/items/item_operations.dart";
import "../models/item_data.dart";
import "../models/item_snapshot_data.dart";
import "../models/timeline_data.dart";
import "../models/world_settings_data.dart";
import "../presentation/providers/project_state_providers.dart";
import "../presentation/providers/timeline_providers.dart";
import "../presentation/widgets/project_object_selector.dart";

class ItemView extends ConsumerStatefulWidget {
  final String? initialClassId;
  final int selectionRequestId;

  const ItemView({super.key, this.initialClassId, this.selectionRequestId = 0});

  @override
  ConsumerState<ItemView> createState() => _ItemViewState();
}

class _ItemViewState extends ConsumerState<ItemView> {
  static const _uuid = Uuid();
  static const _baselineSnapshotSelection = "__baseline__";
  static const _allFilter = "__all__";
  String? _selectedClassId;
  String? _selectedClassSnapshotId;
  final Map<String, String?> _selectedInstanceSnapshotIds = {};
  final _searchController = TextEditingController();
  String _modeFilter = _allFilter;
  String _categoryFilter = _allFilter;
  String _assignmentFilter = _allFilter;

  @override
  void initState() {
    super.initState();
    _selectedClassId = widget.initialClassId;
  }

  @override
  void didUpdateWidget(covariant ItemView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectionRequestId != oldWidget.selectionRequestId) {
      _selectedClassId = widget.initialClassId;
      _selectedClassSnapshotId = null;
      _selectedInstanceSnapshotIds.clear();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _createClass() {
    final itemClass = ItemClassData(
      classId: _uuid.v4(),
      name: "新物品",
      mode: ItemMode.dedicated,
      defaultState: ItemSnapshotState(name: "新物品"),
    );
    ref.read(itemWorkspaceProvider.notifier).putClass(itemClass);
    ref
        .read(itemWorkspaceProvider.notifier)
        .putInstance(
          ItemInstanceData(
            instanceId: _uuid.v4(),
            classId: itemClass.classId,
            name: itemClass.name,
          ),
        );
    setState(() {
      _selectedClassId = itemClass.classId;
      _selectedClassSnapshotId = null;
      _selectedInstanceSnapshotIds.clear();
    });
  }

  void _updateClass(ItemClassData value) {
    ref.read(itemWorkspaceProvider.notifier).putClass(value);
  }

  void _createInstance(ItemClassData itemClass) {
    final instance = ItemInstanceData(
      instanceId: _uuid.v4(),
      classId: itemClass.classId,
      name: "${itemClass.name}（單件）",
    );
    ref.read(itemWorkspaceProvider.notifier).putInstance(instance);
  }

  List<_RelationTarget> _relationTargets() {
    final targets = <_RelationTarget>[];
    for (final entry in ref.read(characterDataProvider).entries) {
      targets.add(
        _RelationTarget(
          id: entry.key,
          kind: ItemRelationTargetKind.character,
          label: entry.value.displayName,
        ),
      );
    }
    void addLocations(List<LocationData> nodes, [String path = ""]) {
      for (final node in nodes) {
        final label = path.isEmpty
            ? node.localName
            : "$path / ${node.localName}";
        targets.add(
          _RelationTarget(
            id: node.id,
            kind: ItemRelationTargetKind.location,
            label: label,
          ),
        );
        addLocations(node.child, label);
      }
    }

    addLocations(ref.read(worldSettingsDataProvider));
    for (final storyline in ref.read(outlineDataProvider)) {
      for (final event in storyline.scenes) {
        targets.add(
          _RelationTarget(
            id: event.storyEventUUID,
            kind: ItemRelationTargetKind.event,
            label: event.storyEvent,
          ),
        );
        for (final scene in event.scenes) {
          targets.add(
            _RelationTarget(
              id: scene.sceneUUID,
              kind: ItemRelationTargetKind.scene,
              label: "${event.storyEvent} / ${scene.sceneName}",
            ),
          );
        }
      }
    }
    return targets;
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

  bool _previewIsCurrent({
    required ItemWorkspaceData workspace,
    required TimelineDocumentData timeline,
    required String sceneId,
    required String placementId,
    required int startTick,
  }) {
    if (!identical(ref.read(itemWorkspaceProvider), workspace) ||
        !identical(ref.read(timelineDocumentProvider), timeline)) {
      return false;
    }
    return _placedScenes().any(
      (scene) =>
          scene.sceneId == sceneId &&
          scene.placementId == placementId &&
          scene.startTick == startTick,
    );
  }

  void _showStalePreviewMessage() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("物品或 Scene 已更新，請重新開啟預覽後再提交。")));
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

  bool _isAssignedAtTick({
    required ItemClassData itemClass,
    required ItemWorkspaceData workspace,
    required int tick,
  }) {
    final timeline = ref.read(timelineDocumentProvider);
    final classState = resolveItemClassSnapshot(
      itemClass: itemClass,
      changes: workspace.itemClassStateChanges,
      timeline: timeline,
      atTick: tick,
    );
    if (classState.exists &&
        classState.allocations.any(
          (allocation) =>
              allocation.holderCharacterId != null ||
              allocation.locationId != null,
        )) {
      return true;
    }
    if (itemClass.mode == ItemMode.generic) return false;
    for (final instance in workspace.itemInstances.values.where(
      (value) => value.classId == itemClass.classId && !value.archived,
    )) {
      final state = resolveItemInstanceSnapshot(
        itemClass: itemClass,
        instance: instance,
        classChanges: workspace.itemClassStateChanges,
        instanceChanges: workspace.itemInstanceStateChanges,
        timeline: timeline,
        atTick: tick,
      );
      if (state.exists &&
          (state.holderCharacterId != null || state.locationId != null)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _addRelation(
    ItemClassData itemClass,
    List<ItemInstanceData> instances,
  ) async {
    final targets = _relationTargets();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("請先建立人物、地點或事件，再新增物品關聯。")));
      return;
    }
    var itemKind = ItemReferenceKind.itemClass;
    var itemId = itemClass.classId;
    var target = targets.first;
    var role = "";
    var note = "";
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("新增物品關聯"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  key: const Key("item-relation-subject"),
                  initialValue: "${itemKind.name}:$itemId",
                  decoration: const InputDecoration(labelText: "物品"),
                  items: [
                    DropdownMenuItem(
                      value:
                          "${ItemReferenceKind.itemClass.name}:${itemClass.classId}",
                      child: Text("Class：${itemClass.name}"),
                    ),
                    for (final instance in instances)
                      DropdownMenuItem(
                        value:
                            "${ItemReferenceKind.instance.name}:${instance.instanceId}",
                        child: Text("單件：${instance.name}"),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    final separator = value.indexOf(":");
                    itemKind = ItemReferenceKind.values.byName(
                      value.substring(0, separator),
                    );
                    itemId = value.substring(separator + 1);
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key("item-relation-target"),
                  icon: const Icon(Icons.manage_search),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "${_targetKindLabel(target.kind)}：${target.label}",
                    ),
                  ),
                  onPressed: () async {
                    final selected = await showProjectObjectSelector(
                      context: context,
                      title: "選擇連結目標",
                      allowedKinds: const {
                        ProjectObjectKind.character,
                        ProjectObjectKind.location,
                        ProjectObjectKind.event,
                        ProjectObjectKind.scene,
                      },
                    );
                    final kind = selected?.relationTargetKind;
                    if (selected == null || kind == null) return;
                    setDialogState(() {
                      target = _RelationTarget(
                        id: selected.id,
                        kind: kind,
                        label: selected.label,
                      );
                    });
                  },
                ),
                TextField(
                  onChanged: (value) => role = value,
                  decoration: const InputDecoration(labelText: "關係／用途"),
                ),
                TextField(
                  onChanged: (value) => note = value,
                  decoration: const InputDecoration(labelText: "備註"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("取消"),
            ),
            FilledButton(
              key: const Key("item-relation-confirm"),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("新增關聯"),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    ref
        .read(itemWorkspaceProvider.notifier)
        .putRelation(
          ItemRelationData(
            relationId: _uuid.v4(),
            itemId: itemId,
            itemKind: itemKind,
            targetId: target.id,
            targetKind: target.kind,
            role: role.trim(),
            note: note.trim(),
          ),
        );
  }

  Future<void> _addAllocation(ItemClassData itemClass) async {
    final targets = _relationTargets()
        .where(
          (value) =>
              value.kind == ItemRelationTargetKind.character ||
              value.kind == ItemRelationTargetKind.location,
        )
        .toList(growable: false);
    if (targets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("請先建立人物或地點，再新增數量分配。")));
      return;
    }
    var target = targets.first;
    var quantityText = "";
    var note = "";
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("新增數量分配"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  key: const Key("item-allocation-target"),
                  initialValue: "${target.kind.name}:${target.id}",
                  decoration: const InputDecoration(labelText: "分配對象"),
                  items: targets
                      .map(
                        (value) => DropdownMenuItem(
                          value: "${value.kind.name}:${value.id}",
                          child: Text(
                            "${_targetKindLabel(value.kind)}：${value.label}",
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() {
                      target = targets.firstWhere(
                        (candidate) =>
                            "${candidate.kind.name}:${candidate.id}" == value,
                      );
                    });
                  },
                ),
                TextField(
                  key: const Key("item-allocation-quantity"),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => quantityText = value,
                  decoration: const InputDecoration(
                    labelText: "數量",
                    helperText: "留空代表數量未知",
                  ),
                ),
                TextField(
                  onChanged: (value) => note = value,
                  decoration: const InputDecoration(labelText: "備註"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("取消"),
            ),
            FilledButton(
              key: const Key("item-allocation-confirm"),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("新增分配"),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final normalizedQuantity = quantityText.trim();
    final quantity = normalizedQuantity.isEmpty
        ? null
        : int.tryParse(normalizedQuantity);
    if (normalizedQuantity.isNotEmpty && (quantity == null || quantity < 0)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("數量必須是零或正整數，也可以留空表示未知。")));
      return;
    }
    final allocation = ItemAllocationData(
      allocationId: _uuid.v4(),
      holderCharacterId: target.kind == ItemRelationTargetKind.character
          ? target.id
          : null,
      locationId: target.kind == ItemRelationTargetKind.location
          ? target.id
          : null,
      quantity: quantity,
      note: note.trim(),
    );
    _updateClass(
      itemClass.copyWith(
        defaultState: itemClass.defaultState.copyWith(
          allocations: [...itemClass.defaultState.allocations, allocation],
        ),
      ),
    );
  }

  void _removeAllocation(ItemClassData itemClass, String allocationId) {
    _updateClass(
      itemClass.copyWith(
        defaultState: itemClass.defaultState.copyWith(
          allocations: itemClass.defaultState.allocations
              .where((value) => value.allocationId != allocationId)
              .toList(growable: false),
        ),
      ),
    );
  }

  Future<void> _transferAllocation(
    ItemClassData itemClass,
    ItemSnapshotState currentState,
    ItemAllocationData source,
  ) async {
    final scenes = _placedScenes();
    final targets = _relationTargets()
        .where(
          (value) =>
              (value.kind == ItemRelationTargetKind.character ||
                  value.kind == ItemRelationTargetKind.location) &&
              value.id != source.holderCharacterId &&
              value.id != source.locationId,
        )
        .toList(growable: false);
    if (scenes.isEmpty || targets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("轉移前需要至少一個場景及另一個人物或地點。")));
      return;
    }
    var placementId = scenes.first.placementId;
    var target = targets.first;
    var quantityText = "";
    var sourceAfterText = "";
    var destinationAfterText = "";
    var note = "";
    final previewWorkspace = ref.read(itemWorkspaceProvider);
    final previewTimeline = ref.read(timelineDocumentProvider);
    ItemSnapshotState stateAt(int tick) => resolveItemClassSnapshot(
      itemClass: itemClass,
      changes: previewWorkspace.itemClassStateChanges,
      timeline: previewTimeline,
      atTick: tick,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("轉移聚合數量"),
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
                    if (value != null) placementId = value;
                  },
                ),
                DropdownButtonFormField<String>(
                  key: const Key("item-transfer-target"),
                  initialValue: "${target.kind.name}:${target.id}",
                  decoration: const InputDecoration(labelText: "轉移至"),
                  items: targets
                      .map(
                        (value) => DropdownMenuItem(
                          value: "${value.kind.name}:${value.id}",
                          child: Text(
                            "${_targetKindLabel(value.kind)}：${value.label}",
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() {
                      target = targets.firstWhere(
                        (candidate) =>
                            "${candidate.kind.name}:${candidate.id}" == value,
                      );
                    });
                  },
                ),
                TextField(
                  key: const Key("item-transfer-quantity"),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => quantityText = value,
                  decoration: const InputDecoration(labelText: "轉移數量"),
                ),
                if (source.quantity == null)
                  TextField(
                    keyboardType: TextInputType.number,
                    onChanged: (value) => sourceAfterText = value,
                    decoration: const InputDecoration(
                      labelText: "轉移後來源數量",
                      helperText: "來源數量未知，必須明確設定",
                    ),
                  ),
                if (currentState.allocations.any(
                  (value) =>
                      value.quantity == null &&
                      ((target.kind == ItemRelationTargetKind.character &&
                              value.holderCharacterId == target.id) ||
                          (target.kind == ItemRelationTargetKind.location &&
                              value.locationId == target.id)),
                ))
                  TextField(
                    keyboardType: TextInputType.number,
                    onChanged: (value) => destinationAfterText = value,
                    decoration: const InputDecoration(
                      labelText: "轉移後目的數量",
                      helperText: "目的數量未知，必須明確設定",
                    ),
                  ),
                TextField(
                  onChanged: (value) => note = value,
                  decoration: const InputDecoration(labelText: "備註"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("取消"),
            ),
            FilledButton(
              key: const Key("item-transfer-confirm"),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("建立轉移快照"),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final selectedScene = scenes.firstWhere(
        (scene) => scene.placementId == placementId,
      );
      if (!_previewIsCurrent(
        workspace: previewWorkspace,
        timeline: previewTimeline,
        sceneId: selectedScene.sceneId,
        placementId: selectedScene.placementId,
        startTick: selectedScene.startTick,
      )) {
        _showStalePreviewMessage();
        return;
      }
      final result = transferAggregateItem(
        itemClass: itemClass,
        currentState: stateAt(selectedScene.startTick),
        request: AggregateItemTransferRequest(
          sourceAllocationId: source.allocationId,
          destinationCharacterId:
              target.kind == ItemRelationTargetKind.character
              ? target.id
              : null,
          destinationLocationId: target.kind == ItemRelationTargetKind.location
              ? target.id
              : null,
          quantity: int.tryParse(quantityText.trim()) ?? 0,
          sourceQuantityAfter: int.tryParse(sourceAfterText.trim()),
          destinationQuantityAfter: int.tryParse(destinationAfterText.trim()),
          destinationAllocationId: _uuid.v4(),
          sceneUUID: selectedScene.sceneId,
          sourcePlacementUUID: selectedScene.placementId,
          fallbackTick: selectedScene.startTick,
          note: note.trim(),
        ),
      );
      ref
          .read(itemWorkspaceProvider.notifier)
          .putClassStateChange(result.change);
      ref
          .read(timelineViewProvider.notifier)
          .setCurrentTick(selectedScene.startTick);
    } on ArgumentError catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message?.toString() ?? "$error")),
      );
    } on StateError catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _materializeAllocation(
    ItemClassData itemClass,
    ItemAllocationData source, {
    ItemMode targetMode = ItemMode.semiDedicated,
  }) async {
    final scenes = _placedScenes();
    if (scenes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("請先將 Scene 放入時間軸，再拆出單件物品。")));
      return;
    }
    var placementId = scenes.first.placementId;
    var instanceName = itemClass.name;
    var sourceAfterText = "";
    var note = "";
    final previewWorkspace = ref.read(itemWorkspaceProvider);
    final previewTimeline = ref.read(timelineDocumentProvider);
    ItemSnapshotState stateAt(int tick) => resolveItemClassSnapshot(
      itemClass: itemClass,
      changes: previewWorkspace.itemClassStateChanges,
      timeline: previewTimeline,
      atTick: tick,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedScene = scenes.firstWhere(
            (scene) => scene.placementId == placementId,
          );
          final sceneState = stateAt(selectedScene.startTick);
          final sceneSource = sceneState.allocations
              .where((value) => value.allocationId == source.allocationId)
              .firstOrNull;
          return AlertDialog(
            title: Text(
              targetMode == ItemMode.dedicated ? "建立專用單件" : "從聚合數量拆出單件",
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppDropdownField<String>(
                    value: placementId,
                    labelText: "建立於 Scene",
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
                  Text(
                    sceneSource == null
                        ? "所選 Scene 尚無這筆聚合分配。"
                        : sceneSource.quantity == null
                        ? "所選 Scene 的來源數量未知。"
                        : "所選 Scene 的來源數量：${sceneSource.quantity}",
                    key: const Key("item-materialize-preview"),
                  ),
                  TextFormField(
                    key: const Key("item-materialize-name"),
                    initialValue: instanceName,
                    onChanged: (value) => instanceName = value,
                    decoration: const InputDecoration(labelText: "單件名稱"),
                  ),
                  if (sceneSource?.quantity == null && sceneSource != null)
                    TextField(
                      key: const Key("item-materialize-source-after"),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => sourceAfterText = value,
                      decoration: const InputDecoration(
                        labelText: "拆出後來源數量",
                        helperText: "來源數量未知，必須明確設定",
                      ),
                    ),
                  TextField(
                    key: const Key("item-materialize-note"),
                    onChanged: (value) => note = value,
                    decoration: const InputDecoration(labelText: "轉換備註"),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("取消"),
              ),
              FilledButton(
                key: const Key("item-materialize-confirm"),
                onPressed: sceneSource == null
                    ? null
                    : () => Navigator.pop(context, true),
                child: const Text("建立單件"),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final selectedScene = scenes.firstWhere(
        (scene) => scene.placementId == placementId,
      );
      if (!_previewIsCurrent(
        workspace: previewWorkspace,
        timeline: previewTimeline,
        sceneId: selectedScene.sceneId,
        placementId: selectedScene.placementId,
        startTick: selectedScene.startTick,
      )) {
        _showStalePreviewMessage();
        return;
      }
      final conversionId = _uuid.v4();
      final result = materializeAggregateItem(
        itemClass: itemClass,
        currentState: stateAt(selectedScene.startTick),
        request: AggregateItemMaterializationRequest(
          sourceAllocationId: source.allocationId,
          sourceQuantityAfter: int.tryParse(sourceAfterText.trim()),
          instanceId: _uuid.v4(),
          instanceName: instanceName,
          sceneUUID: selectedScene.sceneId,
          sourcePlacementUUID: selectedScene.placementId,
          fallbackTick: selectedScene.startTick,
          conversionId: conversionId,
          note: note.trim(),
          targetMode: targetMode,
        ),
      );
      ref
          .read(itemWorkspaceProvider.notifier)
          .materializeAggregateInstance(
            itemClass: result.itemClass,
            instance: result.instance,
            classChange: result.classChange,
            instanceChange: result.instanceChange,
          );
      ref
          .read(timelineViewProvider.notifier)
          .setCurrentTick(selectedScene.startTick);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("已從聚合數量建立單件物品。")));
    } on ArgumentError catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message?.toString() ?? "$error")),
      );
    } on StateError catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _demoteToGeneric(
    ItemClassData itemClass,
    List<ItemInstanceData> instances,
  ) async {
    final scenes = _placedScenes();
    if (scenes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("請先將 Scene 放入時間軸，再轉為非專用。")));
      return;
    }
    var placementId = scenes.first.placementId;
    var note = "";
    final workspace = ref.read(itemWorkspaceProvider);
    final timeline = ref.read(timelineDocumentProvider);
    List<ItemSnapshotState> statesAt(int tick) => instances
        .map(
          (instance) => resolveItemInstanceSnapshot(
            itemClass: itemClass,
            instance: instance,
            classChanges: workspace.itemClassStateChanges,
            instanceChanges: workspace.itemInstanceStateChanges,
            timeline: timeline,
            atTick: tick,
          ),
        )
        .toList(growable: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedScene = scenes.firstWhere(
            (scene) => scene.placementId == placementId,
          );
          final activeStates = statesAt(
            selectedScene.startTick,
          ).where((state) => state.exists).toList(growable: false);
          final groupedTargets = activeStates
              .map(
                (state) =>
                    "${state.holderCharacterId ?? ""}|${state.locationId ?? ""}",
              )
              .toSet();
          return AlertDialog(
            title: const Text("安全轉為非專用"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppDropdownField<String>(
                    value: placementId,
                    labelText: "轉換 Scene",
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
                  const SizedBox(height: 12),
                  Text(
                    "將彙總 ${activeStates.length} 件當時存在的單件，建立 ${groupedTargets.length} 筆聚合分配。",
                    key: const Key("item-demotion-preview"),
                  ),
                  const SizedBox(height: 8),
                  const Text("原 Class、instance ID、快照與一般關聯會保留為封存歷史。"),
                  TextField(
                    key: const Key("item-demotion-note"),
                    onChanged: (value) => note = value,
                    decoration: const InputDecoration(labelText: "轉換備註"),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("取消"),
              ),
              FilledButton(
                key: const Key("item-demotion-confirm"),
                onPressed: () => Navigator.pop(context, true),
                child: const Text("建立聚合 Class"),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true || !mounted) return;
    final selectedScene = scenes.firstWhere(
      (scene) => scene.placementId == placementId,
    );
    if (!_previewIsCurrent(
      workspace: workspace,
      timeline: timeline,
      sceneId: selectedScene.sceneId,
      placementId: selectedScene.placementId,
      startTick: selectedScene.startTick,
    )) {
      _showStalePreviewMessage();
      return;
    }
    final currentStates = <String, ItemSnapshotState>{};
    final states = statesAt(selectedScene.startTick);
    for (var index = 0; index < instances.length; index++) {
      currentStates[instances[index].instanceId] = states[index];
    }
    try {
      final currentClassState = resolveItemClassSnapshot(
        itemClass: itemClass,
        changes: workspace.itemClassStateChanges,
        timeline: timeline,
        atTick: selectedScene.startTick,
      );
      final result = demoteIdentifiedItems(
        itemClass: itemClass,
        instances: instances,
        currentClassState: currentClassState,
        currentStates: currentStates,
        request: IdentifiedItemDemotionRequest(
          targetClassId: _uuid.v4(),
          sceneUUID: selectedScene.sceneId,
          sourcePlacementUUID: selectedScene.placementId,
          fallbackTick: selectedScene.startTick,
          conversionId: _uuid.v4(),
          note: note.trim(),
        ),
      );
      ref
          .read(itemWorkspaceProvider.notifier)
          .demoteIdentifiedClass(
            sourceClass: result.sourceClass,
            sourceInstances: result.sourceInstances,
            targetClass: result.targetClass,
            sourceClassChange: result.sourceClassChange,
            targetClassChange: result.targetClassChange,
            sourceInstanceChanges: result.sourceInstanceChanges,
          );
      ref
          .read(timelineViewProvider.notifier)
          .setCurrentTick(selectedScene.startTick);
      setState(() {
        _selectedClassId = result.targetClass.classId;
        _selectedClassSnapshotId = result.targetClassChange.stateChangeId;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("已建立新的非專用聚合 Class。")));
    } on ArgumentError catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message?.toString() ?? "$error")),
      );
    } on StateError catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _changeMode(
    ItemClassData itemClass,
    ItemMode mode,
    List<ItemInstanceData> instances,
  ) async {
    if (mode == ItemMode.generic && itemClass.mode != ItemMode.generic) {
      await _demoteToGeneric(itemClass, instances);
      return;
    }
    if (itemClass.mode == ItemMode.generic &&
        mode == ItemMode.dedicated &&
        instances.isEmpty) {
      final tick = ref.read(timelineViewProvider).currentTick;
      final currentState = ref.read(
        itemClassSnapshotProvider((id: itemClass.classId, tick: tick)),
      );
      final sources =
          currentState?.allocations
              .where(
                (allocation) =>
                    allocation.quantity == null || allocation.quantity! > 0,
              )
              .toList(growable: false) ??
          const <ItemAllocationData>[];
      if (sources.isNotEmpty) {
        if (sources.length != 1 ||
            (sources.single.quantity != null && sources.single.quantity != 1)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("轉為專用前只能剩下一筆、數量為 1 的聚合分配；可先轉為半專用逐件拆分。"),
            ),
          );
          return;
        }
        await _materializeAllocation(
          itemClass,
          sources.single,
          targetMode: ItemMode.dedicated,
        );
        return;
      }
    }
    if (itemClass.mode == ItemMode.semiDedicated &&
        mode == ItemMode.dedicated) {
      if (instances.length > 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("目前有多個固定 ID，不能直接合併為一件專用物品。")),
        );
        return;
      }
      final tick = ref.read(timelineViewProvider).currentTick;
      final currentState = ref.read(
        itemClassSnapshotProvider((id: itemClass.classId, tick: tick)),
      );
      final remainingStock =
          currentState?.allocations.any(
            (allocation) =>
                allocation.quantity == null || allocation.quantity! > 0,
          ) ??
          false;
      if (remainingStock) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("仍有未拆分的聚合數量，請先逐件拆分後再轉為專用。")),
        );
        return;
      }
    }
    try {
      ref
          .read(itemWorkspaceProvider.notifier)
          .changeClassMode(
            classId: itemClass.classId,
            mode: mode,
            dedicatedInstanceId: _uuid.v4(),
          );
    } on ArgumentError catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message?.toString() ?? "$error")),
      );
    } on StateError catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _migrateWorldItems() async {
    final worldNodes = ref.read(worldSettingsDataProvider);
    final count = countWorldItemNodes(worldNodes);
    if (count == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("搬移世界設定物品"),
        content: Text("將 $count 筆世界設定物品搬到獨立物品頁。原物品 ID、內容與來源路徑會保留。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("取消"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("搬移"),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final workspace = ref.read(itemWorkspaceProvider);
    final result = migrateWorldItems(
      worldNodes: worldNodes,
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "已搬移 ${result.migratedCount} 筆物品${result.warnings.isEmpty ? "" : "，${result.warnings.length} 筆需留意"}",
        ),
      ),
    );
  }

  Future<void> _addClassSnapshot(ItemClassData itemClass) async {
    final scenes = _placedScenes();
    if (scenes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("請先將 Scene 放入時間軸，再新增物品快照。")));
      return;
    }
    var placementId = scenes.first.placementId;
    var exists = true;
    var status = "";
    String? holderCharacterId;
    String? locationId;
    final characters = _relationTargets()
        .where((value) => value.kind == ItemRelationTargetKind.character)
        .toList(growable: false);
    final locations = _relationTargets()
        .where((value) => value.kind == ItemRelationTargetKind.location)
        .toList(growable: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("新增物品場景快照"),
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
                    if (value != null) placementId = value;
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("此時已存在"),
                  value: exists,
                  onChanged: (value) => setDialogState(() => exists = value),
                ),
                TextField(
                  onChanged: (value) => status = value,
                  decoration: const InputDecoration(labelText: "狀態"),
                ),
                DropdownButtonFormField<String>(
                  key: const Key("item-class-snapshot-holder"),
                  initialValue: "",
                  decoration: const InputDecoration(labelText: "持有人"),
                  items: [
                    const DropdownMenuItem(value: "", child: Text("未設定")),
                    for (final character in characters)
                      DropdownMenuItem(
                        value: character.id,
                        child: Text(character.label),
                      ),
                  ],
                  onChanged: (value) =>
                      holderCharacterId = value?.isEmpty == true ? null : value,
                ),
                DropdownButtonFormField<String>(
                  key: const Key("item-class-snapshot-location"),
                  initialValue: "",
                  decoration: const InputDecoration(labelText: "所在地"),
                  items: [
                    const DropdownMenuItem(value: "", child: Text("未設定")),
                    for (final location in locations)
                      DropdownMenuItem(
                        value: location.id,
                        child: Text(location.label),
                      ),
                  ],
                  onChanged: (value) =>
                      locationId = value?.isEmpty == true ? null : value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("取消"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("新增快照"),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final selectedScene = scenes.firstWhere(
      (scene) => scene.placementId == placementId,
    );
    final change = ItemClassStateChange(
      classId: itemClass.classId,
      sceneUUID: selectedScene.sceneId,
      sourcePlacementUUID: selectedScene.placementId,
      fallbackTick: selectedScene.startTick,
      patch: ItemStatePatch(
        exists: StateValue.set(exists),
        status: StateValue.set(status),
        holderCharacterId: StateValue<String?>.set(holderCharacterId),
        locationId: StateValue<String?>.set(locationId),
      ),
    );
    ref.read(itemWorkspaceProvider.notifier).putClassStateChange(change);
    setState(() => _selectedClassSnapshotId = change.stateChangeId);
    ref
        .read(timelineViewProvider.notifier)
        .setCurrentTick(selectedScene.startTick);
  }

  Future<void> _addInstanceSnapshot(ItemInstanceData instance) async {
    final scenes = _placedScenes();
    if (scenes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("請先將 Scene 放入時間軸，再新增單件物品快照。")),
      );
      return;
    }
    var placementId = scenes.first.placementId;
    var exists = true;
    var status = "";
    String? holderCharacterId;
    String? locationId;
    final characters = _relationTargets()
        .where((value) => value.kind == ItemRelationTargetKind.character)
        .toList(growable: false);
    final locations = _relationTargets()
        .where((value) => value.kind == ItemRelationTargetKind.location)
        .toList(growable: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("新增「${instance.name}」場景快照"),
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
                    if (value != null) placementId = value;
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("此時已存在"),
                  value: exists,
                  onChanged: (value) => setDialogState(() => exists = value),
                ),
                TextField(
                  onChanged: (value) => status = value,
                  decoration: const InputDecoration(labelText: "狀態"),
                ),
                DropdownButtonFormField<String>(
                  key: const Key("item-instance-snapshot-holder"),
                  initialValue: "",
                  decoration: const InputDecoration(labelText: "持有人"),
                  items: [
                    const DropdownMenuItem(value: "", child: Text("未設定")),
                    for (final character in characters)
                      DropdownMenuItem(
                        value: character.id,
                        child: Text(character.label),
                      ),
                  ],
                  onChanged: (value) =>
                      holderCharacterId = value?.isEmpty == true ? null : value,
                ),
                DropdownButtonFormField<String>(
                  key: const Key("item-instance-snapshot-location"),
                  initialValue: "",
                  decoration: const InputDecoration(labelText: "所在地"),
                  items: [
                    const DropdownMenuItem(value: "", child: Text("未設定")),
                    for (final location in locations)
                      DropdownMenuItem(
                        value: location.id,
                        child: Text(location.label),
                      ),
                  ],
                  onChanged: (value) =>
                      locationId = value?.isEmpty == true ? null : value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("取消"),
            ),
            FilledButton(
              key: const Key("item-instance-snapshot-confirm"),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("新增快照"),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final selectedScene = scenes.firstWhere(
      (scene) => scene.placementId == placementId,
    );
    final change = ItemInstanceStateChange(
      instanceId: instance.instanceId,
      sceneUUID: selectedScene.sceneId,
      sourcePlacementUUID: selectedScene.placementId,
      fallbackTick: selectedScene.startTick,
      patch: ItemStatePatch(
        exists: StateValue.set(exists),
        status: StateValue.set(status.trim()),
        holderCharacterId: StateValue<String?>.set(holderCharacterId),
        locationId: StateValue<String?>.set(locationId),
      ),
    );
    ref.read(itemWorkspaceProvider.notifier).putInstanceStateChange(change);
    setState(() {
      _selectedInstanceSnapshotIds[instance.instanceId] = change.stateChangeId;
    });
    ref
        .read(timelineViewProvider.notifier)
        .setCurrentTick(selectedScene.startTick);
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(itemWorkspaceProvider);
    final query = _searchController.text.trim().toLowerCase();
    final tick = ref.watch(
      timelineViewProvider.select((state) => state.currentTick),
    );
    final categories =
        workspace.itemClasses.values
            .where(
              (value) => !value.archived && value.category.trim().isNotEmpty,
            )
            .map((value) => value.category.trim())
            .toSet()
            .toList()
          ..sort();
    final classes =
        workspace.itemClasses.values
            .where((value) => !value.archived)
            .where(
              (value) =>
                  query.isEmpty ||
                  value.name.toLowerCase().contains(query) ||
                  value.category.toLowerCase().contains(query),
            )
            .where(
              (value) =>
                  _modeFilter == _allFilter || value.mode.name == _modeFilter,
            )
            .where(
              (value) =>
                  _categoryFilter == _allFilter ||
                  value.category.trim() == _categoryFilter,
            )
            .where((value) {
              if (_assignmentFilter == _allFilter) return true;
              final assigned = _isAssignedAtTick(
                itemClass: value,
                workspace: workspace,
                tick: tick,
              );
              return _assignmentFilter == "assigned" ? assigned : !assigned;
            })
            .toList(growable: false)
          ..sort((a, b) => a.name.compareTo(b.name));
    final selected = workspace.itemClasses[_selectedClassId];
    final worldItemCount = countWorldItemNodes(
      ref.watch(worldSettingsDataProvider),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("物品設定"),
        actions: [
          if (worldItemCount > 0)
            IconButton(
              key: const Key("item-migrate-world"),
              tooltip: "搬移世界設定中的 $worldItemCount 筆物品",
              onPressed: _migrateWorldItems,
              icon: const Icon(Icons.move_down),
            ),
          IconButton(
            key: const Key("item-add-class"),
            tooltip: "新增物品",
            onPressed: _createClass,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 720) {
            return selected == null
                ? _buildClassList(classes, categories)
                : _buildDetails(selected, workspace);
          }
          return Row(
            children: [
              SizedBox(width: 300, child: _buildClassList(classes, categories)),
              const VerticalDivider(width: 1),
              Expanded(
                child: selected == null
                    ? const Center(child: Text("選擇或新增物品"))
                    : _buildDetails(selected, workspace),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildClassList(List<ItemClassData> classes, List<String> categories) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: "搜尋物品",
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppDropdownField<String>(
                      key: const Key("item-mode-filter"),
                      value: _modeFilter,
                      labelText: "管理模式",
                      options: [
                        const DropdownOption(value: _allFilter, label: "全部"),
                        for (final mode in ItemMode.values)
                          DropdownOption(
                            value: mode.name,
                            label: _modeLabel(mode),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _modeFilter = value ?? _allFilter),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppDropdownField<String>(
                      key: const Key("item-assignment-filter"),
                      value: _assignmentFilter,
                      labelText: "歸屬",
                      options: const [
                        DropdownOption(value: _allFilter, label: "全部"),
                        DropdownOption(value: "assigned", label: "已有歸屬"),
                        DropdownOption(value: "unassigned", label: "尚無歸屬"),
                      ],
                      onChanged: (value) => setState(
                        () => _assignmentFilter = value ?? _allFilter,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AppDropdownField<String>(
                key: const Key("item-category-filter"),
                value: _categoryFilter,
                labelText: "分類",
                options: [
                  const DropdownOption(value: _allFilter, label: "全部分類"),
                  for (final category in categories)
                    DropdownOption(value: category, label: category),
                ],
                onChanged: (value) =>
                    setState(() => _categoryFilter = value ?? _allFilter),
              ),
            ],
          ),
        ),
        Expanded(
          child: classes.isEmpty
              ? Center(
                  child: FilledButton.icon(
                    onPressed: _createClass,
                    icon: const Icon(Icons.add),
                    label: const Text("新增第一個物品"),
                  ),
                )
              : ListView.builder(
                  itemCount: classes.length,
                  itemBuilder: (context, index) {
                    final itemClass = classes[index];
                    return ListTile(
                      selected: itemClass.classId == _selectedClassId,
                      leading: Icon(_modeIcon(itemClass.mode)),
                      title: Text(
                        itemClass.name.trim().isEmpty
                            ? "未命名物品"
                            : itemClass.name,
                      ),
                      subtitle: Text(_modeLabel(itemClass.mode)),
                      onTap: () => setState(() {
                        _selectedClassId = itemClass.classId;
                        _selectedClassSnapshotId = null;
                        _selectedInstanceSnapshotIds.clear();
                      }),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDetails(ItemClassData itemClass, ItemWorkspaceData workspace) {
    final instances = workspace.itemInstances.values
        .where((value) => value.classId == itemClass.classId && !value.archived)
        .toList(growable: false);
    final tick = ref.watch(timelineViewProvider).currentTick;
    final snapshot = ref.watch(
      itemClassSnapshotProvider((id: itemClass.classId, tick: tick)),
    );
    final instanceIds = instances.map((value) => value.instanceId).toSet();
    final relations = workspace.itemRelations
        .where(
          (value) =>
              (value.itemKind == ItemReferenceKind.itemClass &&
                  value.itemId == itemClass.classId) ||
              (value.itemKind == ItemReferenceKind.instance &&
                  instanceIds.contains(value.itemId)),
        )
        .toList(growable: false);
    final targetLabels = {
      for (final target in _relationTargets())
        "${target.kind.name}:${target.id}": target.label,
    };
    final sceneLabels = _sceneLabels();
    final classChanges =
        workspace.itemClassStateChanges
            .where((value) => value.classId == itemClass.classId)
            .toList(growable: false)
          ..sort((a, b) {
            final tickOrder = b.fallbackTick.compareTo(a.fallbackTick);
            return tickOrder != 0
                ? tickOrder
                : b.sequence.compareTo(a.sequence);
          });
    final selectedSnapshotChange = classChanges
        .where((change) => change.stateChangeId == _selectedClassSnapshotId)
        .firstOrNull;
    final snapshotSelection =
        selectedSnapshotChange?.stateChangeId ?? _baselineSnapshotSelection;

    return ListView(
      key: ValueKey("item-details-${itemClass.classId}"),
      padding: const EdgeInsets.all(16),
      children: [
        if (MediaQuery.sizeOf(context).width < 720)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _selectedClassId = null),
              icon: const Icon(Icons.arrow_back),
              label: const Text("返回物品清單"),
            ),
          ),
        TextFormField(
          key: ValueKey("item-name-${itemClass.classId}"),
          initialValue: itemClass.name,
          decoration: const InputDecoration(labelText: "名稱"),
          onChanged: (value) => _updateClass(
            itemClass.copyWith(
              name: value,
              defaultState: itemClass.defaultState.copyWith(name: value),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey("item-unit-${itemClass.classId}"),
          initialValue: itemClass.unit,
          decoration: const InputDecoration(labelText: "數量單位"),
          onChanged: (value) => _updateClass(itemClass.copyWith(unit: value)),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: ValueKey("item-category-${itemClass.classId}"),
          initialValue: itemClass.category,
          decoration: const InputDecoration(labelText: "分類"),
          onChanged: (value) =>
              _updateClass(itemClass.copyWith(category: value)),
        ),
        const SizedBox(height: 16),
        Text("管理模式", style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<ItemMode>(
          key: const Key("item-mode-switch"),
          segments: ItemMode.values
              .map(
                (mode) => ButtonSegment(
                  value: mode,
                  icon: Icon(_modeIcon(mode)),
                  label: Text(_modeLabel(mode)),
                ),
              )
              .toList(growable: false),
          selected: {itemClass.mode},
          onSelectionChanged: (selection) {
            _changeMode(itemClass, selection.single, instances);
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          key: ValueKey("item-description-${itemClass.classId}"),
          initialValue: itemClass.description,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: "設定說明",
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => _updateClass(
            itemClass.copyWith(
              description: value,
              defaultState: itemClass.defaultState.copyWith(description: value),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: AppDropdownField<String>(
                key: ValueKey(
                  "item-snapshot-selector-${itemClass.classId}-$snapshotSelection",
                ),
                value: snapshotSelection,
                labelText: "物品快照",
                options: [
                  const DropdownOption(
                    value: _baselineSnapshotSelection,
                    label: "預設",
                  ),
                  for (final change in classChanges.reversed)
                    DropdownOption(
                      value: change.stateChangeId,
                      label: sceneLabels[change.sceneUUID] ?? change.sceneUUID,
                    ),
                ],
                onChanged: (value) {
                  final selectedId = value == _baselineSnapshotSelection
                      ? null
                      : value;
                  setState(() => _selectedClassSnapshotId = selectedId);
                  if (selectedId == null) return;
                  final change = classChanges.firstWhere(
                    (entry) => entry.stateChangeId == selectedId,
                  );
                  final resolved = resolveItemClassStateChangeTime(
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
              key: const Key("item-add-snapshot"),
              tooltip: "新增 Scene 快照",
              onPressed: () => _addClassSnapshot(itemClass),
              style: IconButton.styleFrom(foregroundColor: Colors.green),
              icon: const Icon(Icons.add_photo_alternate_outlined),
            ),
            IconButton(
              key: const Key("item-delete-selected-snapshot"),
              tooltip: "刪除目前快照",
              onPressed: selectedSnapshotChange == null
                  ? null
                  : () {
                      ref
                          .read(itemWorkspaceProvider.notifier)
                          .removeClassStateChange(
                            selectedSnapshotChange.stateChangeId,
                          );
                      setState(() => _selectedClassSnapshotId = null);
                    },
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
                      snapshot.exists ? "存在" : "尚未存在",
                      snapshot.status.isEmpty ? "未設定狀態" : snapshot.status,
                      if (snapshot.holderCharacterId != null)
                        "持有人：${targetLabels["${ItemRelationTargetKind.character.name}:${snapshot.holderCharacterId}"] ?? snapshot.holderCharacterId}",
                      if (snapshot.locationId != null)
                        "所在地：${targetLabels["${ItemRelationTargetKind.location.name}:${snapshot.locationId}"] ?? snapshot.locationId}",
                    ].join("・"),
            ),
          ),
        ),
        if (classChanges.isNotEmpty)
          ExpansionTile(
            key: const Key("item-class-snapshot-history"),
            leading: const Icon(Icons.history),
            title: Text("Class 快照歷程（${classChanges.length}）"),
            children: classChanges
                .map(
                  (change) => ListTile(
                    key: ValueKey(
                      "item-class-snapshot-${change.stateChangeId}",
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
                      tooltip: "移除快照",
                      onPressed: () => ref
                          .read(itemWorkspaceProvider.notifier)
                          .removeClassStateChange(change.stateChangeId),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                "單件物品",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (itemClass.mode == ItemMode.semiDedicated ||
                (itemClass.mode == ItemMode.dedicated && instances.isEmpty))
              FilledButton.tonalIcon(
                key: const Key("item-add-instance"),
                onPressed: () => _createInstance(itemClass),
                icon: const Icon(Icons.add),
                label: const Text("新增單件"),
              ),
          ],
        ),
        if (itemClass.mode != ItemMode.dedicated ||
            (snapshot?.allocations.isNotEmpty ??
                itemClass.defaultState.allocations.isNotEmpty))
          _buildAllocations(
            itemClass,
            snapshot ?? itemClass.defaultState,
            targetLabels,
            tick,
          )
        else
          const SizedBox.shrink(),
        if (itemClass.mode != ItemMode.generic && instances.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text("尚未建立單件物品。"),
          )
        else if (itemClass.mode != ItemMode.generic)
          ...instances.map((instance) {
            final changes =
                workspace.itemInstanceStateChanges
                    .where((value) => value.instanceId == instance.instanceId)
                    .toList(growable: false)
                  ..sort((a, b) {
                    final tickOrder = b.fallbackTick.compareTo(a.fallbackTick);
                    return tickOrder != 0
                        ? tickOrder
                        : b.sequence.compareTo(a.sequence);
                  });
            final selectedChange = changes
                .where(
                  (change) =>
                      change.stateChangeId ==
                      _selectedInstanceSnapshotIds[instance.instanceId],
                )
                .firstOrNull;
            final selection =
                selectedChange?.stateChangeId ?? _baselineSnapshotSelection;
            return ExpansionTile(
              key: ValueKey("item-instance-${instance.instanceId}"),
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(
                instance.name.isEmpty ? itemClass.name : instance.name,
              ),
              subtitle: Text("ID：${instance.instanceId}"),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppDropdownField<String>(
                              key: ValueKey(
                                "item-instance-snapshot-selector-${instance.instanceId}-$selection",
                              ),
                              value: selection,
                              labelText: "單件物品快照",
                              options: [
                                const DropdownOption(
                                  value: _baselineSnapshotSelection,
                                  label: "預設",
                                ),
                                for (final change in changes.reversed)
                                  DropdownOption(
                                    value: change.stateChangeId,
                                    label:
                                        sceneLabels[change.sceneUUID] ??
                                        change.sceneUUID,
                                  ),
                              ],
                              onChanged: (value) {
                                final selectedId =
                                    value == _baselineSnapshotSelection
                                    ? null
                                    : value;
                                setState(() {
                                  _selectedInstanceSnapshotIds[instance
                                          .instanceId] =
                                      selectedId;
                                });
                                if (selectedId == null) return;
                                final change = changes.firstWhere(
                                  (entry) => entry.stateChangeId == selectedId,
                                );
                                final resolved =
                                    resolveItemInstanceStateChangeTime(
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
                            key: ValueKey(
                              "item-instance-add-snapshot-${instance.instanceId}",
                            ),
                            tooltip: "新增 Scene 快照",
                            onPressed: () => _addInstanceSnapshot(instance),
                            style: IconButton.styleFrom(
                              foregroundColor: Colors.green,
                            ),
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                            ),
                          ),
                          IconButton(
                            key: ValueKey(
                              "item-instance-delete-selected-snapshot-${instance.instanceId}",
                            ),
                            tooltip: "刪除目前快照",
                            onPressed: selectedChange == null
                                ? null
                                : () {
                                    ref
                                        .read(itemWorkspaceProvider.notifier)
                                        .removeInstanceStateChange(
                                          selectedChange.stateChangeId,
                                        );
                                    setState(() {
                                      _selectedInstanceSnapshotIds.remove(
                                        instance.instanceId,
                                      );
                                    });
                                  },
                            style: IconButton.styleFrom(
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                            ),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final state = ref.watch(
                            itemInstanceSnapshotProvider((
                              id: instance.instanceId,
                              tick: tick,
                            )),
                          );
                          return Text(
                            [
                              state?.exists == false ? "此場景尚未存在" : "此場景存在",
                              if (state?.status.isNotEmpty == true)
                                state!.status,
                              if (state?.holderCharacterId != null)
                                "持有人：${targetLabels["${ItemRelationTargetKind.character.name}:${state!.holderCharacterId}"] ?? state.holderCharacterId}",
                              if (state?.locationId != null)
                                "所在地：${targetLabels["${ItemRelationTargetKind.location.name}:${state!.locationId}"] ?? state.locationId}",
                            ].join("・"),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                if (changes.isNotEmpty)
                  ...changes.map(
                    (change) => ListTile(
                      dense: true,
                      key: ValueKey(
                        "item-instance-snapshot-${change.stateChangeId}",
                      ),
                      leading: const Icon(Icons.history, size: 20),
                      title: Text(
                        sceneLabels[change.sceneUUID] ?? change.sceneUUID,
                      ),
                      subtitle: Text(
                        change.patch.status?.value?.isNotEmpty == true
                            ? change.patch.status!.value!
                            : "連結此 Scene",
                      ),
                    ),
                  ),
              ],
            );
          }),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text("關聯", style: Theme.of(context).textTheme.titleMedium),
            ),
            FilledButton.tonalIcon(
              key: const Key("item-add-relation"),
              onPressed: () => _addRelation(itemClass, instances),
              icon: const Icon(Icons.add_link),
              label: const Text("新增關聯"),
            ),
          ],
        ),
        if (relations.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text("尚未連結人物、地點或事件。"),
          )
        else
          ...relations.map(
            (relation) => ListTile(
              key: ValueKey("item-relation-${relation.relationId}"),
              leading: const Icon(Icons.link),
              title: Text(
                targetLabels["${relation.targetKind.name}:${relation.targetId}"] ??
                    relation.targetId,
              ),
              subtitle: Text(
                [
                  _targetKindLabel(relation.targetKind),
                  if (relation.role.isNotEmpty) relation.role,
                  if (relation.note.isNotEmpty) relation.note,
                ].join("・"),
              ),
              trailing: IconButton(
                tooltip: "移除關聯",
                onPressed: () => ref
                    .read(itemWorkspaceProvider.notifier)
                    .removeRelation(relation.relationId),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAllocations(
    ItemClassData itemClass,
    ItemSnapshotState currentState,
    Map<String, String> targetLabels,
    int tick,
  ) {
    final allocations = currentState.allocations;
    final knownTotal = allocations
        .where((value) => value.quantity != null)
        .fold<int>(0, (sum, value) => sum + value.quantity!);
    final hasUnknown = allocations.any((value) => value.quantity == null);
    final unit = itemClass.unit.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(switch (itemClass.mode) {
            ItemMode.generic => "非專用模式以 Class 與聚合分配管理，不建立單件 ID。",
            ItemMode.semiDedicated => "半專用模式保留尚未識別的聚合數量，並可在 Scene 中逐件拆出固定 ID。",
            ItemMode.dedicated => "此區顯示轉為專用前的歷史聚合數量。",
          }),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                "數量分配：$knownTotal${unit.isEmpty ? "" : " $unit"}${hasUnknown ? "，另有未知數量" : ""}",
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            FilledButton.tonalIcon(
              key: const Key("item-add-allocation"),
              onPressed: () => _addAllocation(itemClass),
              icon: const Icon(Icons.add),
              label: const Text("新增分配"),
            ),
          ],
        ),
        if (allocations.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text("尚未分配數量。"),
          )
        else
          ...allocations.map((allocation) {
            final hasTarget =
                allocation.holderCharacterId != null ||
                allocation.locationId != null;
            final targetKey = allocation.holderCharacterId != null
                ? "${ItemRelationTargetKind.character.name}:${allocation.holderCharacterId}"
                : "${ItemRelationTargetKind.location.name}:${allocation.locationId}";
            return ListTile(
              key: ValueKey("item-allocation-${allocation.allocationId}"),
              leading: Icon(
                allocation.holderCharacterId != null
                    ? Icons.person_outline
                    : allocation.locationId != null
                    ? Icons.place_outlined
                    : Icons.inventory_2_outlined,
              ),
              title: Text(
                hasTarget ? targetLabels[targetKey] ?? "找不到分配對象" : "未分配",
              ),
              subtitle: Text(
                [
                  allocation.quantity == null
                      ? "數量未知"
                      : "${allocation.quantity}${unit.isEmpty ? "" : " $unit"}",
                  if (allocation.note.isNotEmpty) allocation.note,
                ].join("・"),
              ),
              trailing: Wrap(
                children: [
                  if (itemClass.mode != ItemMode.dedicated)
                    IconButton(
                      key: ValueKey("item-transfer-${allocation.allocationId}"),
                      tooltip: "轉移數量",
                      onPressed: () => _transferAllocation(
                        itemClass,
                        currentState,
                        allocation,
                      ),
                      icon: const Icon(Icons.swap_horiz),
                    ),
                  if (itemClass.mode == ItemMode.semiDedicated)
                    IconButton(
                      key: ValueKey(
                        "item-materialize-${allocation.allocationId}",
                      ),
                      tooltip: "拆出單件物品",
                      onPressed: () =>
                          _materializeAllocation(itemClass, allocation),
                      icon: const Icon(Icons.call_split_outlined),
                    ),
                  if (itemClass.mode != ItemMode.dedicated)
                    IconButton(
                      tooltip: "移除預設分配",
                      onPressed:
                          itemClass.defaultState.allocations.any(
                            (value) =>
                                value.allocationId == allocation.allocationId,
                          )
                          ? () => _removeAllocation(
                              itemClass,
                              allocation.allocationId,
                            )
                          : null,
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

String _modeLabel(ItemMode mode) => switch (mode) {
  ItemMode.dedicated => "專用",
  ItemMode.semiDedicated => "半專用",
  ItemMode.generic => "非專用",
};

String _targetKindLabel(ItemRelationTargetKind kind) => switch (kind) {
  ItemRelationTargetKind.character => "人物",
  ItemRelationTargetKind.location => "地點",
  ItemRelationTargetKind.event => "事件",
  ItemRelationTargetKind.scene => "場景",
};

class _RelationTarget {
  final String id;
  final ItemRelationTargetKind kind;
  final String label;

  const _RelationTarget({
    required this.id,
    required this.kind,
    required this.label,
  });
}

IconData _modeIcon(ItemMode mode) => switch (mode) {
  ItemMode.dedicated => Icons.fingerprint,
  ItemMode.semiDedicated => Icons.account_tree_outlined,
  ItemMode.generic => Icons.category_outlined,
};
