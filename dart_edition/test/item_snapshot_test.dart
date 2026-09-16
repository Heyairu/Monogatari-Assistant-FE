import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/file.dart";
import "package:monogatari_assistant/application/collaboration/project_record_codec.dart";
import "package:monogatari_assistant/models/item_data.dart";
import "package:monogatari_assistant/models/item_snapshot_data.dart";
import "package:monogatari_assistant/models/location_snapshot_data.dart";
import "package:monogatari_assistant/models/timeline_data.dart";
import "package:monogatari_assistant/presentation/providers/project_snapshot_utils.dart";

void main() {
  const classId = "11111111-1111-4111-8111-111111111111";
  const instanceId = "22222222-2222-4222-8222-222222222222";
  const sceneId = "33333333-3333-4333-8333-333333333333";
  const locationId = "44444444-4444-4444-8444-444444444444";
  const characterId = "55555555-5555-4555-8555-555555555555";

  final timeline = TimelineDocumentData(
    placements: const [
      TimelinePlacementData(
        placementUUID: "placement",
        sceneUUID: sceneId,
        trackUUID: "track",
        startTick: 10,
      ),
    ],
  );

  test(
    "instance inherits Class state and applies its own historical patch",
    () {
      final itemClass = ItemClassData(
        classId: classId,
        name: "制服",
        mode: ItemMode.semiDedicated,
        defaultState: ItemSnapshotState(
          name: "制服",
          status: "完好",
          properties: const {"材質": "棉"},
        ),
      );
      final instance = ItemInstanceData(
        instanceId: instanceId,
        classId: classId,
        name: "小夏的制服",
        defaultState: ItemStatePatch(
          name: const StateValue.set("小夏的制服"),
          exists: const StateValue.set(false),
        ),
      );
      final change = ItemInstanceStateChange(
        stateChangeId: "change",
        instanceId: instanceId,
        sceneUUID: sceneId,
        patch: ItemStatePatch(
          exists: const StateValue.set(true),
          holderCharacterId: const StateValue.set(characterId),
          locationId: const StateValue.set(locationId),
        ),
      );

      final before = resolveItemInstanceSnapshot(
        itemClass: itemClass,
        instance: instance,
        instanceChanges: [change],
        timeline: timeline,
        atTick: 9,
      );
      final after = resolveItemInstanceSnapshot(
        itemClass: itemClass,
        instance: instance,
        instanceChanges: [change],
        timeline: timeline,
        atTick: 10,
      );

      expect(before.exists, isFalse);
      expect(before.name, "小夏的制服");
      expect(before.properties, {"材質": "棉"});
      expect(after.exists, isTrue);
      expect(after.holderCharacterId, characterId);
      expect(after.locationId, locationId);
      expect(after.properties, {"材質": "棉"});
    },
  );

  test("location nodes resolve independently at the current Tick", () {
    final change = LocationStateChange(
      stateChangeId: "location-change",
      locationId: locationId,
      sceneUUID: sceneId,
      patch: LocationStatePatch(
        status: const StateValue.set("封鎖"),
        accessible: const StateValue.set(false),
      ),
    );
    final before = resolveLocationSnapshot(
      locationId: locationId,
      defaultState: LocationSnapshotState(name: "中央車站"),
      changes: [change],
      timeline: timeline,
      atTick: 9,
    );
    final after = resolveLocationSnapshot(
      locationId: locationId,
      defaultState: LocationSnapshotState(name: "中央車站"),
      changes: [change],
      timeline: timeline,
      atTick: 10,
    );
    expect(before.status, isEmpty);
    expect(before.accessible, isTrue);
    expect(after.status, "封鎖");
    expect(after.accessible, isFalse);
  });

  test("project XML preserves item modes, relations and state changes", () {
    final itemClass = ItemClassData(
      classId: classId,
      name: "制服",
      category: "服裝",
      mode: ItemMode.semiDedicated,
    );
    final instance = ItemInstanceData(
      instanceId: instanceId,
      classId: classId,
      name: "小夏的制服",
    );
    final project = ProjectData.empty();
    project.itemClasses = {classId: itemClass};
    project.itemInstances = {instanceId: instance};
    project.itemRelations = [
      ItemRelationData(
        relationId: "relation",
        itemId: instanceId,
        targetId: characterId,
        targetKind: ItemRelationTargetKind.character,
        role: "owner",
      ),
    ];
    project.itemInstanceStateChanges = [
      ItemInstanceStateChange(
        stateChangeId: "change",
        instanceId: instanceId,
        sceneUUID: sceneId,
        fallbackTick: 10,
        patch: ItemStatePatch(
          holderCharacterId: const StateValue.set(characterId),
        ),
      ),
    ];
    project.locationStateChanges = [
      LocationStateChange(
        stateChangeId: "location-change",
        locationId: locationId,
        sceneUUID: sceneId,
        fallbackTick: 10,
        transactionId: "location-batch",
        patch: LocationStatePatch(
          status: const StateValue.set("封鎖"),
          properties: const StateValue.set({"治安": "危險", "天候": "暴雨"}),
        ),
      ),
    ];

    final xml = FileService.generateProjectXMLWithoutLatestSaveUpdate(project);
    final result = FileService.parseProjectXMLWithMetadata(xml);

    expect(result.projectVersion, "1.18");
    expect(result.data.itemClasses[classId], itemClass);
    expect(result.data.itemInstances[instanceId], instance);
    expect(result.data.itemRelations, project.itemRelations);
    expect(
      result.data.itemInstanceStateChanges,
      project.itemInstanceStateChanges,
    );
    expect(result.data.locationStateChanges, project.locationStateChanges);
  });

  test("generic allocation rejects a negative known quantity", () {
    expect(
      () => ItemAllocationData(allocationId: "allocation", quantity: -1),
      throwsArgumentError,
    );
    expect(ItemAllocationData(allocationId: "unknown").quantity, isNull);
  });

  test("snapshot and collaboration records retain every new collection", () {
    final project = ProjectData.empty();
    final itemClass = ItemClassData(classId: classId, name: "懷錶");
    final instance = ItemInstanceData(instanceId: instanceId, classId: classId);
    project.itemClasses = {classId: itemClass};
    project.itemInstances = {instanceId: instance};
    project.itemRelations = [
      ItemRelationData(
        relationId: "relation",
        itemId: instanceId,
        targetId: locationId,
        targetKind: ItemRelationTargetKind.location,
      ),
    ];
    project.itemClassStateChanges = [
      ItemClassStateChange(
        stateChangeId: "class-change",
        classId: classId,
        sceneUUID: sceneId,
      ),
    ];
    project.itemInstanceStateChanges = [
      ItemInstanceStateChange(
        stateChangeId: "instance-change",
        instanceId: instanceId,
        sceneUUID: sceneId,
      ),
    ];
    project.locationStateChanges = [
      LocationStateChange(
        stateChangeId: "location-change",
        locationId: locationId,
        sceneUUID: sceneId,
      ),
    ];

    final snapshot = snapshotProjectData(project);
    expect(snapshot.itemClasses, project.itemClasses);
    expect(() => snapshot.itemClasses.clear(), throwsUnsupportedError);

    final records = ProjectRecordCodec.snapshot(project);
    expect(ProjectRecordCodec.decodeItemClasses(records), project.itemClasses);
    expect(
      ProjectRecordCodec.decodeItemInstances(records),
      project.itemInstances,
    );
    expect(
      ProjectRecordCodec.decodeItemRelations(records),
      project.itemRelations,
    );
    expect(
      ProjectRecordCodec.decodeItemClassChanges(records),
      project.itemClassStateChanges,
    );
    expect(
      ProjectRecordCodec.decodeItemInstanceChanges(records),
      project.itemInstanceStateChanges,
    );
    expect(
      ProjectRecordCodec.decodeLocationChanges(records),
      project.locationStateChanges,
    );
  });
}
