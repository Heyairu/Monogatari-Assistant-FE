/*
 * ものがたり·アシスタント - Monogatari Assistant
 * Copyright (c) 2025 Heyairu（部屋伊琉）
 *
 * Licensed under the Business Source License 1.1 (Modified).
 * You may not use this file except in compliance with the License.
 * Change Date: 2030-11-04 05:14 a.m. (UTC+8)
 * Change License: Apache License 2.0
 *
 * Commercial use allowed under conditions described in Section 1;
 * Competing products (≥3 overlapping modules or similar UI structure)
 * and repackaging without permission are prohibited.
 */

/*
  滑桿儲存格式：
  <slider Title="title" leftTag="leftTag" rightTag="rightTag">數值</slider>
  
  範例：
  <slider Title="courage" leftTag="cowardly" rightTag="brave">30.0</slider>
  
  注意：Title、leftTag、rightTag 使用英文以便多語識別
*/

import "package:flutter/material.dart";
import "dart:async";
import "package:xml/xml.dart" as xml;
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../bin/ui_library.dart";
import "package:logging/logging.dart";
import "../models/character_data.dart";
import "../presentation/providers/project_state_providers.dart";

export "../models/character_data.dart";

final _log = Logger("CharacterView");

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
          final characterName = entry.key;
          final data = entry.value.toLegacyMap();

          builder.element(
            "Character",
            attributes: {"Name": characterName},
            nest: () {
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
    String title,
    String leftTag,
    String rightTag,
    double value,
  ) {
    builder.element(
      "slider",
      attributes: {"Title": title, "leftTag": leftTag, "rightTag": rightTag},
      nest: value.toStringAsFixed(1),
    );
  }

  /// 從 XML 載入角色資料
  static Map<String, CharacterEntryData>? loadXML(String content) {
    try {
      final document = xml.XmlDocument.parse(content);

      final typeElement = document.findAllElements("Type").firstOrNull;
      if (typeElement == null) return null;

      final nameElement = typeElement.findAllElements("Name").firstOrNull;
      if (nameElement?.innerText != "Characters") return null;

      final characterData = <String, CharacterEntryData>{};

      for (final charNode in typeElement.findAllElements("Character")) {
        final characterName = charNode.getAttribute("Name") ?? "";

        final data = <String, dynamic>{};

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
          data["socialItemValues"] = _parseSliders(social, "socialItemSliders");
          data["relationship"] = _getText(social, "relationship");
          data["isFindNewLove"] = _getText(social, "isFindNewLove") == "true";
          data["isHarem"] = _getText(social, "isHarem") == "true";
          data["otherRelationship"] = _getText(social, "otherRelationship");
          data["approachValues"] = _parseSliders(social, "approachSliders");
          data["traitsValues"] = _parseSliders(social, "traitsSliders");
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

        characterData[characterName] = CharacterEntryData.fromLegacyMap(
          data,
          fallbackName: characterName,
        );
      }

      return characterData.isNotEmpty ? characterData : null;
    } catch (e) {
      _log.severe("Error parsing Character XML: $e");
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
    builder.element(
      name,
      nest: () {
        builder.text(_encodeNewlines(value));
      },
    );
  }

  static String _readElementText(xml.XmlElement? element) {
    if (element == null) return "";
    if (element.children.isEmpty) {
      return _decodeNewlines(element.innerText);
    }
    final cdataBuffer = StringBuffer();
    for (final node in element.children) {
      if (node is xml.XmlCDATA) {
        cdataBuffer.write(node.text);
      }
    }
    final cdataText = cdataBuffer.toString();
    if (cdataText.isNotEmpty) {
      return _decodeNewlines(cdataText);
    }
    final buffer = StringBuffer();
    for (final node in element.children) {
      if (node is xml.XmlText || node is xml.XmlCDATA) {
        buffer.write(node.text);
      }
    }
    final text = buffer.toString();
    return _decodeNewlines(text.isNotEmpty ? text : element.innerText);
  }

  static String _encodeNewlines(String value) {
    if (value.isEmpty) return value;
    final normalized = value.replaceAll("\r\n", "\n").replaceAll("\r", "\n");
    final buffer = StringBuffer();
    for (final codeUnit in normalized.codeUnits) {
      switch (codeUnit) {
        case 10: // \n
          buffer.write("&#10;");
          break;
        case 35: // #
          buffer.write("&#35;");
          break;
        case 59: // ;
          buffer.write("&#59;");
          break;
        default:
          buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }

  static String _decodeNewlines(String value) {
    return value
        .replaceAll("&#13;", "")
        .replaceAll("&#10;", "\n")
        .replaceAll("&#35;", "#")
        .replaceAll("&#59;", ";");
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

  static List<double> _parseSliders(xml.XmlElement node, String tagName) {
    final list = <double>[];
    final parent = node.findAllElements(tagName).firstOrNull;
    if (parent != null) {
      for (final slider in parent.findAllElements("slider")) {
        final val = double.tryParse(slider.innerText) ?? 0;
        list.add(val);
      }
    }
    return list;
  }
}

class CharacterView extends ConsumerStatefulWidget {
  const CharacterView({super.key});

  @override
  ConsumerState<CharacterView> createState() => _CharacterViewState();
}

// MARK: - 角色資料控制項

class _CharacterViewState extends ConsumerState<CharacterView>
    with SingleTickerProviderStateMixin {
  // 拖動相關狀態
  bool _isDragging = false;
  String? _currentDragData;

  // Tab Controller
  late TabController _tabController;

  // Character List
  String? selectedCharacter;
  int? selectedCharacterIndex;

  List<String> get characters =>
      ref.read(characterDataProvider).keys.toList(growable: false);
  Map<String, CharacterEntryData> get characterData =>
      ref.read(characterDataProvider);
  CharacterDataNotifier get _characterNotifier =>
      ref.read(characterDataProvider.notifier);

  // New character input controller
  final TextEditingController _newCharacterController = TextEditingController();

  // Unified Text Controllers
  final Map<String, TextEditingController> _controllers = {};

  // Alignment - 陣營 (九宮格)
  String? selectedAlignment;

  // Hinder Events - 阻礙事件
  List<Map<String, String>> hinderEvents = [];
  final TextEditingController _hinderEventController = TextEditingController();
  final TextEditingController _solveController = TextEditingController();
  int? selectedHinderIndex;

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

  void _markAsModified() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) _saveCurrentCharacterData();
    });
  }

  void _setupListeners() {
    // 建立所有控制項
    for (var key in CharacterCodec.allControllerKeys) {
      _controllers[key] = TextEditingController();
    }

    // Name needs specific sync
    final nameController = _controllers["name"];
    if (nameController != null) {
      nameController.addListener(() {
        if (_isLoading) return;
        _syncCharacterName(nameController.text);
        _markAsModified();
      });
    }

    // Batch setup listeners
    for (var entry in _controllers.entries) {
      if (entry.key == "name") continue; // Handled specially

      entry.value.addListener(() {
        if (!_isLoading) _markAsModified();
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
    final names = next.keys.toList(growable: false);

    if (names.isEmpty) {
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
      // During rename, provider update can arrive before local selected key
      // is committed; prefer the current name field text if it exists.
      final pendingName = _controllers["name"]?.text.trim() ?? "";
      if (pendingName.isNotEmpty && next.containsKey(pendingName)) {
        final pendingIndex = names.indexOf(pendingName);
        setState(() {
          selectedCharacter = pendingName;
          selectedCharacterIndex = pendingIndex >= 0 ? pendingIndex : 0;
          _loadCharacterData(selectedCharacter!);
        });
        return;
      }

      setState(() {
        selectedCharacter = names.first;
        selectedCharacterIndex = 0;
        _loadCharacterData(selectedCharacter!);
      });
      return;
    }

    final nextIndex = names.indexOf(selectedCharacter!);
    if (selectedCharacterIndex != nextIndex || forceLoadSelected) {
      setState(() {
        selectedCharacterIndex = nextIndex;
        if (forceLoadSelected) {
          _loadCharacterData(selectedCharacter!);
        }
      });
    }
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
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
      _saveCurrentCharacterData();
    }
    _tabController.dispose();
    _newCharacterController.dispose();

    // Dispose unified controllers
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();

    _hinderEventController.dispose();
    _solveController.dispose();
    super.dispose();
  }

  // MARK: - UI 介面

  @override
  Widget build(BuildContext context) {
    ref.watch(characterDataProvider);
    _hydrateInitialCharacterDataIfNeeded();
    ref.listen<Map<String, CharacterEntryData>>(characterDataProvider, (
      previous,
      next,
    ) {
      if (!mounted || _isLoading) {
        return;
      }
      _syncSelectionFromProviderIfNeeded(next);
    });

    return Column(
      children: [
        // Main Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LargeTitle(icon: Icons.person_rounded, text: "角色編輯"),
                const SizedBox(height: 32),
                _buildCharacterListSection(),
                const SizedBox(height: 16),
                _buildCharacterEditSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCharacterListSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ListView.builder(
                itemCount: characters.length,
                itemBuilder: (context, index) {
                  final name = characters[index];
                  final isSelected = selectedCharacterIndex == index;

                  return DraggableCardNode<String>(
                    key: ValueKey(name),
                    dragData: name,
                    nodeId: name,
                    nodeType: NodeType.item,
                    isDragging: _isDragging,
                    isThisDragging: _currentDragData == name,
                    isSelected: isSelected,

                    title: Text(
                      name,
                      style: isSelected
                          ? TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () => _deleteCharacter(index),
                      tooltip: "刪除",
                    ),
                    onClicked: () => _selectCharacter(index),

                    onDragStarted: () {
                      setState(() {
                        _isDragging = true;
                        _currentDragData = name;
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
      return Card(
        child: SizedBox(
          height: 400,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_outline,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  "請選取一個角色",
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: "基本資料"),
              Tab(text: "個性＆價值觀"),
              Tab(text: "能力＆才華"),
              Tab(text: "社交相關"),
              Tab(text: "其他"),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
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

  Widget _buildCurrentTab() {
    switch (_tabController.index) {
      case 0:
        return _buildBasicInfoTab();
      case 1:
        return _buildPersonalityTab();
      case 2:
        return _buildAbilityTab();
      case 3:
        return _buildSocialTab();
      case 4:
        return _buildOtherTab();
      default:
        return Container();
    }
  }

  // MARK: - 角色基本資訊

  Widget _buildBasicInfoTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildNameField("姓名：", _controllers["name"]!),
        _buildTextField("暱稱：", _controllers["nickname"]!),
        _buildTextField("年齡：", _controllers["age"]!),
        _buildTextField("性別：", _controllers["gender"]!),
        _buildTextField("職業：", _controllers["occupation"]!),
        _buildTextField("生日：", _controllers["birthday"]!),
        _buildTextField("出生地：", _controllers["native"]!),
        _buildTextField("居住地：", _controllers["live"]!),
        _buildTextField("住址：", _controllers["address"]!),
        const Divider(height: 32),
        SmallTitle(icon: Icons.face, text: "外觀"),
        const SizedBox(height: 8),
        _buildTextField("身高：", _controllers["height"]!),
        _buildTextField("體重：", _controllers["weight"]!),
        _buildTextField("血型：", _controllers["blood"]!),
        _buildTextField("髮色：", _controllers["hair"]!),
        _buildTextField("瞳色：", _controllers["eye"]!),
        _buildTextField("膚色：", _controllers["skin"]!),
        _buildTextField("臉型：", _controllers["faceFeatures"]!),
        _buildTextField("眼型：", _controllers["eyeFeatures"]!),
        _buildTextField("耳型：", _controllers["earFeatures"]!),
        _buildTextField("鼻型：", _controllers["noseFeatures"]!),
        _buildTextField("嘴型：", _controllers["mouthFeatures"]!),
        _buildTextField("眉型：", _controllers["eyebrowFeatures"]!),
        _buildTextField("體格：", _controllers["body"]!),
        _buildTextField("服裝：", _controllers["dress"]!),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SmallTitle(icon: Icons.description, text: "故事相關"),
                const SizedBox(height: 16),
                TextField(
                  controller: _controllers["intention"]!,
                  decoration: const InputDecoration(
                    labelText: "故事中的動機、目標？",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SmallTitle(icon: Icons.warning_amber, text: "阻礙主角的事件？"),
                const SizedBox(height: 8),
                _buildHinderTable(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _hinderEventController,
                        decoration: const InputDecoration(
                          labelText: "阻礙事件",
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _addHinderEvent,
                      tooltip: "新增",
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: selectedHinderIndex != null
                          ? _deleteHinderEvent
                          : null,
                      tooltip: "刪除",
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _solveController,
                  decoration: const InputDecoration(
                    labelText: "解決方式",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // MARK: - 角色個性＆價值觀

  Widget _buildPersonalityTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField("MBTI：", _controllers["mbti"]!),
        _buildMultilineField("個性：", _controllers["personality"]!),
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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
        _buildMultilineField("來自他人的印象", _controllers["impression"]!),
        const SizedBox(height: 8),
        _buildTextField("最受他人欣賞/喜愛的特點", _controllers["likable"]!),
        const SizedBox(height: 8),
        _buildMultilineField("簡述原生家庭", _controllers["family"]!),
        const Divider(height: 32),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SmallTitle(icon: Icons.sentiment_satisfied, text: "如何表達「喜歡」"),
                const SizedBox(height: 8),
                _buildCheckboxGroup(howToShowLove, howToShowLoveLabels),
                const SizedBox(height: 8),
                TextField(
                  controller: _controllers["otherShowLove"]!,
                  decoration: const InputDecoration(
                    labelText: "其他",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SmallTitle(icon: Icons.sentiment_satisfied_alt, text: "如何表達好意"),
                const SizedBox(height: 8),
                _buildCheckboxGroup(howToShowGoodwill, howToShowGoodwillLabels),
                const SizedBox(height: 8),
                TextField(
                  controller: _controllers["otherGoodwill"]!,
                  decoration: const InputDecoration(
                    labelText: "其他",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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
                TextField(
                  controller: _controllers["otherHatePeople"]!,
                  decoration: const InputDecoration(
                    labelText: "其他",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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
        TextField(
          controller: _controllers["originalName"]!,
          decoration: const InputDecoration(
            labelText: "原文姓名",
            hintText: "例如：桜田如羽",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        CardList(
          title: "喜歡的人事物",
          icon: Icons.thumb_up_alt_outlined,
          items: likeItemList,
          onAdd: _addLikeItem,
          onRemove: _deleteLikeItem,
        ),
        const SizedBox(height: 16),
        CardList(
          title: "憧憬的人事物",
          icon: Icons.auto_awesome,
          items: admireItemList,
          onAdd: _addAdmireItem,
          onRemove: _deleteAdmireItem,
        ),
        const SizedBox(height: 16),
        CardList(
          title: "討厭的人事物",
          icon: Icons.thumb_down_alt_outlined,
          items: hateItemList,
          onAdd: _addHateItem,
          onRemove: _deleteHateItem,
        ),
        const SizedBox(height: 16),
        CardList(
          title: "害怕的人事物",
          icon: Icons.bug_report,
          items: fearItemList,
          onAdd: _addFearItem,
          onRemove: _deleteFearItem,
        ),
        const SizedBox(height: 16),
        CardList(
          title: "習慣的人事物",
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
    return CharacterTextField(label: label, controller: controller);
  }

  // MARK: - UI 元件建構

  // 專門用於處理角色名稱的欄位,會同步更新列表
  Widget _buildNameField(String label, TextEditingController controller) {
    // 這裡使用 CharacterTextField，它是一個 Stateless Widget
    // 名稱同步邏輯已經在 _setupListeners 中的 addListener 處理了
    return CharacterTextField(label: label, controller: controller);
  }

  // 多行文字欄位

  Widget _buildMultilineField(String label, TextEditingController controller) {
    return CharacterTextField(
      label: label,
      controller: controller,
      maxLines: 4,
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
            style: const TextStyle(fontSize: 12),
          ),
          value: alignment,
          groupValue: selectedAlignment,
          onChanged: (value) {
            setState(() {
              selectedAlignment = value;
              _markAsModified();
            });
          },
        );
      },
    );
  }

  // 阻礙事件表格

  Widget _buildHinderTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      "阻礙事件",
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      "解決方式",
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Data rows
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: hinderEvents.length,
              itemBuilder: (context, index) {
                final event = hinderEvents[index];
                return InkWell(
                  onTap: () {
                    setState(() {
                      selectedHinderIndex = index;
                      _hinderEventController.text = event["event"] ?? "";
                      _solveController.text = event["solve"] ?? "";
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: selectedHinderIndex == index
                          ? Theme.of(context).primaryColor.withOpacity(0.1)
                          : null,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(event["event"] ?? ""),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(event["solve"] ?? ""),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
            style: const TextStyle(fontSize: 13),
          ),
          value: entry.value,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          onChanged: (bool? value) {
            setState(() {
              values[entry.key] = value ?? false;
              _markAsModified();
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
                _markAsModified();
              });
            },
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controllers["otherRelationship"]!,
          decoration: const InputDecoration(
            labelText: "其他：",
            hintText: "其他……",
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
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
              _markAsModified();
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
              _markAsModified();
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
              _markAsModified();
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
              _markAsModified();
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
              _markAsModified();
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
              _markAsModified();
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
      _loadCharacterData(selectedCharacter!);
    });
  }

  // 儲存當前角色資料
  void _saveCurrentCharacterData() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    if (selectedCharacter == null) return;

    final data = <String, dynamic>{};

    // Save all text controllers
    for (final key in CharacterCodec.allControllerKeys) {
      data[key] = _controllers[key]?.text ?? "";
    }

    // Add complex data (raw), then normalize with deep copy in a single path.
    data["alignment"] = selectedAlignment;
    data["hinderEvents"] = hinderEvents;
    data["loveToDoList"] = loveToDoList;
    data["hateToDoList"] = hateToDoList;
    data["wantToDoList"] = wantToDoList;
    data["fearToDoList"] = fearToDoList;
    data["proficientToDoList"] = proficientToDoList;
    data["unProficientToDoList"] = unProficientToDoList;
    data["commonAbilityValues"] = commonAbilityValues;
    data["howToShowLove"] = howToShowLove;
    data["howToShowGoodwill"] = howToShowGoodwill;
    data["handleHatePeople"] = handleHatePeople;
    data["socialItemValues"] = socialItemValues;
    data["relationship"] = selectedRelationship;
    data["isFindNewLove"] = isFindNewLove;
    data["isHarem"] = isHarem;
    data["approachValues"] = approachValues;
    data["traitsValues"] = traitsValues;
    data["likeItemList"] = likeItemList;
    data["admireItemList"] = admireItemList;
    data["hateItemList"] = hateItemList;
    data["fearItemList"] = fearItemList;
    data["familiarItemList"] = familiarItemList;

    final didUpdate = _characterNotifier.setCharacterEntry(
      name: selectedCharacter!,
      entry: CharacterEntryData.fromLegacyMap(
        data,
        fallbackName: selectedCharacter,
      ),
    );

    if (didUpdate) {
      _emitCharacterDataChanged();
    }
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
  void _loadCharacterData(String characterName) {
    _isLoading = true;
    final data = characterData[characterName];

    if (data == null) {
      _clearAllFields();
      if (_controllers.containsKey("name")) {
        _controllers["name"]!.text = characterName;
      }
      _isLoading = false;
      return;
    }

    final normalizedData = data.toLegacyMap();

    // Load all text controllers
    for (final key in CharacterCodec.allControllerKeys) {
      _controllers[key]?.text = normalizedData[key]?.toString() ?? "";
    }

    // Fallback for name if empty
    if ((_controllers["name"]?.text ?? "").isEmpty) {
      _controllers["name"]?.text = characterName;
    }

    selectedAlignment = normalizedData["alignment"]?.toString().replaceAll(
      "\r\n",
      "\n",
    );
    hinderEvents = _readHinderEvents(normalizedData, "hinderEvents");

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
  }

  // 清空所有欄位
  void _clearAllFields() {
    for (var controller in _controllers.values) {
      controller.clear();
    }

    selectedAlignment = null;
    hinderEvents.clear();
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
  }

  // 同步角色名稱到列表
  void _syncCharacterName(String newName) {
    if (selectedCharacter == null || selectedCharacterIndex == null) return;

    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) return;

    // 檢查名稱是否與其他角色重複
    if (trimmedName != selectedCharacter && characters.contains(trimmedName)) {
      // 如果重複,不進行更新,可以顯示提示
      return;
    }

    final oldName = selectedCharacter!;
    if (oldName == trimmedName) {
      return;
    }

    final currentData = characterData;
    final oldEntry = currentData[oldName];
    if (oldEntry == null) {
      return;
    }

    final orderedNames = currentData.keys.toList(growable: true);
    final currentIndex = orderedNames.indexOf(oldName);
    if (currentIndex < 0) {
      return;
    }
    orderedNames[currentIndex] = trimmedName;

    final renamedEntry = CharacterCodec.copyCharacterEntry(
      oldEntry,
    ).withTextField("name", trimmedName);
    final nextCharacterData = <String, CharacterEntryData>{};
    for (final name in orderedNames) {
      if (name == trimmedName) {
        nextCharacterData[name] = renamedEntry;
        continue;
      }

      final entry = currentData[name];
      if (entry != null) {
        nextCharacterData[name] = CharacterCodec.copyCharacterEntry(entry);
      }
    }

    // Update local selection first to avoid listener race that may fallback to
    // index 0 before the renamed key is observed.
    selectedCharacter = trimmedName;
    selectedCharacterIndex = currentIndex;

    _characterNotifier.setCharacterData(nextCharacterData);
    _emitCharacterDataChanged();

    setState(() {
      selectedCharacter = trimmedName;
      selectedCharacterIndex = currentIndex;
    });
  }

  void _addCharacter() {
    final name = _newCharacterController.text.trim();
    if (name.isEmpty) return;

    if (characters.contains(name)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("角色名稱已存在")));
      return;
    }

    // 確保現有更動被儲存
    if (selectedCharacter != null) {
      _saveCurrentCharacterData();
    }

    final added = _characterNotifier.setCharacterEntry(
      name: name,
      entry: CharacterEntryData.withName(name),
    );
    if (!added) {
      return;
    }
    _emitCharacterDataChanged();

    setState(() {
      _newCharacterController.clear();
      selectedCharacter = name;
      selectedCharacterIndex = characters.indexOf(name);
      _loadCharacterData(name);
    });
  }

  void _deleteCharacter(int index) {
    if (index < 0 || index >= characters.length) {
      return;
    }
    final characterName = characters[index];

    // 確保現有更動被儲存
    if (selectedCharacter != null) {
      _saveCurrentCharacterData();
    }

    final removed = _characterNotifier.removeCharacterEntry(characterName);
    if (!removed) {
      return;
    }
    _emitCharacterDataChanged();

    final nextCharacters = characters;

    setState(() {
      if (nextCharacters.isEmpty) {
        selectedCharacterIndex = null;
        selectedCharacter = null;
        _clearAllFields();
        return;
      }

      if (selectedCharacter == characterName) {
        final nextIndex = index.clamp(0, nextCharacters.length - 1);
        selectedCharacterIndex = nextIndex;
        selectedCharacter = nextCharacters[nextIndex];
        _loadCharacterData(selectedCharacter!);
      } else if (selectedCharacter != null) {
        selectedCharacterIndex = nextCharacters.indexOf(selectedCharacter!);
      }
    });
  }

  void _addHinderEvent() {
    if (_hinderEventController.text.isNotEmpty &&
        _solveController.text.isNotEmpty) {
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.title.isNotEmpty) ...[
            SizedBox(
              width: 60,
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.leftLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      widget.rightLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    showValueIndicator: ShowValueIndicator.always,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16,
                    ),
                  ),
                  child: Slider(
                    value: _currentValue,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: _currentValue.toStringAsFixed(0),
                    onChanged: (value) {
                      setState(() {
                        _currentValue = value;
                      });
                      widget.onChanged(value);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CharacterTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hintText;
  final int maxLines;

  const CharacterTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
