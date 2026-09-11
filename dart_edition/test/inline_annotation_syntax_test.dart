import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation_parser.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation_syntax.dart";

void main() {
  const uuid = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";
  const parser = InlineAnnotationParser();

  test("formats a canonical semantic annotation and round-trips escapes", () {
    final source = InlineAnnotationSyntax.format(
      kind: InlineAnnotationKind.character,
      state: InlineAnnotationState.start,
      colors: const InlineAnnotationColorCode(background: "c", foreground: "e"),
      targetId: uuid.toUpperCase(),
      displayText: r"小|艾/莉\絲",
      note: "首次{登場}",
    );
    final annotation = parser.parse(source).single;

    expect(source, "//@+^CE<$uuid|小\\|艾\\/莉\\\\絲>{首次\\{登場\\}}//");
    expect(annotation.displayText, r"小|艾/莉\絲");
    expect(annotation.note, "首次{登場}");
  });

  test("uses compact default emphasis syntax", () {
    expect(
      InlineAnnotationSyntax.format(
        kind: InlineAnnotationKind.emphasis,
        displayText: "重點",
      ),
      "//^<重點>//",
    );
  });

  test("rejects semantic annotations without a valid UUID", () {
    expect(
      () => InlineAnnotationSyntax.format(
        kind: InlineAnnotationKind.location,
        displayText: "教堂",
      ),
      throwsFormatException,
    );
  });

  test("rejects state on emphasis", () {
    expect(
      () => InlineAnnotationSyntax.format(
        kind: InlineAnnotationKind.emphasis,
        state: InlineAnnotationState.start,
        displayText: "重點",
      ),
      throwsFormatException,
    );
  });
}
