import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/ui_library.dart";
import "package:monogatari_assistant/models/character_snapshot_data.dart";
import "package:monogatari_assistant/models/item_data.dart";
import "package:monogatari_assistant/models/item_snapshot_data.dart";
import "package:monogatari_assistant/models/location_snapshot_data.dart";
import "package:monogatari_assistant/models/outline_data.dart";
import "package:monogatari_assistant/models/timeline_data.dart";
import "package:monogatari_assistant/modules/characterview.dart";
import "package:monogatari_assistant/modules/itemview.dart";
import "package:monogatari_assistant/modules/worldsettingsview.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";
import "package:monogatari_assistant/presentation/providers/scene_selection_providers.dart";
import "package:monogatari_assistant/presentation/providers/snapshot_timeline_providers.dart";
import "package:monogatari_assistant/presentation/providers/timeline_providers.dart";
import "package:monogatari_assistant/presentation/widgets/snapshot_panel_card.dart";
import "package:monogatari_assistant/presentation/widgets/snapshot_timeline_preview.dart";
import "package:monogatari_assistant/presentation/widgets/timeline_mini_view.dart";

const timeline = TimelineDocumentData(
  tracks: [
    TimelineTrackData(trackUUID: "lower", name: "下軌", order: 9),
    TimelineTrackData(trackUUID: "upper", name: "上軌", order: 2),
  ],
  placements: [
    TimelinePlacementData(
      placementUUID: "a-lower",
      sceneUUID: "lower-scene",
      trackUUID: "lower",
      startTick: 20,
    ),
    TimelinePlacementData(
      placementUUID: "repeat",
      sceneUUID: "upper-scene",
      trackUUID: "upper",
      startTick: 80,
    ),
    TimelinePlacementData(
      placementUUID: "z-upper",
      sceneUUID: "upper-scene",
      trackUUID: "upper",
      startTick: 20,
    ),
    TimelinePlacementData(
      placementUUID: "early",
      sceneUUID: "early-scene",
      trackUUID: "lower",
      startTick: -10,
      durationTicks: 100,
    ),
  ],
);

ProviderContainer setup() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(outlineDataProvider.notifier).setOutlineData([
    StorylineData(
      storylineName: "主線",
      scenes: [
        StoryEventData(
          storyEvent: "事件",
          scenes: [
            SceneData(sceneUUID: "unplaced", sceneName: "未排定"),
            SceneData(sceneUUID: "lower-scene", sceneName: "下軌場景"),
            SceneData(sceneUUID: "upper-scene", sceneName: "上軌場景"),
            SceneData(sceneUUID: "early-scene", sceneName: "早期"),
          ],
        ),
      ],
    ),
  ]);
  container
      .read(timelineDocumentProvider.notifier)
      .setDocument(timeline, synchronizeOutline: false);
  container.read(timelineViewProvider.notifier).setCurrentTick(78);
  container
      .read(characterDataProvider.notifier)
      .setCharacterEntry(
        characterId: "alice",
        entry: const CharacterEntryData(
          characterId: "alice",
          displayName: "Alice",
        ),
      );
  container.read(worldSettingsDataProvider.notifier).setWorldSettingsData([
    LocationData(id: "home", localName: "家"),
  ]);
  container
      .read(itemWorkspaceProvider.notifier)
      .setWorkspace(
        ItemWorkspaceData(
          itemClasses: {
            "weapons": ItemClassData(classId: "weapons", name: "武器"),
          },
          itemInstances: {
            "sword": ItemInstanceData(
              instanceId: "sword",
              classId: "weapons",
              name: "劍",
            ),
          },
        ),
      );
  return container;
}

