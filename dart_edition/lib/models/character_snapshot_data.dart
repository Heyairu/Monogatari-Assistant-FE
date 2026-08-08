import "dart:collection";

import "package:uuid/uuid.dart";

import "character_data.dart";
import "timeline_data.dart";

const _snapshotUuid = Uuid();

String generateCharacterStateChangeId() => _snapshotUuid.v4();

class CharacterSnapshotState {
  final List<CharacterConflict> conflicts;
  final List<CharacterRelationship> relationships;
  final List<CharacterProfileTableEntry> organizations;
  final List<CharacterProfileTableEntry> statusEntries;
  final List<CharacterPossessionEntry> possessions;
  final Map<String, CustomFieldValue> customFields;

  CharacterSnapshotState({
    Iterable<CharacterConflict> conflicts = const <CharacterConflict>[],
    Iterable<CharacterRelationship> relationships =
        const <CharacterRelationship>[],
    Iterable<CharacterProfileTableEntry> organizations =
        const <CharacterProfileTableEntry>[],
    Iterable<CharacterProfileTableEntry> statusEntries =
        const <CharacterProfileTableEntry>[],
    Iterable<CharacterPossessionEntry> possessions =
        const <CharacterPossessionEntry>[],
    Map<String, CustomFieldValue> customFields =
        const <String, CustomFieldValue>{},
  }) : conflicts = List<CharacterConflict>.unmodifiable(conflicts),
       relationships = List<CharacterRelationship>.unmodifiable(relationships),
       organizations = List<CharacterProfileTableEntry>.unmodifiable(
         organizations,
       ),
       statusEntries = List<CharacterProfileTableEntry>.unmodifiable(
         statusEntries,
       ),
       possessions = List<CharacterPossessionEntry>.unmodifiable(possessions),
       customFields = Map<String, CustomFieldValue>.unmodifiable(customFields);

  factory CharacterSnapshotState.fromCharacterEntry(CharacterEntryData entry) {
    return CharacterSnapshotState(
      conflicts: entry.conflicts,
      relationships: entry.relationships,
      organizations: entry.organizations,
      statusEntries: entry.statusEntries,
      possessions: entry.possessions,
      customFields: entry.customFields,
    );
  }

  CharacterEntryData applyToCharacterEntry(CharacterEntryData entry) {
    return entry.copyWith(
      conflicts: conflicts,
      hinderEvents: conflicts
          .map(
            (item) => CharacterHinderEvent(
              event: item.obstacle,
              solve: item.resolution,
            ),
          )
          .toList(growable: false),
      relationships: relationships,
      organizations: organizations,
      statusEntries: statusEntries,
      possessions: possessions,
      customFields: customFields,
    );
  }

