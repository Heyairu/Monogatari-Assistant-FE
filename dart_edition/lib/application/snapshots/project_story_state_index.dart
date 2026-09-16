import "../../models/item_data.dart";
import "../../models/item_snapshot_data.dart";
import "../../models/location_snapshot_data.dart";
import "../../models/story_state_time.dart";
import "../../models/timeline_data.dart";

/// Shared, revision-scoped index used by item and location snapshot projections.
/// It groups changes once and resolves Scene placements lazily per subject.
class ProjectStoryStateIndex {
  final StoryStateTimeIndex<ItemClassStateChange> _classChanges =
      StoryStateTimeIndex<ItemClassStateChange>(
        subjectId: (change) => change.classId,
        stateChangeId: (change) => change.stateChangeId,
        sequence: (change) => change.sequence,
        anchor: (change) => change.anchor,
      );
  final StoryStateTimeIndex<ItemInstanceStateChange> _instanceChanges =
      StoryStateTimeIndex<ItemInstanceStateChange>(
        subjectId: (change) => change.instanceId,
        stateChangeId: (change) => change.stateChangeId,
        sequence: (change) => change.sequence,
        anchor: (change) => change.anchor,
      );
  final StoryStateTimeIndex<LocationStateChange> _locationChanges =
      StoryStateTimeIndex<LocationStateChange>(
        subjectId: (change) => change.locationId,
        stateChangeId: (change) => change.stateChangeId,
        sequence: (change) => change.sequence,
        anchor: (change) => change.anchor,
      );

  ProjectStoryStateIndex({
    required Iterable<ItemClassStateChange> itemClassChanges,
    required Iterable<ItemInstanceStateChange> itemInstanceChanges,
    required Iterable<LocationStateChange> locationChanges,
    required TimelineDocumentData timeline,
  }) {
    final dataRevision = Object();
    final timelineRevision = Object();
    _classChanges.update(
      changes: itemClassChanges,
      timeline: timeline,
      dataRevision: dataRevision,
      timelineRevision: timelineRevision,
    );
    _instanceChanges.update(
      changes: itemInstanceChanges,
      timeline: timeline,
      dataRevision: dataRevision,
      timelineRevision: timelineRevision,
    );
    _locationChanges.update(
      changes: locationChanges,
      timeline: timeline,
      dataRevision: dataRevision,
      timelineRevision: timelineRevision,
    );
  }

  ItemSnapshotState resolveItemClass(ItemClassData itemClass, int atTick) {
    var state = itemClass.defaultState;
    for (final entry in _classChanges.orderedChanges(itemClass.classId)) {
      if (entry.time.resolvedTick > atTick) break;
      state = entry.change.patch.applyTo(
        state,
        inherited: itemClass.defaultState,
      );
    }
    return state;
  }

  ItemSnapshotState resolveItemInstance({
    required ItemClassData itemClass,
    required ItemInstanceData instance,
    required int atTick,
  }) {
    if (instance.classId != itemClass.classId) {
      throw ArgumentError("Instance belongs to another Class");
    }
    final inherited = resolveItemClass(itemClass, atTick);
    var overrides = instance.defaultState;
    for (final entry in _instanceChanges.orderedChanges(instance.instanceId)) {
      if (entry.time.resolvedTick > atTick) break;
      overrides = overrides.merge(entry.change.patch);
    }
    return overrides.applyTo(inherited, inherited: inherited);
  }

  LocationSnapshotState resolveLocation({
    required String locationId,
    LocationSnapshotState? defaultState,
    required int atTick,
  }) {
    final defaults = defaultState ?? LocationSnapshotState();
    var state = defaults;
    for (final entry in _locationChanges.orderedChanges(locationId)) {
      if (entry.time.resolvedTick > atTick) break;
      state = entry.change.patch.applyTo(state, inherited: defaults);
    }
    return state;
  }
}
