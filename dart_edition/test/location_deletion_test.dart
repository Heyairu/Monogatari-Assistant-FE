import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/application/locations/location_deletion.dart";
import "package:monogatari_assistant/models/item_data.dart";
import "package:monogatari_assistant/models/item_snapshot_data.dart";
import "package:monogatari_assistant/models/location_snapshot_data.dart";
import "package:monogatari_assistant/models/world_settings_data.dart";

void main() {
  test(
    "permanent location deletion reports and cleans every location reference",
    () {
      final root = LocationData(
        id: "city",
        localName: "城市",
        child: [LocationData(id: "harbor", localName: "港口")],
      );
      final itemClasses = {
        "supplies": ItemClassData(
          classId: "supplies",
          name: "補給",
          mode: ItemMode.generic,
          defaultState: ItemSnapshotState(
            allocations: [
              ItemAllocationData(allocationId: "a1", locationId: "harbor"),
              ItemAllocationData(allocationId: "a2", locationId: "elsewhere"),
            ],
          ),
        ),
      };
      final itemInstances = {
        "key": ItemInstanceData(
          instanceId: "key",
          classId: "keys",
          name: "鑰匙",
          defaultState: ItemStatePatch(
            locationId: const StateValue<String?>.set("city"),
          ),
        ),
      };
      final relations = [
        ItemRelationData(
          relationId: "r1",
          itemId: "key",
          targetId: "harbor",
          targetKind: ItemRelationTargetKind.location,
        ),
      ];
      final classChanges = [
        ItemClassStateChange(
          stateChangeId: "c1",
          classId: "supplies",
          sceneUUID: "scene",
          patch: ItemStatePatch(
            allocations: StateValue.set([
              ItemAllocationData(allocationId: "a3", locationId: "city"),
            ]),
          ),
        ),
      ];
      final instanceChanges = [
        ItemInstanceStateChange(
          stateChangeId: "i1",
          instanceId: "key",
          sceneUUID: "scene",
          patch: ItemStatePatch(
            locationId: const StateValue<String?>.set("harbor"),
          ),
        ),
      ];
      final locationChanges = [
        LocationStateChange(
          stateChangeId: "l1",
          locationId: "city",
          sceneUUID: "scene",
        ),
        LocationStateChange(
          stateChangeId: "l2",
          locationId: "elsewhere",
          sceneUUID: "scene",
        ),
      ];
      final ids = LocationDeletionPlanner.collectSubtreeIds(root);

      final impact = LocationDeletionPlanner.inspect(
        locationIds: ids,
        itemClasses: itemClasses,
        itemInstances: itemInstances,
        itemRelations: relations,
        itemClassStateChanges: classChanges,
        itemInstanceStateChanges: instanceChanges,
        locationStateChanges: locationChanges,
      );
      expect(impact.locationCount, 2);
      expect(impact.snapshotCount, 1);
      expect(impact.relationCount, 1);
      expect(impact.itemPlacementCount, 4);

      final result = LocationDeletionPlanner.cleanup(
        locationIds: ids,
        itemClasses: itemClasses,
        itemInstances: itemInstances,
        itemRelations: relations,
        itemClassStateChanges: classChanges,
        itemInstanceStateChanges: instanceChanges,
        locationStateChanges: locationChanges,
      );
      expect(
        result
            .itemClasses["supplies"]!
            .defaultState
            .allocations
            .single
            .locationId,
        "elsewhere",
      );
      expect(
        result.itemInstances["key"]!.defaultState.locationId!.value,
        isNull,
      );
      expect(result.itemRelations, isEmpty);
      expect(result.locationStateChanges.single.locationId, "elsewhere");
      expect(
        result.itemClassStateChanges.single.patch.allocations!.value,
        isEmpty,
      );
      expect(
        result.itemInstanceStateChanges.single.patch.locationId!.value,
        isNull,
      );
    },
  );
}
