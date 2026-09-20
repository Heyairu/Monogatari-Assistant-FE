import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/application/items/item_operations.dart";
import "package:monogatari_assistant/models/item_data.dart";
import "package:monogatari_assistant/models/item_snapshot_data.dart";
import "package:monogatari_assistant/models/location_snapshot_data.dart";
import "package:monogatari_assistant/models/timeline_data.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";

void main() {
  test("workspace validates modes, references and duplicate relations", () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(itemWorkspaceProvider.notifier);
    const classId = "class";
    const instanceId = "instance";

    notifier.putClass(
      ItemClassData(classId: classId, name: "制服", mode: ItemMode.semiDedicated),
    );
    notifier.putInstance(
      ItemInstanceData(instanceId: instanceId, classId: classId),
    );
    notifier.putRelation(
      ItemRelationData(
        relationId: "one",
        itemId: instanceId,
        targetId: "character",
        targetKind: ItemRelationTargetKind.character,
        role: "owner",
      ),
    );
    expect(
      () => notifier.putRelation(
        ItemRelationData(
          relationId: "two",
          itemId: instanceId,
          targetId: "character",
          targetKind: ItemRelationTargetKind.character,
          role: "owner",
        ),
      ),
      throwsStateError,
    );

    notifier.putClass(
      ItemClassData(classId: "generic", mode: ItemMode.generic),
    );
    expect(
      () => notifier.putInstance(
        ItemInstanceData(instanceId: "coin", classId: "generic"),
      ),
      throwsStateError,
    );
    expect(container.read(itemWorkspaceProvider).itemRelations, hasLength(1));
  });

  test("snapshot providers project class and instance state by Tick", () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(itemWorkspaceProvider.notifier);
    notifier.putClass(
      ItemClassData(
        classId: "class",
        mode: ItemMode.semiDedicated,
        defaultState: ItemSnapshotState(status: "完好"),
      ),
    );
    notifier.putInstance(
      ItemInstanceData(instanceId: "instance", classId: "class"),
    );
    notifier.putInstanceStateChange(
      ItemInstanceStateChange(
        stateChangeId: "change",
        instanceId: "instance",
        sceneUUID: "scene",
        fallbackTick: 5,
        patch: ItemStatePatch(status: const StateValue.set("損壞")),
      ),
    );
    container
        .read(timelineDocumentProvider.notifier)
        .setDocument(const TimelineDocumentData());

    expect(
      container
          .read(itemInstanceSnapshotProvider((id: "instance", tick: 4)))
          ?.status,
      "完好",
    );
    expect(
      container
          .read(itemInstanceSnapshotProvider((id: "instance", tick: 5)))
          ?.status,
      "損壞",
    );
  });

  test("workspace removes class, instance and location snapshots by ID", () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(itemWorkspaceProvider.notifier);
    notifier.putClass(
      ItemClassData(classId: "class", mode: ItemMode.semiDedicated),
    );
    notifier.putInstance(
      ItemInstanceData(instanceId: "instance", classId: "class"),
    );
    notifier.putClassStateChange(
      ItemClassStateChange(
        stateChangeId: "class-change",
        classId: "class",
        sceneUUID: "scene",
      ),
    );
    notifier.putInstanceStateChange(
      ItemInstanceStateChange(
        stateChangeId: "instance-change",
        instanceId: "instance",
        sceneUUID: "scene",
      ),
    );
    notifier.putLocationStateChange(
      LocationStateChange(
        stateChangeId: "location-change",
        locationId: "location",
        sceneUUID: "scene",
      ),
    );

    notifier.removeClassStateChange("class-change");
    notifier.removeInstanceStateChange("instance-change");
    notifier.removeLocationStateChange("location-change");

    final workspace = container.read(itemWorkspaceProvider);
    expect(workspace.itemClassStateChanges, isEmpty);
    expect(workspace.itemInstanceStateChanges, isEmpty);
    expect(workspace.locationStateChanges, isEmpty);
  });

  test("workspace removes a location snapshot transaction atomically", () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(itemWorkspaceProvider.notifier);
    notifier.putLocationStateChanges([
      LocationStateChange(
        stateChangeId: "parent-change",
        locationId: "parent",
        sceneUUID: "scene",
        transactionId: "batch",
      ),
      LocationStateChange(
        stateChangeId: "child-change",
        locationId: "child",
        sceneUUID: "scene",
        transactionId: "batch",
      ),
      LocationStateChange(
        stateChangeId: "independent-change",
        locationId: "other",
        sceneUUID: "scene",
      ),
    ]);

    notifier.removeLocationStateChange("child-change");

    expect(
      container
          .read(itemWorkspaceProvider)
          .locationStateChanges
          .map((change) => change.stateChangeId),
      ["independent-change"],
    );
  });

  test("workspace commits a materialized instance and both changes once", () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(itemWorkspaceProvider.notifier);
    notifier.putClass(
      ItemClassData(classId: "class", name: "鑰匙", mode: ItemMode.semiDedicated),
    );
    final instance = ItemInstanceData(
      instanceId: "instance",
      classId: "class",
      name: "北門鑰匙",
    );
    final classChange = ItemClassStateChange(
      stateChangeId: "class-change",
      classId: "class",
      sceneUUID: "scene",
    );
    final instanceChange = ItemInstanceStateChange(
      stateChangeId: "instance-change",
      instanceId: "instance",
      sceneUUID: "scene",
    );

    notifier.materializeAggregateInstance(
      itemClass: container.read(itemWorkspaceProvider).itemClasses["class"]!,
      instance: instance,
      classChange: classChange,
      instanceChange: instanceChange,
    );

    final workspace = container.read(itemWorkspaceProvider);
    expect(workspace.itemInstances["instance"], instance);
    expect(workspace.itemClassStateChanges, [classChange]);
    expect(workspace.itemInstanceStateChanges, [instanceChange]);
  });

  test(
    "identified-to-generic conversion requires an atomic Scene demotion",
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(itemWorkspaceProvider.notifier);
      notifier.putClass(
        ItemClassData(classId: "class", name: "硬幣", mode: ItemMode.dedicated),
      );
      notifier.putInstance(
        ItemInstanceData(instanceId: "old-instance", classId: "class"),
      );
      notifier.putRelation(
        ItemRelationData(
          relationId: "relation",
          itemId: "old-instance",
          targetId: "vault",
          targetKind: ItemRelationTargetKind.location,
        ),
      );

      expect(
        () =>
            notifier.changeClassMode(classId: "class", mode: ItemMode.generic),
        throwsStateError,
      );
      expect(
        container
            .read(itemWorkspaceProvider)
            .itemInstances["old-instance"]!
            .archived,
        isFalse,
      );

      final result = demoteIdentifiedItems(
        itemClass: container.read(itemWorkspaceProvider).itemClasses["class"]!,
        instances: container.read(itemWorkspaceProvider).itemInstances.values,
        currentClassState: ItemSnapshotState(name: "硬幣"),
        currentStates: {"old-instance": ItemSnapshotState()},
        request: const IdentifiedItemDemotionRequest(
          targetClassId: "aggregate-class",
          sceneUUID: "scene",
          sourcePlacementUUID: "placement",
          fallbackTick: 8,
          conversionId: "conversion",
        ),
      );
      expect(
        () => notifier.demoteIdentifiedClass(
          sourceClass: result.sourceClass,
          sourceInstances: const [],
          targetClass: result.targetClass,
          sourceClassChange: result.sourceClassChange,
          targetClassChange: result.targetClassChange,
          sourceInstanceChanges: const [],
        ),
        throwsArgumentError,
      );
      notifier.demoteIdentifiedClass(
        sourceClass: result.sourceClass,
        sourceInstances: result.sourceInstances,
        targetClass: result.targetClass,
        sourceClassChange: result.sourceClassChange,
        targetClassChange: result.targetClassChange,
        sourceInstanceChanges: result.sourceInstanceChanges,
      );

      final workspace = container.read(itemWorkspaceProvider);
      expect(workspace.itemClasses["class"]!.archived, isTrue);
      expect(workspace.itemClasses["aggregate-class"]!.mode, ItemMode.generic);
      expect(workspace.itemInstances["old-instance"]!.archived, isTrue);
      expect(
        workspace.itemRelations.single.itemKind,
        ItemReferenceKind.instance,
      );
      expect(workspace.itemRelations.single.itemId, "old-instance");
      expect(workspace.itemClassStateChanges, hasLength(2));
      expect(workspace.itemInstanceStateChanges, hasLength(1));
    },
  );

  test("pristine identified item can become generic without a Scene", () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(itemWorkspaceProvider.notifier);
    notifier.putClass(
      ItemClassData(
        classId: "class",
        name: "新物品",
        mode: ItemMode.dedicated,
        defaultState: ItemSnapshotState(name: "新物品"),
      ),
    );
    notifier.putInstance(
      ItemInstanceData(
        instanceId: "temporary-instance",
        classId: "class",
        name: "新物品",
      ),
    );

    expect(notifier.canChangeToGenericDirectly("class"), isTrue);
    notifier.changeClassMode(classId: "class", mode: ItemMode.generic);

    final workspace = container.read(itemWorkspaceProvider);
    expect(workspace.itemClasses["class"]!.mode, ItemMode.generic);
    expect(workspace.itemClasses["class"]!.name, "新物品");
    expect(workspace.itemInstances, isEmpty);
  });

  test("semi-dedicated conversion cannot merge multiple stable IDs", () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(itemWorkspaceProvider.notifier);
    notifier.putClass(
      ItemClassData(classId: "class", mode: ItemMode.semiDedicated),
    );
    notifier.putInstance(
      ItemInstanceData(instanceId: "first", classId: "class"),
    );
    notifier.putInstance(
      ItemInstanceData(instanceId: "second", classId: "class"),
    );
    notifier.putRelation(
      ItemRelationData(
        relationId: "relation",
        itemId: "first",
        targetId: "owner",
        targetKind: ItemRelationTargetKind.character,
      ),
    );

    expect(
      () =>
          notifier.changeClassMode(classId: "class", mode: ItemMode.dedicated),
      throwsStateError,
    );

    final workspace = container.read(itemWorkspaceProvider);
    expect(workspace.itemClasses["class"]!.mode, ItemMode.semiDedicated);
    expect(workspace.itemInstances["first"]!.archived, isFalse);
    expect(workspace.itemInstances["second"]!.archived, isFalse);
    expect(workspace.itemRelations.single.itemId, "first");
  });
}
