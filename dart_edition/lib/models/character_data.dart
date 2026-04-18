import "package:freezed_annotation/freezed_annotation.dart";

part "character_data.freezed.dart";

class CharacterDataKeys {
  CharacterDataKeys._();

  static const basicKeys = [
    "name",
    "nickname",
    "age",
    "gender",
    "occupation",
    "birthday",
    "native",
    "live",
    "address",
  ];

  static const appearanceKeys = [
    "height",
    "weight",
    "blood",
    "hair",
    "eye",
    "skin",
    "faceFeatures",
    "eyeFeatures",
    "earFeatures",
    "noseFeatures",
    "mouthFeatures",
    "eyebrowFeatures",
    "body",
    "dress",
  ];

  static const personalityKeys = [
    "mbti",
    "personality",
    "language",
    "interest",
    "habit",
    "alignment",
    "belief",
    "limit",
    "future",
    "cherish",
    "disgust",
    "fear",
    "curious",
    "expect",
    "intention",
    "otherValues",
  ];

  static const socialKeys = [
    "impression",
    "likable",
    "family",
    "otherShowLove",
    "otherGoodwill",
    "otherHatePeople",
    "otherRelationship",
  ];

  static const otherKeys = ["originalName", "otherText"];

  static const allControllerKeys = [
    ...basicKeys,
    ...appearanceKeys,
    ...personalityKeys,
    ...socialKeys,
    ...otherKeys,
  ];
}

@freezed
class CharacterHinderEvent with _$CharacterHinderEvent {
  const factory CharacterHinderEvent({
    @Default("") String event,
    @Default("") String solve,
  }) = _CharacterHinderEvent;

  factory CharacterHinderEvent.fromMap(Map<dynamic, dynamic> source) {
    return CharacterHinderEvent(
      event: source["event"]?.toString() ?? "",
      solve: source["solve"]?.toString() ?? "",
    );
  }
}

@Freezed(makeCollectionsUnmodifiable: false)
class CharacterEntryData with _$CharacterEntryData {
  const CharacterEntryData._();

  const factory CharacterEntryData({
    @Default(<String, String>{}) Map<String, String> textFields,
    String? alignment,
    @Default(<CharacterHinderEvent>[]) List<CharacterHinderEvent> hinderEvents,
    @Default(<String>[]) List<String> loveToDoList,
    @Default(<String>[]) List<String> hateToDoList,
    @Default(<String>[]) List<String> wantToDoList,
    @Default(<String>[]) List<String> fearToDoList,
    @Default(<String>[]) List<String> proficientToDoList,
    @Default(<String>[]) List<String> unProficientToDoList,
    @Default(<double>[]) List<double> commonAbilityValues,
    @Default(<String, bool>{}) Map<String, bool> howToShowLove,
    @Default(<String, bool>{}) Map<String, bool> howToShowGoodwill,
    @Default(<String, bool>{}) Map<String, bool> handleHatePeople,
    @Default(<double>[]) List<double> socialItemValues,
    String? relationship,
    @Default(false) bool isFindNewLove,
    @Default(false) bool isHarem,
    @Default(<double>[]) List<double> approachValues,
    @Default(<double>[]) List<double> traitsValues,
    @Default(<String>[]) List<String> likeItemList,
    @Default(<String>[]) List<String> admireItemList,
    @Default(<String>[]) List<String> hateItemList,
    @Default(<String>[]) List<String> fearItemList,
    @Default(<String>[]) List<String> familiarItemList,
  }) = _CharacterEntryData;

  factory CharacterEntryData.withName(String name) {
    final trimmed = name.trim();
    return CharacterEntryData(
      textFields: trimmed.isEmpty
          ? const <String, String>{}
          : {"name": trimmed},
    );
  }

  factory CharacterEntryData.fromLegacyMap(
    Map<String, dynamic> source, {
    String? fallbackName,
  }) {
    final normalizedTextFields = <String, String>{};

    for (final key in CharacterDataKeys.allControllerKeys) {
      final value = source[key];
      if (value == null) {
        continue;
      }
      normalizedTextFields[key] = value.toString();
    }

    final trimmedFallbackName = fallbackName?.trim();
    if ((normalizedTextFields["name"] ?? "").trim().isEmpty &&
        trimmedFallbackName != null &&
        trimmedFallbackName.isNotEmpty) {
      normalizedTextFields["name"] = trimmedFallbackName;
    }

    return CharacterEntryData(
      textFields: normalizedTextFields,
      alignment: _readNullableString(source["alignment"]),
      hinderEvents: _readHinderEvents(source["hinderEvents"]),
      loveToDoList: _readStringList(source["loveToDoList"]),
      hateToDoList: _readStringList(source["hateToDoList"]),
      wantToDoList: _readStringList(source["wantToDoList"]),
      fearToDoList: _readStringList(source["fearToDoList"]),
      proficientToDoList: _readStringList(source["proficientToDoList"]),
      unProficientToDoList: _readStringList(source["unProficientToDoList"]),
      commonAbilityValues: _readDoubleList(source["commonAbilityValues"]),
      howToShowLove: _readBoolMap(source["howToShowLove"]),
      howToShowGoodwill: _readBoolMap(source["howToShowGoodwill"]),
      handleHatePeople: _readBoolMap(source["handleHatePeople"]),
      socialItemValues: _readDoubleList(source["socialItemValues"]),
      relationship: _readNullableString(source["relationship"]),
      isFindNewLove: _readBool(source["isFindNewLove"]),
      isHarem: _readBool(source["isHarem"]),
      approachValues: _readDoubleList(source["approachValues"]),
      traitsValues: _readDoubleList(source["traitsValues"]),
      likeItemList: _readStringList(source["likeItemList"]),
      admireItemList: _readStringList(source["admireItemList"]),
      hateItemList: _readStringList(source["hateItemList"]),
      fearItemList: _readStringList(source["fearItemList"]),
      familiarItemList: _readStringList(source["familiarItemList"]),
    );
  }

