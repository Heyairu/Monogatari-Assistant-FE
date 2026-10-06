import 'phrase_body_validator.dart';
import 'phrase_entry.dart';
import 'phrase_display_preview.dart';
import '../inline_annotations/inline_annotation.dart';

final class PhraseSearchResult {
  final PhraseEntry phrase;
  final String preview;
  final List<InlineAnnotation> annotations;

  const PhraseSearchResult(this.phrase, this.preview, this.annotations);
}

/// Built when the project phrase library changes, then reused per keystroke.
final class PhraseSearchIndex {
  final List<_IndexedPhrase> _entries;

  PhraseSearchIndex(Iterable<PhraseEntry> phrases)
    : _entries = List<_IndexedPhrase>.unmodifiable([
        for (final phrase in phrases)
          if (phrase.enabled)
            _IndexedPhrase(
              phrase,
              const PhraseBodyValidator().validate(phrase.body),
            ),
      ]);

  List<PhraseSearchResult> search(String query, {int limit = 100}) {
    if (limit <= 0) return const <PhraseSearchResult>[];
    final normalized = query.trim().toLowerCase();
    final ranked =
        <(int, _IndexedPhrase)>[
          for (final entry in _entries)
            if (entry.rank(normalized) case final rank? when rank >= 0)
              (rank, entry),
        ]..sort((left, right) {
          final byRank = left.$1.compareTo(right.$1);
          if (byRank != 0) return byRank;
          final byShortcut = left.$2.phrase.shortcut.compareTo(
            right.$2.phrase.shortcut,
          );
          return byShortcut != 0
              ? byShortcut
              : left.$2.phrase.id.compareTo(right.$2.phrase.id);
        });
    return List<PhraseSearchResult>.unmodifiable([
      for (final item in ranked.take(limit))
        PhraseSearchResult(
          item.$2.phrase,
          item.$2.preview,
          item.$2.annotations,
        ),
    ]);
  }
}

final class _IndexedPhrase {
  final PhraseEntry phrase;
  final String preview;
  final List<InlineAnnotation> annotations;
  final List<String> tags;
  final String text;

  _IndexedPhrase(this.phrase, PhraseBodyValidation validation)
    : preview = phraseDisplayPreview(phrase.body),
      annotations = validation.annotations,
      tags = phrase.tags.map((tag) => tag.toLowerCase()).toList(),
      text = phraseDisplayPreview(phrase.body).toLowerCase();

  int? rank(String query) {
    if (query.isEmpty) return 0;
    if (phrase.normalizedShortcut == query) return 0;
    if (phrase.normalizedShortcut.startsWith(query)) return 1;
    if (tags.any((tag) => tag.contains(query))) return 2;
    if (text.contains(query)) return 3;
    return null;
  }
}
