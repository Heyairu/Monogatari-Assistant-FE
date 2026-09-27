import "../../models/item_data.dart";
import "../../models/item_snapshot_data.dart";

class DedicatedItemCreationRequest {
  final String classId;
  final String instanceId;
  final String name;

  const DedicatedItemCreationRequest({
    required this.classId,
    required this.instanceId,
    required this.name,
  });
}

class DedicatedItemCreationResult {
  final ItemClassData itemClass;
  final ItemInstanceData instance;

  const DedicatedItemCreationResult({
    required this.itemClass,
    required this.instance,
  });
}

/// Creates the Class and its initial one-to-one instance together.
///
/// Keeping the pair in one operation prevents entry points such as ItemView
/// and Mosaic's quick-create action from producing different initial data.
DedicatedItemCreationResult createDedicatedItem({
  required DedicatedItemCreationRequest request,
}) {
  final classId = request.classId.trim();
  final instanceId = request.instanceId.trim();
  final name = request.name.trim();
  if (classId.isEmpty) {
    throw ArgumentError.value(request.classId, "classId", "is empty");
  }
  if (instanceId.isEmpty) {
    throw ArgumentError.value(request.instanceId, "instanceId", "is empty");
  }
  if (name.isEmpty) {
    throw ArgumentError.value(request.name, "name", "is empty");
  }
  if (classId == instanceId) {
    throw ArgumentError("classId and instanceId must be distinct");
  }

  final itemClass = ItemClassData(
    classId: classId,
    name: name,
    mode: ItemMode.dedicated,
    defaultState: ItemSnapshotState(name: name),
  );
  return DedicatedItemCreationResult(
    itemClass: itemClass,
    instance: ItemInstanceData(
      instanceId: instanceId,
      classId: classId,
      name: name,
    ),
  );
}

class AggregateItemTransferRequest {
  final String sourceAllocationId;
  final String? destinationCharacterId;
  final String? destinationLocationId;
  final int quantity;
  final int? sourceQuantityAfter;
  final int? destinationQuantityAfter;
  final String destinationAllocationId;
  final String sceneUUID;
  final String? sourcePlacementUUID;
  final int fallbackTick;
  final String note;

  const AggregateItemTransferRequest({
    required this.sourceAllocationId,
    this.destinationCharacterId,
    this.destinationLocationId,
    required this.quantity,
    this.sourceQuantityAfter,
    this.destinationQuantityAfter,
    required this.destinationAllocationId,
    required this.sceneUUID,
    this.sourcePlacementUUID,
    this.fallbackTick = 0,
    this.note = "",
  });
}

class AggregateItemTransferResult {
  final List<ItemAllocationData> allocations;
  final ItemClassStateChange change;

  const AggregateItemTransferResult({
    required this.allocations,
    required this.change,
  });
}

class AggregateItemMaterializationRequest {
  final String sourceAllocationId;
  final int? sourceQuantityAfter;
  final String instanceId;
  final String instanceName;
  final String sceneUUID;
  final String? sourcePlacementUUID;
  final int fallbackTick;
  final String conversionId;
  final String note;
  final ItemMode targetMode;

  const AggregateItemMaterializationRequest({
    required this.sourceAllocationId,
    this.sourceQuantityAfter,
    required this.instanceId,
    this.instanceName = "",
    required this.sceneUUID,
    this.sourcePlacementUUID,
    this.fallbackTick = 0,
    required this.conversionId,
    this.note = "",
    this.targetMode = ItemMode.semiDedicated,
  });
}

class AggregateItemMaterializationResult {
  final List<ItemAllocationData> allocations;
  final ItemClassData itemClass;
  final ItemInstanceData instance;
  final ItemClassStateChange classChange;
  final ItemInstanceStateChange instanceChange;

  const AggregateItemMaterializationResult({
    required this.allocations,
    required this.itemClass,
    required this.instance,
    required this.classChange,
    required this.instanceChange,
  });
}

class IdentifiedItemDemotionRequest {
  final String targetClassId;
  final String sceneUUID;
  final String? sourcePlacementUUID;
  final int fallbackTick;
  final String conversionId;
  final String note;

