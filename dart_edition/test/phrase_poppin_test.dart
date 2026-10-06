import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monogatari_assistant/features/poppin/mosaic_intellisense.dart';
import 'package:monogatari_assistant/features/phrases/phrase_entry.dart';
import 'package:monogatari_assistant/features/phrases/phrase_search_index.dart';

void main() {
  const engine = MosaicIntelliSenseEngine();
  final phrase = PhraseEntry(
    id: '8f680e3c-90c1-4f37-ae35-f70c4dc7fe8f',
    name: '抵達',
    shortcut: 'arrive',
    body: '她抵達了。',
    createdAt: DateTime.utc(2026, 10, 1),
    updatedAt: DateTime.utc(2026, 10, 1),
  );
  final index = PhraseSearchIndex([phrase]);

  MosaicCompletionSession? build(
    String raw, {
    int? menuStart,
    int? queryStart,
  }) => engine.build(
    rawText: raw,
    rawCaret: raw.length,
    loadTargets: (_) => const [],
    phraseIndex: index,
    phraseMenuTriggerStart: menuStart,
    phraseMenuQueryStart: queryStart,
  );

  test(';; searches phrases and replaces the full trigger query', () {
    final session = build('前文 ;;arr');
    expect(session?.kind, MosaicCompletionKind.phrase);
    expect(session?.rawReplacementRange, const TextRange(start: 3, end: 8));
    expect(session?.candidates.single.phraseId, phrase.id);
    expect(build('前文 ;;arr ')?.kind, isNot(MosaicCompletionKind.phrase));
    expect(build('//@<;;arr')?.kind, isNot(MosaicCompletionKind.phrase));
  });

  test('slash and backslash keep phrase category and query', () {
    for (final trigger in ['/', r'\']) {
      final menu = build('前文 $trigger');
      expect(menu?.candidates.any((item) => item.phraseMenu), isTrue);
      final start = '前文 '.length;
      final query = build(
        '前文 ${trigger}arr',
        menuStart: start,
        queryStart: start + 1,
      );
      expect(query?.kind, MosaicCompletionKind.phrase);
      expect(query?.rawReplacementRange.start, start);
      expect(query?.candidates.single.phraseId, phrase.id);
    }
  });

  test('large phrase library searches without reparsing on each query', () {
    final entries = [
      for (var index = 0; index < 2000; index++)
        PhraseEntry(
          id: '00000000-0000-4000-8000-${index.toString().padLeft(12, '0')}',
          name: '短語 $index',
          shortcut: 'entry$index',
          body: '固定正文 $index',
          createdAt: DateTime.utc(2026, 10, 1),
          updatedAt: DateTime.utc(2026, 10, 1),
        ),
    ];
    final stopwatch = Stopwatch()..start();
    final largeIndex = PhraseSearchIndex(entries);
    for (var query = 0; query < 50; query++) {
      expect(largeIndex.search('entry$query', limit: 100), isNotEmpty);
    }
    stopwatch.stop();
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 10)));
  });

  test('candidate reports Mention and unresolved counts', () {
    final withMention = PhraseEntry(
      id: '4d470aaf-48ea-4550-930e-9e5636c82a11',
      name: '角色稱呼',
      shortcut: 'alias',
      body: '//@<4e251fc2-1e2b-4f78-93da-91f8c76d9a92|艾莉絲>//',
      createdAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
    );
    final session = engine.build(
      rawText: ';;alias',
      rawCaret: 7,
      loadTargets: (_) => const [],
      phraseIndex: PhraseSearchIndex([withMention]),
      phraseTargetExists: (_, __) => false,
    );
    expect(session?.candidates.single.detail, contains('Mention 1'));
    expect(session?.candidates.single.detail, contains('待連結 1'));
    expect(session?.candidates.single.detail, contains('@艾莉絲'));
    expect(session?.candidates.single.detail, isNot(contains('//@<')));
  });
}
