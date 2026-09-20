import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/models/item_data.dart";
import "package:monogatari_assistant/models/item_snapshot_data.dart";
import "package:monogatari_assistant/models/location_snapshot_data.dart";
import "package:monogatari_assistant/models/outline_data.dart";
import "package:monogatari_assistant/models/timeline_data.dart";
import "package:monogatari_assistant/modules/worldsettingsview.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";
import "package:monogatari_assistant/presentation/providers/timeline_providers.dart";

void main() {
  testWidgets("world detail fields defer writes until IME composition ends", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(worldSettingsDataProvider.notifier).setWorldSettingsData([
      LocationData(id: "ime-location", localName: "原始名稱"),
    ]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: WorldSettingsView(
              initialLocationId: "ime-location",
              selectionRequestId: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final region = find.byKey(const ValueKey("world-name-ime-location"));
    final field = find.descendant(
      of: region,
      matching: find.byType(TextFormField),
    );
    await tester.tap(field);
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: "世",
        selection: TextSelection.collapsed(offset: 1),
        composing: TextRange(start: 0, end: 1),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      container
          .read(worldSettingsDataProvider)
          .singleWhere((location) => location.id == "ime-location")
          .localName,
      "原始名稱",
    );
    final controller = tester.widget<TextFormField>(field).controller!;
    expect(controller.value.composing, const TextRange(start: 0, end: 1));

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: "世界",
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange.empty,
      ),
    );
    await tester.pump(const Duration(milliseconds: 301));

    expect(
      container
          .read(worldSettingsDataProvider)
          .singleWhere((location) => location.id == "ime-location")
          .localName,
      "世界",
    );
  });

  testWidgets(
    "location tree retains existing children beneath an unavailable parent",
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(worldSettingsDataProvider.notifier).setWorldSettingsData([
        LocationData(
          id: "city",
          localName: "城市",
          child: [
            LocationData(
              id: "street",
              localName: "街道",
              child: [LocationData(id: "house", localName: "房屋")],
            ),
          ],
        ),
      ]);
      container
          .read(itemWorkspaceProvider.notifier)
          .putLocationStateChange(
            LocationStateChange(
              stateChangeId: "city-disappears",
              locationId: "city",
              sceneUUID: "removed-scene",
              fallbackTick: 5,
              patch: LocationStatePatch(
                exists: const StateValue.set(false),
                name: const StateValue.set("沉沒城市"),
              ),
            ),
          );
      container.read(timelineViewProvider.notifier).setCurrentTick(4);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: WorldSettingsView())),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey("location-timeline-status-city")),
            )
            .data,
        isNot(contains("此 Tick 尚未存在")),
      );
      container.read(timelineViewProvider.notifier).setCurrentTick(5);
      await tester.pumpAndSettle();

      final cityStatus = find.byKey(
        const ValueKey("location-timeline-status-city"),
      );
      final streetStatus = find.byKey(
        const ValueKey("location-timeline-status-street"),
      );
      final houseStatus = find.byKey(
        const ValueKey("location-timeline-status-house"),
      );
      expect(cityStatus, findsOneWidget);
      expect(streetStatus, findsOneWidget);
      expect(houseStatus, findsOneWidget);
      expect(tester.widget<Text>(cityStatus).data, contains("此 Tick 尚未存在"));
      expect(tester.widget<Text>(cityStatus).data, contains("保留樹殼：仍有存在的子地點"));
      expect(tester.widget<Text>(cityStatus).data, contains("當時名稱：沉沒城市"));
      expect(
        tester.widget<Text>(streetStatus).data,
        contains("父層在此 Tick 不存在；此節點仍獨立存在"),
      );
      expect(
        tester.widget<Text>(houseStatus).data,
        contains("父層在此 Tick 不存在；此節點仍獨立存在"),
      );
    },
  );

  testWidgets("location page projects item quantities at current Tick", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(worldSettingsDataProvider.notifier).setWorldSettingsData([
      LocationData(id: "warehouse", localName: "倉庫"),
    ]);
    container
        .read(itemWorkspaceProvider.notifier)
        .putClass(
          ItemClassData(
            classId: "grain",
            name: "糧食",
            unit: "袋",
            mode: ItemMode.generic,
            defaultState: ItemSnapshotState(
              name: "糧食",
              allocations: [
                ItemAllocationData(
                  allocationId: "warehouse-grain",
                  locationId: "warehouse",
                  quantity: 8,
                  note: "備用糧食",
                ),
              ],
            ),
          ),
        );
    container
        .read(itemWorkspaceProvider.notifier)
        .putRelation(
          ItemRelationData(
            relationId: "grain-location-relation",
            itemId: "grain",
            itemKind: ItemReferenceKind.itemClass,
            targetId: "warehouse",
            targetKind: ItemRelationTargetKind.location,
            role: "儲藏物",
          ),
        );
    String? openedItemClassId;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: WorldSettingsView(
              initialLocationId: "warehouse",
              selectionRequestId: 1,
              onOpenItem: (classId) => openedItemClassId = classId,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final table = find.byKey(const ValueKey("location-items-table"));
    await tester.ensureVisible(table);

    expect(table, findsOneWidget);
    expect(find.text("一般關聯物品"), findsOneWidget);
    expect(find.text("目前位於本地點的物品"), findsOneWidget);
    expect(find.text("糧食"), findsNWidgets(2));
    expect(find.text("儲藏物"), findsOneWidget);
    expect(find.text("8 袋"), findsOneWidget);
    expect(find.text("備用糧食"), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey("location-open-item-warehouse-grain")),
    );
    expect(openedItemClassId, "grain");
    openedItemClassId = null;
    await tester.tap(
      find.byKey(
        const ValueKey("location-open-related-item-grain-location-relation"),
      ),
    );
    expect(openedItemClassId, "grain");
    container
        .read(itemWorkspaceProvider.notifier)
        .putClass(ItemClassData(classId: "relic", name: "石碑"));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("location-link-item")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("石碑"));
    await tester.pumpAndSettle();
    expect(
      container
          .read(itemWorkspaceProvider)
          .itemRelations
          .any(
            (relation) =>
                relation.itemId == "relic" && relation.targetId == "warehouse",
          ),
      isTrue,
    );

    container.read(itemWorkspaceProvider.notifier).putClass(
      ItemClassData(
        classId: "water",
        name: "飲水",
        mode: ItemMode.generic,
      ),
    );
    await tester.pumpAndSettle();
    final assignButton = find.byKey(const Key("location-assign-item"));
    await tester.ensureVisible(assignButton);
    await tester.tap(assignButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text("飲水"));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key("location-assignment-quantity")),
      "6",
    );
    await tester.tap(find.byKey(const Key("location-assignment-confirm")));
    await tester.pumpAndSettle();
    final water = container.read(itemWorkspaceProvider).itemClasses["water"]!;
    expect(water.defaultState.allocations.single.locationId, "warehouse");
    expect(water.defaultState.allocations.single.quantity, 6);
  });

  testWidgets("location snapshot is anchored to a timeline Scene", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(worldSettingsDataProvider.notifier).setWorldSettingsData([
      LocationData(
        id: "harbor",
        localName: "港口",
        customVal: [LocationCustomize(key: "治安", val: "普通")],
        child: [
          LocationData(
            id: "harbor-district",
            localName: "港區",
            child: [LocationData(id: "warehouse", localName: "倉庫")],
          ),
        ],
      ),
    ]);
    container.read(outlineDataProvider.notifier).setOutlineData([
      StorylineData(
        chapterUUID: "main-story",
        storylineName: "主線",
        scenes: [
          StoryEventData(
            storyEventUUID: "arrival-event",
            storyEvent: "抵達",
            scenes: [SceneData(sceneUUID: "arrival-scene", sceneName: "靠岸")],
          ),
        ],
      ),
    ]);
    container
        .read(timelineDocumentProvider.notifier)
        .setDocument(
          TimelineDocumentData.initial().copyWith(
            placements: const [
              TimelinePlacementData(
                placementUUID: "arrival-placement",
                sceneUUID: "arrival-scene",
                trackUUID: "timeline-track-default",
                startTick: 42,
                label: "靠岸",
              ),
            ],
          ),
          synchronizeOutline: false,
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: WorldSettingsView(
              initialLocationId: "harbor",
              selectionRequestId: 1,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final addButton = find.byKey(
      const ValueKey("location-add-snapshot-harbor"),
    );
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();
    expect(find.text("主線 / 抵達 / 靠岸"), findsOneWidget);
    await tester.tap(
      find.byKey(const Key("location-snapshot-include-descendants")),
    );
    await tester.pump();
    expect(find.text("將建立 3 筆獨立快照"), findsOneWidget);
    expect(
      find.byKey(const Key("location-snapshot-batch-preview")),
      findsOneWidget,
    );
    expect(find.text("批次差異預覽"), findsOneWidget);
    expect(find.textContaining("港口："), findsOneWidget);
    expect(find.textContaining("港區："), findsOneWidget);
    expect(find.textContaining("倉庫："), findsOneWidget);
    await tester.tap(find.byKey(const Key("location-snapshot-confirm")));
    await tester.pumpAndSettle();

    final changes = container.read(itemWorkspaceProvider).locationStateChanges;
    expect(changes, hasLength(3));
    expect(changes.map((change) => change.locationId).toSet(), {
      "harbor",
      "harbor-district",
      "warehouse",
    });
    expect(changes.map((change) => change.transactionId).toSet(), hasLength(1));
    expect(changes.first.transactionId, isNotNull);
    for (final change in changes) {
      expect(change.sceneUUID, "arrival-scene");
      expect(change.sourcePlacementUUID, "arrival-placement");
      expect(change.fallbackTick, 42);
      expect(change.patch.name, isNull);
      expect(change.patch.description, isNull);
      expect(change.patch.properties, isNull);
    }
    final deleteSnapshot = find.byKey(
      const Key("location-delete-selected-snapshot-harbor"),
    );
    expect(tester.widget<IconButton>(deleteSnapshot).onPressed, isNotNull);
    await tester.tap(deleteSnapshot);
    await tester.pumpAndSettle();
    expect(find.text("刪除整批地點快照？"), findsOneWidget);
    expect(find.textContaining("將一併刪除 3 筆快照"), findsOneWidget);
    await tester.tap(
      find.byKey(const Key("location-snapshot-delete-batch-confirm")),
    );
    await tester.pumpAndSettle();
    expect(container.read(itemWorkspaceProvider).locationStateChanges, isEmpty);

    await tester.tap(addButton);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key("location-snapshot-name")),
      "舊港",
    );
    await tester.enterText(
      find.byKey(const Key("location-snapshot-description")),
      "戰後封閉的舊港區",
    );
    await tester.enterText(
      find.byKey(const Key("location-snapshot-status")),
      "封鎖",
    );
    await tester.enterText(
      find.byKey(const Key("location-snapshot-property-value-0")),
      "危險",
    );
    await tester.tap(find.byKey(const Key("location-snapshot-property-add")));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key("location-snapshot-property-key-1")),
      "治安",
    );
    await tester.enterText(
      find.byKey(const Key("location-snapshot-property-value-1")),
      "暴雨",
    );
    await tester.tap(find.byKey(const Key("location-snapshot-confirm")));
    await tester.pump();
    expect(find.text("自訂屬性的設定名稱不可重複。"), findsOneWidget);
    expect(container.read(itemWorkspaceProvider).locationStateChanges, isEmpty);
    await tester.enterText(
      find.byKey(const Key("location-snapshot-property-key-1")),
      "天候",
    );
    await tester.tap(find.byKey(const Key("location-snapshot-confirm")));
    await tester.pumpAndSettle();

    final singleChange = container
        .read(itemWorkspaceProvider)
        .locationStateChanges
        .single;
    expect(singleChange.locationId, "harbor");
    expect(singleChange.transactionId, isNull);
    expect(singleChange.patch.name?.value, "舊港");
    expect(singleChange.patch.description?.value, "戰後封閉的舊港區");
    expect(singleChange.patch.status?.value, "封鎖");
    expect(singleChange.patch.properties?.value, {"治安": "危險", "天候": "暴雨"});
    expect(find.textContaining("名稱：舊港"), findsNWidgets(2));
    expect(find.textContaining("描述：戰後封閉的舊港區"), findsOneWidget);
    expect(find.textContaining("屬性：治安=危險、天候=暴雨"), findsOneWidget);
  });

  testWidgets(
    "permanent deletion previews impact and differs from story absence",
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(worldSettingsDataProvider.notifier).setWorldSettingsData([
        LocationData(
          id: "city",
          localName: "城市",
          child: [LocationData(id: "harbor", localName: "港口")],
        ),
      ]);
      container
          .read(itemWorkspaceProvider.notifier)
          .setWorkspace(
            ItemWorkspaceData(
              itemClasses: {
                "grain": ItemClassData(
                  classId: "grain",
                  name: "糧食",
                  mode: ItemMode.generic,
                  defaultState: ItemSnapshotState(
                    allocations: [
                      ItemAllocationData(
                        allocationId: "grain-city",
                        locationId: "city",
                        quantity: 3,
                      ),
                    ],
                  ),
                ),
              },
              itemRelations: [
                ItemRelationData(
                  relationId: "grain-harbor",
                  itemId: "grain",
                  itemKind: ItemReferenceKind.itemClass,
                  targetId: "harbor",
                  targetKind: ItemRelationTargetKind.location,
                ),
              ],
              locationStateChanges: [
                LocationStateChange(
                  stateChangeId: "city-absent",
                  locationId: "city",
                  sceneUUID: "scene",
                  patch: LocationStatePatch(
                    exists: const StateValue.set(false),
                  ),
                ),
              ],
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: WorldSettingsView())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip("刪除地點").first);
      await tester.pumpAndSettle();

      expect(find.text("永久刪除「城市」？"), findsOneWidget);
      expect(find.textContaining("新增 Scene 快照並關閉「此時已存在」"), findsOneWidget);
      expect(find.text("將永久刪除 2 個地點節點"), findsOneWidget);
      expect(find.text("移除 1 筆地點快照"), findsOneWidget);
      expect(find.text("移除 1 筆物品關聯"), findsOneWidget);
      expect(find.text("清除 1 筆物品地點記錄"), findsOneWidget);
      expect(container.read(worldSettingsDataProvider), isNotEmpty);

      await tester.tap(
        find.byKey(const Key("location-permanent-delete-confirm")),
      );
      await tester.pumpAndSettle();
      expect(container.read(worldSettingsDataProvider), isEmpty);
      final workspace = container.read(itemWorkspaceProvider);
      expect(workspace.locationStateChanges, isEmpty);
      expect(workspace.itemRelations, isEmpty);
      expect(workspace.itemClasses["grain"]!.defaultState.allocations, isEmpty);
    },
  );
}