  const IdentifiedItemDemotionRequest({
    required this.targetClassId,
    required this.sceneUUID,
    this.sourcePlacementUUID,
    this.fallbackTick = 0,
    required this.conversionId,
    this.note = "",
  });
}

class IdentifiedItemDemotionResult {
  final ItemClassData sourceClass;
  final List<ItemInstanceData> sourceInstances;
  final ItemClassData targetClass;
  final ItemClassStateChange sourceClassChange;
  final ItemClassStateChange targetClassChange;
  final List<ItemInstanceStateChange> sourceInstanceChanges;

  const IdentifiedItemDemotionResult({
    required this.sourceClass,
    required this.sourceInstances,
    required this.targetClass,
    required this.sourceClassChange,
    required this.targetClassChange,
    required this.sourceInstanceChanges,
  });
}

IdentifiedItemDemotionResult demoteIdentifiedItems({
  required ItemClassData itemClass,
  required Iterable<ItemInstanceData> instances,
  required ItemSnapshotState currentClassState,
  required Map<String, ItemSnapshotState> currentStates,
  required IdentifiedItemDemotionRequest request,
}) {
  if (itemClass.mode == ItemMode.generic) {
    throw StateError("非專用物品不需要反向聚合。");
  }
  final targetClassId = request.targetClassId.trim();
  final conversionId = request.conversionId.trim();
  if (targetClassId.isEmpty) {
    throw ArgumentError.value(targetClassId, "targetClassId", "is empty");
  }
  if (targetClassId == itemClass.classId) {
    throw StateError("反向聚合必須建立新的 Class ID。");
  }
  if (conversionId.isEmpty) {
    throw ArgumentError.value(conversionId, "conversionId", "is empty");
  }
  final sourceInstances = instances
      .where((instance) => instance.classId == itemClass.classId)
      .toList(growable: false);
  final activeInstances = sourceInstances
      .where((instance) => currentStates[instance.instanceId]?.exists == true)
      .toList(growable: false);
  final grouped = <String, ItemAllocationData>{};
  for (final instance in activeInstances) {
    final state = currentStates[instance.instanceId]!;
    final holder = state.holderCharacterId;
    final location = state.locationId;
    final key = "${holder ?? ""}|${location ?? ""}";
    final previous = grouped[key];
    grouped[key] = ItemAllocationData(
      allocationId: previous?.allocationId ?? "$conversionId:$key",
      holderCharacterId: holder,
      locationId: location,
      quantity: (previous?.quantity ?? 0) + 1,
      note: request.note,
    );
  }
  final allocations = List<ItemAllocationData>.unmodifiable(grouped.values);
  final sourceData = ItemConversionSourceData(
    sourceClassId: itemClass.classId,
    sourceInstanceIds: sourceInstances
        .map((instance) => instance.instanceId)
        .toList(growable: false),
    sceneUUID: request.sceneUUID,
    conversionId: conversionId,
    note: request.note,
  );
  final sourceClass = itemClass.copyWith(archived: true);
  final archivedInstances = sourceInstances
      .map((instance) => instance.copyWith(archived: true))
      .toList(growable: false);
  final targetClass = ItemClassData(
    classId: targetClassId,
    name: itemClass.name,
    description: itemClass.description,
    category: itemClass.category,
    unit: itemClass.unit,
    mode: ItemMode.generic,
    defaultState: currentClassState.copyWith(
      exists: false,
      holderCharacterId: null,
      locationId: null,
      ownerCharacterIds: const [],
      allocations: const [],
    ),
    conversionSource: sourceData,
  );
  return IdentifiedItemDemotionResult(
    sourceClass: sourceClass,
    sourceInstances: List.unmodifiable(archivedInstances),
    targetClass: targetClass,
    sourceClassChange: ItemClassStateChange(
      classId: itemClass.classId,
      sceneUUID: request.sceneUUID,
      sourcePlacementUUID: request.sourcePlacementUUID,
      fallbackTick: request.fallbackTick,
      patch: ItemStatePatch(exists: const StateValue.set(false)),
      note: request.note,
    ),
    targetClassChange: ItemClassStateChange(
      classId: targetClassId,
      sceneUUID: request.sceneUUID,
      sourcePlacementUUID: request.sourcePlacementUUID,
      fallbackTick: request.fallbackTick,
      patch: ItemStatePatch(
        exists: const StateValue.set(true),
        allocations: StateValue.set(allocations),
      ),
      note: request.note,
    ),
    sourceInstanceChanges: activeInstances
        .map(
          (instance) => ItemInstanceStateChange(
            instanceId: instance.instanceId,
            sceneUUID: request.sceneUUID,
            sourcePlacementUUID: request.sourcePlacementUUID,
            fallbackTick: request.fallbackTick,
            patch: ItemStatePatch(exists: const StateValue.set(false)),
            note: request.note,
          ),
        )
        .toList(growable: false),
  );
}

