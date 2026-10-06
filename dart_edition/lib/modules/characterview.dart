/************************************************************
 * 
 * Copyright 2025-2026 Heyairu（部屋伊琉）
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * 
 ************************************************************/

/*
  滑桿儲存格式：
  <slider Title="title" leftTag="leftTag" rightTag="rightTag">數值</slider>
  
  範例：
  <slider Title="courage" leftTag="cowardly" rightTag="brave">30.0</slider>
  
  注意：Title、leftTag、rightTag 使用英文以便多語識別
*/

import "package:flutter/material.dart";
import "../ui_library/alias_terms.dart";
import "../features/inline_annotations/alias_mention_updates.dart";
import "dart:async";
import "package:xml/xml.dart" as xml;
import "../models/codecs/xml_text_codec.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:uuid/uuid.dart";
import "../bin/ui_library.dart";
import "package:logging/logging.dart";
import "../models/character_data.dart";
import "../application/collaboration/project_collaborative_text_codec.dart";
import "../domain/collaboration/collaboration_operation.dart"
    show ProjectRecordKind;
import "../domain/collaboration/typed_operation_log.dart" show ProjectRecordKey;
import "../features/revision_tracking/presentation/revision_field_marker.dart";
import "../application/items/legacy_character_possession_conversion.dart";
import "../application/items/item_assignment_operations.dart";
import "../models/character_snapshot_data.dart";
import "../models/world_settings_data.dart";
import "../models/timeline_data.dart";
import "../models/item_data.dart";
import "../presentation/providers/character_snapshot_providers.dart";
import "../presentation/providers/project_state_providers.dart";
import "../presentation/providers/timeline_providers.dart";
import "../presentation/widgets/remote_text_cursor_overlay.dart";
import "../presentation/widgets/project_object_selector.dart";
import "../presentation/widgets/timeline_mini_view.dart";
import "character_relationship_operations.dart" as relationship_operations;

export "../models/character_data.dart";

final _log = Logger("CharacterView");

class _LinkedCharacterItem {
  final String id;
  final String classId;
  final String itemId;
  final ItemReferenceKind itemKind;
  final String name;
  final String quantity;
  final String description;

  const _LinkedCharacterItem({
    required this.id,
    required this.classId,
    required this.itemId,
    required this.itemKind,
    required this.name,
    required this.quantity,
    required this.description,
  });
}

class _LegacyCharacterItemSubject {
  final String itemId;
  final ItemReferenceKind itemKind;
  final ItemClassData? newClass;
  final ItemInstanceData? newInstance;

  const _LegacyCharacterItemSubject({
    required this.itemId,
    required this.itemKind,
    this.newClass,
    this.newInstance,
  });
}

/// Owns the pending CharacterView draft for exactly one project session.
///
/// Project switching flushes the old registration before provider state is
/// replaced. A view that is disposed a frame later can only unregister itself;
/// it can never write its old controllers into the new project's provider.
class CharacterDraftSessionCoordinator {
  CharacterDraftSessionCoordinator._();

  static final CharacterDraftSessionCoordinator instance =
      CharacterDraftSessionCoordinator._();

  _CharacterDraftRegistration? _registration;

  void register({
    required int sessionId,
    required Object owner,
    required VoidCallback flush,
  }) {
    _registration = _CharacterDraftRegistration(
      sessionId: sessionId,
      owner: owner,
      flush: flush,
    );
  }

  bool owns(int sessionId, Object owner) {
    final registration = _registration;
    return registration != null &&
        registration.sessionId == sessionId &&
        identical(registration.owner, owner);
  }

  void flush(int sessionId) {
    final registration = _registration;
    if (registration == null || registration.sessionId != sessionId) {
      return;
    }
    registration.flush();
  }

  void flushAndClose(int sessionId) {
    final registration = _registration;
    if (registration == null || registration.sessionId != sessionId) {
      return;
    }
    try {
      registration.flush();
    } finally {
      if (identical(_registration, registration)) {
        _registration = null;
      }
    }
  }

  void unregister({required int sessionId, required Object owner}) {
    if (owns(sessionId, owner)) {
      _registration = null;
    }
  }
}

class _CharacterDraftRegistration {
  final int sessionId;
  final Object owner;
  final VoidCallback flush;

  const _CharacterDraftRegistration({
    required this.sessionId,
    required this.owner,
    required this.flush,
  });
}

class _WorldDirectoryOption {
  final String label;
  final String targetName;
  final String fullPath;

  const _WorldDirectoryOption({
    required this.label,
    required this.targetName,
    required this.fullPath,
  });
}

// MARK: - 滑桿結構(解決硬編碼問題)
class TraitDefinition {
  final String xmlTitle; // XML 儲存用的 Title 或 Key
  final String uiTitle; // UI 顯示用的標題
  final String xmlLeft; // XML 左側標籤
  final String xmlRight; // XML 右側標籤
  final String uiLeft; // UI 左側標籤
  final String uiRight; // UI 右側標籤

  const TraitDefinition({
    required this.xmlTitle,
    required this.uiTitle,
    required this.xmlLeft,
    required this.xmlRight,
    required this.uiLeft,
    required this.uiRight,
  });
}

class TraitDefinitions {
  static const commonAbilities = [
    TraitDefinition(
      xmlTitle: "cooking",
      uiTitle: "料理",
      xmlLeft: "poor",
      xmlRight: "good",
      uiLeft: "不擅長",
      uiRight: "擅長",
    ),
    TraitDefinition(
      xmlTitle: "cleaning",
      uiTitle: "清潔",
      xmlLeft: "poor",
      xmlRight: "good",
      uiLeft: "不擅長",
      uiRight: "擅長",
    ),
    TraitDefinition(
      xmlTitle: "finance",
      uiTitle: "理財",
      xmlLeft: "poor",
      xmlRight: "good",
      uiLeft: "不擅長",
      uiRight: "擅長",
    ),
    TraitDefinition(
      xmlTitle: "fitness",
      uiTitle: "體能",
      xmlLeft: "poor",
      xmlRight: "good",
      uiLeft: "不擅長",
      uiRight: "擅長",
    ),
    TraitDefinition(
      xmlTitle: "art",
      uiTitle: "藝術",
      xmlLeft: "poor",
      xmlRight: "good",
      uiLeft: "不擅長",
      uiRight: "擅長",
    ),
    TraitDefinition(
      xmlTitle: "music",
      uiTitle: "音樂",
      xmlLeft: "poor",
      xmlRight: "good",
      uiLeft: "不擅長",
      uiRight: "擅長",
    ),
    TraitDefinition(
      xmlTitle: "dance",
      uiTitle: "舞蹈",
      xmlLeft: "poor",
      xmlRight: "good",
      uiLeft: "不擅長",
      uiRight: "擅長",
    ),
    TraitDefinition(
      xmlTitle: "handicraft",
      uiTitle: "手工",
      xmlLeft: "poor",
      xmlRight: "good",
      uiLeft: "不擅長",
      uiRight: "擅長",
    ),
    TraitDefinition(
      xmlTitle: "social",
      uiTitle: "社交",
      xmlLeft: "poor",
      xmlRight: "good",
      uiLeft: "不擅長",
      uiRight: "擅長",
    ),
    TraitDefinition(
      xmlTitle: "leadership",
      uiTitle: "領導",
      xmlLeft: "poor",
      xmlRight: "good",
      uiLeft: "不擅長",
      uiRight: "擅長",
    ),
    TraitDefinition(
      xmlTitle: "analysis",
      uiTitle: "分析",
      xmlLeft: "poor",
      xmlRight: "good",
      uiLeft: "不擅長",
      uiRight: "擅長",
    ),
    TraitDefinition(
      xmlTitle: "creativity",
      uiTitle: "創意",
      xmlLeft: "poor",
      xmlRight: "good",
      uiLeft: "不擅長",
      uiRight: "擅長",
    ),
    TraitDefinition(
      xmlTitle: "memory",
      uiTitle: "記憶",
      xmlLeft: "poor",
      xmlRight: "good",
      uiLeft: "不擅長",
      uiRight: "擅長",
    ),
    TraitDefinition(
      xmlTitle: "observation",
      uiTitle: "觀察",
      xmlLeft: "poor",
      xmlRight: "good",
      uiLeft: "不擅長",
      uiRight: "擅長",
    ),
    TraitDefinition(
      xmlTitle: "adaptability",
      uiTitle: "應變",
      xmlLeft: "poor",
      xmlRight: "good",
      uiLeft: "不擅長",
      uiRight: "擅長",
    ),
    TraitDefinition(
      xmlTitle: "learning",
      uiTitle: "學習",
      xmlLeft: "poor",
      xmlRight: "good",
      uiLeft: "不擅長",
      uiRight: "擅長",
    ),
  ];

  static const socialItems = [
    TraitDefinition(
      xmlTitle: "",
      uiTitle: "",
      xmlLeft: "introverted",
      xmlRight: "extroverted",
      uiLeft: "內向",
      uiRight: "外向",
    ),
    TraitDefinition(
      xmlTitle: "",
      uiTitle: "",
      xmlLeft: "emotional",
      xmlRight: "rational",
      uiLeft: "感性",
      uiRight: "理性",
    ),
    TraitDefinition(
      xmlTitle: "",
      uiTitle: "",
      xmlLeft: "passive",
      xmlRight: "active",
      uiLeft: "被動",
      uiRight: "主動",
    ),
    TraitDefinition(
      xmlTitle: "",
      uiTitle: "",
      xmlLeft: "conservative",
      xmlRight: "open",
      uiLeft: "保守",
      uiRight: "開放",
    ),
    TraitDefinition(
      xmlTitle: "",
      uiTitle: "",
      xmlLeft: "cautious",
      xmlRight: "adventurous",
      uiLeft: "謹慎",
      uiRight: "冒險",
    ),
    TraitDefinition(
      xmlTitle: "",
      uiTitle: "",
      xmlLeft: "dependent",
      xmlRight: "independent",
      uiLeft: "依賴",
      uiRight: "獨立",
    ),
    TraitDefinition(
      xmlTitle: "",
      uiTitle: "",
      xmlLeft: "compliant",
      xmlRight: "stubborn",
      uiLeft: "柔順",
      uiRight: "固執",
    ),
    TraitDefinition(
      xmlTitle: "",
      uiTitle: "",
      xmlLeft: "pessimistic",
      xmlRight: "optimistic",
      uiLeft: "悲觀",
      uiRight: "樂觀",
    ),
    TraitDefinition(
      xmlTitle: "",
      uiTitle: "",
      xmlLeft: "serious",
      xmlRight: "humorous",
      uiLeft: "嚴肅",
      uiRight: "幽默",
    ),
    TraitDefinition(
      xmlTitle: "",
      uiTitle: "",
      xmlLeft: "shy",
      xmlRight: "outgoing",
      uiLeft: "害羞",
      uiRight: "大方",
    ),
  ];

  static const approaches = [
    TraitDefinition(
      xmlTitle: "",
      uiTitle: "",
      xmlLeft: "low-key",
      xmlRight: "high-profile",
      uiLeft: "低調",
      uiRight: "高調",
    ),
    TraitDefinition(
      xmlTitle: "",
      uiTitle: "",
      xmlLeft: "passive",
      xmlRight: "proactive",
      uiLeft: "消極",
      uiRight: "積極",
    ),
    TraitDefinition(
      xmlTitle: "",
      uiTitle: "",
      xmlLeft: "cunning",
      xmlRight: "honest",
      uiLeft: "狡猾",
      uiRight: "老實",
    ),
    TraitDefinition(
      xmlTitle: "",
      uiTitle: "",
      xmlLeft: "immature",
      xmlRight: "mature",
      uiLeft: "幼稚",
      uiRight: "成熟",
    ),
    TraitDefinition(
      xmlTitle: "",
      uiTitle: "",
      xmlLeft: "calm",
      xmlRight: "impulsive",
      uiLeft: "冷靜",
      uiRight: "衝動",
    ),
    TraitDefinition(
      xmlTitle: "",
      uiTitle: "",
      xmlLeft: "taciturn",
      xmlRight: "talkative",
      uiLeft: "寡言",
      uiRight: "多話",
    ),
    TraitDefinition(
      xmlTitle: "",
      uiTitle: "",
      xmlLeft: "obstinate",
      xmlRight: "obedient",
      uiLeft: "執拗",
      uiRight: "順從",
    ),
    TraitDefinition(
      xmlTitle: "",
      uiTitle: "",
      xmlLeft: "unrestrained",
      xmlRight: "disciplined",
      uiLeft: "奔放",
      uiRight: "自律",
    ),
    TraitDefinition(
      xmlTitle: "",
      uiTitle: "",
      xmlLeft: "serious",
      xmlRight: "frivolous",
      uiLeft: "嚴肅",
      uiRight: "輕浮",
    ),
    TraitDefinition(
      xmlTitle: "",
      uiTitle: "",
      xmlLeft: "reserved",
      xmlRight: "frank",
      uiLeft: "彆扭",
      uiRight: "坦率",
    ),
    TraitDefinition(
      xmlTitle: "",
      uiTitle: "",
      xmlLeft: "indifferent",
      xmlRight: "curious",
      uiLeft: "淡漠",
      uiRight: "好奇",
    ),
    TraitDefinition(
      xmlTitle: "",
      uiTitle: "",
      xmlLeft: "dull",
      xmlRight: "perceptive",
      uiLeft: "遲鈍",
      uiRight: "敏銳",
    ),
  ];

  static const traits = [
    TraitDefinition(
      xmlTitle: "attitude",
      uiTitle: "",
      xmlLeft: "pessimistic",
      xmlRight: "optimistic",
      uiLeft: "悲觀",
      uiRight: "樂觀",
    ),
    TraitDefinition(
      xmlTitle: "expression",
      uiTitle: "",
      xmlLeft: "expressionless",
      xmlRight: "vivid",
      uiLeft: "面癱",
      uiRight: "生動",
    ),
    TraitDefinition(
      xmlTitle: "aptitude",
      uiTitle: "",
      xmlLeft: "dull",
      xmlRight: "genius",
      uiLeft: "笨蛋",
      uiRight: "天才",
    ),
    TraitDefinition(
      xmlTitle: "mindset",
      uiTitle: "",
      xmlLeft: "simple",
      xmlRight: "complex",
      uiLeft: "單純",
      uiRight: "複雜",
    ),
    TraitDefinition(
      xmlTitle: "shamelessness",
      uiTitle: "",
      xmlLeft: "thin-skinned",
      xmlRight: "thick-skinned",
      uiLeft: "臉薄",
      uiRight: "厚顏",
    ),
    TraitDefinition(
      xmlTitle: "temper",
      uiTitle: "",
      xmlLeft: "gentle",
      xmlRight: "hot-tempered",
      uiLeft: "溫和",
      uiRight: "火爆",
    ),
    TraitDefinition(
      xmlTitle: "manners",
      uiTitle: "",
      xmlLeft: "rude",
      xmlRight: "refined",
      uiLeft: "粗魯",
      uiRight: "斯文",
    ),
    TraitDefinition(
      xmlTitle: "willpower",
      uiTitle: "",
      xmlLeft: "fragile",
      xmlRight: "strong",
      uiLeft: "軟弱",
      uiRight: "堅定",
    ),
    TraitDefinition(
      xmlTitle: "desire",
      uiTitle: "",
      xmlLeft: "ascetic",
      xmlRight: "intense",
      uiLeft: "無慾",
      uiRight: "強烈",
    ),
    TraitDefinition(
      xmlTitle: "courage",
      uiTitle: "",
      xmlLeft: "cowardly",
      xmlRight: "brave",
      uiLeft: "膽小",
      uiRight: "勇敢",
    ),
    TraitDefinition(
      xmlTitle: "eloquence",
      uiTitle: "",
      xmlLeft: "inarticulate",
      xmlRight: "witty",
      uiLeft: "木訥",
      uiRight: "風趣",
    ),
    TraitDefinition(
      xmlTitle: "vigilance",
      uiTitle: "",
      xmlLeft: "gullible",
      xmlRight: "suspicious",
      uiLeft: "輕信",
      uiRight: "多疑",
    ),
    TraitDefinition(
      xmlTitle: "self-esteem",
      uiTitle: "",
      xmlLeft: "low",
      xmlRight: "high",
      uiLeft: "自卑",
      uiRight: "自信",
    ),
    TraitDefinition(
      xmlTitle: "confidence",
      uiTitle: "",
      xmlLeft: "low",
      xmlRight: "high",
      uiLeft: "退縮",
      uiRight: "果敢",
    ),
    TraitDefinition(
      xmlTitle: "archetype",
      uiTitle: "",
      xmlLeft: "antagonist",
      xmlRight: "protagonist",
      uiLeft: "陰角",
      uiRight: "陽角",
    ),
  ];
}

// MARK: - CharacterCodec for XML Save/Load

class CharacterCodec {
  static const basicKeys = CharacterDataKeys.basicKeys;
  static const appearanceKeys = CharacterDataKeys.appearanceKeys;
  static const personalityKeys = CharacterDataKeys.personalityKeys;
  static const socialKeys = CharacterDataKeys.socialKeys;
  static const otherKeys = CharacterDataKeys.otherKeys;
  static const allControllerKeys = CharacterDataKeys.allControllerKeys;

  static CharacterEntryData copyCharacterEntry(CharacterEntryData source) {
    return source.deepCopy();
  }

  static Map<String, CharacterEntryData> copyCharacterDataMap(
    Map<String, CharacterEntryData> source,
  ) {
    return source.map((name, data) => MapEntry(name, copyCharacterEntry(data)));
  }

  static List<String> _asStringList(dynamic listData) {
    if (listData is! List) {
      return <String>[];
    }
    return listData.map((item) => item.toString()).toList();
  }

  static List<double> _asDoubleList(dynamic listData) {
    if (listData is! List) {
      return <double>[];
    }
    return listData.map((item) {
      if (item is num) {
        return item.toDouble();
      }
      return double.tryParse(item.toString()) ?? 0.0;
    }).toList();
  }

  static List<Map<String, String>> _asHinderEvents(dynamic rawData) {
    if (rawData is! List) {
      return <Map<String, String>>[];
    }

    return rawData
        .whereType<Map>()
        .map(
          (event) => <String, String>{
            "event": event["event"]?.toString() ?? "",
            "solve": event["solve"]?.toString() ?? "",
          },
        )
        .toList();
  }

  static Map<String, bool> _asBoolMap(dynamic rawData) {
    if (rawData is! Map) {
      return <String, bool>{};
    }

    final normalized = <String, bool>{};
    rawData.forEach((key, value) {
      final normalizedKey = key.toString();
      bool normalizedValue;
      if (value is bool) {
        normalizedValue = value;
      } else if (value is num) {
        normalizedValue = value != 0;
      } else if (value is String) {
        normalizedValue = value.toLowerCase() == "true";
      } else {
        normalizedValue = false;
      }
      normalized[normalizedKey] = normalizedValue;
    });
    return normalized;
  }

  /// 將角色資料序列化成 XML 格式
  static String? saveXML(Map<String, CharacterEntryData> characterData) {
    if (characterData.isEmpty) {
      return null;
    }

    final builder = xml.XmlBuilder();
    builder.element(
      "Type",
      nest: () {
        builder.element("Name", nest: "Characters");

        for (final entry in characterData.entries) {
          final character = entry.value;
          final characterId = character.characterId.isEmpty
              ? entry.key
              : character.characterId;
          final characterName = character.displayName.isEmpty
              ? character.textFields["name"] ?? ""
              : character.displayName;
          final data = character.toLegacyMap();

          builder.element(
            "Character",
            attributes: {
              "Id": characterId,
              "Name": characterName,
              "NanoID": normalizeCharacterNanoId(character.nanoId),
            },
            nest: () {
              _saveProfile(builder, character);
              // Basic Info
              builder.element(
                "BasicInfo",
                nest: () {
                  _saveStrings(builder, data, basicKeys);
                },
              );

              // Appearance
              builder.element(
                "Appearance",
                nest: () {
                  _saveStrings(builder, data, appearanceKeys);
                },
              );

              // Personality
              builder.element(
                "Personality",
                nest: () {
                  _saveStrings(builder, data, personalityKeys);
                  _writeTextElement(
                    builder,
                    "alignment",
                    character.alignment ?? "",
                  );

                  final hinderEvents = _asHinderEvents(data["hinderEvents"]);
                  if (hinderEvents.isNotEmpty) {
                    builder.element(
                      "hinderEvents",
                      nest: () {
                        for (final event in hinderEvents) {
                          builder.element(
                            "event",
                            nest: () {
                              _writeTextElement(
                                builder,
                                "name",
                                event["event"] ?? "",
                              );
                              _writeTextElement(
                                builder,
                                "solve",
                                event["solve"] ?? "",
                              );
                            },
                          );
                        }
                      },
                    );
                  }
                },
              );

              // Ability
              builder.element(
                "Ability",
                nest: () {
                  _saveList(builder, "loveToDoList", data["loveToDoList"]);
                  _saveList(builder, "hateToDoList", data["hateToDoList"]);
                  _saveList(builder, "wantToDoList", data["wantToDoList"]);
                  _saveList(builder, "fearToDoList", data["fearToDoList"]);
                  _saveList(
                    builder,
                    "proficientToDoList",
                    data["proficientToDoList"],
                  );
                  _saveList(
                    builder,
                    "unProficientToDoList",
                    data["unProficientToDoList"],
                  );

                  final commonAbilityValues = _asDoubleList(
                    data["commonAbilityValues"],
                  );

                  if (commonAbilityValues.isNotEmpty) {
                    builder.element(
                      "commonAbilitySliders",
                      nest: () {
                        for (
                          int i = 0;
                          i < commonAbilityValues.length &&
                              i < TraitDefinitions.commonAbilities.length;
                          i++
                        ) {
                          final def = TraitDefinitions.commonAbilities[i];
                          _saveSlider(
                            builder,
                            commonAbilityIds[i],
                            def.xmlTitle,
                            def.xmlLeft,
                            def.xmlRight,
                            commonAbilityValues[i],
                          );
                        }
                      },
                    );
                  }
                },
              );

              // Social
              builder.element(
                "Social",
                nest: () {
                  _writeTextElement(
                    builder,
                    "impression",
                    data["impression"] ?? "",
                  );
                  _writeTextElement(builder, "likable", data["likable"] ?? "");
                  _writeTextElement(builder, "family", data["family"] ?? "");

                  _saveCheckboxGroup(
                    builder,
                    "howToShowLove",
                    data["howToShowLove"],
                  );
                  _writeTextElement(
                    builder,
                    "otherShowLove",
                    data["otherShowLove"] ?? "",
                  );

                  _saveCheckboxGroup(
                    builder,
                    "howToShowGoodwill",
                    data["howToShowGoodwill"],
                  );
                  _writeTextElement(
                    builder,
                    "otherGoodwill",
                    data["otherGoodwill"] ?? "",
                  );

                  _saveCheckboxGroup(
                    builder,
                    "handleHatePeople",
                    data["handleHatePeople"],
                  );
                  _writeTextElement(
                    builder,
                    "otherHatePeople",
                    data["otherHatePeople"] ?? "",
                  );

                  // Social Item Sliders
                  final socialItemValues = _asDoubleList(
                    data["socialItemValues"],
                  );

                  if (socialItemValues.isNotEmpty) {
                    builder.element(
                      "socialItemSliders",
                      nest: () {
                        for (
                          int i = 0;
                          i < socialItemValues.length &&
                              i < TraitDefinitions.socialItems.length;
                          i++
                        ) {
                          final def = TraitDefinitions.socialItems[i];
                          _saveSlider(
                            builder,
                            socialTraitIds[i],
                            def.xmlTitle,
                            def.xmlLeft,
                            def.xmlRight,
                            socialItemValues[i],
                          );
                        }
                      },
                    );
                  }

                  _writeTextElement(
                    builder,
                    "relationship",
                    data["relationship"] ?? "",
                  );
                  builder.element(
                    "isFindNewLove",
                    nest: (data["isFindNewLove"] ?? false).toString(),
                  );
                  builder.element(
                    "isHarem",
                    nest: (data["isHarem"] ?? false).toString(),
                  );
                  _writeTextElement(
                    builder,
                    "otherRelationship",
                    data["otherRelationship"] ?? "",
                  );

                  // Approach Style Sliders
                  final approachValues = _asDoubleList(data["approachValues"]);

                  if (approachValues.isNotEmpty) {
                    builder.element(
                      "approachSliders",
                      nest: () {
                        for (
                          int i = 0;
                          i < approachValues.length &&
                              i < TraitDefinitions.approaches.length;
                          i++
                        ) {
                          final def = TraitDefinitions.approaches[i];
                          _saveSlider(
                            builder,
                            approachIds[i],
                            def.xmlTitle,
                            def.xmlLeft,
                            def.xmlRight,
                            approachValues[i],
                          );
                        }
                      },
                    );
                  }

                  // Traits Sliders
                  final traitsValues = _asDoubleList(data["traitsValues"]);

                  if (traitsValues.isNotEmpty) {
                    builder.element(
                      "traitsSliders",
                      nest: () {
                        for (
                          int i = 0;
                          i < traitsValues.length &&
                              i < TraitDefinitions.traits.length;
                          i++
                        ) {
                          final def = TraitDefinitions.traits[i];
                          _saveSlider(
                            builder,
                            personalityTraitIds[i],
                            def.xmlTitle,
                            def.xmlLeft,
                            def.xmlRight,
                            traitsValues[i],
                          );
                        }
                      },
                    );
                  }
                },
              );

              // Other
              builder.element(
                "Other",
                nest: () {
                  _writeTextElement(
                    builder,
                    "originalName",
                    data["originalName"] ?? "",
                  );
                  _saveList(builder, "likeItemList", data["likeItemList"]);
                  _saveList(builder, "admireItemList", data["admireItemList"]);
                  _saveList(builder, "hateItemList", data["hateItemList"]);
                  _saveList(builder, "fearItemList", data["fearItemList"]);
                  _saveList(
                    builder,
                    "familiarItemList",
                    data["familiarItemList"],
                  );
                  _writeTextElement(
                    builder,
                    "otherText",
                    data["otherText"] ?? "",
                  );
                },
              );
            },
          );
        }
      },
    );

    return builder.buildDocument().toXmlString(pretty: true, indent: "  ");
  }

