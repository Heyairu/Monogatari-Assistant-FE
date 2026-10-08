import "dart:ui" show PointerDeviceKind;

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/ui_library.dart" show NeonIconButton;
import "package:monogatari_assistant/models/character_snapshot_data.dart";
import "package:monogatari_assistant/models/item_data.dart";
import "package:monogatari_assistant/models/item_snapshot_data.dart";
import "package:monogatari_assistant/models/location_snapshot_data.dart";
import "package:monogatari_assistant/models/timeline_data.dart";
import "package:monogatari_assistant/modules/itemview.dart";
import "package:monogatari_assistant/modules/worldsettingsview.dart";
import "package:monogatari_assistant/modules/characterview.dart";
import "package:monogatari_assistant/modules/character_relationship_graph_view.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";
import "package:monogatari_assistant/presentation/providers/character_snapshot_providers.dart";
import "package:monogatari_assistant/presentation/providers/snapshot_timeline_providers.dart";
import "package:monogatari_assistant/presentation/providers/timeline_providers.dart";
import "package:monogatari_assistant/presentation/widgets/scene_snapshot_timeline_preview.dart";
import "package:monogatari_assistant/presentation/widgets/snapshot_timeline_preview.dart";
import "package:monogatari_assistant/presentation/widgets/timeline_mini_view.dart";

const subject = (kind: SnapshotSubjectKind.character, id: "alice");
const placed = TimelineDocumentData(
  placements: [
    TimelinePlacementData(
      placementUUID: "p",
      sceneUUID: "scene",
      trackUUID: "t",
      startTick: 3,
      durationTicks: 5,
      label: "抵達",
    ),
    TimelinePlacementData(
      placementUUID: "p2",
      sceneUUID: "scene",
      trackUUID: "t",
      startTick: 15,
      durationTicks: 3,
      label: "再次抵達",
    ),
  ],
);

CharacterStateChange change(String id, {int sequence = 0}) =>
    CharacterStateChange(
      stateChangeId: id,
      characterId: "alice",
      sceneUUID: "scene",
      sourcePlacementUUID: "p",
      fallbackTick: 99,
      sequence: sequence,
    );

Widget host(ProviderContainer container, Widget child) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(width: 640, child: child),
          ),
        ),
      ),
    );

