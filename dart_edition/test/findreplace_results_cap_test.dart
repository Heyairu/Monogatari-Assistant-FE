import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

import "package:monogatari_assistant/bin/findreplace.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("updateSearchHighlights enforces max results cap", (
    tester,
  ) async {
    final controller = HighlightTextEditingController(text: 'a' * 4000);

    // Create more matches than the controller is allowed to retain.
    final matches = <TextSelection>[];
    for (int i = 0; i < 3000; i++) {
      final start = i % 3800;
      matches.add(TextSelection(baseOffset: start, extentOffset: start + 1));
    }

    controller.updateSearchHighlights(matches: matches, currentIndex: 0);

    expect(
      controller.searchMatches.length,
      HighlightTextEditingController.maxSearchResults,
    );
    controller.dispose();
  });
}
