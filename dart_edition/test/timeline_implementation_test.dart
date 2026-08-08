import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/file.dart";
import "package:monogatari_assistant/models/chapter_selection_data.dart";
import "package:monogatari_assistant/models/codecs/timeline_codec.dart";
import "package:monogatari_assistant/models/outline_data.dart";
import "package:monogatari_assistant/models/timeline_data.dart";
import "package:monogatari_assistant/modules/timelineview.dart";
import "package:monogatari_assistant/presentation/providers/editor_coordinator_provider.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";
import "package:monogatari_assistant/presentation/providers/timeline_providers.dart";
import "package:xml/xml.dart" as xml;

void main() {
  group("Timeline operations", () {
    test("new middle and small boxes create matching outline nodes", () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(outlineDataProvider.notifier)
          .setOutlineData(const <StorylineData>[]);
      final actions = container.read(timelineActionsProvider);
      actions.updateGrid(
        const TimelineGridConfig(
          ticksPerSmallBox: 3,
          ticksPerMiddleBox: 4,
          middleBoxesPerLargeBox: 6,
        ),
      );
      final large = actions.addPlacement(
        level: TimelineElementLevel.large,
        label: "第一幕",
        startTick: 30,
      );
      final outlineAfterLarge = container.read(outlineDataProvider);
      expect(outlineAfterLarge, hasLength(1));
      expect(outlineAfterLarge.single.storylineName, "第一幕");
      expect(large.storylineUUID, outlineAfterLarge.single.chapterUUID);
      final middle = actions.addPlacement(
        level: TimelineElementLevel.middle,
        parentPlacementUUID: large.placementUUID,
        label: "衝突開始",
        startTick: 31,
      );
      final small = actions.addPlacement(
        level: TimelineElementLevel.small,
        parentPlacementUUID: middle.placementUUID,
        label: "主角抵達",
        startTick: 32,
      );

      final outline = container.read(outlineDataProvider);
      expect(outline, hasLength(1));
      expect(outline.single.storylineName, "第一幕");
      expect(outline.single.scenes, hasLength(1));
      expect(outline.single.scenes.single.storyEvent, "衝突開始");
      expect(outline.single.scenes.single.scenes, hasLength(1));
      expect(outline.single.scenes.single.scenes.single.sceneName, "主角抵達");

      final placements = container.read(timelineDocumentProvider).placements;
      final linkedLarge = placements.singleWhere(
        (placement) => placement.placementUUID == large.placementUUID,
      );
      final linkedMiddle = placements.singleWhere(
        (placement) => placement.placementUUID == middle.placementUUID,
      );
      final linkedSmall = placements.singleWhere(
        (placement) => placement.placementUUID == small.placementUUID,
      );
      expect(linkedLarge.storylineUUID, outline.single.chapterUUID);
      expect(
        linkedMiddle.eventUUID,
        outline.single.scenes.single.storyEventUUID,
      );
      expect(
        linkedSmall.sceneUUID,
        outline.single.scenes.single.scenes.single.sceneUUID,
      );
      expect(linkedLarge.durationTicks, 72);
      expect(linkedMiddle.durationTicks, 12);
      expect(linkedSmall.durationTicks, 3);
      expect(linkedLarge.startTick, 30);
      expect(linkedMiddle.startTick, 31);
      expect(linkedSmall.startTick, 32);
    });

    test("Tick and placement mutations are clamped to the safe range", () {
      final created = TimelinePlacementData.create(
        level: TimelineElementLevel.small,
        trackUUID: "track",
        startTick: timelineMaximumTick,
        durationTicks: timelineMaximumTick,
      );
      expect(created.startTick, timelineMaximumNodeTick);
      expect(created.durationTicks, 1);
      expect(created.endTick, timelineMaximumTick);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final view = container.read(timelineViewProvider.notifier);
      view.setCurrentTick(timelineMaximumTick + 1000);
      expect(
        container.read(timelineViewProvider).currentTick,
        timelineMaximumTick,
      );
      view.setCurrentTick(timelineMinimumTick - 1000);
      expect(
        container.read(timelineViewProvider).currentTick,
        timelineMinimumTick,
      );

      final actions = container.read(timelineActionsProvider);
      final placement = actions.addPlacement(
        level: TimelineElementLevel.large,
        label: "邊界節點",
        startTick: timelineMaximumTick,
      );
      expect(placement.startTick, timelineMaximumNodeTick);
      expect(placement.endTick, timelineMaximumTick);

      actions.updatePlacement(
        placement.placementUUID,
        startTick: timelineMinimumTick - 1000,
        durationTicks: timelineMaximumTick * 4,
      );
      var updated = container
          .read(timelineDocumentProvider)
          .placements
          .singleWhere((item) => item.placementUUID == placement.placementUUID);
      expect(updated.startTick, timelineMinimumTick);
      expect(updated.endTick, timelineMaximumTick);

      actions.resizePlacement(
        placement.placementUUID,
        startTick: timelineMaximumTick + 1000,
      );
      updated = container
          .read(timelineDocumentProvider)
          .placements
          .singleWhere((item) => item.placementUUID == placement.placementUUID);
      expect(updated.startTick, timelineMaximumNodeTick);
      expect(updated.durationTicks, 1);
      expect(updated.endTick, timelineMaximumTick);

      container
          .read(timelineDocumentProvider.notifier)
          .setDocument(
            const TimelineDocumentData(
              tracks: [TimelineTrackData(trackUUID: "track", name: "主線")],
              placements: [
                TimelinePlacementData(
                  placementUUID: "external-overflow",
                  trackUUID: "track",
                  startTick: timelineMaximumTick + 999,
                  durationTicks: timelineMaximumTick * 99,
                ),
              ],
            ),
          );
      final normalized = container
          .read(timelineDocumentProvider)
          .placements
          .single;
      expect(normalized.startTick, timelineMaximumNodeTick);
      expect(normalized.durationTicks, 1);
      expect(normalized.endTick, timelineMaximumTick);
    });

    test("outline large-box deletion removes only its timeline subtree", () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final actions = container.read(timelineActionsProvider);
      final removedLarge = actions.addPlacement(
        level: TimelineElementLevel.large,
        label: "待刪大箱",
      );
      final removedMiddle = actions.addPlacement(
        level: TimelineElementLevel.middle,
        parentPlacementUUID: removedLarge.placementUUID,
        label: "待刪中箱",
      );
      final removedSmall = actions.addPlacement(
        level: TimelineElementLevel.small,
        parentPlacementUUID: removedMiddle.placementUUID,
        label: "待刪小箱",
      );
      final keptLarge = actions.addPlacement(
        level: TimelineElementLevel.large,
        label: "保留大箱",
      );

      container
          .read(outlineDataProvider.notifier)
          .updateOutlineData(
            (outline) => outline
                .where(
                  (storyline) =>
                      storyline.chapterUUID != removedLarge.storylineUUID,
                )
                .toList(growable: false),
          );
      actions.removeStorylinePlacements(removedLarge.storylineUUID!);

      final placements = container.read(timelineDocumentProvider).placements;
      expect(
        placements.map((placement) => placement.placementUUID),
        isNot(contains(removedLarge.placementUUID)),
      );
      expect(
        placements.map((placement) => placement.placementUUID),
        isNot(contains(removedMiddle.placementUUID)),
      );
      expect(
        placements.map((placement) => placement.placementUUID),
        isNot(contains(removedSmall.placementUUID)),
      );
      expect(
        placements.map((placement) => placement.placementUUID),
        contains(keptLarge.placementUUID),
      );
    });

    test("timeline deletion does not delete its outline large box", () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final actions = container.read(timelineActionsProvider);
      final large = actions.addPlacement(
        level: TimelineElementLevel.large,
        label: "只刪時間軸",
      );
      final storylineUUID = large.storylineUUID!;

      actions.removePlacement(large.placementUUID);

      expect(container.read(timelineDocumentProvider).placements, isEmpty);
      expect(
        container
            .read(outlineDataProvider)
            .map((storyline) => storyline.chapterUUID),
        contains(storylineUUID),
      );
    });

    test("automatic ordering synchronizes timeline and outline both ways", () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final first = StorylineData(storylineName: "先寫的大箱");
      final second = StorylineData(storylineName: "後寫的大箱");
      container.read(outlineDataProvider.notifier).setOutlineData([
        first,
        second,
      ]);
      final seeded = TimelineOutlineMapper.seedFromOutline(
        TimelineDocumentData.initial(),
        [first, second],
      );
      final firstPlacement = seeded.placements.singleWhere(
        (placement) => placement.storylineUUID == first.chapterUUID,
      );
      final secondPlacement = seeded.placements.singleWhere(
        (placement) => placement.storylineUUID == second.chapterUUID,
      );
      final reversedTimeline = seeded.copyWith(
        placements: [
          for (final placement in seeded.placements)
            if (placement.placementUUID == firstPlacement.placementUUID)
              placement.copyWith(startTick: 24)
            else if (placement.placementUUID == secondPlacement.placementUUID)
              placement.copyWith(startTick: 0)
            else
              placement,
        ],
      );
      container
          .read(timelineDocumentProvider.notifier)
          .setDocument(reversedTimeline);

      container
          .read(timelineActionsProvider)
          .updateGrid(reversedTimeline.grid.copyWith(autoSortOutline: true));
      expect(
        container.read(outlineDataProvider).map((item) => item.chapterUUID),
        [second.chapterUUID, first.chapterUUID],
      );

      container.read(outlineDataProvider.notifier).setOutlineData([
        first,
        second,
      ]);
      final aligned = container.read(timelineDocumentProvider);
      final alignedFirst = aligned.placements.singleWhere(
        (placement) => placement.storylineUUID == first.chapterUUID,
      );
      final alignedSecond = aligned.placements.singleWhere(
        (placement) => placement.storylineUUID == second.chapterUUID,
      );
      expect(alignedFirst.startTick, lessThan(alignedSecond.startTick));
    });

    test("child edits extend ancestors and parent moves preserve offsets", () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final actions = container.read(timelineActionsProvider);

      final large = actions.addPlacement(
        level: TimelineElementLevel.large,
        label: "第一幕",
      );
      final middle = actions.addPlacement(
        level: TimelineElementLevel.middle,
        parentPlacementUUID: large.placementUUID,
        label: "第一段",
      );
      final small = actions.addPlacement(
        level: TimelineElementLevel.small,
        parentPlacementUUID: middle.placementUUID,
        label: "場景 A",
      );

      actions.updatePlacement(
        small.placementUUID,
        startTick: -3,
        durationTicks: 2,
      );
      var document = container.read(timelineDocumentProvider);
      TimelinePlacementData find(String id) => document.placements.singleWhere(
        (placement) => placement.placementUUID == id,
      );

      expect(find(middle.placementUUID).startTick, lessThanOrEqualTo(-3));
      expect(find(middle.placementUUID).endTick, greaterThanOrEqualTo(-1));
      expect(find(large.placementUUID).startTick, lessThanOrEqualTo(-3));
      expect(find(large.placementUUID).endTick, greaterThanOrEqualTo(-1));

      final middleBefore = find(middle.placementUUID);
      final smallBefore = find(small.placementUUID);
      actions.updatePlacement(
        middle.placementUUID,
        startTick: middleBefore.startTick + 7,
      );
      document = container.read(timelineDocumentProvider);
      expect(find(small.placementUUID).startTick - smallBefore.startTick, 7);
    });

    test("new large, middle and small boxes are split when overlapping", () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final actions = container.read(timelineActionsProvider);
      final lowerTrack = actions.addTrack("下方空軌道");

      final firstLarge = actions.addPlacement(
        level: TimelineElementLevel.large,
        label: "第一幕",
        startTick: 0,
      );
      final secondLarge = actions.addPlacement(
        level: TimelineElementLevel.large,
        label: "第二幕",
        startTick: 1,
      );
      final firstMiddle = actions.addPlacement(
        level: TimelineElementLevel.middle,
        parentPlacementUUID: firstLarge.placementUUID,
        label: "第一段",
        startTick: 0,
      );
      final secondMiddle = actions.addPlacement(
        level: TimelineElementLevel.middle,
        parentPlacementUUID: firstLarge.placementUUID,
        label: "第二段",
        startTick: 1,
      );
      final firstSmall = actions.addPlacement(
        level: TimelineElementLevel.small,
        parentPlacementUUID: firstMiddle.placementUUID,
        label: "場景 A",
        startTick: 0,
      );
      final secondSmall = actions.addPlacement(
        level: TimelineElementLevel.small,
        parentPlacementUUID: firstMiddle.placementUUID,
        label: "場景 B",
        startTick: 0,
      );

      final document = container.read(timelineDocumentProvider);
      expect(document.tracks, hasLength(2));
      expect(secondLarge.trackUUID, lowerTrack.trackUUID);
      expect(secondMiddle.trackUUID, lowerTrack.trackUUID);

      for (final pair in [
        (firstLarge.placementUUID, secondLarge.placementUUID),
        (firstMiddle.placementUUID, secondMiddle.placementUUID),
        (firstSmall.placementUUID, secondSmall.placementUUID),
      ]) {
        final first = document.placements.singleWhere(
          (placement) => placement.placementUUID == pair.$1,
        );
        final second = document.placements.singleWhere(
          (placement) => placement.placementUUID == pair.$2,
        );
        final overlapsOnSameTrack =
            first.trackUUID == second.trackUUID &&
            first.startTick < second.endTick &&
            second.startTick < first.endTick;
        expect(overlapsOnSameTrack, isFalse);
      }
    });

    test("overlapping later elements are moved to a generated track", () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final actions = container.read(timelineActionsProvider);
      final first = actions.addPlacement(
        level: TimelineElementLevel.large,
        label: "第一幕",
      );
      final second = actions.addPlacement(
        level: TimelineElementLevel.large,
        label: "第二幕",
      );

      final result = actions.updatePlacement(
        second.placementUUID,
        startTick: first.startTick + 1,
      );
      final document = container.read(timelineDocumentProvider);
      final firstAfter = document.placements.singleWhere(
        (placement) => placement.placementUUID == first.placementUUID,
      );
      final secondAfter = document.placements.singleWhere(
        (placement) => placement.placementUUID == second.placementUUID,
      );

      expect(result.message, contains("自動移至新軌道"));
      expect(document.tracks, hasLength(2));
      expect(secondAfter.trackUUID, isNot(firstAfter.trackUUID));
      expect(secondAfter.startTick, first.startTick + 1);
    });

    test("overlap reuses a free lower track before creating one", () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final actions = container.read(timelineActionsProvider);
      final lowerTrack = actions.addTrack("備用軌道");
      final first = actions.addPlacement(
        level: TimelineElementLevel.large,
        label: "第一幕",
      );
      final second = actions.addPlacement(
        level: TimelineElementLevel.large,
        label: "第二幕",
      );

      final result = actions.updatePlacement(
        second.placementUUID,
        startTick: first.startTick + 1,
      );
      final document = container.read(timelineDocumentProvider);
      final secondAfter = document.placements.singleWhere(
        (placement) => placement.placementUUID == second.placementUUID,
      );

      expect(document.tracks, hasLength(2));
      expect(secondAfter.trackUUID, lowerTrack.trackUUID);
      expect(result.message, contains("下方既有軌道"));
    });

    test("overlap creates a track when every lower track is occupied", () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final actions = container.read(timelineActionsProvider);
      final first = actions.addPlacement(
        level: TimelineElementLevel.large,
        label: "第一幕",
      );
      final second = actions.addPlacement(
        level: TimelineElementLevel.large,
        label: "第二幕",
      );
      final blocker = actions.addPlacement(
        level: TimelineElementLevel.large,
        label: "下方既有章節",
      );
      final lowerTrack = actions.addTrack("已有內容的軌道");
      actions.updatePlacement(
        blocker.placementUUID,
        startTick: first.startTick + 1,
        trackUUID: lowerTrack.trackUUID,
      );

      final result = actions.updatePlacement(
        second.placementUUID,
        startTick: first.startTick + 1,
      );
      final document = container.read(timelineDocumentProvider);
      final secondAfter = document.placements.singleWhere(
        (placement) => placement.placementUUID == second.placementUUID,
      );

      expect(document.tracks, hasLength(3));
      expect(secondAfter.trackUUID, isNot(lowerTrack.trackUUID));
      expect(result.message, contains("新軌道"));
    });

    test("moving a parent to another track also moves descendants", () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final actions = container.read(timelineActionsProvider);
      final targetTrack = actions.addTrack("下方軌道");
      final large = actions.addPlacement(
        level: TimelineElementLevel.large,
        label: "第一幕",
      );
      final middle = actions.addPlacement(
        level: TimelineElementLevel.middle,
        parentPlacementUUID: large.placementUUID,
        label: "第一段",
      );

      actions.updatePlacement(
        large.placementUUID,
        trackUUID: targetTrack.trackUUID,
      );
      final placements = container.read(timelineDocumentProvider).placements;

      expect(
        placements
            .singleWhere(
              (placement) => placement.placementUUID == large.placementUUID,
            )
            .trackUUID,
        targetTrack.trackUUID,
      );
      expect(
        placements
            .singleWhere(
              (placement) => placement.placementUUID == middle.placementUUID,
            )
            .trackUUID,
        targetTrack.trackUUID,
      );
    });

    test("resize changes one boundary without translating descendants", () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final actions = container.read(timelineActionsProvider);
      final large = actions.addPlacement(
        level: TimelineElementLevel.large,
        label: "第一幕",
      );
      final middle = actions.addPlacement(
        level: TimelineElementLevel.middle,
        parentPlacementUUID: large.placementUUID,
        label: "第一段",
      );
      final small = actions.addPlacement(
        level: TimelineElementLevel.small,
        parentPlacementUUID: middle.placementUUID,
        label: "場景 A",
      );
      final originalSmallStart = small.startTick;

      actions.resizePlacement(large.placementUUID, startTick: -3);
      var document = container.read(timelineDocumentProvider);
      var resizedLarge = document.placements.singleWhere(
        (placement) => placement.placementUUID == large.placementUUID,
      );
      var resizedSmall = document.placements.singleWhere(
        (placement) => placement.placementUUID == small.placementUUID,
      );
      expect(resizedLarge.startTick, -3);
      expect(resizedLarge.endTick, large.endTick);
      expect(resizedSmall.startTick, originalSmallStart);

      actions.resizePlacement(large.placementUUID, endTick: 1);
      document = container.read(timelineDocumentProvider);
      resizedLarge = document.placements.singleWhere(
        (placement) => placement.placementUUID == large.placementUUID,
      );
      resizedSmall = document.placements.singleWhere(
        (placement) => placement.placementUUID == small.placementUUID,
      );
      expect(resizedLarge.endTick, greaterThanOrEqualTo(middle.endTick));
      expect(resizedSmall.startTick, originalSmallStart);

      final smallBeforeEndResize = resizedSmall;
      actions.resizePlacement(
        small.placementUUID,
        endTick: smallBeforeEndResize.endTick + 3,
      );
      document = container.read(timelineDocumentProvider);
      resizedSmall = document.placements.singleWhere(
        (placement) => placement.placementUUID == small.placementUUID,
      );
      expect(resizedSmall.startTick, smallBeforeEndResize.startTick);
      expect(resizedSmall.endTick, smallBeforeEndResize.endTick + 3);
    });

    test("chapter links are UUID based and duplicate safe", () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final actions = container.read(timelineActionsProvider);

      actions.addChapterLink("scene-a", "chapter-a");
      actions.addChapterLink("scene-a", "chapter-a");
      actions.addChapterLink("scene-a", "chapter-b");

      final links = container.read(outlineChapterLinksProvider);
      expect(links, hasLength(2));
      expect(links.map((link) => link.chapterUUID), {"chapter-a", "chapter-b"});
    });

    test(
      "container chapter selection is applied to every descendant scene",
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        const document = TimelineDocumentData(
          tracks: [TimelineTrackData(trackUUID: "track", name: "時間軸 1")],
          placements: [
            TimelinePlacementData(
              placementUUID: "large",
              level: TimelineElementLevel.large,
              trackUUID: "track",
            ),
            TimelinePlacementData(
              placementUUID: "middle",
              parentPlacementUUID: "large",
              level: TimelineElementLevel.middle,
              trackUUID: "track",
            ),
            TimelinePlacementData(
              placementUUID: "small-a",
              sceneUUID: "scene-a",
              parentPlacementUUID: "middle",
              trackUUID: "track",
            ),
            TimelinePlacementData(
              placementUUID: "small-b",
              sceneUUID: "scene-b",
              parentPlacementUUID: "middle",
              trackUUID: "track",
            ),
          ],
        );
        container.read(timelineDocumentProvider.notifier).setDocument(document);
        final actions = container.read(timelineActionsProvider);
        actions.addChapterLink("scene-a", "chapter-old");
        actions.addChapterLink("scene-outside", "chapter-outside");

        expect(timelineSceneUUIDsForPlacement(document, "large"), {
          "scene-a",
          "scene-b",
        });
        actions.setChapterLinksForPlacement("middle", {
          "chapter-a",
          "chapter-b",
        });

        var links = container.read(outlineChapterLinksProvider);
        for (final sceneUUID in ["scene-a", "scene-b"]) {
          expect(
            links
                .where((link) => link.sceneUUID == sceneUUID)
                .map((link) => link.chapterUUID),
            {"chapter-a", "chapter-b"},
          );
        }
        expect(
          links.any(
            (link) =>
                link.sceneUUID == "scene-outside" &&
                link.chapterUUID == "chapter-outside",
          ),
          isTrue,
        );

        actions.setChapterLinksForPlacement("large", {"chapter-b"});
        links = container.read(outlineChapterLinksProvider);
        expect(
          links
              .where((link) => {"scene-a", "scene-b"}.contains(link.sceneUUID))
              .map((link) => link.chapterUUID),
          everyElement("chapter-b"),
        );

        actions.removeChapterLinkFromPlacement("middle", "chapter-b");
        links = container.read(outlineChapterLinksProvider);
        expect(
          links.any((link) => {"scene-a", "scene-b"}.contains(link.sceneUUID)),
          isFalse,
        );
        expect(links.single.sceneUUID, "scene-outside");
      },
    );

    test(
      "chapter navigation flushes current provider content before switch",
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(segmentsDataProvider.notifier).setSegmentsData([
          SegmentData(
            segmentUUID: "folder",
            chapters: [
              ChapterData(
                chapterUUID: "chapter-a",
                chapterName: "A",
                chapterContent: "old",
              ),
              ChapterData(
                chapterUUID: "chapter-b",
                chapterName: "B",
                chapterContent: "target",
              ),
            ],
          ),
        ]);
        container
            .read(editorSelectionProvider.notifier)
            .setSelection(selectedSegID: "folder", selectedChapID: "chapter-a");
        container.read(editorContentProvider.notifier).setContent("draft");

        final opened = container
            .read(editorCoordinatorProvider.notifier)
            .navigateToChapter("chapter-b");

        expect(opened, isTrue);
        expect(
          container.read(editorSelectionProvider).selectedChapID,
          "chapter-b",
        );
        expect(container.read(editorContentProvider), "target");
        final stored = ChapterTree.findChapter(
          container.read(segmentsDataProvider),
          chapterId: "chapter-a",
        );
        expect(stored?.chapter.chapterContent, "draft");
      },
    );
  });

  test("timeline XML clamps nodes that exceed the safe range", () {
    final document = xml.XmlDocument.parse("""
<Type>
  <Name>Timeline</Name>
  <Timeline SchemaVersion="1">
    <Tracks>
      <Track UUID="track" Name="主線" />
    </Tracks>
    <Placements>
      <Placement UUID="overflow" TrackUUID="track" Level="small"
          StartTick="999999999" DurationTicks="999999999" />
    </Placements>
  </Timeline>
</Type>
""");

    final placement = TimelineCodec.loadElement(
      document.rootElement,
    )!.document.placements.single;
    expect(placement.startTick, timelineMaximumNodeTick);
    expect(placement.durationTicks, 1);
    expect(placement.endTick, timelineMaximumTick);
  });

  test(
    "project XML round-trips timeline grid, hierarchy, tracks and links",
    () {
      final scene = SceneData(
        sceneUUID: "scene-1",
        sceneName: "抵達港口",
        time: "第三天晚上",
      );
      final chapter = ChapterData(
        chapterUUID: "chapter-1",
        chapterName: "第一章",
        chapterContent: "內容",
      );
      const large = TimelinePlacementData(
        placementUUID: "large-1",
        level: TimelineElementLevel.large,
        trackUUID: "track-1",
        startTick: -4,
        durationTicks: 24,
        label: "第一幕",
      );
      const middle = TimelinePlacementData(
        placementUUID: "middle-1",
        parentPlacementUUID: "large-1",
        level: TimelineElementLevel.middle,
        trackUUID: "track-1",
        startTick: -2,
        durationTicks: 8,
        label: "港口段落",
      );
      const small = TimelinePlacementData(
        placementUUID: "small-1",
        parentPlacementUUID: "middle-1",
        sceneUUID: "scene-1",
        level: TimelineElementLevel.small,
        trackUUID: "track-1",
        startTick: 1,
        durationTicks: 2,
      );
      final data = ProjectData(
        baseInfoData: ProjectData.empty().baseInfoData,
        segmentsData: [
          SegmentData(
            segmentUUID: "folder-1",
            segmentName: "正文",
            chapters: [chapter],
          ),
        ],
        outlineData: [
          StorylineData(
            chapterUUID: "storyline-1",
            storylineName: "主線",
            scenes: [
              StoryEventData(
                storyEventUUID: "event-1",
                storyEvent: "抵達",
                scenes: [scene],
              ),
            ],
          ),
        ],
        foreshadowData: const [],
        updatePlanData: const [],
        worldSettingsData: const [],
        characterData: const {},
        timelineDocument: const TimelineDocumentData(
          grid: TimelineGridConfig(
            ticksPerLittleBox: TickDurationData(
              value: 15,
              unit: TickDurationUnit.minute,
            ),
            ticksPerSmallBox: 3,
            ticksPerMiddleBox: 4,
            middleBoxesPerLargeBox: 6,
            autoSortOutline: true,
            originLabel: "故事開場",
          ),
          tracks: [TimelineTrackData(trackUUID: "track-1", name: "主角線")],
          placements: [large, middle, small],
        ),
        outlineChapterLinks: const [
          OutlineChapterLinkData(
            linkUUID: "link-1",
            sceneUUID: "scene-1",
            chapterUUID: "chapter-1",
          ),
        ],
      );

      final xml = FileService.generateProjectXMLWithoutLatestSaveUpdate(data);
      final parsed = FileService.parseProjectXMLWithMetadata(xml).data;

      expect(parsed.timelineDocument.grid.ticksPerLittleBox.value, 15);
      expect(
        parsed.timelineDocument.grid.ticksPerLittleBox.unit,
        TickDurationUnit.minute,
      );
      expect(parsed.timelineDocument.grid.ticksPerSmallBox, 3);
      expect(parsed.timelineDocument.tracks.single.name, "主角線");
      expect(parsed.timelineDocument.grid.autoSortOutline, isTrue);
      expect(parsed.timelineDocument.placements, hasLength(3));
      expect(
        parsed.timelineDocument.placements
            .singleWhere((placement) => placement.placementUUID == "small-1")
            .parentPlacementUUID,
        "middle-1",
      );
      expect(parsed.outlineChapterLinks.single.sceneUUID, "scene-1");
      expect(parsed.outlineChapterLinks.single.chapterUUID, "chapter-1");
    },
  );

  test("1.09 outline is migrated to a complete timeline hierarchy", () {
    const oldXml = """
<?xml version="1.0" encoding="UTF-8"?>
<Project>
  <ver>1.09</ver>
  <Type>
    <Name>Outline</Name>
    <Storyline Name="主線" Type="Main" UUID="storyline-old">
      <Event Name="序幕" UUID="event-old">
        <Scene Name="相遇" UUID="scene-old">
          <Time>第一天</Time>
        </Scene>
      </Event>
    </Storyline>
  </Type>
</Project>
""";

    final parsed = FileService.parseProjectXMLWithMetadata(oldXml);
    final placements = parsed.data.timelineDocument.placements;
    final large = placements.singleWhere(
      (placement) => placement.level == TimelineElementLevel.large,
    );
    final middle = placements.singleWhere(
      (placement) => placement.level == TimelineElementLevel.middle,
    );
    final small = placements.singleWhere(
      (placement) => placement.level == TimelineElementLevel.small,
    );

    expect(parsed.wasMigrated, isTrue);
    expect(parsed.data.timelineDocument.grid.ticksPerSmallBox, 1);
    expect(large.storylineUUID, "storyline-old");
    expect(middle.storylineUUID, "storyline-old");
    expect(middle.eventUUID, "event-old");
    expect(middle.parentPlacementUUID, large.placementUUID);
    expect(small.sceneUUID, "scene-old");
    expect(small.eventUUID, "event-old");
    expect(small.parentPlacementUUID, middle.placementUUID);
    expect(large.startTick, lessThanOrEqualTo(middle.startTick));
    expect(large.endTick, greaterThanOrEqualTo(middle.endTick));
    expect(middle.startTick, lessThanOrEqualTo(small.startTick));
    expect(middle.endTick, greaterThanOrEqualTo(small.endTick));

    final saved = FileService.generateProjectXMLWithoutLatestSaveUpdate(
      parsed.data,
    );
    expect(saved, contains("<ver>1.12</ver>"));
    expect(saved, contains('TicksPerSmallBox="1"'));
    final reopened = FileService.parseProjectXMLWithMetadata(saved);
    expect(reopened.wasMigrated, isFalse);
    expect(reopened.data.timelineDocument.placements, hasLength(3));
  });

  test("1.09 existing boxes regain their outline hierarchy links", () {
    const oldXml = """
<?xml version="1.0" encoding="UTF-8"?>
<Project>
  <ver>1.09</ver>
  <Type>
    <Name>Outline</Name>
    <Storyline Name="主線" Type="Main" UUID="storyline-linked">
      <Event Name="序幕" UUID="event-linked">
        <Scene Name="相遇" UUID="scene-linked" />
      </Event>
    </Storyline>
  </Type>
  <Type>
    <Name>Timeline</Name>
    <Timeline SchemaVersion="1">
      <Tracks>
        <Track UUID="track-old" Name="時間軸 1" Order="0" Collapsed="false" />
      </Tracks>
      <Placements>
        <Placement UUID="large-old" Level="large" TrackUUID="track-old" StartTick="0" DurationTicks="16" Order="0" Label="主線" />
        <Placement UUID="middle-old" ParentUUID="large-old" Level="middle" TrackUUID="track-old" StartTick="0" DurationTicks="4" Order="0" Label="序幕" />
        <Placement UUID="small-old" SceneUUID="scene-linked" ParentUUID="middle-old" Level="small" TrackUUID="track-old" StartTick="1" DurationTicks="1" Order="0" Label="相遇" />
      </Placements>
    </Timeline>
  </Type>
</Project>
""";

    final parsed = FileService.parseProjectXMLWithMetadata(oldXml);
    final placements = parsed.data.timelineDocument.placements;

    expect(parsed.wasMigrated, isTrue);
    expect(placements, hasLength(3));
    expect(
      placements
          .singleWhere((item) => item.placementUUID == "large-old")
          .storylineUUID,
      "storyline-linked",
    );
    final middle = placements.singleWhere(
      (item) => item.placementUUID == "middle-old",
    );
    expect(middle.storylineUUID, "storyline-linked");
    expect(middle.eventUUID, "event-linked");
    final small = placements.singleWhere(
      (item) => item.placementUUID == "small-old",
    );
    expect(small.storylineUUID, "storyline-linked");
    expect(small.eventUUID, "event-linked");
    expect(small.parentPlacementUUID, "middle-old");
    expect(small.startTick, 1);
  });

  test("1.10 keeps an intentionally deleted timeline empty", () {
    final empty = ProjectData.empty();
    final storyline = StorylineData(
      chapterUUID: "storyline-current",
      storylineName: "主線",
      scenes: [
        StoryEventData(
          storyEventUUID: "event-current",
          storyEvent: "序幕",
          scenes: [SceneData(sceneUUID: "scene-current", sceneName: "相遇")],
        ),
      ],
    );
    final data = ProjectData(
      baseInfoData: empty.baseInfoData,
      segmentsData: empty.segmentsData,
      outlineData: [storyline],
      foreshadowData: empty.foreshadowData,
      updatePlanData: empty.updatePlanData,
      worldSettingsData: empty.worldSettingsData,
      characterData: empty.characterData,
      timelineDocument: TimelineDocumentData.initial(),
    );

    final xml = FileService.generateProjectXMLWithoutLatestSaveUpdate(data);
    final parsed = FileService.parseProjectXMLWithMetadata(xml);

    expect(xml, contains("<ver>1.12</ver>"));
    expect(parsed.wasMigrated, isFalse);
    expect(parsed.data.timelineDocument.placements, isEmpty);
  });

  testWidgets("timeline page renders shared controls and unplanned scenes", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(outlineDataProvider.notifier).setOutlineData([
      StorylineData(
        storylineName: "主線",
        scenes: [
          StoryEventData(
            storyEvent: "序幕",
            scenes: [SceneData(sceneName: "相遇")],
          ),
        ],
      ),
    ]);
    final large = container
        .read(timelineActionsProvider)
        .addPlacement(level: TimelineElementLevel.large, label: "第一幕");
    final lowerTrack = container
        .read(timelineActionsProvider)
        .addTrack("時間軸 2");

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TimelineView()),
      ),
    );
    await tester.pump();

    expect(find.text("時間軸"), findsOneWidget);
    expect(find.text("主時間軸"), findsOneWidget);
    expect(find.text("未排定大箱"), findsOneWidget);
    expect(find.text("主線"), findsOneWidget);
    expect(find.text("相遇"), findsNothing);
    expect(find.text("第一幕"), findsOneWidget);
    expect(find.text("時間軸 1"), findsOneWidget);
    expect(find.byTooltip("畫面 Tick 寬度"), findsOneWidget);
    expect(find.text("Tick 對應單位數"), findsOneWidget);
    expect(find.text("每小箱 Tick 數"), findsOneWidget);
    expect(
      find.byKey(const ValueKey("timeline-current-tick-stepper")),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey("timeline-omit-empty-ranges")),
      findsOneWidget,
    );
    expect(find.text("故事刻度設定"), findsOneWidget);
    expect(
      find.byKey(const ValueKey("timeline-auto-sort-outline")),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey("timeline-resize-start-${large.placementUUID}")),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey("timeline-resize-end-${large.placementUUID}")),
      findsOneWidget,
    );
    final horizontalScrollbar = tester.widget<Scrollbar>(
      find.byKey(const ValueKey("timeline-horizontal-scrollbar")),
    );
    expect(horizontalScrollbar.thumbVisibility, isTrue);
    expect(horizontalScrollbar.trackVisibility, isTrue);
    expect(horizontalScrollbar.interactive, isTrue);
    expect(
      horizontalScrollbar.scrollbarOrientation,
      ScrollbarOrientation.bottom,
    );
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byKey(ValueKey("timeline-resize-start-${large.placementUUID}")),
      const Offset(-72, 0),
    );
    await tester.pumpAndSettle();
    final resized = container
        .read(timelineDocumentProvider)
        .placements
        .singleWhere(
          (placement) => placement.placementUUID == large.placementUUID,
        );
    expect(resized.durationTicks, greaterThan(large.durationTicks));
    expect(resized.startTick, lessThan(large.startTick));

    final verticalMoveHandle = find.byKey(
      ValueKey("timeline-move-vertical-${large.placementUUID}"),
    );
    await tester.ensureVisible(verticalMoveHandle);
    await tester.pumpAndSettle();
    await tester.drag(verticalMoveHandle, const Offset(0, 152));
    await tester.pumpAndSettle();
    final movedDown = container
        .read(timelineDocumentProvider)
        .placements
        .singleWhere(
          (placement) => placement.placementUUID == large.placementUUID,
        );
    expect(movedDown.trackUUID, lowerTrack.trackUUID);

    await tester.tap(find.byTooltip("軌道選項").first);
    await tester.pumpAndSettle();
    expect(find.text("重新命名"), findsOneWidget);
    expect(find.text("收合軌道"), findsOneWidget);
    expect(find.text("刪除軌道"), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byTooltip("同步整個大箱"));
    await tester.pump();
    await tester.tap(find.byTooltip("同步整個大箱"));
    await tester.pump();
    final synced = container.read(timelineDocumentProvider).placements;
    expect(
      synced.where((placement) => placement.storylineUUID != null),
      hasLength(4),
    );
    expect(
      synced.where((placement) => placement.sceneUUID != null),
      hasLength(1),
    );
  });

  testWidgets("large and middle boxes show descendant chapter selections", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(segmentsDataProvider.notifier).setSegmentsData([
      SegmentData(
        segmentUUID: "folder",
        segmentName: "正文",
        chapters: [ChapterData(chapterUUID: "chapter-a", chapterName: "已選章節")],
      ),
    ]);
    const document = TimelineDocumentData(
      tracks: [TimelineTrackData(trackUUID: "track", name: "時間軸 1")],
      placements: [
        TimelinePlacementData(
          placementUUID: "large",
          level: TimelineElementLevel.large,
          trackUUID: "track",
          label: "大箱",
        ),
        TimelinePlacementData(
          placementUUID: "middle",
          parentPlacementUUID: "large",
          level: TimelineElementLevel.middle,
          trackUUID: "track",
          label: "中箱",
        ),
        TimelinePlacementData(
          placementUUID: "small",
          sceneUUID: "scene-a",
          parentPlacementUUID: "middle",
          trackUUID: "track",
          label: "小箱",
        ),
      ],
    );
    container.read(timelineDocumentProvider.notifier).setDocument(document);
    container.read(outlineChapterLinksProvider.notifier).setLinks(const [
      OutlineChapterLinkData(
        linkUUID: "link-a",
        sceneUUID: "scene-a",
        chapterUUID: "chapter-a",
      ),
    ]);
    container.read(timelineViewProvider.notifier).select("large");

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TimelineView()),
      ),
    );
    await tester.pump();

    expect(find.text("已選章節 (1/1)"), findsOneWidget);
    expect(find.byTooltip("連結章節並套用到所有子節點"), findsOneWidget);

    container.read(timelineViewProvider.notifier).select("middle");
    await tester.pump();
    expect(find.text("已選章節 (1/1)"), findsOneWidget);
    expect(find.byTooltip("連結章節並套用到所有子節點"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("Tick stepper input, scrubber accumulation and empty omission", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    const document = TimelineDocumentData(
      tracks: [TimelineTrackData(trackUUID: "track", name: "時間軸 1")],
      placements: [
        TimelinePlacementData(
          placementUUID: "early",
          level: TimelineElementLevel.large,
          trackUUID: "track",
          startTick: 0,
          durationTicks: 2,
          label: "早期事件",
        ),
        TimelinePlacementData(
          placementUUID: "late",
          level: TimelineElementLevel.large,
          trackUUID: "track",
          startTick: 100,
          durationTicks: 2,
          label: "後期事件",
        ),
      ],
    );
    container.read(timelineDocumentProvider.notifier).setDocument(document);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TimelineView()),
      ),
    );
    await tester.pump();

    final scrollbarFinder = find.byKey(
      const ValueKey("timeline-horizontal-scrollbar"),
    );
    var scrollbar = tester.widget<Scrollbar>(scrollbarFinder);
    final expandedExtent = scrollbar.controller!.position.maxScrollExtent;
    expect(expandedExtent, greaterThan(1000));

    final currentTickStepper = find.byKey(
      const ValueKey("timeline-current-tick-stepper"),
    );
    final currentTickField = find.descendant(
      of: currentTickStepper,
      matching: find.byType(TextField),
    );
    final increaseTickButton = find.descendant(
      of: currentTickStepper,
      matching: find.byTooltip("增加"),
    );
    expect(tester.widget<TextField>(currentTickField).readOnly, isFalse);
    await tester.tap(increaseTickButton);
    await tester.pump();
    expect(container.read(timelineViewProvider).currentTick, 1);

    container.read(timelineViewProvider.notifier).setPixelsPerTick(100);
    await tester.pump();
    await tester.enterText(currentTickField, "100");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    scrollbar = tester.widget<Scrollbar>(scrollbarFinder);
    expect(scrollbar.controller!.offset, greaterThan(0));
    expect(container.read(timelineViewProvider).currentTick, 100);
    final scrollOffsetBeforeScrub = scrollbar.controller!.offset;

    final scrubber = find.byKey(const ValueKey("timeline-scrubber"));
    final scrubbedTicks = <int>[];
    final scrubberSubscription = container.listen<TimelineViewState>(
      timelineViewProvider,
      (previous, next) {
        if (previous?.currentTick != next.currentTick) {
          scrubbedTicks.add(next.currentTick);
        }
      },
    );
    addTearDown(scrubberSubscription.close);
    final scrubberGesture = await tester.startGesture(
      tester.getCenter(scrubber),
    );
    await scrubberGesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await scrubberGesture.moveBy(const Offset(-50, 0));
    await tester.pump();
    expect(container.read(timelineViewProvider).currentTick, 100);
    await tester.pump(const Duration(milliseconds: 100));
    expect(container.read(timelineViewProvider).currentTick, 100);
    await tester.pump(const Duration(milliseconds: 100));
    expect(container.read(timelineViewProvider).currentTick, 99);
    await tester.pump(const Duration(milliseconds: 100));
    expect(container.read(timelineViewProvider).currentTick, 99);
    await tester.pump(const Duration(milliseconds: 100));
    final heldScrubberTick = container.read(timelineViewProvider).currentTick;
    expect(heldScrubberTick, 98);
    scrollbar = tester.widget<Scrollbar>(scrollbarFinder);
    expect(scrollbar.controller!.offset, lessThan(scrollOffsetBeforeScrub));
    expect(
      scrubbedTicks.toSet().where((tick) => tick < 100).length,
      greaterThanOrEqualTo(2),
    );
    await scrubberGesture.up();
    await tester.pump();
    final scrubbedTick = container.read(timelineViewProvider).currentTick;
    expect(scrubbedTick, heldScrubberTick);
    expect(
      tester.widget<TextField>(currentTickField).controller!.text,
      scrubbedTick.toString(),
    );

    await tester.tap(find.byKey(const ValueKey("timeline-omit-empty-ranges")));
    await tester.pumpAndSettle();
    scrollbar = tester.widget<Scrollbar>(scrollbarFinder);
    expect(
      scrollbar.controller!.position.maxScrollExtent,
      lessThan(expandedExtent / 2),
    );
    expect(container.read(timelineViewProvider).omitEmptyRanges, isTrue);
    expect(container.read(timelineDocumentProvider), document);

    scrollbar.controller!.jumpTo(0);
    await tester.pump();
    final earlyMove = find.byKey(const ValueKey("timeline-move-early"));
    final lateMove = find.byKey(const ValueKey("timeline-move-late"));
    final compressedDistance =
        tester.getCenter(lateMove).dx - tester.getCenter(earlyMove).dx;
    await tester.drag(earlyMove, Offset(compressedDistance, 0));
    await tester.pumpAndSettle();
    final movedEarly = container
        .read(timelineDocumentProvider)
        .placements
        .singleWhere((placement) => placement.placementUUID == "early");
    expect(movedEarly.startTick, 100);
    expect(tester.takeException(), isNull);
  });

  testWidgets("timeline toolbar lays out on a narrow window", (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TimelineView())),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey("timeline-current-tick-stepper")),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey("timeline-jump-tick-button")),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey("timeline-navigation-row")),
      findsOneWidget,
    );
    final zoomControls = find.byKey(const ValueKey("timeline-zoom-controls"));
    final navigationRow = find.byKey(const ValueKey("timeline-navigation-row"));
    expect(zoomControls, findsOneWidget);
    expect(
      tester.getBottomLeft(zoomControls).dy,
      lessThanOrEqualTo(tester.getTopLeft(navigationRow).dy),
    );
    expect(
      find.byKey(const ValueKey("timeline-tick-unit-value")),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey("timeline-small-box-ticks")),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey("timeline-scrubber")), findsOneWidget);
    expect(
      find.byKey(const ValueKey("timeline-omit-empty-ranges")),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets("new nodes use the scrubber tick and ruler clicks move it", (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(timelineViewProvider.notifier).setCurrentTick(10);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TimelineView()),
      ),
    );
    await tester.pump();

    final addLarge = find.byKey(const ValueKey("timeline-add-large"));
    await tester.ensureVisible(addLarge);
    await tester.tap(addLarge);
    await tester.pumpAndSettle();
    final labelField = find.descendant(
      of: find.byKey(const ValueKey("timeline-add-node-label")),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(labelField, "Scrubber 起點大箱");
    await tester.tap(find.byKey(const ValueKey("timeline-confirm-add-node")));
    await tester.pumpAndSettle();

    final placement = container
        .read(timelineDocumentProvider)
        .placements
        .single;
    expect(placement.level, TimelineElementLevel.large);
    expect(placement.startTick, 10);

    final ruler = find.byKey(const ValueKey("timeline-ruler"));
    final scrubber = find.byKey(const ValueKey("timeline-scrubber"));
    final target = Offset(
      tester.getCenter(scrubber).dx + 2 * 72,
      tester.getCenter(ruler).dy,
    );
    await tester.tapAt(target);
    await tester.pump();

    expect(container.read(timelineViewProvider).currentTick, 12);
    expect(tester.takeException(), isNull);
  });
}
