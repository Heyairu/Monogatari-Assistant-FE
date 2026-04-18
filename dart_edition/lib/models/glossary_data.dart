import "dart:collection";

import "package:flutter/material.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "glossary_data.freezed.dart";

enum GlossaryPolarity { positive, negative, neutral }

GlossaryPolarity parseGlossaryPolarity(String? raw) {
  switch ((raw ?? "").toLowerCase()) {
    case "positive":
      return GlossaryPolarity.positive;
    case "negative":
      return GlossaryPolarity.negative;
    case "neutral":
    default:
      return GlossaryPolarity.neutral;
  }
}

extension GlossaryPolarityX on GlossaryPolarity {
  String get rawValue {
    switch (this) {
      case GlossaryPolarity.positive:
        return "positive";
      case GlossaryPolarity.negative:
        return "negative";
      case GlossaryPolarity.neutral:
        return "neutral";
    }
  }

  String get label {
    switch (this) {
      case GlossaryPolarity.positive:
        return "正面";
      case GlossaryPolarity.negative:
        return "負面";
      case GlossaryPolarity.neutral:
        return "中性";
    }
  }

  IconData get icon {
    switch (this) {
      case GlossaryPolarity.positive:
        return Icons.sentiment_satisfied_alt;
      case GlossaryPolarity.negative:
        return Icons.sentiment_dissatisfied;
      case GlossaryPolarity.neutral:
        return Icons.sentiment_neutral;
    }
  }

  Color color(ColorScheme scheme) {
    switch (this) {
      case GlossaryPolarity.positive:
        return scheme.primary;
      case GlossaryPolarity.negative:
        return scheme.error;
      case GlossaryPolarity.neutral:
        return scheme.tertiary;
    }
  }
}

enum GlossaryPartOfSpeech {
  noun,
  verb,
  adjective,
  adverb,
  pronoun,
  custom,
  unspecified,
}

GlossaryPartOfSpeech parseGlossaryPartOfSpeech(String? raw) {
  switch ((raw ?? "").toLowerCase()) {
    case "noun":
      return GlossaryPartOfSpeech.noun;
    case "verb":
      return GlossaryPartOfSpeech.verb;
    case "adjective":
      return GlossaryPartOfSpeech.adjective;
    case "adverb":
      return GlossaryPartOfSpeech.adverb;
    case "pronoun":
      return GlossaryPartOfSpeech.pronoun;
    case "custom":
      return GlossaryPartOfSpeech.custom;
    case "unspecified":
    default:
      return GlossaryPartOfSpeech.unspecified;
  }
}

extension GlossaryPartOfSpeechX on GlossaryPartOfSpeech {
  String get rawValue {
    switch (this) {
      case GlossaryPartOfSpeech.noun:
        return "noun";
      case GlossaryPartOfSpeech.verb:
        return "verb";
      case GlossaryPartOfSpeech.adjective:
        return "adjective";
      case GlossaryPartOfSpeech.adverb:
        return "adverb";
      case GlossaryPartOfSpeech.pronoun:
        return "pronoun";
      case GlossaryPartOfSpeech.custom:
        return "custom";
      case GlossaryPartOfSpeech.unspecified:
        return "unspecified";
    }
  }

  String get label {
    switch (this) {
      case GlossaryPartOfSpeech.noun:
        return "名詞";
      case GlossaryPartOfSpeech.verb:
        return "動詞";
      case GlossaryPartOfSpeech.adjective:
        return "形容詞";
      case GlossaryPartOfSpeech.adverb:
        return "副詞";
      case GlossaryPartOfSpeech.pronoun:
        return "代詞";
      case GlossaryPartOfSpeech.custom:
        return "自訂";
      case GlossaryPartOfSpeech.unspecified:
        return "未指定";
    }
  }
}

@unfreezed
class GlossaryPair with _$GlossaryPair {
  factory GlossaryPair({
    @Default("") String meaning,
    @Default("") String example,
  }) = _GlossaryPair;

  GlossaryPair._();

