import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/copilot/domain/copilot_models.dart";

void main() {
  test(
    "100 KiB, 500 KiB, and 1 MiB chapter contexts stay bounded",
    () {
      const inputSizes = <int>[100 * 1024, 500 * 1024, 1024 * 1024];
      final total = Stopwatch()..start();

      for (final inputSize in inputSizes) {
        final content = "x" * inputSize;
        final stopwatch = Stopwatch()..start();
        final first = CopilotContextSnapshot.currentChapter(
          chapterId: "chapter-$inputSize",
          title: "Benchmark $inputSize",
          content: content,
        );
        final second = CopilotContextSnapshot.currentChapter(
          chapterId: "chapter-$inputSize",
          title: "Benchmark $inputSize",
          content: content,
        );
        final promptBytes = utf8.encode(first.toPromptBlock()).length;
        stopwatch.stop();

        expect(utf8.encode(content), hasLength(inputSize));
        expect(
          utf8.encode(first.content).length,
          CopilotContextSnapshot.maxContentBytes,
        );
        expect(first.truncated, isTrue);
        expect(first.fingerprint, second.fingerprint);
        expect(first.content, second.content);
        expect(
          promptBytes,
          lessThan(CopilotContextSnapshot.maxContentBytes + 1024),
        );

        // Visible under expanded reporting for profile and CI baselines.
        // ignore: avoid_print
        print(
          "copilot context benchmark: input=${inputSize ~/ 1024}KiB, "
          "output=${utf8.encode(first.content).length ~/ 1024}KiB, "
          "prompt=${promptBytes ~/ 1024}KiB, "
          "twoBuilds=${stopwatch.elapsedMilliseconds}ms",
        );
      }
      total.stop();

      // Generous debug/CI budget that still catches accidental quadratic
      // scans or retaining the complete manuscript in the prompt payload.
      expect(total.elapsed, lessThan(const Duration(seconds: 5)));
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );
}
