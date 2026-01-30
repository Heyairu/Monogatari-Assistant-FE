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
import "package:xml/xml.dart" as xml;

// MARK: - CharacterCodec for XML Save/Load

class CharacterCodec {
  /// 將角色資料序列化成 XML 格式
  static String? saveXML(Map<String, Map<String, dynamic>> characterData) {
    if (characterData.isEmpty) {
      return null;
    }

    final builder = xml.XmlBuilder();
    builder.element("Type", nest: () {
      builder.element("Name", nest: "Characters");

      for (final entry in characterData.entries) {
        final characterName = entry.key;
        final data = entry.value;

        builder.element("Character", attributes: {"Name": characterName}, nest: () {
          // Basic Info
          builder.element("BasicInfo", nest: () {
            builder.element("name", nest: data["name"] ?? "");
            builder.element("nickname", nest: data["nickname"] ?? "");
            builder.element("age", nest: data["age"] ?? "");
            builder.element("gender", nest: data["gender"] ?? "");
            builder.element("occupation", nest: data["occupation"] ?? "");
            builder.element("birthday", nest: data["birthday"] ?? "");
            builder.element("native", nest: data["native"] ?? "");
            builder.element("live", nest: data["live"] ?? "");
            builder.element("address", nest: data["address"] ?? "");
          });

          // Appearance
          builder.element("Appearance", nest: () {
            builder.element("height", nest: data["height"] ?? "");
            builder.element("weight", nest: data["weight"] ?? "");
            builder.element("blood", nest: data["blood"] ?? "");
            builder.element("hair", nest: data["hair"] ?? "");
            builder.element("eye", nest: data["eye"] ?? "");
            builder.element("skin", nest: data["skin"] ?? "");
            builder.element("faceFeatures", nest: data["faceFeatures"] ?? "");
            builder.element("eyeFeatures", nest: data["eyeFeatures"] ?? "");
            builder.element("earFeatures", nest: data["earFeatures"] ?? "");
            builder.element("noseFeatures", nest: data["noseFeatures"] ?? "");
            builder.element("mouthFeatures", nest: data["mouthFeatures"] ?? "");
            builder.element("eyebrowFeatures", nest: data["eyebrowFeatures"] ?? "");
            builder.element("body", nest: data["body"] ?? "");
            builder.element("dress", nest: data["dress"] ?? "");
          });

          // Personality
          builder.element("Personality", nest: () {
            builder.element("mbti", nest: data["mbti"] ?? "");
            builder.element("personality", nest: data["personality"] ?? "");
            builder.element("language", nest: data["language"] ?? "");
            builder.element("interest", nest: data["interest"] ?? "");
            builder.element("habit", nest: data["habit"] ?? "");
            builder.element("alignment", nest: data["alignment"] ?? "");
            builder.element("belief", nest: data["belief"] ?? "");
            builder.element("limit", nest: data["limit"] ?? "");
            builder.element("future", nest: data["future"] ?? "");
            builder.element("cherish", nest: data["cherish"] ?? "");
            builder.element("disgust", nest: data["disgust"] ?? "");
            builder.element("fear", nest: data["fear"] ?? "");
            builder.element("curious", nest: data["curious"] ?? "");
            builder.element("expect", nest: data["expect"] ?? "");
            builder.element("intention", nest: data["intention"] ?? "");
            builder.element("otherValues", nest: data["otherValues"] ?? "");

            final hinderEvents = data["hinderEvents"] as List<Map<String, String>>? ?? [];
            if (hinderEvents.isNotEmpty) {
              builder.element("hinderEvents", nest: () {
                for (final event in hinderEvents) {
                  builder.element("event", nest: () {
                    builder.element("name", nest: event["event"] ?? "");
                    builder.element("solve", nest: event["solve"] ?? "");
                  });
                }
              });
            }
          });

          // Ability
          builder.element("Ability", nest: () {
            _saveList(builder, "loveToDoList", data["loveToDoList"]);
            _saveList(builder, "hateToDoList", data["hateToDoList"]);
            _saveList(builder, "proficientToDoList", data["proficientToDoList"]);
            _saveList(builder, "unProficientToDoList", data["unProficientToDoList"]);

            final commonAbilityValues = data["commonAbilityValues"] as List<double>? ?? [];
            final commonAbilityLabels = [
              "cooking", "cleaning", "finance", "fitness",
              "art", "music", "dance", "handicraft",
              "social", "leadership", "analysis", "creativity",
              "memory", "observation", "adaptability", "learning",
            ];
            if (commonAbilityValues.isNotEmpty) {
              builder.element("commonAbilitySliders", nest: () {
                for (int i = 0; i < commonAbilityValues.length && i < commonAbilityLabels.length; i++) {
                  _saveSlider(builder, commonAbilityLabels[i], "poor", "good", commonAbilityValues[i]);
                }
              });
            }
          });

          // Social
          builder.element("Social", nest: () {
            builder.element("impression", nest: data["impression"] ?? "");
            builder.element("likable", nest: data["likable"] ?? "");
            builder.element("family", nest: data["family"] ?? "");

            _saveCheckboxGroup(builder, "howToShowLove", data["howToShowLove"]);
            builder.element("otherShowLove", nest: data["otherShowLove"] ?? "");

            _saveCheckboxGroup(builder, "howToShowGoodwill", data["howToShowGoodwill"]);
            builder.element("otherGoodwill", nest: data["otherGoodwill"] ?? "");

            _saveCheckboxGroup(builder, "handleHatePeople", data["handleHatePeople"]);
            builder.element("otherHatePeople", nest: data["otherHatePeople"] ?? "");

            // Social Item Sliders
            final socialItemValues = data["socialItemValues"] as List<double>? ?? [];
            final socialItemLabels = [
              ["introverted", "extroverted"],
              ["emotional", "rational"],
              ["passive", "active"],
              ["conservative", "open"],
              ["cautious", "adventurous"],
              ["dependent", "independent"],
              ["compliant", "stubborn"],
              ["pessimistic", "optimistic"],
              ["serious", "humorous"],
              ["shy", "outgoing"],
            ];
            if (socialItemValues.isNotEmpty) {
              builder.element("socialItemSliders", nest: () {
                for (int i = 0; i < socialItemValues.length && i < socialItemLabels.length; i++) {
                  _saveSlider(builder, "", socialItemLabels[i][0], socialItemLabels[i][1], socialItemValues[i]);
                }
              });
            }

            builder.element("relationship", nest: data["relationship"] ?? "");
            builder.element("isFindNewLove", nest: (data["isFindNewLove"] ?? false).toString());
            builder.element("isHarem", nest: (data["isHarem"] ?? false).toString());
            builder.element("otherRelationship", nest: data["otherRelationship"] ?? "");

            // Approach Style Sliders
            final approachValues = data["approachValues"] as List<double>? ?? [];
            final approachLabels = [
              ["low-key", "high-profile"],
              ["passive", "proactive"],
              ["cunning", "honest"],
              ["immature", "mature"],
              ["calm", "impulsive"],
              ["taciturn", "talkative"],
              ["obstinate", "obedient"],
              ["unrestrained", "disciplined"],
              ["serious", "frivolous"],
              ["reserved", "frank"],
              ["indifferent", "curious"],
              ["dull", "perceptive"],
            ];
            if (approachValues.isNotEmpty) {
              builder.element("approachSliders", nest: () {
                for (int i = 0; i < approachValues.length && i < approachLabels.length; i++) {
                  _saveSlider(builder, "", approachLabels[i][0], approachLabels[i][1], approachValues[i]);
                }
              });
            }

            // Traits Sliders
            final traitsValues = data["traitsValues"] as List<double>? ?? [];
            final traitsLabels = [
              {"label": "attitude", "left": "pessimistic", "right": "optimistic"},
              {"label": "expression", "left": "expressionless", "right": "vivid"},
              {"label": "aptitude", "left": "dull", "right": "genius"},
              {"label": "mindset", "left": "simple", "right": "complex"},
              {"label": "shamelessness", "left": "thin-skinned", "right": "thick-skinned"},
              {"label": "temper", "left": "gentle", "right": "hot-tempered"},
              {"label": "manners", "left": "rude", "right": "refined"},
              {"label": "willpower", "left": "fragile", "right": "strong"},
              {"label": "desire", "left": "ascetic", "right": "intense"},
              {"label": "courage", "left": "cowardly", "right": "brave"},
              {"label": "eloquence", "left": "inarticulate", "right": "witty"},
              {"label": "vigilance", "left": "gullible", "right": "suspicious"},
              {"label": "self-esteem", "left": "low", "right": "high"},
              {"label": "confidence", "left": "low", "right": "high"},
              {"label": "archetype", "left": "antagonist", "right": "protagonist"},
            ];
            if (traitsValues.isNotEmpty) {
              builder.element("traitsSliders", nest: () {
                for (int i = 0; i < traitsValues.length && i < traitsLabels.length; i++) {
                  _saveSlider(builder, traitsLabels[i]["label"]!, traitsLabels[i]["left"]!, traitsLabels[i]["right"]!, traitsValues[i]);
                }
              });
            }
          });

          // Other
          builder.element("Other", nest: () {
            builder.element("originalName", nest: data["originalName"] ?? "");
            _saveList(builder, "likeItemList", data["likeItemList"]);
            _saveList(builder, "hateItemList", data["hateItemList"]);
            _saveList(builder, "familiarItemList", data["familiarItemList"]);
            builder.element("otherText", nest: data["otherText"] ?? "");
          });
        });
      }
    });

    return builder.buildDocument().toXmlString(pretty: true, indent: "  ");
  }

