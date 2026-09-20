import "dart:io";
import "dart:ui";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter/scheduler.dart";
import "package:flutter_test/flutter_test.dart";
import "package:integration_test/integration_test.dart";
import "package:monogatari_assistant/models/outline_data.dart";
import "package:monogatari_assistant/models/timeline_data.dart";
import "package:monogatari_assistant/modules/itemview.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";
import "package:window_manager/window_manager.dart";

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("desktop and narrow item workflow remains responsive", (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await windowManager.ensureInitialized();
    container.read(outlineDataProvider.notifier).setOutlineData([
      StorylineData(
        storylineName: "主線",
        scenes: [
          StoryEventData(
            storyEventUUID: "profile-event",
            storyEvent: "交付事件",
            scenes: [SceneData(sceneUUID: "profile-scene", sceneName: "交付場景")],
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
                placementUUID: "profile-placement",
                sceneUUID: "profile-scene",
                trackUUID: "timeline-track-default",
                startTick: 24,
              ),
            ],
          ),
          synchronizeOutline: false,
        );

    await windowManager.setSize(const Size(1200, 900));
    final rssBefore = ProcessInfo.currentRss;
    final frameTimings = <FrameTiming>[];
    void collectFrameTimings(List<FrameTiming> timings) {
      frameTimings.addAll(timings);
    }

    SchedulerBinding.instance.addTimingsCallback(collectFrameTimings);
    addTearDown(
      () =>
          SchedulerBinding.instance.removeTimingsCallback(collectFrameTimings),
    );
    final workflow = Stopwatch()..start();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ItemView()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key("item-add-class")));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key("item-mode-switch")), findsOneWidget);
    final classId = container
        .read(itemWorkspaceProvider)
        .itemClasses
        .keys
        .single;
    final nameField = find.byKey(ValueKey("item-name-$classId"));
    await tester.tap(nameField);
    await tester.enterText(nameField, "驗收物品");
    // Flutter Driver's Windows text channel does not dispatch TextFormField
    // onChanged in profile mode. The ordinary widget test covers that path.
    tester.widget<TextFormField>(nameField).onChanged!("驗收物品");
    await tester.pumpAndSettle();
    expect(
      container.read(itemWorkspaceProvider).itemClasses[classId]?.name,
      "驗收物品",
    );

    await tester.tap(find.byKey(const Key("item-add-snapshot")));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, "狀態"), "已交付");
    await tester.tap(find.widgetWithText(FilledButton, "新增快照"));
    await tester.pumpAndSettle();
    expect(
      container.read(itemWorkspaceProvider).itemClassStateChanges,
      hasLength(1),
    );

    await tester.tap(find.text("半專用").last);
    await tester.pumpAndSettle();
    final addInstance = find.byKey(const Key("item-add-instance"));
    await tester.scrollUntilVisible(
      addInstance,
      400,
      scrollable: find.byType(Scrollable).last,
    );
    tester.widget<FilledButton>(addInstance).onPressed!();
    await tester.pumpAndSettle();
    expect(find.textContaining("ID："), findsNWidgets(2));

    final addRelation = find.byKey(const Key("item-add-relation"));
    await tester.scrollUntilVisible(
      addRelation,
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(addRelation);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("item-relation-target")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("交付事件").last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, "關係／用途"), "交付物");
    await tester.tap(find.byKey(const Key("item-relation-confirm")));
    await tester.pumpAndSettle();
    expect(container.read(itemWorkspaceProvider).itemRelations, hasLength(1));

    await windowManager.setSize(const Size(600, 900));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key("item-narrow-sections")), findsOneWidget);
    expect(find.text("物品清單"), findsOneWidget);
    expect(find.text("搜尋物品"), findsOneWidget);
    await tester.tap(find.widgetWithText(TextField, "搜尋物品"));
    await tester.enterText(find.widgetWithText(TextField, "搜尋物品"), "驗收");
    await tester.pumpAndSettle();
    expect(find.text("驗收物品"), findsOneWidget);

    workflow.stop();
    await tester.pump();
    final rssAfter = ProcessInfo.currentRss;
    final buildMicros = [
      for (final timing in frameTimings) timing.buildDuration.inMicroseconds,
    ]..sort();
    final rasterMicros = [
      for (final timing in frameTimings) timing.rasterDuration.inMicroseconds,
    ]..sort();
    final buildP95 = _percentile95(buildMicros);
    final rasterP95 = _percentile95(rasterMicros);
    expect(frameTimings, isNotEmpty);
    // P0 did not define a product frame budget. Keep a broad regression guard
    // against visible half-second stalls and report the measured baseline.
    expect(buildP95, lessThan(500000));
    expect(rasterP95, lessThan(500000));
    binding.reportData = {
      ...?binding.reportData,
      "itemWorkflowElapsedMicros": workflow.elapsedMicroseconds,
      "frameCount": frameTimings.length,
      "buildP95Micros": buildP95,
      "rasterP95Micros": rasterP95,
      "rssBeforeBytes": rssBefore,
      "rssAfterBytes": rssAfter,
      "maxRssBytes": ProcessInfo.maxRss,
      "desktopLogicalSize": "1200x900",
      "narrowLogicalSize": "600x900",
    };
    // ignore: avoid_print
    print(
      "item profile workflow: ${workflow.elapsedMilliseconds}ms; "
      "frames=${frameTimings.length}; buildP95=${buildP95}us; "
      "rasterP95=${rasterP95}us; rss=${rssBefore ~/ 1048576}->"
      "${rssAfter ~/ 1048576}MiB; maxRss=${ProcessInfo.maxRss ~/ 1048576}MiB",
    );
  });
}

int _percentile95(List<int> sortedValues) {
  if (sortedValues.isEmpty) return 0;
  final index = ((sortedValues.length - 1) * 0.95).ceil();
  return sortedValues[index];
}
