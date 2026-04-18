import "package:freezed_annotation/freezed_annotation.dart";
import "package:uuid/uuid.dart";

part "world_settings_data.freezed.dart";

String _generateWorldSettingsId() {
  return const Uuid().v4();
}

enum WorldNodeType { location, organization, rule, item }

extension WorldNodeTypeX on WorldNodeType {
  String get xmlValue {
    switch (this) {
      case WorldNodeType.location:
        return "location";
      case WorldNodeType.organization:
        return "organization";
      case WorldNodeType.rule:
        return "rule";
      case WorldNodeType.item:
        return "item";
    }
  }

  String get label {
    switch (this) {
      case WorldNodeType.location:
        return "地點";
      case WorldNodeType.organization:
        return "組織";
      case WorldNodeType.rule:
        return "規則";
      case WorldNodeType.item:
        return "物品";
    }
  }
}

WorldNodeType parseWorldNodeType(String? raw) {
  switch ((raw ?? "").trim().toLowerCase()) {
    case "organization":
    case "組織":
      return WorldNodeType.organization;
    case "rule":
    case "規則":
      return WorldNodeType.rule;
    case "item":
    case "物品":
      return WorldNodeType.item;
    case "location":
    case "地點":
    default:
      return WorldNodeType.location;
  }
}

@Freezed(makeCollectionsUnmodifiable: false)
class LocationCustomize with _$LocationCustomize {
  const LocationCustomize._();

  const factory LocationCustomize.raw({
    required String id,
    @Default("") String key,
    @Default("") String val,
  }) = _LocationCustomize;

  factory LocationCustomize({String? id, String key = "", String val = ""}) {
    final resolvedId = id?.trim().isNotEmpty == true
        ? id!.trim()
        : _generateWorldSettingsId();

    return LocationCustomize.raw(id: resolvedId, key: key, val: val);
  }

  factory LocationCustomize.fromJson(Map<String, dynamic> json) {
    return LocationCustomize(
      id: json["id"] as String?,
      key: json["key"] as String? ?? "",
      val: json["val"] as String? ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {"id": id, "key": key, "val": val};
  }

  LocationCustomize deepCopy() {
    return copyWith();
  }
}

@Freezed(makeCollectionsUnmodifiable: false)
class LocationData with _$LocationData {
  const LocationData._();

  const factory LocationData.raw({
    required String id,
    @Default("") String localName,
    @Default("") String localType,
    @Default(WorldNodeType.location) WorldNodeType nodeType,
    @Default(<LocationCustomize>[]) List<LocationCustomize> customVal,
    @Default("") String note,
    @Default(<LocationData>[]) List<LocationData> child,
  }) = _LocationData;

  factory LocationData({
    String? id,
    String localName = "",
    String localType = "",
    WorldNodeType nodeType = WorldNodeType.location,
    List<LocationCustomize>? customVal,
    String note = "",
    List<LocationData>? child,
  }) {
    final resolvedId = id?.trim().isNotEmpty == true
        ? id!.trim()
        : _generateWorldSettingsId();

    return LocationData.raw(
      id: resolvedId,
      localName: localName,
      localType: localType,
      nodeType: nodeType,
      customVal: (customVal ?? const <LocationCustomize>[])
          .map((item) => item.deepCopy())
          .toList(),
      note: note,
      child: (child ?? const <LocationData>[])
          .map((item) => item.deepCopy())
          .toList(),
    );
  }

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      id: json["id"] as String?,
      localName: json["localName"] as String? ?? "",
      localType: json["localType"] as String? ?? "",
      nodeType: parseWorldNodeType(json["nodeType"]?.toString()),
      customVal: (json["customVal"] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map(LocationCustomize.fromJson)
          .toList(),
      note: json["note"] as String? ?? "",
      child: (json["child"] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map(LocationData.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "localName": localName,
      "localType": localType,
      "nodeType": nodeType.xmlValue,
      "customVal": customVal.map((item) => item.toJson()).toList(),
      "note": note,
      "child": child.map((item) => item.toJson()).toList(),
    };
  }

  LocationData deepCopy() {
    return copyWith(
      customVal: customVal.map((item) => item.deepCopy()).toList(),
      child: child.map((item) => item.deepCopy()).toList(),
    );
  }

  bool isContentEqual(LocationData other) {
    if (other.localName != localName ||
        other.localType != localType ||
        other.nodeType != nodeType ||
        other.note != note ||
        other.customVal.length != customVal.length ||
        other.child.length != child.length) {
      return false;
    }

    for (var index = 0; index < customVal.length; index++) {
      if (other.customVal[index] != customVal[index]) {
        return false;
      }
    }

    for (var index = 0; index < child.length; index++) {
      if (!other.child[index].isContentEqual(child[index])) {
        return false;
      }
    }

    return true;
  }
}
