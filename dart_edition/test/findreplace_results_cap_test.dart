import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

import "package:monogatari_assistant/bin/findreplace.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("updateSearchHighlights enforces max results cap", (
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

    final controller = HighlightTextEditingController(text: 'a' * 2000);

    // create 1500 matches spaced
    final matches = <TextSelection>[];
    for (int i = 0; i < 1500; i++) {
      final start = i % 1800;
      matches.add(TextSelection(baseOffset: start, extentOffset: start + 1));
    }

    controller.updateSearchHighlights(matches: matches, currentIndex: 0);

    expect(controller.searchMatches.length <= 1000, isTrue);
    expect(controller.searchMatches.length, 1000);
  });
}
