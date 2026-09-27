import "package:flutter_localizations/flutter_localizations.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_quill/flutter_quill.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/editor/plain_text_quill_adapter.dart";
import "package:monogatari_assistant/features/editor/plain_text_quill_editor_poc.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation_parser.dart";
import "package:monogatari_assistant/presentation/providers/collaboration_providers.dart";

void main() {
  Widget buildPoc({
    required String content,
    required ValueChanged<String> onChanged,
    PlainTextQuillEditorCommands? commands,
    PlainTextQuillSearchController? searchController,
    List<RemoteCursorState> remoteCursors = const <RemoteCursorState>[],
    PlainTextQuillCursorReporter? onLocalCursorChanged,
    FocusNode? focusNode,
    int selectionOffset = 0,
  }) {
    return MaterialApp(
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[Locale("zh", "TW")],
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: PlainTextQuillEditorPoc(
            content: content,
            onChanged: onChanged,
            commands: commands,
            searchController: searchController,
            remoteCursors: remoteCursors,
            onLocalCursorChanged: onLocalCursorChanged,
            focusNode: focusNode,
            selectionOffset: selectionOffset,
          ),
        ),
      ),
    );
  }

  QuillController controllerOf(WidgetTester tester) {
    return tester
        .widget<QuillEditor>(
          find.byKey(const ValueKey<String>("plain-text-quill-editor")),
        )
        .controller;
  }

  testWidgets("loads only adapter-produced plain text", (tester) async {
    final changes = <String>[];
    await tester.pumpWidget(
      buildPoc(
        content: "甲\r\n乙//^<重點>//",
        selectionOffset: 3,
        onChanged: changes.add,
      ),
    );

    final controller = controllerOf(tester);
    final editor = tester.widget<QuillEditor>(
      find.byKey(const ValueKey<String>("plain-text-quill-editor")),
    );
    expect(
      PlainTextQuillAdapter.toPlainText(controller.document),
      "甲\n乙//^<重點>//",
    );
    expect(controller.selection.baseOffset, 2);
    expect(editor.config.customStyles?.paragraph?.style.height, 1.15);
    expect(changes, isEmpty);
  });

  testWidgets("emits plain text after a CJK Quill edit", (tester) async {
    final changes = <String>[];
    await tester.pumpWidget(buildPoc(content: "原文", onChanged: changes.add));

    controllerOf(tester).replaceText(
      0,
      "原文".length,
      "新しい正文",
      const TextSelection.collapsed(offset: 5),
    );
    await tester.pump();

    expect(changes, <String>["新しい正文"]);
    expect(
      PlainTextQuillAdapter.toPlainText(controllerOf(tester).document),
      "新しい正文",
    );
  });

  testWidgets("replaces the document when the host switches chapters", (
    tester,
  ) async {
    final changes = <String>[];
    await tester.pumpWidget(
      buildPoc(content: "第一章\r\n正文", onChanged: changes.add),
    );

    await tester.pumpWidget(
      buildPoc(content: "第二章\n正文", onChanged: changes.add),
    );
    await tester.pump();

    expect(
      PlainTextQuillAdapter.toPlainText(controllerOf(tester).document),
      "第二章\n正文",
    );
    expect(changes, isEmpty);
  });

  testWidgets("uses a host-owned focus node for existing commands", (
    tester,
  ) async {
    final focusNode = FocusNode(debugLabel: "production-editor-focus");
    final commands = PlainTextQuillEditorCommands();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      buildPoc(
        content: "正文",
        onChanged: (_) {},
        commands: commands,
        focusNode: focusNode,
      ),
    );

    commands.requestFocus();
    await tester.pump();

    expect(focusNode.hasFocus, isTrue);
    expect(commands.hasFocus, isTrue);
  });

  testWidgets(
    "keeps undo history when a host mirrors a local plain-text edit",
    (tester) async {
      final commands = PlainTextQuillEditorCommands();
      await tester.pumpWidget(
        buildPoc(content: "原文", onChanged: (_) {}, commands: commands),
      );
      controllerOf(
        tester,
      ).replaceText(0, 2, "修改後", const TextSelection.collapsed(offset: 3));
      await tester.pump();

      // This is the normal editorContentProvider -> host-widget echo.
      await tester.pumpWidget(
        buildPoc(content: "修改後", onChanged: (_) {}, commands: commands),
      );
      commands.undo();
      await tester.pump();

      expect(
        PlainTextQuillAdapter.toPlainText(controllerOf(tester).document),
        "原文",
      );
    },
  );

  testWidgets("command bridge selects text and performs local undo and redo", (
    tester,
  ) async {
    final changes = <String>[];
    final commands = PlainTextQuillEditorCommands();
    await tester.pumpWidget(
      buildPoc(content: "原文", onChanged: changes.add, commands: commands),
    );

    commands.requestFocus();
    commands.selectAll();
    expect(
      controllerOf(tester).selection,
      const TextSelection(baseOffset: 0, extentOffset: 2),
    );

    commands.replaceSelectionWith("新しい正文");
    await tester.pump();
    expect(changes, <String>["新しい正文"]);

    commands.undo();
    await tester.pump();
    expect(
      PlainTextQuillAdapter.toPlainText(controllerOf(tester).document),
      "原文",
    );

    commands.redo();
    await tester.pump();
    expect(
      PlainTextQuillAdapter.toPlainText(controllerOf(tester).document),
      "新しい正文",
    );
    expect(commands.hasFocus, isTrue);
  });

  testWidgets("command bridge copy cut and paste remain plain text", (
    tester,
  ) async {
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

    final changes = <String>[];
    final commands = PlainTextQuillEditorCommands();
    await tester.pumpWidget(
      buildPoc(content: "甲乙丙", onChanged: changes.add, commands: commands),
    );
    final controller = controllerOf(tester);
    controller.updateSelection(
      const TextSelection(baseOffset: 1, extentOffset: 2),
      ChangeSource.local,
    );

    await commands.copy();
    expect(clipboardText, "乙");
    await commands.cut();
    await tester.pump();
    expect(PlainTextQuillAdapter.toPlainText(controller.document), "甲丙");

    controller.updateSelection(
      const TextSelection.collapsed(offset: 2),
      ChangeSource.local,
    );
    await commands.paste();
    await tester.pump();
    expect(PlainTextQuillAdapter.toPlainText(controller.document), "甲丙乙");
    expect(changes, <String>["甲丙", "甲丙乙"]);
  });

  testWidgets("editor keyboard undo takes precedence over host shortcuts", (
    tester,
  ) async {
    final commands = PlainTextQuillEditorCommands();
    await tester.pumpWidget(
      buildPoc(content: "原文", onChanged: (_) {}, commands: commands),
    );
    commands
      ..requestFocus()
      ..selectAll()
      ..replaceSelectionWith("修改後");
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(
      PlainTextQuillAdapter.toPlainText(controllerOf(tester).document),
      "原文",
    );
  });

  testWidgets("search maps CJK matches to Quill offsets and selects next", (
    tester,
  ) async {
    final search = PlainTextQuillSearchController();
    await tester.pumpWidget(
      buildPoc(content: "甲乙甲乙", onChanged: (_) {}, searchController: search),
    );

    await search.find("乙");
    expect(search.state.matches, const <TextRange>[
      TextRange(start: 1, end: 2),
      TextRange(start: 3, end: 4),
    ]);
    expect(search.state.currentMatchIndex, 0);
    expect(
      controllerOf(tester).selection,
      const TextSelection(baseOffset: 1, extentOffset: 2),
    );

    await search.findNext();
    expect(search.state.currentMatchIndex, 1);
    expect(
      controllerOf(tester).selection,
      const TextSelection(baseOffset: 3, extentOffset: 4),
    );
  });

  testWidgets("replace current and all preserve plain-text document offsets", (
    tester,
  ) async {
    final changes = <String>[];
    final search = PlainTextQuillSearchController();
    await tester.pumpWidget(
      buildPoc(
        content: "甲\r\n乙乙",
        onChanged: changes.add,
        searchController: search,
      ),
    );

    await search.find("乙");
    expect(search.state.matches.first, const TextRange(start: 2, end: 3));
    await search.replaceCurrent("丙");
    await tester.pump();
    expect(
      PlainTextQuillAdapter.toPlainText(controllerOf(tester).document),
      "甲\n丙乙",
    );

    await search.replaceAll("丁");
    await tester.pump();
    expect(
      PlainTextQuillAdapter.toPlainText(controllerOf(tester).document),
      "甲\n丙丁",
    );
    expect(changes, <String>["甲\n丙乙", "甲\n丙丁"]);
  });

  testWidgets("stale search and proofreading ranges clear after an edit", (
    tester,
  ) async {
    final search = PlainTextQuillSearchController();
    await tester.pumpWidget(
      buildPoc(content: "甲乙甲", onChanged: (_) {}, searchController: search),
    );

    final pending = search.find("甲");
    search.clear();
    await pending;
    expect(search.state.matches, isEmpty);

    search.setProofreadingRanges(const <TextRange>[
      TextRange(start: 1, end: 2),
    ]);
    expect(search.state.proofreadingRanges, hasLength(1));
    controllerOf(
      tester,
    ).replaceText(0, 1, "丙", const TextSelection.collapsed(offset: 1));
    await tester.pump();
    expect(search.state.matches, isEmpty);
    expect(search.state.proofreadingRanges, isEmpty);
  });

  testWidgets("invalid regexp safely produces no search ranges", (
    tester,
  ) async {
    final search = PlainTextQuillSearchController();
    await tester.pumpWidget(
      buildPoc(content: "甲乙", onChanged: (_) {}, searchController: search),
    );

    await search.find("[", useRegexp: true);

    expect(search.state.query, "[");
    expect(search.state.matches, isEmpty);
    expect(search.state.currentMatchIndex, -1);
  });

  testWidgets("keeps Mosaic source visible and lossless after a Quill edit", (
    tester,
  ) async {
    const source =
        "前//@<4e251fc2-1e2b-4f78-93da-91f8c76d9a92|艾莉絲>{初登場}//"
        "與//^<重\\>點>//後";
    final changes = <String>[];
    await tester.pumpWidget(buildPoc(content: source, onChanged: changes.add));

    final controller = controllerOf(tester);
    expect(PlainTextQuillAdapter.toPlainText(controller.document), source);
    expect(const InlineAnnotationParser().parse(source), hasLength(2));

    controller.replaceText(0, 1, "序", const TextSelection.collapsed(offset: 1));
    await tester.pump();

    const expected =
        "序//@<4e251fc2-1e2b-4f78-93da-91f8c76d9a92|艾莉絲>{初登場}//"
        "與//^<重\\>點>//後";
    expect(changes, const <String>[expected]);
    expect(PlainTextQuillAdapter.toPlainText(controller.document), expected);
    expect(const InlineAnnotationParser().parse(expected), hasLength(2));
  });

  testWidgets("reports focused local selections as plain-text offsets", (
    tester,
  ) async {
    final reports = <({int anchorOffset, int focusOffset})>[];
    await tester.pumpWidget(
      buildPoc(
        content: "甲乙丙",
        onChanged: (_) {},
        onLocalCursorChanged: ({required anchorOffset, required focusOffset}) =>
            reports.add((anchorOffset: anchorOffset, focusOffset: focusOffset)),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>("plain-text-quill-editor")),
    );
    await tester.pump();
    controllerOf(tester).updateSelection(
      const TextSelection(baseOffset: 1, extentOffset: 3),
      ChangeSource.local,
    );
    await tester.pump();

    expect(reports.last, (anchorOffset: 1, focusOffset: 3));
  });

  testWidgets("measures a remote plain-text cursor in the Quill render tree", (
    tester,
  ) async {
    final remote = RemoteChapterCursorState(
      replicaId: "peer-a",
      ipAddress: "192.168.1.20",
      chapterId: "chapter-1",
      anchorOffset: 1,
      focusOffset: 2,
      presenceSequence: 1,
      observedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      buildPoc(
        content: "甲乙丙",
        onChanged: (_) {},
        remoteCursors: <RemoteCursorState>[remote],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey<String>("plain-text-quill-remote-caret-peer-a"),
      ),
      findsOneWidget,
    );
  });

  testWidgets("loads a 200KB chapter and extracts only plain text", (
    tester,
  ) async {
    final buffer = StringBuffer();
    while (buffer.length < 200 * 1024) {
      buffer.writeln("這是一段用於 Quill 純文字 PoC 的長正文。");
    }
    final content = buffer.toString();

    await tester.pumpWidget(buildPoc(content: content, onChanged: (_) {}));
    await tester.pump();

    final controller = controllerOf(tester);
    expect(PlainTextQuillAdapter.toPlainText(controller.document), content);
    expect(controller.document.toDelta().toJson(), everyElement(isA<Map>()));
  });
}