void main() {
  for (final page in ["location", "class", "instance"]) {
    testWidgets("$page copies the selected snapshot's complete state", (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = setup();
      final itemState = ItemSnapshotState(
        name: "歷史名稱",
        description: "歷史描述",
        exists: false,
        status: "來源狀態",
        holderCharacterId: "alice",
        locationId: "home",
        ownerCharacterIds: ["alice"],
        properties: {"材質": "鐵"},
        allocations: [ItemAllocationData(allocationId: "stock", quantity: 3)],
      );
      final locationState = LocationSnapshotState(
        name: "歷史地點",
        description: "歷史地點描述",
        exists: false,
        accessible: false,
        status: "來源狀態",
        controllerCharacterId: "alice",
        properties: {"天氣": "雨"},
      );
      final workspace = container.read(itemWorkspaceProvider);
      container
          .read(itemWorkspaceProvider.notifier)
          .setWorkspace(
            workspace.copyWith(
              itemClassStateChanges: [
                ItemClassStateChange(
                  stateChangeId: "source",
                  classId: "weapons",
                  sceneUUID: "upper-scene",
                  sourcePlacementUUID: "z-upper",
                  patch: ItemStatePatch.fromState(itemState),
                ),
                ItemClassStateChange(
                  stateChangeId: "later",
                  classId: "weapons",
                  sceneUUID: "upper-scene",
                  sourcePlacementUUID: "z-upper",
                  sequence: 1,
                  patch: ItemStatePatch(status: const StateValue.set("後續狀態")),
                ),
              ],
              itemInstanceStateChanges: [
                ItemInstanceStateChange(
                  stateChangeId: "source",
                  instanceId: "sword",
                  sceneUUID: "upper-scene",
                  sourcePlacementUUID: "z-upper",
                  patch: ItemStatePatch.fromState(itemState),
                ),
                ItemInstanceStateChange(
                  stateChangeId: "later",
                  instanceId: "sword",
                  sceneUUID: "upper-scene",
                  sourcePlacementUUID: "z-upper",
                  sequence: 1,
                  patch: ItemStatePatch(status: const StateValue.set("後續狀態")),
                ),
              ],
              locationStateChanges: [
                LocationStateChange(
                  stateChangeId: "source",
                  locationId: "home",
                  sceneUUID: "upper-scene",
                  sourcePlacementUUID: "z-upper",
                  patch: LocationStatePatch.fromState(locationState),
                ),
                LocationStateChange(
                  stateChangeId: "later",
                  locationId: "home",
                  sceneUUID: "upper-scene",
                  sourcePlacementUUID: "z-upper",
                  sequence: 1,
                  patch: LocationStatePatch(
                    status: const StateValue.set("後續狀態"),
                  ),
                ),
              ],
            ),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: page == "location"
                  ? const WorldSettingsView(initialLocationId: "home")
                  : const ItemView(initialClassId: "weapons"),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (page == "instance") {
        final tile = find.byKey(const ValueKey("item-instance-sword"));
        tester
            .widget<ListTile>(
              find.descendant(of: tile, matching: find.byType(ListTile)).first,
            )
            .onTap!();
        await tester.pumpAndSettle();
      }
      final previewKey = switch (page) {
        "location" => "location-snapshot-preview-home",
        "class" => "item-class-snapshot-preview-weapons",
        _ => "item-instance-snapshot-preview-sword",
      };
      final mini = tester.widget<TimelineMiniView>(
        find.descendant(
          of: find.byKey(ValueKey(previewKey)),
          matching: find.byType(TimelineMiniView),
        ),
      );
      final kind = switch (page) {
        "location" => "location",
        "class" => "itemClass",
        _ => "itemInstance",
      };
      mini.onMarkerGroupTap!([
        mini.markers.singleWhere((marker) => marker.id == "$kind:source"),
      ]);
      await tester.pumpAndSettle();
      final before = container.read(itemWorkspaceProvider);
      final copyKey = switch (page) {
        "location" => "location-copy-snapshot-home",
        "class" => "item-copy-snapshot",
        _ => "item-instance-copy-snapshot-sword",
      };
      final copy = find.byKey(ValueKey(copyKey));
      await tester.ensureVisible(copy);
      await tester.tap(copy);
      await tester.pumpAndSettle();
      expect(find.text("來源狀態"), findsWidgets);
      final scene = tester
          .widgetList<AppDropdownField<String>>(
            find.byType(AppDropdownField<String>),
          )
          .singleWhere((field) => field.labelText == "綁定 Scene");
      final targetPlacement = page == "class" ? "z-upper" : "repeat";
      scene.onChanged!(targetPlacement);
      await tester.pumpAndSettle();
      expect(container.read(itemWorkspaceProvider), same(before));
      expect(container.read(timelineViewProvider).currentTick, 20);
      final confirm = find.widgetWithText(FilledButton, "複製快照");
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      final after = container.read(itemWorkspaceProvider);
      if (page == "location") {
        expect(after.locationStateChanges, hasLength(3));
        final copied = after.locationStateChanges.last;
        expect(copied.sourcePlacementUUID, targetPlacement);
        expect(copied.stateChangeId, isNot("source"));
        expect(
          copied.patch.applyTo(LocationSnapshotState()).toJson(),
          locationState.toJson(),
        );
        expect(after.itemClassStateChanges, before.itemClassStateChanges);
        expect(after.itemInstanceStateChanges, before.itemInstanceStateChanges);
      } else {
        final copiedPatch = page == "class"
            ? after.itemClassStateChanges.last.patch
            : after.itemInstanceStateChanges.last.patch;
        expect(
          copiedPatch.applyTo(ItemSnapshotState()).toJson(),
          itemState.toJson(),
        );
        expect(
          page == "class"
              ? after.itemClassStateChanges
              : after.itemInstanceStateChanges,
          hasLength(3),
        );
        expect(
          page == "class"
              ? after.itemClassStateChanges.last.sourcePlacementUUID
              : after.itemInstanceStateChanges.last.sourcePlacementUUID,
          targetPlacement,
        );
        expect(after.locationStateChanges, before.locationStateChanges);
      }
      if (page == "class") {
        expect(
          tester
              .widget<TimelineMiniView>(
                find.descendant(
                  of: find.byKey(
                    const ValueKey("item-class-snapshot-preview-weapons"),
                  ),
                  matching: find.byType(TimelineMiniView),
                ),
              )
              .selectedMarkerId,
          "itemClass:${after.itemClassStateChanges.last.stateChangeId}",
        );
        expect(after.itemClassStateChanges.last.sequence, greaterThan(1));
        expect(
          resolveItemClassSnapshot(
            itemClass: after.itemClasses["weapons"]!,
            changes: after.itemClassStateChanges,
            timeline: timeline,
            atTick: 20,
          ).toJson(),
          itemState.toJson(),
        );
      }
      expect(
        container.read(timelineViewProvider).currentTick,
        page == "class" ? 20 : 80,
      );
      expect(tester.takeException(), isNull);
    });
  }

  test("Scene choices use start then track order and deterministic ties", () {
    final container = setup();
    final choices = container.read(placedSceneChoicesProvider);
    expect(choices.map((p) => p.placementUUID), [
      "early",
      "z-upper",
      "a-lower",
      "repeat",
    ]);
    TimelinePlacementData? nearest(int tick) =>
        nearestSceneChoice(choices, tick, (p) => p.startTick);
    expect(nearest(78)?.placementUUID, "repeat");
    expect(nearest(20)?.placementUUID, "z-upper");
    expect(nearest(50)?.placementUUID, "z-upper");
    expect(nearest(-100)?.placementUUID, "early");
    expect(nearest(100)?.placementUUID, "repeat");
    expect(
      nearestSceneChoice<TimelinePlacementData>([], 0, (p) => p.startTick),
      isNull,
    );
    container
        .read(timelineDocumentProvider.notifier)
        .setDocument(
          timeline.copyWith(
            tracks: [
              timeline.tracks.first.copyWith(order: 0),
              timeline.tracks.last,
            ],
          ),
          synchronizeOutline: false,
        );
    expect(
      container.read(placedSceneChoicesProvider).map((p) => p.placementUUID),
      ["early", "a-lower", "z-upper", "repeat"],
    );
  });

  test("Scene choices exclude missing references and container placements", () {
    final container = setup();
    container
        .read(timelineDocumentProvider.notifier)
        .setDocument(
          timeline.copyWith(
            placements: [
              ...timeline.placements,
              timeline.placements.first.copyWith(
                placementUUID: "container",
                level: TimelineElementLevel.middle,
              ),
              timeline.placements.first.copyWith(
                placementUUID: "missing",
                sceneUUID: "deleted",
              ),
            ],
          ),
          synchronizeOutline: false,
        );
    expect(container.read(placedSceneChoicesProvider), hasLength(4));
  });

  test("preview events use track order before sequence at the same start", () {
    final events = buildSnapshotTimelineEvents(
      subject: (kind: SnapshotSubjectKind.character, id: "alice"),
      timeline: timeline,
      characterChanges: [
        CharacterStateChange(
          stateChangeId: "lower",
          characterId: "alice",
          sceneUUID: "lower-scene",
          sourcePlacementUUID: "a-lower",
          fallbackTick: 20,
          sequence: -1,
        ),
        CharacterStateChange(
          stateChangeId: "upper",
          characterId: "alice",
          sceneUUID: "upper-scene",
          sourcePlacementUUID: "z-upper",
          fallbackTick: 20,
          sequence: 1,
        ),
      ],
    );
    expect(events.map((e) => e.sourceId), ["upper", "lower"]);
  });

  for (final page in ["character", "location", "class", "instance"]) {
    testWidgets("$page snapshot defaults to the closest Scene placement", (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = setup();
      final Widget view = switch (page) {
        "character" => const CharacterView(initialCharacterId: "alice"),
        "location" => const WorldSettingsView(initialLocationId: "home"),
        _ => const ItemView(initialClassId: "weapons"),
      };
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: Scaffold(body: view)),
        ),
      );
      await tester.pumpAndSettle();
      final layout = tester.widget<SnapshotWorkspaceLayout>(
        find.byType(SnapshotWorkspaceLayout),
      );
      final collectionRect = tester.getRect(find.byWidget(layout.collection));
      final timelineRect = tester.getRect(find.byWidget(layout.timeline));
      final detailsRect = tester.getRect(find.byWidget(layout.details));
      expect(collectionRect.bottom, lessThan(timelineRect.top));
      expect(timelineRect.bottom, lessThan(detailsRect.top));
      expect(
        find.descendant(
          of: find.byWidget(layout.details),
          matching: find.byType(SnapshotPanelCard),
        ),
        findsNothing,
      );
      final panel = find.byType(SnapshotPanelCard);
      final expandToggle = find.descendant(
        of: panel,
        matching: find.byKey(const ValueKey("snapshot-panel-expand-toggle")),
      );
      final preview = find
          .descendant(of: panel, matching: find.byType(SnapshotTimelinePreview))
          .first;
      final previewState = tester.state(preview);
      tester.widget<IconButton>(expandToggle).onPressed!();
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: panel,
          matching: find.byType(SnapshotTimelinePreview),
        ),
        findsNothing,
      );
      expect(
        tester.getRect(find.byWidget(layout.details)).top,
        lessThan(detailsRect.top),
      );
      expect(container.read(timelineViewProvider).currentTick, 78);
      tester.widget<IconButton>(expandToggle).onPressed!();
      await tester.pumpAndSettle();
      expect(tester.state(preview), same(previewState));
      if (page == "instance") {
        tester
            .widget<ListTile>(
              find
                  .descendant(
                    of: find.byKey(const ValueKey("item-instance-sword")),
                    matching: find.byType(ListTile),
                  )
                  .first,
            )
            .onTap!();
        await tester.pumpAndSettle();
      }
      final addKey = switch (page) {
        "character" => "character-snapshot-toolbar-add",
        "location" => "location-add-snapshot-home",
        "class" => "item-add-snapshot",
        _ => "item-instance-add-snapshot-sword",
      };
      tester.widget<NeonIconButton>(find.byKey(ValueKey(addKey))).onPressed!();
      await tester.pumpAndSettle();
      final selector = tester
          .widgetList<AppDropdownField<String>>(
            find.byType(AppDropdownField<String>),
          )
          .singleWhere((field) => field.labelText == "綁定 Scene");
      expect(selector.value, page == "character" ? "upper-scene" : "repeat");
      expect(selector.options.take(3).map((option) => option.label), [
        "主線 / 事件 / 早期",
        "主線 / 事件 / 上軌場景",
        "主線 / 事件 / 下軌場景",
      ]);
      expect(container.read(timelineViewProvider).currentTick, 78);
      final confirm = switch (page) {
        "character" => find.byKey(
          const ValueKey("character-snapshot-dialog-confirm"),
        ),
        "location" => find.byKey(const Key("location-snapshot-confirm")),
        "instance" => find.byKey(const Key("item-instance-snapshot-confirm")),
        _ => find.widgetWithText(FilledButton, "新增快照"),
      };
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      final String? placementId = switch (page) {
        "character" =>
          container
              .read(characterStateChangesProvider)
              .single
              .sourcePlacementUUID,
        "location" =>
          container
              .read(itemWorkspaceProvider)
              .locationStateChanges
              .single
              .sourcePlacementUUID,
        "class" =>
          container
              .read(itemWorkspaceProvider)
              .itemClassStateChanges
              .single
              .sourcePlacementUUID,
        _ =>
          container
              .read(itemWorkspaceProvider)
              .itemInstanceStateChanges
              .single
              .sourcePlacementUUID,
      };
      expect(placementId, "repeat");
      expect(tester.takeException(), isNull);
    });
  }
}