  static void _saveList(xml.XmlBuilder builder, String tagName, dynamic listData) {
    final list = listData as List<String>? ?? [];
    if (list.isNotEmpty) {
      builder.element(tagName, nest: () {
        for (final item in list) {
          builder.element("item", nest: item);
        }
      });
    }
  }

  static void _saveCheckboxGroup(xml.XmlBuilder builder, String tagName, dynamic mapData) {
    final map = mapData as Map<String, bool>? ?? {};
    if (map.isNotEmpty) {
      builder.element(tagName, nest: () {
        for (final entry in map.entries) {
          builder.element("item", attributes: {"key": entry.key}, nest: entry.value.toString());
        }
      });
    }
  }

  static void _saveSlider(xml.XmlBuilder builder, String title, String leftTag, String rightTag, double value) {
    builder.element("slider", attributes: {
      "Title": title,
      "leftTag": leftTag,
      "rightTag": rightTag,
    }, nest: value.toStringAsFixed(1));
  }

  /// 從 XML 載入角色資料
  static Map<String, Map<String, dynamic>>? loadXML(String content) {
    try {
      final document = xml.XmlDocument.parse(content);
      
      final typeElement = document.findAllElements("Type").firstOrNull;
      if (typeElement == null) return null;

      final nameElement = typeElement.findAllElements("Name").firstOrNull;
      if (nameElement?.innerText != "Characters") return null;

      final characterData = <String, Map<String, dynamic>>{};

      for (final charNode in typeElement.findAllElements("Character")) {
        final characterName = charNode.getAttribute("Name") ?? "";
        
        final data = <String, dynamic>{};
        
        // Basic Info
        final basicInfo = charNode.findAllElements("BasicInfo").firstOrNull;
        if (basicInfo != null) {
          data["name"] = _getText(basicInfo, "name");
          data["nickname"] = _getText(basicInfo, "nickname");
          data["age"] = _getText(basicInfo, "age");
          data["gender"] = _getText(basicInfo, "gender");
          data["occupation"] = _getText(basicInfo, "occupation");
          data["birthday"] = _getText(basicInfo, "birthday");
          data["native"] = _getText(basicInfo, "native");
          data["live"] = _getText(basicInfo, "live");
          data["address"] = _getText(basicInfo, "address");
        }

        // Appearance
        final appearance = charNode.findAllElements("Appearance").firstOrNull;
        if (appearance != null) {
          data["height"] = _getText(appearance, "height");
          data["weight"] = _getText(appearance, "weight");
          data["blood"] = _getText(appearance, "blood");
          data["hair"] = _getText(appearance, "hair");
          data["eye"] = _getText(appearance, "eye");
          data["skin"] = _getText(appearance, "skin");
          data["faceFeatures"] = _getText(appearance, "faceFeatures");
          data["eyeFeatures"] = _getText(appearance, "eyeFeatures");
          data["earFeatures"] = _getText(appearance, "earFeatures");
          data["noseFeatures"] = _getText(appearance, "noseFeatures");
          data["mouthFeatures"] = _getText(appearance, "mouthFeatures");
          data["eyebrowFeatures"] = _getText(appearance, "eyebrowFeatures");
          data["body"] = _getText(appearance, "body");
          data["dress"] = _getText(appearance, "dress");
        }

        // Personality
        final personality = charNode.findAllElements("Personality").firstOrNull;
        if (personality != null) {
          data["mbti"] = _getText(personality, "mbti");
          data["personality"] = _getText(personality, "personality");
          data["language"] = _getText(personality, "language");
          data["interest"] = _getText(personality, "interest");
          data["habit"] = _getText(personality, "habit");
          data["alignment"] = _getText(personality, "alignment");
          data["belief"] = _getText(personality, "belief");
          data["limit"] = _getText(personality, "limit");
          data["future"] = _getText(personality, "future");
          data["cherish"] = _getText(personality, "cherish");
          data["disgust"] = _getText(personality, "disgust");
          data["fear"] = _getText(personality, "fear");
          data["curious"] = _getText(personality, "curious");
          data["expect"] = _getText(personality, "expect");
          data["intention"] = _getText(personality, "intention");
          data["otherValues"] = _getText(personality, "otherValues");
          data["hinderEvents"] = _parseHinderEvents(personality);
        }

        // Ability
        final ability = charNode.findAllElements("Ability").firstOrNull;
        if (ability != null) {
          data["loveToDoList"] = _parseList(ability, "loveToDoList");
          data["hateToDoList"] = _parseList(ability, "hateToDoList");
          data["proficientToDoList"] = _parseList(ability, "proficientToDoList");
          data["unProficientToDoList"] = _parseList(ability, "unProficientToDoList");
          data["commonAbilityValues"] = _parseSliders(ability, "commonAbilitySliders");
        }

        // Social
        final social = charNode.findAllElements("Social").firstOrNull;
        if (social != null) {
          data["impression"] = _getText(social, "impression");
          data["likable"] = _getText(social, "likable");
          data["family"] = _getText(social, "family");
          data["howToShowLove"] = _parseCheckboxGroup(social, "howToShowLove");
          data["otherShowLove"] = _getText(social, "otherShowLove");
          data["howToShowGoodwill"] = _parseCheckboxGroup(social, "howToShowGoodwill");
          data["otherGoodwill"] = _getText(social, "otherGoodwill");
          data["handleHatePeople"] = _parseCheckboxGroup(social, "handleHatePeople");
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
          data["hateItemList"] = _parseList(other, "hateItemList");
          data["familiarItemList"] = _parseList(other, "familiarItemList");
          data["otherText"] = _getText(other, "otherText");
        }

        characterData[characterName] = data;
      }
      
      return characterData.isNotEmpty ? characterData : null;
    } catch (e) {
      print("Error parsing Character XML: $e");
      return null;
    }
  }

