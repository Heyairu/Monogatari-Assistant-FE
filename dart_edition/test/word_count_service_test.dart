import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/settings_manager.dart";
import "package:monogatari_assistant/services/word_count_service.dart";

void main() {
  test(
    "pending revisions never synchronously fall back and latest wins",
    () async {
      final calls = <String>[];
      final completions = <Completer<int>>[];
      final service = WordCountService(
        maxConcurrent: 2,
        calculator: (content, mode) {
          calls.add(content);
          final completer = Completer<int>();
          completions.add(completer);
          return completer.future;
        },
      );
      addTearDown(service.dispose);

      service.synchronizeChapters(const <WordCountChapterInput>[
        WordCountChapterInput(chapterId: "chapter", content: "old"),
      ], WordCountMode.characters);

      expect(calls, <String>["old"]);
      expect(
        service.lookup("chapter", WordCountMode.characters).isPending,
        isTrue,
      );
      expect(service.cachedCount("chapter", WordCountMode.characters), isNull);

      service.synchronizeChapters(const <WordCountChapterInput>[
        WordCountChapterInput(chapterId: "chapter", content: "newest"),
      ], WordCountMode.characters);
      expect(calls, <String>["old"]);

      completions.first.complete(3);
      await Future<void>.delayed(Duration.zero);
      expect(calls, <String>["old", "newest"]);
      expect(service.total, 0);

      completions.last.complete(6);
      await Future<void>.delayed(Duration.zero);
      expect(service.total, 6);
      expect(service.cachedCount("chapter", WordCountMode.characters), 6);
    },
  );

  test("cached reads are keyed by chapter and mode", () {
    final service = WordCountService(
      calculator: (content, mode) async => content.length,
    );
    addTearDown(service.dispose);

    service.storeCount(
      chapterId: "a",
      content: "abc",
      mode: WordCountMode.characters,
      count: 3,
    );

    expect(service.cachedCount("a", WordCountMode.characters), 3);
    expect(service.cachedCount("a", WordCountMode.wordsAndCharacters), isNull);
    expect(service.cachedCount("b", WordCountMode.characters), isNull);
  });
}
