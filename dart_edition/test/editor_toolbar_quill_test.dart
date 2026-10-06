import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_localizations/flutter_localizations.dart";
import "package:flutter_quill/flutter_quill.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/content.dart";
import "package:monogatari_assistant/bin/findreplace.dart";
import "package:monogatari_assistant/features/editor/plain_text_quill_adapter.dart";
import "package:monogatari_assistant/main.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";
import "package:shared_preferences/shared_preferences.dart";

void main() {
  testWidgets("production toolbar edits the focused Quill plain text", (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.binding.setSurfaceSize(const Size(2400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const source =
        "甲//@<4e251fc2-1e2b-4f78-93da-91f8c76d9a92|艾莉絲>{secret}//乙\n丙";
    const displayText = "甲\u2003艾莉絲乙\n丙";
    final container = ProviderContainer();
    addTearDown(container.dispose);

    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case "Clipboard.setData":
            clipboardText =
                (call.arguments as Map<Object?, Object?>)["text"] as String?;
            return null;
          case "Clipboard.getData":
            return clipboardText == null
                ? null
                : <String, String>{"text": clipboardText!};
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
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          home: ContentView(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    container.read(editorContentProvider.notifier).setContent(source);
    await tester.pump();
    final host = tester.widget<EditorTextBox>(find.byType(EditorTextBox));
    final quill = tester.widget<QuillEditor>(
      find.byKey(const ValueKey<String>("plain-text-quill-editor")),
    );
    expect(
      PlainTextQuillAdapter.toPlainText(quill.controller.document),
      displayText,
    );
    host.focusNode.requestFocus();
    await tester.pump();

    Future<void> click(String tooltip) async {
      await tester.tap(find.byTooltip(tooltip));
      await tester.pump(const Duration(milliseconds: 250));
      expect(host.focusNode.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    }

    await click("Select All");
    expect(
      quill.controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: displayText.length),
    );
    await click("Copy");
    expect(clipboardText, "甲艾莉絲乙\n丙");
    expect(container.read(editorContentProvider), source);

    await click("Cut");
    expect(clipboardText, "甲艾莉絲乙\n丙");
    expect(PlainTextQuillAdapter.toPlainText(quill.controller.document), "");
    expect(container.read(editorContentProvider), "");

    clipboardText = "新\r\n文";
    await click("Paste");
    expect(
      PlainTextQuillAdapter.toPlainText(quill.controller.document),
      "新\n文",
    );
    expect(container.read(editorContentProvider), "新\n文");

    quill.controller.updateSelection(
      const TextSelection(baseOffset: 3, extentOffset: 1),
      ChangeSource.local,
    );
    await tester.pump();
    clipboardText = "替";
    await click("Paste");
    expect(PlainTextQuillAdapter.toPlainText(quill.controller.document), "新替");
    expect(container.read(editorContentProvider), "新替");

    // Moving to a standard input must retarget the same toolbar.
    await tester.tap(find.byTooltip("搜尋"));
    await tester.pump();
    final search = tester.widget<FindReplaceBar>(find.byType(FindReplaceBar));
    final searchField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.controller == search.findController,
    );
    await tester.enterText(searchField, "搜尋文字");
    await tester.tap(find.byTooltip("Select All"));
    await tester.pump();
    expect(
      search.findController.selection,
      const TextSelection(baseOffset: 0, extentOffset: 4),
    );
    await tester.tap(find.byTooltip("Copy"));
    await tester.pump();
    expect(clipboardText, "搜尋文字");
    await tester.tap(find.byTooltip("Cut"));
    await tester.pump();
    expect(search.findController.text, "");
    clipboardText = "尋找";
    await tester.tap(find.byTooltip("Paste"));
    await tester.pump();
    expect(search.findController.text, "尋找");
    expect(PlainTextQuillAdapter.toPlainText(quill.controller.document), "新替");

    host.focusNode.requestFocus();
    await tester.pump();
    await click("Select All");
    await click("Copy");
    expect(clipboardText, "新替");

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
