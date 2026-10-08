import 'package:uuid/uuid.dart';
import 'item_data.dart';
import 'item_snapshot_data.dart';
import 'story_state_time.dart';
import 'timeline_data.dart';

class LocationSnapshotState extends ItemJsonValue {
  final bool exists;
  final String name;
  final String description;
  final String status;
  final String? controllerCharacterId;
  final bool accessible;
  final Map<String, String> properties;
  LocationSnapshotState({
    this.exists = true,
    this.name = '',
    this.description = '',
    this.status = '',
    this.controllerCharacterId = null,
    this.accessible = true,
    Map<String, String> properties = const {},
  }) : properties = Map.unmodifiable(properties);
  LocationSnapshotState copyWith({
    bool? exists,
    String? name,
    String? description,
    String? status,
    Object? controllerCharacterId = itemUnset,
    bool? accessible,
    Map<String, String>? properties,
  }) => LocationSnapshotState(
    exists: exists ?? this.exists,
    name: name ?? this.name,
    description: description ?? this.description,
    status: status ?? this.status,
    controllerCharacterId: identical(controllerCharacterId, itemUnset)
        ? this.controllerCharacterId
        : controllerCharacterId as String?,
    accessible: accessible ?? this.accessible,
    properties: properties ?? this.properties,
  );
  factory LocationSnapshotState.fromJson(Map<String, dynamic> json) =>
      LocationSnapshotState(
        exists: json['exists'] as bool? ?? true,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        status: json['status'] as String? ?? '',
        controllerCharacterId: json['controllerCharacterId'] as String?,
        accessible: json['accessible'] as bool? ?? true,
        properties: Map<String, String>.from(
          json['properties'] as Map? ?? const {},
        ),
      );
  @override
  Map<String, dynamic> toJson() => {
    'exists': exists,
    'name': name,
    'description': description,
    'status': status,
    'controllerCharacterId': controllerCharacterId,
    'accessible': accessible,
    'properties': properties,
  };
}

class LocationStatePatch extends ItemJsonValue {
  final StateValue<bool>? exists;
  final StateValue<String>? name;
  final StateValue<String>? description;
  final StateValue<String>? status;
  final StateValue<String?>? controllerCharacterId;
  final StateValue<bool>? accessible;
  final StateValue<Map<String, String>>? properties;
  LocationStatePatch({
    StateValue<bool>? exists,
    StateValue<String>? name,
    StateValue<String>? description,
    StateValue<String>? status,
    StateValue<String?>? controllerCharacterId,
    StateValue<bool>? accessible,
    StateValue<Map<String, String>>? properties,
  }) : exists = exists,
       name = name,
       description = description,
       status = status,
       controllerCharacterId = controllerCharacterId,
       accessible = accessible,
       properties = properties == null
           ? null
           : properties.operation == StateValueOperation.set
           ? StateValue.set(Map.unmodifiable(properties.value!))
           : properties;
  factory LocationStatePatch.fromState(LocationSnapshotState state) =>
      LocationStatePatch(
        exists: StateValue.set(state.exists),
        name: StateValue.set(state.name),
        description: StateValue.set(state.description),
        status: StateValue.set(state.status),
        controllerCharacterId: StateValue.set(state.controllerCharacterId),
        accessible: StateValue.set(state.accessible),
        properties: StateValue.set(state.properties),
      );
  factory LocationStatePatch.fromJson(Map<String, dynamic> json) =>
      LocationStatePatch(
        exists: json['exists'] == null
            ? null
            : StateValue<bool>.fromJson(
                Map<String, dynamic>.from(json['exists'] as Map),
                (v) => v as bool,
              ),
        name: json['name'] == null
            ? null
            : StateValue<String>.fromJson(
                Map<String, dynamic>.from(json['name'] as Map),
                (v) => v as String,
              ),
        description: json['description'] == null
            ? null
            : StateValue<String>.fromJson(
                Map<String, dynamic>.from(json['description'] as Map),
                (v) => v as String,
              ),
        status: json['status'] == null
            ? null
            : StateValue<String>.fromJson(
                Map<String, dynamic>.from(json['status'] as Map),
                (v) => v as String,
              ),
        controllerCharacterId: json['controllerCharacterId'] == null
            ? null
            : StateValue<String?>.fromJson(
                Map<String, dynamic>.from(json['controllerCharacterId'] as Map),
                (v) => v as String?,
              ),
        accessible: json['accessible'] == null
            ? null
            : StateValue<bool>.fromJson(
                Map<String, dynamic>.from(json['accessible'] as Map),
                (v) => v as bool,
              ),
        properties: json['properties'] == null
            ? null
            : StateValue<Map<String, String>>.fromJson(
                Map<String, dynamic>.from(json['properties'] as Map),
                (v) => Map<String, String>.from(v as Map),
              ),
      );
  @override
  Map<String, dynamic> toJson() => {
    if (exists != null) 'exists': exists!.toJson(),
    if (name != null) 'name': name!.toJson(),
    if (description != null) 'description': description!.toJson(),
    if (status != null) 'status': status!.toJson(),
    if (controllerCharacterId != null)
      'controllerCharacterId': controllerCharacterId!.toJson(),
    if (accessible != null) 'accessible': accessible!.toJson(),
    if (properties != null) 'properties': properties!.toJson(),
  };
  bool get isEmpty =>
      exists == null &&
      name == null &&
      description == null &&
      status == null &&
      controllerCharacterId == null &&
      accessible == null &&
      properties == null;

