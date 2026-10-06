import 'dart:convert';

import 'phrase_body_validator.dart';
import 'phrase_entry.dart';

enum PhraseScope { project, global }

enum PhraseImportChoice { skip, replace, copy }

final class ScopedPhrase {
  final PhraseEntry phrase;
  final PhraseScope scope;

  const ScopedPhrase(this.phrase, this.scope);
}

bool phraseHasMention(PhraseEntry phrase) => const PhraseBodyValidator()
    .validate(phrase.body)
    .annotations
    .any((annotation) => annotation.hasTarget);

List<PhraseEntry> availablePhrases(
  Iterable<PhraseEntry> project,
  Iterable<PhraseEntry> global,
) {
  final projectEntries = project.toList();
  final projectIds = projectEntries.map((phrase) => phrase.id).toSet();
  final projectShortcuts = projectEntries
      .map((phrase) => phrase.normalizedShortcut)
      .toSet();
  return List.unmodifiable([
    ...projectEntries,
    for (final phrase in global)
      if (!projectIds.contains(phrase.id) &&
          !projectShortcuts.contains(phrase.normalizedShortcut))
        phrase,
  ]);
}

/// Portable short-phrase file. Project mentions always need relinking on import.
abstract final class PhraseTransferCodec {
  static const kind = 'monogatari-phrase-bundle';
  static const version = 1;

  static String encode(Iterable<ScopedPhrase> phrases) {
    final entries = phrases.toList();
    for (final entry in entries) {
      if (entry.scope == PhraseScope.global && phraseHasMention(entry.phrase)) {
        throw const FormatException('含 Mention 的短語不能匯出為全域短語');
      }
    }
    return const JsonEncoder.withIndent('  ').convert({
      'kind': kind,
      'version': version,
      'phrases': [
        for (final entry in entries)
          {'scope': entry.scope.name, 'phrase': entry.phrase.toJson()},
      ],
    });
  }

  static List<ScopedPhrase> decode(String source) {
    final value = jsonDecode(source);
    if (value is! Map ||
        value['kind'] != kind ||
        value['version'] != version ||
        value['phrases'] is! List) {
      throw const FormatException('不支援的短語匯入檔案');
    }
    final entries = <ScopedPhrase>[];
    for (final item in value['phrases'] as List) {
      if (item is! Map || item['phrase'] is! Map) {
        throw const FormatException('短語匯入檔案格式錯誤');
      }
      final scope = PhraseScope.values.where(
        (scope) => scope.name == item['scope'],
      );
      if (scope.isEmpty) throw const FormatException('短語範圍無效');
      final phrase = PhraseEntry.fromJson(
        Map<String, Object?>.from(item['phrase'] as Map),
      );
      final hasMention = phraseHasMention(phrase);
      entries.add(
        ScopedPhrase(
          hasMention ? copyPhrase(phrase, requiresRelink: true) : phrase,
          hasMention ? PhraseScope.project : scope.first,
        ),
      );
    }
    return List.unmodifiable(entries);
  }
}

PhraseEntry copyPhrase(
  PhraseEntry source, {
  String? id,
  String? shortcut,
  bool? enabled,
  bool? requiresRelink,
  DateTime? updatedAt,
}) => PhraseEntry(
  id: id ?? source.id,
  name: source.name,
  shortcut: shortcut ?? source.shortcut,
  category: source.category,
  tags: source.tags,
  body: source.body,
  enabled: enabled ?? source.enabled,
  requiresRelink: requiresRelink ?? source.requiresRelink,
  createdAt: source.createdAt,
  updatedAt: updatedAt ?? source.updatedAt,
);

String nextAvailableShortcut(String shortcut, Iterable<PhraseEntry> existing) {
  final used = existing.map((phrase) => phrase.normalizedShortcut).toSet();
  if (!used.contains(shortcut.toLowerCase())) return shortcut;
  for (var suffix = 2; ; suffix++) {
    final tail = '_$suffix';
    final prefix = shortcut.substring(
      0,
      (32 - tail.length).clamp(0, shortcut.length),
    );
    final candidate = '$prefix$tail';
    if (!used.contains(candidate.toLowerCase())) return candidate;
  }
}

List<ScopedPhrase> phraseImportConflicts(
  PhraseEntry incoming,
  Iterable<PhraseEntry> projects,
  Iterable<PhraseEntry> globals,
) => [
  for (final phrase in projects)
    if (phrase.id == incoming.id ||
        phrase.normalizedShortcut == incoming.normalizedShortcut)
      ScopedPhrase(phrase, PhraseScope.project),
  for (final phrase in globals)
    if (phrase.id == incoming.id ||
        phrase.normalizedShortcut == incoming.normalizedShortcut)
      ScopedPhrase(phrase, PhraseScope.global),
];

/// Mutates the staged lists only; callers persist them after every decision.
PhraseEntry? applyPhraseImport({
  required ScopedPhrase incoming,
  required List<PhraseEntry> projects,
  required List<PhraseEntry> globals,
  required PhraseImportChoice choice,
  String? copyId,
}) {
  final conflicts = phraseImportConflicts(incoming.phrase, projects, globals);
  if (conflicts.isNotEmpty && choice == PhraseImportChoice.skip) return null;
  var phrase = incoming.phrase;
  if (conflicts.isNotEmpty && choice == PhraseImportChoice.copy) {
    if (copyId == null) throw ArgumentError.notNull('copyId');
    phrase = copyPhrase(
      phrase,
      id: copyId,
      shortcut: nextAvailableShortcut(phrase.shortcut, [
        ...projects,
        ...globals,
      ]),
    );
  } else if (conflicts.isNotEmpty && choice == PhraseImportChoice.replace) {
    final ids = conflicts.map((item) => item.phrase.id).toSet();
    projects.removeWhere((item) => ids.contains(item.id));
    globals.removeWhere((item) => ids.contains(item.id));
  }
  if (incoming.scope == PhraseScope.global && !phraseHasMention(phrase)) {
    globals.add(phrase);
  } else {
    projects.add(phrase);
  }
  return phrase;
}
