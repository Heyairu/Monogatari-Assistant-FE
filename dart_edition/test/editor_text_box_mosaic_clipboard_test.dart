import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/content.dart";
import "package:monogatari_assistant/bin/findreplace.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("copy and cut expose display text while preserving raw syntax", (
    tester,
  ) async {
    const uuid = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";
    const raw = "A //@<$uuid|艾莉絲>{secret}// B";
    final controller = HighlightTextEditingController(text: raw);
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == "Clipboard.setData") {
          clipboardText =
              (call.arguments as Map<Object?, Object?>)["text"] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(controller: controller, focusNode: focusNode),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    controller.selection = const TextSelection(baseOffset: 3, extentOffset: 6);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(clipboardText, "艾莉絲");
    expect(controller.rawText, raw);

    controller.selection = const TextSelection(baseOffset: 3, extentOffset: 6);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(clipboardText, "艾莉絲");
    expect(controller.text, "A  B");
    expect(controller.rawText, "A  B");
  });
}