  /// Merge changes to the override layer before resolving against the current Class.
  LocationStatePatch merge(LocationStatePatch next) => LocationStatePatch(
    exists: next.exists ?? exists,
    name: next.name ?? name,
    description: next.description ?? description,
    status: next.status ?? status,
    controllerCharacterId: next.controllerCharacterId ?? controllerCharacterId,
    accessible: next.accessible ?? accessible,
    properties: next.properties ?? properties,
  );
  LocationStatePatch copyWith({
    Object? exists = itemUnset,
    Object? name = itemUnset,
    Object? description = itemUnset,
    Object? status = itemUnset,
    Object? controllerCharacterId = itemUnset,
    Object? accessible = itemUnset,
    Object? properties = itemUnset,
  }) => LocationStatePatch(
    exists: identical(exists, itemUnset)
        ? this.exists
        : exists as StateValue<bool>?,
    name: identical(name, itemUnset) ? this.name : name as StateValue<String>?,
    description: identical(description, itemUnset)
        ? this.description
        : description as StateValue<String>?,
    status: identical(status, itemUnset)
        ? this.status
        : status as StateValue<String>?,
    controllerCharacterId: identical(controllerCharacterId, itemUnset)
        ? this.controllerCharacterId
        : controllerCharacterId as StateValue<String?>?,
    accessible: identical(accessible, itemUnset)
        ? this.accessible
        : accessible as StateValue<bool>?,
    properties: identical(properties, itemUnset)
        ? this.properties
        : properties as StateValue<Map<String, String>>?,
  );
  LocationSnapshotState applyTo(
    LocationSnapshotState source, {
    LocationSnapshotState? inherited,
  }) {
    final defaults = LocationSnapshotState();
    return LocationSnapshotState(
      exists:
          exists?.resolve((inherited ?? defaults).exists, defaults.exists) ??
          source.exists,
      name:
          name?.resolve((inherited ?? defaults).name, defaults.name) ??
          source.name,
      description:
          description?.resolve(
            (inherited ?? defaults).description,
            defaults.description,
          ) ??
          source.description,
      status:
          status?.resolve((inherited ?? defaults).status, defaults.status) ??
          source.status,
      controllerCharacterId:
          controllerCharacterId?.resolve(
            (inherited ?? defaults).controllerCharacterId,
            defaults.controllerCharacterId,
          ) ??
          source.controllerCharacterId,
      accessible:
          accessible?.resolve(
            (inherited ?? defaults).accessible,
            defaults.accessible,
          ) ??
          source.accessible,
      properties:
          properties?.resolve(
            (inherited ?? defaults).properties,
            defaults.properties,
          ) ??
          source.properties,
    );
  }
}

