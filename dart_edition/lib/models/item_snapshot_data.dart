import 'package:uuid/uuid.dart';
import 'item_data.dart';
import 'timeline_data.dart';
import 'story_state_time.dart';

enum StateValueOperation { inherit, clear, set }

/// A missing patch field leaves the existing override untouched. Inherit removes
/// that override, clear uses the field's empty default, and set stores a value.
class StateValue<T> extends ItemJsonValue {
  final StateValueOperation operation;
  final T? value;
  const StateValue.inherit()
    : operation = StateValueOperation.inherit,
      value = null;
  const StateValue.clear()
    : operation = StateValueOperation.clear,
      value = null;
  const StateValue.set(T this.value) : operation = StateValueOperation.set;
  factory StateValue.fromJson(
    Map<String, dynamic> json,
    T Function(Object?) decode,
  ) {
    switch (StateValueOperation.values.byName(json['operation'] as String)) {
      case StateValueOperation.inherit:
        return StateValue<T>.inherit();
      case StateValueOperation.clear:
        return StateValue<T>.clear();
      case StateValueOperation.set:
        return StateValue<T>.set(decode(json['value']));
    }
  }
  @override
  Map<String, dynamic> toJson() => {
    'operation': operation.name,
    if (operation == StateValueOperation.set) 'value': _encodeStateValue(value),
  };
  T resolve(T inherited, T empty) => switch (operation) {
    StateValueOperation.inherit => inherited,
    StateValueOperation.clear => empty,
    StateValueOperation.set => value as T,
  };
}

Object? _encodeStateValue(Object? value) => value is ItemJsonValue
    ? value.toJson()
    : value is List
    ? value.map(_encodeStateValue).toList()
    : value;

