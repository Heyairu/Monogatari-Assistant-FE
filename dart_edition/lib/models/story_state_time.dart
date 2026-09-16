import "timeline_data.dart";

/// A domain-independent Scene anchor. Patch data stays with its owning domain.
class StoryStateTimeAnchor {
  final String sceneUUID;
  final String? sourcePlacementUUID;
  final int fallbackTick;

  const StoryStateTimeAnchor({
    required this.sceneUUID,
    this.sourcePlacementUUID,
    required this.fallbackTick,
  });
}

class ResolvedStoryStateTime {
  final int resolvedTick;
  final String? resolvedPlacementUUID;
  final bool sourcePlacementMissing;

  const ResolvedStoryStateTime({
    required this.resolvedTick,
    required this.resolvedPlacementUUID,
    required this.sourcePlacementMissing,
  });

  bool get usesFallbackTick => resolvedPlacementUUID == null;
}

ResolvedStoryStateTime resolveStoryStateTime(
  StoryStateTimeAnchor anchor,
  TimelineDocumentData timeline,
) {
  final tracks = {
    for (final track in timeline.tracks) track.trackUUID: track.order,
  };
  final candidates = timeline.placements
      .where(
        (placement) =>
            placement.sceneUUID == anchor.sceneUUID &&
            placement.level == TimelineElementLevel.small,
      )
      .toList();
  return _resolveStoryStateTimeFromCandidates(anchor, candidates, tracks);
}

ResolvedStoryStateTime _resolveStoryStateTimeFromCandidates(
  StoryStateTimeAnchor anchor,
  List<TimelinePlacementData> candidates,
  Map<String, int> tracks,
) {
  TimelinePlacementData? placement;
  if (anchor.sourcePlacementUUID != null) {
    for (final candidate in candidates) {
      if (candidate.placementUUID == anchor.sourcePlacementUUID) {
        placement = candidate;
        break;
      }
    }
  }
  final sourcePlacementMissing =
      anchor.sourcePlacementUUID != null && placement == null;
  if (placement == null && candidates.isNotEmpty) {
    candidates.sort((a, b) {
      final byTick = a.startTick.compareTo(b.startTick);
      if (byTick != 0) return byTick;
      final byTrack = (tracks[a.trackUUID] ?? 0).compareTo(
        tracks[b.trackUUID] ?? 0,
      );
      if (byTrack != 0) return byTrack;
      return a.placementUUID.compareTo(b.placementUUID);
    });
    placement = candidates.first;
  }
  return ResolvedStoryStateTime(
    resolvedTick: placement?.startTick ?? anchor.fallbackTick,
    resolvedPlacementUUID: placement?.placementUUID,
    sourcePlacementMissing: sourcePlacementMissing,
  );
}

int compareStoryStateTime({
  required int leftTick,
  required int leftSequence,
  required String leftId,
  required int rightTick,
  required int rightSequence,
  required String rightId,
}) {
  final byTick = leftTick.compareTo(rightTick);
  if (byTick != 0) return byTick;
  final bySequence = leftSequence.compareTo(rightSequence);
  return bySequence != 0 ? bySequence : leftId.compareTo(rightId);
}

class ResolvedStoryStateChange<T> {
  final T change;
  final ResolvedStoryStateTime time;

  const ResolvedStoryStateChange(this.change, this.time);
}

/// Owner-scoped cache of ordered changes, never full snapshots per Tick.
/// Call [update] before querying; owners must advance revisions on edits,
/// including project replacement. Only the current revision is retained.
class StoryStateTimeIndex<T> {
  final String Function(T) subjectId;
  final String Function(T) stateChangeId;
  final int Function(T) sequence;
  final StoryStateTimeAnchor Function(T) anchor;
  Object? _dataRevision;
  Object? _timelineRevision;
  TimelineDocumentData? _timeline;
  Map<String, int> _trackOrders = const {};
  Map<String, List<TimelinePlacementData>> _placementsByScene = const {};
  final _subjects = <String, List<T>>{};
  final _resolved = <String, List<ResolvedStoryStateChange<T>>>{};

  StoryStateTimeIndex({
    required this.subjectId,
    required this.stateChangeId,
    required this.sequence,
    required this.anchor,
  });

  void update({
    required Iterable<T> changes,
    required TimelineDocumentData timeline,
    required Object dataRevision,
    required Object timelineRevision,
  }) {
    final dataChanged = _timeline == null || _dataRevision != dataRevision;
    if (dataChanged) {
      _subjects.clear();
      for (final change in changes) {
        _subjects.putIfAbsent(subjectId(change), () => <T>[]).add(change);
      }
    }
    final timelineChanged =
        _timeline == null || _timelineRevision != timelineRevision;
    if (timelineChanged) {
      _trackOrders = {
        for (final track in timeline.tracks) track.trackUUID: track.order,
      };
      final placementsByScene = <String, List<TimelinePlacementData>>{};
      for (final placement in timeline.placements) {
        final sceneUUID = placement.sceneUUID;
        if (sceneUUID == null ||
            placement.level != TimelineElementLevel.small) {
          continue;
        }
        placementsByScene
            .putIfAbsent(sceneUUID, () => <TimelinePlacementData>[])
            .add(placement);
      }
      _placementsByScene = placementsByScene;
    }
    if (dataChanged || timelineChanged) {
      _resolved.clear();
    }
    _dataRevision = dataRevision;
    _timelineRevision = timelineRevision;
    _timeline = timeline;
  }

  List<ResolvedStoryStateChange<T>> orderedChanges(String id) {
    final timeline = _timeline;
    if (timeline == null) throw StateError("Call update before querying");
    // Do not retain arbitrary missing subject queries.
    final changes = _subjects[id];
    if (changes == null) return List<ResolvedStoryStateChange<T>>.empty();
    return _resolved.putIfAbsent(id, () {
      final result = changes.map((change) {
        final changeAnchor = anchor(change);
        return ResolvedStoryStateChange(
          change,
          _resolveStoryStateTimeFromCandidates(
            changeAnchor,
            _placementsByScene[changeAnchor.sceneUUID] ??
                const <TimelinePlacementData>[],
            _trackOrders,
          ),
        );
      }).toList();
      result.sort(
        (a, b) => compareStoryStateTime(
          leftTick: a.time.resolvedTick,
          leftSequence: sequence(a.change),
          leftId: stateChangeId(a.change),
          rightTick: b.time.resolvedTick,
          rightSequence: sequence(b.change),
          rightId: stateChangeId(b.change),
        ),
      );
      return List<ResolvedStoryStateChange<T>>.unmodifiable(result);
    });
  }
}
