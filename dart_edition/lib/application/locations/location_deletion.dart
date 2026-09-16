import "../../models/item_data.dart";
import "../../models/item_snapshot_data.dart";
import "../../models/location_snapshot_data.dart";
import "../../models/world_settings_data.dart";

class LocationDeletionImpact {
  final Set<String> locationIds;
  final int snapshotCount;
  final int relationCount;
  final int itemPlacementCount;

  const LocationDeletionImpact({
    required this.locationIds,
    required this.snapshotCount,
    required this.relationCount,
    required this.itemPlacementCount,
  });

  int get locationCount => locationIds.length;
}

class LocationDeletionCleanup {
  final Map<String, ItemClassData> itemClasses;
  final Map<String, ItemInstanceData> itemInstances;
  final List<ItemRelationData> itemRelations;
  final List<ItemClassStateChange> itemClassStateChanges;
  final List<ItemInstanceStateChange> itemInstanceStateChanges;
  final List<LocationStateChange> locationStateChanges;

  const LocationDeletionCleanup({
    required this.itemClasses,
    required this.itemInstances,
    required this.itemRelations,
    required this.itemClassStateChanges,
    required this.itemInstanceStateChanges,
    required this.locationStateChanges,
  });
}

class LocationDeletionPlanner {
  static Set<String> collectSubtreeIds(LocationData root) {
    final ids = <String>{};
    void visit(LocationData node) {
      ids.add(node.id);
      for (final child in node.child) {
        visit(child);
      }
    }

    visit(root);
    return Set.unmodifiable(ids);
  }

  static LocationDeletionImpact inspect({
    required Set<String> locationIds,
    required Map<String, ItemClassData> itemClasses,
    required Map<String, ItemInstanceData> itemInstances,
    required List<ItemRelationData> itemRelations,
    required List<ItemClassStateChange> itemClassStateChanges,
    required List<ItemInstanceStateChange> itemInstanceStateChanges,
    required List<LocationStateChange> locationStateChanges,
  }) {
    var itemPlacementCount = 0;
    for (final itemClass in itemClasses.values) {
      itemPlacementCount += itemClass.defaultState.allocations
          .where((value) => locationIds.contains(value.locationId))
          .length;
    }
    for (final instance in itemInstances.values) {
      if (_setsDeletedLocation(instance.defaultState.locationId, locationIds)) {
        itemPlacementCount++;
      }
    }
    for (final change in itemClassStateChanges) {
      itemPlacementCount += _deletedAllocationCount(
        change.patch.allocations,
        locationIds,
      );
    }
    for (final change in itemInstanceStateChanges) {
      if (_setsDeletedLocation(change.patch.locationId, locationIds)) {
        itemPlacementCount++;
      }
    }

    return LocationDeletionImpact(
      locationIds: Set.unmodifiable(locationIds),
      snapshotCount: locationStateChanges
          .where((value) => locationIds.contains(value.locationId))
          .length,
      relationCount: itemRelations
          .where(
            (value) =>
                value.targetKind == ItemRelationTargetKind.location &&
                locationIds.contains(value.targetId),
          )
          .length,
      itemPlacementCount: itemPlacementCount,
    );
  }

  static LocationDeletionCleanup cleanup({
    required Set<String> locationIds,
    required Map<String, ItemClassData> itemClasses,
    required Map<String, ItemInstanceData> itemInstances,
    required List<ItemRelationData> itemRelations,
    required List<ItemClassStateChange> itemClassStateChanges,
    required List<ItemInstanceStateChange> itemInstanceStateChanges,
    required List<LocationStateChange> locationStateChanges,
  }) {
    return LocationDeletionCleanup(
      itemClasses: {
        for (final entry in itemClasses.entries)
          entry.key: entry.value.copyWith(
            defaultState: entry.value.defaultState.copyWith(
              allocations: _withoutDeletedAllocations(
                entry.value.defaultState.allocations,
                locationIds,
              ),
            ),
          ),
      },
      itemInstances: {
        for (final entry in itemInstances.entries)
          entry.key: entry.value.copyWith(
            defaultState: _cleanPatch(entry.value.defaultState, locationIds),
          ),
      },
      itemRelations: itemRelations
          .where(
            (value) =>
                value.targetKind != ItemRelationTargetKind.location ||
                !locationIds.contains(value.targetId),
          )
          .toList(growable: false),
      itemClassStateChanges: itemClassStateChanges
          .map(
            (change) =>
                change.copyWith(patch: _cleanPatch(change.patch, locationIds)),
          )
          .toList(growable: false),
      itemInstanceStateChanges: itemInstanceStateChanges
          .map(
            (change) =>
                change.copyWith(patch: _cleanPatch(change.patch, locationIds)),
          )
          .toList(growable: false),
      locationStateChanges: locationStateChanges
          .where((value) => !locationIds.contains(value.locationId))
          .toList(growable: false),
    );
  }

  static int _deletedAllocationCount(
    StateValue<List<ItemAllocationData>>? value,
    Set<String> locationIds,
  ) {
    if (value?.operation != StateValueOperation.set) return 0;
    return value!.value!
        .where((allocation) => locationIds.contains(allocation.locationId))
        .length;
  }

  static bool _setsDeletedLocation(
    StateValue<String?>? value,
    Set<String> locationIds,
  ) =>
      value?.operation == StateValueOperation.set &&
      locationIds.contains(value?.value);

  static List<ItemAllocationData> _withoutDeletedAllocations(
    List<ItemAllocationData> values,
    Set<String> locationIds,
  ) => values
      .where((value) => !locationIds.contains(value.locationId))
      .toList(growable: false);

  static ItemStatePatch _cleanPatch(
    ItemStatePatch patch,
    Set<String> locationIds,
  ) {
    final allocations = patch.allocations;
    final locationId = patch.locationId;
    return patch.copyWith(
      allocations: allocations?.operation == StateValueOperation.set
          ? StateValue.set(
              _withoutDeletedAllocations(allocations!.value!, locationIds),
            )
          : allocations,
      locationId: _setsDeletedLocation(locationId, locationIds)
          ? const StateValue<String?>.set(null)
          : locationId,
    );
  }
}
