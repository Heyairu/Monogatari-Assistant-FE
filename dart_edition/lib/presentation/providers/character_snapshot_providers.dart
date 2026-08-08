import "package:flutter_riverpod/flutter_riverpod.dart";

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
