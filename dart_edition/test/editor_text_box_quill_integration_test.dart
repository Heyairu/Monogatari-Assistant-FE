import "package:flutter_localizations/flutter_localizations.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter_quill/flutter_quill.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/content.dart";
import "package:monogatari_assistant/bin/findreplace.dart";
import "package:monogatari_assistant/features/editor/plain_text_quill_adapter.dart";
import "package:monogatari_assistant/features/editor/plain_text_quill_editor_poc.dart";
import "package:monogatari_assistant/features/editor/plain_text_quill_render_range.dart";

void main() {
  Widget buildEditor({
    required HighlightTextEditingController controller,
    required FocusNode focusNode,
    PlainTextQuillSearchController? searchController,
    ValueChanged<EditorTextInteraction>? onInteractionOffset,
  }) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: const <Locale>[Locale("zh", "TW")],
        home: Scaffold(
          body: EditorTextBox(
            controller: controller,
            focusNode: focusNode,
            quillSearchController: searchController,
            onInteractionOffset: onInteractionOffset,
          ),
        ),
      ),
    );
  }

  QuillController quillControllerOf(WidgetTester tester) {
    return tester
        .widget<QuillEditor>(
          find.byKey(const ValueKey<String>("plain-text-quill-editor")),
        )
        .controller;
  }

  testWidgets("default host projects Mosaic syntax and preserves raw edits", (
    tester,
  ) async {
    const source = "前//@<4e251fc2-1e2b-4f78-93da-91f8c76d9a92|艾莉絲>{登場}//後";
    final controller = HighlightTextEditingController(text: source);
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      buildEditor(controller: controller, focusNode: focusNode),
    );
    final quill = quillControllerOf(tester);
    expect(PlainTextQuillAdapter.toPlainText(quill.document), "前\u2003艾莉絲後");
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>("plain-text-quill-mention-1")),
      findsOneWidget,
    );
    final mention = find.byKey(
      const ValueKey<String>("plain-text-quill-mention-1"),
    );
    final symbol = tester.widget<Text>(
      find.descendant(of: mention, matching: find.text("@")),
    );
    final badge = tester.widget<DecoratedBox>(
      find.descendant(of: mention, matching: find.byType(DecoratedBox)),
    );
    expect(symbol.style?.fontSize, 16);
    expect(symbol.style?.height, 1.15);
    expect(symbol.style?.fontWeight, FontWeight.normal);
    expect((badge.decoration as BoxDecoration).borderRadius, isNull);
    expect(
      PlainTextQuillAdapter.toPlainText(quill.document),
      isNot(contains("id")),
    );

    focusNode.requestFocus();
    quill.replaceText(0, 1, "序", const TextSelection.collapsed(offset: 1));
    await tester.pump();

    expect(
      controller.rawText,
      "序//@<4e251fc2-1e2b-4f78-93da-91f8c76d9a92|艾莉絲>{登場}//後",
    );
    expect(controller.displayText, "序\uFFFC艾莉絲後");
    expect(PlainTextQuillAdapter.toPlainText(quill.document), "序\u2003艾莉絲後");
  });

  testWidgets("host display selection is applied to the Quill document", (
    tester,
  ) async {
    final controller = HighlightTextEditingController(text: "甲乙丙");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    controller.setRawText(
      "甲乙丙",
      rawSelection: const TextSelection.collapsed(offset: 2),
    );

    await tester.pumpWidget(
      buildEditor(controller: controller, focusNode: focusNode),
    );
    await tester.pump();

    expect(quillControllerOf(tester).selection.baseOffset, 2);
  });

  testWidgets("host FindReplace ranges select and highlight the Quill text", (
    tester,
  ) async {
    final controller = HighlightTextEditingController(text: "甲乙甲乙");
    final focusNode = FocusNode();
    final searchController = PlainTextQuillSearchController();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    addTearDown(searchController.dispose);

    await tester.pumpWidget(
      buildEditor(
        controller: controller,
        focusNode: focusNode,
        searchController: searchController,
      ),
    );
    searchController.showHostResults(
      query: "乙",
      matches: const <TextRange>[
        TextRange(start: 1, end: 2),
        TextRange(start: 3, end: 4),
      ],
      currentMatchIndex: 1,
    );
    await tester.pump();
    await tester.pump();

    expect(
      quillControllerOf(tester).selection,
      const TextSelection(baseOffset: 3, extentOffset: 4),
    );
    expect(
      find.byKey(const ValueKey<String>("plain-text-quill-search-0")),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>("plain-text-quill-search-1")),
      findsOneWidget,
    );
    final otherPaint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey<String>("plain-text-quill-search-0")),
    );
    final currentPaint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey<String>("plain-text-quill-search-1")),
    );
    expect(
      (otherPaint.painter as dynamic).backgroundColor,
      const Color(0xFFFFD600).withValues(alpha: 0.30),
    );
    expect(
      (currentPaint.painter as dynamic).backgroundColor,
      const Color(0xFFFF1744).withValues(alpha: 0.34),
    );
    expect(
      (otherPaint.painter as dynamic).outlineColor,
      const Color(0xFFFFB300).withValues(alpha: 0.95),
    );
    expect(
      (currentPaint.painter as dynamic).outlineColor,
      const Color(0xFFF50032).withValues(alpha: 0.95),
    );

    searchController.setProofreadingRanges(const <TextRange>[
      TextRange(start: 0, end: 1),
    ]);
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>("plain-text-quill-proofreading-0")),
      findsOneWidget,
    );
  });

  testWidgets("host CRLF search ranges map to canonical Quill LF offsets", (
    tester,
  ) async {
    final controller = HighlightTextEditingController(text: "甲\r\n乙\r\n丙乙");
    final focusNode = FocusNode();
    final searchController = PlainTextQuillSearchController();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    addTearDown(searchController.dispose);

    await tester.pumpWidget(
      buildEditor(
        controller: controller,
        focusNode: focusNode,
        searchController: searchController,
      ),
    );
    searchController.showHostResults(
      query: "乙",
      matches: const <TextRange>[
        TextRange(start: 3, end: 4),
        TextRange(start: 7, end: 8),
      ],
      currentMatchIndex: 1,
    );
    await tester.pump();

    expect(searchController.state.matches, const <TextRange>[
      TextRange(start: 2, end: 3),
      TextRange(start: 5, end: 6),
    ]);
    expect(
      quillControllerOf(tester).selection,
      const TextSelection(baseOffset: 5, extentOffset: 6),
    );
  });

  testWidgets("Rhodanthe render ranges become visible Quill decorations", (
    tester,
  ) async {
    final controller = HighlightTextEditingController(text: "甲\r\n乙");
    final focusNode = FocusNode();
    final searchController = PlainTextQuillSearchController();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    addTearDown(searchController.dispose);

    await tester.pumpWidget(
      buildEditor(
        controller: controller,
        focusNode: focusNode,
        searchController: searchController,
      ),
    );
    searchController.setRenderRanges(const <PlainTextQuillRenderRange>[
      PlainTextQuillRenderRange(
        range: TextRange(start: 3, end: 4),
        decorationColor: Colors.red,
        decorationThickness: 2,
        doubleUnderline: true,
      ),
    ]);
    await tester.pump();
    await tester.pump();

    expect(
      searchController.state.renderRanges.single.range,
      const TextRange(start: 2, end: 3),
    );
    expect(
      find.byKey(const ValueKey<String>("plain-text-quill-rhodanthe-0")),
      findsOneWidget,
    );
    final paint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey<String>("plain-text-quill-rhodanthe-0")),
    );
    expect((paint.painter as dynamic).doubleUnderline, isTrue);
  });

  testWidgets("Mosaic Mention pointer interaction reaches the host", (
    tester,
  ) async {
    const source = "前//@<4e251fc2-1e2b-4f78-93da-91f8c76d9a92|艾莉絲>{登場}//後";
    final controller = HighlightTextEditingController(text: source);
    final focusNode = FocusNode();
    EditorTextInteraction? interaction;
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      buildEditor(
        controller: controller,
        focusNode: focusNode,
        onInteractionOffset: (value) => interaction = value,
      ),
    );
    final paragraph = tester.renderObject<RenderParagraph>(
      find
          .descendant(
            of: find.byType(QuillEditor),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is RichText &&
                  widget.text.toPlainText().contains("艾莉絲"),
            ),
          )
          .first,
    );
    final box = paragraph
        .getBoxesForSelection(
          const TextSelection(baseOffset: 3, extentOffset: 4),
        )
        .single
        .toRect();
    await tester.tapAt(
      paragraph.localToGlobal(
        Offset(box.left + box.width * 0.2, box.center.dy),
      ),
    );
    await tester.pump();

    expect(interaction, isNotNull);
    expect(interaction!.displayOffset, 3);
    expect(
      controller.projection.annotationAtDisplayOffset(
        interaction!.displayOffset,
      ),
      isNotNull,
    );
  });

  testWidgets(
    "Rhodanthe boxes follow paragraph padding wrapping and scrolling",
    (tester) async {
      final text = List.filled(1000, "甲乙丙丁").join();
      final controller = HighlightTextEditingController(text: text);
      final focusNode = FocusNode();
      final search = PlainTextQuillSearchController();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);
      addTearDown(search.dispose);
      await tester.pumpWidget(
        buildEditor(
          controller: controller,
          focusNode: focusNode,
          searchController: search,
        ),
      );
      search.setRenderRanges(const [
        PlainTextQuillRenderRange(
          range: TextRange(start: 1, end: 100),
          decorationColor: Colors.red,
        ),
      ]);
      await tester.pump();
      await tester.pump();
      final paragraph = tester.renderObject<RenderParagraph>(
        find
            .descendant(
              of: find.byType(QuillEditor),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is RichText &&
                    widget.text.toPlainText().startsWith("甲乙丙丁"),
              ),
            )
            .first,
      );
      void verify() {
        final boxes = paragraph.getBoxesForSelection(
          const TextSelection(baseOffset: 1, extentOffset: 100),
        );
        expect(boxes.length, greaterThan(1));
        for (var i = 0; i < boxes.length; i++) {
          final suffix = i == 0 ? "0" : "0-$i";
          final rect = tester.getRect(
            find.byKey(ValueKey("plain-text-quill-rhodanthe-$suffix")),
          );
          final expected = boxes[i].toRect();
          expect(rect.topLeft, paragraph.localToGlobal(expected.topLeft));
          expect(rect.size, expected.size);
        }
      }

      verify();
      final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
      expect(editor.scrollController.position.maxScrollExtent, greaterThan(40));
      editor.scrollController.jumpTo(40);
      await tester.pump();
      await tester.pump();
      verify();
    },
  );

  testWidgets("PoppinSense panel opens from Quill trigger input", (
    tester,
  ) async {
    final controller = HighlightTextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      buildEditor(controller: controller, focusNode: focusNode),
    );
    focusNode.requestFocus();
    quillControllerOf(
      tester,
    ).replaceText(0, 0, "/", const TextSelection.collapsed(offset: 1));
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>("mosaic-completion-panel")),
      findsOneWidget,
    );
  });
}
