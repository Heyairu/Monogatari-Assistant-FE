import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

import "package:monogatari_assistant/bin/findreplace.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation_projection.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    "HighlightTextEditingController prioritizes current search over other matches",
    (tester) async {
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

      final controller = HighlightTextEditingController(text: "abcd");
      controller.updateSearchHighlights(
        matches: const [
          TextSelection(baseOffset: 0, extentOffset: 1),
          TextSelection(baseOffset: 2, extentOffset: 3),
        ],
        currentIndex: 1,
      );
      controller.updatePunctuationHighlights(
        matches: const [TextSelection(baseOffset: 1, extentOffset: 2)],
      );
      controller.updateFillerHighlights(
        matches: const [TextSelection(baseOffset: 3, extentOffset: 4)],
      );

      final span = controller.buildTextSpan(
        context: context!,
        style: const TextStyle(fontSize: 14),
      );

      expect(span.children, isNotNull);
      final children = span.children!.cast<TextSpan>();
      expect(children.length, 4);
      expect(children.map((child) => child.text).toList(), [
        "a",
        "b",
        "c",
        "d",
      ]);

      expect(children[0].style?.color, controller.otherMatchColor);
      expect(children[1].style?.color, controller.punctuationColor);
      expect(children[2].style?.color, controller.currentMatchColor);
      expect(children[3].style?.color, controller.fillerWordColor);
    },
  );

  testWidgets(
    "HighlightTextEditingController returns plain text when no highlights exist",
    (tester) async {
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

      final controller = HighlightTextEditingController(text: "plain text");
      final span = controller.buildTextSpan(
        context: context!,
        style: const TextStyle(fontSize: 14),
      );

      expect(span.text, "plain text");
      expect(span.children, isNull);
    },
  );

  testWidgets("search color overrides Mosaic foreground but keeps background", (
    tester,
  ) async {
    late BuildContext context;
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

    const uuid = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";
    const raw = "A //@^CE<$uuid|艾莉絲>{secret}// B";
    final controller = HighlightTextEditingController(text: raw);
    addTearDown(controller.dispose);
    controller.updateSearchHighlights(
      matches: const [TextSelection(baseOffset: 3, extentOffset: 6)],
      currentIndex: 0,
    );

    final span = controller.buildTextSpan(context: context);
    final label = span.children!.cast<TextSpan>().singleWhere(
      (child) => child.text == "艾莉絲",
    );

    expect(controller.text, "A $inlineAnnotationPlaceholder艾莉絲 B");
    expect(controller.rawText, raw);
    expect(label.style?.color, controller.currentMatchColor);
    expect(label.style?.backgroundColor, isNotNull);
  });
}
