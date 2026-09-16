import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/models/character_data.dart";
import "package:monogatari_assistant/models/item_data.dart";
import "package:monogatari_assistant/models/item_snapshot_data.dart";
import "package:monogatari_assistant/models/outline_data.dart";
import "package:monogatari_assistant/models/world_settings_data.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";
import "package:monogatari_assistant/presentation/widgets/project_object_selector.dart";

void main() {
  testWidgets("object selector searches every supported project object", (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(characterDataProvider.notifier).setCharacterData({
      "hero": const CharacterEntryData(
        characterId: "hero",
        displayName: "勇者",
        roleOrOccupation: "冒險者",
      ),
    });
    container.read(worldSettingsDataProvider.notifier).setWorldSettingsData([
      LocationData(id: "castle", localName: "王城"),
    ]);
    container.read(outlineDataProvider.notifier).setOutlineData([
      StorylineData(
        storylineName: "主線",
        scenes: [
          StoryEventData(
            storyEventUUID: "battle",
            storyEvent: "決戰",
            scenes: [SceneData(sceneUUID: "gate", sceneName: "城門")],
          ),
        ],
      ),
    ]);
    container
        .read(itemWorkspaceProvider.notifier)
        .setWorkspace(
          ItemWorkspaceData(
            itemClasses: {
              "sword": ItemClassData(
                classId: "sword",
                name: "聖劍",
                mode: ItemMode.semiDedicated,
              ),
            },
            itemInstances: {
              "sword-1": ItemInstanceData(
                instanceId: "sword-1",
                classId: "sword",
                name: "初代聖劍",
                defaultState: ItemStatePatch(
                  holderCharacterId: const StateValue.set("hero"),
                ),
              ),
            },
          ),
        );

    ProjectObjectSelection? selected;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                key: const Key("open-selector"),
                onPressed: () async {
                  selected = await showProjectObjectSelector(
                    context: context,
                    allowedKinds: ProjectObjectKind.values.toSet(),
                  );
                },
                child: const Text("選擇"),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key("open-selector")));
    await tester.pumpAndSettle();
    expect(find.text("聖劍"), findsOneWidget);
    expect(find.text("初代聖劍"), findsOneWidget);
    expect(find.textContaining("半專用"), findsWidgets);
    expect(find.textContaining("持有人：勇者"), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key("project-object-selector-search")),
      "決戰",
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey("project-object-event-battle")),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey("project-object-scene-gate")),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key("project-object-selector-search")),
      "初代",
    );
    await tester.pump();
    expect(find.text("初代聖劍"), findsOneWidget);
    expect(find.text("勇者"), findsNothing);
    await tester.tap(find.text("初代聖劍"));
    await tester.pumpAndSettle();

    expect(selected?.kind, ProjectObjectKind.itemInstance);
    expect(selected?.id, "sword-1");
    expect(selected?.classId, "sword");
  });

  testWidgets("object selector excludes already linked objects", (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(itemWorkspaceProvider.notifier)
        .putClass(ItemClassData(classId: "coin", name: "銀幣"));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showProjectObjectSelector(
                  context: context,
                  allowedKinds: const {ProjectObjectKind.itemClass},
                  excludedKeys: const {"itemClass:coin"},
                ),
                child: const Text("選擇"),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text("選擇"));
    await tester.pumpAndSettle();
    expect(find.text("銀幣"), findsNothing);
    expect(find.text("沒有符合條件的物件。"), findsOneWidget);
  });
}