class LocationStateChange extends ItemJsonValue {
  final String stateChangeId;
  final String locationId;
  final String sceneUUID;
  final String? sourcePlacementUUID;
  final int fallbackTick;
  final int sequence;
  final String? transactionId;
  final LocationStatePatch patch;
  final String note;
  LocationStateChange({
    String? stateChangeId,
    required this.locationId,
    required this.sceneUUID,
    this.sourcePlacementUUID,
    this.fallbackTick = 0,
    this.sequence = 0,
    this.transactionId,
    LocationStatePatch? patch,
    this.note = '',
  }) : stateChangeId = stateChangeId ?? const Uuid().v4(),
       patch = patch ?? LocationStatePatch();
  StoryStateTimeAnchor get anchor => StoryStateTimeAnchor(
    sceneUUID: sceneUUID,
    sourcePlacementUUID: sourcePlacementUUID,
    fallbackTick: fallbackTick,
  );
  LocationStateChange copyWith({
    String? stateChangeId,
    String? locationId,
    String? sceneUUID,
    Object? sourcePlacementUUID = itemUnset,
    int? fallbackTick,
    int? sequence,
    Object? transactionId = itemUnset,
    LocationStatePatch? patch,
    String? note,
  }) => LocationStateChange(
    stateChangeId: stateChangeId ?? this.stateChangeId,
    locationId: locationId ?? this.locationId,
    sceneUUID: sceneUUID ?? this.sceneUUID,
    sourcePlacementUUID: identical(sourcePlacementUUID, itemUnset)
        ? this.sourcePlacementUUID
        : sourcePlacementUUID as String?,
    fallbackTick: fallbackTick ?? this.fallbackTick,
    sequence: sequence ?? this.sequence,
    transactionId: identical(transactionId, itemUnset)
        ? this.transactionId
        : transactionId as String?,
    patch: patch ?? this.patch,
    note: note ?? this.note,
  );
  factory LocationStateChange.fromJson(Map<String, dynamic> json) =>
      LocationStateChange(
        stateChangeId: json['stateChangeId'] as String?,
        locationId: json['locationId'] as String,
        sceneUUID: json['sceneUUID'] as String,
        sourcePlacementUUID: json['sourcePlacementUUID'] as String?,
        fallbackTick: json['fallbackTick'] as int? ?? 0,
        sequence: json['sequence'] as int? ?? 0,
        transactionId: json['transactionId'] as String?,
        patch: LocationStatePatch.fromJson(
          Map<String, dynamic>.from(json['patch'] as Map? ?? const {}),
        ),
        note: json['note'] as String? ?? '',
      );
  @override
  Map<String, dynamic> toJson() => {
    'stateChangeId': stateChangeId,
    'locationId': locationId,
    'sceneUUID': sceneUUID,
    'sourcePlacementUUID': sourcePlacementUUID,
    'fallbackTick': fallbackTick,
    'sequence': sequence,
    'transactionId': transactionId,
    'patch': patch.toJson(),
    'note': note,
  };
}

ResolvedStoryStateTime resolveLocationStateChangeTime(
  LocationStateChange change,
  TimelineDocumentData timeline,
) => resolveStoryStateTime(change.anchor, timeline);
List<ResolvedStoryStateChange<LocationStateChange>>
orderedLocationStateChanges({
  required String locationId,
  required Iterable<LocationStateChange> changes,
  required TimelineDocumentData timeline,
}) {
  final result = changes
      .where((c) => c.locationId == locationId)
      .map(
        (c) => ResolvedStoryStateChange(
          c,
          resolveStoryStateTime(c.anchor, timeline),
        ),
      )
      .toList();
  result.sort(
    (a, b) => compareStoryStateTime(
      leftTick: a.time.resolvedTick,
      leftSequence: a.change.sequence,
      leftId: a.change.stateChangeId,
      rightTick: b.time.resolvedTick,
      rightSequence: b.change.sequence,
      rightId: b.change.stateChangeId,
    ),
  );
  return List.unmodifiable(result);
}

/// Resolve one node only: editing-tree parents never affect historical state.
/// [throughStateChangeId] stops after the selected event when copying a snapshot.
LocationSnapshotState resolveLocationSnapshot({
  required String locationId,
  LocationSnapshotState? defaultState,
  required Iterable<LocationStateChange> changes,
  required TimelineDocumentData timeline,
  required int atTick,
  String? throughStateChangeId,
}) {
  final defaults = defaultState ?? LocationSnapshotState();
  var state = defaults;
  for (final entry in orderedLocationStateChanges(
    locationId: locationId,
    changes: changes,
    timeline: timeline,
  )) {
    if (entry.time.resolvedTick > atTick) break;
    state = entry.change.patch.applyTo(state, inherited: defaults);
    if (entry.change.stateChangeId == throughStateChangeId) break;
  }
  return state;
}