  CharacterSnapshotState copyWith({
    Iterable<CharacterConflict>? conflicts,
    Iterable<CharacterRelationship>? relationships,
    Iterable<CharacterProfileTableEntry>? organizations,
    Iterable<CharacterProfileTableEntry>? statusEntries,
    Iterable<CharacterPossessionEntry>? possessions,
    Map<String, CustomFieldValue>? customFields,
  }) {
    return CharacterSnapshotState(
      conflicts: conflicts ?? this.conflicts,
      relationships: relationships ?? this.relationships,
      organizations: organizations ?? this.organizations,
      statusEntries: statusEntries ?? this.statusEntries,
      possessions: possessions ?? this.possessions,
      customFields: customFields ?? this.customFields,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CharacterSnapshotState &&
      _listEquals(other.conflicts, conflicts) &&
      _listEquals(other.relationships, relationships) &&
      _listEquals(other.organizations, organizations) &&
      _listEquals(other.statusEntries, statusEntries) &&
      _listEquals(other.possessions, possessions) &&
      _mapEquals(other.customFields, customFields);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(conflicts),
    Object.hashAll(relationships),
    Object.hashAll(organizations),
    Object.hashAll(statusEntries),
    Object.hashAll(possessions),
    Object.hashAllUnordered(
      customFields.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
  );
}

class CharacterStatePatch {
  final List<CharacterConflict>? conflicts;
  final List<CharacterRelationship>? relationships;
  final List<CharacterProfileTableEntry>? organizations;
  final List<CharacterProfileTableEntry>? statusEntries;
  final List<CharacterPossessionEntry>? possessions;
  final Map<String, CustomFieldValue>? customFields;

  CharacterStatePatch({
    Iterable<CharacterConflict>? conflicts,
    Iterable<CharacterRelationship>? relationships,
    Iterable<CharacterProfileTableEntry>? organizations,
    Iterable<CharacterProfileTableEntry>? statusEntries,
    Iterable<CharacterPossessionEntry>? possessions,
    Map<String, CustomFieldValue>? customFields,
  }) : conflicts = conflicts == null
           ? null
           : List<CharacterConflict>.unmodifiable(conflicts),
       relationships = relationships == null
           ? null
           : List<CharacterRelationship>.unmodifiable(relationships),
       organizations = organizations == null
           ? null
           : List<CharacterProfileTableEntry>.unmodifiable(organizations),
       statusEntries = statusEntries == null
           ? null
           : List<CharacterProfileTableEntry>.unmodifiable(statusEntries),
       possessions = possessions == null
           ? null
           : List<CharacterPossessionEntry>.unmodifiable(possessions),
       customFields = customFields == null
           ? null
           : Map<String, CustomFieldValue>.unmodifiable(customFields);

  factory CharacterStatePatch.fromState(CharacterSnapshotState state) {
    return CharacterStatePatch(
      conflicts: state.conflicts,
      relationships: state.relationships,
      organizations: state.organizations,
      statusEntries: state.statusEntries,
      possessions: state.possessions,
      customFields: state.customFields,
    );
  }

  bool get isEmpty =>
      conflicts == null &&
      relationships == null &&
      organizations == null &&
      statusEntries == null &&
      possessions == null &&
      customFields == null;

  CharacterSnapshotState applyTo(CharacterSnapshotState source) {
    return CharacterSnapshotState(
      conflicts: conflicts ?? source.conflicts,
      relationships: relationships ?? source.relationships,
      organizations: organizations ?? source.organizations,
      statusEntries: statusEntries ?? source.statusEntries,
      possessions: possessions ?? source.possessions,
      customFields: customFields ?? source.customFields,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CharacterStatePatch &&
      _nullableListEquals(other.conflicts, conflicts) &&
      _nullableListEquals(other.relationships, relationships) &&
      _nullableListEquals(other.organizations, organizations) &&
      _nullableListEquals(other.statusEntries, statusEntries) &&
      _nullableListEquals(other.possessions, possessions) &&
      _nullableMapEquals(other.customFields, customFields);

  @override
  int get hashCode => Object.hash(
    conflicts == null ? null : Object.hashAll(conflicts!),
    relationships == null ? null : Object.hashAll(relationships!),
    organizations == null ? null : Object.hashAll(organizations!),
    statusEntries == null ? null : Object.hashAll(statusEntries!),
    possessions == null ? null : Object.hashAll(possessions!),
    customFields == null
        ? null
        : Object.hashAllUnordered(
            customFields!.entries.map(
              (entry) => Object.hash(entry.key, entry.value),
            ),
          ),
  );
}

class CharacterStateBaseline {
  final String characterId;
  final CharacterStatePatch patch;
  final String note;

  CharacterStateBaseline({
    required this.characterId,
    CharacterStatePatch? patch,
    this.note = "",
  }) : patch = patch ?? CharacterStatePatch();

  CharacterStateBaseline copyWith({
    String? characterId,
    CharacterStatePatch? patch,
    String? note,
  }) {
    return CharacterStateBaseline(
      characterId: characterId ?? this.characterId,
      patch: patch ?? this.patch,
      note: note ?? this.note,
    );
  }

  CharacterSnapshotState resolve([CharacterSnapshotState? source]) =>
      patch.applyTo(source ?? CharacterSnapshotState());

  CharacterSnapshotState get resolvedState => resolve();

  @override
  bool operator ==(Object other) =>
      other is CharacterStateBaseline &&
      other.characterId == characterId &&
      other.patch == patch &&
      other.note == note;

  @override
  int get hashCode => Object.hash(characterId, patch, note);
}

class CharacterStateChange {
  final String stateChangeId;
  final String characterId;
  final String sceneUUID;
  final String? sourcePlacementUUID;
  final int fallbackTick;
  final int sequence;
  final CharacterStatePatch patch;
  final String note;

  CharacterStateChange({
    String? stateChangeId,
    required this.characterId,
    required this.sceneUUID,
    this.sourcePlacementUUID,
    required this.fallbackTick,
    this.sequence = 0,
    CharacterStatePatch? patch,
    this.note = "",
  }) : stateChangeId = stateChangeId?.trim().isNotEmpty == true
           ? stateChangeId!.trim()
           : generateCharacterStateChangeId(),
       patch = patch ?? CharacterStatePatch();

  CharacterStateChange copyWith({
    String? stateChangeId,
    String? characterId,
    String? sceneUUID,
    Object? sourcePlacementUUID = _unset,
    int? fallbackTick,
    int? sequence,
    CharacterStatePatch? patch,
    String? note,
  }) {
    return CharacterStateChange(
      stateChangeId: stateChangeId ?? this.stateChangeId,
      characterId: characterId ?? this.characterId,
      sceneUUID: sceneUUID ?? this.sceneUUID,
      sourcePlacementUUID: identical(sourcePlacementUUID, _unset)
          ? this.sourcePlacementUUID
          : sourcePlacementUUID as String?,
      fallbackTick: fallbackTick ?? this.fallbackTick,
      sequence: sequence ?? this.sequence,
      patch: patch ?? this.patch,
      note: note ?? this.note,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CharacterStateChange &&
      other.stateChangeId == stateChangeId &&
      other.characterId == characterId &&
      other.sceneUUID == sceneUUID &&
      other.sourcePlacementUUID == sourcePlacementUUID &&
      other.fallbackTick == fallbackTick &&
      other.sequence == sequence &&
      other.patch == patch &&
      other.note == note;

  @override
  int get hashCode => Object.hash(
    stateChangeId,
    characterId,
    sceneUUID,
    sourcePlacementUUID,
    fallbackTick,
    sequence,
    patch,
    note,
  );
}

class ResolvedCharacterStateChange {
  final CharacterStateChange change;
  final int resolvedTick;
  final String? resolvedPlacementUUID;
  final bool usesFallbackTick;

  const ResolvedCharacterStateChange({
    required this.change,
    required this.resolvedTick,
    required this.resolvedPlacementUUID,
    required this.usesFallbackTick,
  });
}

class CharacterStorySnapshot {
  final String characterId;
  final int resolvedTick;
  final String? sceneUUID;
  final String? sourcePlacementUUID;
  final CharacterSnapshotState state;
  final List<String> appliedStateChangeIds;

  CharacterStorySnapshot({
    required this.characterId,
    required this.resolvedTick,
    this.sceneUUID,
    this.sourcePlacementUUID,
    CharacterSnapshotState? state,
    Iterable<String> appliedStateChangeIds = const <String>[],
  }) : state = state ?? CharacterSnapshotState(),
       appliedStateChangeIds = List<String>.unmodifiable(appliedStateChangeIds);
}

class CharacterSnapshotTimelineEntry {
  final bool isBaseline;
  final CharacterStorySnapshot snapshot;
  final CharacterStateChange? change;
  final String sceneName;
  final bool usesFallbackTick;

  const CharacterSnapshotTimelineEntry({
    required this.isBaseline,
    required this.snapshot,
    required this.change,
    required this.sceneName,
    required this.usesFallbackTick,
  });
}

ResolvedCharacterStateChange resolveCharacterStateChangeTime(
  CharacterStateChange change,
  TimelineDocumentData timeline,
) {
  final tracks = {
    for (final track in timeline.tracks) track.trackUUID: track.order,
  };
  final candidates = timeline.placements
      .where(
        (placement) =>
            placement.sceneUUID == change.sceneUUID &&
            placement.level == TimelineElementLevel.small,
      )
      .toList(growable: false);

  TimelinePlacementData? placement;
  if (change.sourcePlacementUUID != null) {
    for (final candidate in candidates) {
      if (candidate.placementUUID == change.sourcePlacementUUID) {
        placement = candidate;
        break;
      }
    }
  }
  if (placement == null && candidates.isNotEmpty) {
    final sorted = [...candidates]
      ..sort((a, b) {
        final byTick = a.startTick.compareTo(b.startTick);
        if (byTick != 0) return byTick;
        final byTrack = (tracks[a.trackUUID] ?? 0).compareTo(
          tracks[b.trackUUID] ?? 0,
        );
        if (byTrack != 0) return byTrack;
        return a.placementUUID.compareTo(b.placementUUID);
      });
    placement = sorted.first;
  }

  return ResolvedCharacterStateChange(
    change: change,
    resolvedTick: placement?.startTick ?? change.fallbackTick,
    resolvedPlacementUUID: placement?.placementUUID,
    usesFallbackTick: placement == null,
  );
}

List<ResolvedCharacterStateChange> orderedCharacterStateChanges({
  required String characterId,
  required Iterable<CharacterStateChange> changes,
  required TimelineDocumentData timeline,
}) {
  final result = changes
      .where((change) => change.characterId == characterId)
      .map((change) => resolveCharacterStateChangeTime(change, timeline))
      .toList(growable: false);
  result.sort((a, b) {
    final byTick = a.resolvedTick.compareTo(b.resolvedTick);
    if (byTick != 0) return byTick;
    final bySequence = a.change.sequence.compareTo(b.change.sequence);
    if (bySequence != 0) return bySequence;
    return a.change.stateChangeId.compareTo(b.change.stateChangeId);
  });
  return List<ResolvedCharacterStateChange>.unmodifiable(result);
}

CharacterStorySnapshot resolveCharacterSnapshot({
  required String characterId,
  CharacterStateBaseline? baseline,
  CharacterSnapshotState? defaultState,
  required Iterable<CharacterStateChange> changes,
  required TimelineDocumentData timeline,
  required int atTick,
}) {
  var state =
      baseline?.resolve(defaultState) ??
      defaultState ??
      CharacterSnapshotState();
  final applied = <String>[];
  String? lastScene;
  String? lastPlacement;
  for (final resolved in orderedCharacterStateChanges(
    characterId: characterId,
    changes: changes,
    timeline: timeline,
  )) {
    if (resolved.resolvedTick > atTick) break;
    state = resolved.change.patch.applyTo(state);
    applied.add(resolved.change.stateChangeId);
    lastScene = resolved.change.sceneUUID;
    lastPlacement = resolved.resolvedPlacementUUID;
  }
  return CharacterStorySnapshot(
    characterId: characterId,
    resolvedTick: atTick,
    sceneUUID: lastScene,
    sourcePlacementUUID: lastPlacement,
    state: state,
    appliedStateChangeIds: applied,
  );
}

List<CharacterSnapshotTimelineEntry> buildCharacterSnapshotTimeline({
  required String characterId,
  CharacterStateBaseline? baseline,
  CharacterSnapshotState? defaultState,
  required Iterable<CharacterStateChange> changes,
  required TimelineDocumentData timeline,
  Map<String, String> sceneNames = const <String, String>{},
}) {
  var state =
      baseline?.resolve(defaultState) ??
      defaultState ??
      CharacterSnapshotState();
  final applied = <String>[];
  final result = <CharacterSnapshotTimelineEntry>[
    CharacterSnapshotTimelineEntry(
      isBaseline: true,
      snapshot: CharacterStorySnapshot(
        characterId: characterId,
        resolvedTick: 0,
        state: state,
      ),
      change: null,
      sceneName: "預設狀態",
      usesFallbackTick: false,
    ),
  ];
  for (final resolved in orderedCharacterStateChanges(
    characterId: characterId,
    changes: changes,
    timeline: timeline,
  )) {
    state = resolved.change.patch.applyTo(state);
    applied.add(resolved.change.stateChangeId);
    result.add(
      CharacterSnapshotTimelineEntry(
        isBaseline: false,
        snapshot: CharacterStorySnapshot(
          characterId: characterId,
          resolvedTick: resolved.resolvedTick,
          sceneUUID: resolved.change.sceneUUID,
          sourcePlacementUUID: resolved.resolvedPlacementUUID,
          state: state,
          appliedStateChangeIds: applied,
        ),
        change: resolved.change,
        sceneName:
            sceneNames[resolved.change.sceneUUID] ?? resolved.change.sceneUUID,
        usesFallbackTick: resolved.usesFallbackTick,
      ),
    );
  }
  return List<CharacterSnapshotTimelineEntry>.unmodifiable(result);
}

Map<String, String> describeCharacterSnapshotDiff(
  CharacterSnapshotState previous,
  CharacterSnapshotState current,
) {
  final result = <String, String>{};
  void add(String label, Object previousValue, Object currentValue) {
    if (previousValue != currentValue) {
      result[label] = "$previousValue → $currentValue";
    }
  }

  if (!_listEquals(previous.conflicts, current.conflicts)) {
    result["阻礙"] =
        "${previous.conflicts.length} 筆 → ${current.conflicts.length} 筆";
  }
  if (!_listEquals(previous.relationships, current.relationships)) {
    result["人物關係"] =
        "${previous.relationships.length} 筆 → ${current.relationships.length} 筆";
  }
  if (!_listEquals(previous.organizations, current.organizations)) {
    result["組織"] =
        "${previous.organizations.length} 筆 → ${current.organizations.length} 筆";
  }
  if (!_listEquals(previous.statusEntries, current.statusEntries)) {
    result["角色狀態"] =
        "${previous.statusEntries.length} 筆 → ${current.statusEntries.length} 筆";
  }
  if (!_listEquals(previous.possessions, current.possessions)) {
    result["擁有物品"] =
        "${previous.possessions.length} 筆 → ${current.possessions.length} 筆";
  }
  final customKeys = {
    ...previous.customFields.keys,
    ...current.customFields.keys,
  };
  for (final key in customKeys) {
    add(
      "自訂欄位：$key",
      previous.customFields[key]?.displayValue ?? "",
      current.customFields[key]?.displayValue ?? "",
    );
  }
  return UnmodifiableMapView(result);
}

const Object _unset = Object();

bool _listEquals<T>(List<T> first, List<T> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

bool _mapEquals<K, V>(Map<K, V> first, Map<K, V> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (final entry in first.entries) {
    if (!second.containsKey(entry.key) || second[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

bool _nullableListEquals<T>(List<T>? first, List<T>? second) {
  if (first == null || second == null) return first == second;
  return _listEquals(first, second);
}

bool _nullableMapEquals<K, V>(Map<K, V>? first, Map<K, V>? second) {
  if (first == null || second == null) return first == second;
  return _mapEquals(first, second);
}
