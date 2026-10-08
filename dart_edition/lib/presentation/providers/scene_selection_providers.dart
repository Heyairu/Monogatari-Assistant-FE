import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../models/timeline_data.dart";
import "project_state_providers.dart";
import "timeline_providers.dart";

/// Scene choices follow timeline starts, then the configured track order.
final placedSceneChoicesProvider = Provider<List<TimelinePlacementData>>((ref) {
  final document = ref.watch(timelineDocumentProvider);
  final sceneIndex = ref.watch(timelineSceneIndexProvider);
  final trackOrders = {
    for (final track in document.tracks) track.trackUUID: track.order,
  };
  final placements = document.placements
      .where(
        (p) =>
            p.level == TimelineElementLevel.small &&
            p.sceneUUID != null &&
            sceneIndex.containsKey(p.sceneUUID),
      )
      .toList();
  placements.sort((a, b) {
    final byStart = a.startTick.compareTo(b.startTick);
    if (byStart != 0) return byStart;
    final byTrack = (trackOrders[a.trackUUID] ?? 0).compareTo(
      trackOrders[b.trackUUID] ?? 0,
    );
    if (byTrack != 0) return byTrack;
    return a.placementUUID.compareTo(b.placementUUID);
  });
  return List.unmodifiable(placements);
});

/// Equal distances keep the supplied start/track ordering.
T? nearestSceneChoice<T>(
  Iterable<T> choices,
  int tick,
  int Function(T) startTick,
) {
  T? nearest;
  int? distance;
  for (final choice in choices) {
    final candidateDistance = (startTick(choice) - tick).abs();
    if (distance == null || candidateDistance < distance) {
      nearest = choice;
      distance = candidateDistance;
    }
  }
  return nearest;
}