  static const _profileTextFields = <String>[
    "roleOrOccupation",
    "age",
    "gender",
    "appearanceSummary",
    "personalitySummary",
    "speechStyle",
    "motivation",
    "goal",
    "valuesAndBeliefs",
    "fear",
    "relationshipSummary",
    "notes",
  ];

  static void _saveProfile(
    xml.XmlBuilder builder,
    CharacterEntryData character,
  ) {
    final values = <String, String>{
      "roleOrOccupation": character.roleOrOccupation,
      "age": character.age,
      "gender": character.gender,
      "appearanceSummary": character.appearanceSummary,
      "personalitySummary": character.personalitySummary,
      "speechStyle": character.speechStyle,
      "motivation": character.motivation,
      "goal": character.goal,
      "valuesAndBeliefs": character.valuesAndBeliefs,
      "fear": character.fear,
      "relationshipSummary": character.relationshipSummary,
      "notes": character.notes,
    };
    builder.element(
      "Profile",
      nest: () {
        _writeTextElement(
          builder,
          "NanoID",
          normalizeCharacterNanoId(character.nanoId),
        );
        for (final key in _profileTextFields) {
          _writeTextElement(builder, key, values[key] ?? "");
        }
        if (character.aliases.isNotEmpty) {
          builder.element(
            "Aliases",
            nest: () {
              for (final alias in character.aliases) {
                for (final value in alias.values) {
                  builder.element(
                    "Alias",
                    attributes: {"Type": alias.type},
                    nest: value,
                  );
                }
              }
            },
          );
        }
        if (character.conflicts.isNotEmpty) {
          builder.element(
            "Conflicts",
            nest: () {
              for (final conflict in character.conflicts) {
                builder.element(
                  "Conflict",
                  nest: () {
                    _writeTextElement(builder, "Obstacle", conflict.obstacle);
                    _writeTextElement(
                      builder,
                      "Resolution",
                      conflict.resolution,
                    );
                  },
                );
              }
            },
          );
        }
        builder.element(
          "Relationships",
          nest: () {
            for (final relationship in character.relationships) {
              builder.element(
                "Relationship",
                nest: () {
                  _writeTextElement(builder, "Person", relationship.person);
                  _writeTextElement(
                    builder,
                    "Description",
                    relationship.relationship,
                  );
                  _writeTextElement(
                    builder,
                    "InternalRelationship",
                    relationship.internalRelationship,
                  );
                },
              );
            }
          },
        );
        _writeTextElement(builder, "CharacterType", character.characterType);
        _saveProfileTable(
          builder,
          "Organizations",
          "Organization",
          character.organizations,
        );
        _savePossessionTable(builder, character.possessions);
        _saveProfileTable(
          builder,
          "StatusEntries",
          "Status",
          character.statusEntries,
        );
        _saveCustomFieldMap(builder, character.customFields);
        _saveStringMap(builder, "LegacyFields", character.legacyFields);
      },
    );
  }

  static void _saveStringMap(
    xml.XmlBuilder builder,
    String tagName,
    Map<String, String> values,
  ) {
    if (values.isEmpty) return;
    builder.element(
      tagName,
      nest: () {
        for (final entry in values.entries) {
          builder.element(
            "Field",
            attributes: {"Key": entry.key},
            nest: entry.value,
          );
        }
      },
    );
  }

  static void _saveProfileTable(
    xml.XmlBuilder builder,
    String containerTag,
    String entryTag,
    List<CharacterProfileTableEntry> entries,
  ) {
    if (entries.isEmpty) return;
    builder.element(
      containerTag,
      nest: () {
        for (final entry in entries) {
          builder.element(
            entryTag,
            nest: () {
              _writeTextElement(builder, "Name", entry.name);
              _writeTextElement(builder, "Description", entry.description);
            },
          );
        }
      },
    );
  }

  static void _savePossessionTable(
    xml.XmlBuilder builder,
    List<CharacterPossessionEntry> entries,
  ) {
    if (entries.isEmpty) return;
    builder.element(
      "Possessions",
      nest: () {
        for (final entry in entries) {
          builder.element(
            "Possession",
            nest: () {
              _writeTextElement(builder, "Name", entry.name);
              _writeTextElement(builder, "Quantity", entry.quantity);
              _writeTextElement(builder, "Description", entry.description);
            },
          );
        }
      },
    );
  }

  static void _saveCustomFieldMap(
    xml.XmlBuilder builder,
    Map<String, CustomFieldValue> values,
  ) {
    if (values.isEmpty) return;
    builder.element(
      "CustomFields",
      nest: () {
        for (final entry in values.entries) {
          builder.element(
            "Field",
            attributes: {"Key": entry.key, "Type": entry.value.type.name},
            nest: () {
              if (entry.value.type == CustomFieldType.list) {
                for (final item in entry.value.rawValue.split("\n")) {
                  if (item.trim().isNotEmpty) {
                    _writeTextElement(builder, "Item", item.trim());
                  }
                }
              } else {
                builder.text(entry.value.rawValue);
              }
            },
          );
        }
      },
    );
  }

  static CharacterEntryData _loadProfile(
    xml.XmlElement characterNode,
    CharacterEntryData fallback,
  ) {
    final profile = characterNode.findElements("Profile").firstOrNull;
    if (profile == null) return fallback;

    String value(String key, String oldValue) {
      final element = profile.findElements(key).firstOrNull;
      return element == null ? oldValue : _readElementText(element);
    }

    final aliasesByType = <String, List<String>>{};
    final aliasesNode = profile.findElements("Aliases").firstOrNull;
    if (aliasesNode != null) {
      for (final alias in aliasesNode.findElements("Alias")) {
        final aliasValue = _readElementText(alias);
        if (aliasValue.isEmpty) continue;
        aliasesByType
            .putIfAbsent(alias.getAttribute("Type") ?? "other", () => [])
            .add(aliasValue);
      }
    }

    final conflicts = <CharacterConflict>[];
    final conflictsNode = profile.findElements("Conflicts").firstOrNull;
    if (conflictsNode != null) {
      for (final conflict in conflictsNode.findElements("Conflict")) {
        conflicts.add(
          CharacterConflict(
            obstacle: _readElementText(
              conflict.findElements("Obstacle").firstOrNull,
            ),
            resolution: _readElementText(
              conflict.findElements("Resolution").firstOrNull,
            ),
          ),
        );
      }
    }

    final relationships = <CharacterRelationship>[];
    final relationshipsNode = profile.findElements("Relationships").firstOrNull;
    if (relationshipsNode != null) {
      for (final relationship in relationshipsNode.findElements(
        "Relationship",
      )) {
        relationships.add(
          CharacterRelationship(
            person: _readElementText(
              relationship.findElements("Person").firstOrNull,
            ),
            relationship: _readElementText(
              relationship.findElements("Description").firstOrNull,
            ),
            internalRelationship: _readElementText(
              relationship.findElements("InternalRelationship").firstOrNull,
            ),
          ),
        );
      }
    }

    List<CharacterProfileTableEntry> loadProfileTable(
      String containerTag,
      String entryTag,
      List<CharacterProfileTableEntry> fallbackEntries,
    ) {
      final container = profile.findElements(containerTag).firstOrNull;
      if (container == null) return fallbackEntries;
      return container
          .findElements(entryTag)
          .map(
            (entry) => CharacterProfileTableEntry(
              name: _readElementText(entry.findElements("Name").firstOrNull),
              description: _readElementText(
                entry.findElements("Description").firstOrNull,
              ),
            ),
          )
          .where((entry) => entry.name.trim().isNotEmpty)
          .toList(growable: false);
    }

    List<CharacterPossessionEntry> loadPossessions() {
      final container = profile.findElements("Possessions").firstOrNull;
      if (container == null) return fallback.possessions;
      return container
          .findElements("Possession")
          .map(
            (entry) => CharacterPossessionEntry(
              name: _readElementText(entry.findElements("Name").firstOrNull),
              quantity: _readElementText(
                entry.findElements("Quantity").firstOrNull,
              ),
              description: _readElementText(
                entry.findElements("Description").firstOrNull,
              ),
            ),
          )
          .where((entry) => entry.name.trim().isNotEmpty)
          .toList(growable: false);
    }

    var restoredRelationshipSummary = value(
      "relationshipSummary",
      fallback.relationshipSummary,
    );
    final legacyFamily = (fallback.textFields["family"] ?? "").trim();
    final legacyImpression = (fallback.textFields["impression"] ?? "").trim();
    final legacyRelationship = fallback.relationship?.trim() ?? "";
    final retainedRelationships = relationships
        .where((relationship) {
          final description = relationship.relationship.trim();
          if (relationship.person == "家庭／重要背景" &&
              legacyFamily.isNotEmpty &&
              description == legacyFamily) {
            if (restoredRelationshipSummary.isEmpty) {
              restoredRelationshipSummary = description;
            }
            return false;
          }
          if (relationship.person == "他人印象" &&
              legacyImpression.isNotEmpty &&
              description == legacyImpression) {
            return false;
          }
          if (relationship.person == "感情狀態" &&
              legacyRelationship.isNotEmpty &&
              description == legacyRelationship) {
            return false;
          }
          return true;
        })
        .toList(growable: false);

    return fallback.copyWith(
      aliases: aliasesByType.isEmpty
          ? fallback.aliases
          : aliasesByType.entries
                .map(
                  (entry) =>
                      CharacterAlias(type: entry.key, values: entry.value),
                )
                .toList(growable: false),
      roleOrOccupation: value("roleOrOccupation", fallback.roleOrOccupation),
      age: value("age", fallback.age),
      gender: value("gender", fallback.gender),
      appearanceSummary: value("appearanceSummary", fallback.appearanceSummary),
      personalitySummary: value(
        "personalitySummary",
        fallback.personalitySummary,
      ),
      speechStyle: value("speechStyle", fallback.speechStyle),
      motivation: value("motivation", fallback.motivation),
      goal: value("goal", fallback.goal),
      conflicts: conflicts.isEmpty ? fallback.conflicts : conflicts,
      relationships: relationshipsNode == null
          ? fallback.relationships
          : retainedRelationships,
      characterType:
          value("CharacterType", fallback.characterType).trim().isEmpty
          ? defaultCharacterType
          : value("CharacterType", fallback.characterType),
      organizations: loadProfileTable(
        "Organizations",
        "Organization",
        fallback.organizations,
      ),
      possessions: loadPossessions(),
      statusEntries: loadProfileTable(
        "StatusEntries",
        "Status",
        fallback.statusEntries,
      ),
      valuesAndBeliefs: value("valuesAndBeliefs", fallback.valuesAndBeliefs),
      fear: value("fear", fallback.fear),
      relationshipSummary: restoredRelationshipSummary,
      notes: value("notes", fallback.notes),
      customFields: _loadCustomFieldMap(profile),
      legacyFields: {
        ...fallback.legacyFields,
        ..._loadStringMap(profile, "LegacyFields"),
        "nanoId": normalizeCharacterNanoId(value("NanoID", fallback.nanoId)),
      },
    );
  }

  static Map<String, String> _loadStringMap(
    xml.XmlElement parent,
    String tagName,
  ) {
    final result = <String, String>{};
    final node = parent.findElements(tagName).firstOrNull;
    if (node == null) return result;
    for (final field in node.findElements("Field")) {
      final key = field.getAttribute("Key");
      if (key != null && key.isNotEmpty) {
        result[key] = _readElementText(field);
      }
    }
    return result;
  }

  static Map<String, CustomFieldValue> _loadCustomFieldMap(
    xml.XmlElement parent,
  ) {
    final result = <String, CustomFieldValue>{};
    final node = parent.findElements("CustomFields").firstOrNull;
    if (node == null) return result;
    for (final field in node.findElements("Field")) {
      final key = field.getAttribute("Key");
      if (key == null || key.isEmpty) continue;
      final typeName = field.getAttribute("Type") ?? "text";
      final type = CustomFieldType.values.firstWhere(
        (candidate) => candidate.name == typeName,
        orElse: () => CustomFieldType.text,
      );
      result[key] = CustomFieldValue(
        type: type,
        rawValue:
            type == CustomFieldType.list &&
                field.findElements("Item").isNotEmpty
            ? field.findElements("Item").map(_readElementText).join("\n")
            : _readElementText(field),
      );
    }
    return result;
  }

  static void _saveList(
    xml.XmlBuilder builder,
    String tagName,
    dynamic listData,
  ) {
    final list = _asStringList(listData);
    if (list.isNotEmpty) {
      builder.element(
        tagName,
        nest: () {
          for (final item in list) {
            _writeTextElement(builder, "item", item);
          }
        },
      );
    }
  }

  static void _saveStrings(
    xml.XmlBuilder builder,
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      _writeTextElement(builder, key, data[key]?.toString() ?? "");
    }
  }

  static void _loadStrings(
    Map<String, dynamic> data,
    xml.XmlElement node,
    List<String> keys,
  ) {
    for (final key in keys) {
      data[key] = _getText(node, key);
    }
  }

  static void _saveCheckboxGroup(
    xml.XmlBuilder builder,
    String tagName,
    dynamic mapData,
  ) {
    final map = _asBoolMap(mapData);
    if (map.isNotEmpty) {
      builder.element(
        tagName,
        nest: () {
          for (final entry in map.entries) {
            builder.element(
              "item",
              attributes: {"key": entry.key},
              nest: entry.value.toString(),
            );
          }
        },
      );
    }
  }

  static void _saveSlider(
    xml.XmlBuilder builder,
    String id,
    String title,
    String leftTag,
    String rightTag,
    double value,
  ) {
    builder.element(
      "slider",
      attributes: {
        "Id": id,
        "Title": title.isEmpty ? id : title,
        "leftTag": leftTag,
        "rightTag": rightTag,
      },
      nest: value.toStringAsFixed(1),
    );
  }

  /// 從 XML 載入角色資料
  static Map<String, CharacterEntryData>? loadXML(String content) {
    try {
      final document = xml.XmlDocument.parse(content);
      final typeElement = document.findAllElements("Type").firstOrNull;
      return typeElement == null ? null : loadElement(typeElement);
    } catch (e) {
      _log.severe("Error parsing Character XML: $e");
      return null;
    }
  }

  // 自已解析的 Type 區塊載入，避免專案載入時重複序列化與解析。
  static Map<String, CharacterEntryData>? loadElement(
    xml.XmlElement typeElement, {
    bool? migrateLegacyRelationshipLists,
  }) {
    try {
      final nameElement = typeElement.findAllElements("Name").firstOrNull;
      if (nameElement?.innerText != "Characters") return null;

      final characterData = <String, CharacterEntryData>{};

      for (final charNode in typeElement.findAllElements("Character")) {
        final characterName =
            charNode.getAttribute("DisplayName") ??
            charNode.getAttribute("Name") ??
            "";
        final characterId = charNode.getAttribute("Id");

        final data = <String, dynamic>{};
        data["nanoId"] = charNode.getAttribute("NanoID") ?? "";

        // Basic Info
        final basicInfo = charNode.findAllElements("BasicInfo").firstOrNull;
        if (basicInfo != null) {
          _loadStrings(data, basicInfo, basicKeys);
        }

        // Appearance
        final appearance = charNode.findAllElements("Appearance").firstOrNull;
        if (appearance != null) {
          _loadStrings(data, appearance, appearanceKeys);
        }

        // Personality
        final personality = charNode.findAllElements("Personality").firstOrNull;
        if (personality != null) {
          _loadStrings(data, personality, personalityKeys);
          data["alignment"] = _getText(personality, "alignment");
          data["hinderEvents"] = _parseHinderEvents(personality);
        }

        // Ability
        final ability = charNode.findAllElements("Ability").firstOrNull;
        if (ability != null) {
          data["loveToDoList"] = _parseList(ability, "loveToDoList");
          data["hateToDoList"] = _parseList(ability, "hateToDoList");
          data["wantToDoList"] = _parseList(ability, "wantToDoList");
          data["fearToDoList"] = _parseList(ability, "fearToDoList");
          data["proficientToDoList"] = _parseList(
            ability,
            "proficientToDoList",
          );
          data["unProficientToDoList"] = _parseList(
            ability,
            "unProficientToDoList",
          );
          data["commonAbilityValues"] = _parseSliders(
            ability,
            "commonAbilitySliders",
            commonAbilityIds,
          );
        }

        // Social
        final social = charNode.findAllElements("Social").firstOrNull;
        if (social != null) {
          data["impression"] = _getText(social, "impression");
          data["likable"] = _getText(social, "likable");
          data["family"] = _getText(social, "family");
          data["howToShowLove"] = _parseCheckboxGroup(social, "howToShowLove");
          data["otherShowLove"] = _getText(social, "otherShowLove");
          data["howToShowGoodwill"] = _parseCheckboxGroup(
            social,
            "howToShowGoodwill",
          );
          data["otherGoodwill"] = _getText(social, "otherGoodwill");
          data["handleHatePeople"] = _parseCheckboxGroup(
            social,
            "handleHatePeople",
          );
          data["otherHatePeople"] = _getText(social, "otherHatePeople");
          data["socialItemValues"] = _parseSliders(
            social,
            "socialItemSliders",
            socialTraitIds,
          );
          data["relationship"] = _getText(social, "relationship");
          data["isFindNewLove"] = _getText(social, "isFindNewLove") == "true";
          data["isHarem"] = _getText(social, "isHarem") == "true";
          data["otherRelationship"] = _getText(social, "otherRelationship");
          data["approachValues"] = _parseSliders(
            social,
            "approachSliders",
            approachIds,
          );
          data["traitsValues"] = _parseSliders(
            social,
            "traitsSliders",
            personalityTraitIds,
          );
        }

        // Other
        final other = charNode.findAllElements("Other").firstOrNull;
        if (other != null) {
          data["originalName"] = _getText(other, "originalName");
          data["likeItemList"] = _parseList(other, "likeItemList");
          data["admireItemList"] = _parseList(other, "admireItemList");
          data["hateItemList"] = _parseList(other, "hateItemList");
          data["fearItemList"] = _parseList(other, "fearItemList");
          data["familiarItemList"] = _parseList(other, "familiarItemList");
          data["otherText"] = _getText(other, "otherText");
        }

        var character = CharacterEntryData.fromLegacyMap(
          data,
          fallbackName: characterName,
          characterId: characterId,
          migrateLegacyRelationshipLists:
              migrateLegacyRelationshipLists ??
              charNode.findElements("Profile").isEmpty,
        );
        character = _loadProfile(charNode, character);
        characterData[character.characterId] = character;
      }

      return characterData.isNotEmpty ? characterData : null;
    } catch (e) {
      _log.severe("Error parsing Character XML element: $e");
      return null;
    }
  }

  static String _getText(xml.XmlElement node, String tagName) {
    final element = node.findAllElements(tagName).firstOrNull;
    return _readElementText(element);
  }

  static void _writeTextElement(
    xml.XmlBuilder builder,
    String name,
    String value,
  ) {
    XmlTextCodec.writeTextElement(builder, name, value);
  }

  static String _readElementText(xml.XmlElement? element) {
    return XmlTextCodec.readElementText(element);
  }

  static List<String> _parseList(xml.XmlElement node, String tagName) {
    final list = <String>[];
    final parent = node.findAllElements(tagName).firstOrNull;
    if (parent != null) {
      for (final item in parent.findAllElements("item")) {
        list.add(item.innerText);
      }
    }
    return list;
  }

  static Map<String, bool> _parseCheckboxGroup(
    xml.XmlElement node,
    String tagName,
  ) {
    final map = <String, bool>{};
    final parent = node.findAllElements(tagName).firstOrNull;
    if (parent != null) {
      for (final item in parent.findAllElements("item")) {
        final key = item.getAttribute("key") ?? "";
        final val = item.innerText == "true";
        if (key.isNotEmpty) {
          map[key] = val;
        }
      }
    }
    return map;
  }

  static List<Map<String, String>> _parseHinderEvents(xml.XmlElement node) {
    final list = <Map<String, String>>[];
    final parent = node.findAllElements("hinderEvents").firstOrNull;
    if (parent != null) {
      for (final eventNode in parent.findAllElements("event")) {
        list.add({
          "event": _getText(eventNode, "name"),
          "solve": _getText(eventNode, "solve"),
        });
      }
    }
    return list;
  }

  static List<double> _parseSliders(
    xml.XmlElement node,
    String tagName,
    List<String> stableIds,
  ) {
    final byId = <String, double>{};
    final legacyValues = <double>[];
    final parent = node.findAllElements(tagName).firstOrNull;
    if (parent != null) {
      for (final slider in parent.findAllElements("slider")) {
        final val = double.tryParse(slider.innerText) ?? 0;
        final id = slider.getAttribute("Id") ?? slider.getAttribute("Title");
        if (id != null && id.isNotEmpty && stableIds.contains(id)) {
          byId[id] = val;
        } else {
          legacyValues.add(val);
        }
      }
    }
    if (byId.isEmpty) {
      return legacyValues;
    }
    var legacyIndex = 0;
    return stableIds
        .map((id) {
          final value = byId[id];
          if (value != null) return value;
          if (legacyIndex < legacyValues.length) {
            return legacyValues[legacyIndex++];
          }
          return 50.0;
        })
        .toList(growable: false);
  }
}

class CharacterView extends ConsumerStatefulWidget {
  final int projectSessionId;
  final String? initialCharacterId;
  final int selectionRequestId;
  final ValueChanged<String>? onOpenItem;

  const CharacterView({
    super.key,
    this.projectSessionId = 0,
    this.initialCharacterId,
    this.selectionRequestId = 0,
    this.onOpenItem,
  });

  @override
  ConsumerState<CharacterView> createState() => _CharacterViewState();
}

// MARK: - 角色資料控制項

