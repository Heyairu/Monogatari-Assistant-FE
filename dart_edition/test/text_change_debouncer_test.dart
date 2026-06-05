import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/utils/text_change_debouncer.dart";

void main() {
  testWidgets("word count pipeline triggers at most once per debounce window", (
    tester,
  ) async {
    for (final size in [10 * 1024, 100 * 1024, 500 * 1024]) {
      var wordCountTriggers = 0;
      var contentCommitTriggers = 0;
      String? wordCountText;
      String? committedText;
      final debouncer = TextChangeDebouncer(
        wordCountDelay: const Duration(milliseconds: 300),
        contentCommitDelay: const Duration(milliseconds: 200),
        onWordCountTrigger: (text) {
          wordCountTriggers++;
          wordCountText = text;
        },
        onContentCommitTrigger: (text) {
          contentCommitTriggers++;
          committedText = text;
        },
      );
      addTearDown(debouncer.cancelAll);

      final baseText = List.filled(size, "字").join();
      for (var index = 0; index < 20; index++) {
        debouncer.onTextChanged("$baseText$index");
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(wordCountTriggers, 0);

      await tester.pump(const Duration(milliseconds: 289));
      expect(wordCountTriggers, 0);

      await tester.pump(const Duration(milliseconds: 1));
      expect(wordCountTriggers, 1);
      expect(wordCountText, "$baseText${19}");
      expect(contentCommitTriggers, 1);
      expect(committedText, "$baseText${19}");

      debouncer.cancelAll();
    }
  });
}