void main() {
  testWidgets(
    "toolbar stays on one scrollable row and follow toggles baseline",
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(timelineViewProvider.notifier).setCurrentTick(42);
      var mode = SnapshotPreviewMode.followTimeline;
      await tester.pumpWidget(
        host(
          container,
          Center(
            child: SizedBox(
              width: 280,
              child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.7)),
                child: StatefulBuilder(
                  builder: (context, setState) => SnapshotTimelinePreview(
                    subject: subject,
                    hint: "快照操作說明",
                    mode: mode,
                    onModeChanged: (value) => setState(() => mode = value),
                    snapshotActionsBuilder: (_) => [
                      NeonIconButton(
                        key: const ValueKey("add"),
                        icon: Icons.add,
                        label: "新增快照",
                        onPressed: () {},
                      ),
                      NeonIconButton(
                        key: const ValueKey("copy"),
                        icon: Icons.copy,
                        label: "複製快照",
                        onPressed: () {},
                      ),
                      const NeonIconButton(
                        key: ValueKey("delete"),
                        icon: Icons.delete,
                        label: "刪除快照",
                        onPressed: null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final follow = find.byKey(const ValueKey("snapshot-preview-follow"));
      expect(
        tester.widget<NeonIconButton>(follow).icon,
        Icons.playlist_add_check_rounded,
      );
      expect(tester.widget<NeonIconButton>(follow).label, "跟隨時間軸");
      expect(
        find.byKey(const ValueKey("snapshot-preview-baseline")),
        findsNothing,
      );
      expect(
        tester.getCenter(find.byKey(const ValueKey("add"))).dy,
        tester.getCenter(find.byKey(const ValueKey("copy"))).dy,
      );
      expect(
        tester
            .getCenter(find.byKey(const ValueKey("snapshot-preview-hint")))
            .dx,
        lessThan(tester.getCenter(find.byKey(const ValueKey("add"))).dx),
      );
      final toolbar = tester.widget<SingleChildScrollView>(
        find.byKey(const ValueKey("snapshot-preview-toolbar-scroll-area")),
      );
      expect((toolbar.padding! as EdgeInsets).top, greaterThan(0));
      expect(
        tester.getCenter(find.byKey(const ValueKey("copy"))).dy,
        tester.getCenter(follow).dy,
      );
      expect(
        tester.getCenter(find.byKey(const ValueKey("delete"))).dx,
        lessThan(tester.getCenter(find.byType(VerticalDivider)).dx),
      );
      expect(
        tester.getCenter(find.byType(VerticalDivider)).dx,
        lessThan(tester.getCenter(follow).dx),
      );
      final scrollbar = tester.widget<Scrollbar>(
        find.byKey(const ValueKey("snapshot-preview-toolbar-scrollbar")),
      );
      expect(scrollbar.thumbVisibility, isFalse);
      expect(scrollbar.controller!.position.maxScrollExtent, greaterThan(0));
      final toolbarHover = find.byKey(
        const ValueKey("snapshot-preview-toolbar-hover"),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(toolbarHover));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Scrollbar>(
              find.byKey(const ValueKey("snapshot-preview-toolbar-scrollbar")),
            )
            .thumbVisibility,
        isTrue,
      );
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Scrollbar>(
              find.byKey(const ValueKey("snapshot-preview-toolbar-scrollbar")),
            )
            .thumbVisibility,
        isFalse,
      );
      await mouse.removePointer();
      await tester.ensureVisible(follow);
      await tester.tap(follow);
      await tester.pumpAndSettle();
      expect(mode, SnapshotPreviewMode.baseline);
      expect(tester.widget<NeonIconButton>(follow).selected, isFalse);
      expect(
        tester
            .widget<TimelineMiniView>(find.byType(TimelineMiniView))
            .showPlayhead,
        isFalse,
      );
      await tester.tap(follow);
      await tester.pumpAndSettle();
      expect(mode, SnapshotPreviewMode.followTimeline);
      expect(container.read(timelineViewProvider).currentTick, 42);
      await tester.ensureVisible(
        find.byKey(const ValueKey("snapshot-preview-context")),
      );
      await tester.pumpAndSettle();
      expect(scrollbar.controller!.offset, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    "Scene menu changes context without changing the story or cursor",
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(timelineDocumentProvider.notifier).setDocument(placed);
      container.read(timelineViewProvider.notifier).setCurrentTick(42);
      await tester.pumpWidget(
        host(container, const SnapshotTimelinePreview(subject: subject)),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TimelineMiniView>(find.byType(TimelineMiniView))
            .placements,
        isEmpty,
      );
      await tester.tap(find.text("相關 Scene"));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, "完整 Scene"));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TimelineMiniView>(find.byType(TimelineMiniView))
            .placements,
        placed.placements,
      );
      expect(container.read(timelineViewProvider).currentTick, 42);
      expect(container.read(timelineDocumentProvider), placed);
      expect(container.read(characterStateChangesProvider), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  test("unused Tick projections are released after navigation", () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final oldCharacters = characterDataAtSnapshotTickProvider(1);
    final oldItems = itemClassSnapshotProvider((id: "none", tick: 1));
    final characterSubscription = container.listen(oldCharacters, (_, _) {});
    final itemSubscription = container.listen(oldItems, (_, _) {});
    expect(container.exists(oldCharacters), isTrue);
    expect(container.exists(oldItems), isTrue);
    characterSubscription.close();
    itemSubscription.close();
    await container.pump();
    expect(container.exists(oldCharacters), isFalse);
    expect(container.exists(oldItems), isFalse);
  });

  testWidgets(
    "location preview follows time and baseline keeps the global cursor",
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(worldSettingsDataProvider.notifier).setWorldSettingsData([
        LocationData(id: "home", localName: "家"),
      ]);
      container.read(timelineDocumentProvider.notifier).setDocument(placed);
      container
          .read(itemWorkspaceProvider.notifier)
          .putLocationStateChange(
            LocationStateChange(
              locationId: "home",
              sceneUUID: "scene",
              sourcePlacementUUID: "p",
              patch: LocationStatePatch(
                accessible: const StateValue.set(false),
                status: const StateValue.set("封閉"),
              ),
            ),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: WorldSettingsView(initialLocationId: "home")),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = container.read(itemWorkspaceProvider);
      final preview = find.byKey(
        const ValueKey("location-snapshot-preview-home"),
      );
      final mini = find.descendant(
        of: preview,
        matching: find.byType(TimelineMiniView),
      );
      expect(mini, findsOneWidget);
      tester.widget<TimelineMiniView>(mini).onTickChanged!(3);
      await tester.pumpAndSettle();
      expect(find.textContaining("封閉"), findsWidgets);
      final baseline = find.descendant(
        of: preview,
        matching: find.byKey(const ValueKey("snapshot-preview-follow")),
      );
      await tester.ensureVisible(baseline);
      await tester.tap(baseline);
      await tester.pumpAndSettle();
      expect(find.textContaining("封閉"), findsNothing);
      expect(container.read(timelineViewProvider).currentTick, 3);
      expect(tester.widget<TimelineMiniView>(mini).showPlayhead, isFalse);
      expect(container.read(itemWorkspaceProvider), same(before));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    "instance inherits Class markers without using them as delete targets",
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(timelineDocumentProvider.notifier).setDocument(placed);
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
              itemClassStateChanges: [
                ItemClassStateChange(
                  stateChangeId: "class-change",
                  classId: "weapons",
                  sceneUUID: "scene",
                  sourcePlacementUUID: "p",
                  patch: ItemStatePatch(status: const StateValue.set("損壞")),
                ),
              ],
              itemInstanceStateChanges: [
                ItemInstanceStateChange(
                  stateChangeId: "own-change",
                  instanceId: "sword",
                  sceneUUID: "unplaced",
                  fallbackTick: 5,
                  patch: ItemStatePatch(status: const StateValue.set("遺失")),
                ),
              ],
            ),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: ItemView(initialClassId: "weapons")),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final instancePreview = find.byKey(
        const ValueKey("item-instance-snapshot-preview-sword"),
      );
      expect(instancePreview, findsNothing);
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
      final mini = find.descendant(
        of: instancePreview,
        matching: find.byType(TimelineMiniView),
      );
      var timeline = tester.widget<TimelineMiniView>(mini);
      expect(timeline.markers, hasLength(2));
      timeline.onMarkerGroupTap!([
        timeline.markers.firstWhere((m) => m.id == "itemClass:class-change"),
      ]);
      await tester.pumpAndSettle();
      final delete = find.byKey(
        const ValueKey("item-instance-delete-selected-snapshot-sword"),
      );
      expect(tester.widget<NeonIconButton>(delete).onPressed, isNull);
      timeline = tester.widget<TimelineMiniView>(mini);
      timeline.onMarkerGroupTap!([
        timeline.markers.firstWhere((m) => m.id == "itemInstance:own-change"),
      ]);
      await tester.pumpAndSettle();
      expect(tester.widget<NeonIconButton>(delete).onPressed, isNotNull);
      timeline = tester.widget<TimelineMiniView>(mini);
      timeline.onTickChanged!(4);
      await tester.pumpAndSettle();
      expect(tester.widget<NeonIconButton>(delete).onPressed, isNull);
      expect(
        container.read(itemWorkspaceProvider).itemClassStateChanges,
        hasLength(1),
      );
      expect(
        container.read(itemWorkspaceProvider).itemInstanceStateChanges,
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("deleted selection clears without selecting another event", (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(characterStateChangesProvider.notifier).setChanges([
      change("a"),
      change("b"),
    ]);
    container.read(timelineDocumentProvider.notifier).setDocument(placed);
    container.read(timelineViewProvider.notifier).setCurrentTick(3);
    SnapshotTimelineEvent? selection;
    await tester.pumpWidget(
      host(
        container,
        SnapshotTimelinePreview(
          subject: subject,
          onEventSelected: (value) => selection = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("mini-timeline-scrubber")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey("snapshot-event-character:b")));
    await tester.pumpAndSettle();
    expect(selection?.sourceId, "b");
    container.read(characterStateChangesProvider.notifier).setChanges([
      change("a"),
    ]);
    await tester.pumpAndSettle();
    expect(selection, isNull);
    expect(find.textContaining("歷史預覽唯讀"), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test("event projection uses resolved placement, sequence, then ID", () {
    final events = buildSnapshotTimelineEvents(
      subject: subject,
      timeline: placed,
      characterChanges: [
        change("z"),
        change("a"),
        change("first", sequence: -1),
        CharacterStateChange(
          stateChangeId: "later",
          characterId: "alice",
          sceneUUID: "scene",
          sourcePlacementUUID: "p2",
          fallbackTick: -100,
        ),
        CharacterStateChange(
          characterId: "other",
          sceneUUID: "scene",
          fallbackTick: 0,
        ),
      ],
    );
    expect(events.map((e) => e.sourceId), ["first", "a", "z", "later"]);
    expect(events.map((e) => e.tick), [3, 3, 3, 15]);
    expect(events.first.placementUUID, "p");
  });

  test("missing sources remain visible and never fabricate placements", () {
    final events = buildSnapshotTimelineEvents(
      subject: subject,
      timeline: const TimelineDocumentData(),
      characterChanges: [change("a")],
    );
    expect(events.single.tick, 99);
    expect(events.single.usesFallbackTick, isTrue);
    expect(events.single.sourcePlacementMissing, isTrue);
    expect(events.single.placementUUID, isNull);
    final recovered = buildSnapshotTimelineEvents(
      subject: subject,
      timeline: placed.copyWith(placements: [placed.placements.last]),
      characterChanges: [change("a")],
    );
    expect(recovered.single.tick, 15);
    expect(recovered.single.sourcePlacementMissing, isTrue);
    expect(recovered.single.usesFallbackTick, isFalse);
  });

  test(
    "location and item projections preserve owners and inherited sources",
    () {
      final locations = buildSnapshotTimelineEvents(
        subject: (kind: SnapshotSubjectKind.location, id: "home"),
        timeline: placed,
        locationChanges: [
          LocationStateChange(
            locationId: "home",
            sceneUUID: "scene",
            transactionId: "batch",
            note: "消失",
          ),
          LocationStateChange(locationId: "child", sceneUUID: "scene"),
        ],
      );
      expect(locations, hasLength(1));
      expect(locations.single.transactionId, "batch");
      expect(locations.single.note, "消失");
      final events = buildSnapshotTimelineEvents(
        subject: (kind: SnapshotSubjectKind.itemInstance, id: "sword"),
        timeline: placed,
        instance: ItemInstanceData(instanceId: "sword", classId: "weapons"),
        classChanges: [
          ItemClassStateChange(
            stateChangeId: "same",
            classId: "weapons",
            sceneUUID: "scene",
          ),
          ItemClassStateChange(classId: "other", sceneUUID: "scene"),
        ],
        instanceChanges: [
          ItemInstanceStateChange(
            stateChangeId: "same",
            instanceId: "sword",
            sceneUUID: "scene",
          ),
        ],
      );
      expect(events, hasLength(2));
      expect(events.map((e) => e.id).toSet(), hasLength(2));
      expect(
        events.where((e) => e.inherited).single.description,
        contains("繼承自 Class"),
      );
      expect(
        events.where((e) => !e.inherited).single.kind,
        SnapshotSubjectKind.itemInstance,
      );
    },
  );

  testWidgets(
    "coincident events choose exact IDs; navigation changes no story data",
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(timelineDocumentProvider.notifier).setDocument(placed);
      container.read(timelineViewProvider.notifier).setCurrentTick(3);
      container.read(characterStateChangesProvider.notifier).setChanges([
        change("a"),
        change("b", sequence: 1),
      ]);
      final before = container.read(characterStateChangesProvider);
      final workspace = container.read(itemWorkspaceProvider);
      SnapshotTimelineEvent? selection;
      var mode = SnapshotPreviewMode.followTimeline;
      await tester.pumpWidget(
        host(
          container,
          StatefulBuilder(
            builder: (context, setState) => SnapshotTimelinePreview(
              subject: subject,
              mode: mode,
              onModeChanged: (value) => setState(() => mode = value),
              onEventSelected: (event) => selection = event,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey("mini-timeline-scrubber")));
      await tester.pumpAndSettle();
      expect(find.text("Tick 3 的事件"), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey("snapshot-event-character:b")),
      );
      await tester.pumpAndSettle();
      expect(selection?.sourceId, "b");
      tester
          .widget<TimelineMiniView>(find.byType(TimelineMiniView))
          .onTickChanged!(5);
      await tester.pumpAndSettle();
      expect(selection, isNull);
      expect(container.read(timelineViewProvider).currentTick, 5);
      expect(container.read(characterStateChangesProvider), same(before));
      expect(container.read(itemWorkspaceProvider), same(workspace));
      expect(container.read(timelineDocumentProvider), placed);
      await tester.tap(find.byKey(const ValueKey("snapshot-preview-follow")));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey("mini-timeline-scrubber")),
        findsNothing,
      );
      expect(
        tester
            .widget<TimelineMiniView>(find.byType(TimelineMiniView))
            .showPlayhead,
        isFalse,
      );
      tester
          .widget<TimelineMiniView>(find.byType(TimelineMiniView))
          .onTickChanged!(-2);
      await tester.pumpAndSettle();
      expect(mode, SnapshotPreviewMode.followTimeline);
      expect(container.read(timelineViewProvider).currentTick, -2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("local dialogs retain anchors in gaps and ambiguous ranges", (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(timelineDocumentProvider.notifier)
        .setDocument(
          placed.copyWith(
            placements: [
              ...placed.placements,
              placed.placements.first.copyWith(
                placementUUID: "overlap",
                sceneUUID: "other",
                startTick: 4,
              ),
            ],
          ),
        );
    container.read(timelineViewProvider.notifier).setCurrentTick(42);
    var placement = "p";
    await tester.pumpWidget(
      host(
        container,
        StatefulBuilder(
          builder: (context, setState) => SceneSnapshotTimelinePreview(
            subject: subject,
            placementUUID: placement,
            onPlacementSelected: (value) => setState(() => placement = value),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    void tick(int value) => tester
        .widget<TimelineMiniView>(find.byType(TimelineMiniView))
        .onTickChanged!(value);
    tick(5);
    await tester.pump();
    expect(placement, "p");
    tick(12);
    await tester.pump();
    expect(placement, "p");
    tick(16);
    await tester.pumpAndSettle();
    expect(placement, "p2");
    expect(container.read(timelineViewProvider).currentTick, 42);
    expect(container.read(characterStateChangesProvider), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets("narrow scaled baseline and empty history render", (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.7)),
                child: const SizedBox(
                  width: 280,
                  child: SnapshotTimelinePreview(
                    subject: subject,
                    mode: SnapshotPreviewMode.baseline,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TimelineMiniView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    "CharacterView time navigation keeps its editor and data intact",
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(characterDataProvider.notifier)
          .setCharacterEntry(
            characterId: "alice",
            entry: const CharacterEntryData(
              characterId: "alice",
              displayName: "艾莉絲",
            ),
          );
      container.read(timelineDocumentProvider.notifier).setDocument(placed);
      container.read(characterStateChangesProvider.notifier).setChanges([
        change("a"),
      ]);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: CharacterView())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(Tab, "故事快照"), findsNothing);
      expect(
        find.byKey(const ValueKey("character-snapshot-card")),
        findsOneWidget,
      );
      final before = container.read(characterStateChangesProvider);
      final mini = find.byType(TimelineMiniView);
      expect(mini, findsOneWidget);
      tester.widget<TimelineMiniView>(mini).onTickChanged!(5);
      await tester.pumpAndSettle();
      expect(find.text("故事狀態 · Tick 5 · 唯讀預覽"), findsOneWidget);
      expect(find.text("編輯預設"), findsNothing);
      expect(
        tester
            .widget<Tooltip>(
              find.byKey(const ValueKey("snapshot-preview-hint")),
            )
            .message,
        contains("此 Tick 無快照"),
      );
      expect(
        find.byKey(const ValueKey("character-snapshot-preview-alice")),
        findsOneWidget,
      );
      expect(container.read(characterStateChangesProvider), same(before));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    "graph snapshot switch enables, disables and restores minimized previews",
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(characterDataProvider.notifier)
          .setCharacterEntry(
            characterId: "alice",
            entry: const CharacterEntryData(
              characterId: "alice",
              displayName: "Alice",
            ),
          );
      container.read(timelineDocumentProvider.notifier).setDocument(placed);
      container.read(characterStateChangesProvider.notifier).setChanges([
        change("relationship").copyWith(
          patch: CharacterStatePatch(
            relationships: const [
              CharacterRelationship(person: "Ghost", relationship: "朋友"),
            ],
          ),
        ),
      ]);
      container.read(timelineViewProvider.notifier).setCurrentTick(42);
      final before = container.read(characterStateChangesProvider);
      Widget graph(int session) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: CharacterRelationshipGraphView(projectSessionId: session),
          ),
        ),
      );
      await tester.pumpWidget(graph(0));
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey("relationship-snapshot-toggle"));
      final card = find.byKey(const ValueKey("relationship-snapshot-card"));
      final preview = find.byType(SnapshotTimelinePreview);
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      GestureDetector nodeGesture() => tester.widget<GestureDetector>(
        find
            .descendant(
              of: find.byKey(const ValueKey("relationship-node-alice")),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      expect(tester.widget<NeonIconButton>(toggle).selected, isFalse);
      expect(card, findsNothing);
      expect(find.text("未連結：Ghost"), findsNothing);
      expect(nodeGesture().onPanStart, isNotNull);

      await tap(toggle);
      expect(tester.widget<NeonIconButton>(toggle).selected, isTrue);
      expect(card, findsOneWidget);
      expect(
        tester.widget<SnapshotTimelinePreview>(preview).mode,
        SnapshotPreviewMode.followTimeline,
      );
      expect(find.text("未連結：Ghost"), findsOneWidget);
      expect(nodeGesture().onPanStart, isNull);
      await tap(find.byKey(const ValueKey("snapshot-preview-local")));
      tester
          .widget<TimelineMiniView>(find.byType(TimelineMiniView))
          .onTickChanged!(5);
      await tester.pumpAndSettle();
      final previewState = tester.state(preview);

      await tap(find.byKey(const ValueKey("relationship-snapshot-minimize")));
      expect(tester.widget<NeonIconButton>(toggle).selected, isTrue);
      expect(card, findsNothing);
      expect(find.text("未連結：Ghost"), findsOneWidget);
      expect(nodeGesture().onPanStart, isNull);
      await tap(find.byKey(const ValueKey("relationship-toolbar-toggle")));
      expect(toggle, findsOneWidget);
      await tap(toggle);
      expect(card, findsOneWidget);
      expect(tester.widget<NeonIconButton>(toggle).selected, isTrue);
      expect(tester.state(preview), same(previewState));
      expect(tester.widget<SnapshotTimelinePreview>(preview).localTick, 5);

      await tap(toggle);
      expect(tester.widget<NeonIconButton>(toggle).selected, isFalse);
      expect(card, findsNothing);
      expect(find.text("未連結：Ghost"), findsNothing);
      expect(nodeGesture().onPanStart, isNotNull);
      await tap(toggle);
      expect(card, findsOneWidget);
      expect(tester.widget<SnapshotTimelinePreview>(preview).localTick, 5);
      expect(find.text("未連結：Ghost"), findsOneWidget);

      await tester.pumpWidget(graph(1));
      await tester.pumpAndSettle();
      expect(tester.widget<NeonIconButton>(toggle).selected, isFalse);
      expect(card, findsNothing);
      expect(find.text("未連結：Ghost"), findsNothing);
      await tap(toggle);
      expect(
        tester.widget<SnapshotTimelinePreview>(preview).mode,
        SnapshotPreviewMode.followTimeline,
      );
      expect(container.read(timelineViewProvider).currentTick, 42);
      expect(container.read(characterStateChangesProvider), same(before));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    "relationship graph previews arbitrary Tick independently and remains readonly",
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(characterDataProvider.notifier)
          .setCharacterEntry(
            characterId: "alice",
            entry: const CharacterEntryData(
              characterId: "alice",
              displayName: "艾莉絲",
            ),
          );
      container.read(timelineDocumentProvider.notifier).setDocument(placed);
      container.read(characterStateChangesProvider.notifier).setChanges([
        change("a"),
      ]);
      container.read(timelineViewProvider.notifier).setCurrentTick(42);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: CharacterRelationshipGraphView()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final transform = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!
          .value
          .clone();
      tester
          .widget<NeonIconButton>(
            find.byKey(const ValueKey("relationship-snapshot-toggle")),
          )
          .onPressed!();
      await tester.pumpAndSettle();
      tester
          .widget<NeonIconButton>(
            find.byKey(const ValueKey("snapshot-preview-local")),
          )
          .onPressed!();
      await tester.pumpAndSettle();
      tester
          .widget<NeonIconButton>(
            find.byKey(const ValueKey("relationship-toolbar-toggle")),
          )
          .onPressed!();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey("relationship-snapshot-card")),
        findsOneWidget,
      );
      tester
          .widget<TimelineMiniView>(find.byType(TimelineMiniView))
          .onTickChanged!(5);
      await tester.pumpAndSettle();
      expect(container.read(timelineViewProvider).currentTick, 42);
      final preview = tester.widget<SnapshotTimelinePreview>(
        find.byType(SnapshotTimelinePreview),
      );
      expect(preview.mode, SnapshotPreviewMode.localTick);
      expect(preview.localTick, 5);
      expect(find.textContaining("歷史預覽唯讀"), findsNothing);
      final hint = find.byKey(const ValueKey("snapshot-preview-hint"));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(hint));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.textContaining("歷史預覽唯讀"), findsOneWidget);
      await mouse.removePointer();
      await tester.pumpAndSettle();
      final gesture = tester.widget<GestureDetector>(
        find
            .descendant(
              of: find.byKey(const ValueKey("relationship-node-alice")),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      expect(gesture.onPanStart, isNull);
      expect(
        tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .transformationController!
            .value,
        transform,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey("snapshot-preview-follow")),
      );
      await tester.tap(find.byKey(const ValueKey("snapshot-preview-follow")));
      await tester.pumpAndSettle();
      tester
          .widget<TimelineMiniView>(find.byType(TimelineMiniView))
          .onTickChanged!(6);
      await tester.pumpAndSettle();
      expect(container.read(timelineViewProvider).currentTick, 6);
      await tester.ensureVisible(
        find.byKey(const ValueKey("snapshot-preview-follow")),
      );
      await tester.tap(find.byKey(const ValueKey("snapshot-preview-follow")));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SnapshotTimelinePreview>(
              find.byType(SnapshotTimelinePreview),
            )
            .mode,
        SnapshotPreviewMode.baseline,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
