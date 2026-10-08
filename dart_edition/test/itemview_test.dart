import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/ui_library.dart";
import "package:monogatari_assistant/modules/itemview.dart";
import "package:monogatari_assistant/models/item_data.dart";
import "package:monogatari_assistant/models/item_snapshot_data.dart";
import "package:monogatari_assistant/models/world_settings_data.dart";
import "package:monogatari_assistant/models/outline_data.dart";
import "package:monogatari_assistant/models/timeline_data.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";
import "package:monogatari_assistant/presentation/providers/timeline_providers.dart";

void _placeScene(ProviderContainer container, String sceneId, {int tick = 12}) {
  container
      .read(timelineDocumentProvider.notifier)
      .setDocument(
        TimelineDocumentData.initial().copyWith(
          placements: [
            TimelinePlacementData(
              placementUUID: "placement-$sceneId",
              sceneUUID: sceneId,
              trackUUID: "timeline-track-default",
              startTick: tick,
              label: sceneId,
            ),
          ],
        ),
        synchronizeOutline: false,
      );
}

// These management tests edit default item data; synchronized event editing
// is covered in snapshot_sync_editing_test.dart.
Future<void> _editDefaults(WidgetTester tester) async {
  await tester.pumpAndSettle();
  final buttons = tester.widgetList<NeonIconButton>(
    find.byKey(const ValueKey("snapshot-preview-follow")),
  );
  if (buttons.isNotEmpty && buttons.first.selected == true) {
    buttons.first.onPressed!();
    await tester.pumpAndSettle();
  }
}

