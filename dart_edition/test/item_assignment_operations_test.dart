import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/application/items/item_assignment_operations.dart";
import "package:monogatari_assistant/models/item_data.dart";

void main() {
  test("aggregate class can be assigned and cleared from a character", () {
    final itemClass = ItemClassData(
      classId: "coins",
      name: "金幣",
      mode: ItemMode.generic,
    );

    final assigned = assignItemDefault(
      itemClasses: {itemClass.classId: itemClass},
      itemInstances: const {},
      itemKind: ItemReferenceKind.itemClass,
      itemId: itemClass.classId,
      targetKind: ItemRelationTargetKind.character,
      targetId: "hero",
      allocationId: "allocation",
      quantity: 12,
    );

    expect(
      assigned.itemClasses["coins"]!.defaultState.allocations.single
          .holderCharacterId,
      "hero",
    );
    expect(
      assigned.itemClasses["coins"]!.defaultState.allocations.single.quantity,
      12,
    );

    final cleared = clearItemDefaultAssignment(
      itemClasses: assigned.itemClasses,
      itemInstances: assigned.itemInstances,
      itemKind: ItemReferenceKind.itemClass,
      itemId: "coins",
      targetKind: ItemRelationTargetKind.character,
      targetId: "hero",
    );
    expect(cleared.itemClasses["coins"]!.defaultState.allocations, isEmpty);
  });

  test("dedicated class assignment resolves its single instance", () {
    final itemClass = ItemClassData(
      classId: "sword",
      name: "劍",
      mode: ItemMode.dedicated,
    );
    final instance = ItemInstanceData(
      instanceId: "sword-1",
      classId: itemClass.classId,
      name: "王者之劍",
    );

    final assigned = assignItemDefault(
      itemClasses: {itemClass.classId: itemClass},
      itemInstances: {instance.instanceId: instance},
      itemKind: ItemReferenceKind.itemClass,
      itemId: itemClass.classId,
      targetKind: ItemRelationTargetKind.location,
      targetId: "castle",
      allocationId: "unused",
    );

    expect(
      assigned.itemInstances[instance.instanceId]!.defaultState.locationId
          ?.value,
      "castle",
    );
  });
}