AggregateItemMaterializationResult materializeAggregateItem({
  required ItemClassData itemClass,
  required ItemSnapshotState currentState,
  required AggregateItemMaterializationRequest request,
}) {
  if (request.targetMode == ItemMode.generic ||
      (itemClass.mode != ItemMode.generic &&
          itemClass.mode != ItemMode.semiDedicated)) {
    throw StateError("只有非專用或半專用物品可從聚合分配拆出單件。");
  }
  if (request.instanceId.trim().isEmpty) {
    throw ArgumentError.value(request.instanceId, "instanceId", "is empty");
  }
  if (request.conversionId.trim().isEmpty) {
    throw ArgumentError.value(request.conversionId, "conversionId", "is empty");
  }
  final sourceIndex = currentState.allocations.indexWhere(
    (allocation) => allocation.allocationId == request.sourceAllocationId,
  );
  if (sourceIndex < 0) {
    throw ArgumentError.value(
      request.sourceAllocationId,
      "sourceAllocationId",
      "unknown allocation",
    );
  }
  final source = currentState.allocations[sourceIndex];
  final int sourceAfter;
  if (source.quantity == null) {
    final explicit = request.sourceQuantityAfter;
    if (explicit == null || explicit < 0) {
      throw StateError("來源數量未知，必須明確設定拆出後來源數量。");
    }
    sourceAfter = explicit;
  } else {
    if (source.quantity! < 1) throw StateError("來源已知數量不足。");
    sourceAfter = source.quantity! - 1;
  }
  final allocations = List<ItemAllocationData>.of(currentState.allocations);
  allocations[sourceIndex] = source.copyWith(quantity: sourceAfter);
  if (request.targetMode == ItemMode.dedicated &&
      allocations.any(
        (allocation) => allocation.quantity == null || allocation.quantity! > 0,
      )) {
    throw StateError("轉為專用時，拆出後不可留下其他聚合數量。");
  }
  final immutableAllocations = List<ItemAllocationData>.unmodifiable(
    allocations,
  );
  final instanceId = request.instanceId.trim();
  final instanceName = request.instanceName.trim().isEmpty
      ? itemClass.name
      : request.instanceName.trim();
  final sourceData = ItemConversionSourceData(
    sourceClassId: itemClass.classId,
    sceneUUID: request.sceneUUID,
    conversionId: request.conversionId.trim(),
    note: request.note,
  );
  final instance = ItemInstanceData(
    instanceId: instanceId,
    classId: itemClass.classId,
    name: instanceName,
    defaultState: ItemStatePatch(
      exists: const StateValue.set(false),
      name: StateValue.set(instanceName),
      holderCharacterId: StateValue<String?>.set(source.holderCharacterId),
      locationId: StateValue<String?>.set(source.locationId),
    ),
    conversionSource: sourceData,
  );
  return AggregateItemMaterializationResult(
    allocations: immutableAllocations,
    itemClass: itemClass.copyWith(
      mode: request.targetMode,
      conversionSource: itemClass.mode == request.targetMode
          ? itemClass.conversionSource
          : sourceData,
    ),
    instance: instance,
    classChange: ItemClassStateChange(
      classId: itemClass.classId,
      sceneUUID: request.sceneUUID,
      sourcePlacementUUID: request.sourcePlacementUUID,
      fallbackTick: request.fallbackTick,
      patch: ItemStatePatch(allocations: StateValue.set(immutableAllocations)),
      note: request.note,
    ),
    instanceChange: ItemInstanceStateChange(
      instanceId: instanceId,
      sceneUUID: request.sceneUUID,
      sourcePlacementUUID: request.sourcePlacementUUID,
      fallbackTick: request.fallbackTick,
      patch: ItemStatePatch(
        exists: const StateValue.set(true),
        holderCharacterId: StateValue<String?>.set(source.holderCharacterId),
        locationId: StateValue<String?>.set(source.locationId),
      ),
      note: request.note,
    ),
  );
}