void main() {
  Finder detailScrollable() => find
      .descendant(
        of: find.byWidgetPredicate(
          (widget) =>
              widget is ListView &&
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                "item-details-",
              ),
        ),
        matching: find.byType(Scrollable),
      )
      .first;
  Finder timelineScrollable() => find
      .descendant(
        of: find.byKey(const Key("item-narrow-sections")),
        matching: find.byType(Scrollable),
      )
      .first;
  testWidgets(
    "item search, filters and details share input surfaces and height",
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(itemWorkspaceProvider.notifier)
          .putClass(ItemClassData(classId: "padding-item", name: "內距測試"));

      for (final dark in [false, true]) {
        for (final scale in [1.0, 1.4]) {
          final theme = dark
              ? AppTheme.getDarkTheme(14, Colors.green)
              : AppTheme.getLightTheme(14, Colors.green);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: theme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const ItemView(initialClassId: "padding-item"),
              ),
            ),
          );
          await _editDefaults(tester);
          await tester.pumpAndSettle();
          for (final label in ["搜尋物品", "管理模式", "歸屬", "名稱", "數量單位"]) {
            final field = find.byWidgetPredicate(
              (widget) =>
                  widget is InputDecorator &&
                  widget.decoration.labelText == label,
            );
            expect(field, findsOneWidget);
            final decoration = tester.widget<InputDecorator>(field).decoration;
            expect(
              decoration.fillColor,
              theme.colorScheme.surfaceContainerLowest,
            );
            expect(
              (decoration.contentPadding! as EdgeInsets).left,
              AppSpacing.md,
            );
            final text = find
                .descendant(of: field, matching: find.byType(Text))
                .first;
            final context = tester.element(text);
            expect(
              InputDecorator.containerOf(context)!.size.height,
              closeTo(AppControlSize.heightForContext(context), 0.01),
              reason: "$label, dark=$dark, text scale=$scale",
            );
          }
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets("item page uses collection and detail sections", (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(itemWorkspaceProvider.notifier)
        .putClass(ItemClassData(classId: "relic", name: "古代遺物"));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ItemView()),
      ),
    );
    await _editDefaults(tester);
    await tester.pumpAndSettle();

    expect(find.text("物品設定"), findsOneWidget);
    expect(find.text("物品清單"), findsOneWidget);
    expect(find.text("物品詳情"), findsOneWidget);
    expect(find.byKey(const Key("item-class-collection")), findsOneWidget);
    expect(find.textContaining("專用 · 0 件單件 · 0 個關聯"), findsOneWidget);

    final addInput = find.descendant(
      of: find.byType(AddItemInput),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(addInput, "魔法書");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(
      container
          .read(itemWorkspaceProvider)
          .itemClasses
          .values
          .any((itemClass) => itemClass.name == "魔法書"),
      isTrue,
    );
  });

  testWidgets("item list archives a Class and its active instances", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(itemWorkspaceProvider.notifier);
    notifier.putClass(ItemClassData(classId: "relic", name: "古代遺物"));
    notifier.putInstance(
      ItemInstanceData(
        instanceId: "relic-instance",
        classId: "relic",
        name: "古代遺物",
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ItemView()),
      ),
    );
    await _editDefaults(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip("封存物品"));
    await tester.pumpAndSettle();
    expect(find.textContaining("1 件單件物品會一併封存"), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, "封存"));
    await tester.pumpAndSettle();

    final workspace = container.read(itemWorkspaceProvider);
    expect(workspace.itemClasses["relic"]?.archived, isTrue);
    expect(workspace.itemInstances["relic-instance"]?.archived, isTrue);
    expect(find.text("古代遺物"), findsNothing);
  });

  testWidgets("item list filters by mode, category and current assignment", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(itemWorkspaceProvider.notifier)
        .setWorkspace(
          ItemWorkspaceData(
            itemClasses: {
              "sword": ItemClassData(
                classId: "sword",
                name: "聖劍",
                category: "武器",
              ),
              "uniform": ItemClassData(
                classId: "uniform",
                name: "制服",
                category: "服裝",
                mode: ItemMode.semiDedicated,
              ),
              "coin": ItemClassData(
                classId: "coin",
                name: "金幣",
                category: "貨幣",
                mode: ItemMode.generic,
                defaultState: ItemSnapshotState(
                  allocations: [
                    ItemAllocationData(
                      allocationId: "coin-stock",
                      locationId: "vault",
                      quantity: 20,
                    ),
                  ],
                ),
              ),
            },
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ItemView()),
      ),
    );
    await _editDefaults(tester);
    await tester.pump();

    tester
        .widget<AppDropdownField<String>>(
          find.byKey(const Key("item-mode-filter")),
        )
        .onChanged!(ItemMode.generic.name);
    await tester.pump();
    expect(find.text("金幣"), findsOneWidget);
    expect(find.text("聖劍"), findsNothing);

    tester
        .widget<AppDropdownField<String>>(
          find.byKey(const Key("item-mode-filter")),
        )
        .onChanged!("__all__");
    tester
        .widget<AppDropdownField<String>>(
          find.byKey(const Key("item-category-filter")),
        )
        .onChanged!("武器");
    await tester.pump();
    expect(find.text("聖劍"), findsOneWidget);
    expect(find.text("金幣"), findsNothing);

    tester
        .widget<AppDropdownField<String>>(
          find.byKey(const Key("item-category-filter")),
        )
        .onChanged!("__all__");
    tester
        .widget<AppDropdownField<String>>(
          find.byKey(const Key("item-assignment-filter")),
        )
        .onChanged!("assigned");
    await tester.pump();
    expect(find.text("金幣"), findsOneWidget);
    expect(find.text("制服"), findsNothing);
  });

  testWidgets("item page opens a requested Class", (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(itemWorkspaceProvider.notifier)
        .setWorkspace(
          ItemWorkspaceData(
            itemClasses: {
              "first": ItemClassData(classId: "first", name: "第一件"),
              "requested": ItemClassData(classId: "requested", name: "指定物品"),
            },
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ItemView(initialClassId: "requested", selectionRequestId: 1),
        ),
      ),
    );
    await _editDefaults(tester);
    await tester.pump();

    expect(
      find.byKey(const ValueKey("item-details-requested")),
      findsOneWidget,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: ItemView(initialClassId: "first", selectionRequestId: 2),
        ),
      ),
    );
    await _editDefaults(tester);
    await tester.pump();

    expect(find.byKey(const ValueKey("item-details-first")), findsOneWidget);
  });

  testWidgets("item page creates a Class, changes mode and expands instances", (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ItemView())),
    );
    await _editDefaults(tester);

    expect(find.text("新增第一個物品"), findsOneWidget);
    await tester.tap(find.byKey(const Key("item-add-class")));
    await tester.pump();

    expect(find.byKey(const Key("item-mode-switch")), findsOneWidget);
    expect(find.text("專用"), findsWidgets);

    await tester.ensureVisible(find.byKey(const Key("item-mode-switch")));
    await tester.tap(find.text("半專用").last);
    await tester.pump();
    final addInstanceButton = find.byKey(const Key("item-add-instance"));
    await tester.ensureVisible(detailScrollable());
    await tester.scrollUntilVisible(
      addInstanceButton,
      400,
      scrollable: detailScrollable(),
    );
    tester.widget<FilledButton>(addInstanceButton).onPressed!();
    await tester.pump();

    expect(find.byKey(const Key("item-add-instance")), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ExpansionTile &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              "item-instance-",
            ),
      ),
      findsNWidgets(2),
    );

    final modeSwitch = find.byKey(const Key("item-mode-switch"));
    await tester.ensureVisible(detailScrollable());
    await tester.scrollUntilVisible(
      modeSwitch,
      -400,
      scrollable: detailScrollable(),
    );
    tester.widget<SegmentedButton<ItemMode>>(modeSwitch).onSelectionChanged!({
      ItemMode.dedicated,
    });
    await tester.pumpAndSettle();
    expect(find.text("目前有多個固定 ID，不能直接合併為一件專用物品。"), findsOneWidget);
    expect(tester.widget<SegmentedButton<ItemMode>>(modeSwitch).selected, {
      ItemMode.semiDedicated,
    });
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    await tester.tap(find.text("非專用").last);
    await tester.pump();
    expect(find.text("請先將 Scene 放入時間軸，再轉為非專用。"), findsOneWidget);
  });

  testWidgets("item name edit persists to the workspace", (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ItemView()),
      ),
    );
    await _editDefaults(tester);
    await tester.tap(find.byKey(const Key("item-add-class")));
    await tester.pump();
    final classId = container
        .read(itemWorkspaceProvider)
        .itemClasses
        .keys
        .single;
    await tester.enterText(find.byKey(ValueKey("item-name-$classId")), "驗收物品");
    await tester.pump();

    expect(
      container.read(itemWorkspaceProvider).itemClasses[classId]?.name,
      "驗收物品",
    );
    expect(
      container
          .read(itemWorkspaceProvider)
          .itemClasses[classId]
          ?.defaultState
          .name,
      "驗收物品",
    );
  });

  testWidgets("new item can switch to generic without a Scene", (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ItemView()),
      ),
    );
    await _editDefaults(tester);
    await tester.tap(find.byKey(const Key("item-add-class")));
    await tester.pump();

    final modeSwitch = find.byKey(const Key("item-mode-switch"));
    tester.widget<SegmentedButton<ItemMode>>(modeSwitch).onSelectionChanged!({
      ItemMode.generic,
    });
    await tester.pumpAndSettle();

    final workspace = container.read(itemWorkspaceProvider);
    expect(workspace.itemClasses.values.single.mode, ItemMode.generic);
    expect(workspace.itemInstances, isEmpty);
    expect(find.text("請先將 Scene 放入時間軸，再轉為非專用。"), findsNothing);
  });

  testWidgets("narrow item page keeps the selector above item details", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ItemView())),
    );
    await _editDefaults(tester);
    await tester.tap(find.byKey(const Key("item-add-class")));
    await tester.pump();
    expect(find.byKey(const Key("item-narrow-sections")), findsOneWidget);
    expect(find.text("物品清單"), findsOneWidget);
    expect(find.text("搜尋物品"), findsOneWidget);
    expect(find.text("物品詳情"), findsOneWidget);
    expect(find.text("返回物品清單"), findsNothing);
  });

  testWidgets("item page explicitly migrates legacy world items", (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(worldSettingsDataProvider.notifier).setWorldSettingsData([
      LocationData(
        id: "legacy-item",
        localName: "舊懷錶",
        nodeType: WorldNodeType.item,
      ),
    ]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ItemView()),
      ),
    );
    await _editDefaults(tester);

    await tester.tap(find.byKey(const Key("item-migrate-world")));
    await tester.pumpAndSettle();
    expect(find.text("搬移世界設定物品"), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, "搬移"));
    await tester.pumpAndSettle();

    expect(container.read(worldSettingsDataProvider), isEmpty);
    expect(
      container.read(itemWorkspaceProvider).itemInstances,
      contains("legacy-item"),
    );
    expect(find.text("舊懷錶"), findsOneWidget);
  });

  testWidgets("item page creates a Scene-anchored class snapshot", (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(outlineDataProvider.notifier).setOutlineData([
      StorylineData(
        storylineName: "主線",
        scenes: [
          StoryEventData(
            storyEvent: "事件",
            scenes: [SceneData(sceneUUID: "class-scene", sceneName: "場景")],
          ),
        ],
      ),
    ]);
    _placeScene(container, "class-scene", tick: 24);
    container.read(worldSettingsDataProvider.notifier).setWorldSettingsData([
      LocationData(id: "snapshot-location", localName: "測試倉庫"),
    ]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ItemView()),
      ),
    );
    await _editDefaults(tester);
    await tester.tap(find.byKey(const Key("item-add-class")));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key("item-add-snapshot")));
    await tester.tap(find.byKey(const Key("item-add-snapshot")));
    await tester.pumpAndSettle();
    expect(find.text("主線 / 事件 / 場景"), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextField, "狀態"),
      ),
      "損壞",
    );
    await tester.ensureVisible(
      find.byKey(const Key("item-class-snapshot-location")),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("item-class-snapshot-location")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("測試倉庫").last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, "新增快照"));
    await tester.pumpAndSettle();

    final changes = container.read(itemWorkspaceProvider).itemClassStateChanges;
    expect(changes, hasLength(1));
    expect(changes.single.patch.status?.value, "損壞");
    expect(changes.single.patch.locationId?.value, "snapshot-location");
    expect(changes.single.sourcePlacementUUID, "placement-class-scene");
    expect(changes.single.fallbackTick, 24);
    final deleteSnapshot = find.byKey(
      const Key("item-delete-selected-snapshot"),
    );
    expect(tester.widget<NeonIconButton>(deleteSnapshot).onPressed, isNotNull);
    await tester.ensureVisible(deleteSnapshot);
    await tester.tap(deleteSnapshot);
    await tester.pump();
    expect(
      container.read(itemWorkspaceProvider).itemClassStateChanges,
      isEmpty,
    );
  });

  testWidgets("item page links a Class to an event", (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(outlineDataProvider.notifier).setOutlineData([
      StorylineData(
        storylineName: "主線",
        scenes: [StoryEventData(storyEvent: "奪劍事件")],
      ),
    ]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ItemView()),
      ),
    );
    await _editDefaults(tester);

    await tester.tap(find.byKey(const Key("item-add-class")));
    await tester.pump();
    await tester.ensureVisible(detailScrollable());
    await tester.scrollUntilVisible(
      find.byKey(const Key("item-add-relation")),
      400,
      scrollable: detailScrollable(),
    );
    await tester.tap(find.byKey(const Key("item-add-relation")));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key("item-relation-target")), findsOneWidget);
    await tester.tap(find.byKey(const Key("item-relation-target")));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key("project-object-selector")), findsOneWidget);
    await tester.tap(find.text("奪劍事件").last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, "關係／用途"), "事件道具");
    await tester.tap(find.byKey(const Key("item-relation-confirm")));
    await tester.pumpAndSettle();

    final relations = container.read(itemWorkspaceProvider).itemRelations;
    expect(relations, hasLength(1));
    expect(relations.single.itemKind, ItemReferenceKind.itemClass);
    expect(relations.single.targetKind, ItemRelationTargetKind.event);
    expect(relations.single.role, "事件道具");
    expect(find.text("奪劍事件"), findsOneWidget);
  });

  testWidgets("item page creates a Scene snapshot for an instance", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(outlineDataProvider.notifier).setOutlineData([
      StorylineData(
        scenes: [
          StoryEventData(
            storyEvent: "事件",
            scenes: [SceneData(sceneUUID: "instance-scene", sceneName: "場景")],
          ),
        ],
      ),
    ]);
    _placeScene(container, "instance-scene");
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ItemView()),
      ),
    );
    await _editDefaults(tester);

    await tester.tap(find.byKey(const Key("item-add-class")));
    await tester.pump();
    final instanceId = container
        .read(itemWorkspaceProvider)
        .itemInstances
        .keys
        .single;
    await tester.scrollUntilVisible(
      find.byKey(ValueKey("item-instance-$instanceId")),
      300,
      scrollable: timelineScrollable(),
    );
    await tester.pumpAndSettle();
    final instanceHeader = find
        .descendant(
          of: find.byKey(ValueKey("item-instance-$instanceId")),
          matching: find.byType(ListTile),
        )
        .first;
    await tester.ensureVisible(instanceHeader);
    await tester.pumpAndSettle();
    await tester.tap(instanceHeader);
    await tester.pumpAndSettle();
    final snapshotButton = find.byKey(
      ValueKey("item-instance-add-snapshot-$instanceId"),
    );
    await tester.scrollUntilVisible(
      snapshotButton,
      150,
      scrollable: timelineScrollable(),
    );
    await tester.pumpAndSettle();
    tester.widget<NeonIconButton>(snapshotButton).onPressed!();
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextField, "狀態"),
      ),
      "遺失",
    );
    await tester.tap(find.byKey(const Key("item-instance-snapshot-confirm")));
    await tester.pumpAndSettle();

    final changes = container
        .read(itemWorkspaceProvider)
        .itemInstanceStateChanges;
    expect(changes, hasLength(1));
    expect(changes.single.patch.status?.value, "遺失");
    expect(changes.single.sourcePlacementUUID, "placement-instance-scene");
    final deleteSnapshot = find.byKey(
      ValueKey("item-instance-delete-selected-snapshot-$instanceId"),
    );
    expect(tester.widget<NeonIconButton>(deleteSnapshot).onPressed, isNotNull);
    await tester.tap(deleteSnapshot);
    await tester.pump();
    expect(
      container.read(itemWorkspaceProvider).itemInstanceStateChanges,
      isEmpty,
    );
  });

  testWidgets("generic item records aggregate allocation quantity", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(worldSettingsDataProvider.notifier).setWorldSettingsData([
      LocationData(id: "warehouse", localName: "倉庫"),
    ]);
    container
        .read(itemWorkspaceProvider.notifier)
        .putClass(
          ItemClassData(
            classId: "supplies",
            name: "補給品",
            mode: ItemMode.generic,
          ),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ItemView()),
      ),
    );
    await _editDefaults(tester);

    await tester.tap(find.text("補給品").first);
    await _editDefaults(tester);
    await tester.pump();
    final addButton = find.byKey(const Key("item-add-allocation"));
    await tester.ensureVisible(addButton);
    tester.widget<FilledButton>(addButton).onPressed!();
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key("item-allocation-quantity")),
      "12",
    );
    await tester.tap(find.byKey(const Key("item-allocation-confirm")));
    await tester.pumpAndSettle();

    final itemClass = container
        .read(itemWorkspaceProvider)
        .itemClasses
        .values
        .single;
    expect(itemClass.mode, ItemMode.generic);
    expect(itemClass.defaultState.allocations, hasLength(1));
    expect(itemClass.defaultState.allocations.single.locationId, "warehouse");
    expect(itemClass.defaultState.allocations.single.quantity, 12);
  });

  testWidgets("generic item transfers quantity through a Scene snapshot", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(worldSettingsDataProvider.notifier).setWorldSettingsData([
      LocationData(id: "source", localName: "倉庫"),
      LocationData(id: "destination", localName: "市集"),
    ]);
    container.read(outlineDataProvider.notifier).setOutlineData([
      StorylineData(
        scenes: [
          StoryEventData(
            storyEvent: "交易",
            scenes: [SceneData(sceneUUID: "trade-scene", sceneName: "成交")],
          ),
        ],
      ),
    ]);
    _placeScene(container, "trade-scene", tick: 36);
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
                  allocationId: "source-stock",
                  locationId: "source",
                  quantity: 10,
                ),
              ],
            ),
          ),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ItemView()),
      ),
    );
    await _editDefaults(tester);
    await tester.tap(find.text("糧食"));
    await _editDefaults(tester);
    await tester.pump();
    final transferButton = find.byKey(
      const ValueKey("item-transfer-source-stock"),
    );
    await tester.ensureVisible(transferButton);
    tester.widget<NeonIconButton>(transferButton).onPressed!();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("item-transfer-target")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("地點：市集").last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key("item-transfer-quantity")),
      "3",
    );
    await tester.tap(find.byKey(const Key("item-transfer-confirm")));
    await tester.pumpAndSettle();

    final change = container
        .read(itemWorkspaceProvider)
        .itemClassStateChanges
        .single;
    final allocations = change.patch.allocations!.value!;
    expect(allocations.first.quantity, 7);
    expect(
      allocations
          .singleWhere((value) => value.locationId == "destination")
          .quantity,
      3,
    );
    expect(change.sceneUUID, "trade-scene");
    expect(change.sourcePlacementUUID, "placement-trade-scene");
    expect(change.fallbackTick, 36);
  });

  testWidgets("semi-dedicated stock materializes one instance at a Scene", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(worldSettingsDataProvider.notifier).setWorldSettingsData([
      LocationData(id: "warehouse", localName: "倉庫"),
    ]);
    container.read(outlineDataProvider.notifier).setOutlineData([
      StorylineData(
        scenes: [
          StoryEventData(
            storyEvent: "分配",
            scenes: [SceneData(sceneUUID: "split-scene", sceneName: "領取")],
          ),
        ],
      ),
    ]);
    _placeScene(container, "split-scene", tick: 24);
    container
        .read(itemWorkspaceProvider.notifier)
        .putClass(
          ItemClassData(
            classId: "keys",
            name: "鑰匙",
            unit: "把",
            mode: ItemMode.semiDedicated,
            defaultState: ItemSnapshotState(
              name: "鑰匙",
              allocations: [
                ItemAllocationData(
                  allocationId: "warehouse-keys",
                  locationId: "warehouse",
                  quantity: 5,
                ),
              ],
            ),
          ),
        );
    container
        .read(itemWorkspaceProvider.notifier)
        .putClassStateChange(
          ItemClassStateChange(
            stateChangeId: "earlier-stock-count",
            classId: "keys",
            sceneUUID: "unplaced-stock-count",
            fallbackTick: 20,
            patch: ItemStatePatch(
              allocations: StateValue.set([
                ItemAllocationData(
                  allocationId: "warehouse-keys",
                  locationId: "warehouse",
                  quantity: 2,
                ),
              ]),
            ),
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ItemView()),
      ),
    );
    await _editDefaults(tester);
    await tester.tap(find.text("鑰匙").first);
    await _editDefaults(tester);
    await tester.pumpAndSettle();
    final materializeButton = find.byKey(
      const ValueKey("item-materialize-warehouse-keys"),
    );
    await tester.ensureVisible(materializeButton);
    tester.widget<NeonIconButton>(materializeButton).onPressed!();
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key("item-materialize-name")),
      "北門鑰匙",
    );
    await tester.tap(find.byKey(const Key("item-materialize-confirm")));
    await tester.pumpAndSettle();

    final workspace = container.read(itemWorkspaceProvider);
    final instance = workspace.itemInstances.values.single;
    expect(instance.name, "北門鑰匙");
    expect(workspace.itemClassStateChanges, hasLength(2));
    expect(workspace.itemInstanceStateChanges, hasLength(1));
    expect(container.read(timelineViewProvider).currentTick, 24);
    final timeline = container.read(timelineDocumentProvider);
    final itemClass = workspace.itemClasses["keys"]!;
    expect(
      resolveItemClassSnapshot(
        itemClass: itemClass,
        changes: workspace.itemClassStateChanges,
        timeline: timeline,
        atTick: 19,
      ).allocations.single.quantity,
      5,
    );
    expect(
      resolveItemClassSnapshot(
        itemClass: itemClass,
        changes: workspace.itemClassStateChanges,
        timeline: timeline,
        atTick: 23,
      ).allocations.single.quantity,
      2,
    );
    expect(
      resolveItemClassSnapshot(
        itemClass: itemClass,
        changes: workspace.itemClassStateChanges,
        timeline: timeline,
        atTick: 24,
      ).allocations.single.quantity,
      1,
    );
    expect(
      resolveItemInstanceSnapshot(
        itemClass: itemClass,
        instance: instance,
        instanceChanges: workspace.itemInstanceStateChanges,
        timeline: timeline,
        atTick: 23,
      ).exists,
      isFalse,
    );
    expect(
      resolveItemInstanceSnapshot(
        itemClass: itemClass,
        instance: instance,
        instanceChanges: workspace.itemInstanceStateChanges,
        timeline: timeline,
        atTick: 24,
      ).exists,
      isTrue,
    );
    expect(find.text("北門鑰匙"), findsWidgets);
    tester
        .widgetList<NeonIconButton>(
          find.byKey(const ValueKey("snapshot-preview-follow")),
        )
        .first
        .onPressed!();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey("item-allocation-warehouse-keys")),
      150,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey("item-details-keys")),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text("1 把"), findsOneWidget);
    await _editDefaults(tester);
    final scaffoldContext = tester.element(find.byType(Scaffold));
    ScaffoldMessenger.of(scaffoldContext).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    tester
        .widget<SegmentedButton<ItemMode>>(
          find.byKey(const Key("item-mode-switch")),
        )
        .onSelectionChanged!({ItemMode.dedicated});
    await tester.pumpAndSettle();
    expect(find.text("仍有未拆分的聚合數量，請先逐件拆分後再轉為專用。"), findsOneWidget);
    expect(
      container.read(itemWorkspaceProvider).itemClasses["keys"]?.mode,
      ItemMode.semiDedicated,
    );
  });

  testWidgets("one generic unit converts directly to dedicated at a Scene", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(worldSettingsDataProvider.notifier).setWorldSettingsData([
      LocationData(id: "vault", localName: "寶庫"),
    ]);
    container.read(outlineDataProvider.notifier).setOutlineData([
      StorylineData(
        scenes: [
          StoryEventData(
            storyEvent: "加冕",
            scenes: [SceneData(sceneUUID: "coronation", sceneName: "戴上王冠")],
          ),
        ],
      ),
    ]);
    _placeScene(container, "coronation", tick: 30);
    container
        .read(itemWorkspaceProvider.notifier)
        .putClass(
          ItemClassData(
            classId: "crown",
            name: "王冠",
            mode: ItemMode.generic,
            defaultState: ItemSnapshotState(
              name: "王冠",
              allocations: [
                ItemAllocationData(
                  allocationId: "vault-crown",
                  locationId: "vault",
                  quantity: 1,
                ),
              ],
            ),
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ItemView()),
      ),
    );
    await _editDefaults(tester);
    await tester.tap(find.text("王冠").first);
    await _editDefaults(tester);
    await tester.pumpAndSettle();
    final modeSwitch = find.byKey(const Key("item-mode-switch"));
    tester.widget<SegmentedButton<ItemMode>>(modeSwitch).onSelectionChanged!({
      ItemMode.dedicated,
    });
    await tester.pumpAndSettle();
    expect(find.text("建立專用單件"), findsOneWidget);
    await tester.tap(find.byKey(const Key("item-materialize-confirm")));
    await tester.pumpAndSettle();

    final workspace = container.read(itemWorkspaceProvider);
    final itemClass = workspace.itemClasses["crown"]!;
    final instance = workspace.itemInstances.values.single;
    expect(itemClass.mode, ItemMode.dedicated);
    expect(itemClass.conversionSource?.sceneUUID, "coronation");
    expect(
      workspace
          .itemClassStateChanges
          .single
          .patch
          .allocations
          ?.value
          ?.single
          .quantity,
      0,
    );
    expect(
      workspace.itemInstanceStateChanges.single.patch.exists?.value,
      isTrue,
    );
    final timeline = container.read(timelineDocumentProvider);
    expect(
      resolveItemClassSnapshot(
        itemClass: itemClass,
        changes: workspace.itemClassStateChanges,
        timeline: timeline,
        atTick: 29,
      ).allocations.single.quantity,
      1,
    );
    expect(
      resolveItemInstanceSnapshot(
        itemClass: itemClass,
        instance: instance,
        instanceChanges: workspace.itemInstanceStateChanges,
        timeline: timeline,
        atTick: 29,
      ).exists,
      isFalse,
    );
    expect(
      resolveItemInstanceSnapshot(
        itemClass: itemClass,
        instance: instance,
        instanceChanges: workspace.itemInstanceStateChanges,
        timeline: timeline,
        atTick: 30,
      ).exists,
      isTrue,
    );
  });

  testWidgets("identified items safely aggregate into a new Class at a Scene", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(worldSettingsDataProvider.notifier).setWorldSettingsData([
      LocationData(id: "warehouse", localName: "倉庫"),
    ]);
    container.read(outlineDataProvider.notifier).setOutlineData([
      StorylineData(
        scenes: [
          StoryEventData(
            storyEvent: "清點",
            scenes: [SceneData(sceneUUID: "inventory", sceneName: "重新入庫")],
          ),
        ],
      ),
    ]);
    _placeScene(container, "inventory", tick: 20);
    final sourceClass = ItemClassData(
      classId: "keys",
      name: "鑰匙",
      unit: "把",
      mode: ItemMode.semiDedicated,
      defaultState: ItemSnapshotState(name: "鑰匙"),
    );
    final warehouseKey = ItemInstanceData(
      instanceId: "warehouse-key",
      classId: "keys",
      name: "倉庫鑰匙",
      defaultState: ItemStatePatch(
        exists: const StateValue.set(true),
        locationId: const StateValue.set("warehouse"),
      ),
    );
    final looseKey = ItemInstanceData(
      instanceId: "loose-key",
      classId: "keys",
      name: "散落鑰匙",
      defaultState: ItemStatePatch(exists: const StateValue.set(true)),
    );
    final relation = ItemRelationData(
      relationId: "historical-relation",
      itemId: "warehouse-key",
      targetId: "warehouse",
      targetKind: ItemRelationTargetKind.location,
      role: "原存放處",
    );
    container
        .read(itemWorkspaceProvider.notifier)
        .setWorkspace(
          ItemWorkspaceData(
            itemClasses: {"keys": sourceClass},
            itemInstances: {
              warehouseKey.instanceId: warehouseKey,
              looseKey.instanceId: looseKey,
            },
            itemRelations: [relation],
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ItemView()),
      ),
    );
    await _editDefaults(tester);
    await tester.tap(find.text("鑰匙").first);
    await tester.pumpAndSettle();
    await _editDefaults(tester);
    tester
        .widget<SegmentedButton<ItemMode>>(
          find.byKey(const Key("item-mode-switch")),
        )
        .onSelectionChanged!({ItemMode.generic});
    await tester.pumpAndSettle();

    expect(find.text("安全轉為非專用"), findsOneWidget);
    expect(find.text("將彙總 2 件當時存在的單件，建立 2 筆聚合分配。"), findsOneWidget);
    await tester.tap(find.byKey(const Key("item-demotion-confirm")));
    await tester.pumpAndSettle();

    final workspace = container.read(itemWorkspaceProvider);
    expect(workspace.itemClasses, hasLength(2));
    final archivedClass = workspace.itemClasses["keys"]!;
    final aggregateClass = workspace.itemClasses.values.singleWhere(
      (value) => value.classId != "keys",
    );
    expect(archivedClass.archived, isTrue);
    expect(aggregateClass.mode, ItemMode.generic);
    expect(
      workspace.itemInstances.values.every((value) => value.archived),
      isTrue,
    );
    expect(workspace.itemRelations, [relation]);
    expect(container.read(timelineViewProvider).currentTick, 20);

    final timeline = container.read(timelineDocumentProvider);
    expect(
      resolveItemClassSnapshot(
        itemClass: archivedClass,
        changes: workspace.itemClassStateChanges,
        timeline: timeline,
        atTick: 19,
      ).exists,
      isTrue,
    );
    expect(
      resolveItemClassSnapshot(
        itemClass: archivedClass,
        changes: workspace.itemClassStateChanges,
        timeline: timeline,
        atTick: 20,
      ).exists,
      isFalse,
    );
    final aggregateBefore = resolveItemClassSnapshot(
      itemClass: aggregateClass,
      changes: workspace.itemClassStateChanges,
      timeline: timeline,
      atTick: 19,
    );
    final aggregateAfter = resolveItemClassSnapshot(
      itemClass: aggregateClass,
      changes: workspace.itemClassStateChanges,
      timeline: timeline,
      atTick: 20,
    );
    expect(aggregateBefore.exists, isFalse);
    expect(aggregateAfter.exists, isTrue);
    expect(aggregateAfter.allocations, hasLength(2));
    expect(
      aggregateAfter.allocations
          .singleWhere((value) => value.locationId == "warehouse")
          .quantity,
      1,
    );
    expect(
      aggregateAfter.allocations
          .singleWhere(
            (value) =>
                value.locationId == null && value.holderCharacterId == null,
          )
          .quantity,
      1,
    );
    for (final instance in workspace.itemInstances.values) {
      expect(
        resolveItemInstanceSnapshot(
          itemClass: archivedClass,
          instance: instance,
          instanceChanges: workspace.itemInstanceStateChanges,
          timeline: timeline,
          atTick: 19,
        ).exists,
        isTrue,
      );
      expect(
        resolveItemInstanceSnapshot(
          itemClass: archivedClass,
          instance: instance,
          instanceChanges: workspace.itemInstanceStateChanges,
          timeline: timeline,
          atTick: 20,
        ).exists,
        isFalse,
      );
    }
    expect(find.text("未分配"), findsOneWidget);
  });

  testWidgets("stale demotion preview cannot overwrite newer item data", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(outlineDataProvider.notifier).setOutlineData([
      StorylineData(
        scenes: [
          StoryEventData(
            storyEvent: "整理",
            scenes: [SceneData(sceneUUID: "sorting", sceneName: "整理物品")],
          ),
        ],
      ),
    ]);
    _placeScene(container, "sorting", tick: 15);
    final sourceClass = ItemClassData(
      classId: "tools",
      name: "工具",
      mode: ItemMode.semiDedicated,
    );
    container.read(itemWorkspaceProvider.notifier).putClass(sourceClass);
    container
        .read(itemWorkspaceProvider.notifier)
        .putInstance(
          ItemInstanceData(
            instanceId: "hammer",
            classId: "tools",
            name: "鐵鎚",
            defaultState: ItemStatePatch(exists: const StateValue.set(true)),
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ItemView()),
      ),
    );
    await _editDefaults(tester);
    await tester.tap(find.text("工具").first);
    await _editDefaults(tester);
    await tester.pumpAndSettle();
    tester
        .widget<SegmentedButton<ItemMode>>(
          find.byKey(const Key("item-mode-switch")),
        )
        .onSelectionChanged!({ItemMode.generic});
    await tester.pumpAndSettle();
    expect(find.text("安全轉為非專用"), findsOneWidget);

    container
        .read(itemWorkspaceProvider.notifier)
        .putClass(sourceClass.copyWith(description: "協作者剛更新的說明"));
    await tester.pump();
    await tester.tap(find.byKey(const Key("item-demotion-confirm")));
    await tester.pumpAndSettle();

    final workspace = container.read(itemWorkspaceProvider);
    expect(workspace.itemClasses, hasLength(1));
    expect(workspace.itemClasses["tools"]?.description, "協作者剛更新的說明");
    expect(workspace.itemClasses["tools"]?.archived, isFalse);
    expect(workspace.itemInstances["hammer"]?.archived, isFalse);
    expect(workspace.itemClassStateChanges, isEmpty);
    expect(workspace.itemInstanceStateChanges, isEmpty);
    expect(find.text("物品或 Scene 已更新，請重新開啟預覽後再提交。"), findsOneWidget);
  });
}
