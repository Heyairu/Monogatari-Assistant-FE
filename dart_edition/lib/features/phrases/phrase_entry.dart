import 'phrase_body_validator.dart';

/// A project-scoped, immutable phrase. [body] is Mosaic raw text.
final class PhraseEntry {
  final String id;
  final String name;
  final String shortcut;
  final String category;
  final List<String> tags;
  final String body;
  final bool enabled;

  /// Imported from another project; every Mention needs an explicit decision.
  final bool requiresRelink;
  final DateTime createdAt;
  final DateTime updatedAt;

  PhraseEntry({
    required this.id,
    required this.name,
    required this.shortcut,
    this.category = '',
    List<String> tags = const [],
    required this.body,
    this.enabled = true,
    this.requiresRelink = false,
    required this.createdAt,
    required this.updatedAt,
  }) : tags = List<String>.unmodifiable(tags) {
    if (!RegExp(
      r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      throw const FormatException('phrase id must be a UUID');
    }
    if (name.trim().isEmpty) {
      throw const FormatException('phrase name cannot be empty');
    }
    if (!isValidShortcut(shortcut)) {
      throw const FormatException('phrase shortcut is invalid');
    }
    if (enabled && !const PhraseBodyValidator().validate(body).isValid) {
      throw const FormatException('enabled phrase body is invalid');
    }
  }

  String get normalizedShortcut => shortcut.toLowerCase();

  static bool isValidShortcut(String value) =>
      RegExp(r'^[A-Za-z0-9_-]{1,32}$').hasMatch(value);

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'shortcut': shortcut,
    'category': category,
    'tags': tags,
    'body': body,
    'enabled': enabled,
    'requiresRelink': requiresRelink,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory PhraseEntry.fromJson(Map<String, Object?> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String) throw FormatException('phrase.$key is invalid');
      return value;
    }

    final rawTags = json['tags'];
    if (rawTags is! List || rawTags.any((value) => value is! String)) {
      throw const FormatException('phrase.tags is invalid');
    }
    final enabled = json['enabled'];
    if (enabled is! bool) {
      throw const FormatException('phrase.enabled is invalid');
    }
    final requiresRelink = json['requiresRelink'] ?? false;
    if (requiresRelink is! bool) {
      throw const FormatException('phrase.requiresRelink is invalid');
    }
    return PhraseEntry(
      id: requiredString('id'),
      name: requiredString('name'),
      shortcut: requiredString('shortcut'),
      category: requiredString('category'),
      tags: rawTags.cast<String>(),
      body: requiredString('body'),
      enabled: enabled,
      requiresRelink: requiresRelink,
      createdAt: DateTime.parse(requiredString('createdAt')),
      updatedAt: DateTime.parse(requiredString('updatedAt')),
    );
  }
}

/// Validates identity and shortcut uniqueness before a library is committed.
void validatePhraseLibrary(Iterable<PhraseEntry> phrases) {
  final ids = <String>{};
  final shortcuts = <String>{};
  for (final phrase in phrases) {
    if (!ids.add(phrase.id)) {
      throw FormatException('duplicate phrase id: ${phrase.id}');
    }
    if (!shortcuts.add(phrase.normalizedShortcut)) {
      throw FormatException('duplicate phrase shortcut: ${phrase.shortcut}');
    }
  }
}
