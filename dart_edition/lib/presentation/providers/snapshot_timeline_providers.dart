import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../models/character_snapshot_data.dart";
import "../../models/item_data.dart";
import "../../models/item_snapshot_data.dart";
import "../../models/location_snapshot_data.dart";
import "../../models/story_state_time.dart";
import "../../models/timeline_data.dart";
import "character_snapshot_providers.dart";
import "project_state_providers.dart";

enum SnapshotSubjectKind {
  character,
  location,
  itemClass,
  itemInstance,
  relationships,
}

enum SnapshotPreviewMode { baseline, followTimeline, localTick }

typedef SnapshotTimelineSubject = ({SnapshotSubjectKind kind, String id});

/// Display-only projection. Domain resolvers remain the source of state values.
class SnapshotTimelineEvent {
  final String id;
  final String sourceId;
  final SnapshotSubjectKind kind;
  final String subjectId;
  final String sceneUUID;
  final String? placementUUID;
  final int tick;
  final int sequence;
  final String label;
  final bool usesFallbackTick;
  final bool sourcePlacementMissing;
  final bool inherited;
  final String? transactionId;
  final String note;

  const SnapshotTimelineEvent({
    required this.id,
    required this.sourceId,
    required this.kind,
    required this.subjectId,
    required this.sceneUUID,
    required this.tick,
    required this.label,
    this.placementUUID,
    this.sequence = 0,
    this.usesFallbackTick = false,
    this.sourcePlacementMissing = false,
    this.inherited = false,
    this.transactionId,
    this.note = "",
  });

  String get description => [
    label,
    "Tick $tick",
    if (inherited) "繼承自 Class",
    if (usesFallbackTick) "回退時間：Scene 尚未排定",
    if (sourcePlacementMissing) "原 placement 已失聯",
    if (transactionId != null) "批次 $transactionId",
    if (note.trim().isNotEmpty) note.trim(),
  ].join(" · ");
}

/// Exact-Tick selection for editors. Own events take priority over inheritance;
/// a user's explicit choice is retained while it remains at the current Tick.
SnapshotTimelineEvent? snapshotEventAtTick(
  Iterable<SnapshotTimelineEvent> events,
  int tick, {
  String? selectedId,
}) {
  final candidates = events.where((event) => event.tick == tick).toList();
  return candidates.where((event) => event.id == selectedId).firstOrNull ??
      candidates.where((event) => !event.inherited).lastOrNull ??
      candidates.lastOrNull;
}

