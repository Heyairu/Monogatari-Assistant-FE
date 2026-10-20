// Copyright 2025-2026 Heyairu（部屋伊琉）
// Licensed under the Apache License, Version 2.0.

import 'dart:convert';
import 'package:flutter/services.dart';
import 'help_topic.dart';

class HelpSection {
  const HelpSection({
    required this.heading,
    required this.paragraphs,
    required this.steps,
  });
  final String heading;
  final List<String> paragraphs;
  final List<String> steps;
}

class HelpTopic {
  const HelpTopic({
    required this.id,
    required this.title,
    required this.category,
    required this.keywords,
    required this.sections,
    required this.relatedIds,
  });
  final String id;
  final String title;
  final String category;
  final List<String> keywords;
  final List<HelpSection> sections;
  final List<String> relatedIds;
  String get searchableText => [
    title,
    ...keywords,
    for (final section in sections) ...[
      section.heading,
      ...section.paragraphs,
      ...section.steps,
    ],
  ].join('\n').toLowerCase();
}

class HelpCatalog {
  HelpCatalog._(this.topics);
  final Map<String, HelpTopic> topics;

  static Future<HelpCatalog> load({AssetBundle? bundle}) async =>
      HelpCatalog.parse(
        await (bundle ?? rootBundle).loadString('assets/help/zh_TW.json'),
      );

  factory HelpCatalog.parse(String source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    final topics = <String, HelpTopic>{};
    List<String> strings(dynamic value) => List<String>.unmodifiable(
      (value as List?)?.cast<String>() ?? const <String>[],
    );
    for (final raw in data['topics'] as List) {
      final item = raw as Map<String, dynamic>;
      final id = item['id'] as String;
      if (topics.containsKey(id)) {
        throw FormatException('Duplicate help topic: $id');
      }
      topics[id] = HelpTopic(
        id: id,
        title: item['title'] as String,
        category: item['category'] as String,
        keywords: strings(item['keywords']),
        sections: List.unmodifiable([
          for (final s in item['sections'] as List)
            HelpSection(
              heading: s['heading'] as String? ?? '',
              paragraphs: strings(s['paragraphs']),
              steps: strings(s['steps']),
            ),
        ]),
        relatedIds: strings(item['relatedIds']),
      );
    }
    for (final topic in topics.values) {
      for (final id in topic.relatedIds) {
        if (!topics.containsKey(id)) {
          throw FormatException('Unknown help link: $id');
        }
      }
    }
    if (!topics.containsKey(HelpTopicId.home)) {
      throw const FormatException('Missing help home');
    }
    return HelpCatalog._(Map.unmodifiable(topics));
  }

  HelpTopic topic(String id) => topics[id] ?? topics[HelpTopicId.home]!;

  /// All query terms must match; title matches rank before keyword/body matches.
  List<HelpTopic> search(String query) {
    final terms = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (terms.isEmpty) return topics.values.toList();
    final matches = topics.values
        .where((t) => terms.every(t.searchableText.contains))
        .toList();
    int rank(HelpTopic t) => terms.fold(
      0,
      (score, term) =>
          score +
          (t.title.toLowerCase().contains(term)
              ? 100
              : t.keywords.any((k) => k.toLowerCase().contains(term))
              ? 10
              : 1),
    );
    matches.sort((a, b) {
      final score = rank(b).compareTo(rank(a));
      return score != 0 ? score : a.title.compareTo(b.title);
    });
    return matches;
  }
}