  static String _getText(xml.XmlElement node, String tagName) {
    return node.findAllElements(tagName).firstOrNull?.innerText ?? "";
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

  static Map<String, bool> _parseCheckboxGroup(xml.XmlElement node, String tagName) {
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

class CharacterView extends StatefulWidget {
  final Map<String, Map<String, dynamic>>? initialData;
  final ValueChanged<Map<String, Map<String, dynamic>>>? onDataChanged;

  const CharacterView({
    super.key,
    this.initialData,
    this.onDataChanged,
  });

  @override
  State<CharacterView> createState() => _CharacterViewState();
}

// MARK: - 角色資料控制項

class _CharacterViewState extends State<CharacterView> with SingleTickerProviderStateMixin {
  // Tab Controller
  late TabController _tabController;
  
  // Character List
  List<String> characters = [];
  String? selectedCharacter;
  int? selectedCharacterIndex;
  
  // Character Data Storage - 每個角色的完整資料
  Map<String, Map<String, dynamic>> characterData = {};
  
  // New character input controller
  final TextEditingController _newCharacterController = TextEditingController();

  // Basic Info - 基本資料
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _occupationController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();
  final TextEditingController _nativeController = TextEditingController();
  final TextEditingController _liveController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Appearance - 外觀
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _bloodController = TextEditingController();
  final TextEditingController _hairController = TextEditingController();
  final TextEditingController _eyeController = TextEditingController();
  final TextEditingController _skinController = TextEditingController();
  final TextEditingController _faceFeaturesController = TextEditingController();
  final TextEditingController _eyeFeaturesController = TextEditingController();
  final TextEditingController _earFeaturesController = TextEditingController();
  final TextEditingController _noseFeaturesController = TextEditingController();
  final TextEditingController _mouthFeaturesController = TextEditingController();
  final TextEditingController _eyebrowFeaturesController = TextEditingController();

  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _dressController = TextEditingController();

  // Personality - 個性
  final TextEditingController _personalityController = TextEditingController();
  final TextEditingController _languageController = TextEditingController();
  final TextEditingController _interestController = TextEditingController();
  final TextEditingController _habitController = TextEditingController();
  final TextEditingController _beliefController = TextEditingController();
  final TextEditingController _limitController = TextEditingController();
  final TextEditingController _futureController = TextEditingController();
  final TextEditingController _cherishController = TextEditingController();
  final TextEditingController _disgustController = TextEditingController();
  final TextEditingController _fearController = TextEditingController();
  final TextEditingController _curiousController = TextEditingController();
  final TextEditingController _expectController = TextEditingController();
  final TextEditingController _intentionController = TextEditingController();
  final TextEditingController _otherValuesController = TextEditingController();

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
  List<String> proficientToDoList = [];
  List<String> unProficientToDoList = [];
  final TextEditingController _loveToDoController = TextEditingController();
  final TextEditingController _hateToDoController = TextEditingController();
  final TextEditingController _proficientToDoController = TextEditingController();
  final TextEditingController _unProficientToDoController = TextEditingController();

  // Common Ability Sliders (16 items) - 生活常用技能
  List<double> commonAbilityValues = List.filled(16, 50.0);
  final List<String> commonAbilityLabels = [
    "料理", "清潔", "理財", "體能", 
    "藝術", "音樂", "舞蹈", "手工",
    "社交", "領導", "分析", "創意", 
    "記憶", "觀察", "應變", "學習",
  ];
  
  // English keys for saving (matching the display labels above)
  final List<String> commonAbilityKeys = [
    "cooking", "cleaning", "finance", "fitness",
    "art", "music", "dance", "handicraft",
    "social", "leadership", "analysis", "creativity",
    "memory", "observation", "adaptability", "learning",
  ];

  // Social - 社交
  final TextEditingController _impressionController = TextEditingController();
  final TextEditingController _likableController = TextEditingController();
  final TextEditingController _familyController = TextEditingController();
  
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
  final TextEditingController _otherShowLoveController = TextEditingController();
  
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
  final TextEditingController _otherGoodwillController = TextEditingController();
  
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
  final TextEditingController _otherHatePeopleController = TextEditingController();
  
  // Social Item Sliders (10 items) - 社交相關項目
  List<double> socialItemValues = List.filled(10, 50.0);
  final List<List<String>> socialItemLabels = [
    ["內向", "外向"],
    ["感性", "理性"],
    ["被動", "主動"],
    ["保守", "開放"],
    ["謹慎", "冒險"],
    ["依賴", "獨立"],
    ["柔順", "固執"],
    ["悲觀", "樂觀"],
    ["嚴肅", "幽默"],
    ["害羞", "大方"],
  ];

  // MBTI
  final TextEditingController _mbtiController = TextEditingController();

  // Relationship - 戀愛關係
  String? selectedRelationship;
  bool isFindNewLove = false;
  bool isHarem = false;
  final TextEditingController _otherRelationshipController = TextEditingController();

  // Approach Style - 行事作風 (12 items)
  List<double> approachValues = List.filled(12, 50.0);
  final List<List<String>> approachLabels = [
    ["低調", "高調"],
    ["消極", "積極"],
    ["狡猾", "老實"],
    ["幼稚", "成熟"],
    ["冷靜", "衝動"],
    ["寡言", "多話"],
    ["執拗", "順從"],
    ["奔放", "自律"],
    ["嚴肅", "輕浮"],
    ["彆扭", "坦率"],
    ["淡漠", "好奇"],
    ["遲鈍", "敏銳"],
  ];

  // Traits - 性格特質 (15 items)
  List<double> traitsValues = List.filled(15, 50.0);
  final List<Map<String, String>> traitsLabels = [
    {"label": "態度", "left": "悲觀", "right": "樂觀"},
    {"label": "表情", "left": "面癱", "right": "生動"},
    {"label": "資質", "left": "笨蛋", "right": "天才"},
    {"label": "思想", "left": "單純", "right": "複雜"},
    {"label": "臉皮", "left": "極薄", "right": "極厚"},
    {"label": "脾氣", "left": "溫和", "right": "火爆"},
    {"label": "舉止", "left": "粗魯", "right": "斯文"},
    {"label": "意志", "left": "易碎", "right": "堅強"},
    {"label": "慾望", "left": "無慾", "right": "強烈"},
    {"label": "膽量", "left": "膽小", "right": "勇敢"},
    {"label": "談吐", "left": "木訥", "right": "風趣"},
    {"label": "戒心", "left": "輕信", "right": "多疑"},
    {"label": "自尊", "left": "低下", "right": "高亢"},
    {"label": "自信", "left": "低下", "right": "高亢"},
    {"label": "陰陽", "left": "陰角", "right": "陽角"},
  ];

  // Other - 其他
  final TextEditingController _originalNameController = TextEditingController();
  List<String> likeItemList = [];
  List<String> hateItemList = [];
  List<String> familiarItemList = [];
  final TextEditingController _likeItemController = TextEditingController();
  final TextEditingController _hateItemController = TextEditingController();
  final TextEditingController _familiarItemController = TextEditingController();
  final TextEditingController _otherTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    
    // 載入初始資料
    if (widget.initialData != null && widget.initialData!.isNotEmpty) {
      characterData = Map<String, Map<String, dynamic>>.from(widget.initialData!);
      characters = characterData.keys.toList();
      
      // 如果有角色,選取第一個
      if (characters.isNotEmpty) {
        selectedCharacterIndex = 0;
        selectedCharacter = characters[0];
        _loadCharacterData(selectedCharacter!);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _newCharacterController.dispose();
    _nameController.dispose();
    _nicknameController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _occupationController.dispose();
    _birthdayController.dispose();
    _nativeController.dispose();
    _liveController.dispose();
    _addressController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _bloodController.dispose();
    _hairController.dispose();
    _eyeController.dispose();
    _skinController.dispose();
    _faceFeaturesController.dispose();
    _eyeFeaturesController.dispose();
    _earFeaturesController.dispose();
    _noseFeaturesController.dispose();
    _mouthFeaturesController.dispose();
    _eyebrowFeaturesController.dispose();
    _bodyController.dispose();
    _dressController.dispose();
    _personalityController.dispose();
    _languageController.dispose();
    _interestController.dispose();
    _habitController.dispose();
    _beliefController.dispose();
    _limitController.dispose();
    _futureController.dispose();
    _cherishController.dispose();
    _disgustController.dispose();
    _fearController.dispose();
    _curiousController.dispose();
    _expectController.dispose();
    _intentionController.dispose();
    _otherValuesController.dispose();
    _hinderEventController.dispose();
    _solveController.dispose();
    _loveToDoController.dispose();
    _hateToDoController.dispose();
    _proficientToDoController.dispose();
    _unProficientToDoController.dispose();
    _impressionController.dispose();
    _likableController.dispose();
    _familyController.dispose();
    _otherShowLoveController.dispose();
    _otherGoodwillController.dispose();
    _otherHatePeopleController.dispose();
    _mbtiController.dispose();
    _otherRelationshipController.dispose();
    _originalNameController.dispose();
    _likeItemController.dispose();
    _hateItemController.dispose();
    _familiarItemController.dispose();
    _otherTextController.dispose();
    super.dispose();
  }

  // MARK: - UI 介面

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  Row(
                    children: [
                      Icon(
                        Icons.person_rounded,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "角色編輯",
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildCharacterListSection(),
                  const SizedBox(height: 16),
                  _buildCharacterEditSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterListSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("角色列表", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            // 新增角色輸入框
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCharacterController,
                    decoration: const InputDecoration(
                      labelText: "新角色名稱",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => _addCharacter(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addCharacter,
                  tooltip: "新增",
                ),
              ],
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
                  return ListTile(
                    title: Text(characters[index]),
                    selected: selectedCharacterIndex == index,
                    selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () => _deleteCharacter(index),
                      tooltip: "刪除",
                    ),
                    onTap: () => _selectCharacter(index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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
                Icon(Icons.person_outline, size: 80, color: Colors.grey.shade400),
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
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: IndexedStack(
                index: _tabController.index,
                sizing: StackFit.loose,
                children: [
                  _buildBasicInfoTab(),
                  _buildPersonalityTab(),
                  _buildAbilityTab(),
                  _buildSocialTab(),
                  _buildOtherTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildNameField("姓名：", _nameController),
        _buildTextField("暱稱：", _nicknameController),
        _buildTextField("年齡：", _ageController),
        _buildTextField("性別：", _genderController),
        _buildTextField("職業：", _occupationController),
        _buildTextField("生日：", _birthdayController),
        _buildTextField("出生地：", _nativeController),
        _buildTextField("居住地：", _liveController),
        _buildTextField("住址：", _addressController),
        const Divider(height: 32),
        Text("外觀", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _buildTextField("身高：", _heightController),
        _buildTextField("體重：", _weightController),
        _buildTextField("血型：", _bloodController),
        _buildTextField("髮色：", _hairController),
        _buildTextField("瞳色：", _eyeController),
        _buildTextField("膚色：", _skinController),
        _buildTextField("臉型：", _faceFeaturesController),
        _buildTextField("眼型：", _eyeFeaturesController),
        _buildTextField("耳型：", _earFeaturesController),
        _buildTextField("鼻型：", _noseFeaturesController),
        _buildTextField("嘴型：", _mouthFeaturesController),
        _buildTextField("眉型：", _eyebrowFeaturesController),
        _buildTextField("體格：", _bodyController),
        _buildTextField("服裝：", _dressController),
        
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("故事相關", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                TextField(
                  controller: _intentionController,
                  decoration: const InputDecoration(
                    labelText: "故事中的動機、目標？",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text("阻礙主角的事件？", style: Theme.of(context).textTheme.bodyMedium),
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
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      onPressed: selectedHinderIndex != null ? _deleteHinderEvent : null,
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
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalityTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField("MBTI：", _mbtiController),
        _buildMultilineField("個性：", _personalityController),
        _buildTextField("口頭禪、慣用語：", _languageController),
        _buildTextField("興趣：", _interestController),
        _buildTextField("習慣、癖好：", _habitController),
        _buildTextField("信仰：", _beliefController),
        _buildTextField("底線", _limitController),
        _buildTextField("將來想變得如何？", _futureController),
        _buildTextField("最珍視的事物？", _cherishController),
        _buildTextField("最厭惡的事物？", _disgustController),
        _buildTextField("最害怕的事物？", _fearController),
        _buildTextField("最好奇的事物？", _curiousController),
        _buildTextField("最期待的事物？", _expectController),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("陣營", style: Theme.of(context).textTheme.titleMedium),
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
                Text("性格特質", style: Theme.of(context).textTheme.titleMedium),
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
                Text("行事作風", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                _buildApproachSliders(),
              ],
            ),
          ),
        ),
        const Divider(height: 32),
        _buildMultilineField("其他補充：", _otherValuesController),
      ],
    );
  }

  Widget _buildAbilityTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildListSection("熱愛做的事情", loveToDoList, _loveToDoController, _addLoveToDo, _deleteLoveToDo),
        const SizedBox(height: 16),
        _buildListSection("討厭做的事情", hateToDoList, _hateToDoController, _addHateToDo, _deleteHateToDo),
        const SizedBox(height: 16),
        _buildListSection("擅長做的事情", proficientToDoList, _proficientToDoController, _addProficientToDo, _deleteProficientToDo),
        const SizedBox(height: 16),
        _buildListSection("不擅長做的事情", unProficientToDoList, _unProficientToDoController, _addUnProficientToDo, _deleteUnProficientToDo),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("生活常用技能", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                _buildCommonAbilitySliders(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMultilineField("來自他人的印象", _impressionController),
        const SizedBox(height: 8),
        _buildTextField("最受他人欣賞/喜愛的特點", _likableController),
        const SizedBox(height: 8),
        _buildMultilineField("簡述原生家庭", _familyController),
        const Divider(height: 32),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("如何表達「喜歡」", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _buildCheckboxGroup(howToShowLove, howToShowLoveLabels),
                const SizedBox(height: 8),
                TextField(
                  controller: _otherShowLoveController,
                  decoration: const InputDecoration(
                    labelText: "其他",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                Text("如何表達好意", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _buildCheckboxGroup(howToShowGoodwill, howToShowGoodwillLabels),
                const SizedBox(height: 8),
                TextField(
                  controller: _otherGoodwillController,
                  decoration: const InputDecoration(
                    labelText: "其他",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                Text("如何應對討厭的人？", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _buildCheckboxGroup(handleHatePeople, handleHatePeopleLabels),
                const SizedBox(height: 8),
                TextField(
                  controller: _otherHatePeopleController,
                  decoration: const InputDecoration(
                    labelText: "其他",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                Text("戀愛關係", style: Theme.of(context).textTheme.titleMedium),
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
                Text("社交相關項目", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                _buildSocialItemSliders(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtherTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _originalNameController,
          decoration: const InputDecoration(
            labelText: "原文姓名",
            hintText: "例如：桜田如羽",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        _buildListSection("喜歡的人事物", likeItemList, _likeItemController, _addLikeItem, _deleteLikeItem),
        const SizedBox(height: 16),
        _buildListSection("討厭的人事物", hateItemList, _hateItemController, _addHateItem, _deleteHateItem),
        const SizedBox(height: 16),
        _buildListSection("習慣的人事物", familiarItemList, _familiarItemController, _addFamiliarItem, _deleteFamiliarItem),
        const SizedBox(height: 16),
        _buildMultilineField("其他補充", _otherTextController),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => _saveCurrentCharacterData(),
      ),
    );
  }

  // 專門用於處理角色名稱的欄位,會同步更新列表
  Widget _buildNameField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) {
          _syncCharacterName(value);
          _saveCurrentCharacterData();
        },
      ),
    );
  }

  Widget _buildMultilineField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextField(
        controller: controller,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => _saveCurrentCharacterData(),
      ),
    );
  }

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
          title: Text(alignment, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
          value: alignment,
          groupValue: selectedAlignment,
          onChanged: (value) {
            setState(() {
              selectedAlignment = value;
              _saveCurrentCharacterData();
            });
          },
        );
      },
    );
  }

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

  Widget _buildListSection(
    String title, 
    List<String> items, 
    TextEditingController controller,
    VoidCallback onAdd, 
    VoidCallback onDelete,
  ) {
    int? selectedIndex;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Container(
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(items[index]),
                    selected: selectedIndex == index,
                    selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    onTap: () {
                      setState(() {
                        selectedIndex = index;
                        controller.text = items[index];
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: onAdd,
                  tooltip: "新增",
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: onDelete,
                  tooltip: "刪除",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxGroup(Map<String, bool> values, Map<String, String> labels) {
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
          title: Text(labels[entry.key] ?? entry.key, style: const TextStyle(fontSize: 13)),
          value: entry.value,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          onChanged: (bool? value) {
            setState(() {
              values[entry.key] = value ?? false;
              _saveCurrentCharacterData();
            });
          },
        );
      },
    );
  }

  Widget _buildCommonAbilitySliders() {
    return Column(
      children: List.generate(16, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  commonAbilityLabels[index],
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  "不擅長",
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    showValueIndicator: ShowValueIndicator.onDrag,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value: commonAbilityValues[index],
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: commonAbilityValues[index].toStringAsFixed(0),
                    onChanged: (value) {
                      setState(() {
                        commonAbilityValues[index] = value;
                        _saveCurrentCharacterData();
                      });
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  "擅長",
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildRelationshipSection() {
    final relationships = [
      "單身",
      "已婚/準備結婚",
      "戀愛中/準備戀愛",
      "喪偶",
      "其他",
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...relationships.map((rel) => RadioListTile<String>(
          title: Text(rel),
          value: rel,
          groupValue: selectedRelationship,
          dense: true,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) {
            setState(() {
              selectedRelationship = value;
              _saveCurrentCharacterData();
            });
          },
        )),
        const SizedBox(height: 8),
        TextField(
          controller: _otherRelationshipController,
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
              _saveCurrentCharacterData();
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
              _saveCurrentCharacterData();
            });
          },
        ),
      ],
    );
  }

  Widget _buildSocialItemSliders() {
    return Column(
      children: List.generate(10, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              SizedBox(
                width: 70,
                child: Text(
                  socialItemLabels[index][0],
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    showValueIndicator: ShowValueIndicator.onDrag,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value: socialItemValues[index],
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: socialItemValues[index].toStringAsFixed(0),
                    onChanged: (value) {
                      setState(() {
                        socialItemValues[index] = value;
                        _saveCurrentCharacterData();
                      });
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  socialItemLabels[index][1],
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildApproachSliders() {
    return Column(
      children: List.generate(12, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  approachLabels[index][0],
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    showValueIndicator: ShowValueIndicator.onDrag,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value: approachValues[index],
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: approachValues[index].toStringAsFixed(0),
                    onChanged: (value) {
                      setState(() {
                        approachValues[index] = value;
                        _saveCurrentCharacterData();
                      });
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  approachLabels[index][1],
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTraitsSliders() {
    return Column(
      children: List.generate(15, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  traitsLabels[index]["label"]!,
                  textAlign: TextAlign.left,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  traitsLabels[index]["left"]!,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    showValueIndicator: ShowValueIndicator.onDrag,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value: traitsValues[index],
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: traitsValues[index].toStringAsFixed(0),
                    onChanged: (value) {
                      setState(() {
                        traitsValues[index] = value;
                        _saveCurrentCharacterData();
                      });
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 50,
                child: Text(
                  traitsLabels[index]["right"]!,
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // Action methods
  
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
    if (selectedCharacter == null) return;
    
    characterData[selectedCharacter!] = {
      // Basic Info
      "name": _nameController.text,
      "nickname": _nicknameController.text,
      "age": _ageController.text,
      "gender": _genderController.text,
      "occupation": _occupationController.text,
      "birthday": _birthdayController.text,
      "native": _nativeController.text,
      "live": _liveController.text,
      "address": _addressController.text,
      // Appearance
      "height": _heightController.text,
      "weight": _weightController.text,
      "blood": _bloodController.text,
      "hair": _hairController.text,
      "eye": _eyeController.text,
      "skin": _skinController.text,
      "faceFeatures": _faceFeaturesController.text,
      "eyeFeatures": _eyeFeaturesController.text,
      "earFeatures": _earFeaturesController.text,
      "noseFeatures": _noseFeaturesController.text,
      "mouthFeatures": _mouthFeaturesController.text,
      "eyebrowFeatures": _eyebrowFeaturesController.text,
      "body": _bodyController.text,
      "dress": _dressController.text,
      // Personality
      "mbti": _mbtiController.text,
      "personality": _personalityController.text,
      "language": _languageController.text,
      "interest": _interestController.text,
      "habit": _habitController.text,
      "alignment": selectedAlignment,
      "belief": _beliefController.text,
      "limit": _limitController.text,
      "future": _futureController.text,
      "cherish": _cherishController.text,
      "disgust": _disgustController.text,
      "fear": _fearController.text,
      "curious": _curiousController.text,
      "expect": _expectController.text,
      "intention": _intentionController.text,
      "otherValues": _otherValuesController.text,
      "hinderEvents": List<Map<String, String>>.from(hinderEvents),
      // Ability
      "loveToDoList": List<String>.from(loveToDoList),
      "hateToDoList": List<String>.from(hateToDoList),
      "proficientToDoList": List<String>.from(proficientToDoList),
      "unProficientToDoList": List<String>.from(unProficientToDoList),
      "commonAbilityValues": List<double>.from(commonAbilityValues),
      // Social
      "impression": _impressionController.text,
      "likable": _likableController.text,
      "family": _familyController.text,
      "howToShowLove": Map<String, bool>.from(howToShowLove),
      "otherShowLove": _otherShowLoveController.text,
      "howToShowGoodwill": Map<String, bool>.from(howToShowGoodwill),
      "otherGoodwill": _otherGoodwillController.text,
      "handleHatePeople": Map<String, bool>.from(handleHatePeople),
      "otherHatePeople": _otherHatePeopleController.text,
      "socialItemValues": List<double>.from(socialItemValues),
      "relationship": selectedRelationship,
      "isFindNewLove": isFindNewLove,
      "isHarem": isHarem,
      "otherRelationship": _otherRelationshipController.text,
      "approachValues": List<double>.from(approachValues),
      "traitsValues": List<double>.from(traitsValues),
      // Other
      "originalName": _originalNameController.text,
      "likeItemList": List<String>.from(likeItemList),
      "hateItemList": List<String>.from(hateItemList),
      "familiarItemList": List<String>.from(familiarItemList),
      "otherText": _otherTextController.text,
    };
    
    // 通知外部資料已改變
    widget.onDataChanged?.call(characterData);
  }
  
  // 載入角色資料
  void _loadCharacterData(String characterName) {
    final data = characterData[characterName];
    
    if (data == null) {
      // 清空所有欄位
      _clearAllFields();
      // 如果是新角色,將列表中的名稱填入姓名欄位
      _nameController.text = characterName;
      return;
    }

    // Helper to ensure list length to prevent RangeError
    List<double> ensureList(String key, int length) {
      final list = data[key] as List<dynamic>?;
      if (list == null || list.isEmpty) {
        return List.filled(length, 50.0);
      }
      final typedList = List<double>.from(list);
      if (typedList.length < length) {
        typedList.addAll(List.filled(length - typedList.length, 50.0));
      }
      return typedList;
    }
    
    // Basic Info
    _nameController.text = data["name"] ?? characterName;
    _nicknameController.text = data["nickname"] ?? "";
    _ageController.text = data["age"] ?? "";
    _genderController.text = data["gender"] ?? "";
    _occupationController.text = data["occupation"] ?? "";
    _birthdayController.text = data["birthday"] ?? "";
    _nativeController.text = data["native"] ?? "";
    _liveController.text = data["live"] ?? "";
    _addressController.text = data["address"] ?? "";
    // Appearance
    _heightController.text = data["height"] ?? "";
    _weightController.text = data["weight"] ?? "";
    _bloodController.text = data["blood"] ?? "";
    _hairController.text = data["hair"] ?? "";
    _eyeController.text = data["eye"] ?? "";
    _skinController.text = data["skin"] ?? "";
    _faceFeaturesController.text = data["faceFeatures"] ?? "";
    _eyeFeaturesController.text = data["eyeFeatures"] ?? "";
    _earFeaturesController.text = data["earFeatures"] ?? "";
    _noseFeaturesController.text = data["noseFeatures"] ?? "";
    _mouthFeaturesController.text = data["mouthFeatures"] ?? "";
    _eyebrowFeaturesController.text = data["eyebrowFeatures"] ?? "";
    _bodyController.text = data["body"] ?? "";
    _dressController.text = data["dress"] ?? "";
    // Personality
    _personalityController.text = data["personality"] ?? "";
    _languageController.text = data["language"] ?? "";
    _interestController.text = data["interest"] ?? "";
    _habitController.text = data["habit"] ?? "";
    selectedAlignment = data["alignment"];
    _beliefController.text = data["belief"] ?? "";
    _limitController.text = data["limit"] ?? "";
    _futureController.text = data["future"] ?? "";
    _cherishController.text = data["cherish"] ?? "";
    _disgustController.text = data["disgust"] ?? "";
    _fearController.text = data["fear"] ?? "";
    _curiousController.text = data["curious"] ?? "";
    _expectController.text = data["expect"] ?? "";
    _intentionController.text = data["intention"] ?? "";
    _otherValuesController.text = data["otherValues"] ?? "";
    hinderEvents = List<Map<String, String>>.from(data["hinderEvents"] ?? []);
    // Ability
    loveToDoList = List<String>.from(data["loveToDoList"] ?? []);
    hateToDoList = List<String>.from(data["hateToDoList"] ?? []);
    proficientToDoList = List<String>.from(data["proficientToDoList"] ?? []);
    unProficientToDoList = List<String>.from(data["unProficientToDoList"] ?? []);
    commonAbilityValues = ensureList("commonAbilityValues", 16);
    // Social
    _mbtiController.text = data["mbti"] ?? "";
    _impressionController.text = data["impression"] ?? "";
    _likableController.text = data["likable"] ?? "";
    _familyController.text = data["family"] ?? "";
    if (data["howToShowLove"] != null) {
      howToShowLove.updateAll((key, value) => data["howToShowLove"][key] ?? false);
    }
    _otherShowLoveController.text = data["otherShowLove"] ?? "";
    if (data["howToShowGoodwill"] != null) {
      howToShowGoodwill.updateAll((key, value) => data["howToShowGoodwill"][key] ?? false);
    }
    _otherGoodwillController.text = data["otherGoodwill"] ?? "";
    if (data["handleHatePeople"] != null) {
      handleHatePeople.updateAll((key, value) => data["handleHatePeople"][key] ?? false);
    }
    _otherHatePeopleController.text = data["otherHatePeople"] ?? "";
    socialItemValues = ensureList("socialItemValues", 10);
    selectedRelationship = data["relationship"];
    isFindNewLove = data["isFindNewLove"] ?? false;
    isHarem = data["isHarem"] ?? false;
    _otherRelationshipController.text = data["otherRelationship"] ?? "";
    approachValues = ensureList("approachValues", 12);
    traitsValues = ensureList("traitsValues", 15);
    // Other
    _originalNameController.text = data["originalName"] ?? "";
    likeItemList = List<String>.from(data["likeItemList"] ?? []);
    hateItemList = List<String>.from(data["hateItemList"] ?? []);
    familiarItemList = List<String>.from(data["familiarItemList"] ?? []);
    _otherTextController.text = data["otherText"] ?? "";
  }
  
  // 清空所有欄位
  void _clearAllFields() {
    _nameController.clear();
    _nicknameController.clear();
    _ageController.clear();
    _genderController.clear();
    _occupationController.clear();
    _birthdayController.clear();
    _nativeController.clear();
    _liveController.clear();
    _addressController.clear();
    _heightController.clear();
    _weightController.clear();
    _bloodController.clear();
    _hairController.clear();
    _eyeController.clear();
    _skinController.clear();
    _faceFeaturesController.clear();
    _eyeFeaturesController.clear();
    _earFeaturesController.clear();
    _noseFeaturesController.clear();
    _mouthFeaturesController.clear();
    _eyebrowFeaturesController.clear();
    _bodyController.clear();
    _dressController.clear();
    _personalityController.clear();
    _languageController.clear();
    _interestController.clear();
    _habitController.clear();
    selectedAlignment = null;
    _beliefController.clear();
    _limitController.clear();
    _futureController.clear();
    _cherishController.clear();
    _disgustController.clear();
    _fearController.clear();
    _curiousController.clear();
    _expectController.clear();
    _intentionController.clear();
    _otherValuesController.clear();
    hinderEvents.clear();
    loveToDoList.clear();
    hateToDoList.clear();
    proficientToDoList.clear();
    unProficientToDoList.clear();
    commonAbilityValues = List.filled(16, 50.0);
    _mbtiController.clear();
    _impressionController.clear();
    _likableController.clear();
    _familyController.clear();
    howToShowLove.updateAll((key, value) => false);
    _otherShowLoveController.clear();
    howToShowGoodwill.updateAll((key, value) => false);
    _otherGoodwillController.clear();
    handleHatePeople.updateAll((key, value) => false);
    _otherHatePeopleController.clear();
    socialItemValues = List.filled(10, 50.0);
    selectedRelationship = null;
    isFindNewLove = false;
    isHarem = false;
    _otherRelationshipController.clear();
    approachValues = List.filled(12, 50.0);
    traitsValues = List.filled(15, 50.0);
    _originalNameController.clear();
    likeItemList.clear();
    hateItemList.clear();
    familiarItemList.clear();
    _otherTextController.clear();
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
    
    setState(() {
      final oldName = selectedCharacter!;
      
      // 更新列表中的角色名稱
      characters[selectedCharacterIndex!] = trimmedName;
      
      // 如果 characterData 中有舊名稱的資料,需要轉移到新名稱
      if (characterData.containsKey(oldName)) {
        final data = characterData[oldName]!;
        characterData.remove(oldName);
        characterData[trimmedName] = data;
      }
      
      // 更新當前選中的角色名稱
      selectedCharacter = trimmedName;
    });
  }
  
  void _addCharacter() {
    final name = _newCharacterController.text.trim();
    if (name.isEmpty) return;
    
    if (characters.contains(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("角色名稱已存在")),
      );
      return;
    }

    // 確保現有更動被儲存
    if (selectedCharacter != null) {
      _saveCurrentCharacterData();
    }
    
    setState(() {
      characters.add(name);
      
      // 初始化新角色資料並通知更新
      characterData[name] = {"name": name};
      widget.onDataChanged?.call(characterData);

      _newCharacterController.clear();
      // 自動選取新增的角色
      _selectCharacter(characters.length - 1);
    });
  }
  
  void _deleteCharacter(int index) {
    final characterName = characters[index];
    
    // 確保現有更動被儲存
    if (selectedCharacter != null) {
      _saveCurrentCharacterData();
    }

    setState(() {
      characters.removeAt(index);
      characterData.remove(characterName);
      
      // 通知更新
      widget.onDataChanged?.call(characterData);

      // 如果刪除的是當前選中的角色
      if (selectedCharacterIndex == index) {
        selectedCharacterIndex = null;
        selectedCharacter = null;
        _clearAllFields();
      } else if (selectedCharacterIndex != null && selectedCharacterIndex! > index) {
        // 調整索引
        selectedCharacterIndex = selectedCharacterIndex! - 1;
      }
    });
  }

  void _addHinderEvent() {
    if (_hinderEventController.text.isNotEmpty && _solveController.text.isNotEmpty) {
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

  void _addLoveToDo() {
    if (_loveToDoController.text.isNotEmpty) {
      setState(() {
        loveToDoList.add(_loveToDoController.text);
        _loveToDoController.clear();
        _saveCurrentCharacterData();
      });
    }
  }
  
  void _deleteLoveToDo() {
    if (_loveToDoController.text.isNotEmpty && loveToDoList.contains(_loveToDoController.text)) {
      setState(() {
        loveToDoList.remove(_loveToDoController.text);
        _loveToDoController.clear();
        _saveCurrentCharacterData();
      });
    }
  }
  
  void _addHateToDo() {
    if (_hateToDoController.text.isNotEmpty) {
      setState(() {
        hateToDoList.add(_hateToDoController.text);
        _hateToDoController.clear();
        _saveCurrentCharacterData();
      });
    }
  }
  
  void _deleteHateToDo() {
    if (_hateToDoController.text.isNotEmpty && hateToDoList.contains(_hateToDoController.text)) {
      setState(() {
        hateToDoList.remove(_hateToDoController.text);
        _hateToDoController.clear();
        _saveCurrentCharacterData();
      });
    }
  }
  
  void _addProficientToDo() {
    if (_proficientToDoController.text.isNotEmpty) {
      setState(() {
        proficientToDoList.add(_proficientToDoController.text);
        _proficientToDoController.clear();
        _saveCurrentCharacterData();
      });
    }
  }
  
  void _deleteProficientToDo() {
    if (_proficientToDoController.text.isNotEmpty && proficientToDoList.contains(_proficientToDoController.text)) {
      setState(() {
        proficientToDoList.remove(_proficientToDoController.text);
        _proficientToDoController.clear();
        _saveCurrentCharacterData();
      });
    }
  }
  
  void _addUnProficientToDo() {
    if (_unProficientToDoController.text.isNotEmpty) {
      setState(() {
        unProficientToDoList.add(_unProficientToDoController.text);
        _unProficientToDoController.clear();
        _saveCurrentCharacterData();
      });
    }
  }
  
  void _deleteUnProficientToDo() {
    if (_unProficientToDoController.text.isNotEmpty && unProficientToDoList.contains(_unProficientToDoController.text)) {
      setState(() {
        unProficientToDoList.remove(_unProficientToDoController.text);
        _unProficientToDoController.clear();
        _saveCurrentCharacterData();
      });
    }
  }
  
  void _addLikeItem() {
    if (_likeItemController.text.isNotEmpty) {
      setState(() {
        likeItemList.add(_likeItemController.text);
        _likeItemController.clear();
        _saveCurrentCharacterData();
      });
    }
  }
  
  void _deleteLikeItem() {
    if (_likeItemController.text.isNotEmpty && likeItemList.contains(_likeItemController.text)) {
      setState(() {
        likeItemList.remove(_likeItemController.text);
        _likeItemController.clear();
        _saveCurrentCharacterData();
      });
    }
  }
  
  void _addHateItem() {
    if (_hateItemController.text.isNotEmpty) {
      setState(() {
        hateItemList.add(_hateItemController.text);
        _hateItemController.clear();
        _saveCurrentCharacterData();
      });
    }
  }
  
  void _deleteHateItem() {
    if (_hateItemController.text.isNotEmpty && hateItemList.contains(_hateItemController.text)) {
      setState(() {
        hateItemList.remove(_hateItemController.text);
        _hateItemController.clear();
        _saveCurrentCharacterData();
      });
    }
  }
  
  void _addFamiliarItem() {
    if (_familiarItemController.text.isNotEmpty) {
      setState(() {
        familiarItemList.add(_familiarItemController.text);
        _familiarItemController.clear();
        _saveCurrentCharacterData();
      });
    }
  }
  
  void _deleteFamiliarItem() {
    if (_familiarItemController.text.isNotEmpty && familiarItemList.contains(_familiarItemController.text)) {
      setState(() {
        familiarItemList.remove(_familiarItemController.text);
        _familiarItemController.clear();
        _saveCurrentCharacterData();
      });
    }
  }
}
