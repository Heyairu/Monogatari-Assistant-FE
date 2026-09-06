import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_annotations.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_protocol.dart";

void main() {
  test("resolved and unresolved mentions emit Ring 4 semantic annotations", () {
    const resolved = RhodantheMention(
      mentionId: "m1",
      targetId: "character:alice",
      range: RhodantheRange(2, 7),
    );
    const unresolved = RhodantheMention(
      mentionId: "m2",
      targetId: "character:missing",
      range: RhodantheRange(8, 12),
      resolution: RhodantheMentionResolution.unresolved,
    );

    final resolvedAnnotation = resolved.toAnnotation(sourceOrder: 0);
    final unresolvedAnnotation = unresolved.toAnnotation(sourceOrder: 1);
    expect(resolvedAnnotation.ring, 4);
    expect(resolvedAnnotation.style.weight, "medium");
    expect(resolvedAnnotation.style.interaction, "mention:m1");
    expect(resolvedAnnotation.payloadId, "character:alice");
    expect(unresolvedAnnotation.style.decoration!.style, "dashed");
    expect(
      unresolvedAnnotation.style.foreground,
      "mention.unresolved.foreground",
    );
  });

  test("detach policy removes a mention touched by an edit", () {
    const mention = RhodantheMention(
      mentionId: "m1",
      targetId: "alice",
      range: RhodantheRange(3, 8),
    );
    const edit = RhodantheTextEdit(
      startUtf16: 4,
      endUtf16: 5,
      replacement: "X",
    );
    expect(mention.rebase(edit), isNull);
  });

  test("expand policy includes replacement text and shifts trailing edge", () {
    const mention = RhodantheMention(
      mentionId: "m1",
      targetId: "alice",
      range: RhodantheRange(3, 8),
      anchorPolicy: RhodantheMentionAnchorPolicy.expand,
    );
    const edit = RhodantheTextEdit(
      startUtf16: 5,
      endUtf16: 6,
      replacement: "long",
    );
    final rebased = mention.rebase(edit)!;
    expect(rebased.range.start, 3);
    expect(rebased.range.end, 11);
  });

  test("shrink policy preserves the larger untouched side", () {
    const mention = RhodantheMention(
      mentionId: "m1",
      targetId: "alice",
      range: RhodantheRange(2, 12),
      anchorPolicy: RhodantheMentionAnchorPolicy.shrink,
    );
    const edit = RhodantheTextEdit(
      startUtf16: 4,
      endUtf16: 7,
      replacement: "x",
    );
    final rebased = mention.rebase(edit)!;
    expect(rebased.range.start, 5);
    expect(rebased.range.end, 10);
  });

  test("edits before an anchor shift it without changing its length", () {
    const mention = RhodantheMention(
      mentionId: "m1",
      targetId: "alice",
      range: RhodantheRange(5, 9),
    );
    const edit = RhodantheTextEdit(
      startUtf16: 1,
      endUtf16: 2,
      replacement: "long",
    );
    final rebased = mention.rebase(edit)!;
    expect(rebased.range.start, 8);
    expect(rebased.range.end, 12);
  });

  test("diagnostics emit dotted Ring 8 decoration", () {
    const diagnostic = RhodantheDiagnostic(
      diagnosticId: "punctuation:1",
      range: RhodantheRange(4, 5),
    );
    final annotation = diagnostic.toAnnotation(sourceOrder: 2);
    expect(annotation.ring, 8);
    expect(annotation.style.decoration!.style, "dotted");
    expect(annotation.style.decoration!.color, "diagnostic.decoration");
  });

  test("mention document storage round-trips its versioned anchor model", () {
    final document = RhodantheMentionDocument(
      documentId: "chapter",
      mentions: const <RhodantheMention>[
        RhodantheMention(
          mentionId: "m1",
          targetId: "alice",
          range: RhodantheRange(1, 6),
          anchorPolicy: RhodantheMentionAnchorPolicy.expand,
        ),
      ],
    );

    final decoded = RhodantheMentionDocument.decode(document.encode());
    expect(decoded.documentId, "chapter");
    expect(decoded.mentions.single.mentionId, "m1");
    expect(
      decoded.mentions.single.anchorPolicy,
      RhodantheMentionAnchorPolicy.expand,
    );
    expect(decoded.toAnnotations().single.ring, 4);
  });
}
