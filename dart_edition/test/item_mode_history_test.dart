import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/application/items/item_operations.dart";
import "package:monogatari_assistant/models/item_data.dart";
import "package:monogatari_assistant/models/item_snapshot_data.dart";
import "package:monogatari_assistant/models/project_data.dart";
import "package:monogatari_assistant/presentation/providers/project_history_provider.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";

ProjectData _withWorkspace(ProjectData source, ItemWorkspaceData workspace) {
  return ProjectData(
    projectUUID: source.projectUUID,
    baseInfoData: source.baseInfoData,
    segmentsData: source.segmentsData,
    outlineData: source.outlineData,
    foreshadowData: source.foreshadowData,
    updatePlanData: source.updatePlanData,
    worldSettingsData: source.worldSettingsData,
    itemClasses: workspace.itemClasses,
    itemInstances: workspace.itemInstances,
    itemRelations: workspace.itemRelations,
    itemClassStateChanges: workspace.itemClassStateChanges,
    itemInstanceStateChanges: workspace.itemInstanceStateChanges,
    locationStateChanges: workspace.locationStateChanges,
    characterData: source.characterData,
    characterStates: source.characterStates,
    characterStateBaselines: source.characterStateBaselines,
    characterStateChanges: source.characterStateChanges,
    timelineDocument: source.timelineDocument,
    outlineChapterLinks: source.outlineChapterLinks,
    totalWords: source.totalWords,
    contentText: source.contentText,
    isDirty: true,
  );
}

ProjectHistoryEntry _entry(ProjectData data) {
  return ProjectHistoryEntry(
    data: data,
    pageIndex: 15,
    selectedSegID: data.segmentsData.single.segmentUUID,
    selectedChapID: data.segmentsData.single.chapters.single.chapterUUID,
    cursorOffset: 0,
  );
}

ItemMode _activeMode(ProjectData data) {
  return data.itemClasses.values.singleWhere((value) => !value.archived).mode;
}

({ItemWorkspaceData before, ItemWorkspaceData after}) _convert(
  ItemMode from,
  ItemMode to,
) {
  final container = ProviderContainer();
  try {
    final notifier = container.read(itemWorkspaceProvider.notifier);
    final itemClass = ItemClassData(
      classId: "source",
      name: "測試物品",
      mode: from,
      defaultState: from == ItemMode.generic
          ? ItemSnapshotState(
              allocations: [
                ItemAllocationData(
                  allocationId: "stock",
                  locationId: "warehouse",
                  quantity: 1,
                ),
              ],
            )
          : null,
    );
    notifier.putClass(itemClass);
    if (from != ItemMode.generic) {
      notifier.putInstance(
        ItemInstanceData(
          instanceId: "instance",
          classId: itemClass.classId,
          name: "測試物品",
        ),
      );
    }
    final before = container.read(itemWorkspaceProvider);

    if (from == ItemMode.generic) {
      final result = materializeAggregateItem(
        itemClass: itemClass,
        currentState: itemClass.defaultState,
        request: AggregateItemMaterializationRequest(
          sourceAllocationId: "stock",
          instanceId: "instance",
          instanceName: "測試物品",
          sceneUUID: "conversion-scene",
          sourcePlacementUUID: "conversion-placement",
          fallbackTick: 10,
          conversionId: "${from.name}-${to.name}",
          targetMode: to,
        ),
      );
      notifier.materializeAggregateInstance(
        itemClass: result.itemClass,
        instance: result.instance,
        classChange: result.classChange,
        instanceChange: result.instanceChange,
      );
    } else if (to == ItemMode.generic) {
      final instance = before.itemInstances.values.single;
      final result = demoteIdentifiedItems(
        itemClass: itemClass,
        instances: [instance],
        currentClassState: itemClass.defaultState,
        currentStates: {
          instance.instanceId: ItemSnapshotState(locationId: "warehouse"),
        },
        request: IdentifiedItemDemotionRequest(
          targetClassId: "aggregate",
          sceneUUID: "conversion-scene",
          sourcePlacementUUID: "conversion-placement",
          fallbackTick: 10,
          conversionId: "${from.name}-${to.name}",
        ),
      );
      notifier.demoteIdentifiedClass(
        sourceClass: result.sourceClass,
        sourceInstances: result.sourceInstances,
        targetClass: result.targetClass,
        sourceClassChange: result.sourceClassChange,
        targetClassChange: result.targetClassChange,
        sourceInstanceChanges: result.sourceInstanceChanges,
      );
    } else {
      notifier.changeClassMode(classId: "source", mode: to);
    }
    return (before: before, after: container.read(itemWorkspaceProvider));
  } finally {
    container.dispose();
  }
}

void main() {
  final directions = <(ItemMode, ItemMode)>[
    (ItemMode.dedicated, ItemMode.semiDedicated),
    (ItemMode.dedicated, ItemMode.generic),
    (ItemMode.semiDedicated, ItemMode.dedicated),
    (ItemMode.semiDedicated, ItemMode.generic),
    (ItemMode.generic, ItemMode.dedicated),
    (ItemMode.generic, ItemMode.semiDedicated),
  ];

  for (final direction in directions) {
    test(
      "${direction.$1.name} to ${direction.$2.name} survives undo and redo",
      () {
        final converted = _convert(direction.$1, direction.$2);
        final seed = ProjectData.empty(
          projectUUID: "11111111-1111-4111-8111-111111111111",
        );
        final before = _withWorkspace(seed, converted.before);
        final after = _withWorkspace(seed, converted.after);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final history = container.read(projectHistoryProvider.notifier);
        history.reset(_entry(before));
        expect(history.record(_entry(after)), isTrue);

        final undone = history.undo(_entry(after));
        expect(undone, isNotNull);
        expect(_activeMode(undone!.data), direction.$1);
        final redone = history.redo(_entry(before));
        expect(redone, isNotNull);
        expect(_activeMode(redone!.data), direction.$2);
        expect(redone.contentDigest, _entry(after).contentDigest);
      },
    );
  }
}
