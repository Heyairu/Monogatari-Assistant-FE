import "../../models/item_data.dart";
import "../../models/item_snapshot_data.dart";

class ItemAssignmentResult {
  final Map<String, ItemClassData> itemClasses;
  final Map<String, ItemInstanceData> itemInstances;

  const ItemAssignmentResult({
    required this.itemClasses,
    required this.itemInstances,
  });
}

/// Applies an item assignment to the persisted default state.
///
/// Scene-specific movement remains represented by item state changes. This
/// operation is intended for the character/location editors, where users are
/// editing the project's default assignment directly.
ItemAssignmentResult assignItemDefault({
  required Map<String, ItemClassData> itemClasses,
  required Map<String, ItemInstanceData> itemInstances,
  required ItemReferenceKind itemKind,
  required String itemId,
  required ItemRelationTargetKind targetKind,
  required String targetId,
  required String allocationId,
  int? quantity = 1,
}) {
  _checkTarget(targetKind, targetId);
  if (itemKind == ItemReferenceKind.instance) {
    return _assignInstance(
      itemClasses: itemClasses,
      itemInstances: itemInstances,
      instanceId: itemId,
      targetKind: targetKind,
      targetId: targetId,
    );
  }

  final itemClass = itemClasses[itemId];
  if (itemClass == null || itemClass.archived) {
    throw StateError("找不到可分配的物品。");
  }
  if (itemClass.mode == ItemMode.dedicated) {
    final instances = itemInstances.values
        .where((value) => value.classId == itemId && !value.archived)
        .toList(growable: false);
    if (instances.length != 1) {
      throw StateError("專用物品必須先建立唯一的單件 ID 才能分配。");
    }
    return _assignInstance(
      itemClasses: itemClasses,
      itemInstances: itemInstances,
      instanceId: instances.single.instanceId,
      targetKind: targetKind,
      targetId: targetId,
    );
  }
  if (quantity != null && quantity < 0) {
    throw ArgumentError.value(quantity, "quantity", "must be non-negative");
  }

  final allocations = List<ItemAllocationData>.of(
    itemClass.defaultState.allocations,
  );
  final existingIndex = allocations.indexWhere(
    (value) => _matchesTarget(value, targetKind, targetId),
  );
  if (existingIndex < 0) {
    allocations.add(
      ItemAllocationData(
        allocationId: allocationId,
        holderCharacterId: targetKind == ItemRelationTargetKind.character
            ? targetId
            : null,
        locationId: targetKind == ItemRelationTargetKind.location
            ? targetId
            : null,
        quantity: quantity,
      ),
    );
  } else {
    allocations[existingIndex] = allocations[existingIndex].copyWith(
      quantity: quantity,
    );
  }
  return ItemAssignmentResult(
    itemClasses: {
      ...itemClasses,
      itemId: itemClass.copyWith(
        defaultState: itemClass.defaultState.copyWith(
          allocations: allocations,
        ),
      ),
    },
    itemInstances: itemInstances,
  );
}

ItemAssignmentResult clearItemDefaultAssignment({
  required Map<String, ItemClassData> itemClasses,
  required Map<String, ItemInstanceData> itemInstances,
  required ItemReferenceKind itemKind,
  required String itemId,
  required ItemRelationTargetKind targetKind,
  required String targetId,
}) {
  _checkTarget(targetKind, targetId);
  if (itemKind == ItemReferenceKind.instance) {
    final instance = itemInstances[itemId];
    if (instance == null) {
      return ItemAssignmentResult(
        itemClasses: itemClasses,
        itemInstances: itemInstances,
      );
    }
    final patch = targetKind == ItemRelationTargetKind.character
        ? instance.defaultState.copyWith(
            holderCharacterId: const StateValue<String?>.clear(),
          )
        : instance.defaultState.copyWith(
            locationId: const StateValue<String?>.clear(),
          );
    return ItemAssignmentResult(
      itemClasses: itemClasses,
      itemInstances: {
        ...itemInstances,
        itemId: instance.copyWith(defaultState: patch),
      },
    );
  }

  final itemClass = itemClasses[itemId];
  if (itemClass == null) {
    return ItemAssignmentResult(
      itemClasses: itemClasses,
      itemInstances: itemInstances,
    );
  }
  return ItemAssignmentResult(
    itemClasses: {
      ...itemClasses,
      itemId: itemClass.copyWith(
        defaultState: itemClass.defaultState.copyWith(
          allocations: itemClass.defaultState.allocations
              .where(
                (value) => !_matchesTarget(value, targetKind, targetId),
              )
              .toList(growable: false),
        ),
      ),
    },
    itemInstances: itemInstances,
  );
}

ItemAssignmentResult _assignInstance({
  required Map<String, ItemClassData> itemClasses,
  required Map<String, ItemInstanceData> itemInstances,
  required String instanceId,
  required ItemRelationTargetKind targetKind,
  required String targetId,
}) {
  final instance = itemInstances[instanceId];
  if (instance == null || instance.archived) {
    throw StateError("找不到可分配的單件物品。");
  }
  final patch = targetKind == ItemRelationTargetKind.character
      ? instance.defaultState.copyWith(
          holderCharacterId: StateValue<String?>.set(targetId),
        )
      : instance.defaultState.copyWith(
          locationId: StateValue<String?>.set(targetId),
        );
  return ItemAssignmentResult(
    itemClasses: itemClasses,
    itemInstances: {
      ...itemInstances,
      instanceId: instance.copyWith(defaultState: patch),
    },
  );
}

bool _matchesTarget(
  ItemAllocationData allocation,
  ItemRelationTargetKind targetKind,
  String targetId,
) =>
    targetKind == ItemRelationTargetKind.character
    ? allocation.holderCharacterId == targetId
    : allocation.locationId == targetId;

void _checkTarget(ItemRelationTargetKind kind, String id) {
  if (kind != ItemRelationTargetKind.character &&
      kind != ItemRelationTargetKind.location) {
    throw ArgumentError.value(kind, "targetKind", "must be character/location");
  }
  if (id.trim().isEmpty) {
    throw ArgumentError.value(id, "targetId", "is empty");
  }
}
