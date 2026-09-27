import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/modules/outlineview.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  Future<ProviderContainer> openOutline(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 3500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(outlineDataProvider.notifier).setOutlineData([
      StorylineData(
        chapterUUID: "first",
        storylineName: "第一大箱",
        scenes: [
          StoryEventData(
            storyEventUUID: "event",
            storyEvent: "第一中箱",
            scenes: [SceneData(sceneUUID: "scene", sceneName: "第一小箱")],
          ),
        ],
      ),
      StorylineData(chapterUUID: "second", storylineName: "第二大箱"),
    ]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OutlineAdjustView()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets("draft commits edited fields at all three outline levels", (
    tester,
  ) async {
    final container = await openOutline(tester);
    await tester.enterText(field("故事線名稱"), "修正大箱");
    await tester.enterText(field("類型 (如：開頭、中段、高潮、結尾)"), "承");
    await tester.enterText(field("主要衝突"), "大箱衝突");
    await tester.enterText(field("事件名稱"), "修正中箱");
    await tester.enterText(field("場景名稱"), "修正小箱");
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    final box = container.read(outlineDataProvider).first;
    expect(box.storylineName, "修正大箱");
    expect(box.storylineType, "承");
    expect(box.conflictPoint, "大箱衝突");
    expect(box.scenes.single.storyEvent, "修正中箱");
    expect(box.scenes.single.scenes.single.sceneName, "修正小箱");
    expect(find.text("承"), findsWidgets);
  });

  testWidgets("switching large boxes flushes a draft before the debounce", (
    tester,
  ) async {
    final container = await openOutline(tester);
    await tester.enterText(field("類型 (如：開頭、中段、高潮、結尾)"), "轉");
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text("第二大箱"),
          matching: find.byType(ListTile),
        ),
        matching: find.byIcon(Icons.library_books),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(outlineDataProvider).first.storylineType, "轉");
    expect(container.read(outlineDataProvider).last.storylineType, isEmpty);
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text("第一大箱"),
          matching: find.byType(ListTile),
        ),
        matching: find.byIcon(Icons.library_books),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(field("類型 (如：開頭、中段、高潮、結尾)")).controller!.text,
      "轉",
    );
  });
}
