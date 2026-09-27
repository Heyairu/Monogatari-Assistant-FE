import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/models/outline_data.dart";
import "package:monogatari_assistant/presentation/widgets/scene_range_view.dart";

void main() {
  test("merges adjacent types and counts every descendant box", () {
    final segments = buildSceneRangeSegments([
      StorylineData(
        storylineType: "起",
        scenes: [
          StoryEventData(scenes: [SceneData(), SceneData()]),
          StoryEventData(),
        ],
      ),
      StorylineData(storylineType: "起"),
      StorylineData(storylineType: "承"),
      StorylineData(storylineType: "起"),
    ]);
    expect(segments.map((s) => s.name), ["起", "承", "起"]);
    expect(segments.map((s) => s.count), [2, 1, 1]);
    expect(segments.map((s) => s.firstBox), [1, 3, 4]);
    expect(segments.map((s) => s.weight), [6, 1, 1]);
    expect(buildSceneRangeSegments([]), isEmpty);
  });

  testWidgets("widths use weights and hover shows the large-box type", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SceneRangeView(
            storylines: [
              StorylineData(storylineType: "起", scenes: [StoryEventData()]),
              StorylineData(storylineType: "承"),
              StorylineData(storylineType: "起"),
            ],
          ),
        ),
      ),
    );
    final first = find.byKey(const ValueKey("scene-range-segment-0"));
    final second = find.byKey(const ValueKey("scene-range-segment-1"));
    expect(
      tester.getSize(first).width,
      closeTo(tester.getSize(second).width * 2, .01),
    );
    expect(find.textContaining("75.0%"), findsOneWidget);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(first));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text("起"), findsOneWidget);
    await mouse.removePointer();
  });

  testWidgets("empty and unset types render without errors", (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SceneRangeView(storylines: [])),
      ),
    );
    expect(find.text("新增大箱後，會在這裡顯示場次範圍。"), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SceneRangeView(storylines: [StorylineData()])),
      ),
    );
    expect(find.byTooltip("未設定類型"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
