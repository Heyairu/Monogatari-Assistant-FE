import "package:code_text_field/code_text_field.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/inline_annotations/mosaic_editing_controller.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation_projection.dart";

void main() {
  Widget buildEditor(MosaicEditingController controller, FocusNode focusNode) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 600,
          height: 300,
          child: CodeField(
            controller: controller,
            focusNode: focusNode,
            lineNumbers: false,
            wrap: true,
          ),
        ),
      ),
    );
  }

  testWidgets("CodeField paints collapsed projection and accepts plain edits", (
    tester,
  ) async {
    final controller = MosaicEditingController(rawText: "前 //^<重點>//後");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(buildEditor(controller, focusNode));
    await tester.showKeyboard(find.byType(EditableText));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
    expect(controller.text, "前 $inlineAnnotationPlaceholder重點後");

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: "前文 $inlineAnnotationPlaceholder重點後",
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    await tester.pump();

    expect(controller.rawText, "前文 //^<重點>//後");
    expect(controller.text, "前文 $inlineAnnotationPlaceholder重點後");
    expect(tester.takeException(), isNull);
  });

  testWidgets("Chinese IME composing before annotation remains aligned", (
    tester,
  ) async {
    final controller = MosaicEditingController(rawText: "前 //^<重點>//後");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(buildEditor(controller, focusNode));
    await tester.showKeyboard(find.byType(EditableText));
    await tester.pump();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: "前中文 $inlineAnnotationPlaceholder重點後",
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 1, end: 3),
      ),
    );
    await tester.pump();

    expect(controller.rawText, "前 //^<重點>//後");
    expect(controller.text, "前中文 $inlineAnnotationPlaceholder重點後");
    expect(controller.value.composing, const TextRange(start: 1, end: 3));
    expect(controller.selection.extentOffset, 3);
    expect(tester.takeException(), isNull);

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: "前中文 $inlineAnnotationPlaceholder重點後",
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    await tester.pump();

    expect(controller.rawText, "前中文 //^<重點>//後");
    expect(controller.value.composing, TextRange.empty);
  });

  testWidgets("caret inside label keeps syntax hidden", (tester) async {
    final controller = MosaicEditingController(rawText: "//^<甲>//與//^<乙>//");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(buildEditor(controller, focusNode));
    controller.selection = const TextSelection.collapsed(offset: 1);
    await tester.pump();

    expect(
      controller.text,
      "$inlineAnnotationPlaceholder甲與$inlineAnnotationPlaceholder乙",
    );
    expect(
      controller.projection.projectedAnnotations.where(
        (entry) => entry.isExpanded,
      ),
      isEmpty,
    );
    expect(controller.selection.isCollapsed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets("IME composing inside hidden label updates raw syntax", (
    tester,
  ) async {
    final controller = MosaicEditingController(rawText: "前//^<重點>//後");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(buildEditor(controller, focusNode));
    await tester.showKeyboard(find.byType(EditableText));
    controller.selection = const TextSelection.collapsed(offset: 3);
    await tester.pump();

    final insertionOffset =
        controller.projection.projectedAnnotations.single.labelRange.start + 1;
    final projected = controller.text;
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: projected.replaceRange(insertionOffset, insertionOffset, "中"),
        selection: TextSelection.collapsed(offset: insertionOffset + 1),
        composing: TextRange(start: insertionOffset, end: insertionOffset + 1),
      ),
    );
    await tester.pump();

    expect(controller.rawText, "前//^<重點>//後");
    expect(controller.text, "前$inlineAnnotationPlaceholder重中點後");
    expect(controller.value.composing.isValid, isTrue);
    expect(tester.takeException(), isNull);

    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: projected.replaceRange(insertionOffset, insertionOffset, "中"),
        selection: TextSelection.collapsed(offset: insertionOffset + 1),
      ),
    );
    await tester.pump();

    expect(controller.rawText, "前//^<重中點>//後");
    expect(controller.value.composing, TextRange.empty);
  });
}
