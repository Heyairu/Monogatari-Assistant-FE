import "dart:math" as math;

import "package:freezed_annotation/freezed_annotation.dart";
import "package:uuid/uuid.dart";

part "character_data.freezed.dart";

const _uuid = Uuid();
const _nanoIdAlphabet =
    "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz-";
final _secureRandom = math.Random.secure();

String generateCharacterNanoId() => String.fromCharCodes(
  List<int>.generate(
    8,
    (_) => _nanoIdAlphabet.codeUnitAt(
      _secureRandom.nextInt(_nanoIdAlphabet.length),
    ),
  ),
);

String normalizeCharacterNanoId(String? value) {
  final normalized = value?.trim() ?? "";
  return RegExp(r"^[0-9A-Za-z_-]{8}$").hasMatch(normalized)
      ? normalized
      : generateCharacterNanoId();
}

enum CustomFieldType { text, number, boolean, list }

const defaultCharacterType = "次要配角";

const characterTypeOptions = <String>[
  "主角",
  "重要配角",
  defaultCharacterType,
  "主要反派",
  "次要反派",
  "其他",
];

class CustomFieldValue {
  final CustomFieldType type;
  final String rawValue;

  const CustomFieldValue({
    this.type = CustomFieldType.text,
    this.rawValue = "",
  });

  String get displayValue {
    if (type != CustomFieldType.list) return rawValue;
    return rawValue
        .split(RegExp(r"\r?\n|,"))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .join("、");
  }

  @override
  bool operator ==(Object other) =>
      other is CustomFieldValue &&
      other.type == type &&
      other.rawValue == rawValue;

  @override
  int get hashCode => Object.hash(type, rawValue);
}

@freezed
class CharacterAlias with _$CharacterAlias {
  const factory CharacterAlias({
    @Default("nickname") String type,
    @Default(<String>[]) List<String> values,
  }) = _CharacterAlias;
}

@freezed
class CharacterConflict with _$CharacterConflict {
  const factory CharacterConflict({
    @Default("") String obstacle,
    @Default("") String resolution,
  }) = _CharacterConflict;
}

@freezed
class CharacterRelationship with _$CharacterRelationship {
  const factory CharacterRelationship({
    @Default("") String person,
    @Default("") String relationship,
  }) = _CharacterRelationship;
}

@freezed
class CharacterProfileTableEntry with _$CharacterProfileTableEntry {
  const factory CharacterProfileTableEntry({
    @Default("") String name,
    @Default("") String description,
  }) = _CharacterProfileTableEntry;

  factory CharacterProfileTableEntry.fromMap(Map<dynamic, dynamic> source) {
    return CharacterProfileTableEntry(
      name: source["name"]?.toString() ?? "",
      description: source["description"]?.toString() ?? "",
    );
  }
}

@freezed
class CharacterPossessionEntry with _$CharacterPossessionEntry {
  const factory CharacterPossessionEntry({
    @Default("") String name,
    @Default("") String quantity,
    @Default("") String description,
  }) = _CharacterPossessionEntry;

  factory CharacterPossessionEntry.fromMap(Map<dynamic, dynamic> source) {
    return CharacterPossessionEntry(
      name: source["name"]?.toString() ?? "",
      quantity: source["quantity"]?.toString() ?? "",
      description: source["description"]?.toString() ?? "",
    );
  }
}

@freezed
class CharacterAdvancedProfile with _$CharacterAdvancedProfile {
  const factory CharacterAdvancedProfile({
    @Default(<String, double>{}) Map<String, double> commonAbilities,
    @Default(<String, double>{}) Map<String, double> socialTraits,
    @Default(<String, double>{}) Map<String, double> approaches,
    @Default(<String, double>{}) Map<String, double> personalityTraits,
  }) = _CharacterAdvancedProfile;
}

