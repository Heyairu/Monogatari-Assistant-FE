import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation_palette.dart";
import "package:monogatari_assistant/features/inline_annotations/mosaic_editing_controller.dart";

void main() {
  test("palette keeps automatic channels unset", () {
    final style = InlineAnnotationPalette.light.styleFor(
      const InlineAnnotationColorCode(background: "B", foreground: "0"),
    );

    expect(
      style.backgroundColor,
      InlineAnnotationPalette.light.backgrounds["B"],
    );
    expect(style.color, isNull);
  });

  testWidgets("controller styles only projected display text", (tester) async {
    final controller = MosaicEditingController(
      rawText: "前//^<藍色>//中//^CE<雙色>//後",
    );
    addTearDown(controller.dispose);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );

    final span = controller.buildTextSpan(
      context: context,
      style: const TextStyle(fontSize: 16),
    );
    final children = span.children!.cast<TextSpan>();
    final blue = children.singleWhere((item) => item.text == "藍色");
    final dual = children.singleWhere((item) => item.text == "雙色");

    expect(
      blue.style!.backgroundColor,
      InlineAnnotationPalette.light.backgrounds["B"],
    );
    expect(blue.style!.color, isNull);
    expect(
      dual.style!.backgroundColor,
      InlineAnnotationPalette.light.backgrounds["C"],
    );
    expect(dual.style!.color, InlineAnnotationPalette.light.foregrounds["E"]);
  });

  testWidgets("high contrast palette is selected from MediaQuery", (
    tester,
  ) async {
    final controller = MosaicEditingController(rawText: "//^A<重點>//");
    addTearDown(controller.dispose);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(highContrast: true),
          child: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    final span = controller.buildTextSpan(context: context);
    final highlighted = span.children!.cast<TextSpan>().singleWhere(
      (item) => item.text == "重點",
    );
    expect(
      highlighted.style!.backgroundColor,
      InlineAnnotationPalette.highContrast.backgrounds["A"],
    );
  });
}
