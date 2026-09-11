import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation_parser.dart";

void main() {
  const parser = InlineAnnotationParser();
  const uuid = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";

  test("parses kind, state, colors, UUID, display text and note", () {
    const source = "前//@-^af<$uuid|小\\|艾>{離開\\}隊伍}//後";
    final annotation = parser.parse(source).single;

    expect(annotation.kind, InlineAnnotationKind.character);
    expect(annotation.state, InlineAnnotationState.end);
    expect(annotation.colors.value, "AF");
    expect(annotation.targetId, uuid);
    expect(annotation.displayText, "小|艾");
    expect(annotation.note, "離開}隊伍");
    expect(
      source.substring(
        annotation.sourceRange.start,
        annotation.sourceRange.end,
      ),
      "//@-^af<$uuid|小\\|艾>{離開\\}隊伍}//",
    );
  });

  test("normalizes emphasis default and one/two-channel colors", () {
    final annotations = parser.parse("//^<預設>// //^c<單色>// //^CE<雙色>//");

    expect(annotations.map((item) => item.colors.value), ["B0", "C0", "CE"]);
    expect(annotations.map((item) => item.kind).toSet(), {
      InlineAnnotationKind.emphasis,
    });
  });

  test("reports missing targets without invalidating syntax", () {
    final annotation = parser
        .parse("//!<$uuid|舊教堂>//", targetExists: (_, _) => false)
        .single;

    expect(annotation.targetStatus, InlineAnnotationTargetStatus.missing);
  });

  test("keeps malformed syntax visible and recovers later", () {
    const source = "//^G<非法>//正文 //^<合法>// 尾端//@<未完成";
    final annotations = parser.parse(source);

    expect(annotations, hasLength(1));
    expect(annotations.single.displayText, "合法");
  });

  test("rejects missing or malformed semantic UUID", () {
    expect(parser.parse("//@<艾莉絲>//"), isEmpty);
    expect(parser.parse("//@<not-a-uuid|艾莉絲>//"), isEmpty);
  });

  test("escaped opening delimiter is ordinary text", () {
    expect(parser.parse(r"\//^<不是標記>//"), isEmpty);
  });

  test("ranges use UTF-16 offsets around emoji", () {
    const source = "😀前//^<龍🐉>//後";
    final annotation = parser.parse(source).single;

    expect(annotation.sourceRange.start, "😀前".length);
    expect(annotation.displayText, "龍🐉");
    expect(annotation.displayText.length, 3);
    expect(
      annotation.displayTextSourceRange.end -
          annotation.displayTextSourceRange.start,
      3,
    );
  });
}
