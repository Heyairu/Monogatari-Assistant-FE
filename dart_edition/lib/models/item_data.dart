import 'item_snapshot_data.dart';

enum ItemMode { dedicated, semiDedicated, generic }

enum ItemReferenceKind { itemClass, instance }

enum ItemRelationTargetKind { character, location, event, scene }

const Object itemUnset = Object();

/// Structural equality for immutable persisted values.
abstract class ItemJsonValue {
  const ItemJsonValue();
  Map<String, dynamic> toJson();
  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is ItemJsonValue &&
      _equal(toJson(), other.toJson());
  @override
  int get hashCode => Object.hash(runtimeType, _hash(toJson()));
}

bool _equal(Object? a, Object? b) {
  if (a is Map && b is Map)
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && _equal(a[k], b[k]));
  if (a is List && b is List)
    return a.length == b.length &&
        List.generate(a.length, (i) => i).every((i) => _equal(a[i], b[i]));
  return a == b;
}

int _hash(Object? v) => v is Map
    ? Object.hashAllUnordered(
        v.entries.map((e) => Object.hash(e.key, _hash(e.value))),
      )
    : v is List
    ? Object.hashAll(v.map(_hash))
    : v.hashCode;

class ItemAllocationData extends ItemJsonValue {
  final String allocationId;
  final String? holderCharacterId;
  final String? locationId;
  final int? quantity;
  final String note;
  ItemAllocationData({
    this.allocationId = '',
    this.holderCharacterId = null,
    this.locationId = null,
    this.quantity = null,
    this.note = '',
  }) {
    if (quantity != null && quantity! < 0)
      throw ArgumentError.value(
        quantity,
        'quantity',
        'must be non-negative or unknown',
      );
  }
  ItemAllocationData copyWith({
    String? allocationId,
    Object? holderCharacterId = itemUnset,
    Object? locationId = itemUnset,
    Object? quantity = itemUnset,
    String? note,
  }) => ItemAllocationData(
    allocationId: allocationId ?? this.allocationId,
    holderCharacterId: identical(holderCharacterId, itemUnset)
        ? this.holderCharacterId
        : holderCharacterId as String?,
    locationId: identical(locationId, itemUnset)
        ? this.locationId
        : locationId as String?,
    quantity: identical(quantity, itemUnset) ? this.quantity : quantity as int?,
    note: note ?? this.note,
  );
  factory ItemAllocationData.fromJson(Map<String, dynamic> json) =>
      ItemAllocationData(
        allocationId: json['allocationId'] as String? ?? '',
        holderCharacterId: json['holderCharacterId'] as String?,
        locationId: json['locationId'] as String?,
        quantity: json['quantity'] as int?,
        note: json['note'] as String? ?? '',
      );
  @override
  Map<String, dynamic> toJson() => {
    'allocationId': allocationId,
    'holderCharacterId': holderCharacterId,
    'locationId': locationId,
    'quantity': quantity,
    'note': note,
  };
}

class ItemConversionSourceData extends ItemJsonValue {
  final String sourceClassId;
  final List<String> sourceInstanceIds;
  final String? sceneUUID;
  final String conversionId;
  final String sourcePath;
  final String note;
  ItemConversionSourceData({
    this.sourceClassId = '',
    List<String> sourceInstanceIds = const [],
    this.sceneUUID = null,
    this.conversionId = '',
    this.sourcePath = '',
    this.note = '',
  }) : sourceInstanceIds = List.unmodifiable(sourceInstanceIds);
  ItemConversionSourceData copyWith({
    String? sourceClassId,
    List<String>? sourceInstanceIds,
    Object? sceneUUID = itemUnset,
    String? conversionId,
    String? sourcePath,
    String? note,
  }) => ItemConversionSourceData(
    sourceClassId: sourceClassId ?? this.sourceClassId,
    sourceInstanceIds: sourceInstanceIds ?? this.sourceInstanceIds,
    sceneUUID: identical(sceneUUID, itemUnset)
        ? this.sceneUUID
        : sceneUUID as String?,
    conversionId: conversionId ?? this.conversionId,
    sourcePath: sourcePath ?? this.sourcePath,
    note: note ?? this.note,
  );
  factory ItemConversionSourceData.fromJson(Map<String, dynamic> json) =>
      ItemConversionSourceData(
        sourceClassId: json['sourceClassId'] as String? ?? '',
        sourceInstanceIds: List<String>.from(
          json['sourceInstanceIds'] as List? ?? const [],
        ),
        sceneUUID: json['sceneUUID'] as String?,
        conversionId: json['conversionId'] as String? ?? '',
        sourcePath: json['sourcePath'] as String? ?? '',
        note: json['note'] as String? ?? '',
      );
  @override
  Map<String, dynamic> toJson() => {
    'sourceClassId': sourceClassId,
    'sourceInstanceIds': sourceInstanceIds,
    'sceneUUID': sceneUUID,
    'conversionId': conversionId,
    'sourcePath': sourcePath,
    'note': note,
  };
}