AggregateItemTransferResult transferAggregateItem({
  required ItemClassData itemClass,
  required ItemSnapshotState currentState,
  required AggregateItemTransferRequest request,
}) {
  if (itemClass.mode == ItemMode.dedicated) {
    throw StateError("只有非專用或半專用物品可執行聚合數量轉移。");
  }
  if (request.quantity <= 0) {
    throw ArgumentError.value(request.quantity, "quantity", "must be positive");
  }
  final hasCharacter =
      request.destinationCharacterId?.trim().isNotEmpty == true;
  final hasLocation = request.destinationLocationId?.trim().isNotEmpty == true;
  if (hasCharacter == hasLocation) {
    throw ArgumentError(
      "destinationCharacterId 與 destinationLocationId 必須且只能設定一個。",
    );
  }
  final sourceIndex = currentState.allocations.indexWhere(
    (value) => value.allocationId == request.sourceAllocationId,
  );
  if (sourceIndex < 0) {
    throw ArgumentError.value(
      request.sourceAllocationId,
      "sourceAllocationId",
      "unknown allocation",
    );
  }
  final source = currentState.allocations[sourceIndex];
  if ((hasCharacter &&
          source.holderCharacterId == request.destinationCharacterId) ||
      (hasLocation && source.locationId == request.destinationLocationId)) {
    throw StateError("來源與目的分配不可相同。");
  }

  final int sourceAfter;
  if (source.quantity == null) {
    final explicit = request.sourceQuantityAfter;
    if (explicit == null || explicit < 0) {
      throw StateError("來源數量未知，必須明確設定轉移後來源數量。");
    }
    sourceAfter = explicit;
  } else {
    if (source.quantity! < request.quantity) {
      throw StateError("來源已知數量不足。");
    }
    sourceAfter = source.quantity! - request.quantity;
  }

  final destinationIndex = currentState.allocations.indexWhere(
    (value) =>
        value.allocationId != source.allocationId &&
        (hasCharacter
            ? value.holderCharacterId == request.destinationCharacterId
            : value.locationId == request.destinationLocationId),
  );
  final next = List<ItemAllocationData>.of(currentState.allocations);
  next[sourceIndex] = source.copyWith(quantity: sourceAfter);
  if (destinationIndex < 0) {
    next.add(
      ItemAllocationData(
        allocationId: request.destinationAllocationId,
        holderCharacterId: hasCharacter
            ? request.destinationCharacterId!.trim()
            : null,
        locationId: hasLocation ? request.destinationLocationId!.trim() : null,
        quantity: request.quantity,
        note: request.note,
      ),
    );
  } else {
    final destination = next[destinationIndex];
    final int destinationAfter;
    if (destination.quantity == null) {
      final explicit = request.destinationQuantityAfter;
      if (explicit == null || explicit < request.quantity) {
        throw StateError("目的數量未知，必須明確設定轉移後目的數量。");
      }
      destinationAfter = explicit;
    } else {
      destinationAfter = destination.quantity! + request.quantity;
    }
    next[destinationIndex] = destination.copyWith(
      quantity: destinationAfter,
      note: request.note.isEmpty ? destination.note : request.note,
    );
  }

  final allocations = List<ItemAllocationData>.unmodifiable(next);
  return AggregateItemTransferResult(
    allocations: allocations,
    change: ItemClassStateChange(
      classId: itemClass.classId,
      sceneUUID: request.sceneUUID,
      sourcePlacementUUID: request.sourcePlacementUUID,
      fallbackTick: request.fallbackTick,
      patch: ItemStatePatch(allocations: StateValue.set(allocations)),
      note: request.note,
    ),
  );
}
