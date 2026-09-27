import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/findreplace.dart";

void main() {
  testWidgets("search waits until IME composition is committed", (
    tester,
  ) async {
    final findController = TextEditingController();
    final replaceController = TextEditingController();
    final searches = <String>[];
    addTearDown(findController.dispose);
    addTearDown(replaceController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FindReplaceBar(
            findController: findController,
            replaceController: replaceController,
            options: FindReplaceOptions(),
            onSearchChanged: (text, _) => searches.add(text),
          ),
        ),
      ),
    );

    findController.value = const TextEditingValue(
      text: "ㄉ",
      selection: TextSelection.collapsed(offset: 1),
      composing: TextRange(start: 0, end: 1),
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(searches, isEmpty);

    findController.value = const TextEditingValue(
      text: "的",
      selection: TextSelection.collapsed(offset: 1),
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(searches, <String>["的"]);
  });
}