class _CharacterViewState extends ConsumerState<CharacterView>
    with SingleTickerProviderStateMixin {
  static const String _baselineSnapshotSelection = "__baseline__";

  // 拖動相關狀態
  bool _isDragging = false;
  String? _currentDragData;

  // Tab Controller
  late TabController _tabController;

  // Character List
  String? selectedCharacter;
  int? selectedCharacterIndex;
  String? _selectedSnapshotChangeId;
  Map<String, CustomFieldValue> _snapshotCustomFields =
      <String, CustomFieldValue>{};

  List<String> get characters =>
      ref.read(characterDataProvider).keys.toList(growable: false);
  Map<String, CharacterEntryData> get characterData =>
      ref.read(characterDataProvider);
  CharacterDataNotifier get _characterNotifier =>
      ref.read(characterDataProvider.notifier);

  String _displayNameFor(String characterId) {
    final entry = characterData[characterId];
    if (entry == null) return characterId;
    return entry.displayName.isEmpty
        ? entry.textFields["name"] ?? characterId
        : entry.displayName;
  }

  String _nanoIdFor(String characterId) =>
      normalizeCharacterNanoId(characterData[characterId]?.nanoId);

  String _characterTypeFor(String characterId) {
    if (characterId == selectedCharacter) return selectedCharacterType;
    final value = characterData[characterId]?.characterType ?? "";
    return characterTypeOptions.contains(value) ? value : defaultCharacterType;
  }

  Set<String> get _duplicateCharacterIds {
    final counts = <String, int>{};
    for (final characterId in characters) {
      final name = _displayNameFor(characterId).trim().toLowerCase();
      if (name.isNotEmpty) counts[name] = (counts[name] ?? 0) + 1;
    }
    return characters
        .where(
          (characterId) =>
              (counts[_displayNameFor(characterId).trim().toLowerCase()] ?? 0) >
              1,
        )
        .toSet();
  }

  String _characterLabel(String characterId) {
    final name = _displayNameFor(characterId).trim();
    return _duplicateCharacterIds.contains(characterId)
        ? "$name (${_nanoIdFor(characterId)})"
        : name;
  }

  String _characterNameFromLabel(String value) {
    return value.trim();
  }

  List<String> get _relationshipCharacterOptions {
    final names = <String>{};
    for (final characterId in characters) {
      if (characterId == selectedCharacter) continue;
      final name = _characterLabel(characterId);
      if (name.isNotEmpty) names.add(name);
    }
    return names.toList(growable: false);
  }

  String _worldDirectoryPathLabel(List<String> path) {
    if (path.length <= 3) return "\\${path.join("\\")}";
    return "\\${path.first}\\...\\${path[path.length - 2]}\\${path.last}";
  }

  List<_WorldDirectoryOption> get _worldDirectoryOptions {
    final options = <_WorldDirectoryOption>[];

    void collect(LocationData node, List<String> ancestors) {
      final targetName = node.localName.trim();
      final path = [...ancestors, targetName];
      if (targetName.isNotEmpty &&
          (node.nodeType == WorldNodeType.location ||
              node.nodeType == WorldNodeType.organization)) {
        options.add(
          _WorldDirectoryOption(
            label: _worldDirectoryPathLabel(path),
            targetName: targetName,
            fullPath: "\\${path.join("\\")}",
          ),
        );
      }

      for (final child in node.child) {
        collect(child, path);
      }
    }

    for (final node in ref.read(worldSettingsDataProvider)) {
      collect(node, const <String>[]);
    }
    return options;
  }

  List<String> get _worldDirectoryOptionLabels => _worldDirectoryOptions
      .map((option) => option.label)
      .toList(growable: false);

  String _worldDirectoryTargetName(String label) {
    final normalizedLabel = label.trim();
    for (final option in _worldDirectoryOptions) {
      if (option.label == normalizedLabel) return option.targetName;
    }
    return normalizedLabel;
  }

  bool _matchesWorldDirectoryOption(String label, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;

    final option = _worldDirectoryOptions.where(
      (option) => option.label == label.trim(),
    );
    if (option.isEmpty) return label.toLowerCase().contains(normalizedQuery);

    final querySegments = normalizedQuery
        .split(RegExp(r"[\\/]+"))
        .where((segment) => segment.isNotEmpty && segment != "...")
        .toList(growable: false);
    if (querySegments.isEmpty) return true;

    final pathSegments = option.first.fullPath
        .toLowerCase()
        .split("\\")
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    var nextPathIndex = 0;
    for (final querySegment in querySegments) {
      final matchedIndex = pathSegments.indexWhere(
        (segment) => segment.contains(querySegment),
        nextPathIndex,
      );
      if (matchedIndex == -1) return false;
      nextPathIndex = matchedIndex + 1;
    }
    return true;
  }

  // New character input controller
  final TextEditingController _newCharacterController = TextEditingController();

  // Unified Text Controllers
  final Map<String, TextEditingController> _controllers = {};
  final Map<TextEditingController, String> _controllerKeys = {};
  final Map<String, FocusNode> _collaborationFocusNodes = {};

  // Alignment - 陣營 (九宮格)
  String? selectedAlignment;

  // Hinder Events - 阻礙事件
  List<Map<String, String>> hinderEvents = [];
  final TextEditingController _hinderEventController = TextEditingController();
  final TextEditingController _solveController = TextEditingController();
  int? selectedHinderIndex;

  // Core aliases and relationships.
  List<String> nicknames = [];
  List<CharacterRelationship> characterRelationships = [];
  final TextEditingController _relationshipPersonController =
      TextEditingController();
  final TextEditingController _relationshipInternalController =
      TextEditingController();
  final TextEditingController _relationshipDescriptionController =
      TextEditingController();
  int? selectedCharacterRelationshipIndex;

  // Core profile tables.
  String selectedCharacterType = defaultCharacterType;
  List<CharacterProfileTableEntry> organizations = [];
  List<CharacterPossessionEntry> possessions = [];
  List<CharacterProfileTableEntry> statusEntries = [];
  final TextEditingController _organizationNameController =
      TextEditingController();
  final TextEditingController _organizationDescriptionController =
      TextEditingController();
  final TextEditingController _possessionNameController =
      TextEditingController();
  final TextEditingController _possessionQuantityController =
      TextEditingController();
  final TextEditingController _possessionDescriptionController =
      TextEditingController();
  final TextEditingController _statusNameController = TextEditingController();
  final TextEditingController _statusDescriptionController =
      TextEditingController();
  int? selectedOrganizationIndex;
  int? selectedPossessionIndex;
  int? selectedStatusIndex;

  // Inline custom-field creator.
  final TextEditingController _customFieldNameController =
      TextEditingController();
  CustomFieldType _newCustomFieldType = CustomFieldType.text;

  // Ability Lists - 能力列表
  List<String> loveToDoList = [];
  List<String> hateToDoList = [];
  List<String> wantToDoList = [];
  List<String> fearToDoList = [];
  List<String> proficientToDoList = [];
  List<String> unProficientToDoList = [];

  // Common Ability Sliders - 生活常用技能
  List<double> commonAbilityValues = List.filled(
    TraitDefinitions.commonAbilities.length,
    50.0,
  );

  // Social - 社交

  // How to show love - 如何表達「喜歡」
  final Map<String, bool> howToShowLove = {
    "confess_directly": false,
    "give_gift": false,
    "talk_often": false,
    "get_attention": false,
    "watch_silently": false,
  };
  final Map<String, String> howToShowLoveLabels = {
    "confess_directly": "直接告白",
    "give_gift": "送禮物",
    "talk_often": "常常找對方講話",
    "get_attention": "做些小動作引起注意",
    "watch_silently": "默默關注對方",
  };

  // How to show goodwill - 如何表達好意
  final Map<String, bool> howToShowGoodwill = {
    "smile": false,
    "greet_actively": false,
    "help_actively": false,
    "give_small_gift": false,
    "invite": false,
    "share_things": false,
  };
  final Map<String, String> howToShowGoodwillLabels = {
    "smile": "微笑",
    "greet_actively": "主動打招呼",
    "help_actively": "主動幫忙",
    "give_small_gift": "送小禮物",
    "invite": "邀請對方",
    "share_things": "分享自己的事",
  };

  // Handle hate people - 如何應對討厭的人
  final Map<String, bool> handleHatePeople = {
    "ignore_directly": false,
    "keep_distance": false,
    "be_polite": false,
    "sarcastic": false,
    "confront": false,
    "ask_for_help": false,
  };
  final Map<String, String> handleHatePeopleLabels = {
    "ignore_directly": "直接無視",
    "keep_distance": "保持距離",
    "be_polite": "禮貌應對",
    "sarcastic": "冷嘲熱諷",
    "confront": "正面衝突",
    "ask_for_help": "找人幫忙",
  };

  // Social Item Sliders - 社交相關項目
  List<double> socialItemValues = List.filled(
    TraitDefinitions.socialItems.length,
    50.0,
  );

  // MBTI

  // Relationship - 戀愛關係
  String? selectedRelationship;
  bool isFindNewLove = false;
  bool isHarem = false;

  // Approach Style - 行事作風
  List<double> approachValues = List.filled(
    TraitDefinitions.approaches.length,
    50.0,
  );

  // Traits - 性格特質
  List<double> traitsValues = List.filled(TraitDefinitions.traits.length, 50.0);

  // Other - 其他
  List<String> likeItemList = [];
  List<String> admireItemList = [];
  List<String> hateItemList = [];
  List<String> fearItemList = [];
  List<String> familiarItemList = [];

  bool _isLoading = false;
  Timer? _debounceTimer;
  bool _hasHydratedInitialCharacterData = false;
  bool _registeredCharacterDataListener = false;
  final Set<String> _dirtyControllerKeys = <String>{};
  bool _structuredFieldsDirty = false;
  CharacterEntryData? _loadedCharacterEntrySnapshot;

  void _markAsModified({String? controllerKey, bool structuredFields = false}) {
    if (controllerKey != null) {
      _dirtyControllerKeys.add(controllerKey);
    }
    if (structuredFields) {
      _structuredFieldsDirty = true;
    }
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) _saveCurrentCharacterData(forceStructuredFields: false);
    });
  }

  void _setupListeners() {
    // 建立所有控制項
    for (var key in CharacterCodec.allControllerKeys) {
      final controller = TextEditingController();
      _controllers[key] = controller;
      _controllerKeys[controller] = key;
      _collaborationFocusNodes[key] = FocusNode();
    }

    // Name needs specific sync
    final nameController = _controllers["name"];
    if (nameController != null) {
      nameController.addListener(() {
        if (_isLoading) return;
        _markAsModified(controllerKey: "name");
      });
    }

    // Batch setup listeners
    for (var entry in _controllers.entries) {
      if (entry.key == "name") continue; // Handled specially

      entry.value.addListener(() {
        if (!_isLoading) _markAsModified(controllerKey: entry.key);
      });
    }
  }

  void _emitCharacterDataChanged() {
    // Dirty tracking is driven by provider listeners in coordinator.
  }

  void _syncSelectionFromProviderIfNeeded(
    Map<String, CharacterEntryData> next, {
    bool forceLoadSelected = false,
  }) {
    final ids = next.keys.toList(growable: false);

    if (ids.isEmpty) {
      if (selectedCharacter != null || selectedCharacterIndex != null) {
        setState(() {
          selectedCharacter = null;
          selectedCharacterIndex = null;
          _clearAllFields();
        });
      }
      return;
    }

    if (selectedCharacter == null || !next.containsKey(selectedCharacter)) {
      final requestedId = widget.initialCharacterId;
      final nextSelected = requestedId != null && next.containsKey(requestedId)
          ? requestedId
          : ids.first;
      setState(() {
        selectedCharacter = nextSelected;
        selectedCharacterIndex = ids.indexOf(nextSelected);
        _selectedSnapshotChangeId = null;
        _snapshotCustomFields = <String, CustomFieldValue>{};
        _loadCharacterData(selectedCharacter!);
      });
      return;
    }

    final nextIndex = ids.indexOf(selectedCharacter!);
    final nextEntry = next[selectedCharacter!];
    if (_selectedSnapshotChangeId == null &&
        nextEntry != null &&
        !_sameRelationships(characterRelationships, nextEntry.relationships)) {
      setState(() {
        characterRelationships = _mergeDuplicateCharacterRelationships(
          nextEntry.relationships,
        );
        selectedCharacterRelationshipIndex = null;
        _relationshipPersonController.clear();
        _relationshipDescriptionController.clear();
        _relationshipInternalController.clear();
        _loadedCharacterEntrySnapshot =
            (_loadedCharacterEntrySnapshot ?? nextEntry).copyWith(
              relationships: nextEntry.relationships
                  .map((relationship) => relationship.copyWith())
                  .toList(growable: false),
            );
      });
    }
    if (selectedCharacterIndex != nextIndex || forceLoadSelected) {
      setState(() {
        selectedCharacterIndex = nextIndex;
        if (forceLoadSelected) {
          _loadCharacterData(selectedCharacter!);
        }
      });
    }
  }

  bool _sameRelationships(
    List<CharacterRelationship> first,
    List<CharacterRelationship> second,
  ) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  void _hydrateInitialCharacterDataIfNeeded() {
    if (_hasHydratedInitialCharacterData) {
      return;
    }
    _hasHydratedInitialCharacterData = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _syncSelectionFromProviderIfNeeded(
        ref.read(characterDataProvider),
        forceLoadSelected: true,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _setupListeners();
    CharacterDraftSessionCoordinator.instance.register(
      sessionId: widget.projectSessionId,
      owner: this,
      flush: _flushPendingCharacterDraft,
    );
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant CharacterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectionRequestId == widget.selectionRequestId) return;
    final requestedId = widget.initialCharacterId;
    if (requestedId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final index = characters.indexOf(requestedId);
      if (index >= 0 && selectedCharacter != requestedId) {
        _selectCharacter(index);
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    CharacterDraftSessionCoordinator.instance.unregister(
      sessionId: widget.projectSessionId,
      owner: this,
    );
    _tabController.dispose();
    _newCharacterController.dispose();

    // Dispose unified controllers
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _controllerKeys.clear();
    for (final focusNode in _collaborationFocusNodes.values) {
      focusNode.dispose();
    }
    _collaborationFocusNodes.clear();

    _hinderEventController.dispose();
    _solveController.dispose();
    _relationshipPersonController.dispose();
    _relationshipDescriptionController.dispose();
    _relationshipInternalController.dispose();
    _organizationNameController.dispose();
    _organizationDescriptionController.dispose();
    _possessionNameController.dispose();
    _possessionQuantityController.dispose();
    _possessionDescriptionController.dispose();
    _statusNameController.dispose();
    _statusDescriptionController.dispose();
    _customFieldNameController.dispose();
    super.dispose();
  }

  // MARK: - UI 介面

  @override
  Widget build(BuildContext context) {
    // Watch a lightweight fingerprint to avoid overly broad rebuilds while
    // keeping the listener below for selection sync. Register the listener
    // only once during build to avoid duplicate registrations.
    ref.watch(characterDataProvider.select((m) => m.hashCode));
    ref.watch(worldSettingsDataProvider);
    _hydrateInitialCharacterDataIfNeeded();
    if (!_registeredCharacterDataListener) {
      ref.listen<Map<String, CharacterEntryData>>(characterDataProvider, (
        previous,
        next,
      ) {
        if (!mounted || _isLoading) {
          return;
        }
        _syncSelectionFromProviderIfNeeded(next);
      });
      _registeredCharacterDataListener = true;
    }

    return Column(
      children: [
        // Main Content
        Expanded(
          child: AppPageScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LargeTitle(icon: Icons.person_rounded, text: "角色編輯"),
                const SizedBox(height: 32),
                ResponsiveSplitView(
                  breakpoint: 960,
                  spacing: 16,
                  primaryFlex: 1,
                  secondaryFlex: 2,
                  primary: _buildCharacterListSection(),
                  secondary: _buildCharacterEditSection(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCharacterListSection() {
    return AppSectionCard(
      padding: EdgeInsets.zero,
      useSectionLayout: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MediumTitle(icon: Icons.group, text: "角色列表"),
            const SizedBox(height: 8),
            // 新增角色輸入框
            AddItemInput(
              title: "角色名稱",
              controller: _newCharacterController,
              onAdd: (_) => _addCharacter(),
            ),
            const SizedBox(height: 8),
            CollectionPanel.builder(
              title: "角色列表",
              showSectionCard: false,
              minHeight: 200,
              maxHeight: 200,
              itemCount: characters.length,
              emptyTitle: "尚無角色",
              emptyDescription: "請新增第一個角色",
              emptyIcon: Icons.person_add_alt_outlined,
              itemBuilder: (context, index) {
                final characterId = characters[index];
                final isSelected = selectedCharacterIndex == index;

                return DraggableCardNode<String>(
                  key: ValueKey(characterId),
                  dragData: characterId,
                  nodeId: characterId,
                  nodeType: NodeType.item,
                  isDragging: _isDragging,
                  isThisDragging: _currentDragData == characterId,
                  isSelected: isSelected,

                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _characterLabel(characterId),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      RevisionRecordMarker(
                        recordKey: ProjectRecordKey(
                          kind: ProjectRecordKind.character,
                          recordId: characterId,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text("角色類型：${_characterTypeFor(characterId)}"),
                  trailing: ItemActionBar(
                    actions: [
                      ItemAction.delete(
                        onPressed: () => _deleteCharacter(index),
                      ),
                    ],
                  ),
                  onClicked: () => _selectCharacter(index),

                  onDragStarted: () {
                    setState(() {
                      _isDragging = true;
                      _currentDragData = characterId;
                    });
                  },
                  onDragEnd: () {
                    setState(() {
                      _isDragging = false;
                      _currentDragData = null;
                    });
                  },
                  getDropZoneSize: (pos) {
                    if (_currentDragData == null) return 0.0;
                    // 這裡只支援上下排序，不支援資料夾
                    return pos == DropPosition.child ? 0.0 : 0.5;
                  },
                  onAccept: (data, pos) {
                    if (pos == DropPosition.child) return;

                    int toIndex = index;
                    if (pos == DropPosition.after) toIndex++;

                    int fromIndex = characters.indexOf(data);
                    if (fromIndex < 0) return;

                    if (fromIndex < toIndex) toIndex--;

                    _moveCharacter(fromIndex, toIndex);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _moveCharacter(int oldIndex, int newIndex) {
    final currentData = characterData;
    if (oldIndex < 0 || oldIndex >= currentData.length) {
      return;
    }

    final boundedNewIndex = newIndex.clamp(0, currentData.length - 1);
    if (oldIndex == boundedNewIndex) {
      return;
    }

    final orderedNames = currentData.keys.toList(growable: true);
    final movedName = orderedNames.removeAt(oldIndex);
    orderedNames.insert(boundedNewIndex, movedName);

    final reorderedData = <String, CharacterEntryData>{};
    for (final name in orderedNames) {
      final entry = currentData[name];
      if (entry != null) {
        reorderedData[name] = CharacterCodec.copyCharacterEntry(entry);
      }
    }

    _characterNotifier.setCharacterData(reorderedData);
    _emitCharacterDataChanged();

    setState(() {
      if (selectedCharacter != null) {
        selectedCharacterIndex = orderedNames.indexOf(selectedCharacter!);
      }
    });
  }

  Widget _buildCharacterEditSection() {
    // 未選取角色時顯示提示
    if (selectedCharacter == null) {
      return AppSectionCard(
        padding: EdgeInsets.zero,
        useSectionLayout: false,
        child: const SizedBox(
          height: 400,
          child: AppEmptyState(
            title: "請選取一個角色",
            description: "從左側列表選擇要編輯的角色",
            icon: Icons.person_outline,
          ),
        ),
      );
    }

    return AppSectionCard(
      padding: EdgeInsets.zero,
      useSectionLayout: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: _buildSnapshotQuickControls(),
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: "角色卡"),
              Tab(text: "故事快照"),
              Tab(text: "自訂資料"),
              Tab(text: "進階設定"),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: KeyedSubtree(
                key: ValueKey<int>(_tabController.index),
                child: _buildCurrentTab(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshotQuickControls() {
    final characterId = selectedCharacter!;
    final entries = ref.watch(characterSnapshotTimelineProvider(characterId));
    final availableIds = entries
        .map((entry) => entry.change?.stateChangeId)
        .whereType<String>()
        .toSet();
    final selection =
        _selectedSnapshotChangeId != null &&
            availableIds.contains(_selectedSnapshotChangeId)
        ? _selectedSnapshotChangeId!
        : _baselineSnapshotSelection;
    final selectedEntry = selection == _baselineSnapshotSelection
        ? entries.first
        : entries.firstWhere(
            (entry) => entry.change?.stateChangeId == selection,
            orElse: () => entries.first,
          );

    return Row(
      children: [
        Expanded(
          child: AppDropdownField<String>(
            key: ValueKey("character-snapshot-combo-$characterId-$selection"),
            value: selection,
            labelText: "角色快照",
            options: [
              const DropdownOption(
                value: _baselineSnapshotSelection,
                label: "預設",
              ),
              for (final entry in entries.where((entry) => !entry.isBaseline))
                DropdownOption(
                  value: entry.change!.stateChangeId,
                  label:
                      "Tick ${entry.snapshot.resolvedTick} · ${entry.sceneName}",
                ),
            ],
            onChanged: (value) => _switchSnapshotSelection(value, entries),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          key: const ValueKey("character-snapshot-toolbar-add"),
          tooltip: "新增快照",
          onPressed: () => _showAddSnapshotDialog(),
          style: IconButton.styleFrom(foregroundColor: Colors.green),
          icon: const Icon(Icons.add_photo_alternate_outlined),
        ),
        const SizedBox(width: 4),
        IconButton(
          key: const ValueKey("character-snapshot-toolbar-copy"),
          tooltip: "複製目前快照",
          onPressed: () => _showAddSnapshotDialog(
            sourceState: selectedEntry.snapshot.state,
            sourceLabel: selectedEntry.isBaseline
                ? "預設"
                : selectedEntry.sceneName,
          ),
          style: IconButton.styleFrom(foregroundColor: Colors.green),
          icon: const Icon(Icons.copy_all_outlined),
        ),
        const SizedBox(width: 4),
        IconButton(
          key: const ValueKey("character-snapshot-toolbar-delete"),
          tooltip: "刪除目前快照",
          onPressed: selectedEntry.isBaseline
              ? null
              : () => _deleteSnapshot(selectedEntry.change!),
          style: IconButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }

  Widget _buildCurrentTab() {
    switch (_tabController.index) {
      case 0:
        return _buildCoreProfileTab();
      case 1:
        return _buildCharacterSnapshotsTab();
      case 2:
        return _buildCustomFieldsTab();
      case 3:
        return _selectedSnapshotChangeId == null
            ? _buildAdvancedSettingsTab()
            : _buildLockedSnapshotTab("進階設定");
      default:
        return Container();
    }
  }

  Widget _buildCoreProfileTab() {
    final characterId = selectedCharacter!;
    final entries = ref.watch(characterSnapshotTimelineProvider(characterId));
    final selectedEntry = _selectedSnapshotEntry(entries);
    final isBaseline = selectedEntry.isBaseline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isBaseline) ...[
          const AppNoticeBanner(
            message: "正在編輯 Scene 快照：阻礙、人物關係、組織、角色狀態、擁有物品與自訂欄位可修改；其餘固定資料已鎖定。",
            icon: Icons.lock_outline,
            tone: AppFeedbackTone.info,
          ),
          const SizedBox(height: 8),
        ],
        _buildBaseCharacterProfileFields(),
      ],
    );
  }

  void _switchSnapshotSelection(
    String? value,
    List<CharacterSnapshotTimelineEntry> _,
  ) {
    _saveCurrentCharacterData();
    final entries = ref.read(
      characterSnapshotTimelineProvider(selectedCharacter!),
    );
    final selectedId = value == _baselineSnapshotSelection ? null : value;
    final entry = selectedId == null
        ? entries.first
        : entries.firstWhere(
            (item) => item.change?.stateChangeId == selectedId,
            orElse: () => entries.first,
          );
    setState(() {
      _selectedSnapshotChangeId = entry.change?.stateChangeId;
      if (entry.isBaseline) {
        _snapshotCustomFields = <String, CustomFieldValue>{};
        _loadCharacterData(selectedCharacter!);
      } else {
        _loadSnapshotState(entry.snapshot.state);
      }
      _tabController.index = 0;
    });
  }

  void _loadSnapshotState(CharacterSnapshotState state) {
    hinderEvents = state.conflicts
        .map(
          (item) => <String, String>{
            "event": item.obstacle,
            "solve": item.resolution,
          },
        )
        .toList();
    characterRelationships = state.relationships
        .map((item) => item.copyWith())
        .toList();
    organizations = state.organizations.map((item) => item.copyWith()).toList();
    statusEntries = state.statusEntries.map((item) => item.copyWith()).toList();
    possessions = state.possessions.map((item) => item.copyWith()).toList();
    _snapshotCustomFields = Map<String, CustomFieldValue>.from(
      state.customFields,
    );
    selectedHinderIndex = null;
    selectedCharacterRelationshipIndex = null;
    selectedOrganizationIndex = null;
    selectedStatusIndex = null;
    selectedPossessionIndex = null;
    _clearSnapshotTableEditors();
    _dirtyControllerKeys.clear();
    _structuredFieldsDirty = false;
  }

  void _clearSnapshotTableEditors() {
    _hinderEventController.clear();
    _solveController.clear();
    _relationshipPersonController.clear();
    _relationshipDescriptionController.clear();
    _relationshipInternalController.clear();
    _organizationNameController.clear();
    _organizationDescriptionController.clear();
    _statusNameController.clear();
    _statusDescriptionController.clear();
    _possessionNameController.clear();
    _possessionQuantityController.clear();
    _possessionDescriptionController.clear();
  }

  CharacterSnapshotTimelineEntry _selectedSnapshotEntry(
    List<CharacterSnapshotTimelineEntry> entries,
  ) {
    final selectedId = _selectedSnapshotChangeId;
    if (selectedId == null) return entries.first;
    return entries.firstWhere(
      (entry) => entry.change?.stateChangeId == selectedId,
      orElse: () => entries.first,
    );
  }

  Widget _buildBaseCharacterProfileFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SmallTitle(icon: Icons.badge_outlined, text: "基本識別"),
        const SizedBox(height: 16),
        _buildNameField("姓名（必填）：", _controllers["name"]!),
        _buildTextField("身份／職業：", _controllers["roleOrOccupation"]!),
        const SizedBox(height: 8),
        _buildTextField("年齡：", _controllers["age"]!),
        _buildTextField("性別：", _controllers["gender"]!),
        _buildTextField("生日：", _controllers["birthday"]!),
        const SizedBox(height: 8),
        _fixedSnapshotControl(
          AliasTerms(
            values: nicknames,
            onRenamed: (oldName, newName) {
              final id = selectedCharacter;
              if (id != null) {
                ref.read(aliasRenameProvider.notifier).state = AliasRename(
                  id,
                  oldName,
                  newName,
                );
              }
            },
            onChanged: (values) {
              setState(() => nicknames = values);
              _markAsModified(structuredFields: true);
            },
          ),
        ),
        const Divider(height: 32),
        _fixedSnapshotControl(
          ExpansionTile(
            title: SmallTitle(icon: Icons.theater_comedy, text: "角色類型"),
            subtitle: Text(selectedCharacterType),
            children: [_buildCharacterTypeOptions(), const SizedBox(height: 8)],
          ),
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          title: SmallTitle(icon: Icons.face_retouching_natural, text: "外觀摘要"),
          subtitle: const Text("紀錄角色大致外觀。"),
          children: [
            const SizedBox(height: 16),
            _buildTextField("身高：", _controllers["height"]!),
            _buildTextField("體重：", _controllers["weight"]!),
            _buildTextField("髮色：", _controllers["hair"]!),
            _buildTextField("瞳色：", _controllers["eye"]!),
            _buildTextField("外觀摘要：", _controllers["appearanceSummary"]!),
          ],
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          title: SmallTitle(
            icon: Icons.psychology_alt_outlined,
            text: "性格與故事核心",
          ),
          subtitle: const Text("紀錄角色個性，以及在故事中遇到的困難。"),
          children: [
            const SizedBox(height: 16),
            _buildMultilineField("個性：", _controllers["personality"]!),
            _buildTextField("MBTI：", _controllers["mbti"]!),
            _buildTextField("說話風格：", _controllers["speechStyle"]!),
            _buildTextField("動機：", _controllers["motivation"]!),
            _buildTextField("目標：", _controllers["goal"]!),
            _buildTextField("價值觀與信念：", _controllers["valuesAndBeliefs"]!),
            _buildTextField("恐懼：", _controllers["fear"]!),
            const SizedBox(height: 8),
            _buildProfileTableSection<Map<String, String>>(
              title: "阻礙與解決方式",
              icon: Icons.warning_amber,
              firstHeader: "阻礙事件",
              secondHeader: "解決方式",
              emptyDescription: "在下方輸入事件與解決方式後新增",
              keyPrefix: "hinder",
              entries: hinderEvents,
              firstValueOf: (entry) => entry["event"] ?? "",
              secondValueOf: (entry) => entry["solve"] ?? "",
              selectedIndex: selectedHinderIndex,
              firstController: _hinderEventController,
              secondController: _solveController,
              onSelectedIndexChanged: (value) => selectedHinderIndex = value,
              onSubmit: _addHinderEvent,
              onDelete: _deleteHinderEvent,
              onFirstSubmitted: (index, value) =>
                  _updateHinderEventCell(index, event: value),
              onSecondSubmitted: (index, value) =>
                  _updateHinderEventCell(index, solve: value),
            ),
            const SizedBox(height: 8),
          ],
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          title: SmallTitle(icon: Icons.notes_outlined, text: "人物關係描述"),
          subtitle: const Text("描述角色與其他人的連結。"),
          children: [
            const SizedBox(height: 16),
            _buildTextField("人物關係簡述：", _controllers["relationshipSummary"]!),
            const SizedBox(height: 16),
            _buildCharacterRelationshipsTable(),
            const SizedBox(height: 16),
            _buildProfileTableSection(
              title: "所屬組織",
              icon: Icons.corporate_fare_outlined,
              firstHeader: "組織",
              secondHeader: "身分／職位",
              emptyDescription: "在下方輸入組織與身分或職位後新增",
              keyPrefix: "organization",
              entries: organizations,
              firstValueOf: (entry) => entry.name,
              secondValueOf: (entry) => entry.description,
              selectedIndex: selectedOrganizationIndex,
              firstController: _organizationNameController,
              secondController: _organizationDescriptionController,
              firstHint: "選擇地點或組織，或自行輸入",
              firstFieldBuilder: (context, controller) => AppComboBoxField(
                controller: controller,
                options: _worldDirectoryOptionLabels,
                labelText: "組織",
                hintText: "選擇地點或組織，或自行輸入",
                optionMatchesQuery: _matchesWorldDirectoryOption,
                onSelected: (value) {
                  controller.text = _worldDirectoryTargetName(value);
                  controller.selection = TextSelection.collapsed(
                    offset: controller.text.length,
                  );
                },
              ),
              onSelectedIndexChanged: (value) =>
                  selectedOrganizationIndex = value,
              onSubmit: () => _submitProfileTableEntry(
                entries: organizations,
                selectedIndex: selectedOrganizationIndex,
                firstController: _organizationNameController,
                secondController: _organizationDescriptionController,
                onSelectedIndexChanged: (value) =>
                    selectedOrganizationIndex = value,
              ),
              onDelete: () => _deleteProfileTableEntry(
                entries: organizations,
                selectedIndex: selectedOrganizationIndex,
                firstController: _organizationNameController,
                secondController: _organizationDescriptionController,
                onSelectedIndexChanged: (value) =>
                    selectedOrganizationIndex = value,
              ),
              onFirstSubmitted: (index, value) => _updateProfileTableEntry(
                entries: organizations,
                index: index,
                name: value,
                firstController: _organizationNameController,
                secondController: _organizationDescriptionController,
                onSelectedIndexChanged: (value) =>
                    selectedOrganizationIndex = value,
              ),
              onSecondSubmitted: (index, value) => _updateProfileTableEntry(
                entries: organizations,
                index: index,
                description: value,
                firstController: _organizationNameController,
                secondController: _organizationDescriptionController,
                onSelectedIndexChanged: (value) =>
                    selectedOrganizationIndex = value,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          title: SmallTitle(icon: Icons.sensors_rounded, text: "角色狀態"),
          subtitle: const Text("角色的大致狀態。"),
          children: [
            const SizedBox(height: 16),
            _buildProfileTableSection(
              title: "角色狀態",
              icon: Icons.monitor_heart_outlined,
              firstHeader: "狀態",
              secondHeader: "說明",
              emptyDescription: "在下方輸入狀態與說明後新增",
              keyPrefix: "status",
              entries: statusEntries,
              firstValueOf: (entry) => entry.name,
              secondValueOf: (entry) => entry.description,
              selectedIndex: selectedStatusIndex,
              firstController: _statusNameController,
              secondController: _statusDescriptionController,
              onSelectedIndexChanged: (value) => selectedStatusIndex = value,
              onSubmit: () => _submitProfileTableEntry(
                entries: statusEntries,
                selectedIndex: selectedStatusIndex,
                firstController: _statusNameController,
                secondController: _statusDescriptionController,
                onSelectedIndexChanged: (value) => selectedStatusIndex = value,
              ),
              onDelete: () => _deleteProfileTableEntry(
                entries: statusEntries,
                selectedIndex: selectedStatusIndex,
                firstController: _statusNameController,
                secondController: _statusDescriptionController,
                onSelectedIndexChanged: (value) => selectedStatusIndex = value,
              ),
              onFirstSubmitted: (index, value) => _updateProfileTableEntry(
                entries: statusEntries,
                index: index,
                name: value,
                firstController: _statusNameController,
                secondController: _statusDescriptionController,
                onSelectedIndexChanged: (value) => selectedStatusIndex = value,
              ),
              onSecondSubmitted: (index, value) => _updateProfileTableEntry(
                entries: statusEntries,
                index: index,
                description: value,
                firstController: _statusNameController,
                secondController: _statusDescriptionController,
                onSelectedIndexChanged: (value) => selectedStatusIndex = value,
              ),
            ),
            const SizedBox(height: 16),
            if (possessions.isNotEmpty) ...[
              _buildLegacyPossessionMigrationSection(),
              const SizedBox(height: 16),
            ],
            _buildLinkedItemProjection(),
            const SizedBox(height: 8),
          ],
        ),
        const Divider(height: 32),
        SmallTitle(icon: Icons.notes_outlined, text: "備註"),
        const SizedBox(height: 16),
        _buildMultilineField("備註：", _controllers["notes"]!),
      ],
    );
  }

  Widget _buildCharacterSnapshotsTab() {
    final characterId = selectedCharacter!;
    final entries = ref.watch(characterSnapshotTimelineProvider(characterId));
    final current = ref.watch(currentCharacterSnapshotProvider(characterId));
    final currentTick = ref.watch(
      timelineViewProvider.select((state) => state.currentTick),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SmallTitle(
                icon: Icons.auto_stories_outlined,
                text: "故事狀態 · Tick $currentTick",
              ),
            ),
            FilledButton.icon(
              key: const ValueKey("character-snapshot-add"),
              onPressed: () => _showAddSnapshotDialog(),
              icon: const Icon(Icons.add),
              label: const Text("新增 Scene 快照"),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("目前播放頭狀態", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(_snapshotStateSummary(current.state)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => _showAddSnapshotDialog(
                      sourceState: current.state,
                      sourceLabel: "目前 Tick $currentTick",
                    ),
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text("複製目前狀態"),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: SmallTitle(icon: Icons.history, text: "所有快照"),
            ),
            Text("共 ${entries.length} 筆（含預設）"),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(entries.length, (index) {
          final entry = entries[index];
          final previous = index == 0
              ? CharacterSnapshotState()
              : entries[index - 1].snapshot.state;
          final diff = describeCharacterSnapshotDiff(
            previous,
            entry.snapshot.state,
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          entry.isBaseline
                              ? Icons.flag_outlined
                              : Icons.movie_outlined,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.isBaseline
                                ? "預設快照（故事開始前）"
                                : "Tick ${entry.snapshot.resolvedTick} · ${entry.sceneName}",
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (entry.usesFallbackTick)
                          const Tooltip(
                            message: "Scene 尚未排定或主要 placement 已失效",
                            child: Chip(label: Text("Fallback Tick")),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_snapshotStateSummary(entry.snapshot.state)),
                    if (diff.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        "變更：${diff.keys.join("、")}",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (entry.change?.note.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text("備註：${entry.change!.note.trim()}"),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showAddSnapshotDialog(
                            sourceState: entry.snapshot.state,
                            sourceLabel: entry.isBaseline
                                ? "預設快照"
                                : entry.sceneName,
                          ),
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text("複製"),
                        ),
                        if (entry.isBaseline)
                          FilledButton.tonalIcon(
                            onPressed: () => _selectSnapshotForEditing(entry),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text("編輯預設"),
                          )
                        else ...[
                          OutlinedButton.icon(
                            onPressed: () => _locateSnapshot(entry),
                            icon: const Icon(Icons.my_location_outlined),
                            label: const Text("定位"),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => _selectSnapshotForEditing(entry),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text("編輯"),
                          ),
                          IconButton(
                            tooltip: "刪除快照",
                            onPressed: () => _deleteSnapshot(entry.change!),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  String _snapshotStateSummary(CharacterSnapshotState state) {
    final values = <String>[
      "阻礙 ${state.conflicts.length}",
      "人物關係 ${state.relationships.length}",
      "組織 ${state.organizations.length}",
      "角色狀態 ${state.statusEntries.length}",
      "擁有物品 ${state.possessions.length}",
      "自訂欄位 ${state.customFields.length}",
    ];
    return values.join("　");
  }

  Widget _fixedSnapshotControl(Widget child) {
    final locked = _selectedSnapshotChangeId != null;
    return IgnorePointer(
      ignoring: locked,
      child: Opacity(opacity: locked ? 0.5 : 1, child: child),
    );
  }

  void _selectSnapshotForEditing(CharacterSnapshotTimelineEntry entry) {
    _saveCurrentCharacterData();
    setState(() {
      _selectedSnapshotChangeId = entry.change?.stateChangeId;
      if (entry.isBaseline) {
        _snapshotCustomFields = <String, CustomFieldValue>{};
        _loadCharacterData(selectedCharacter!);
      } else {
        _loadSnapshotState(entry.snapshot.state);
      }
      _tabController.index = 0;
    });
  }

  Future<void> _deleteSnapshot(CharacterStateChange change) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("刪除快照？"),
        content: const Text("刪除後，這個 Scene 之後的角色狀態會重新推導。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("取消"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("刪除"),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref
        .read(characterStateChangesProvider.notifier)
        .deleteChange(change.stateChangeId);
    if (_selectedSnapshotChangeId == change.stateChangeId) {
      setState(() {
        _selectedSnapshotChangeId = null;
        _snapshotCustomFields = <String, CustomFieldValue>{};
        _loadCharacterData(selectedCharacter!);
      });
    }
  }

  Widget _buildLockedSnapshotTab(String title) {
    return AppEmptyState(
      title: "$title已鎖定",
      description: "Scene 快照只允許修改五組角色 Table 與自訂欄位；切回「預設」即可編輯固定資料。",
      icon: Icons.lock_outline,
    );
  }

  TimelinePlacementData? _preferredPlacementForScene(String sceneUUID) {
    final document = ref.read(timelineDocumentProvider);
    final tracks = {
      for (final track in document.tracks) track.trackUUID: track.order,
    };
    final matches = document.placements
        .where(
          (placement) =>
              placement.sceneUUID == sceneUUID &&
              placement.level == TimelineElementLevel.small,
        )
        .toList();
    matches.sort((a, b) {
      final byTick = a.startTick.compareTo(b.startTick);
      if (byTick != 0) return byTick;
      final byTrack = (tracks[a.trackUUID] ?? 0).compareTo(
        tracks[b.trackUUID] ?? 0,
      );
      if (byTrack != 0) return byTrack;
      return a.placementUUID.compareTo(b.placementUUID);
    });
    return matches.firstOrNull;
  }

  TimelinePlacementData? _findSnapshotContainer({
    required TimelineDocumentData document,
    required TimelineElementLevel level,
    required String label,
    String? parentPlacementUUID,
    required int nearTick,
  }) {
    final normalized = label.trim().toLowerCase();
    final matches = document.placements
        .where(
          (item) =>
              item.level == level &&
              item.parentPlacementUUID == parentPlacementUUID &&
              item.label.trim().toLowerCase() == normalized,
        )
        .toList();
    matches.sort((a, b) {
      final aDistance = (a.startTick - nearTick).abs();
      final bDistance = (b.startTick - nearTick).abs();
      final byDistance = aDistance.compareTo(bDistance);
      if (byDistance != 0) return byDistance;
      return a.startTick.compareTo(b.startTick);
    });
    return matches.firstOrNull;
  }

  _SnapshotTimelinePreviewData _buildSnapshotTimelinePreview({
    required TimelineDocumentData document,
    required String largeLabel,
    required String middleLabel,
    required int currentTick,
  }) {
    final large = _findSnapshotContainer(
      document: document,
      level: TimelineElementLevel.large,
      label: largeLabel,
      nearTick: currentTick,
    );
    final middle = large == null
        ? null
        : _findSnapshotContainer(
            document: document,
            level: TimelineElementLevel.middle,
            label: middleLabel,
            parentPlacementUUID: large.placementUUID,
            nearTick: currentTick,
          );

    late final String scopeLabel;
    late final String emptyMessage;
    late final List<TimelinePlacementData> placements;
    TimelinePlacementData? scopePlacement;
    if (middle != null) {
      scopeLabel = "中箱：${middle.label}";
      emptyMessage = "此中箱尚無小箱；新 Scene 會建立在這個中箱中。";
      scopePlacement = middle;
      placements = document.placements
          .where(
            (item) =>
                item.level == TimelineElementLevel.small &&
                item.parentPlacementUUID == middle.placementUUID,
          )
          .toList();
    } else if (large != null) {
      scopeLabel = "大箱：${large.label}";
      emptyMessage = "找不到指定中箱；新中箱會建立在這個大箱中。";
      scopePlacement = large;
      placements = document.placements
          .where(
            (item) =>
                item.level == TimelineElementLevel.middle &&
                item.parentPlacementUUID == large.placementUUID,
          )
          .toList();
    } else {
      scopeLabel = "全域預覽";
      emptyMessage = "找不到指定大箱；將建立新的大箱、中箱與 Scene。";
      placements = document.placements
          .where((item) => item.level == TimelineElementLevel.large)
          .toList();
    }
    placements.sort((a, b) {
      final byTick = a.startTick.compareTo(b.startTick);
      if (byTick != 0) return byTick;
      return a.order.compareTo(b.order);
    });

    var minTick = currentTick;
    var maxTick = currentTick;
    void include(TimelinePlacementData item) {
      if (item.startTick < minTick) minTick = item.startTick;
      if (item.endTick > maxTick) maxTick = item.endTick;
    }

    if (scopePlacement != null) include(scopePlacement);
    for (final placement in placements) {
      include(placement);
    }
    final padding = document.grid.ticksPerSmallBox < 1
        ? 1
        : document.grid.ticksPerSmallBox;
    minTick = clampTimelineTick(minTick - padding);
    maxTick = clampTimelineTick(maxTick + padding);
    if (minTick == maxTick) {
      if (maxTick < timelineMaximumTick) {
        maxTick++;
      } else {
        minTick--;
      }
    }

    return _SnapshotTimelinePreviewData(
      scopeLabel: scopeLabel,
      emptyMessage: emptyMessage,
      placements: placements,
      minTick: minTick,
      maxTick: maxTick,
    );
  }

  TimelinePlacementData _createQuickSnapshotScene({
    required String largeLabel,
    required String middleLabel,
    required String sceneLabel,
    required int tick,
  }) {
    final actions = ref.read(timelineActionsProvider);
    var document = ref.read(timelineDocumentProvider);
    var large = _findSnapshotContainer(
      document: document,
      level: TimelineElementLevel.large,
      label: largeLabel,
      nearTick: tick,
    );
    large ??= actions.addPlacement(
      level: TimelineElementLevel.large,
      label: largeLabel.trim(),
      startTick: tick,
    );
    document = ref.read(timelineDocumentProvider);
    var middle = _findSnapshotContainer(
      document: document,
      level: TimelineElementLevel.middle,
      label: middleLabel,
      parentPlacementUUID: large.placementUUID,
      nearTick: tick,
    );
    middle ??= actions.addPlacement(
      level: TimelineElementLevel.middle,
      parentPlacementUUID: large.placementUUID,
      label: middleLabel.trim(),
      startTick: tick,
    );
    return actions.addPlacement(
      level: TimelineElementLevel.small,
      parentPlacementUUID: middle.placementUUID,
      label: sceneLabel.trim(),
      startTick: tick,
    );
  }

  Future<void> _showAddSnapshotDialog({
    CharacterSnapshotState? sourceState,
    String? sourceLabel,
  }) async {
    final characterId = selectedCharacter;
    if (characterId == null) return;
    final sceneIndex = ref.read(timelineSceneIndexProvider);
    final timelineEntries = ref.read(
      characterSnapshotTimelineProvider(characterId),
    );
    final currentSnapshot = ref.read(
      currentCharacterSnapshotProvider(characterId),
    );
    final currentTick = ref.read(timelineViewProvider).currentTick;
    final timelineDocument = ref.read(timelineDocumentProvider);
    const createValue = "__create_scene__";
    String selectedScene = sceneIndex.keys.firstOrNull ?? createValue;
    String selectedSource = sourceState != null ? "provided" : "current";
    final largePlacements =
        timelineDocument.placements
            .where((item) => item.level == TimelineElementLevel.large)
            .toList()
          ..sort(
            (a, b) => (a.startTick - currentTick).abs().compareTo(
              (b.startTick - currentTick).abs(),
            ),
          );
    final initialLarge = largePlacements.firstOrNull;
    final initialMiddle = initialLarge == null
        ? null
        : timelineDocument.placements
              .where(
                (item) =>
                    item.level == TimelineElementLevel.middle &&
                    item.parentPlacementUUID == initialLarge.placementUUID,
              )
              .firstOrNull;
    final largeName = TextEditingController(
      text: initialLarge?.label.trim().isNotEmpty == true
          ? initialLarge!.label.trim()
          : "角色快照",
    );
    final middleName = TextEditingController(
      text: initialMiddle?.label.trim().isNotEmpty == true
          ? initialMiddle!.label.trim()
          : "角色快照 Scene",
    );
    final sceneName = TextEditingController(text: "新 Scene");
    final tick = TextEditingController(text: currentTick.toString());
    var selectedTick = currentTick;
    String? validationMessage;

    final accepted = await AppDialog.showCustom<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final matchingLargeIds = timelineDocument.placements
              .where(
                (item) =>
                    item.level == TimelineElementLevel.large &&
                    item.label.trim().toLowerCase() ==
                        largeName.text.trim().toLowerCase(),
              )
              .map((item) => item.placementUUID)
              .toSet();
          final middleOptions = timelineDocument.placements
              .where(
                (item) =>
                    item.level == TimelineElementLevel.middle &&
                    matchingLargeIds.contains(item.parentPlacementUUID),
              )
              .map((item) => item.label.trim())
              .where((label) => label.isNotEmpty)
              .toSet()
              .toList();
          final timelinePreview = _buildSnapshotTimelinePreview(
            document: timelineDocument,
            largeLabel: largeName.text,
            middleLabel: middleName.text,
            currentTick: selectedTick,
          );

          void setTick(int value) {
            final normalized = clampTimelineTick(value);
            setDialogState(() {
              selectedTick = normalized;
              tick.text = normalized.toString();
              tick.selection = TextSelection.collapsed(
                offset: tick.text.length,
              );
              validationMessage = null;
            });
          }

          return AppDialog(
            title: sourceLabel == null ? "新增 Scene 快照" : "複製 $sourceLabel",
            icon: sourceLabel == null
                ? Icons.add_photo_alternate_outlined
                : Icons.copy_all_outlined,
            maxWidth: 680,
            content: SizedBox(
              width: 632,
              height: selectedScene == createValue
                  ? (MediaQuery.sizeOf(context).height - 220).clamp(420, 680)
                  : sourceState == null
                  ? 150
                  : 180,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppDropdownField<String>(
                      key: const ValueKey("character-snapshot-scene-selector"),
                      value: selectedScene,
                      labelText: "綁定 Scene",
                      options: [
                        for (final entry in sceneIndex.entries)
                          DropdownOption(
                            value: entry.key,
                            label:
                                "${entry.value.storyline.storylineName} / ${entry.value.event.storyEvent} / ${entry.value.scene.sceneName}",
                          ),
                        const DropdownOption(
                          value: createValue,
                          label: "＋ 快速建立新 Scene",
                        ),
                      ],
                      onChanged: (value) => setDialogState(
                        () => selectedScene = value ?? createValue,
                      ),
                    ),
                    if (selectedScene == createValue) ...[
                      const SizedBox(height: 16),
                      AppSectionCard(
                        title: "Scene 階層",
                        icon: Icons.account_tree_outlined,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          children: [
                            AppComboBoxField(
                              key: const ValueKey("snapshot-large-box-combo"),
                              controller: largeName,
                              options: timelineDocument.placements
                                  .where(
                                    (item) =>
                                        item.level ==
                                        TimelineElementLevel.large,
                                  )
                                  .map((item) => item.label),
                              labelText: "大箱（可選既有或輸入新名稱）",
                              hintText: "例如：第一幕",
                              onChanged: (_) => setDialogState(() {}),
                              onSelected: (_) {
                                final matchingLarge = timelineDocument
                                    .placements
                                    .where(
                                      (item) =>
                                          item.level ==
                                              TimelineElementLevel.large &&
                                          item.label.trim().toLowerCase() ==
                                              largeName.text
                                                  .trim()
                                                  .toLowerCase(),
                                    )
                                    .firstOrNull;
                                final firstMiddle = matchingLarge == null
                                    ? null
                                    : timelineDocument.placements
                                          .where(
                                            (item) =>
                                                item.level ==
                                                    TimelineElementLevel
                                                        .middle &&
                                                item.parentPlacementUUID ==
                                                    matchingLarge.placementUUID,
                                          )
                                          .firstOrNull;
                                setDialogState(() {
                                  if (firstMiddle != null) {
                                    middleName.text = firstMiddle.label;
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            AppComboBoxField(
                              key: const ValueKey("snapshot-middle-box-combo"),
                              controller: middleName,
                              options: middleOptions,
                              labelText: "中箱（可選既有或輸入新名稱）",
                              hintText: "例如：城門衝突",
                              onChanged: (_) => setDialogState(() {}),
                              onSelected: (_) => setDialogState(() {}),
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              key: const ValueKey("snapshot-small-box-name"),
                              controller: sceneName,
                              labelText: "小箱（Scene 名稱）",
                              hintText: "例如：抵達城門",
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SnapshotTimelinePreview(
                        key: const ValueKey("character-snapshot-tick-scrubber"),
                        data: timelinePreview,
                        currentTick: selectedTick,
                        onTickChanged: setTick,
                        markers: [
                          for (final entry in timelineEntries)
                            if (!entry.isBaseline)
                              MiniTimelineMarker(
                                id: entry.change!.stateChangeId,
                                tick: entry.snapshot.resolvedTick,
                                label: entry.sceneName,
                              ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        key: const ValueKey("snapshot-tick-field"),
                        controller: tick,
                        labelText: "時間軸 Tick",
                        helperText:
                            "可輸入 $timelineMinimumTick～+$timelineMaximumTick，或在上方時間軸點擊／拖動 Scrubber。",
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                        ),
                        onChanged: (value) {
                          final parsed = int.tryParse(value.trim());
                          if (parsed == null) return;
                          setDialogState(() {
                            if (parsed < timelineMinimumTick ||
                                parsed > timelineMaximumTick) {
                              validationMessage =
                                  "Tick 必須介於 $timelineMinimumTick～+$timelineMaximumTick。";
                              return;
                            }
                            selectedTick = parsed;
                            validationMessage = null;
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (sourceState == null)
                      AppDropdownField<String>(
                        value: selectedSource,
                        labelText: "初始內容",
                        options: [
                          const DropdownOption(value: "blank", label: "空白狀態"),
                          const DropdownOption(
                            value: "current",
                            label: "目前播放頭狀態",
                          ),
                          for (
                            var index = 0;
                            index < timelineEntries.length;
                            index++
                          )
                            DropdownOption(
                              value: "entry:$index",
                              label: timelineEntries[index].isBaseline
                                  ? "預設快照"
                                  : "Tick ${timelineEntries[index].snapshot.resolvedTick} · ${timelineEntries[index].sceneName}",
                            ),
                        ],
                        onChanged: (value) => setDialogState(
                          () => selectedSource = value ?? "current",
                        ),
                      )
                    else
                      AppNoticeBanner(
                        title: "複製來源：${sourceLabel ?? "指定快照"}",
                        message: "會複製來源當下的完整推導狀態。",
                        icon: Icons.copy_outlined,
                      ),
                    if (validationMessage != null) ...[
                      const SizedBox(height: 12),
                      AppNoticeBanner(
                        message: validationMessage!,
                        tone: AppFeedbackTone.error,
                        compact: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text("取消"),
              ),
              FilledButton(
                key: const ValueKey("character-snapshot-dialog-confirm"),
                onPressed: () {
                  final parsedTick = int.tryParse(tick.text.trim());
                  if (selectedScene == createValue &&
                      (parsedTick == null ||
                          parsedTick < timelineMinimumTick ||
                          parsedTick > timelineMaximumTick)) {
                    setDialogState(() {
                      validationMessage =
                          "Tick 必須介於 $timelineMinimumTick～+$timelineMaximumTick。";
                    });
                    return;
                  }
                  if (selectedScene == createValue &&
                      (largeName.text.trim().isEmpty ||
                          middleName.text.trim().isEmpty ||
                          sceneName.text.trim().isEmpty)) {
                    setDialogState(() {
                      validationMessage = "請填寫大箱、中箱與小箱名稱。";
                    });
                    return;
                  }
                  if (selectedScene == createValue) selectedTick = parsedTick!;
                  Navigator.pop(dialogContext, true);
                },
                child: const Text("建立快照"),
              ),
            ],
          );
        },
      ),
    );
    await Future<void>.delayed(kThemeAnimationDuration);
    if (accepted != true || !mounted) {
      largeName.dispose();
      middleName.dispose();
      sceneName.dispose();
      tick.dispose();
      return;
    }

    TimelinePlacementData? placement;
    String sceneUUID;
    if (selectedScene == createValue) {
      placement = _createQuickSnapshotScene(
        largeLabel: largeName.text.trim(),
        middleLabel: middleName.text.trim(),
        sceneLabel: sceneName.text.trim(),
        tick: selectedTick,
      );
      sceneUUID = placement.sceneUUID!;
    } else {
      sceneUUID = selectedScene;
      placement = _preferredPlacementForScene(sceneUUID);
    }

    var seed = sourceState;
    if (seed == null) {
      if (selectedSource == "blank") {
        seed = CharacterSnapshotState();
      } else if (selectedSource.startsWith("entry:")) {
        final index = int.tryParse(selectedSource.substring(6));
        seed = index == null || index < 0 || index >= timelineEntries.length
            ? currentSnapshot.state
            : timelineEntries[index].snapshot.state;
      } else {
        seed = currentSnapshot.state;
      }
    }
    largeName.dispose();
    middleName.dispose();
    sceneName.dispose();
    tick.dispose();
    if (!mounted) return;
    final created = ref
        .read(characterStateChangesProvider.notifier)
        .duplicateSnapshotToScene(
          characterId: characterId,
          source: seed,
          sceneUUID: sceneUUID,
          sourcePlacementUUID: placement?.placementUUID,
          fallbackTick: placement?.startTick ?? currentTick,
          note: sourceLabel == null ? "" : "複製自 $sourceLabel",
        );
    setState(() {
      _selectedSnapshotChangeId = created.stateChangeId;
      _loadSnapshotState(seed!);
      _tabController.index = 0;
    });
    if (placement != null) {
      ref
          .read(timelineViewProvider.notifier)
          .setCurrentTick(placement.startTick);
    }
    if (mounted) {
      AppFeedback.success(context, "已新增 Scene 快照");
    }
  }

  void _locateSnapshot(CharacterSnapshotTimelineEntry entry) {
    ref
        .read(timelineViewProvider.notifier)
        .setCurrentTick(entry.snapshot.resolvedTick);
    final placementUUID = entry.snapshot.sourcePlacementUUID;
    if (placementUUID != null) {
      ref.read(timelineViewProvider.notifier).select(placementUUID);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("已定位至 Tick ${entry.snapshot.resolvedTick}")),
    );
  }

  Widget _buildAdvancedSettingsTab() {
    return Column(
      children: [
        ExpansionTile(
          title: const Text("識別設定"),
          subtitle: const Text("供角色重名時辨識用的 8 位 NanoID"),
          children: [
            const SizedBox(height: 16),
            _buildTextField("NanoID：", _controllers["nanoId"]!),
          ],
        ),
        ExpansionTile(
          title: const Text("詳細基本資料與外觀"),
          subtitle: Text("居住地、五官與服裝"),
          children: [_buildBasicInfoTab()],
        ),
        ExpansionTile(
          title: const Text("性格工具"),
          subtitle: Text("習慣、陣營與性格量表"),
          children: [_buildPersonalityTab()],
        ),
        ExpansionTile(
          title: const Text("喜好與能力"),
          subtitle: Text("能力清單與生活技能量表"),
          children: [_buildAbilityTab()],
        ),
        ExpansionTile(
          title: const Text("社交問卷"),
          subtitle: Text("社交行為、傾向與戀愛概況"),
          children: [_buildSocialTab()],
        ),
        ExpansionTile(
          title: const Text("其他舊欄位"),
          subtitle: Text("原文姓名、喜惡與其他補充"),
          children: [_buildOtherTab()],
        ),
      ],
    );
  }

  String _customFieldTypeLabel(CustomFieldType type) {
    return switch (type) {
      CustomFieldType.text => "文字",
      CustomFieldType.number => "滑桿",
      CustomFieldType.boolean => "核取方塊",
      CustomFieldType.list => "清單",
    };
  }

  Widget _buildCustomFieldsTab() {
    final characterId = selectedCharacter;
    final fields = characterId == null
        ? const <String, CustomFieldValue>{}
        : _selectedSnapshotChangeId == null
        ? characterData[characterId]?.customFields ??
              const <String, CustomFieldValue>{}
        : _snapshotCustomFields;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SmallTitle(icon: Icons.tune, text: "自訂資料"),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: AddItemInput(
                title: "欄位名稱",
                controller: _customFieldNameController,
                onAdd: (_) => _addCustomField(),
              ),
            ),
            SizedBox(
              width: 200,
              child: AppDropdownField<CustomFieldType>(
                value: _newCustomFieldType,
                labelText: "型別",
                options: CustomFieldType.values
                    .map<DropdownOption<CustomFieldType>>(
                      (type) => DropdownOption(
                        value: type,
                        label: _customFieldTypeLabel(type),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _newCustomFieldType = value);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (fields.isEmpty)
          const AppEmptyState(
            title: "尚無自訂資料",
            description: "輸入欄位名稱並選擇型別後新增",
            icon: Icons.tune_outlined,
          )
        else
          for (final field in fields.entries) ...[
            _buildEditableCustomField(field.key, field.value),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Widget _buildEditableCustomField(String key, CustomFieldValue field) {
    final Widget editor = switch (field.type) {
      CustomFieldType.text => AppTextField(
        key: ValueKey("custom-text-$key"),
        initialValue: field.rawValue,
        labelText: key,
        onChanged: (value) => _updateCustomField(
          key,
          CustomFieldValue(type: field.type, rawValue: value),
        ),
      ),
      CustomFieldType.number => Builder(
        builder: (context) {
          final value = (double.tryParse(field.rawValue) ?? 50).clamp(0, 100);
          return LabeledSlider(
            title: key,
            value: value.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            valueLabelBuilder: (next) => "${next.round()}%",
            onChanged: (next) => _updateCustomField(
              key,
              CustomFieldValue(
                type: field.type,
                rawValue: next.toStringAsFixed(0),
              ),
            ),
          );
        },
      ),
      CustomFieldType.boolean => CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(key),
        value: field.rawValue.toLowerCase() == "true",
        onChanged: (value) => _updateCustomField(
          key,
          CustomFieldValue(
            type: field.type,
            rawValue: (value ?? false).toString(),
          ),
        ),
      ),
      CustomFieldType.list => CardList(
        title: key,
        icon: Icons.list_alt,
        showHeader: false,
        items: field.rawValue
            .split(RegExp(r"\r?\n|,"))
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false),
        onAdd: (value) {
          final items = field.rawValue
              .split(RegExp(r"\r?\n|,"))
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList();
          if (value.trim().isNotEmpty) items.add(value.trim());
          _updateCustomField(
            key,
            CustomFieldValue(type: field.type, rawValue: items.join("\n")),
          );
        },
        onRemove: (index) {
          final items =
              field.rawValue
                  .split(RegExp(r"\r?\n|,"))
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .toList()
                ..removeAt(index);
          _updateCustomField(
            key,
            CustomFieldValue(type: field.type, rawValue: items.join("\n")),
          );
        },
      ),
    };
    return Row(
      crossAxisAlignment: field.type == CustomFieldType.list
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Expanded(child: editor),
        const SizedBox(width: 8),
        IconButton(
          tooltip: "移除$key",
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _removeCustomField(key),
        ),
      ],
    );
  }

  void _addCustomField() {
    final key = _customFieldNameController.text.trim();
    if (key.isEmpty) return;
    final defaultValue = switch (_newCustomFieldType) {
      CustomFieldType.text => "",
      CustomFieldType.number => "50",
      CustomFieldType.boolean => "false",
      CustomFieldType.list => "",
    };
    _updateCustomField(
      key,
      CustomFieldValue(type: _newCustomFieldType, rawValue: defaultValue),
    );
    _customFieldNameController.clear();
  }

  void _updateCustomField(String key, CustomFieldValue value) {
    final characterId = selectedCharacter;
    if (characterId == null) return;
    if (_selectedSnapshotChangeId != null) {
      setState(() {
        _snapshotCustomFields = <String, CustomFieldValue>{
          ..._snapshotCustomFields,
          key: value,
        };
      });
      _saveSelectedSnapshotTables();
      return;
    }
    _saveCurrentCharacterData();
    _characterNotifier.updateCharacterEntry(
      characterId,
      (current) =>
          current.copyWith(customFields: {...current.customFields, key: value}),
    );
    _emitCharacterDataChanged();
  }

  void _removeCustomField(String key) {
    final characterId = selectedCharacter;
    if (characterId == null) return;
    if (_selectedSnapshotChangeId != null) {
      setState(() {
        _snapshotCustomFields = Map<String, CustomFieldValue>.from(
          _snapshotCustomFields,
        )..remove(key);
      });
      _saveSelectedSnapshotTables();
      return;
    }
    _saveCurrentCharacterData();
    _characterNotifier.updateCharacterEntry(characterId, (current) {
      final fields = Map<String, CustomFieldValue>.from(current.customFields)
        ..remove(key);
      return current.copyWith(customFields: fields);
    });
    _emitCharacterDataChanged();
  }

  // MARK: - 角色基本資訊

  Widget _buildBasicInfoTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _buildTextField("出生地：", _controllers["native"]!),
        _buildTextField("居住地：", _controllers["live"]!),
        _buildTextField("住址：", _controllers["address"]!),
        const Divider(height: 32),
        SmallTitle(icon: Icons.face, text: "外觀"),
        const SizedBox(height: 8),
        _buildTextField("血型：", _controllers["blood"]!),
        _buildTextField("膚色：", _controllers["skin"]!),
        _buildTextField("臉型：", _controllers["faceFeatures"]!),
        _buildTextField("眼型：", _controllers["eyeFeatures"]!),
        _buildTextField("耳型：", _controllers["earFeatures"]!),
        _buildTextField("鼻型：", _controllers["noseFeatures"]!),
        _buildTextField("嘴型：", _controllers["mouthFeatures"]!),
        _buildTextField("眉型：", _controllers["eyebrowFeatures"]!),
        _buildTextField("體格：", _controllers["body"]!),
        _buildTextField("服裝：", _controllers["dress"]!),
      ],
    );
  }

  // MARK: - 角色個性＆價值觀

  Widget _buildPersonalityTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _buildTextField("口頭禪、慣用語：", _controllers["language"]!),
        _buildTextField("興趣：", _controllers["interest"]!),
        _buildTextField("習慣、癖好：", _controllers["habit"]!),
        _buildTextField("信仰：", _controllers["belief"]!),
        _buildTextField("底線", _controllers["limit"]!),
        _buildTextField("將來想變得如何？", _controllers["future"]!),
        _buildTextField("最珍視的事物？", _controllers["cherish"]!),
        _buildTextField("最厭惡的事物？", _controllers["disgust"]!),
        _buildTextField("最害怕的事物？", _controllers["fear"]!),
        _buildTextField("最好奇的事物？", _controllers["curious"]!),
        _buildTextField("最期待的事物？", _controllers["expect"]!),
        AppSectionCard(
          padding: EdgeInsets.zero,
          useSectionLayout: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SmallTitle(icon: Icons.flag, text: "陣營"),
                const SizedBox(height: 8),
                _buildAlignmentGrid(),
              ],
            ),
          ),
        ),
        AppSectionCard(
          padding: EdgeInsets.zero,
          useSectionLayout: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SmallTitle(icon: Icons.person, text: "性格特質"),
                const SizedBox(height: 16),
                _buildTraitsSliders(),
              ],
            ),
          ),
        ),
        AppSectionCard(
          padding: EdgeInsets.zero,
          useSectionLayout: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SmallTitle(icon: Icons.directions_run, text: "行事作風"),
                const SizedBox(height: 16),
                _buildApproachSliders(),
              ],
            ),
          ),
        ),
        const Divider(height: 32),
        _buildMultilineField("其他補充：", _controllers["otherValues"]!),
      ],
    );
  }

  // MARK: - 角色能力＆才華

  Widget _buildAbilityTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        CardList(
          title: "熱愛做的事情",
          icon: Icons.favorite,
          items: loveToDoList,
          onAdd: _addLoveToDo,
          onRemove: _deleteLoveToDo,
        ),
        const SizedBox(height: 16),
        CardList(
          title: "想要做還沒做的事情",
          icon: Icons.star_border,
          items: wantToDoList,
          onAdd: _addWantToDo,
          onRemove: _deleteWantToDo,
        ),
        const SizedBox(height: 16),
        CardList(
          title: "討厭做的事情",
          icon: Icons.sentiment_very_dissatisfied,
          items: hateToDoList,
          onAdd: _addHateToDo,
          onRemove: _deleteHateToDo,
        ),
        const SizedBox(height: 16),
        CardList(
          title: "害怕做的事情",
          icon: Icons.warning_amber,
          items: fearToDoList,
          onAdd: _addFearToDo,
          onRemove: _deleteFearToDo,
        ),
        const SizedBox(height: 16),
        CardList(
          title: "擅長做的事情",
          icon: Icons.check_circle_outline,
          items: proficientToDoList,
          onAdd: _addProficientToDo,
          onRemove: _deleteProficientToDo,
        ),
        const SizedBox(height: 16),
        CardList(
          title: "不擅長做的事情",
          icon: Icons.cancel_outlined,
          items: unProficientToDoList,
          onAdd: _addUnProficientToDo,
          onRemove: _deleteUnProficientToDo,
        ),
        const SizedBox(height: 16),
        AppSectionCard(
          padding: EdgeInsets.zero,
          useSectionLayout: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SmallTitle(icon: Icons.school, text: "生活常用技能"),
                const SizedBox(height: 16),
                _buildCommonAbilitySliders(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // MARK: - 角色社交相關

  Widget _buildSocialTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _buildMultilineField("來自他人的印象", _controllers["impression"]!),
        const SizedBox(height: 8),
        _buildTextField("最受他人欣賞/喜愛的特點", _controllers["likable"]!),
        const SizedBox(height: 8),
        _buildMultilineField("簡述原生家庭", _controllers["family"]!),
        const Divider(height: 32),
        AppSectionCard(
          padding: EdgeInsets.zero,
          useSectionLayout: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SmallTitle(icon: Icons.sentiment_satisfied, text: "如何表達「喜歡」"),
                const SizedBox(height: 8),
                _buildCheckboxGroup(howToShowLove, howToShowLoveLabels),
                const SizedBox(height: 8),
                _buildTextField("其他", _controllers["otherShowLove"]!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AppSectionCard(
          padding: EdgeInsets.zero,
          useSectionLayout: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SmallTitle(icon: Icons.sentiment_satisfied_alt, text: "如何表達好意"),
                const SizedBox(height: 8),
                _buildCheckboxGroup(howToShowGoodwill, howToShowGoodwillLabels),
                const SizedBox(height: 8),
                _buildTextField("其他", _controllers["otherGoodwill"]!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AppSectionCard(
          padding: EdgeInsets.zero,
          useSectionLayout: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SmallTitle(
                  icon: Icons.sentiment_very_dissatisfied,
                  text: "如何應對討厭的人？",
                ),
                const SizedBox(height: 8),
                _buildCheckboxGroup(handleHatePeople, handleHatePeopleLabels),
                const SizedBox(height: 8),
                _buildTextField("其他", _controllers["otherHatePeople"]!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AppSectionCard(
          padding: EdgeInsets.zero,
          useSectionLayout: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SmallTitle(icon: Icons.favorite, text: "戀愛關係"),
                const SizedBox(height: 8),
                _buildRelationshipSection(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        AppSectionCard(
          padding: EdgeInsets.zero,
          useSectionLayout: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SmallTitle(icon: Icons.group, text: "社交相關項目"),
                const SizedBox(height: 16),
                _buildSocialItemSliders(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // MARK: - 角色其他資料

  Widget _buildOtherTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _buildCollaborativeCharacterTextField(
          label: "原文姓名",
          controller: _controllers["originalName"]!,
          hintText: "例如：桜田如羽",
        ),
        const SizedBox(height: 16),
        CardList(
          title: "喜歡的事物",
          icon: Icons.thumb_up_alt_outlined,
          items: likeItemList,
          onAdd: _addLikeItem,
          onRemove: _deleteLikeItem,
        ),
        const SizedBox(height: 16),
        CardList(
          title: "憧憬的事物",
          icon: Icons.auto_awesome,
          items: admireItemList,
          onAdd: _addAdmireItem,
          onRemove: _deleteAdmireItem,
        ),
        const SizedBox(height: 16),
        CardList(
          title: "討厭的事物",
          icon: Icons.thumb_down_alt_outlined,
          items: hateItemList,
          onAdd: _addHateItem,
          onRemove: _deleteHateItem,
        ),
        const SizedBox(height: 16),
        CardList(
          title: "害怕的事物",
          icon: Icons.bug_report,
          items: fearItemList,
          onAdd: _addFearItem,
          onRemove: _deleteFearItem,
        ),
        const SizedBox(height: 16),
        CardList(
          title: "習慣的事物",
          icon: Icons.history,
          items: familiarItemList,
          onAdd: _addFamiliarItem,
          onRemove: _deleteFamiliarItem,
        ),
        const SizedBox(height: 16),
        _buildMultilineField("其他補充", _controllers["otherText"]!),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return _buildCollaborativeCharacterTextField(
      label: label,
      controller: controller,
    );
  }

  // MARK: - UI 元件建構

  // 專門用於處理角色名稱的欄位,會同步更新列表
  Widget _buildNameField(String label, TextEditingController controller) {
    // 這裡使用 CharacterTextField，它是一個 Stateless Widget
    // 名稱同步邏輯已經在 _setupListeners 中的 addListener 處理了
    return _buildCollaborativeCharacterTextField(
      label: label,
      controller: controller,
    );
  }

  // 多行文字欄位

  Widget _buildMultilineField(String label, TextEditingController controller) {
    return _buildCollaborativeCharacterTextField(
      label: label,
      controller: controller,
      maxLines: 4,
    );
  }

  Widget _buildCollaborativeCharacterTextField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    String? hintText,
  }) {
    final controllerKey = _controllerKeys[controller];
    final characterId = selectedCharacter;
    final focusNode = controllerKey == null
        ? null
        : _collaborationFocusNodes[controllerKey];
    final field = CharacterTextField(
      label: label,
      controller: controller,
      focusNode: focusNode,
      hintText: hintText,
      maxLines: maxLines,
      enabled: _selectedSnapshotChangeId == null,
    );
    if (controllerKey == null || characterId == null || focusNode == null) {
      return field;
    }
    final documentId = ProjectCollaborativeTextCodec.characterFieldId(
      characterId,
      controllerKey,
    );
    final region = CollaborativeProjectTextFieldRegion(
      key: ValueKey("character-text-$characterId-$controllerKey"),
      fieldId: documentId,
      crdtDocumentId: documentId,
      controller: controller,
      focusNode: focusNode,
      shouldPublishTextChanges: () => !_isLoading,
      child: field,
    );
    return Row(
      children: [
        Expanded(child: region),
        RevisionFieldMarker(
          recordKey: ProjectRecordKey(
            kind: ProjectRecordKind.character,
            recordId: characterId,
          ),
          field: controllerKey == 'name' ? 'displayName' : controllerKey,
        ),
      ],
    );
  }

  // 九宮格陣營選擇

  Widget _buildAlignmentGrid() {
    final alignments = [
      ["守序\n善良", "中立\n善良", "混亂\n善良"],
      ["守序\n中立", "絕對\n中立", "混亂\n中立"],
      ["守序\n邪惡", "中立\n邪惡", "絕對\n邪惡"],
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        final row = index ~/ 3;
        final col = index % 3;
        final alignment = alignments[row][col];
        return RadioListTile<String>(
          title: Text(
            alignment,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          value: alignment,
          groupValue: selectedAlignment,
          onChanged: (value) {
            setState(() {
              selectedAlignment = value;
              _markAsModified(structuredFields: true);
            });
          },
        );
      },
    );
  }

  Widget _buildCharacterTypeOptions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final optionWidth = constraints.maxWidth >= 720
            ? (constraints.maxWidth - 16) / 3
            : constraints.maxWidth >= 480
            ? (constraints.maxWidth - 8) / 2
            : constraints.maxWidth;
        return RadioGroup<String>(
          groupValue: selectedCharacterType,
          onChanged: (value) {
            if (value == null || value == selectedCharacterType) return;
            setState(() {
              selectedCharacterType = value;
              _markAsModified(structuredFields: true);
            });
          },
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: characterTypeOptions
                .map(
                  (type) => SizedBox(
                    width: optionWidth,
                    child: RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(type),
                      value: type,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
    );
  }

  Widget _buildCharacterRelationshipsTable() {
    void clearSelection() {
      setState(() {
        selectedCharacterRelationshipIndex = null;
        _relationshipPersonController.clear();
        _relationshipDescriptionController.clear();
        _relationshipInternalController.clear();
      });
    }

    void select(int index) {
      final entry = characterRelationships[index];
      setState(() {
        selectedCharacterRelationshipIndex = index;
        _relationshipPersonController.text = entry.person;
        _relationshipDescriptionController.text = entry.relationship;
        _relationshipInternalController.text = entry.internalRelationship;
      });
    }

    Widget cell(
      int index,
      String suffix,
      String value,
      ValueChanged<String> onSubmitted,
    ) {
      return AppEditableTableCell(
        key: ValueKey("relationship-$suffix-$index"),
        value: value,
        selected: selectedCharacterRelationshipIndex == index,
        onEditStarted: () => select(index),
        onEditCanceled: clearSelection,
        onSubmitted: onSubmitted,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SmallTitle(icon: Icons.people_outline, text: "人物關係"),
        const SizedBox(height: 8),
        AppThreeColumnTable(
          key: const ValueKey("character-relationships-table"),
          firstHeader: "人物",
          secondHeader: "外在關係",
          thirdHeader: "內在關係",
          bodyHeight: 200,
          onSelectionCleared: clearSelection,
          emptyState: const AppEmptyState(
            title: "尚無人物關係",
            description: "在下方輸入人物、外在關係與內在關係後新增",
            icon: Icons.people_outline,
            compact: true,
          ),
          rows: [
            for (var index = 0; index < characterRelationships.length; index++)
              AppThreeColumnTableRow(
                selected: selectedCharacterRelationshipIndex == index,
                showDivider: index != characterRelationships.length - 1,
                firstCell: cell(
                  index,
                  "name",
                  characterRelationships[index].person,
                  (value) =>
                      _updateCharacterRelationshipCell(index, person: value),
                ),
                secondCell: cell(
                  index,
                  "description",
                  characterRelationships[index].relationship,
                  (value) => _updateCharacterRelationshipCell(
                    index,
                    relationship: value,
                  ),
                ),
                thirdCell: cell(
                  index,
                  "internal",
                  characterRelationships[index].internalRelationship,
                  (value) => _updateCharacterRelationshipCell(
                    index,
                    internalRelationship: value,
                  ),
                ),
                onTap: () => select(index),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: Listenable.merge([
            _relationshipPersonController,
            _relationshipDescriptionController,
            _relationshipInternalController,
          ]),
          builder: (context, child) {
            final fields = <Widget>[
              AppComboBoxField(
                controller: _relationshipPersonController,
                options: _relationshipCharacterOptions,
                labelText: "人物",
                hintText: "選擇角色或自行輸入",
                onSelected: (value) {
                  _relationshipPersonController.text = _characterNameFromLabel(
                    value,
                  );
                },
              ),
              AppTextField(
                controller: _relationshipDescriptionController,
                labelText: "外在關係（可留空）",
              ),
              AppTextField(
                controller: _relationshipInternalController,
                labelText: "內在關係（可留空）",
                onSubmitted: (_) => _addCharacterRelationship(),
              ),
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 600) {
                      return Column(
                        children: [
                          for (final field in fields)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: field,
                            ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        for (final field in fields)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                              ),
                              child: field,
                            ),
                          ),
                      ],
                    );
                  },
                ),
                ItemActionBar(
                  actions: [
                    ItemAction.edit(
                      icon: selectedCharacterRelationshipIndex == null
                          ? Icons.add
                          : Icons.save_outlined,
                      tooltip: selectedCharacterRelationshipIndex == null
                          ? "新增"
                          : "更新",
                      onPressed:
                          _relationshipPersonController.text.trim().isEmpty
                          ? null
                          : _addCharacterRelationship,
                    ),
                    ItemAction.delete(
                      tooltip: "刪除",
                      onPressed: selectedCharacterRelationshipIndex == null
                          ? null
                          : _deleteCharacterRelationship,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildProfileTableSection<T>({
    required String title,
    required IconData icon,
    required String firstHeader,
    required String secondHeader,
    required String emptyDescription,
    required String keyPrefix,
    required List<T> entries,
    required String Function(T entry) firstValueOf,
    required String Function(T entry) secondValueOf,
    required int? selectedIndex,
    required TextEditingController firstController,
    required TextEditingController secondController,
    required ValueChanged<int?> onSelectedIndexChanged,
    required VoidCallback onSubmit,
    required VoidCallback onDelete,
    required void Function(int index, String value) onFirstSubmitted,
    required void Function(int index, String value) onSecondSubmitted,
    String? firstHint,
    String? secondFieldLabel,
    AppTwoColumnTableFieldBuilder? firstFieldBuilder,
  }) {
    void clearSelection() {
      if (selectedIndex == null) return;
      setState(() {
        onSelectedIndexChanged(null);
        firstController.clear();
        secondController.clear();
      });
    }

    void select(int index) {
      if (index < 0 || index >= entries.length) return;
      setState(() {
        onSelectedIndexChanged(index);
        firstController.text = firstValueOf(entries[index]);
        secondController.text = secondValueOf(entries[index]);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SmallTitle(icon: icon, text: title),
        const SizedBox(height: 8),
        AppTwoColumnTable(
          firstHeader: firstHeader,
          secondHeader: secondHeader,
          bodyHeight: 200,
          onSelectionCleared: clearSelection,
          emptyState: AppEmptyState(
            title: "尚無$title",
            description: emptyDescription,
            icon: icon,
            compact: true,
          ),
          rows: entries
              .asMap()
              .entries
              .map((mapEntry) {
                final index = mapEntry.key;
                final entry = mapEntry.value;
                final isSelected = selectedIndex == index;
                return AppTwoColumnTableRow(
                  selected: isSelected,
                  showDivider: index != entries.length - 1,
                  firstCell: AppEditableTableCell(
                    key: ValueKey("$keyPrefix-name-$index"),
                    value: firstValueOf(entry),
                    selected: isSelected,
                    onEditStarted: () => select(index),
                    onEditCanceled: clearSelection,
                    onSubmitted: (value) => onFirstSubmitted(index, value),
                  ),
                  secondCell: AppEditableTableCell(
                    key: ValueKey("$keyPrefix-description-$index"),
                    value: secondValueOf(entry),
                    selected: isSelected,
                    onEditStarted: () => select(index),
                    onEditCanceled: clearSelection,
                    onSubmitted: (value) => onSecondSubmitted(index, value),
                  ),
                  onTap: () => select(index),
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: 8),
        AppTwoColumnTableEditor(
          firstController: firstController,
          secondController: secondController,
          firstLabel: firstHeader,
          firstHint: firstHint,
          secondLabel: secondFieldLabel ?? "$secondHeader（可留空）",
          isEditing: selectedIndex != null,
          canSubmit: (first, second) => first.trim().isNotEmpty,
          firstFieldBuilder: firstFieldBuilder,
          onSubmit: (_, _) => onSubmit(),
          onDelete: onDelete,
        ),
      ],
    );
  }

  // Kept temporarily for binary/source compatibility with draft restoration;
  // the UI now exposes legacy possessions through the migration-only section.
  // ignore: unused_element
  Widget _buildPossessionTableSection() {
    void clearSelection() {
      if (selectedPossessionIndex == null) return;
      setState(() {
        selectedPossessionIndex = null;
        _possessionNameController.clear();
        _possessionQuantityController.clear();
        _possessionDescriptionController.clear();
      });
    }

    void select(int index) {
      if (index < 0 || index >= possessions.length) return;
      setState(() {
        selectedPossessionIndex = index;
        _possessionNameController.text = possessions[index].name;
        _possessionQuantityController.text = possessions[index].quantity;
        _possessionDescriptionController.text = possessions[index].description;
      });
    }

    Widget editorField(
      TextEditingController controller,
      String label, {
      TextInputAction textInputAction = TextInputAction.next,
    }) {
      return AppTextField(
        controller: controller,
        labelText: label,
        textInputAction: textInputAction,
        onSubmitted: textInputAction == TextInputAction.done
            ? (_) => _submitPossessionEntry()
            : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SmallTitle(icon: Icons.inventory_2_outlined, text: "擁有物品"),
        const SizedBox(height: 8),
        AppThreeColumnTable(
          key: const ValueKey("possessions-table"),
          firstHeader: "物品",
          secondHeader: "數量",
          thirdHeader: "說明",
          bodyHeight: 200,
          onSelectionCleared: clearSelection,
          emptyState: const AppEmptyState(
            title: "尚無擁有物品",
            description: "在下方輸入物品、數量與說明後新增",
            icon: Icons.inventory_2_outlined,
            compact: true,
          ),
          rows: possessions
              .asMap()
              .entries
              .map((mapEntry) {
                final index = mapEntry.key;
                final entry = mapEntry.value;
                final isSelected = selectedPossessionIndex == index;
                return AppThreeColumnTableRow(
                  selected: isSelected,
                  showDivider: index != possessions.length - 1,
                  firstCell: AppEditableTableCell(
                    key: ValueKey("possession-name-$index"),
                    value: entry.name,
                    selected: isSelected,
                    onEditStarted: () => select(index),
                    onEditCanceled: clearSelection,
                    onSubmitted: (value) =>
                        _updatePossessionEntry(index, name: value),
                  ),
                  secondCell: AppEditableTableCell(
                    key: ValueKey("possession-quantity-$index"),
                    value: entry.quantity,
                    selected: isSelected,
                    onEditStarted: () => select(index),
                    onEditCanceled: clearSelection,
                    onSubmitted: (value) =>
                        _updatePossessionEntry(index, quantity: value),
                  ),
                  thirdCell: AppEditableTableCell(
                    key: ValueKey("possession-description-$index"),
                    value: entry.description,
                    selected: isSelected,
                    onEditStarted: () => select(index),
                    onEditCanceled: clearSelection,
                    onSubmitted: (value) =>
                        _updatePossessionEntry(index, description: value),
                  ),
                  onTap: () => select(index),
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: 8),
        ListenableBuilder(
          key: const ValueKey("possession-editor"),
          listenable: Listenable.merge([
            _possessionNameController,
            _possessionQuantityController,
            _possessionDescriptionController,
          ]),
          builder: (context, child) {
            final canSubmit = _possessionNameController.text.trim().isNotEmpty;
            final fields = <Widget>[
              editorField(_possessionNameController, "物品"),
              editorField(_possessionQuantityController, "數量"),
              editorField(
                _possessionDescriptionController,
                "說明（可留空）",
                textInputAction: TextInputAction.done,
              ),
            ];
            return LayoutBuilder(
              builder: (context, constraints) {
                final actionBar = ItemActionBar(
                  actions: [
                    ItemAction.edit(
                      icon: selectedPossessionIndex == null
                          ? Icons.add
                          : Icons.save_outlined,
                      tooltip: selectedPossessionIndex == null ? "新增" : "更新",
                      onPressed: canSubmit ? _submitPossessionEntry : null,
                    ),
                    ItemAction(
                      icon: Icons.sync_alt,
                      tooltip: "轉換為正式物品",
                      onPressed: selectedPossessionIndex == null
                          ? null
                          : _convertSelectedLegacyPossession,
                    ),
                    ItemAction.delete(
                      tooltip: "刪除",
                      onPressed: selectedPossessionIndex == null
                          ? null
                          : _deletePossessionEntry,
                    ),
                  ],
                );
                if (constraints.maxWidth < 640) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...fields.expand(
                        (field) => [field, const SizedBox(height: 8)],
                      ),
                      Align(alignment: Alignment.centerRight, child: actionBar),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 2, child: fields[0]),
                    const SizedBox(width: 8),
                    Expanded(child: fields[1]),
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: fields[2]),
                    const SizedBox(width: 8),
                    actionBar,
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildLegacyPossessionMigrationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppNoticeBanner(
          message: "以下是舊版擁有物品資料。請逐筆轉換為正式物品；此頁已不再新增舊格式資料。",
          icon: Icons.move_down_outlined,
          tone: AppFeedbackTone.warning,
        ),
        const SizedBox(height: 8),
        ...possessions.asMap().entries.map((entry) {
          final index = entry.key;
          final possession = entry.value;
          return ListTile(
            key: ValueKey("legacy-possession-$index"),
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(possession.name),
            subtitle: Text(
              [
                if (possession.quantity.isNotEmpty) "數量：${possession.quantity}",
                if (possession.description.isNotEmpty) possession.description,
              ].join("・"),
            ),
            trailing: Wrap(
              children: [
                IconButton(
                  key: ValueKey("legacy-possession-convert-$index"),
                  tooltip: "轉換為正式物品",
                  onPressed: () {
                    setState(() => selectedPossessionIndex = index);
                    _convertSelectedLegacyPossession();
                  },
                  icon: const Icon(Icons.sync_alt),
                ),
                IconButton(
                  tooltip: "刪除舊資料",
                  onPressed: () {
                    setState(() {
                      possessions.removeAt(index);
                      selectedPossessionIndex = null;
                      _saveCurrentCharacterData();
                    });
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLinkedItemProjection() {
    final characterId = selectedCharacter;
    if (characterId == null) return const SizedBox.shrink();
    final workspace = ref.watch(itemWorkspaceProvider);
    final tick = ref.watch(
      timelineViewProvider.select((state) => state.currentTick),
    );
    final relatedEntries =
        workspace.itemRelations
            .where(
              (relation) =>
                  relation.targetKind == ItemRelationTargetKind.character &&
                  relation.targetId == characterId,
            )
            .map((relation) {
              final instance = relation.itemKind == ItemReferenceKind.instance
                  ? workspace.itemInstances[relation.itemId]
                  : null;
              final classId = relation.itemKind == ItemReferenceKind.itemClass
                  ? relation.itemId
                  : instance?.classId;
              final label = relation.itemKind == ItemReferenceKind.itemClass
                  ? workspace.itemClasses[classId]?.name
                  : instance?.name;
              return (
                relation: relation,
                classId: classId,
                label: label?.isNotEmpty == true ? label! : relation.itemId,
              );
            })
            .where((entry) => entry.classId != null)
            .toList(growable: false)
          ..sort((a, b) => a.label.compareTo(b.label));
    final entries = <_LinkedCharacterItem>[];
    for (final itemClass in workspace.itemClasses.values) {
      final unit = itemClass.unit.trim();
      final state = ref.watch(
        itemClassSnapshotProvider((id: itemClass.classId, tick: tick)),
      );
      if (state?.exists == true && state!.allocations.isNotEmpty) {
        for (final allocation in state.allocations.where(
          (value) => value.holderCharacterId == characterId,
        )) {
          entries.add(
            _LinkedCharacterItem(
              id: allocation.allocationId,
              classId: itemClass.classId,
              itemId: itemClass.classId,
              itemKind: ItemReferenceKind.itemClass,
              name: state.name.isEmpty ? itemClass.name : state.name,
              quantity: allocation.quantity == null
                  ? "未知"
                  : "${allocation.quantity}${unit.isEmpty ? "" : " $unit"}",
              description: allocation.note.isNotEmpty
                  ? allocation.note
                  : state.status,
            ),
          );
        }
      }
      if (itemClass.mode == ItemMode.generic) continue;
      for (final instance in workspace.itemInstances.values.where(
        (value) => value.classId == itemClass.classId,
      )) {
        final state = ref.watch(
          itemInstanceSnapshotProvider((id: instance.instanceId, tick: tick)),
        );
        if (state == null ||
            !state.exists ||
            state.holderCharacterId != characterId) {
          continue;
        }
        entries.add(
          _LinkedCharacterItem(
            id: instance.instanceId,
            classId: itemClass.classId,
            itemId: instance.instanceId,
            itemKind: ItemReferenceKind.instance,
            name: state.name.isEmpty
                ? (instance.name.isEmpty ? itemClass.name : instance.name)
                : state.name,
            quantity: "1${unit.isEmpty ? "" : " $unit"}",
            description: state.status,
          ),
        );
      }
    }
    entries.sort((a, b) => a.name.compareTo(b.name));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: SmallTitle(icon: Icons.link_outlined, text: "一般關聯物品"),
            ),
            FilledButton.tonalIcon(
              key: const Key("character-link-item"),
              onPressed: () => _linkItemToCharacter(characterId),
              icon: const Icon(Icons.add_link),
              label: const Text("連結物品"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (relatedEntries.isEmpty)
          const Text("尚未設定一般物品關聯。")
        else
          ...relatedEntries.map(
            (entry) => ListTile(
              dense: true,
              key: ValueKey(
                "character-related-item-${entry.relation.relationId}",
              ),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link),
              title: Text(entry.label),
              subtitle: Text(
                [
                  if (entry.relation.role.isNotEmpty) entry.relation.role,
                  if (entry.relation.note.isNotEmpty) entry.relation.note,
                ].join("・"),
              ),
              trailing: Wrap(
                children: [
                  if (widget.onOpenItem != null)
                    IconButton(
                      key: ValueKey(
                        "character-open-related-item-${entry.relation.relationId}",
                      ),
                      tooltip: "開啟物品頁",
                      onPressed: () => widget.onOpenItem!(entry.classId!),
                      icon: const Icon(Icons.open_in_new),
                    ),
                  IconButton(
                    key: ValueKey(
                      "character-unlink-item-${entry.relation.relationId}",
                    ),
                    tooltip: "解除關聯",
                    onPressed: () => ref
                        .read(itemWorkspaceProvider.notifier)
                        .removeRelation(entry.relation.relationId),
                    icon: const Icon(Icons.link_off),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: SmallTitle(
                icon: Icons.inventory_2_outlined,
                text: "目前持有物品",
              ),
            ),
            FilledButton.tonalIcon(
              key: const Key("character-assign-item"),
              onPressed: () => _assignItemToCharacter(characterId),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text("分配物品"),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          const AppEmptyState(
            title: "目前沒有已連結物品",
            description: "按「分配物品」即可在此頁設定持有人或聚合數量",
            icon: Icons.link_off_outlined,
            compact: true,
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              key: const ValueKey("linked-items-table"),
              columns: const [
                DataColumn(label: Text("物品")),
                DataColumn(label: Text("數量"), numeric: true),
                DataColumn(label: Text("狀態／備註")),
                DataColumn(label: Text("操作")),
              ],
              rows: entries
                  .map(
                    (entry) => DataRow(
                      key: ValueKey("linked-item-${entry.id}"),
                      cells: [
                        DataCell(
                          TextButton.icon(
                            key: ValueKey("character-open-item-${entry.id}"),
                            onPressed: widget.onOpenItem == null
                                ? null
                                : () => widget.onOpenItem!(entry.classId),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: Text(entry.name),
                          ),
                        ),
                        DataCell(Text(entry.quantity)),
                        DataCell(Text(entry.description)),
                        DataCell(
                          IconButton(
                            key: ValueKey(
                              "character-unassign-item-${entry.id}",
                            ),
                            tooltip: "清除預設分配",
                            onPressed: () => _clearCharacterItemAssignment(
                              characterId,
                              entry,
                            ),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
      ],
    );
  }

  Future<void> _assignItemToCharacter(String characterId) async {
    final selected = await showProjectObjectSelector(
      context: context,
      title: "選擇要分配給角色的物品",
      allowedKinds: const {
        ProjectObjectKind.itemClass,
        ProjectObjectKind.itemInstance,
      },
    );
    final itemKind = selected?.itemReferenceKind;
    if (!mounted || selected == null || itemKind == null) return;
    int? quantity = 1;
    final workspace = ref.read(itemWorkspaceProvider);
    final itemClass = workspace.itemClasses[selected.classId ?? selected.id];
    if (itemKind == ItemReferenceKind.itemClass &&
        itemClass != null &&
        itemClass.mode != ItemMode.dedicated) {
      var quantityText = "1";
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("分配「${selected.label}」"),
          content: TextFormField(
            key: const Key("character-assignment-quantity"),
            autofocus: true,
            keyboardType: TextInputType.number,
            initialValue: quantityText,
            decoration: appFieldDecoration(
              context,
              decoration: const InputDecoration(
                labelText: "數量",
                helperText: "留空代表數量未知",
              ),
            ),
            onChanged: (value) => quantityText = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("取消"),
            ),
            FilledButton(
              key: const Key("character-assignment-confirm"),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("分配"),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      quantity = quantityText.trim().isEmpty
          ? null
          : int.tryParse(quantityText.trim());
      if (quantityText.trim().isNotEmpty &&
          (quantity == null || quantity < 0)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("數量必須是零或正整數。")));
        return;
      }
    }
    try {
      final current = ref.read(itemWorkspaceProvider);
      final result = assignItemDefault(
        itemClasses: current.itemClasses,
        itemInstances: current.itemInstances,
        itemKind: itemKind,
        itemId: selected.id,
        targetKind: ItemRelationTargetKind.character,
        targetId: characterId,
        allocationId: const Uuid().v4(),
        quantity: quantity,
      );
      ref
          .read(itemWorkspaceProvider.notifier)
          .setWorkspace(
            current.copyWith(
              itemClasses: result.itemClasses,
              itemInstances: result.itemInstances,
            ),
          );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("無法分配物品：$error")));
      }
    }
  }

  void _clearCharacterItemAssignment(
    String characterId,
    _LinkedCharacterItem entry,
  ) {
    final current = ref.read(itemWorkspaceProvider);
    final result = clearItemDefaultAssignment(
      itemClasses: current.itemClasses,
      itemInstances: current.itemInstances,
      itemKind: entry.itemKind,
      itemId: entry.itemId,
      targetKind: ItemRelationTargetKind.character,
      targetId: characterId,
    );
    ref
        .read(itemWorkspaceProvider.notifier)
        .setWorkspace(
          current.copyWith(
            itemClasses: result.itemClasses,
            itemInstances: result.itemInstances,
          ),
        );
  }

  Future<void> _convertSelectedLegacyPossession() async {
    final index = selectedPossessionIndex;
    final characterId = selectedCharacter;
    if (index == null ||
        characterId == null ||
        index < 0 ||
        index >= possessions.length) {
      return;
    }
    final legacy = possessions[index];
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key("character-legacy-item-choice"),
        title: Text("轉換「${legacy.name}」"),
        content: const Text("會移除角色預設與可定位 Scene 快照中的同名舊資料，並建立正式物品狀態。"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("取消"),
          ),
          OutlinedButton(
            key: const Key("character-legacy-item-existing"),
            onPressed: () => Navigator.pop(context, "existing"),
            child: const Text("連結既有"),
          ),
          FilledButton(
            key: const Key("character-legacy-item-create"),
            onPressed: () => Navigator.pop(context, "create"),
            child: const Text("建立並轉換"),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    _LegacyCharacterItemSubject? subject;
    if (action == "existing") {
      final selected = await showProjectObjectSelector(
        context: context,
        title: "選擇「${legacy.name}」對應的正式物品",
        allowedKinds: const <ProjectObjectKind>{
          ProjectObjectKind.itemClass,
          ProjectObjectKind.itemInstance,
        },
      );
      if (selected == null || selected.itemReferenceKind == null) return;
      subject = _LegacyCharacterItemSubject(
        itemId: selected.id,
        itemKind: selected.itemReferenceKind!,
      );
    } else {
      subject = await _showCreateCharacterLegacyItemDialog(legacy);
    }
    if (!mounted || subject == null) return;

    try {
      final preview = _buildLegacyPossessionConversion(
        characterId,
        legacy,
        subject,
      );
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const Key("character-legacy-item-preview"),
          title: const Text("確認持有物轉換"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("預設／baseline：${preview.convertedDefaultOccurrences} 筆"),
              Text("Scene 快照：${preview.convertedSceneOccurrences} 筆"),
              if (preview.preservedUnanchoredOccurrences > 0)
                Text(
                  "另有 ${preview.preservedUnanchoredOccurrences} 筆舊 CharacterState 無法可靠連結 Scene，將保留原文字。",
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("取消"),
            ),
            FilledButton(
              key: const Key("character-legacy-item-confirm"),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("套用轉換"),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final result = _buildLegacyPossessionConversion(
        characterId,
        legacy,
        subject,
      );
      _commitLegacyPossessionConversion(characterId, result);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("持有物轉換失敗：$error")));
      }
    }
  }

  Future<_LegacyCharacterItemSubject?> _showCreateCharacterLegacyItemDialog(
    CharacterPossessionEntry legacy,
  ) async {
    var name = legacy.name.trim();
    var mode = (int.tryParse(legacy.quantity.trim()) ?? 1) > 1
        ? ItemMode.generic
        : ItemMode.dedicated;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          key: const Key("character-legacy-item-create-dialog"),
          title: const Text("建立正式物品"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                decoration: appFieldDecoration(
                  context,
                  decoration: const InputDecoration(labelText: "物品名稱"),
                ),
                onChanged: (value) => setDialogState(() => name = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ItemMode>(
                style: appDropdownTextStyle(context),
                isDense: true,
                isExpanded: true,
                iconSize: AppControlSize.smallIcon,
                itemHeight: appDropdownItemHeight(context),
                menuMaxHeight: AppControlSize.menuMaxHeight,
                initialValue: mode,
                decoration: appDropdownFieldDecoration(
                  context,
                  decoration: const InputDecoration(labelText: "物品模式"),
                ),
                items: const <DropdownMenuItem<ItemMode>>[
                  DropdownMenuItem(
                    value: ItemMode.dedicated,
                    child: Text("專用（建立獨立 ID）"),
                  ),
                  DropdownMenuItem(
                    value: ItemMode.semiDedicated,
                    child: Text("半專用（Class 內建立一件）"),
                  ),
                  DropdownMenuItem(
                    value: ItemMode.generic,
                    child: Text("非專用（保留數量）"),
                  ),
                ],
                onChanged: (value) => setDialogState(() {
                  if (value != null) mode = value;
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("取消"),
            ),
            FilledButton(
              onPressed: name.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text("建立"),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted || name.trim().isEmpty) return null;
    final classId = const Uuid().v4();
    final itemClass = ItemClassData(
      classId: classId,
      name: name.trim(),
      description: legacy.description,
      mode: mode,
    );
    if (mode == ItemMode.generic) {
      return _LegacyCharacterItemSubject(
        itemId: classId,
        itemKind: ItemReferenceKind.itemClass,
        newClass: itemClass,
      );
    }
    final instance = ItemInstanceData(
      instanceId: const Uuid().v4(),
      classId: classId,
      name: name.trim(),
    );
    return _LegacyCharacterItemSubject(
      itemId: instance.instanceId,
      itemKind: ItemReferenceKind.instance,
      newClass: itemClass,
      newInstance: instance,
    );
  }

  LegacyCharacterPossessionConversionResult _buildLegacyPossessionConversion(
    String characterId,
    CharacterPossessionEntry legacy,
    _LegacyCharacterItemSubject subject,
  ) {
    final workspace = ref.read(itemWorkspaceProvider);
    return const LegacyCharacterPossessionConverter().convert(
      characterId: characterId,
      legacy: legacy,
      characterData: ref.read(characterDataProvider),
      baselines: ref.read(characterStateBaselinesProvider),
      characterChanges: ref.read(characterStateChangesProvider),
      legacyStates: ref.read(characterStatesProvider),
      itemClasses: workspace.itemClasses,
      itemInstances: workspace.itemInstances,
      itemRelations: workspace.itemRelations,
      itemClassStateChanges: workspace.itemClassStateChanges,
      itemInstanceStateChanges: workspace.itemInstanceStateChanges,
      itemKind: subject.itemKind,
      itemId: subject.itemId,
      newClass: subject.newClass,
      newInstance: subject.newInstance,
    );
  }

  void _commitLegacyPossessionConversion(
    String characterId,
    LegacyCharacterPossessionConversionResult result,
  ) {
    final oldCharacters = ref.read(characterDataProvider);
    final oldBaselines = ref.read(characterStateBaselinesProvider);
    final oldChanges = ref.read(characterStateChangesProvider);
    final oldWorkspace = ref.read(itemWorkspaceProvider);
    final nextWorkspace = oldWorkspace.copyWith(
      itemClasses: result.itemClasses,
      itemInstances: result.itemInstances,
      itemRelations: result.itemRelations,
      itemClassStateChanges: result.itemClassStateChanges,
      itemInstanceStateChanges: result.itemInstanceStateChanges,
    );
    try {
      ref
          .read(characterDataProvider.notifier)
          .setCharacterData(result.characterData);
      ref
          .read(characterStateBaselinesProvider.notifier)
          .setBaselines(result.baselines);
      ref
          .read(characterStateChangesProvider.notifier)
          .setChanges(result.characterChanges);
      ref.read(itemWorkspaceProvider.notifier).setWorkspace(nextWorkspace);
    } catch (_) {
      ref.read(characterDataProvider.notifier).setCharacterData(oldCharacters);
      ref
          .read(characterStateBaselinesProvider.notifier)
          .setBaselines(oldBaselines);
      ref.read(characterStateChangesProvider.notifier).setChanges(oldChanges);
      ref.read(itemWorkspaceProvider.notifier).setWorkspace(oldWorkspace);
      rethrow;
    }
    setState(() {
      selectedPossessionIndex = null;
      _possessionNameController.clear();
      _possessionQuantityController.clear();
      _possessionDescriptionController.clear();
      final selectedChangeId = _selectedSnapshotChangeId;
      if (selectedChangeId == null) {
        _loadCharacterData(characterId);
      } else {
        final entries = ref.read(
          characterSnapshotTimelineProvider(characterId),
        );
        final selectedEntry = entries
            .where((entry) => entry.change?.stateChangeId == selectedChangeId)
            .firstOrNull;
        if (selectedEntry == null) {
          _selectedSnapshotChangeId = null;
          _loadCharacterData(characterId);
        } else {
          _loadSnapshotState(selectedEntry.snapshot.state);
        }
      }
    });
  }

  Future<void> _linkItemToCharacter(String characterId) async {
    final workspace = ref.read(itemWorkspaceProvider);
    final excluded = workspace.itemRelations
        .where(
          (relation) =>
              relation.targetKind == ItemRelationTargetKind.character &&
              relation.targetId == characterId,
        )
        .map(
          (relation) =>
              "${relation.itemKind == ItemReferenceKind.itemClass ? ProjectObjectKind.itemClass.name : ProjectObjectKind.itemInstance.name}:${relation.itemId}",
        )
        .toSet();
    final selected = await showProjectObjectSelector(
      context: context,
      title: "選擇要連結的人物物品",
      allowedKinds: const {
        ProjectObjectKind.itemClass,
        ProjectObjectKind.itemInstance,
      },
      excludedKeys: excluded,
    );
    final itemKind = selected?.itemReferenceKind;
    if (!mounted || selected == null || itemKind == null) return;
    ref
        .read(itemWorkspaceProvider.notifier)
        .putRelation(
          ItemRelationData(
            relationId: const Uuid().v4(),
            itemId: selected.id,
            itemKind: itemKind,
            targetId: characterId,
            targetKind: ItemRelationTargetKind.character,
            role: "相關",
          ),
        );
  }

  // Checkbox

  Widget _buildCheckboxGroup(
    Map<String, bool> values,
    Map<String, String> labels,
  ) {
    final entries = values.entries.toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 4,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return CheckboxListTile(
          title: Text(
            labels[entry.key] ?? entry.key,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          value: entry.value,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          onChanged: (bool? value) {
            setState(() {
              values[entry.key] = value ?? false;
              _markAsModified(structuredFields: true);
            });
          },
        );
      },
    );
  }

  Widget _buildRelationshipSection() {
    final relationships = ["單身", "已婚/準備結婚", "戀愛中/準備戀愛", "喪偶", "其他"];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...relationships.map(
          (rel) => RadioListTile<String>(
            title: Text(rel),
            value: rel,
            groupValue: selectedRelationship,
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) {
              setState(() {
                selectedRelationship = value;
                _markAsModified(structuredFields: true);
              });
            },
          ),
        ),
        const SizedBox(height: 8),
        _buildCollaborativeCharacterTextField(
          label: "其他：",
          controller: _controllers["otherRelationship"]!,
          hintText: "其他……",
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          title: const Text("另尋新歡？"),
          value: isFindNewLove,
          dense: true,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) {
            setState(() {
              isFindNewLove = value ?? false;
              _markAsModified(structuredFields: true);
            });
          },
        ),
        CheckboxListTile(
          title: const Text("后宮型作品？"),
          value: isHarem,
          dense: true,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) {
            setState(() {
              isHarem = value ?? false;
              _markAsModified(structuredFields: true);
            });
          },
        ),
      ],
    );
  }

  // MARK: - 滑桿元件控制

  Widget _buildCommonAbilitySliders() {
    return Column(
      children: List.generate(TraitDefinitions.commonAbilities.length, (index) {
        final def = TraitDefinitions.commonAbilities[index];
        return CharacterSlider(
          title: def.uiTitle,
          leftLabel: def.uiLeft,
          rightLabel: def.uiRight,
          value: commonAbilityValues[index],
          onChanged: (value) {
            setState(() {
              commonAbilityValues[index] = value;
              _markAsModified(structuredFields: true);
            });
          },
        );
      }),
    );
  }

  Widget _buildSocialItemSliders() {
    return Column(
      children: List.generate(TraitDefinitions.socialItems.length, (index) {
        final def = TraitDefinitions.socialItems[index];
        return CharacterSlider(
          title: def.uiTitle,
          leftLabel: def.uiLeft,
          rightLabel: def.uiRight,
          value: socialItemValues[index],
          onChanged: (value) {
            setState(() {
              socialItemValues[index] = value;
              _markAsModified(structuredFields: true);
            });
          },
        );
      }),
    );
  }

  Widget _buildApproachSliders() {
    return Column(
      children: List.generate(TraitDefinitions.approaches.length, (index) {
        final def = TraitDefinitions.approaches[index];
        return CharacterSlider(
          title: def.uiTitle,
          leftLabel: def.uiLeft,
          rightLabel: def.uiRight,
          value: approachValues[index],
          onChanged: (value) {
            setState(() {
              approachValues[index] = value;
              _markAsModified(structuredFields: true);
            });
          },
        );
      }),
    );
  }

  Widget _buildTraitsSliders() {
    return Column(
      children: List.generate(TraitDefinitions.traits.length, (index) {
        final def = TraitDefinitions.traits[index];
        return CharacterSlider(
          title: def.uiTitle,
          leftLabel: def.uiLeft,
          rightLabel: def.uiRight,
          value: traitsValues[index],
          onChanged: (value) {
            setState(() {
              traitsValues[index] = value;
              _markAsModified(structuredFields: true);
            });
          },
        );
      }),
    );
  }

  // MARK: - Action methods

  // 選擇角色時載入資料
  void _selectCharacter(int index) {
    // 先儲存當前角色的資料
    if (selectedCharacter != null) {
      _saveCurrentCharacterData();
    }

    setState(() {
      selectedCharacterIndex = index;
      selectedCharacter = characters[index];
      _selectedSnapshotChangeId = null;
      _snapshotCustomFields = <String, CustomFieldValue>{};
      _loadCharacterData(selectedCharacter!);
    });
  }

  // 儲存當前角色資料
  void _flushPendingCharacterDraft() {
    if (_dirtyControllerKeys.isEmpty && !_structuredFieldsDirty) {
      return;
    }
    _saveCurrentCharacterData(forceStructuredFields: false);
  }

  void _saveCurrentCharacterData({bool forceStructuredFields = true}) {
    if (!CharacterDraftSessionCoordinator.instance.owns(
      widget.projectSessionId,
      this,
    )) {
      return;
    }
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    final currentId = selectedCharacter;
    if (currentId == null) return;
    if (_selectedSnapshotChangeId != null) {
      _saveSelectedSnapshotTables();
      _dirtyControllerKeys.clear();
      _structuredFieldsDirty = false;
      return;
    }
    if (forceStructuredFields) {
      _structuredFieldsDirty = true;
    }

    final currentEntry = characterData[currentId];
    final controllerName = (_controllers["name"]?.text ?? "").trim();
    final persistedName = (currentEntry?.displayName ?? "").trim();
    final targetName = _dirtyControllerKeys.contains("name")
        ? (controllerName.isEmpty ? persistedName : controllerName)
        : (persistedName.isEmpty ? controllerName : persistedName);
    final currentData = characterData;

    final baseEntry =
        currentData[currentId] ??
        _loadedCharacterEntrySnapshot ??
        CharacterEntryData.withName(targetName);
    final nextEntry = _buildDraftCharacterEntry(
      targetName,
      baseEntry: baseEntry,
      changedControllerKeys: _dirtyControllerKeys,
      includeStructuredFields: _structuredFieldsDirty,
    );

    final didUpdate = _characterNotifier.setCharacterEntry(
      characterId: currentId,
      entry: nextEntry,
    );
    if (didUpdate) {
      _emitCharacterDataChanged();
      if (currentEntry != null &&
          currentEntry.displayName.isNotEmpty &&
          currentEntry.displayName != nextEntry.displayName) {
        ref.read(aliasRenameProvider.notifier).state = AliasRename(
          currentId,
          currentEntry.displayName,
          nextEntry.displayName,
          isPrimaryName: true,
        );
      }
    }
    _commitSavedCharacterEntrySnapshot(nextEntry);
    _setNameFieldTextSilently(targetName);
  }

  CharacterSnapshotState _currentSnapshotTableState() {
    return CharacterSnapshotState(
      conflicts: hinderEvents.map(
        (item) => CharacterConflict(
          obstacle: item["event"] ?? "",
          resolution: item["solve"] ?? "",
        ),
      ),
      relationships: characterRelationships,
      organizations: organizations,
      statusEntries: statusEntries,
      possessions: possessions,
      customFields: _snapshotCustomFields,
    );
  }

  void _saveSelectedSnapshotTables() {
    final changeId = _selectedSnapshotChangeId;
    if (changeId == null) return;
    final changes = ref.read(characterStateChangesProvider);
    final change = changes
        .where((item) => item.stateChangeId == changeId)
        .firstOrNull;
    if (change == null) return;
    ref
        .read(characterStateChangesProvider.notifier)
        .updateChange(
          change.copyWith(
            patch: CharacterStatePatch.fromState(_currentSnapshotTableState()),
          ),
        );
  }

  void _commitSavedCharacterEntrySnapshot(CharacterEntryData entry) {
    _loadedCharacterEntrySnapshot = CharacterCodec.copyCharacterEntry(entry);
    _dirtyControllerKeys.clear();
    _structuredFieldsDirty = false;
  }

  CharacterEntryData _buildDraftCharacterEntry(
    String fallbackName, {
    required CharacterEntryData baseEntry,
    required Set<String> changedControllerKeys,
    required bool includeStructuredFields,
  }) {
    CharacterEntryData nextEntry = CharacterCodec.copyCharacterEntry(baseEntry);

    if (changedControllerKeys.isNotEmpty ||
        (nextEntry.textFields["name"] ?? "") != fallbackName) {
      final nextTextFields = Map<String, String>.from(nextEntry.textFields);
      for (final key in changedControllerKeys) {
        nextTextFields[key] = _controllers[key]?.text ?? "";
      }
      nextTextFields["name"] = fallbackName;
      nextEntry = nextEntry.copyWith(textFields: nextTextFields);
    }

    if (!includeStructuredFields) {
      return _applyCoreProfile(nextEntry, fallbackName);
    }

    return _applyCoreProfile(
      nextEntry.copyWith(
        alignment: selectedAlignment,
        hinderEvents: hinderEvents
            .map(
              (event) => CharacterHinderEvent(
                event: event["event"] ?? "",
                solve: event["solve"] ?? "",
              ),
            )
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
        relationship: selectedRelationship,
        isFindNewLove: isFindNewLove,
        isHarem: isHarem,
        approachValues: List<double>.from(approachValues),
        traitsValues: List<double>.from(traitsValues),
        likeItemList: List<String>.from(likeItemList),
        admireItemList: List<String>.from(admireItemList),
        hateItemList: List<String>.from(hateItemList),
        fearItemList: List<String>.from(fearItemList),
        familiarItemList: List<String>.from(familiarItemList),
      ),
      fallbackName,
    );
  }

  CharacterEntryData _applyCoreProfile(
    CharacterEntryData entry,
    String displayName,
  ) {
    final aliases = <CharacterAlias>[
      ...entry.aliases.where((alias) => alias.type != "nickname"),
      if (nicknames.isNotEmpty)
        CharacterAlias(type: "nickname", values: List<String>.from(nicknames)),
    ];
    return entry
        .copyWith(
          legacyFields: {
            ...entry.legacyFields,
            "nanoId": normalizeCharacterNanoId(_controllers["nanoId"]?.text),
          },
          displayName: displayName,
          aliases: aliases,
          roleOrOccupation: _controllers["roleOrOccupation"]?.text ?? "",
          age: _controllers["age"]?.text ?? "",
          gender: _controllers["gender"]?.text ?? "",
          appearanceSummary: _controllers["appearanceSummary"]?.text ?? "",
          personalitySummary: _controllers["personalitySummary"]?.text ?? "",
          speechStyle: _controllers["speechStyle"]?.text ?? "",
          motivation: _controllers["motivation"]?.text ?? "",
          goal: _controllers["goal"]?.text ?? "",
          conflicts: hinderEvents
              .map(
                (event) => CharacterConflict(
                  obstacle: event["event"] ?? "",
                  resolution: event["solve"] ?? "",
                ),
              )
              .toList(growable: false),
          valuesAndBeliefs: _controllers["valuesAndBeliefs"]?.text ?? "",
          fear: _controllers["fear"]?.text ?? "",
          relationshipSummary: _controllers["relationshipSummary"]?.text ?? "",
          relationships: characterRelationships
              .map((relationship) => relationship.copyWith())
              .toList(growable: false),
          characterType: selectedCharacterType,
          organizations: organizations
              .map((entry) => entry.copyWith())
              .toList(growable: false),
          possessions: possessions
              .map((entry) => entry.copyWith())
              .toList(growable: false),
          statusEntries: statusEntries
              .map((entry) => entry.copyWith())
              .toList(growable: false),
          notes: _controllers["notes"]?.text ?? "",
        )
        .withTextField("name", displayName)
        .withTextField("nickname", nicknames.firstOrNull ?? "");
  }

  void _setNameFieldTextSilently(String value) {
    final controller = _controllers["name"];
    if (controller == null || controller.text == value) {
      return;
    }

    _isLoading = true;
    controller.text = value;
    _isLoading = false;
  }

  List<String> _readStringList(Map<String, dynamic> data, String key) {
    final raw = data[key];
    if (raw is! List) {
      return <String>[];
    }
    return raw.map((item) => item.toString()).toList();
  }

  List<Map<String, String>> _readHinderEvents(
    Map<String, dynamic> data,
    String key,
  ) {
    final raw = data[key];
    if (raw is! List) {
      return <Map<String, String>>[];
    }

    return raw
        .whereType<Map>()
        .map(
          (item) => <String, String>{
            "event": item["event"]?.toString() ?? "",
            "solve": item["solve"]?.toString() ?? "",
          },
        )
        .toList();
  }

  List<double> _readSliderValues(
    Map<String, dynamic> data,
    String key,
    int length,
  ) {
    final raw = data[key];
    if (raw is! List || raw.isEmpty) {
      return List.filled(length, 50.0);
    }

    final typedList = raw
        .map(
          (item) => item is num
              ? item.toDouble()
              : double.tryParse(item.toString()) ?? 50.0,
        )
        .toList();
    if (typedList.length < length) {
      typedList.addAll(List.filled(length - typedList.length, 50.0));
    }
    return typedList;
  }

  bool _readBool(Map<String, dynamic> data, String key) {
    final raw = data[key];
    if (raw is bool) {
      return raw;
    }
    if (raw is num) {
      return raw != 0;
    }
    if (raw is String) {
      return raw.toLowerCase() == "true";
    }
    return false;
  }

  void _mergeBooleanMap(
    Map<String, bool> target,
    Map<String, dynamic> data,
    String key,
  ) {
    final raw = data[key];
    if (raw is! Map) {
      return;
    }

    target.updateAll((entryKey, _) {
      final dynamic value = raw[entryKey];
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
    });
  }

  // 載入角色資料
  void _loadCharacterData(String characterId) {
    _isLoading = true;
    final data = characterData[characterId];

    if (data == null) {
      _clearAllFields();
      if (_controllers.containsKey("name")) {
        _controllers["name"]!.text = "";
      }
      _loadedCharacterEntrySnapshot = null;
      _dirtyControllerKeys.clear();
      _structuredFieldsDirty = false;
      _isLoading = false;
      return;
    }

    _loadedCharacterEntrySnapshot = CharacterCodec.copyCharacterEntry(data);
    final normalizedData = data.toLegacyMap();

    // Load all text controllers
    for (final key in CharacterCodec.allControllerKeys) {
      _controllers[key]?.text = normalizedData[key]?.toString() ?? "";
    }

    // Fallback for name if empty
    if ((_controllers["name"]?.text ?? "").isEmpty) {
      _controllers["name"]?.text = data.displayName;
    }

    selectedAlignment = normalizedData["alignment"]?.toString().replaceAll(
      "\r\n",
      "\n",
    );
    hinderEvents = _readHinderEvents(normalizedData, "hinderEvents");
    nicknames = data.aliases
        .where((alias) => alias.type == "nickname")
        .expand((alias) => alias.values)
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);
    if (nicknames.isEmpty) {
      final legacyNickname = (normalizedData["nickname"] ?? "")
          .toString()
          .trim();
      if (legacyNickname.isNotEmpty) nicknames = [legacyNickname];
    }
    characterRelationships = _mergeDuplicateCharacterRelationships(
      data.relationships,
    );
    selectedCharacterRelationshipIndex = null;
    _relationshipPersonController.clear();
    _relationshipDescriptionController.clear();
    _relationshipInternalController.clear();
    selectedCharacterType = characterTypeOptions.contains(data.characterType)
        ? data.characterType
        : defaultCharacterType;
    organizations = List<CharacterProfileTableEntry>.from(data.organizations);
    possessions = List<CharacterPossessionEntry>.from(data.possessions);
    statusEntries = List<CharacterProfileTableEntry>.from(data.statusEntries);
    selectedOrganizationIndex = null;
    selectedPossessionIndex = null;
    selectedStatusIndex = null;
    _organizationNameController.clear();
    _organizationDescriptionController.clear();
    _possessionNameController.clear();
    _possessionQuantityController.clear();
    _possessionDescriptionController.clear();
    _statusNameController.clear();
    _statusDescriptionController.clear();

    loveToDoList = _readStringList(normalizedData, "loveToDoList");
    hateToDoList = _readStringList(normalizedData, "hateToDoList");
    wantToDoList = _readStringList(normalizedData, "wantToDoList");
    fearToDoList = _readStringList(normalizedData, "fearToDoList");
    proficientToDoList = _readStringList(normalizedData, "proficientToDoList");
    unProficientToDoList = _readStringList(
      normalizedData,
      "unProficientToDoList",
    );
    commonAbilityValues = _readSliderValues(
      normalizedData,
      "commonAbilityValues",
      TraitDefinitions.commonAbilities.length,
    );

    _mergeBooleanMap(howToShowLove, normalizedData, "howToShowLove");
    _mergeBooleanMap(howToShowGoodwill, normalizedData, "howToShowGoodwill");
    _mergeBooleanMap(handleHatePeople, normalizedData, "handleHatePeople");

    socialItemValues = _readSliderValues(
      normalizedData,
      "socialItemValues",
      TraitDefinitions.socialItems.length,
    );
    selectedRelationship = normalizedData["relationship"]?.toString();
    isFindNewLove = _readBool(normalizedData, "isFindNewLove");
    isHarem = _readBool(normalizedData, "isHarem");
    approachValues = _readSliderValues(
      normalizedData,
      "approachValues",
      TraitDefinitions.approaches.length,
    );
    traitsValues = _readSliderValues(
      normalizedData,
      "traitsValues",
      TraitDefinitions.traits.length,
    );

    likeItemList = _readStringList(normalizedData, "likeItemList");
    admireItemList = _readStringList(normalizedData, "admireItemList");
    hateItemList = _readStringList(normalizedData, "hateItemList");
    fearItemList = _readStringList(normalizedData, "fearItemList");
    familiarItemList = _readStringList(normalizedData, "familiarItemList");

    _isLoading = false;
    _dirtyControllerKeys.clear();
    _structuredFieldsDirty = false;
  }

  // 清空所有欄位
  void _clearAllFields() {
    for (var controller in _controllers.values) {
      controller.clear();
    }

    selectedAlignment = null;
    hinderEvents.clear();
    nicknames = [];
    characterRelationships = [];
    selectedCharacterRelationshipIndex = null;
    selectedCharacterType = defaultCharacterType;
    organizations = [];
    possessions = [];
    statusEntries = [];
    selectedOrganizationIndex = null;
    selectedPossessionIndex = null;
    selectedStatusIndex = null;
    loveToDoList.clear();
    hateToDoList.clear();
    wantToDoList.clear();
    fearToDoList.clear();
    proficientToDoList.clear();
    unProficientToDoList.clear();
    commonAbilityValues = List.filled(
      TraitDefinitions.commonAbilities.length,
      50.0,
    );

    howToShowLove.updateAll((key, value) => false);
    howToShowGoodwill.updateAll((key, value) => false);
    handleHatePeople.updateAll((key, value) => false);

    socialItemValues = List.filled(TraitDefinitions.socialItems.length, 50.0);
    selectedRelationship = null;
    isFindNewLove = false;
    isHarem = false;

    approachValues = List.filled(TraitDefinitions.approaches.length, 50.0);
    traitsValues = List.filled(TraitDefinitions.traits.length, 50.0);

    likeItemList.clear();
    admireItemList.clear();
    hateItemList.clear();
    fearItemList.clear();
    familiarItemList.clear();

    // Clear helpers
    _hinderEventController.clear();
    _solveController.clear();
    _relationshipPersonController.clear();
    _relationshipDescriptionController.clear();
    _relationshipInternalController.clear();
    _organizationNameController.clear();
    _organizationDescriptionController.clear();
    _possessionNameController.clear();
    _possessionQuantityController.clear();
    _possessionDescriptionController.clear();
    _statusNameController.clear();
    _statusDescriptionController.clear();
    _loadedCharacterEntrySnapshot = null;
    _dirtyControllerKeys.clear();
    _structuredFieldsDirty = false;
  }

  void _addCharacter() {
    final name = _newCharacterController.text.trim();
    if (name.isEmpty) return;

    // 確保現有更動被儲存
    if (selectedCharacter != null) {
      _saveCurrentCharacterData();
    }

    final entry = CharacterEntryData.withName(name);
    final added = _characterNotifier.setCharacterEntry(
      characterId: entry.characterId,
      entry: entry,
    );
    if (!added) {
      return;
    }
    _emitCharacterDataChanged();

    setState(() {
      _newCharacterController.clear();
      selectedCharacter = entry.characterId;
      selectedCharacterIndex = characters.indexOf(entry.characterId);
      _selectedSnapshotChangeId = null;
      _snapshotCustomFields = <String, CustomFieldValue>{};
      _loadCharacterData(entry.characterId);
    });
  }

  void _deleteCharacter(int index) {
    if (index < 0 || index >= characters.length) {
      return;
    }
    final characterId = characters[index];

    // 確保現有更動被儲存
    if (selectedCharacter != null) {
      _saveCurrentCharacterData();
    }

    final removed = _characterNotifier.removeCharacterEntry(characterId);
    if (!removed) {
      return;
    }
    ref
        .read(characterStateBaselinesProvider.notifier)
        .removeForCharacter(characterId);
    ref
        .read(characterStateChangesProvider.notifier)
        .deleteForCharacter(characterId);
    _emitCharacterDataChanged();

    final nextCharacters = characters;

    setState(() {
      if (nextCharacters.isEmpty) {
        selectedCharacterIndex = null;
        selectedCharacter = null;
        _clearAllFields();
        return;
      }

      if (selectedCharacter == characterId) {
        final nextIndex = index.clamp(0, nextCharacters.length - 1);
        selectedCharacterIndex = nextIndex;
        selectedCharacter = nextCharacters[nextIndex];
        _selectedSnapshotChangeId = null;
        _snapshotCustomFields = <String, CustomFieldValue>{};
        _loadCharacterData(selectedCharacter!);
      } else if (selectedCharacter != null) {
        selectedCharacterIndex = nextCharacters.indexOf(selectedCharacter!);
      }
    });
  }

  void _submitProfileTableEntry({
    required List<CharacterProfileTableEntry> entries,
    required int? selectedIndex,
    required TextEditingController firstController,
    required TextEditingController secondController,
    required ValueChanged<int?> onSelectedIndexChanged,
  }) {
    final name = firstController.text.trim();
    if (name.isEmpty) return;
    final nextEntry = CharacterProfileTableEntry(
      name: name,
      description: secondController.text.trim(),
    );
    setState(() {
      if (selectedIndex != null &&
          selectedIndex >= 0 &&
          selectedIndex < entries.length) {
        entries[selectedIndex] = nextEntry;
      } else {
        entries.add(nextEntry);
      }
      onSelectedIndexChanged(null);
      firstController.clear();
      secondController.clear();
      _saveCurrentCharacterData();
    });
  }

  void _updateProfileTableEntry({
    required List<CharacterProfileTableEntry> entries,
    required int index,
    String? name,
    String? description,
    required TextEditingController firstController,
    required TextEditingController secondController,
    required ValueChanged<int?> onSelectedIndexChanged,
  }) {
    if (index < 0 || index >= entries.length) return;
    final current = entries[index];
    final nextName = name?.trim() ?? current.name;
    if (nextName.isEmpty) return;
    setState(() {
      entries[index] = current.copyWith(
        name: nextName,
        description: description?.trim() ?? current.description,
      );
      onSelectedIndexChanged(index);
      firstController.text = entries[index].name;
      secondController.text = entries[index].description;
      _saveCurrentCharacterData();
    });
  }

  void _deleteProfileTableEntry({
    required List<CharacterProfileTableEntry> entries,
    required int? selectedIndex,
    required TextEditingController firstController,
    required TextEditingController secondController,
    required ValueChanged<int?> onSelectedIndexChanged,
  }) {
    if (selectedIndex == null ||
        selectedIndex < 0 ||
        selectedIndex >= entries.length) {
      return;
    }
    setState(() {
      entries.removeAt(selectedIndex);
      onSelectedIndexChanged(null);
      firstController.clear();
      secondController.clear();
      _saveCurrentCharacterData();
    });
  }

  void _submitPossessionEntry() {
    final name = _possessionNameController.text.trim();
    if (name.isEmpty) return;
    final nextEntry = CharacterPossessionEntry(
      name: name,
      quantity: _possessionQuantityController.text.trim(),
      description: _possessionDescriptionController.text.trim(),
    );
    setState(() {
      final index = selectedPossessionIndex;
      if (index != null && index >= 0 && index < possessions.length) {
        possessions[index] = nextEntry;
      } else {
        possessions.add(nextEntry);
      }
      selectedPossessionIndex = null;
      _possessionNameController.clear();
      _possessionQuantityController.clear();
      _possessionDescriptionController.clear();
      _saveCurrentCharacterData();
    });
  }

  void _updatePossessionEntry(
    int index, {
    String? name,
    String? quantity,
    String? description,
  }) {
    if (index < 0 || index >= possessions.length) return;
    final current = possessions[index];
    final nextName = name?.trim() ?? current.name;
    if (nextName.isEmpty) return;
    setState(() {
      possessions[index] = current.copyWith(
        name: nextName,
        quantity: quantity?.trim() ?? current.quantity,
        description: description?.trim() ?? current.description,
      );
      selectedPossessionIndex = index;
      _possessionNameController.text = possessions[index].name;
      _possessionQuantityController.text = possessions[index].quantity;
      _possessionDescriptionController.text = possessions[index].description;
      _saveCurrentCharacterData();
    });
  }

  void _deletePossessionEntry() {
    final index = selectedPossessionIndex;
    if (index == null || index < 0 || index >= possessions.length) return;
    setState(() {
      possessions.removeAt(index);
      selectedPossessionIndex = null;
      _possessionNameController.clear();
      _possessionQuantityController.clear();
      _possessionDescriptionController.clear();
      _saveCurrentCharacterData();
    });
  }

  void _addHinderEvent() {
    if (_hinderEventController.text.isNotEmpty) {
      setState(() {
        if (selectedHinderIndex != null) {
          // Update existing
          hinderEvents[selectedHinderIndex!] = {
            "event": _hinderEventController.text,
            "solve": _solveController.text,
          };
          selectedHinderIndex = null;
        } else {
          // Add new
          hinderEvents.add({
            "event": _hinderEventController.text,
            "solve": _solveController.text,
          });
        }
        _hinderEventController.clear();
        _solveController.clear();
        _saveCurrentCharacterData();
      });
    }
  }

  void _updateHinderEventCell(int index, {String? event, String? solve}) {
    if (index < 0 || index >= hinderEvents.length) return;
    setState(() {
      final current = hinderEvents[index];
      final nextEvent = event?.trim() ?? current["event"] ?? "";
      if (nextEvent.isEmpty) return;
      hinderEvents[index] = {
        "event": nextEvent,
        "solve": solve?.trim() ?? current["solve"] ?? "",
      };
      if (selectedHinderIndex == index) {
        _hinderEventController.text = hinderEvents[index]["event"] ?? "";
        _solveController.text = hinderEvents[index]["solve"] ?? "";
      }
      _saveCurrentCharacterData();
    });
  }

  void _deleteHinderEvent() {
    if (selectedHinderIndex != null) {
      setState(() {
        hinderEvents.removeAt(selectedHinderIndex!);
        selectedHinderIndex = null;
        _hinderEventController.clear();
        _solveController.clear();
        _saveCurrentCharacterData();
      });
    }
  }

  void _addCharacterRelationship() {
    final person = _relationshipPersonController.text.trim();
    final relationship = _relationshipDescriptionController.text.trim();
    final internalRelationship = _relationshipInternalController.text.trim();
    if (person.isEmpty) return;
    setState(() {
      final value = CharacterRelationship(
        person: person,
        relationship: relationship,
        internalRelationship: internalRelationship,
      );
      final selectedIndex = selectedCharacterRelationshipIndex;
      final duplicateIndex = _findCharacterRelationshipIndex(
        person,
        excluding: selectedIndex,
      );
      if (duplicateIndex >= 0) {
        final existing = characterRelationships[duplicateIndex];
        characterRelationships[duplicateIndex] = existing.copyWith(
          internalRelationship: _appendRelationshipDescription(
            existing.internalRelationship,
            internalRelationship,
          ),
          relationship: _appendRelationshipDescription(
            existing.relationship,
            relationship,
          ),
        );
        if (selectedIndex != null &&
            selectedIndex >= 0 &&
            selectedIndex < characterRelationships.length) {
          characterRelationships.removeAt(selectedIndex);
        }
      } else if (selectedIndex != null &&
          selectedIndex >= 0 &&
          selectedIndex < characterRelationships.length) {
        characterRelationships[selectedIndex] = value;
        selectedCharacterRelationshipIndex = null;
      } else {
        characterRelationships.add(value);
      }
      selectedCharacterRelationshipIndex = null;
      _relationshipPersonController.clear();
      _relationshipDescriptionController.clear();
      _relationshipInternalController.clear();
      _saveCurrentCharacterData();
    });
  }

  int _findCharacterRelationshipIndex(String person, {int? excluding}) {
    final key = person.trim().toLowerCase();
    if (key.isEmpty) return -1;
    for (var index = 0; index < characterRelationships.length; index++) {
      if (index == excluding) continue;
      if (characterRelationships[index].person.trim().toLowerCase() == key) {
        return index;
      }
    }
    return -1;
  }

  String _appendRelationshipDescription(String existing, String incoming) {
    return relationship_operations.appendRelationshipDescription(
      existing,
      incoming,
    );
  }

  List<CharacterRelationship> _mergeDuplicateCharacterRelationships(
    Iterable<CharacterRelationship> relationships,
  ) {
    return relationship_operations.mergeDuplicateCharacterRelationships(
      relationships,
    );
  }

  void _updateCharacterRelationshipCell(
    int index, {
    String? person,
    String? relationship,
    String? internalRelationship,
  }) {
    if (index < 0 || index >= characterRelationships.length) return;
    final current = characterRelationships[index];
    final nextPerson = person?.trim() ?? current.person;
    if (nextPerson.isEmpty) return;
    setState(() {
      final previousLength = characterRelationships.length;
      characterRelationships[index] = current.copyWith(
        person: nextPerson,
        relationship: relationship?.trim() ?? current.relationship,
        internalRelationship:
            internalRelationship?.trim() ?? current.internalRelationship,
      );
      characterRelationships = _mergeDuplicateCharacterRelationships(
        characterRelationships,
      );
      if (characterRelationships.length == previousLength &&
          index < characterRelationships.length) {
        selectedCharacterRelationshipIndex = index;
        _relationshipPersonController.text =
            characterRelationships[index].person;
        _relationshipDescriptionController.text =
            characterRelationships[index].relationship;
        _relationshipInternalController.text =
            characterRelationships[index].internalRelationship;
      } else {
        selectedCharacterRelationshipIndex = null;
        _relationshipPersonController.clear();
        _relationshipDescriptionController.clear();
        _relationshipInternalController.clear();
      }
      _saveCurrentCharacterData();
    });
  }

  void _deleteCharacterRelationship() {
    final index = selectedCharacterRelationshipIndex;
    if (index == null || index < 0 || index >= characterRelationships.length) {
      return;
    }
    setState(() {
      characterRelationships.removeAt(index);
      selectedCharacterRelationshipIndex = null;
      _relationshipPersonController.clear();
      _relationshipDescriptionController.clear();
      _relationshipInternalController.clear();
      _saveCurrentCharacterData();
    });
  }

  void _addLoveToDo(String value) {
    if (value.isNotEmpty) {
      setState(() {
        loveToDoList.add(value);
        _saveCurrentCharacterData();
      });
    }
  }

  void _deleteLoveToDo(int index) {
    setState(() {
      loveToDoList.removeAt(index);
      _saveCurrentCharacterData();
    });
  }

  void _addHateToDo(String value) {
    if (value.isNotEmpty) {
      setState(() {
        hateToDoList.add(value);
        _saveCurrentCharacterData();
      });
    }
  }

  void _deleteHateToDo(int index) {
    setState(() {
      hateToDoList.removeAt(index);
      _saveCurrentCharacterData();
    });
  }

  void _addWantToDo(String value) {
    if (value.isNotEmpty) {
      setState(() {
        wantToDoList.add(value);
        _saveCurrentCharacterData();
      });
    }
  }

  void _deleteWantToDo(int index) {
    setState(() {
      wantToDoList.removeAt(index);
      _saveCurrentCharacterData();
    });
  }

  void _addFearToDo(String value) {
    if (value.isNotEmpty) {
      setState(() {
        fearToDoList.add(value);
        _saveCurrentCharacterData();
      });
    }
  }

  void _deleteFearToDo(int index) {
    setState(() {
      fearToDoList.removeAt(index);
      _saveCurrentCharacterData();
    });
  }

  void _addProficientToDo(String value) {
    if (value.isNotEmpty) {
      setState(() {
        proficientToDoList.add(value);
        _saveCurrentCharacterData();
      });
    }
  }

  void _deleteProficientToDo(int index) {
    setState(() {
      proficientToDoList.removeAt(index);
      _saveCurrentCharacterData();
    });
  }

  void _addUnProficientToDo(String value) {
    if (value.isNotEmpty) {
      setState(() {
        unProficientToDoList.add(value);
        _saveCurrentCharacterData();
      });
    }
  }

  void _deleteUnProficientToDo(int index) {
    setState(() {
      unProficientToDoList.removeAt(index);
      _saveCurrentCharacterData();
    });
  }

  void _addLikeItem(String value) {
    if (value.isNotEmpty) {
      setState(() {
        likeItemList.add(value);
        _saveCurrentCharacterData();
      });
    }
  }

  void _deleteLikeItem(int index) {
    setState(() {
      likeItemList.removeAt(index);
      _saveCurrentCharacterData();
    });
  }

  void _addAdmireItem(String value) {
    if (value.isNotEmpty) {
      setState(() {
        admireItemList.add(value);
        _saveCurrentCharacterData();
      });
    }
  }

  void _deleteAdmireItem(int index) {
    setState(() {
      admireItemList.removeAt(index);
      _saveCurrentCharacterData();
    });
  }

  void _addHateItem(String value) {
    if (value.isNotEmpty) {
      setState(() {
        hateItemList.add(value);
        _saveCurrentCharacterData();
      });
    }
  }

  void _deleteHateItem(int index) {
    setState(() {
      hateItemList.removeAt(index);
      _saveCurrentCharacterData();
    });
  }

  void _addFearItem(String value) {
    if (value.isNotEmpty) {
      setState(() {
        fearItemList.add(value);
        _saveCurrentCharacterData();
      });
    }
  }

  void _deleteFearItem(int index) {
    setState(() {
      fearItemList.removeAt(index);
      _saveCurrentCharacterData();
    });
  }

  void _addFamiliarItem(String value) {
    if (value.isNotEmpty) {
      setState(() {
        familiarItemList.add(value);
        _saveCurrentCharacterData();
      });
    }
  }

  void _deleteFamiliarItem(int index) {
    setState(() {
      familiarItemList.removeAt(index);
      _saveCurrentCharacterData();
    });
  }
}

// MARK: - Independent Widgets

class _SnapshotTimelinePreviewData {
  final String scopeLabel;
  final String emptyMessage;
  final List<TimelinePlacementData> placements;
  final int minTick;
  final int maxTick;

  _SnapshotTimelinePreviewData({
    required this.scopeLabel,
    required this.emptyMessage,
    required Iterable<TimelinePlacementData> placements,
    required this.minTick,
    required this.maxTick,
  }) : placements = List<TimelinePlacementData>.unmodifiable(placements);
}

class _SnapshotTimelinePreview extends StatelessWidget {
  final _SnapshotTimelinePreviewData data;
  final int currentTick;
  final ValueChanged<int> onTickChanged;
  final List<MiniTimelineMarker> markers;

  const _SnapshotTimelinePreview({
    super.key,
    required this.data,
    required this.currentTick,
    required this.onTickChanged,
    this.markers = const [],
  });

  @override
  Widget build(BuildContext context) => AppSectionCard(
    title: "簡易時間軸",
    icon: Icons.timeline_outlined,
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                data.scopeLabel,
                key: const ValueKey("snapshot-timeline-scope"),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Chip(label: Text("Tick $currentTick")),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TimelineMiniView(
          canvasKey: const ValueKey("snapshot-timeline-canvas"),
          placements: data.placements,
          markers: markers,
          currentTick: currentTick,
          minTick: data.minTick,
          maxTick: data.maxTick,
          onTickChanged: onTickChanged,
          emptyMessage: data.emptyMessage,
          semanticLabel: "快照 Tick Scrubber",
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          "點擊或拖曳選擇時間 · 菱形表示既有快照",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
class CharacterSlider extends StatefulWidget {
  final String title;
  final String leftLabel;
  final String rightLabel;
  final double value;
  final ValueChanged<double> onChanged;

  const CharacterSlider({
    super.key,
    required this.title,
    required this.leftLabel,
    required this.rightLabel,
    required this.value,
    required this.onChanged,
  });

  @override
  State<CharacterSlider> createState() => _CharacterSliderState();
}

class _CharacterSliderState extends State<CharacterSlider> {
  late double _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
  }

  @override
  void didUpdateWidget(CharacterSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.value - _currentValue).abs() > 0.01 &&
        widget.value != oldWidget.value) {
      _currentValue = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LabeledSlider(
      title: widget.title,
      value: _currentValue,
      min: 0,
      max: 100,
      divisions: 100,
      leftLabel: widget.leftLabel,
      rightLabel: widget.rightLabel,
      showValue: false,
      layout: LabeledSliderLayout.inline,
      inlineTitleWidth: 60,
      onChanged: (value) {
        setState(() {
          _currentValue = value;
        });
        widget.onChanged(value);
      },
    );
  }
}

class CharacterTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hintText;
  final int maxLines;
  final bool enabled;
  final FocusNode? focusNode;

  const CharacterTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.maxLines = 1,
    this.enabled = true,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppTextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: maxLines,
        labelText: label,
        hintText: hintText,
        enabled: enabled,
      ),
    );
  }
}
