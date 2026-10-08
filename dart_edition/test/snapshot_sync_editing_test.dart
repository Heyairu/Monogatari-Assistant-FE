import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/ui_library.dart";
import "package:monogatari_assistant/models/character_snapshot_data.dart";
import "package:monogatari_assistant/models/item_snapshot_data.dart";
import "package:monogatari_assistant/models/location_snapshot_data.dart";
import "package:monogatari_assistant/modules/characterview.dart";
import "package:monogatari_assistant/modules/itemview.dart";
import "package:monogatari_assistant/modules/worldsettingsview.dart";
import "package:monogatari_assistant/modules/character_relationship_graph_view.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";
import "package:monogatari_assistant/presentation/providers/snapshot_timeline_providers.dart";
import "package:monogatari_assistant/presentation/providers/timeline_providers.dart";
import "package:monogatari_assistant/presentation/widgets/snapshot_panel_card.dart";
import "package:monogatari_assistant/presentation/widgets/snapshot_timeline_preview.dart";
import "package:monogatari_assistant/presentation/widgets/timeline_mini_view.dart";

import "scene_selection_test.dart" show setup;

Widget host(ProviderContainer container, Widget child) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  test(
    "exact-Tick selection prefers own events and retains explicit choices",
    () {
      const inherited = SnapshotTimelineEvent(
        id: "class:base",
        sourceId: "base",
        kind: SnapshotSubjectKind.itemClass,
        subjectId: "weapons",
        sceneUUID: "scene",
        tick: 20,
        label: "Class",
        inherited: true,
      );
      const first = SnapshotTimelineEvent(
        id: "instance:first",
        sourceId: "first",
        kind: SnapshotSubjectKind.itemInstance,
        subjectId: "sword",
        sceneUUID: "scene",
        tick: 20,
        label: "First",
      );
      const last = SnapshotTimelineEvent(
        id: "instance:last",
        sourceId: "last",
        kind: SnapshotSubjectKind.itemInstance,
        subjectId: "sword",
        sceneUUID: "scene",
        tick: 20,
        label: "Last",
        sequence: 1,
      );
      const events = [first, last, inherited];
      expect(snapshotEventAtTick(events, 20), same(last));
      expect(
        snapshotEventAtTick(events, 20, selectedId: first.id),
        same(first),
      );
      expect(snapshotEventAtTick(events, 21, selectedId: first.id), isNull);
      expect(snapshotEventAtTick([inherited], 20), same(inherited));
    },
  );
  testWidgets("independent preview toggles off both local and follow modes", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = setup();
    await tester.pumpWidget(
      host(container, const CharacterRelationshipGraphView()),
    );
    await tester.pumpAndSettle();
    tester
        .widget<NeonIconButton>(
          find.byKey(const ValueKey("relationship-snapshot-toggle")),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    final local = find.byKey(const ValueKey("snapshot-preview-local"));
    tester.widget<NeonIconButton>(local).onPressed!();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SnapshotTimelinePreview>(find.byType(SnapshotTimelinePreview))
          .mode,
      SnapshotPreviewMode.localTick,
    );
    tester
        .widget<TimelineMiniView>(find.byType(TimelineMiniView))
        .onTickChanged!(20);
    await tester.pumpAndSettle();
    tester.widget<NeonIconButton>(local).onPressed!();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SnapshotTimelinePreview>(find.byType(SnapshotTimelinePreview))
          .mode,
      SnapshotPreviewMode.baseline,
    );
    expect(tester.widget<NeonIconButton>(local).selected, isFalse);
    expect(
      tester
          .widget<NeonIconButton>(
            find.byKey(const ValueKey("snapshot-preview-follow")),
          )
          .selected,
      isFalse,
    );
    expect(container.read(timelineViewProvider).currentTick, 78);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    "character follows exact-Tick events and disables gaps without writing baseline",
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = setup();
      container.read(characterStateChangesProvider.notifier).setChanges([
        CharacterStateChange(
          stateChangeId: "source",
          characterId: "alice",
          fallbackTick: 20,
          sceneUUID: "upper-scene",
          sourcePlacementUUID: "z-upper",
          patch: CharacterStatePatch(
            statusEntries: [
              CharacterProfileTableEntry(name: "狀態", description: "來源"),
            ],
          ),
        ),
      ]);
      final beforeCharacters = container.read(characterDataProvider);
      final beforeChanges = container.read(characterStateChangesProvider);
      await tester.pumpWidget(
        host(container, const CharacterView(initialCharacterId: "alice")),
      );
      await tester.pumpAndSettle();
      final guard = find.byKey(
        const ValueKey("character-snapshot-editor-guard"),
      );
      expect(tester.widget<SnapshotEditorGuard>(guard).enabled, isFalse);
      container.read(timelineViewProvider.notifier).setCurrentTick(20);
      await tester.pumpAndSettle();
      expect(tester.widget<SnapshotEditorGuard>(guard).enabled, isTrue);
      expect(find.text("故事狀態 · Tick 20 · 編輯中：上軌場景"), findsOneWidget);
      expect(
        tester
            .widget<TimelineMiniView>(find.byType(TimelineMiniView))
            .selectedMarkerId,
        "character:source",
      );
      container.read(timelineViewProvider.notifier).setCurrentTick(21);
      await tester.pumpAndSettle();
      expect(tester.widget<SnapshotEditorGuard>(guard).enabled, isFalse);
      expect(
        tester
            .widget<TimelineMiniView>(find.byType(TimelineMiniView))
            .selectedMarkerId,
        isNull,
      );
      expect(container.read(characterDataProvider), same(beforeCharacters));
      expect(
        container.read(characterStateChangesProvider),
        same(beforeChanges),
      );
      tester
          .widget<NeonIconButton>(
            find.byKey(const ValueKey("snapshot-preview-follow")),
          )
          .onPressed!();
      await tester.pumpAndSettle();
      expect(tester.widget<SnapshotEditorGuard>(guard).enabled, isTrue);
      expect(find.text("故事狀態 · 編輯中：預設資料"), findsOneWidget);
      expect(container.read(characterDataProvider), same(beforeCharacters));
      expect(tester.takeException(), isNull);
    },
  );

  for (final page in ["location", "class", "instance"]) {
    testWidgets("$page loads exact-Tick editor and edits only its event", (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = setup();
      final workspace = container.read(itemWorkspaceProvider);
      container
          .read(itemWorkspaceProvider.notifier)
          .setWorkspace(
            workspace.copyWith(
              locationStateChanges: [
                LocationStateChange(
                  stateChangeId: "source",
                  locationId: "home",
                  sceneUUID: "upper-scene",
                  sourcePlacementUUID: "z-upper",
                  patch: LocationStatePatch(
                    name: const StateValue.set("歷史地點"),
                    status: const StateValue.set("來源"),
                  ),
                ),
              ],
              itemClassStateChanges: [
                ItemClassStateChange(
                  stateChangeId: "source",
                  classId: "weapons",
                  sceneUUID: "upper-scene",
                  sourcePlacementUUID: "z-upper",
                  patch: ItemStatePatch(
                    name: const StateValue.set("歷史物品"),
                    status: const StateValue.set("來源"),
                  ),
                ),
              ],
              itemInstanceStateChanges: [
                ItemInstanceStateChange(
                  stateChangeId: "source",
                  instanceId: "sword",
                  sceneUUID: "upper-scene",
                  sourcePlacementUUID: "z-upper",
                  patch: ItemStatePatch(
                    name: const StateValue.set("歷史單件"),
                    status: const StateValue.set("來源"),
                  ),
                ),
              ],
            ),
          );
      await tester.pumpWidget(
        host(
          container,
          page == "location"
              ? const WorldSettingsView(initialLocationId: "home")
              : const ItemView(initialClassId: "weapons"),
        ),
      );
      await tester.pumpAndSettle();
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
      final editorPrefix = switch (page) {
        "location" => "location-editor-home",
        "class" => "item-class-editor-weapons",
        _ => "item-instance-editor-sword",
      };
      Finder field(String context) => find.descendant(
        of: find.byKey(ValueKey("$editorPrefix-$context")),
        matching: find.byKey(const ValueKey("snapshot-state-status")),
      );
      expect(
        tester.widget<TextFormField>(field("preview-78")).enabled,
        isFalse,
      );
      container.read(timelineViewProvider.notifier).setCurrentTick(20);
      await tester.pumpAndSettle();
      final input = field("source");
      expect(tester.widget<TextFormField>(input).enabled, isTrue);
      final edit = tester.widget<TextFormField>(input).onChanged!;
      await tester.ensureVisible(input);
      await tester.enterText(input, "已編輯");
      await tester.pumpAndSettle();
      final after = container.read(itemWorkspaceProvider);
      expect(after.itemClasses, workspace.itemClasses);
      expect(after.itemInstances, workspace.itemInstances);
      final status = switch (page) {
        "location" => after.locationStateChanges.single.patch.status?.value,
        "class" => after.itemClassStateChanges.single.patch.status?.value,
        _ => after.itemInstanceStateChanges.single.patch.status?.value,
      };
      expect(status, "已編輯");
      container.read(timelineViewProvider.notifier).setCurrentTick(21);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(field("preview-21")).enabled,
        isFalse,
      );
      expect(
        tester.widget<TextFormField>(field("preview-21")).initialValue,
        "已編輯",
      );
      edit("過期編輯");
      expect(container.read(itemWorkspaceProvider), same(after));
      if (page == "location") {
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key("location-assign-item")),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key("location-link-item")))
              .onPressed,
          isNull,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
