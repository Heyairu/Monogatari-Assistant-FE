import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/models/item_data.dart";
import "package:monogatari_assistant/modules/outlineview.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";

void main() {
  testWidgets("event details link items and convert legacy text", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(outlineDataProvider.notifier).setOutlineData([
      StorylineData(
        chapterUUID: "storyline-1",
        storylineName: "主線",
        scenes: [
          StoryEventData(
            storyEventUUID: "event-1",
            storyEvent: "港口交易",
            item: ["舊通行證"],
          ),
        ],
      ),
    ]);
    container
        .read(itemWorkspaceProvider.notifier)
        .setWorkspace(
          ItemWorkspaceData(
            itemClasses: {
              "coin": ItemClassData(
                classId: "coin",
                name: "銀幣",
                mode: ItemMode.generic,
              ),
              "seal": ItemClassData(classId: "seal", name: "通行證"),
              "map": ItemClassData(classId: "map", name: "航海圖"),
            },
            itemRelations: [
              ItemRelationData(
                relationId: "coin-event",
                itemId: "coin",
                itemKind: ItemReferenceKind.itemClass,
                targetId: "event-1",
                targetKind: ItemRelationTargetKind.event,
                role: "交易物",
                note: "贖金",
              ),
            ],
          ),
        );
    String? openedClassId;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: OutlineAdjustView(
            onOpenItem: (classId) => openedClassId = classId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("物品分配"), findsOneWidget);
    expect(find.text("銀幣"), findsOneWidget);
    expect(find.text("物品 Class・交易物・贖金"), findsOneWidget);
    await tester.tap(find.byKey(const Key("event-open-item-coin-event")));
    expect(openedClassId, "coin");

    await tester.tap(
      find.byKey(const Key("event-legacy-item-event-1-convert-0")),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("legacy-item-link-existing")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("通行證"));
    await tester.pumpAndSettle();
    expect(
      container.read(outlineDataProvider).single.scenes.single.item,
      isEmpty,
    );
    expect(
      container
          .read(itemWorkspaceProvider)
          .itemRelations
          .any(
            (relation) =>
                relation.itemId == "seal" && relation.targetId == "event-1",
          ),
      isTrue,
    );

    await tester.tap(find.byKey(const Key("event-link-item")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("航海圖"));
    await tester.pumpAndSettle();
    expect(
      container
          .read(itemWorkspaceProvider)
          .itemRelations
          .any(
            (relation) =>
                relation.itemId == "map" && relation.targetId == "event-1",
          ),
      isTrue,
    );
  });

  testWidgets("legacy event text creates and links a dedicated item", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(outlineDataProvider.notifier).setOutlineData([
      StorylineData(
        storylineName: "主線",
        scenes: [
          StoryEventData(
            storyEventUUID: "event-create",
            storyEvent: "獲得護符",
            item: ["古老護符"],
          ),
        ],
      ),
    ]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OutlineAdjustView()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key("event-legacy-item-event-create-convert-0")),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("legacy-item-create-and-link")));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key("legacy-item-create-name")),
          )
          .initialValue,
      "古老護符",
    );
    await tester.tap(find.byKey(const Key("legacy-item-create-confirm")));
    await tester.pumpAndSettle();

    final workspace = container.read(itemWorkspaceProvider);
    expect(
      container.read(outlineDataProvider).single.scenes.single.item,
      isEmpty,
    );
    expect(workspace.itemClasses.values.single.name, "古老護符");
    expect(workspace.itemClasses.values.single.mode, ItemMode.dedicated);
    expect(workspace.itemInstances.values.single.name, "古老護符");
    expect(workspace.itemRelations, hasLength(1));
    expect(workspace.itemRelations.single.itemKind, ItemReferenceKind.instance);
    expect(workspace.itemRelations.single.targetId, "event-create");
    expect(workspace.itemRelations.single.role, "大綱物件");
  });

  testWidgets("legacy scene text links an existing item by ID", (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 3600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(outlineDataProvider.notifier).setOutlineData([
      StorylineData(
        storylineName: "主線",
        scenes: [
          StoryEventData(
            storyEventUUID: "night-event",
            storyEvent: "夜行",
            scenes: [
              SceneData(
                sceneUUID: "forest-scene",
                sceneName: "森林",
                item: ["舊火把"],
              ),
            ],
          ),
        ],
      ),
    ]);
    container
        .read(itemWorkspaceProvider.notifier)
        .putClass(
          ItemClassData(classId: "torch", name: "火把", mode: ItemMode.generic),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OutlineAdjustView()),
      ),
    );
    await tester.pumpAndSettle();

    final convert = find.byKey(
      const Key("scene-legacy-item-forest-scene-convert-0"),
    );
    await tester.ensureVisible(convert);
    await tester.tap(convert);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("legacy-item-link-existing")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("火把"));
    await tester.pumpAndSettle();

    final outline = container.read(outlineDataProvider);
    expect(outline.single.scenes.single.scenes.single.item, isEmpty);
    final relation = container.read(itemWorkspaceProvider).itemRelations.single;
    expect(relation.itemId, "torch");
    expect(relation.targetId, "forest-scene");
    expect(relation.targetKind, ItemRelationTargetKind.scene);

    container.read(itemWorkspaceProvider.notifier).putClass(
      ItemClassData(classId: "lantern", name: "提燈"),
    );
    await tester.pumpAndSettle();
    final assign = find.byKey(const Key("scene-link-item"));
    await tester.ensureVisible(assign);
    await tester.tap(assign);
    await tester.pumpAndSettle();
    await tester.tap(find.text("提燈"));
    await tester.pumpAndSettle();
    expect(
      container.read(itemWorkspaceProvider).itemRelations.any(
        (value) =>
            value.itemId == "lantern" &&
            value.targetId == "forest-scene" &&
            value.targetKind == ItemRelationTargetKind.scene,
      ),
      isTrue,
    );
  });

  testWidgets("stale legacy conversion leaves outline and items unchanged", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    StorylineData outlineWith(String value) => StorylineData(
      chapterUUID: "stale-story",
      storylineName: "主線",
      scenes: [
        StoryEventData(
          storyEventUUID: "stale-event",
          storyEvent: "事件",
          item: [value],
        ),
      ],
    );
    container.read(outlineDataProvider.notifier).setOutlineData([
      outlineWith("舊鑰匙"),
    ]);
    container
        .read(itemWorkspaceProvider.notifier)
        .putClass(ItemClassData(classId: "key", name: "鑰匙"));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OutlineAdjustView()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key("event-legacy-item-stale-event-convert-0")),
    );
    await tester.pumpAndSettle();
    container.read(outlineDataProvider.notifier).setOutlineData([
      outlineWith("協作者改過的鑰匙"),
    ]);
    await tester.tap(find.byKey(const Key("legacy-item-link-existing")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("鑰匙"));
    await tester.pumpAndSettle();

    expect(container.read(outlineDataProvider).single.scenes.single.item, [
      "協作者改過的鑰匙",
    ]);
    expect(container.read(itemWorkspaceProvider).itemRelations, isEmpty);
    expect(find.text("原物件文字已變更，請重新開啟轉換流程。"), findsOneWidget);
  });
}