class ItemClassData extends ItemJsonValue {
  final String classId;
  final String name;
  final String description;
  final String category;
  final String unit;
  final ItemMode mode;
  final ItemSnapshotState defaultState;
  final bool archived;
  final ItemConversionSourceData? conversionSource;
  ItemClassData({
    required this.classId,
    this.name = '',
    this.description = '',
    this.category = '',
    this.unit = '',
    this.mode = ItemMode.dedicated,
    ItemSnapshotState? defaultState,
    this.archived = false,
    this.conversionSource = null,
  }) : defaultState = defaultState ?? ItemSnapshotState();
  ItemClassData copyWith({
    String? classId,
    String? name,
    String? description,
    String? category,
    String? unit,
    ItemMode? mode,
    ItemSnapshotState? defaultState,
    bool? archived,
    Object? conversionSource = itemUnset,
  }) => ItemClassData(
    classId: classId ?? this.classId,
    name: name ?? this.name,
    description: description ?? this.description,
    category: category ?? this.category,
    unit: unit ?? this.unit,
    mode: mode ?? this.mode,
    defaultState: defaultState ?? this.defaultState,
    archived: archived ?? this.archived,
    conversionSource: identical(conversionSource, itemUnset)
        ? this.conversionSource
        : conversionSource as ItemConversionSourceData?,
  );
  factory ItemClassData.fromJson(Map<String, dynamic> json) => ItemClassData(
    classId: json['classId'] as String? ?? '',
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    category: json['category'] as String? ?? '',
    unit: json['unit'] as String? ?? '',
    mode: ItemMode.values.byName(
      json['mode'] as String? ?? ItemMode.dedicated.name,
    ),
    defaultState: ItemSnapshotState.fromJson(
      Map<String, dynamic>.from(json['defaultState'] as Map? ?? const {}),
    ),
    archived: json['archived'] as bool? ?? false,
    conversionSource: json['conversionSource'] == null
        ? null
        : ItemConversionSourceData.fromJson(
            Map<String, dynamic>.from(json['conversionSource'] as Map),
          ),
  );
  @override
  Map<String, dynamic> toJson() => {
    'classId': classId,
    'name': name,
    'description': description,
    'category': category,
    'unit': unit,
    'mode': mode.name,
    'defaultState': defaultState.toJson(),
    'archived': archived,
    'conversionSource': conversionSource?.toJson(),
  };
}

class ItemInstanceData extends ItemJsonValue {
  final String instanceId;
  final String classId;
  final String name;
  final ItemStatePatch defaultState;
  final bool archived;
  final ItemConversionSourceData? conversionSource;
  ItemInstanceData({
    required this.instanceId,
    required this.classId,
    this.name = '',
    ItemStatePatch? defaultState,
    this.archived = false,
    this.conversionSource = null,
  }) : defaultState = defaultState ?? ItemStatePatch();
  ItemInstanceData copyWith({
    String? instanceId,
    String? classId,
    String? name,
    ItemStatePatch? defaultState,
    bool? archived,
    Object? conversionSource = itemUnset,
  }) => ItemInstanceData(
    instanceId: instanceId ?? this.instanceId,
    classId: classId ?? this.classId,
    name: name ?? this.name,
    defaultState: defaultState ?? this.defaultState,
    archived: archived ?? this.archived,
    conversionSource: identical(conversionSource, itemUnset)
        ? this.conversionSource
        : conversionSource as ItemConversionSourceData?,
  );
  factory ItemInstanceData.fromJson(Map<String, dynamic> json) =>
      ItemInstanceData(
        instanceId: json['instanceId'] as String? ?? '',
        classId: json['classId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        defaultState: ItemStatePatch.fromJson(
          Map<String, dynamic>.from(json['defaultState'] as Map? ?? const {}),
        ),
        archived: json['archived'] as bool? ?? false,
        conversionSource: json['conversionSource'] == null
            ? null
            : ItemConversionSourceData.fromJson(
                Map<String, dynamic>.from(json['conversionSource'] as Map),
              ),
      );
  @override
  Map<String, dynamic> toJson() => {
    'instanceId': instanceId,
    'classId': classId,
    'name': name,
    'defaultState': defaultState.toJson(),
    'archived': archived,
    'conversionSource': conversionSource?.toJson(),
  };
}

class ItemRelationData extends ItemJsonValue {
  final String relationId;
  final String itemId;
  final ItemReferenceKind itemKind;
  final String targetId;
  final ItemRelationTargetKind targetKind;
  final String role;
  final String note;
  ItemRelationData({
    required this.relationId,
    required this.itemId,
    this.itemKind = ItemReferenceKind.instance,
    required this.targetId,
    this.targetKind = ItemRelationTargetKind.event,
    this.role = '',
    this.note = '',
  });
  ItemRelationData copyWith({
    String? relationId,
    String? itemId,
    ItemReferenceKind? itemKind,
    String? targetId,
    ItemRelationTargetKind? targetKind,
    String? role,
    String? note,
  }) => ItemRelationData(
    relationId: relationId ?? this.relationId,
    itemId: itemId ?? this.itemId,
    itemKind: itemKind ?? this.itemKind,
    targetId: targetId ?? this.targetId,
    targetKind: targetKind ?? this.targetKind,
    role: role ?? this.role,
    note: note ?? this.note,
  );
  factory ItemRelationData.fromJson(Map<String, dynamic> json) =>
      ItemRelationData(
        relationId: json['relationId'] as String? ?? '',
        itemId: json['itemId'] as String? ?? '',
        itemKind: ItemReferenceKind.values.byName(
          json['itemKind'] as String? ?? ItemReferenceKind.instance.name,
        ),
        targetId: json['targetId'] as String? ?? '',
        targetKind: ItemRelationTargetKind.values.byName(
          json['targetKind'] as String? ?? ItemRelationTargetKind.event.name,
        ),
        role: json['role'] as String? ?? '',
        note: json['note'] as String? ?? '',
      );
  @override
  Map<String, dynamic> toJson() => {
    'relationId': relationId,
    'itemId': itemId,
    'itemKind': itemKind.name,
    'targetId': targetId,
    'targetKind': targetKind.name,
    'role': role,
    'note': note,
  };
}