  CharacterEntryData deepCopy() {
    return copyWith(
      textFields: Map<String, String>.from(textFields),
      hinderEvents: hinderEvents
          .map((event) => event.copyWith())
          .toList(growable: false),
      loveToDoList: List<String>.from(loveToDoList),
      hateToDoList: List<String>.from(hateToDoList),
      wantToDoList: List<String>.from(wantToDoList),
      fearToDoList: List<String>.from(fearToDoList),
      proficientToDoList: List<String>.from(proficientToDoList),
      unProficientToDoList: List<String>.from(unProficientToDoList),
      commonAbilityValues: List<double>.from(commonAbilityValues),
      howToShowLove: Map<String, bool>.from(howToShowLove),
      howToShowGoodwill: Map<String, bool>.from(howToShowGoodwill),
      handleHatePeople: Map<String, bool>.from(handleHatePeople),
      socialItemValues: List<double>.from(socialItemValues),
      approachValues: List<double>.from(approachValues),
      traitsValues: List<double>.from(traitsValues),
      likeItemList: List<String>.from(likeItemList),
      admireItemList: List<String>.from(admireItemList),
      hateItemList: List<String>.from(hateItemList),
      fearItemList: List<String>.from(fearItemList),
      familiarItemList: List<String>.from(familiarItemList),
    );
  }

  CharacterEntryData withTextField(String key, String value) {
    final nextTextFields = Map<String, String>.from(textFields);
    nextTextFields[key] = value;
    return copyWith(textFields: nextTextFields);
  }

  Map<String, dynamic> toLegacyMap() {
    return <String, dynamic>{
      ...textFields,
      "alignment": alignment,
      "hinderEvents": hinderEvents
          .map(
            (event) => <String, String>{
              "event": event.event,
              "solve": event.solve,
            },
          )
          .toList(growable: false),
      "loveToDoList": List<String>.from(loveToDoList),
      "hateToDoList": List<String>.from(hateToDoList),
      "wantToDoList": List<String>.from(wantToDoList),
      "fearToDoList": List<String>.from(fearToDoList),
      "proficientToDoList": List<String>.from(proficientToDoList),
      "unProficientToDoList": List<String>.from(unProficientToDoList),
      "commonAbilityValues": List<double>.from(commonAbilityValues),
      "howToShowLove": Map<String, bool>.from(howToShowLove),
      "howToShowGoodwill": Map<String, bool>.from(howToShowGoodwill),
      "handleHatePeople": Map<String, bool>.from(handleHatePeople),
      "socialItemValues": List<double>.from(socialItemValues),
      "relationship": relationship,
      "isFindNewLove": isFindNewLove,
      "isHarem": isHarem,
      "approachValues": List<double>.from(approachValues),
      "traitsValues": List<double>.from(traitsValues),
      "likeItemList": List<String>.from(likeItemList),
      "admireItemList": List<String>.from(admireItemList),
      "hateItemList": List<String>.from(hateItemList),
      "fearItemList": List<String>.from(fearItemList),
      "familiarItemList": List<String>.from(familiarItemList),
    };
  }
}

Map<String, CharacterEntryData> copyCharacterDataMap(
  Map<String, CharacterEntryData> source,
) {
  return source.map((name, data) => MapEntry(name, data.deepCopy()));
}

Map<String, CharacterEntryData> parseCharacterDataMapFromLegacy(
  Map<String, Map<String, dynamic>> source,
) {
  return source.map(
    (name, data) => MapEntry(
      name,
      CharacterEntryData.fromLegacyMap(data, fallbackName: name),
    ),
  );
}

Map<String, Map<String, dynamic>> convertCharacterDataMapToLegacy(
  Map<String, CharacterEntryData> source,
) {
  return source.map((name, data) => MapEntry(name, data.toLegacyMap()));
}

String? _readNullableString(dynamic value) {
  if (value == null) {
    return null;
  }
  final normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

List<String> _readStringList(dynamic value) {
  if (value is! List) {
    return <String>[];
  }
  return value.map((item) => item.toString()).toList(growable: false);
}

List<double> _readDoubleList(dynamic value) {
  if (value is! List) {
    return <double>[];
  }

  return value
      .map((item) {
        if (item is num) {
          return item.toDouble();
        }
        return double.tryParse(item.toString()) ?? 0.0;
      })
      .toList(growable: false);
}

List<CharacterHinderEvent> _readHinderEvents(dynamic value) {
  if (value is! List) {
    return <CharacterHinderEvent>[];
  }

  return value
      .whereType<Map>()
      .map((item) => CharacterHinderEvent.fromMap(item))
      .toList(growable: false);
}

Map<String, bool> _readBoolMap(dynamic value) {
  if (value is! Map) {
    return <String, bool>{};
  }

  final normalized = <String, bool>{};
  value.forEach((key, rawValue) {
    normalized[key.toString()] = _readBool(rawValue);
  });
  return normalized;
}

bool _readBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    return value.toLowerCase() == "true";
  }
  return false;
}
