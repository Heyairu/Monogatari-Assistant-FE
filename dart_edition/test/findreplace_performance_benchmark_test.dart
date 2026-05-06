import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

import "package:monogatari_assistant/bin/findreplace.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("buildTextSpan benchmark with 100KB text and 1000 matches", (
    tester,
  ) async {
    BuildContext? context;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (buildContext) {
            context = buildContext;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(context, isNotNull);

    final String largeText = List<String>.filled(50000, "ab").join();
    final controller = HighlightTextEditingController(text: largeText);

    final List<TextSelection> matches = <TextSelection>[];
    for (int i = 0; i < 1500; i++) {
      final int start = i * 2;
      if (start + 1 >= largeText.length) {
        break;
      }
      matches.add(TextSelection(baseOffset: start, extentOffset: start + 1));
    }

    controller.updateSearchHighlights(matches: matches, currentIndex: 0);

    // Warm up once to avoid measuring one-time setup cost.
    controller.buildTextSpan(
      context: context!,
      style: const TextStyle(fontSize: 14),
    );

    final Stopwatch stopwatch = Stopwatch()..start();
    const int iterations = 20;
    for (int i = 0; i < iterations; i++) {
      controller.buildTextSpan(
        context: context!,
        style: const TextStyle(fontSize: 14),
      );
    }
    stopwatch.stop();

    final double averageMs = stopwatch.elapsedMicroseconds / 1000 / iterations;
    // ignore: avoid_print
    print(
      'buildTextSpan benchmark: ${iterations} iterations, '
      'total=${stopwatch.elapsedMilliseconds}ms, '
      'avg=${averageMs.toStringAsFixed(2)}ms, '
      'matches=${controller.searchMatches.length}, '
      'textLength=${largeText.length}',
    );

    expect(controller.searchMatches.length, 1000);
    expect(averageMs, lessThan(250));
  });
}
