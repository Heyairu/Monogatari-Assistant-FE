import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

import "package:monogatari_assistant/bin/content.dart";
import "package:monogatari_assistant/presentation/providers/global_state_providers.dart";

class _TestSettingsStateNotifier extends SettingsStateNotifier {
  @override
  Future<AppSettingsStateData> build() async {
    return const AppSettingsStateData(fontSize: 14);
  }
}

Widget _buildHarness({
  required TextEditingController controller,
  required FocusNode editorFocusNode,
  FocusNode? secondaryFocusNode,
}) {
  return ProviderScope(
    overrides: [
      settingsStateProvider.overrideWith(_TestSettingsStateNotifier.new),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: EditorTextBox(
                controller: controller,
                focusNode: editorFocusNode,
              ),
            ),
            if (secondaryFocusNode != null)
              TextField(
                focusNode: secondaryFocusNode,
              ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  group("EditorTextBox with CodeField", () {
    testWidgets("syncs typed input back to external controller", (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        _buildHarness(controller: controller, editorFocusNode: focusNode),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, "hello world");
      await tester.pumpAndSettle();

      expect(controller.text, "hello world");

      controller.dispose();
      focusNode.dispose();
    });

    testWidgets("syncs external selection and text updates", (tester) async {
      final controller = TextEditingController(text: "alpha beta");
      final focusNode = FocusNode();

      await tester.pumpWidget(
        _buildHarness(controller: controller, editorFocusNode: focusNode),
      );
      await tester.pumpAndSettle();

      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pumpAndSettle();

      final updated = controller.text.replaceRange(
        controller.selection.start,
        controller.selection.end,
        "gamma",
      );
      controller.value = TextEditingValue(
        text: updated,
        selection: const TextSelection.collapsed(offset: 5),
      );
      await tester.pumpAndSettle();

      final editable = tester.widget<EditableText>(find.byType(EditableText).first);
      expect(controller.text, "gamma beta");
      expect(editable.controller.text, controller.text);

      controller.dispose();
      focusNode.dispose();
    });

    testWidgets("supports focus switch between editor and another input", (tester) async {
      final controller = TextEditingController();
      final editorFocusNode = FocusNode();
      final secondaryFocusNode = FocusNode();

      await tester.pumpWidget(
        _buildHarness(
          controller: controller,
          editorFocusNode: editorFocusNode,
          secondaryFocusNode: secondaryFocusNode,
        ),
      );
      await tester.pumpAndSettle();

      editorFocusNode.requestFocus();
      await tester.pumpAndSettle();
      expect(editorFocusNode.hasFocus, isTrue);

      secondaryFocusNode.requestFocus();
      await tester.pumpAndSettle();
      expect(secondaryFocusNode.hasFocus, isTrue);
      expect(editorFocusNode.hasFocus, isFalse);

      controller.dispose();
      editorFocusNode.dispose();
      secondaryFocusNode.dispose();
    });
  });
}
