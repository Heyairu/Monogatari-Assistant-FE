import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/modules/outlineview.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("OutlineAdjustView edits storyline and syncs provider", (tester) async {
    final container = ProviderContainer();

    container.read(outlineDataProvider.notifier).state = [
      StorylineData(
        storylineName: "主線",
        chapterUUID: "sl-1",
        scenes: [
          StoryEventData(
            storyEvent: "事件1",
            storyEventUUID: "ev-1",
            scenes: [
              SceneData(sceneName: "場景1", sceneUUID: "sc-1"),
            ],
          ),
        ],
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        parent: container,
        child: MaterialApp(
          home: Scaffold(
            body: OutlineAdjustView(
              onStorylineChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text("大綱調整"), findsOneWidget);

    final nameField = find.widgetWithText(TextField, "主線").first;
    await tester.enterText(nameField, "主線-更新");
    await tester.pumpAndSettle();

    expect(container.read(outlineDataProvider).first.storylineName, "主線-更新");
  });
}