List<SnapshotTimelineEvent> buildSnapshotTimelineEvents({
  required SnapshotTimelineSubject subject,
  required TimelineDocumentData timeline,
  Map<String, String> sceneNames = const {},
  Iterable<CharacterStateChange> characterChanges = const [],
  Iterable<LocationStateChange> locationChanges = const [],
  Iterable<ItemClassStateChange> classChanges = const [],
  Iterable<ItemInstanceStateChange> instanceChanges = const [],
  ItemInstanceData? instance,
  Iterable<CharacterSnapshotEvent> relationshipEvents = const [],
}) {
  final result = <SnapshotTimelineEvent>[];
  void add({
    required SnapshotSubjectKind kind,
    required String owner,
    required String id,
    required StoryStateTimeAnchor anchor,
    required int sequence,
    bool inherited = false,
    String? transactionId,
    String note = "",
  }) {
    final time = resolveStoryStateTime(anchor, timeline);
    result.add(
      SnapshotTimelineEvent(
        id: "${kind.name}:$id",
        sourceId: id,
        kind: kind,
        subjectId: owner,
        sceneUUID: anchor.sceneUUID,
        placementUUID: time.resolvedPlacementUUID,
        tick: time.resolvedTick,
        sequence: sequence,
        label: sceneNames[anchor.sceneUUID] ?? "未命名 Scene",
        usesFallbackTick: time.usesFallbackTick,
        sourcePlacementMissing: time.sourcePlacementMissing,
        inherited: inherited,
        transactionId: transactionId,
        note: note,
      ),
    );
  }

  switch (subject.kind) {
    case SnapshotSubjectKind.character:
      for (final change in characterChanges.where(
        (c) => c.characterId == subject.id,
      )) {
        add(
          kind: subject.kind,
          owner: subject.id,
          id: change.stateChangeId,
          anchor: StoryStateTimeAnchor(
            sceneUUID: change.sceneUUID,
            sourcePlacementUUID: change.sourcePlacementUUID,
            fallbackTick: change.fallbackTick,
          ),
          sequence: change.sequence,
          note: change.note,
        );
      }
    case SnapshotSubjectKind.location:
      for (final change in locationChanges.where(
        (c) => c.locationId == subject.id,
      )) {
        add(
          kind: subject.kind,
          owner: subject.id,
          id: change.stateChangeId,
          anchor: change.anchor,
          sequence: change.sequence,
          transactionId: change.transactionId,
          note: change.note,
        );
      }
    case SnapshotSubjectKind.itemClass:
      for (final change in classChanges.where((c) => c.classId == subject.id)) {
        add(
          kind: subject.kind,
          owner: subject.id,
          id: change.stateChangeId,
          anchor: change.anchor,
          sequence: change.sequence,
          note: change.note,
        );
      }
    case SnapshotSubjectKind.itemInstance:
      for (final change in classChanges.where(
        (c) => c.classId == instance?.classId,
      )) {
        add(
          kind: SnapshotSubjectKind.itemClass,
          owner: change.classId,
          id: change.stateChangeId,
          anchor: change.anchor,
          sequence: change.sequence,
          inherited: true,
          note: change.note,
        );
      }
      for (final change in instanceChanges.where(
        (c) => c.instanceId == subject.id,
      )) {
        add(
          kind: subject.kind,
          owner: subject.id,
          id: change.stateChangeId,
          anchor: change.anchor,
          sequence: change.sequence,
          note: change.note,
        );
      }
    case SnapshotSubjectKind.relationships:
      for (final event in relationshipEvents) {
        result.add(
          SnapshotTimelineEvent(
            id: "relationships:${event.id}",
            sourceId: event.id,
            kind: subject.kind,
            subjectId: subject.id,
            sceneUUID: event.sceneUUID,
            placementUUID: event.resolvedPlacementUUID,
            tick: event.resolvedTick,
            label:
                "${event.sceneName}（${event.changedCharacterIds.length} 位角色變更）",
            usesFallbackTick: event.usesFallbackTick,
            sourcePlacementMissing: characterChanges
                .where((c) => event.stateChangeIds.contains(c.stateChangeId))
                .any(
                  (c) => resolveStoryStateTime(
                    StoryStateTimeAnchor(
                      sceneUUID: c.sceneUUID,
                      sourcePlacementUUID: c.sourcePlacementUUID,
                      fallbackTick: c.fallbackTick,
                    ),
                    timeline,
                  ).sourcePlacementMissing,
                ),
          ),
        );
      }
  }
  final trackOrders = {
    for (final track in timeline.tracks) track.trackUUID: track.order,
  };
  final placementTracks = {
    for (final placement in timeline.placements)
      placement.placementUUID: trackOrders[placement.trackUUID] ?? 0,
  };
  result.sort((a, b) {
    final byTick = a.tick.compareTo(b.tick);
    if (byTick != 0) return byTick;
    final byTrack = (placementTracks[a.placementUUID] ?? 0).compareTo(
      placementTracks[b.placementUUID] ?? 0,
    );
    if (byTrack != 0) return byTrack;
    return compareStoryStateTime(
      leftTick: a.tick,
      leftSequence: a.sequence,
      leftId: a.id,
      rightTick: b.tick,
      rightSequence: b.sequence,
      rightId: b.id,
    );
  });
  return List.unmodifiable(result);
}

final snapshotTimelineEventsProvider = Provider.autoDispose
    .family<List<SnapshotTimelineEvent>, SnapshotTimelineSubject>((
      ref,
      subject,
    ) {
      final timeline = ref.watch(timelineDocumentProvider);
      final names = ref.watch(characterSceneNamesProvider);
      if (subject.kind == SnapshotSubjectKind.relationships) {
        return buildSnapshotTimelineEvents(
          subject: subject,
          timeline: timeline,
          relationshipEvents: ref.watch(characterSnapshotEventsProvider),
          characterChanges: ref.watch(characterStateChangesProvider),
        );
      }
      if (subject.kind == SnapshotSubjectKind.character) {
        return buildSnapshotTimelineEvents(
          subject: subject,
          timeline: timeline,
          sceneNames: names,
          characterChanges: ref.watch(characterStateChangesProvider),
        );
      }
      final workspace = ref.watch(itemWorkspaceProvider);
      return buildSnapshotTimelineEvents(
        subject: subject,
        timeline: timeline,
        sceneNames: names,
        locationChanges: workspace.locationStateChanges,
        classChanges: workspace.itemClassStateChanges,
        instanceChanges: workspace.itemInstanceStateChanges,
        instance: workspace.itemInstances[subject.id],
      );
    });
