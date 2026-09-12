import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/inline_annotations/mosaic_editing_controller.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation_projection.dart";

void main() {
  test("stores raw syntax while exposing collapsed text to CodeField", () {
    final controller = MosaicEditingController(rawText: "前//^<重點>//後");
    addTearDown(controller.dispose);

    expect(controller.rawText, "前//^<重點>//後");
    expect(controller.text, "前$inlineAnnotationPlaceholder重點後");
  });

  test("editing ordinary projected text updates raw text", () {
    final controller = MosaicEditingController(rawText: "前//^<重點>//後");
    addTearDown(controller.dispose);

    controller.value = const TextEditingValue(
      text: "序前$inlineAnnotationPlaceholder重點後",
      selection: TextSelection.collapsed(offset: 1),
    );

    expect(controller.rawText, "序前//^<重點>//後");
    expect(controller.rawRevision, 1);
  });

  test("deleting a projected annotation removes full raw syntax", () {
    final controller = MosaicEditingController(rawText: "前//^<重點>//後");
    addTearDown(controller.dispose);

    controller.value = const TextEditingValue(
      text: "前後",
      selection: TextSelection.collapsed(offset: 1),
    );

    expect(controller.rawText, "前後");
  });

  test("inserting at a collapsed leading edge edits display text", () {
    final controller = MosaicEditingController(rawText: "前//^<重點>//後");
    addTearDown(controller.dispose);

    controller.value = const TextEditingValue(
      text: "前$inlineAnnotationPlaceholder新重點後",
      selection: TextSelection.collapsed(offset: 3),
    );

    expect(controller.rawText, "前//^<新重點>//後");
    expect(controller.text, "前$inlineAnnotationPlaceholder新重點後");
  });

  test("moving caret into a Mention keeps raw syntax hidden", () async {
    final controller = MosaicEditingController(rawText: "前//^<重點>//後");
    addTearDown(controller.dispose);

    controller.selection = const TextSelection.collapsed(offset: 3);
    await Future<void>.delayed(Duration.zero);

    expect(controller.text, "前$inlineAnnotationPlaceholder重點後");
    expect(controller.activeAnnotationStart, isNull);
    expect(controller.presentationRevision, 0);
  });

  test("projection cache only rebuilds when raw text changes", () {
    final controller = MosaicEditingController(rawText: "前//^<重點>//後");
    addTearDown(controller.dispose);
    final initialProjection = controller.projection;

    controller.selection = const TextSelection.collapsed(offset: 2);
    expect(identical(controller.projection, initialProjection), isTrue);

    controller.setRawText(
      "前//^<重點>//後",
      rawSelection: const TextSelection.collapsed(offset: 1),
    );
    expect(identical(controller.projection, initialProjection), isTrue);
    expect(controller.rawRevision, 0);

    controller.setRawText("新前//^<重點>//後");
    expect(identical(controller.projection, initialProjection), isFalse);
    expect(controller.rawRevision, 1);
  });

  test("plain copy omits the placeholder, UUID, and note", () {
    const uuid = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";
    final controller = MosaicEditingController(
      rawText: "前//@<$uuid|艾莉絲>{主角}//後",
    );
    addTearDown(controller.dispose);
    final entry = controller.projection.projectedAnnotations.single;

    expect(
      controller.plainTextForSelection(
        TextSelection(
          baseOffset: entry.displayRange.start,
          extentOffset: entry.displayRange.end,
        ),
      ),
      "艾莉絲",
    );
  });

  test("atomic Mention navigation and deletion use its full display range", () {
    const uuid = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";
    final controller = MosaicEditingController(rawText: "A//@<$uuid|艾莉絲>//B");
    addTearDown(controller.dispose);
    var entry = controller.projection.projectedAnnotations.single;

    expect(
      controller.atomicNavigationTarget(entry.displayRange.start, 1),
      entry.displayRange.end,
    );
    expect(
      controller.atomicNavigationTarget(entry.displayRange.end, -1),
      entry.displayRange.start,
    );
    expect(
      controller.deleteAtomicAnnotationAt(
        entry.displayRange.end,
        backward: true,
      ),
      isTrue,
    );
    expect(controller.rawText, "AB");

    controller.setRawText("A//@<$uuid|艾莉絲>//B");
    entry = controller.projection.projectedAnnotations.single;
    expect(
      controller.deleteAtomicAnnotationAt(
        entry.displayRange.start,
        backward: false,
      ),
      isTrue,
    );
    expect(controller.rawText, "AB");
  });

  test("IME commit folds an escape even when committed text is unchanged", () {
    final controller = MosaicEditingController();
    addTearDown(controller.dispose);

    controller.value = const TextEditingValue(
      text: r"\/",
      selection: TextSelection.collapsed(offset: 2),
      composing: TextRange(start: 0, end: 2),
    );

    expect(controller.rawText, isEmpty);
    expect(controller.displayText, r"\/");
    expect(controller.value.composing, const TextRange(start: 0, end: 2));

    controller.value = controller.value.copyWith(composing: TextRange.empty);

    expect(controller.rawText, r"\/");
    expect(controller.displayText, "/");
    expect(controller.selection, const TextSelection.collapsed(offset: 1));
    expect(controller.value.composing, TextRange.empty);
  });

  test("IME intermediate replacements are committed to raw text once", () {
    final controller = MosaicEditingController(rawText: "前//^<重點>//後");
    addTearDown(controller.dispose);
    final baseDisplay = controller.displayText;
    final insertionOffset = baseDisplay.indexOf("前") + 1;

    controller.value = TextEditingValue(
      text: baseDisplay.replaceRange(insertionOffset, insertionOffset, "n"),
      selection: TextSelection.collapsed(offset: insertionOffset + 1),
      composing: TextRange(start: insertionOffset, end: insertionOffset + 1),
    );
    expect(controller.rawText, "前//^<重點>//後");
    expect(controller.rawRevision, 0);

    controller.value = TextEditingValue(
      text: baseDisplay.replaceRange(insertionOffset, insertionOffset, "ni"),
      selection: TextSelection.collapsed(offset: insertionOffset + 2),
      composing: TextRange(start: insertionOffset, end: insertionOffset + 2),
    );
    expect(controller.rawText, "前//^<重點>//後");
    expect(controller.rawRevision, 0);

    controller.value = TextEditingValue(
      text: baseDisplay.replaceRange(insertionOffset, insertionOffset, "你"),
      selection: TextSelection.collapsed(offset: insertionOffset + 1),
    );
    expect(controller.rawText, "前你//^<重點>//後");
    expect(controller.displayText, "前你$inlineAnnotationPlaceholder重點後");
    expect(controller.rawRevision, 1);
  });
}
