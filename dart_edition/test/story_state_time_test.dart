import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/models/character_snapshot_data.dart";
import "package:monogatari_assistant/models/story_state_time.dart";
import "package:monogatari_assistant/models/timeline_data.dart";

TimelinePlacementData placement(
  String id,
  int tick, {
  String scene = "scene",
  String track = "unknown",
  TimelineElementLevel level = TimelineElementLevel.small,
}) => TimelinePlacementData(
  placementUUID: id,
  sceneUUID: scene,
  trackUUID: track,
  startTick: tick,
  level: level,
);

StoryStateTimeAnchor anchor([String? source]) => StoryStateTimeAnchor(
  sceneUUID: "scene",
  sourcePlacementUUID: source,
  fallbackTick: -99,
);

CharacterStateChange change(
  String id, {
  int sequence = 0,
  String subject = "one",
}) => CharacterStateChange(
  stateChangeId: id,
  characterId: subject,
  sceneUUID: "scene",
  fallbackTick: -99,
  sequence: sequence,
);

void main() {
  test("preferred small placement wins even when later", () {
    final timeline = TimelineDocumentData(
      placements: [placement("early", -5), placement("preferred", 20)],
    );
    final result = resolveStoryStateTime(anchor("preferred"), timeline);
    expect(result.resolvedTick, 20);
    expect(result.resolvedPlacementUUID, "preferred");
    expect(result.sourcePlacementMissing, isFalse);
    expect(result.usesFallbackTick, isFalse);
  });

  test("candidate order uses tick, track order (unknown zero), then ID", () {
    final candidates = [
      placement("later", 0, track: "first"),
      placement("z", -5, track: "last"),
      placement("b", -5),
      placement("a", -5),
    ];
    for (final input in [candidates, candidates.reversed.toList()]) {
      final timeline = TimelineDocumentData(
        tracks: const [
          TimelineTrackData(trackUUID: "first", name: "First", order: -1),
          TimelineTrackData(trackUUID: "last", name: "Last", order: 1),
        ],
        placements: input,
      );
      final result = resolveStoryStateTime(anchor(), timeline);
      expect(result.resolvedTick, -5);
      expect(result.resolvedPlacementUUID, "a");
      expect(result.sourcePlacementMissing, isFalse);
    }
  });

  test(
    "invalid sources distinguish alternate candidate from full fallback",
    () {
      for (final source in ["deleted", "wrong-scene", "large"]) {
        final excluded = [
          placement("wrong-scene", -100, scene: "other"),
          placement("large", -100, level: TimelineElementLevel.large),
        ];
        final alternate = resolveStoryStateTime(
          anchor(source),
          TimelineDocumentData(
            placements: [...excluded, placement("valid", -5)],
          ),
        );
        expect(alternate.sourcePlacementMissing, isTrue);
        expect(alternate.usesFallbackTick, isFalse);
        expect(alternate.resolvedPlacementUUID, "valid");
        final fallback = resolveStoryStateTime(
          anchor(source),
          TimelineDocumentData(placements: excluded),
        );
        expect(fallback.sourcePlacementMissing, isTrue);
        expect(fallback.usesFallbackTick, isTrue);
        expect(fallback.resolvedTick, -99);
        expect(fallback.resolvedPlacementUUID, isNull);
      }
      final result = resolveStoryStateTime(
        anchor(),
        const TimelineDocumentData(),
      );
      expect(result.usesFallbackTick, isTrue);
      expect(result.sourcePlacementMissing, isFalse);
    },
  );

  test(
    "character ordering and inclusive negative Tick boundary are preserved",
    () {
      final changes = [
        change("z", sequence: 1),
        change("b"),
        change("a"),
        change("other", subject: "two"),
      ];
      final timeline = TimelineDocumentData(placements: [placement("p", -5)]);
      CharacterStorySnapshot snapshot(int tick) => resolveCharacterSnapshot(
        characterId: "one",
        changes: changes,
        timeline: timeline,
        atTick: tick,
      );
      expect(snapshot(-6).appliedStateChangeIds, isEmpty);
      expect(snapshot(-5).appliedStateChangeIds, ["a", "b", "z"]);
      expect(snapshot(0).appliedStateChangeIds, ["a", "b", "z"]);
      expect(snapshot(-5).sourcePlacementUUID, "p");
    },
  );

  test(
    "subject index caches current revision and invalidates movement and edits",
    () {
      final index = StoryStateTimeIndex<CharacterStateChange>(
        subjectId: (c) => c.characterId,
        stateChangeId: (c) => c.stateChangeId,
        sequence: (c) => c.sequence,
        anchor: (c) => StoryStateTimeAnchor(
          sceneUUID: c.sceneUUID,
          sourcePlacementUUID: c.sourcePlacementUUID,
          fallbackTick: c.fallbackTick,
        ),
      );
      expect(() => index.orderedChanges("one"), throwsStateError);
      final changes = [
        change("b"),
        change("a"),
        change("other", subject: "two"),
      ];
      void update(
        int tick,
        int dataRevision,
        int timelineRevision, [
        List<CharacterStateChange>? data,
      ]) => index.update(
        changes: data ?? changes,
        timeline: TimelineDocumentData(placements: [placement("p", tick)]),
        dataRevision: dataRevision,
        timelineRevision: timelineRevision,
      );
      update(-5, 0, 0);
      final original = index.orderedChanges("one");
      expect(original.map((c) => c.change.stateChangeId), ["a", "b"]);
      expect(index.orderedChanges("two").single.change.stateChangeId, "other");
      expect(index.orderedChanges("missing"), isEmpty);
      expect(() => original.clear(), throwsUnsupportedError);
      update(-5, 0, 0);
      expect(identical(original, index.orderedChanges("one")), isTrue);
      update(15, 0, 1);
      expect(index.orderedChanges("one").first.time.resolvedTick, 15);
      expect(original.first.time.resolvedTick, -5);
      update(15, 1, 1, [change("b", sequence: -1), change("a")]);
      expect(index.orderedChanges("one").map((c) => c.change.stateChangeId), [
        "b",
        "a",
      ]);
      expect(index.orderedChanges("two"), isEmpty);
    },
  );
}