class ItemSnapshotState extends ItemJsonValue {
  final bool exists;
  final String name;
  final String description;
  final String status;
  final String? holderCharacterId;
  final String? locationId;
  final List<String> ownerCharacterIds;
  final Map<String, String> properties;
  final List<ItemAllocationData> allocations;
  ItemSnapshotState({
    this.exists = true,
    this.name = '',
    this.description = '',
    this.status = '',
    this.holderCharacterId = null,
    this.locationId = null,
    List<String> ownerCharacterIds = const [],
    Map<String, String> properties = const {},
    List<ItemAllocationData> allocations = const [],
  }) : ownerCharacterIds = List.unmodifiable(ownerCharacterIds),
       properties = Map.unmodifiable(properties),
       allocations = List.unmodifiable(allocations);
  ItemSnapshotState copyWith({
    bool? exists,
    String? name,
    String? description,
    String? status,
    Object? holderCharacterId = itemUnset,
    Object? locationId = itemUnset,
    List<String>? ownerCharacterIds,
    Map<String, String>? properties,
    List<ItemAllocationData>? allocations,
  }) => ItemSnapshotState(
    exists: exists ?? this.exists,
    name: name ?? this.name,
    description: description ?? this.description,
    status: status ?? this.status,
    holderCharacterId: identical(holderCharacterId, itemUnset)
        ? this.holderCharacterId
        : holderCharacterId as String?,
    locationId: identical(locationId, itemUnset)
        ? this.locationId
        : locationId as String?,
    ownerCharacterIds: ownerCharacterIds ?? this.ownerCharacterIds,
    properties: properties ?? this.properties,
    allocations: allocations ?? this.allocations,
  );
  factory ItemSnapshotState.fromJson(Map<String, dynamic> json) =>
      ItemSnapshotState(
        exists: json['exists'] as bool? ?? true,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        status: json['status'] as String? ?? '',
        holderCharacterId: json['holderCharacterId'] as String?,
        locationId: json['locationId'] as String?,
        ownerCharacterIds: List<String>.from(
          json['ownerCharacterIds'] as List? ?? const [],
        ),
        properties: Map<String, String>.from(
          json['properties'] as Map? ?? const {},
        ),
        allocations: (json['allocations'] as List? ?? const [])
            .map(
              (e) => ItemAllocationData.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList(),
      );
  @override
  Map<String, dynamic> toJson() => {
    'exists': exists,
    'name': name,
    'description': description,
    'status': status,
    'holderCharacterId': holderCharacterId,
    'locationId': locationId,
    'ownerCharacterIds': ownerCharacterIds,
    'properties': properties,
    'allocations': allocations.map((e) => e.toJson()).toList(),
  };
}

class ItemStatePatch extends ItemJsonValue {
  final StateValue<bool>? exists;
  final StateValue<String>? name;
  final StateValue<String>? description;
  final StateValue<String>? status;
  final StateValue<String?>? holderCharacterId;
  final StateValue<String?>? locationId;
  final StateValue<List<String>>? ownerCharacterIds;
  final StateValue<Map<String, String>>? properties;
  final StateValue<List<ItemAllocationData>>? allocations;
  ItemStatePatch({
    StateValue<bool>? exists,
    StateValue<String>? name,
    StateValue<String>? description,
    StateValue<String>? status,
    StateValue<String?>? holderCharacterId,
    StateValue<String?>? locationId,
    StateValue<List<String>>? ownerCharacterIds,
    StateValue<Map<String, String>>? properties,
    StateValue<List<ItemAllocationData>>? allocations,
  }) : exists = exists,
       name = name,
       description = description,
       status = status,
       holderCharacterId = holderCharacterId,
       locationId = locationId,
       ownerCharacterIds = ownerCharacterIds == null
           ? null
           : ownerCharacterIds.operation == StateValueOperation.set
           ? StateValue.set(List.unmodifiable(ownerCharacterIds.value!))
           : ownerCharacterIds,
       properties = properties == null
           ? null
           : properties.operation == StateValueOperation.set
           ? StateValue.set(Map.unmodifiable(properties.value!))
           : properties,
       allocations = allocations == null
           ? null
           : allocations.operation == StateValueOperation.set
           ? StateValue.set(List.unmodifiable(allocations.value!))
           : allocations;
  factory ItemStatePatch.fromState(ItemSnapshotState state) => ItemStatePatch(
    exists: StateValue.set(state.exists),
    name: StateValue.set(state.name),
    description: StateValue.set(state.description),
    status: StateValue.set(state.status),
    holderCharacterId: StateValue.set(state.holderCharacterId),
    locationId: StateValue.set(state.locationId),
    ownerCharacterIds: StateValue.set(state.ownerCharacterIds),
    properties: StateValue.set(state.properties),
    allocations: StateValue.set(state.allocations),
  );
  factory ItemStatePatch.fromJson(Map<String, dynamic> json) => ItemStatePatch(
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
    holderCharacterId: json['holderCharacterId'] == null
        ? null
        : StateValue<String?>.fromJson(
            Map<String, dynamic>.from(json['holderCharacterId'] as Map),
            (v) => v as String?,
          ),
    locationId: json['locationId'] == null
        ? null
        : StateValue<String?>.fromJson(
            Map<String, dynamic>.from(json['locationId'] as Map),
            (v) => v as String?,
          ),
    ownerCharacterIds: json['ownerCharacterIds'] == null
        ? null
        : StateValue<List<String>>.fromJson(
            Map<String, dynamic>.from(json['ownerCharacterIds'] as Map),
            (v) => List<String>.from(v as List),
          ),
    properties: json['properties'] == null
        ? null
        : StateValue<Map<String, String>>.fromJson(
            Map<String, dynamic>.from(json['properties'] as Map),
            (v) => Map<String, String>.from(v as Map),
          ),
    allocations: json['allocations'] == null
        ? null
        : StateValue<List<ItemAllocationData>>.fromJson(
            Map<String, dynamic>.from(json['allocations'] as Map),
            (v) => (v as List)
                .map(
                  (e) => ItemAllocationData.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList(),
          ),
  );
  @override
  Map<String, dynamic> toJson() => {
    if (exists != null) 'exists': exists!.toJson(),
    if (name != null) 'name': name!.toJson(),
    if (description != null) 'description': description!.toJson(),
    if (status != null) 'status': status!.toJson(),
    if (holderCharacterId != null)
      'holderCharacterId': holderCharacterId!.toJson(),
    if (locationId != null) 'locationId': locationId!.toJson(),
    if (ownerCharacterIds != null)
      'ownerCharacterIds': ownerCharacterIds!.toJson(),
    if (properties != null) 'properties': properties!.toJson(),
    if (allocations != null) 'allocations': allocations!.toJson(),
  };
  bool get isEmpty =>
      exists == null &&
      name == null &&
      description == null &&
      status == null &&
      holderCharacterId == null &&
      locationId == null &&
      ownerCharacterIds == null &&
      properties == null &&
      allocations == null;

  /// Merge changes to the override layer before resolving against the current Class.
  ItemStatePatch merge(ItemStatePatch next) => ItemStatePatch(
    exists: next.exists ?? exists,
    name: next.name ?? name,
    description: next.description ?? description,
    status: next.status ?? status,
    holderCharacterId: next.holderCharacterId ?? holderCharacterId,
    locationId: next.locationId ?? locationId,
    ownerCharacterIds: next.ownerCharacterIds ?? ownerCharacterIds,
    properties: next.properties ?? properties,
    allocations: next.allocations ?? allocations,
  );
  ItemStatePatch copyWith({
    Object? exists = itemUnset,
    Object? name = itemUnset,
    Object? description = itemUnset,
    Object? status = itemUnset,
    Object? holderCharacterId = itemUnset,
    Object? locationId = itemUnset,
    Object? ownerCharacterIds = itemUnset,
    Object? properties = itemUnset,
    Object? allocations = itemUnset,
  }) => ItemStatePatch(
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
    holderCharacterId: identical(holderCharacterId, itemUnset)
        ? this.holderCharacterId
        : holderCharacterId as StateValue<String?>?,
    locationId: identical(locationId, itemUnset)
        ? this.locationId
        : locationId as StateValue<String?>?,
    ownerCharacterIds: identical(ownerCharacterIds, itemUnset)
        ? this.ownerCharacterIds
        : ownerCharacterIds as StateValue<List<String>>?,
    properties: identical(properties, itemUnset)
        ? this.properties
        : properties as StateValue<Map<String, String>>?,
    allocations: identical(allocations, itemUnset)
        ? this.allocations
        : allocations as StateValue<List<ItemAllocationData>>?,
  );
  ItemSnapshotState applyTo(
    ItemSnapshotState source, {
    ItemSnapshotState? inherited,
  }) {
    final defaults = ItemSnapshotState();
    return ItemSnapshotState(
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
      holderCharacterId:
          holderCharacterId?.resolve(
            (inherited ?? defaults).holderCharacterId,
            defaults.holderCharacterId,
          ) ??
          source.holderCharacterId,
      locationId:
          locationId?.resolve(
            (inherited ?? defaults).locationId,
            defaults.locationId,
          ) ??
          source.locationId,
      ownerCharacterIds:
          ownerCharacterIds?.resolve(
            (inherited ?? defaults).ownerCharacterIds,
            defaults.ownerCharacterIds,
          ) ??
          source.ownerCharacterIds,
      properties:
          properties?.resolve(
            (inherited ?? defaults).properties,
            defaults.properties,
          ) ??
          source.properties,
      allocations:
          allocations?.resolve(
            (inherited ?? defaults).allocations,
            defaults.allocations,
          ) ??
          source.allocations,
    );
  }
}

class ItemClassStateChange extends ItemJsonValue {
  final String stateChangeId;
  final String classId;
  final String sceneUUID;
  final String? sourcePlacementUUID;
  final int fallbackTick;
  final int sequence;
  final ItemStatePatch patch;
  final String note;
  ItemClassStateChange({
    String? stateChangeId,
    required this.classId,
    required this.sceneUUID,
    this.sourcePlacementUUID,
    this.fallbackTick = 0,
    this.sequence = 0,
    ItemStatePatch? patch,
    this.note = '',
  }) : stateChangeId = stateChangeId ?? const Uuid().v4(),
       patch = patch ?? ItemStatePatch();
  StoryStateTimeAnchor get anchor => StoryStateTimeAnchor(
    sceneUUID: sceneUUID,
    sourcePlacementUUID: sourcePlacementUUID,
    fallbackTick: fallbackTick,
  );
  ItemClassStateChange copyWith({
    String? stateChangeId,
    String? classId,
    String? sceneUUID,
    Object? sourcePlacementUUID = itemUnset,
    int? fallbackTick,
    int? sequence,
    ItemStatePatch? patch,
    String? note,
  }) => ItemClassStateChange(
    stateChangeId: stateChangeId ?? this.stateChangeId,
    classId: classId ?? this.classId,
    sceneUUID: sceneUUID ?? this.sceneUUID,
    sourcePlacementUUID: identical(sourcePlacementUUID, itemUnset)
        ? this.sourcePlacementUUID
        : sourcePlacementUUID as String?,
    fallbackTick: fallbackTick ?? this.fallbackTick,
    sequence: sequence ?? this.sequence,
    patch: patch ?? this.patch,
    note: note ?? this.note,
  );
  factory ItemClassStateChange.fromJson(Map<String, dynamic> json) =>
      ItemClassStateChange(
        stateChangeId: json['stateChangeId'] as String?,
        classId: json['classId'] as String,
        sceneUUID: json['sceneUUID'] as String,
        sourcePlacementUUID: json['sourcePlacementUUID'] as String?,
        fallbackTick: json['fallbackTick'] as int? ?? 0,
        sequence: json['sequence'] as int? ?? 0,
        patch: ItemStatePatch.fromJson(
          Map<String, dynamic>.from(json['patch'] as Map? ?? const {}),
        ),
        note: json['note'] as String? ?? '',
      );
  @override
  Map<String, dynamic> toJson() => {
    'stateChangeId': stateChangeId,
    'classId': classId,
    'sceneUUID': sceneUUID,
    'sourcePlacementUUID': sourcePlacementUUID,
    'fallbackTick': fallbackTick,
    'sequence': sequence,
    'patch': patch.toJson(),
    'note': note,
  };
}

class ItemInstanceStateChange extends ItemJsonValue {
  final String stateChangeId;
  final String instanceId;
  final String sceneUUID;
  final String? sourcePlacementUUID;
  final int fallbackTick;
  final int sequence;
  final ItemStatePatch patch;
  final String note;
  ItemInstanceStateChange({
    String? stateChangeId,
    required this.instanceId,
    required this.sceneUUID,
    this.sourcePlacementUUID,
    this.fallbackTick = 0,
    this.sequence = 0,
    ItemStatePatch? patch,
    this.note = '',
  }) : stateChangeId = stateChangeId ?? const Uuid().v4(),
       patch = patch ?? ItemStatePatch();
  StoryStateTimeAnchor get anchor => StoryStateTimeAnchor(
    sceneUUID: sceneUUID,
    sourcePlacementUUID: sourcePlacementUUID,
    fallbackTick: fallbackTick,
  );
  ItemInstanceStateChange copyWith({
    String? stateChangeId,
    String? instanceId,
    String? sceneUUID,
    Object? sourcePlacementUUID = itemUnset,
    int? fallbackTick,
    int? sequence,
    ItemStatePatch? patch,
    String? note,
  }) => ItemInstanceStateChange(
    stateChangeId: stateChangeId ?? this.stateChangeId,
    instanceId: instanceId ?? this.instanceId,
    sceneUUID: sceneUUID ?? this.sceneUUID,
    sourcePlacementUUID: identical(sourcePlacementUUID, itemUnset)
        ? this.sourcePlacementUUID
        : sourcePlacementUUID as String?,
    fallbackTick: fallbackTick ?? this.fallbackTick,
    sequence: sequence ?? this.sequence,
    patch: patch ?? this.patch,
    note: note ?? this.note,
  );
  factory ItemInstanceStateChange.fromJson(Map<String, dynamic> json) =>
      ItemInstanceStateChange(
        stateChangeId: json['stateChangeId'] as String?,
        instanceId: json['instanceId'] as String,
        sceneUUID: json['sceneUUID'] as String,
        sourcePlacementUUID: json['sourcePlacementUUID'] as String?,
        fallbackTick: json['fallbackTick'] as int? ?? 0,
        sequence: json['sequence'] as int? ?? 0,
        patch: ItemStatePatch.fromJson(
          Map<String, dynamic>.from(json['patch'] as Map? ?? const {}),
        ),
        note: json['note'] as String? ?? '',
      );
  @override
  Map<String, dynamic> toJson() => {
    'stateChangeId': stateChangeId,
    'instanceId': instanceId,
    'sceneUUID': sceneUUID,
    'sourcePlacementUUID': sourcePlacementUUID,
    'fallbackTick': fallbackTick,
    'sequence': sequence,
    'patch': patch.toJson(),
    'note': note,
  };
}

ResolvedStoryStateTime resolveItemClassStateChangeTime(
  ItemClassStateChange change,
  TimelineDocumentData timeline,
) => resolveStoryStateTime(change.anchor, timeline);
List<ResolvedStoryStateChange<ItemClassStateChange>>
orderedItemClassStateChanges({
  required String classId,
  required Iterable<ItemClassStateChange> changes,
  required TimelineDocumentData timeline,
}) {
  final result = changes
      .where((c) => c.classId == classId)
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

ResolvedStoryStateTime resolveItemInstanceStateChangeTime(
  ItemInstanceStateChange change,
  TimelineDocumentData timeline,
) => resolveStoryStateTime(change.anchor, timeline);
List<ResolvedStoryStateChange<ItemInstanceStateChange>>
orderedItemInstanceStateChanges({
  required String instanceId,
  required Iterable<ItemInstanceStateChange> changes,
  required TimelineDocumentData timeline,
}) {
  final result = changes
      .where((c) => c.instanceId == instanceId)
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

/// [throughStateChangeId] includes that event and stops before later changes,
/// including other changes at the same Tick, when copying a selected snapshot.
ItemSnapshotState resolveItemClassSnapshot({
  required ItemClassData itemClass,
  required Iterable<ItemClassStateChange> changes,
  required TimelineDocumentData timeline,
  required int atTick,
  String? throughStateChangeId,
}) {
  var state = itemClass.defaultState;
  for (final entry in orderedItemClassStateChanges(
    classId: itemClass.classId,
    changes: changes,
    timeline: timeline,
  )) {
    if (entry.time.resolvedTick > atTick) break;
    state = entry.change.patch.applyTo(
      state,
      inherited: itemClass.defaultState,
    );
    if (entry.change.stateChangeId == throughStateChangeId) break;
  }
  return state;
}

/// Optional event IDs bound the instance overrides and inherited Class state
/// independently when copying a selected snapshot.
ItemSnapshotState resolveItemInstanceSnapshot({
  required ItemClassData itemClass,
  required ItemInstanceData instance,
  Iterable<ItemClassStateChange> classChanges = const [],
  Iterable<ItemInstanceStateChange> instanceChanges = const [],
  required TimelineDocumentData timeline,
  required int atTick,
  String? throughStateChangeId,
  String? throughClassStateChangeId,
}) {
  if (instance.classId != itemClass.classId)
    throw ArgumentError('Instance belongs to another Class');
  final inherited = resolveItemClassSnapshot(
    itemClass: itemClass,
    changes: classChanges,
    timeline: timeline,
    atTick: atTick,
    throughStateChangeId: throughClassStateChangeId,
  );
  var overrides = instance.defaultState;
  for (final entry in orderedItemInstanceStateChanges(
    instanceId: instance.instanceId,
    changes: instanceChanges,
    timeline: timeline,
  )) {
    if (entry.time.resolvedTick > atTick) break;
    overrides = overrides.merge(entry.change.patch);
    if (entry.change.stateChangeId == throughStateChangeId) break;
  }
  return overrides.applyTo(inherited, inherited: inherited);
}
