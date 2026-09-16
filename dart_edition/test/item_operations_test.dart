import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/application/items/item_operations.dart";
import "package:monogatari_assistant/models/item_data.dart";
import "package:monogatari_assistant/models/item_snapshot_data.dart";

void main() {
  test("semi-dedicated materialization creates one stable instance", () {
    final itemClass = ItemClassData(
      classId: "keys",
      name: "鑰匙",
      mode: ItemMode.semiDedicated,
    );
    final state = ItemSnapshotState(
      allocations: [
        ItemAllocationData(
          allocationId: "guard-keys",
          holderCharacterId: "guard",
          quantity: 3,
        ),
      ],
    );

    final result = materializeAggregateItem(
      itemClass: itemClass,
      currentState: state,
      request: const AggregateItemMaterializationRequest(
        sourceAllocationId: "guard-keys",
        instanceId: "north-gate-key",
        instanceName: "北門鑰匙",
        sceneUUID: "handoff-scene",
        sourcePlacementUUID: "handoff-placement",
        fallbackTick: 18,
        conversionId: "conversion-1",
      ),
    );

    expect(result.allocations.single.quantity, 2);
    expect(result.instance.instanceId, "north-gate-key");
    expect(result.instance.defaultState.exists?.value, isFalse);
    expect(result.instance.defaultState.holderCharacterId?.value, "guard");
    expect(result.instance.conversionSource?.conversionId, "conversion-1");
    expect(result.classChange.patch.allocations?.value?.single.quantity, 2);
    expect(result.instanceChange.patch.exists?.value, isTrue);
    expect(result.instanceChange.sceneUUID, "handoff-scene");
    expect(result.instanceChange.sourcePlacementUUID, "handoff-placement");
  });

  test("materialization requires an explicit remainder for unknown stock", () {
    final itemClass = ItemClassData(
      classId: "keys",
      mode: ItemMode.semiDedicated,
    );
    final state = ItemSnapshotState(
      allocations: [
        ItemAllocationData(
          allocationId: "unknown-stock",
          locationId: "warehouse",
        ),
      ],
    );
    const request = AggregateItemMaterializationRequest(
      sourceAllocationId: "unknown-stock",
      instanceId: "key-1",
      sceneUUID: "scene",
      conversionId: "conversion",
    );

    expect(
      () => materializeAggregateItem(
        itemClass: itemClass,
        currentState: state,
        request: request,
      ),
      throwsStateError,
    );
    final result = materializeAggregateItem(
      itemClass: itemClass,
      currentState: state,
      request: const AggregateItemMaterializationRequest(
        sourceAllocationId: "unknown-stock",
        sourceQuantityAfter: 4,
        instanceId: "key-1",
        sceneUUID: "scene",
        conversionId: "conversion",
      ),
    );
    expect(result.allocations.single.quantity, 4);
    expect(result.instance.defaultState.locationId?.value, "warehouse");
  });

  test("one aggregate unit converts directly to a dedicated instance", () {
    final itemClass = ItemClassData(
      classId: "relic",
      name: "王冠",
      mode: ItemMode.generic,
    );
    final state = ItemSnapshotState(
      allocations: [
        ItemAllocationData(
          allocationId: "crown-stock",
          locationId: "vault",
          quantity: 1,
        ),
      ],
    );
    final result = materializeAggregateItem(
      itemClass: itemClass,
      currentState: state,
      request: const AggregateItemMaterializationRequest(
        sourceAllocationId: "crown-stock",
        instanceId: "royal-crown",
        instanceName: "王冠",
        sceneUUID: "coronation",
        conversionId: "conversion-dedicated",
        targetMode: ItemMode.dedicated,
      ),
    );

    expect(result.itemClass.mode, ItemMode.dedicated);
    expect(result.itemClass.conversionSource?.sceneUUID, "coronation");
    expect(result.allocations.single.quantity, 0);
    expect(result.instance.defaultState.exists?.value, isFalse);
    expect(result.instanceChange.patch.exists?.value, isTrue);

    expect(
      () => materializeAggregateItem(
        itemClass: itemClass,
        currentState: ItemSnapshotState(
          allocations: [
            ItemAllocationData(
              allocationId: "two-crowns",
              locationId: "vault",
              quantity: 2,
            ),
          ],
        ),
        request: const AggregateItemMaterializationRequest(
          sourceAllocationId: "two-crowns",
          instanceId: "crown",
          sceneUUID: "scene",
          conversionId: "invalid",
          targetMode: ItemMode.dedicated,
        ),
      ),
      throwsStateError,
    );
  });

  test("identified items demote into a new aggregate Class at a Scene", () {
    final itemClass = ItemClassData(
      classId: "keys",
      name: "鑰匙",
      unit: "把",
      mode: ItemMode.semiDedicated,
      defaultState: ItemSnapshotState(status: "原始狀態"),
      conversionSource: ItemConversionSourceData(
        sourceClassId: "old-stock",
        conversionId: "earlier-class-conversion",
      ),
    );
    final instances = [
      ItemInstanceData(
        instanceId: "key-a",
        classId: "keys",
        conversionSource: ItemConversionSourceData(
          sourceClassId: "keys",
          conversionId: "earlier-instance-conversion",
        ),
      ),
      ItemInstanceData(instanceId: "key-b", classId: "keys"),
      ItemInstanceData(instanceId: "key-c", classId: "keys"),
      ItemInstanceData(instanceId: "lost-key", classId: "keys"),
    ];
    final result = demoteIdentifiedItems(
      itemClass: itemClass,
      instances: instances,
      currentClassState: ItemSnapshotState(
        name: "當時的鑰匙",
        status: "已清點",
        properties: const {"材質": "鐵"},
      ),
      currentStates: {
        "key-a": ItemSnapshotState(holderCharacterId: "alice"),
        "key-b": ItemSnapshotState(holderCharacterId: "alice"),
        "key-c": ItemSnapshotState(locationId: "warehouse"),
        "lost-key": ItemSnapshotState(exists: false),
      },
      request: const IdentifiedItemDemotionRequest(
        targetClassId: "aggregate-keys",
        sceneUUID: "inventory-scene",
        sourcePlacementUUID: "inventory-placement",
        fallbackTick: 42,
        conversionId: "demotion-1",
        note: "完成清點",
      ),
    );

    expect(result.sourceClass.archived, isTrue);
    expect(
      result.sourceClass.conversionSource?.conversionId,
      "earlier-class-conversion",
    );
    expect(result.sourceInstances, everyElement(isA<ItemInstanceData>()));
    expect(result.sourceInstances.every((value) => value.archived), isTrue);
    expect(
      result.sourceInstances
          .singleWhere((value) => value.instanceId == "key-a")
          .conversionSource
          ?.conversionId,
      "earlier-instance-conversion",
    );
    expect(result.targetClass.classId, "aggregate-keys");
    expect(result.targetClass.mode, ItemMode.generic);
    expect(result.targetClass.defaultState.exists, isFalse);
    expect(result.targetClass.defaultState.name, "當時的鑰匙");
    expect(result.targetClass.defaultState.status, "已清點");
    expect(result.targetClass.defaultState.properties, {"材質": "鐵"});
    final allocations = result.targetClassChange.patch.allocations!.value!;
    expect(allocations, hasLength(2));
    expect(
      allocations
          .singleWhere((value) => value.holderCharacterId == "alice")
          .quantity,
      2,
    );
    expect(
      allocations
          .singleWhere((value) => value.locationId == "warehouse")
          .quantity,
      1,
    );
    expect(result.sourceClassChange.patch.exists?.value, isFalse);
    expect(result.targetClassChange.patch.exists?.value, isTrue);
    expect(
      result.sourceInstanceChanges.map((value) => value.instanceId).toSet(),
      {"key-a", "key-b", "key-c"},
    );
    expect(result.targetClass.conversionSource?.conversionId, "demotion-1");
  });

  test("aggregate transfer moves a known quantity in one Scene patch", () {
    final itemClass = ItemClassData(classId: "coins", mode: ItemMode.generic);
    final state = ItemSnapshotState(
      allocations: [
        ItemAllocationData(
          allocationId: "warehouse",
          locationId: "warehouse-location",
          quantity: 10,
        ),
      ],
    );

    final result = transferAggregateItem(
      itemClass: itemClass,
      currentState: state,
      request: const AggregateItemTransferRequest(
        sourceAllocationId: "warehouse",
        destinationCharacterId: "alice",
        quantity: 3,
        destinationAllocationId: "alice-coins",
        sceneUUID: "scene-a",
        fallbackTick: 12,
        note: "支付旅費",
      ),
    );

    expect(result.allocations.first.quantity, 7);
    expect(result.allocations.last.holderCharacterId, "alice");
    expect(result.allocations.last.quantity, 3);
    expect(result.change.sceneUUID, "scene-a");
    expect(result.change.patch.allocations!.value, result.allocations);
  });

  test("aggregate transfer rejects insufficient known quantity", () {
    final itemClass = ItemClassData(classId: "coins", mode: ItemMode.generic);
    final state = ItemSnapshotState(
      allocations: [
        ItemAllocationData(
          allocationId: "source",
          locationId: "warehouse",
          quantity: 2,
        ),
      ],
    );

    expect(
      () => transferAggregateItem(
        itemClass: itemClass,
        currentState: state,
        request: const AggregateItemTransferRequest(
          sourceAllocationId: "source",
          destinationCharacterId: "alice",
          quantity: 3,
          destinationAllocationId: "destination",
          sceneUUID: "scene",
        ),
      ),
      throwsStateError,
    );
  });

  test("unknown source and destination require explicit resulting amounts", () {
    final itemClass = ItemClassData(classId: "coins", mode: ItemMode.generic);
    final state = ItemSnapshotState(
      allocations: [
        ItemAllocationData(allocationId: "source", locationId: "warehouse"),
        ItemAllocationData(
          allocationId: "destination",
          holderCharacterId: "alice",
        ),
      ],
    );

    expect(
      () => transferAggregateItem(
        itemClass: itemClass,
        currentState: state,
        request: const AggregateItemTransferRequest(
          sourceAllocationId: "source",
          destinationCharacterId: "alice",
          quantity: 1,
          destinationAllocationId: "unused",
          sceneUUID: "scene",
        ),
      ),
      throwsStateError,
    );

    final result = transferAggregateItem(
      itemClass: itemClass,
      currentState: state,
      request: const AggregateItemTransferRequest(
        sourceAllocationId: "source",
        destinationCharacterId: "alice",
        quantity: 1,
        sourceQuantityAfter: 4,
        destinationQuantityAfter: 6,
        destinationAllocationId: "unused",
        sceneUUID: "scene",
      ),
    );
    expect(result.allocations.first.quantity, 4);
    expect(result.allocations.last.quantity, 6);
  });
}
