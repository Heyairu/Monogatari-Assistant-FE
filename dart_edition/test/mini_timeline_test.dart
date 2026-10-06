import "package:flutter/material.dart";
import "package:flutter/semantics.dart";
import "package:flutter/services.dart";
import "package:flutter/gestures.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/models/timeline_data.dart";
import "package:monogatari_assistant/presentation/widgets/timeline_mini_view.dart";
import "package:monogatari_assistant/ui_library/mini_timeline.dart";

const canvasKey = ValueKey("test-timeline-canvas");

Widget host(
  Widget child, {
  double width = 400,
  double scale = 1,
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: brightness,
    ),
  ),
  home: Scaffold(
    body: Center(
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);

void main() {
  testWidgets("nearby markers have distinct hit regions", (tester) async {
    final selected = <int>[];
    await tester.pumpWidget(
      host(
        MiniTimeline(
          canvasKey: canvasKey,
          currentTick: 0,
          minTick: 0,
          maxTick: 100,
          markers: const [
            MiniTimelineMarker(id: "a", tick: 50),
            MiniTimelineMarker(id: "b", tick: 51),
          ],
          onTickChanged: selected.add,
        ),
      ),
    );
    final rect = tester.getRect(find.byKey(canvasKey));
    await tester.tapAt(
      Offset(rect.left + 16 + (rect.width - 32) * .5, rect.top + 18),
    );
    await tester.tapAt(
      Offset(rect.left + 16 + (rect.width - 32) * .51, rect.top + 18),
    );
    expect(selected, [50, 51]);
  });

  testWidgets("clicks clamp at viewport ends and keyboard steps the cursor", (
    tester,
  ) async {
    var tick = 0;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => MiniTimeline(
            canvasKey: canvasKey,
            currentTick: tick,
            minTick: -10,
            maxTick: 10,
            onTickChanged: (value) => setState(() => tick = value),
          ),
        ),
      ),
    );
    final rect = tester.getRect(find.byKey(canvasKey));
    await tester.tapAt(Offset(rect.left + 2, rect.center.dy));
    await tester.pump();
    expect(tick, -10);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(tick, -9);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(tick, 10);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(tick, 10);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(tick, -10);
    await tester.tapAt(Offset(rect.right - 2, rect.center.dy));
    await tester.pump();
    expect(tick, 10);
  });

  testWidgets(
    "scrubber follows pointer immediately and stays still when held",
    (tester) async {
      var tick = 0;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) => MiniTimeline(
              canvasKey: canvasKey,
              currentTick: tick,
              minTick: tick - 10,
              maxTick: tick + 10,
              pixelsPerTick: 40,
              onTickChanged: (value) => setState(() => tick = value),
            ),
          ),
        ),
      );
      final handle = find.byKey(const ValueKey("mini-timeline-scrubber"));
      final origin = tester.getCenter(handle);
      final gesture = await tester.startGesture(origin);
      await gesture.moveTo(origin + const Offset(48, 0));
      expect(tick, 1);
      await tester.pump();
      expect(tester.getCenter(handle).dx, closeTo(origin.dx + 48, .01));
      await gesture.moveTo(origin + const Offset(58, 0));
      expect(tick, 1);
      await tester.pump();
      expect(tester.getCenter(handle).dx, closeTo(origin.dx + 58, .01));
      await gesture.moveTo(origin + const Offset(80, 0));
      expect(tick, 2);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tick, 2);
      await gesture.moveTo(origin + const Offset(-80, 0));
      expect(tick, -2);
      await gesture.moveTo(origin + const Offset(800, 0));
      expect(tick, 10);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tick, 10);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("coincident snapshot markers select an exact Tick once", (
    tester,
  ) async {
    final selected = <int>[];
    final tapped = <String>[];
    await tester.pumpWidget(
      host(
        MiniTimeline(
          canvasKey: canvasKey,
          currentTick: 0,
          minTick: 0,
          maxTick: 10,
          markers: const [
            MiniTimelineMarker(id: "a", tick: 5, label: "快照 A"),
            MiniTimelineMarker(id: "b", tick: 5, label: "快照 B"),
            MiniTimelineMarker(id: "outside", tick: 20, label: "範圍外"),
          ],
          onTickChanged: selected.add,
          onMarkerTap: (marker) => tapped.add(marker.id),
        ),
      ),
    );
    final rect = tester.getRect(find.byKey(canvasKey));
    await tester.tapAt(Offset(rect.center.dx, rect.top + 18));
    expect(selected, [5]);
    expect(tapped, ["a"]);
    expect(find.byTooltip("快照 A · Tick 5\n快照 B · Tick 5"), findsOneWidget);
    expect(find.byTooltip("範圍外 · Tick 20"), findsNothing);
  });

  testWidgets(
    "overlapping placements do not cover each other and rows scroll",
    (tester) async {
      await tester.pumpWidget(
        host(
          TimelineMiniView(
            placements: [
              for (var i = 0; i < 6; i++)
                TimelinePlacementData(
                  placementUUID: "$i",
                  trackUUID: "main",
                  label: "Scene $i",
                  startTick: 0,
                  durationTicks: 5,
                ),
              const TimelinePlacementData(
                placementUUID: "next",
                trackUUID: "main",
                label: "接續",
                startTick: 5,
                durationTicks: 2,
              ),
            ],
            currentTick: 1,
            minTick: 0,
            maxTick: 10,
          ),
        ),
      );
      final first = find.byTooltip("Scene 0 · Tick 0–4");
      final second = find.byTooltip("Scene 1 · Tick 0–4");
      final next = find.byTooltip("接續 · Tick 5–6");
      expect(
        tester.getTopLeft(second).dy,
        greaterThan(tester.getBottomLeft(first).dy),
      );
      expect(tester.getTopLeft(next).dy, tester.getTopLeft(first).dy);
      final before = tester.getTopLeft(find.byTooltip("Scene 5 · Tick 0–4")).dy;
      await tester.drag(
        find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.vertical,
        ),
        const Offset(0, -80),
      );
      await tester.pumpAndSettle();
      final after = tester.getTopLeft(find.byTooltip("Scene 5 · Tick 0–4")).dy;
      expect(after, lessThan(before));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    "horizontal scrolling leaves the cursor unchanged and node names appear on hover",
    (tester) async {
      final selected = <int>[];
      await tester.pumpWidget(
        host(
          TimelineMiniView(
            placements: const [
              TimelinePlacementData(
                placementUUID: "far",
                trackUUID: "main",
                label: "遠方場景",
                startTick: 40,
                durationTicks: 4,
              ),
            ],
            currentTick: 0,
            minTick: 0,
            maxTick: 50,
            onTickChanged: selected.add,
          ),
        ),
      );
      final scrollbar = tester.widget<Scrollbar>(
        find.byKey(const ValueKey("mini-timeline-horizontal-scrollbar")),
      );
      expect(scrollbar.thumbVisibility, isTrue);
      expect(scrollbar.trackVisibility, isTrue);
      expect(scrollbar.controller!.position.maxScrollExtent, greaterThan(0));
      await tester.drag(
        find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        ),
        const Offset(-240, 0),
      );
      await tester.pumpAndSettle();
      expect(scrollbar.controller!.offset, greaterThan(0));
      expect(selected, isEmpty);
      scrollbar.controller!.jumpTo(1700);
      await tester.pumpAndSettle();
      final node = find.byTooltip("遠方場景 · Tick 40–43");
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await mouse.moveTo(tester.getCenter(node));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text("遠方場景 · Tick 40–43"), findsOneWidget);
      await mouse.removePointer();
    },
  );

  testWidgets("cancelled and disposed drags stop updating", (tester) async {
    final selected = <int>[];
    await tester.pumpWidget(
      host(
        MiniTimeline(
          currentTick: 0,
          minTick: -10,
          maxTick: 10,
          onTickChanged: selected.add,
        ),
      ),
    );
    var handle = find.byKey(const ValueKey("mini-timeline-scrubber"));
    var gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(selected, isNotEmpty);
    await gesture.cancel();
    final count = selected.length;
    await tester.pump(const Duration(milliseconds: 500));
    expect(selected, hasLength(count));
    handle = find.byKey(const ValueKey("mini-timeline-scrubber"));
    gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pumpWidget(const SizedBox());
    await gesture.cancel();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets("drag coordinates compensate for horizontal scrolling", (
    tester,
  ) async {
    var tick = 10;
    final selected = <int>[];
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => MiniTimeline(
            currentTick: tick,
            minTick: 0,
            maxTick: 100,
            pixelsPerTick: 40,
            onTickChanged: (value) {
              selected.add(value);
              setState(() => tick = value);
            },
          ),
        ),
      ),
    );
    final handle = find.byKey(const ValueKey("mini-timeline-scrubber"));
    final origin = tester.getCenter(handle);
    final gesture = await tester.startGesture(origin);
    await gesture.moveTo(origin + const Offset(48, 0));
    await tester.pump();
    expect(tick, 11);
    final controller = tester
        .widget<Scrollbar>(
          find.byKey(const ValueKey("mini-timeline-horizontal-scrollbar")),
        )
        .controller!;
    controller.jumpTo(controller.offset + 40);
    await tester.pump();
    await gesture.moveTo(origin + const Offset(52, 0));
    await tester.pump();
    expect(tick, 12);
    expect(tester.getCenter(handle).dx, closeTo(origin.dx + 52, .01));
    await gesture.moveTo(origin + const Offset(54, 0));
    await tester.pump();
    expect(selected, [11, 12]);
    expect(tester.getCenter(handle).dx, closeTo(origin.dx + 54, .01));
    await gesture.up();
  });

  testWidgets(
    "offscreen intervals are clipped instead of becoming edge nodes",
    (tester) async {
      await tester.pumpWidget(
        host(
          const MiniTimeline(
            currentTick: 5,
            minTick: 0,
            maxTick: 10,
            intervals: [
              MiniTimelineInterval(
                id: "left",
                label: "左側",
                startTick: -10,
                endTick: 0,
              ),
              MiniTimelineInterval(
                id: "right",
                label: "右側",
                startTick: 10,
                endTick: 20,
              ),
              MiniTimelineInterval(
                id: "cross",
                label: "跨界",
                startTick: -5,
                endTick: 15,
              ),
            ],
          ),
        ),
      );
      expect(find.byTooltip("左側 · Tick -10–-1"), findsNothing);
      expect(find.byTooltip("右側 · Tick 10–19"), findsNothing);
      final interval = find.byTooltip("跨界 · Tick -5–14");
      expect(interval, findsOneWidget);
      expect(tester.getSize(interval).width, lessThanOrEqualTo(400));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("narrow, scaled and huge Tick windows render in both themes", (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        host(
          const MiniTimeline(
            currentTick: timelineMaximumTick,
            minTick: timelineMinimumTick,
            maxTick: timelineMaximumTick,
            markers: [MiniTimelineMarker(id: "origin", tick: 0)],
            intervals: [
              MiniTimelineInterval(id: "tiny", startTick: -1, endTick: 1),
            ],
          ),
          width: 96,
          scale: 3,
          brightness: brightness,
        ),
      );
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(
      host(const Row(children: [MiniTimeline(currentTick: 0)])),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(host(const MiniTimeline(currentTick: 0), width: 0));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    "screen reader steps stop at bounds and readonly has no slider actions",
    (tester) async {
      final semantics = tester.ensureSemantics();
      var tick = 0;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) => MiniTimeline(
              currentTick: tick,
              minTick: 0,
              maxTick: 1,
              onTickChanged: (value) => setState(() => tick = value),
            ),
          ),
        ),
      );
      var node = tester.getSemantics(find.bySemanticsLabel("微型時間軸"));
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.increase),
        isTrue,
      );
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.decrease),
        isFalse,
      );
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          viewId: tester.view.viewId,
          nodeId: node.id,
          type: SemanticsAction.increase,
        ),
      );
      await tester.pump();
      expect(tick, 1);
      node = tester.getSemantics(find.bySemanticsLabel("微型時間軸"));
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.increase),
        isFalse,
      );
      await tester.pumpWidget(host(const MiniTimeline(currentTick: 0)));
      node = tester.getSemantics(find.bySemanticsLabel("微型時間軸"));
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.increase),
        isFalse,
      );
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.decrease),
        isFalse,
      );
      semantics.dispose();
    },
  );
}
