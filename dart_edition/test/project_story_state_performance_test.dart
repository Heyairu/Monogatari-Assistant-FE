import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/application/snapshots/project_story_state_index.dart";
import "package:monogatari_assistant/models/item_data.dart";
import "package:monogatari_assistant/models/item_snapshot_data.dart";
import "package:monogatari_assistant/models/location_snapshot_data.dart";
import "package:monogatari_assistant/models/timeline_data.dart";

void main() {
  test(
    "large project indexes 20k changes and reuses ordered subject results",
    () {
      const locationCount = 1000;
      const instanceCount = 2000;
      const classChangeCount = 7000;
      const instanceChangeCount = 7000;
      const locationChangeCount = 6000;

      final timeline = TimelineDocumentData(
        tracks: const [TimelineTrackData(trackUUID: "main", name: "主線")],
        placements: [
          for (var index = 0; index < locationCount; index++)
            TimelinePlacementData(
              placementUUID: "placement-$index",
              sceneUUID: "scene-$index",
              trackUUID: "main",
              startTick: index * 10,
            ),
        ],
      );
      final classes = [
        for (var index = 0; index < instanceCount; index++)
          ItemClassData(
            classId: "class-$index",
            name: "物品 $index",
            mode: ItemMode.semiDedicated,
          ),
      ];
      final instances = [
        for (var index = 0; index < instanceCount; index++)
          ItemInstanceData(
            instanceId: "instance-$index",
            classId: "class-$index",
            name: "單件 $index",
          ),
      ];
      final classChanges = [
        for (var index = 0; index < classChangeCount; index++)
          ItemClassStateChange(
            stateChangeId: "class-change-$index",
            classId: "class-${index % instanceCount}",
            sceneUUID: "scene-${index % locationCount}",
            sourcePlacementUUID: "placement-${index % locationCount}",
            sequence: index,
            patch: ItemStatePatch(status: StateValue.set("狀態 $index")),
          ),
      ];
      final instanceChanges = [
        for (var index = 0; index < instanceChangeCount; index++)
          ItemInstanceStateChange(
            stateChangeId: "instance-change-$index",
            instanceId: "instance-${index % instanceCount}",
            sceneUUID: "scene-${index % locationCount}",
            sourcePlacementUUID: "placement-${index % locationCount}",
            sequence: index,
            patch: ItemStatePatch(
              locationId: StateValue.set("location-${index % locationCount}"),
            ),
          ),
      ];
      final locationChanges = [
        for (var index = 0; index < locationChangeCount; index++)
          LocationStateChange(
            stateChangeId: "location-change-$index",
            locationId: "location-${index % locationCount}",
            sceneUUID: "scene-${index % locationCount}",
            sourcePlacementUUID: "placement-${index % locationCount}",
            sequence: index,
            patch: LocationStatePatch(status: StateValue.set("狀態 $index")),
          ),
      ];

      final indexing = Stopwatch()..start();
      final snapshotIndex = ProjectStoryStateIndex(
        itemClassChanges: classChanges,
        itemInstanceChanges: instanceChanges,
        locationChanges: locationChanges,
        timeline: timeline,
      );
      indexing.stop();

      final firstProjection = Stopwatch()..start();
      for (var index = 0; index < instanceCount; index++) {
        snapshotIndex.resolveItemInstance(
          itemClass: classes[index],
          instance: instances[index],
          atTick: 10000,
        );
      }
      for (var index = 0; index < locationCount; index++) {
        snapshotIndex.resolveLocation(
          locationId: "location-$index",
          atTick: 10000,
        );
      }
      firstProjection.stop();

      final playheadQueries = Stopwatch()..start();
      for (var tick = 0; tick < 10000; tick += 100) {
        for (var index = 0; index < 20; index++) {
          snapshotIndex.resolveItemInstance(
            itemClass: classes[index],
            instance: instances[index],
            atTick: tick,
          );
          snapshotIndex.resolveLocation(
            locationId: "location-$index",
            atTick: tick,
          );
        }
      }
      playheadQueries.stop();

      // These generous limits catch accidental whole-list scans while allowing
      // slower debug and CI machines. Product profile thresholds remain manual.
      expect(indexing.elapsed, lessThan(const Duration(seconds: 5)));
      expect(firstProjection.elapsed, lessThan(const Duration(seconds: 5)));
      expect(playheadQueries.elapsed, lessThan(const Duration(seconds: 5)));
      expect(
        snapshotIndex
            .resolveItemInstance(
              itemClass: classes.first,
              instance: instances.first,
              atTick: 10000,
            )
            .locationId,
        "location-0",
      );
      expect(
        snapshotIndex
            .resolveLocation(locationId: "location-0", atTick: 10000)
            .status,
        "狀態 5000",
      );

      // Visible under `flutter test -r expanded` and useful for profile baselines.
      // ignore: avoid_print
      print(
        "story-state performance: index=${indexing.elapsedMilliseconds}ms, "
        "first=${firstProjection.elapsedMilliseconds}ms, "
        "playhead=${playheadQueries.elapsedMilliseconds}ms",
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