@freezed
class CharacterState with _$CharacterState {
  const factory CharacterState({
    required String characterId,
    String? storyTimePointId,
    @Default("") String location,
    @Default("") String healthStatus,
    @Default("") String emotion,
    @Default("") String alignment,
    @Default(<String>[]) List<String> possessions,
  }) = _CharacterState;
}

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

  static const profileKeys = [
    "roleOrOccupation",
    "appearanceSummary",
    "personalitySummary",
    "speechStyle",
    "motivation",
    "goal",
    "valuesAndBeliefs",
    "relationshipSummary",
    "notes",
  ];

  static const allControllerKeys = [
    ...basicKeys,
    ...appearanceKeys,
    ...personalityKeys,
    ...socialKeys,
    ...otherKeys,
    ...profileKeys,
    "nanoId",
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

@freezed
class CharacterEntryData with _$CharacterEntryData {
  const CharacterEntryData._();

  const factory CharacterEntryData({
    @Default("") String characterId,
    @Default("") String displayName,
    @Default(<CharacterAlias>[]) List<CharacterAlias> aliases,
    @Default("") String roleOrOccupation,
    @Default("") String age,
    @Default("") String gender,
    @Default("") String appearanceSummary,
    @Default("") String personalitySummary,
    @Default("") String speechStyle,
    @Default("") String motivation,
    @Default("") String goal,
    @Default(<CharacterConflict>[]) List<CharacterConflict> conflicts,
    @Default("") String valuesAndBeliefs,
    @Default("") String fear,
    @Default("") String relationshipSummary,
    @Default(<CharacterRelationship>[])
    List<CharacterRelationship> relationships,
    @Default(defaultCharacterType) String characterType,
    @Default(<CharacterProfileTableEntry>[])
    List<CharacterProfileTableEntry> organizations,
    @Default(<CharacterPossessionEntry>[])
    List<CharacterPossessionEntry> possessions,
    @Default(<CharacterProfileTableEntry>[])
    List<CharacterProfileTableEntry> statusEntries,
    @Default("") String notes,
    @Default(CharacterAdvancedProfile()) CharacterAdvancedProfile advanced,
    @Default(<String, CustomFieldValue>{})
    Map<String, CustomFieldValue> customFields,
    @Default(<String, String>{}) Map<String, String> legacyFields,
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
      characterId: _uuid.v4(),
      displayName: trimmed,
      legacyFields: {"nanoId": generateCharacterNanoId()},
      textFields: trimmed.isEmpty
          ? const <String, String>{}
          : {"name": trimmed},
    );
  }

  factory CharacterEntryData.fromLegacyMap(
    Map<String, dynamic> source, {
    String? fallbackName,
    String? characterId,
    bool migrateLegacyRelationshipLists = true,
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

    final displayName =
        (normalizedTextFields["name"] ?? trimmedFallbackName ?? "").trim();
    final aliases = <CharacterAlias>[];
    final nickname = (normalizedTextFields["nickname"] ?? "").trim();
    final originalName = (normalizedTextFields["originalName"] ?? "").trim();
    if (nickname.isNotEmpty) {
      aliases.add(CharacterAlias(type: "nickname", values: [nickname]));
    }
    if (originalName.isNotEmpty) {
      aliases.add(CharacterAlias(type: "originalName", values: [originalName]));
    }

    final hinderEvents = _readHinderEvents(source["hinderEvents"]);
    final likeItemList = _readStringList(source["likeItemList"]);
    final admireItemList = _readStringList(source["admireItemList"]);
    final hateItemList = _readStringList(source["hateItemList"]);
    final fearItemList = _readStringList(source["fearItemList"]);
    final relationships = migrateLegacyRelationshipLists
        ? _readLegacyRelationships(source)
        : const <CharacterRelationship>[];
    final commonAbilityValues = _readDoubleList(source["commonAbilityValues"]);
    final socialItemValues = _readDoubleList(source["socialItemValues"]);
    final approachValues = _readDoubleList(source["approachValues"]);
    final traitsValues = _readDoubleList(source["traitsValues"]);

    return CharacterEntryData(
      characterId: characterId?.trim().isNotEmpty == true
          ? characterId!.trim()
          : _uuid.v4(),
      displayName: displayName,
      aliases: aliases,
      roleOrOccupation: normalizedTextFields["occupation"] ?? "",
      age: normalizedTextFields["age"] ?? "",
      gender: normalizedTextFields["gender"] ?? "",
      personalitySummary: normalizedTextFields["personality"] ?? "",
      speechStyle: normalizedTextFields["language"] ?? "",
      goal: normalizedTextFields["intention"] ?? "",
      conflicts: hinderEvents
          .map(
            (event) => CharacterConflict(
              obstacle: event.event,
              resolution: event.solve,
            ),
          )
          .toList(growable: false),
      valuesAndBeliefs: normalizedTextFields["belief"] ?? "",
      fear: normalizedTextFields["fear"] ?? "",
      relationshipSummary:
          normalizedTextFields["relationshipSummary"] ??
          normalizedTextFields["family"] ??
          "",
      relationships: relationships,
      characterType:
          _readNullableString(source["characterType"]) ?? defaultCharacterType,
      organizations: _readProfileTableEntries(source["organizations"]),
      possessions: _readPossessionEntries(source["possessions"]),
      statusEntries: _readProfileTableEntries(source["statusEntries"]),
      notes:
          normalizedTextFields["otherText"] ??
          normalizedTextFields["otherValues"] ??
          "",
      advanced: CharacterAdvancedProfile(
        commonAbilities: _sliderMap(commonAbilityValues, commonAbilityIds),
        socialTraits: _sliderMap(socialItemValues, socialTraitIds),
        approaches: _sliderMap(approachValues, approachIds),
        personalityTraits: _sliderMap(traitsValues, personalityTraitIds),
      ),
      legacyFields: {
        ..._legacyCompatibilityFields(normalizedTextFields),
        "nanoId": normalizeCharacterNanoId(source["nanoId"]?.toString()),
      },
      textFields: normalizedTextFields,
      alignment: _readNullableString(source["alignment"]),
      hinderEvents: hinderEvents,
      loveToDoList: _readStringList(source["loveToDoList"]),
      hateToDoList: _readStringList(source["hateToDoList"]),
      wantToDoList: _readStringList(source["wantToDoList"]),
      fearToDoList: _readStringList(source["fearToDoList"]),
      proficientToDoList: _readStringList(source["proficientToDoList"]),
      unProficientToDoList: _readStringList(source["unProficientToDoList"]),
      commonAbilityValues: commonAbilityValues,
      howToShowLove: _readBoolMap(source["howToShowLove"]),
      howToShowGoodwill: _readBoolMap(source["howToShowGoodwill"]),
      handleHatePeople: _readBoolMap(source["handleHatePeople"]),
      socialItemValues: socialItemValues,
      relationship: _readNullableString(source["relationship"]),
      isFindNewLove: _readBool(source["isFindNewLove"]),
      isHarem: _readBool(source["isHarem"]),
      approachValues: approachValues,
      traitsValues: traitsValues,
      likeItemList: migrateLegacyRelationshipLists
          ? const <String>[]
          : likeItemList,
      admireItemList: migrateLegacyRelationshipLists
          ? const <String>[]
          : admireItemList,
      hateItemList: migrateLegacyRelationshipLists
          ? const <String>[]
          : hateItemList,
      fearItemList: migrateLegacyRelationshipLists
          ? const <String>[]
          : fearItemList,
      familiarItemList: _readStringList(source["familiarItemList"]),
    );
  }

  CharacterEntryData deepCopy() {
    return copyWith(
      aliases: aliases
          .map(
            (alias) => alias.copyWith(values: List<String>.from(alias.values)),
          )
          .toList(growable: false),
      conflicts: conflicts.map((conflict) => conflict.copyWith()).toList(),
      relationships: relationships
          .map((relationship) => relationship.copyWith())
          .toList(growable: false),
      organizations: organizations
          .map((entry) => entry.copyWith())
          .toList(growable: false),
      possessions: possessions
          .map((entry) => entry.copyWith())
          .toList(growable: false),
      statusEntries: statusEntries
          .map((entry) => entry.copyWith())
          .toList(growable: false),
      advanced: advanced.copyWith(
        commonAbilities: Map<String, double>.from(advanced.commonAbilities),
        socialTraits: Map<String, double>.from(advanced.socialTraits),
        approaches: Map<String, double>.from(advanced.approaches),
        personalityTraits: Map<String, double>.from(advanced.personalityTraits),
      ),
      customFields: Map<String, CustomFieldValue>.from(customFields),
      legacyFields: Map<String, String>.from(legacyFields),
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

  CharacterEntryData withDisplayName(String value) {
    final normalized = value.trim();
    return copyWith(displayName: normalized).withTextField("name", normalized);
  }

  Map<String, dynamic> toLegacyMap() {
    return <String, dynamic>{
      ...textFields,
      "name": displayName,
      "displayName": displayName,
      "nanoId": nanoId,
      "roleOrOccupation": roleOrOccupation,
      "age": age.isNotEmpty ? age : textFields["age"] ?? "",
      "gender": gender.isNotEmpty ? gender : textFields["gender"] ?? "",
      "appearanceSummary": appearanceSummary,
      "personalitySummary": personalitySummary,
      "speechStyle": speechStyle,
      "motivation": motivation,
      "goal": goal,
      "valuesAndBeliefs": valuesAndBeliefs,
      "fear": fear,
      "relationshipSummary": relationshipSummary,
      "characterType": characterType,
      "organizations": organizations
          .map(
            (entry) => <String, String>{
              "name": entry.name,
              "description": entry.description,
            },
          )
          .toList(growable: false),
      "possessions": possessions
          .map(
            (entry) => <String, String>{
              "name": entry.name,
              "quantity": entry.quantity,
              "description": entry.description,
            },
          )
          .toList(growable: false),
      "statusEntries": statusEntries
          .map(
            (entry) => <String, String>{
              "name": entry.name,
              "description": entry.description,
            },
          )
          .toList(growable: false),
      "notes": notes,
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

extension CharacterEntryDataNanoId on CharacterEntryData {
  String get nanoId => normalizeCharacterNanoId(legacyFields["nanoId"]);
}

const commonAbilityIds = <String>[
  "cooking",
  "cleaning",
  "finance",
  "fitness",
  "art",
  "music",
  "dance",
  "handicraft",
  "social",
  "leadership",
  "analysis",
  "creativity",
  "memory",
  "observation",
  "adaptability",
  "learning",
];

const socialTraitIds = <String>[
  "introversion_extroversion",
  "emotion_reason",
  "passive_active",
  "conservative_open",
  "cautious_adventurous",
  "dependent_independent",
  "compliant_stubborn",
  "pessimistic_optimistic",
  "serious_humorous",
  "shy_outgoing",
];

const approachIds = <String>[
  "low_key_high_profile",
  "passive_proactive",
  "cunning_honest",
  "immature_mature",
  "calm_impulsive",
  "taciturn_talkative",
  "obstinate_obedient",
  "unrestrained_disciplined",
  "serious_frivolous",
  "reserved_frank",
  "indifferent_curious",
  "dull_perceptive",
];

const personalityTraitIds = <String>[
  "attitude",
  "expression",
  "aptitude",
  "mindset",
  "shamelessness",
  "temper",
  "manners",
  "willpower",
  "desire",
  "courage",
  "eloquence",
  "vigilance",
  "self_esteem",
  "confidence",
  "archetype",
];

Map<String, double> _sliderMap(List<double> values, List<String> ids) {
  final result = <String, double>{};
  for (var index = 0; index < values.length && index < ids.length; index++) {
    result[ids[index]] = values[index];
  }
  return result;
}

Map<String, String> _legacyCompatibilityFields(Map<String, String> fields) {
  const compatibilityKeys = <String>{
    "address",
    "blood",
    "earFeatures",
    "eyebrowFeatures",
    "curious",
    "otherValues",
    "otherText",
  };
  return {
    for (final entry in fields.entries)
      if (compatibilityKeys.contains(entry.key) && entry.value.isNotEmpty)
        entry.key: entry.value,
  };
}

List<CharacterRelationship> _readLegacyRelationships(
  Map<String, dynamic> source,
) {
  final result = <CharacterRelationship>[];
  void addItems(String relationship, dynamic values) {
    for (final person in _readStringList(values)) {
      final normalized = person.trim();
      if (normalized.isEmpty) continue;
      result.add(
        CharacterRelationship(person: normalized, relationship: relationship),
      );
    }
  }

  addItems("喜歡", source["likeItemList"]);
  addItems("憧憬", source["admireItemList"]);
  addItems("討厭", source["hateItemList"]);
  addItems("害怕", source["fearItemList"]);
  return result;
}

Map<String, CharacterEntryData> copyCharacterDataMap(
  Map<String, CharacterEntryData> source,
) {
  return source.map((name, data) => MapEntry(name, data.deepCopy()));
}

Map<String, CharacterEntryData> parseCharacterDataMapFromLegacy(
  Map<String, Map<String, dynamic>> source,
) {
  final result = <String, CharacterEntryData>{};
  for (final entry in source.entries) {
    final character = CharacterEntryData.fromLegacyMap(
      entry.value,
      fallbackName: entry.key,
    );
    result[character.characterId] = character;
  }
  return result;
}

Map<String, Map<String, dynamic>> convertCharacterDataMapToLegacy(
  Map<String, CharacterEntryData> source,
) {
  return source.map(
    (id, data) => MapEntry(
      data.displayName.isEmpty ? id : data.displayName,
      data.toLegacyMap(),
    ),
  );
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

List<CharacterProfileTableEntry> _readProfileTableEntries(dynamic value) {
  if (value is! List) {
    return <CharacterProfileTableEntry>[];
  }

  return value
      .whereType<Map>()
      .map(CharacterProfileTableEntry.fromMap)
      .where((entry) => entry.name.trim().isNotEmpty)
      .toList(growable: false);
}

List<CharacterPossessionEntry> _readPossessionEntries(dynamic value) {
  if (value is! List) {
    return <CharacterPossessionEntry>[];
  }

  return value
      .whereType<Map>()
      .map(CharacterPossessionEntry.fromMap)
      .where((entry) => entry.name.trim().isNotEmpty)
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
