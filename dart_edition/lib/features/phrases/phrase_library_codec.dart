import 'dart:convert';

import 'phrase_entry.dart';

abstract final class PhraseLibraryCodec {
  static const version = 1;

  static String encode(Iterable<PhraseEntry> phrases) {
    final entries = phrases.toList(growable: false);
    validatePhraseLibrary(entries);
    return jsonEncode({
      'version': version,
      'phrases': entries.map((entry) => entry.toJson()).toList(),
    });
  }

  static List<PhraseEntry> decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map ||
        decoded['version'] != version ||
        decoded['phrases'] is! List) {
      throw const FormatException('unsupported phrase library payload');
    }
    final entries = <PhraseEntry>[
      for (final value in decoded['phrases'] as List)
        if (value is Map)
          PhraseEntry.fromJson(Map<String, Object?>.from(value))
        else
          throw const FormatException('phrase entry is invalid'),
    ];
    validatePhraseLibrary(entries);
    return List<PhraseEntry>.unmodifiable(entries);
  }
}