  factory GlossaryPair.fromJson(Map<String, dynamic> json) {
    return GlossaryPair(
      meaning: json["meaning"] as String? ?? "",
      example: json["example"] as String? ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {"meaning": meaning, "example": example};
  }

  GlossaryPair deepCopy() {
    return copyWith();
  }
}

@unfreezed
class GlossaryEntry with _$GlossaryEntry {
  factory GlossaryEntry({
    required String id,
    required String term,
    required GlossaryPartOfSpeech partOfSpeech,
    required String customPartOfSpeech,
    required GlossaryPolarity polarity,
    required List<GlossaryPair> pairs,
  }) = _GlossaryEntry;

  GlossaryEntry._();

  factory GlossaryEntry.fromJson(Map<String, dynamic> json) {
    final List<GlossaryPair> parsedPairs = [];
    final dynamic pairsRaw = json["pairs"];

    if (pairsRaw is List<dynamic>) {
      for (final dynamic item in pairsRaw) {
        if (item is Map<String, dynamic>) {
          parsedPairs.add(GlossaryPair.fromJson(item));
        }
      }
    }

    if (parsedPairs.isEmpty) {
      final List<String> meanings =
          (json["meanings"] as List<dynamic>? ?? <dynamic>[])
              .map((e) => e.toString())
              .toList(growable: false);
      final List<String> examples =
          (json["examples"] as List<dynamic>? ?? <dynamic>[])
              .map((e) => e.toString())
              .toList(growable: false);
      final int pairCount = meanings.length > examples.length
          ? meanings.length
          : examples.length;
      for (int i = 0; i < pairCount; i++) {
        final String meaning = i < meanings.length ? meanings[i] : "";
        final String example = i < examples.length ? examples[i] : "";
        if (meaning.trim().isNotEmpty || example.trim().isNotEmpty) {
          parsedPairs.add(GlossaryPair(meaning: meaning, example: example));
        }
      }
    }

    if (parsedPairs.isEmpty) {
      parsedPairs.add(GlossaryPair());
    }

    return GlossaryEntry(
      id: json["id"] as String? ?? "",
      term: json["term"] as String? ?? "",
      partOfSpeech: parseGlossaryPartOfSpeech(json["partOfSpeech"] as String?),
      customPartOfSpeech: json["customPartOfSpeech"] as String? ?? "",
      polarity: parseGlossaryPolarity(json["polarity"] as String?),
      pairs: parsedPairs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "term": term,
      "partOfSpeech": partOfSpeech.rawValue,
      "customPartOfSpeech": customPartOfSpeech,
      "polarity": polarity.rawValue,
      "pairs": pairs.map((pair) => pair.toJson()).toList(growable: false),
    };
  }

  GlossaryEntry deepCopy() {
    return copyWith(
      pairs: pairs.map((pair) => pair.deepCopy()).toList(growable: false),
    );
  }
}

@unfreezed
class GlossaryCategory with _$GlossaryCategory {
  factory GlossaryCategory({
    required String id,
    required String name,
    required List<String> entryIds,
    required List<GlossaryCategory> children,
  }) = _GlossaryCategory;

  GlossaryCategory._();

  factory GlossaryCategory.fromJson(Map<String, dynamic> json) {
    return GlossaryCategory(
      id: json["id"] as String? ?? "",
      name: json["name"] as String? ?? "",
      entryIds: (json["entryIds"] as List<dynamic>? ?? <dynamic>[])
          .map((e) => e.toString())
          .toList(),
      children: (json["children"] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(GlossaryCategory.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "entryIds": entryIds,
      "children": children
          .map((category) => category.toJson())
          .toList(growable: false),
    };
  }

  GlossaryCategory deepCopy() {
    return copyWith(
      entryIds: List<String>.from(entryIds),
      children: children.map((category) => category.deepCopy()).toList(),
    );
  }
}

List<GlossaryCategory> copyGlossaryCategoryTree(List<GlossaryCategory> nodes) {
  return nodes.map((node) => node.deepCopy()).toList();
}

HashMap<String, GlossaryEntry> copyGlossaryEntryIndex(
  Map<String, GlossaryEntry> source,
) {
  final copied = HashMap<String, GlossaryEntry>();
  for (final entry in source.entries) {
    copied[entry.key] = entry.value.deepCopy();
  }
  return copied;
}
