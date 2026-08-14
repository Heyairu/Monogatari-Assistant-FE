import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../models/character_data.dart";
import "../../models/character_snapshot_data.dart";
import "project_state_providers.dart";
import "timeline_providers.dart";

final characterSceneNamesProvider = Provider<Map<String, String>>((ref) {
  final outline = ref.watch(outlineDataProvider);
  return Map<String, String>.unmodifiable({
    for (final storyline in outline)
      for (final event in storyline.scenes)
        for (final scene in event.scenes)
          scene.sceneUUID: scene.sceneName.trim().isEmpty
              ? "未命名 Scene"
              : scene.sceneName.trim(),
  });
});

final characterSnapshotTimelineProvider =
    Provider.family<List<CharacterSnapshotTimelineEntry>, String>((
      ref,
      characterId,
    ) {
      final character = ref.watch(characterDataProvider)[characterId];
      final defaultState = character == null
          ? CharacterSnapshotState()
          : CharacterSnapshotState.fromCharacterEntry(character);
      return buildCharacterSnapshotTimeline(
        characterId: characterId,
        baseline: ref.watch(characterStateBaselinesProvider)[characterId],
        defaultState: defaultState,
        changes: ref.watch(characterStateChangesProvider),
        timeline: ref.watch(timelineDocumentProvider),
        sceneNames: ref.watch(characterSceneNamesProvider),
      );
    });

final currentCharacterSnapshotProvider =
    Provider.family<CharacterStorySnapshot, String>((ref, characterId) {
      final currentTick = ref.watch(
        timelineViewProvider.select((state) => state.currentTick),
      );
      final character = ref.watch(characterDataProvider)[characterId];
      return resolveCharacterSnapshot(
        characterId: characterId,
        baseline: ref.watch(characterStateBaselinesProvider)[characterId],
        defaultState: character == null
            ? CharacterSnapshotState()
            : CharacterSnapshotState.fromCharacterEntry(character),
        changes: ref.watch(characterStateChangesProvider),
        timeline: ref.watch(timelineDocumentProvider),
        atTick: currentTick,
      );
    });

/// The complete character-card projection at a historical Tick.
///
/// Each entry is resolved separately. This is important for relationship
/// graphs: a connection comes from that character's own most recent snapshot
/// at or before the selected Tick, rather than from the most recently changed
/// character in the whole project.
final characterDataAtSnapshotTickProvider =
    Provider.family<Map<String, CharacterEntryData>, int>((ref, tick) {
      final characters = ref.watch(characterDataProvider);
      final baselines = ref.watch(characterStateBaselinesProvider);
      final changes = ref.watch(characterStateChangesProvider);
      final timeline = ref.watch(timelineDocumentProvider);
      return Map<String, CharacterEntryData>.unmodifiable({
        for (final entry in characters.entries)
          entry.key: resolveCharacterSnapshot(
            characterId: entry.key,
            baseline: baselines[entry.key],
            defaultState: CharacterSnapshotState.fromCharacterEntry(
              entry.value,
            ),
            changes: changes,
            timeline: timeline,
            atTick: tick,
          ).state.applyToCharacterEntry(entry.value),
      });
    });

/// All story events that contain snapshot changes, ordered by their resolved
/// timeline Tick. Consumers can use an event as a historical graph cursor.
final characterSnapshotEventsProvider = Provider<List<CharacterSnapshotEvent>>(
  (ref) => buildCharacterSnapshotEvents(
    changes: ref.watch(characterStateChangesProvider),
    timeline: ref.watch(timelineDocumentProvider),
    sceneNames: ref.watch(characterSceneNamesProvider),
  ),
);

final characterStateChangesAtCurrentTickProvider =
    Provider<List<ResolvedCharacterStateChange>>((ref) {
      final currentTick = ref.watch(
        timelineViewProvider.select((state) => state.currentTick),
      );
      final timeline = ref.watch(timelineDocumentProvider);
      return List<ResolvedCharacterStateChange>.unmodifiable(
        ref
            .watch(characterStateChangesProvider)
            .map((change) => resolveCharacterStateChangeTime(change, timeline))
            .where((resolved) => resolved.resolvedTick == currentTick),
      );
    });
