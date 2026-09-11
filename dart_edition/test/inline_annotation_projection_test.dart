import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation_projection.dart";

void main() {
  test("projects escaped prose slashes and backslashes as one character", () {
    final projection = InlineAnnotationProjection.build(r"A\/B\\C");

    expect(projection.rawText, r"A\/B\\C");
    expect(projection.displayText, r"A/B\C");
    expect(projection.readerText, r"A/B\C");
    expect(projection.rawOffsetToDisplay(3), 2);
    expect(
      projection.displayRangeToRaw(const TextRange(start: 1, end: 2)),
      const TextRange(start: 1, end: 3),
    );
  });

  test("reader projection strips syntax, notes, and badge placeholders", () {
    const uuid = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";
    const raw = "她看見 //@+^CE<$uuid|艾莉絲>{主角}//。";

    expect(InlineAnnotationProjection.readerTextFromRaw(raw), "她看見 艾莉絲。");
  });

  const uuid = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";

  test("collapses valid annotations and preserves malformed source", () {
    const raw = "她看見 //@<$uuid|艾莉絲>{主角}//，以及 //^G<原文>//。";
    final projection = InlineAnnotationProjection.build(raw);

    expect(
      projection.displayText,
      "她看見 $inlineAnnotationPlaceholder艾莉絲，以及 //^G<原文>//。",
    );
    expect(projection.projectedAnnotations, hasLength(1));
  });

  test("maps collapsed edges with explicit affinities", () {
    const raw = "A//^<龍🐉>//Z";
    final projection = InlineAnnotationProjection.build(raw);
    final entry = projection.projectedAnnotations.single;
    final annotation = entry.annotation;

    expect(projection.displayText, "A$inlineAnnotationPlaceholder龍🐉Z");
    expect(
      projection.displayOffsetToRaw(entry.displayRange.start),
      annotation.sourceRange.start,
    );
    expect(
      projection.displayOffsetToRaw(entry.labelRange.start),
      annotation.displayTextSourceRange.start,
    );
    expect(
      projection.displayOffsetToRaw(
        entry.displayRange.start,
        affinity: MosaicOffsetAffinity.upstream,
      ),
      annotation.sourceRange.start,
    );
    expect(
      projection.displayOffsetToRaw(
        entry.displayRange.end,
        affinity: MosaicOffsetAffinity.upstream,
      ),
      annotation.displayTextSourceRange.end,
    );
    expect(
      projection.displayOffsetToRaw(entry.displayRange.end),
      annotation.sourceRange.end,
    );
  });

  test("remote raw offsets inside hidden syntax snap outside the label", () {
    const raw = "A//@<$uuid|艾莉絲>{主角}//Z";
    final projection = InlineAnnotationProjection.build(raw);
    final entry = projection.projectedAnnotations.single;

    final uuidOffset = raw.indexOf(uuid) + 5;
    final noteOffset = raw.indexOf("主角") + 1;
    expect(projection.rawOffsetToDisplay(uuidOffset), entry.labelRange.start);
    expect(projection.rawOffsetToDisplay(noteOffset), entry.labelRange.end);
  });

  test("whole display annotation range maps to complete raw syntax", () {
    const raw = "前//^<重點>//後";
    final projection = InlineAnnotationProjection.build(raw);
    final entry = projection.projectedAnnotations.single;

    expect(
      projection.displayRangeToRaw(entry.displayRange),
      entry.annotation.sourceRange,
    );
    expect(entry.badgeRange.end - entry.badgeRange.start, 1);
    expect(entry.labelRange.start, entry.badgeRange.end);
    expect(
      projection.displayRangeToRaw(entry.badgeRange),
      entry.annotation.sourceRange,
    );
    expect(
      projection.readerTextFor(
        TextRange(start: 0, end: projection.displayText.length),
      ),
      "前重點後",
    );
  });

  test("collapsed selections stay collapsed at annotation edges", () {
    const raw = "A//^<BC>//D";
    final projection = InlineAnnotationProjection.build(raw);
    final entry = projection.projectedAnnotations.single;

    for (final offset in [entry.displayRange.start, entry.displayRange.end]) {
      final mapped = projection.displaySelectionToRaw(
        TextSelection.collapsed(offset: offset),
      );
      expect(mapped.isCollapsed, isTrue);
      expect(projection.rawSelectionToDisplay(mapped).extentOffset, offset);
    }
  });

  test("partial display range maps only to display text", () {
    const raw = "//^<ABC>//";
    final projection = InlineAnnotationProjection.build(raw);
    final mapped = projection.displayRangeToRaw(
      TextRange(
        start: projection.projectedAnnotations.single.labelRange.start + 1,
        end: projection.projectedAnnotations.single.labelRange.start + 2,
      ),
    );

    expect(raw.substring(mapped.start, mapped.end), "B");
  });

  test("decodes escapes while retaining a stable UTF-16 map", () {
    const raw = r"x//^<A\|B\\C>//y";
    final projection = InlineAnnotationProjection.build(raw);
    final entry = projection.projectedAnnotations.single;

    expect(projection.displayText, "x${inlineAnnotationPlaceholder}A|B\\Cy");
    for (
      var display = entry.displayRange.start;
      display <= entry.displayRange.end;
      display++
    ) {
      final rawOffset = projection.displayOffsetToRaw(
        display,
        affinity: MosaicOffsetAffinity.upstream,
      );
      expect(projection.rawOffsetToDisplay(rawOffset), display);
    }
  });

  test("only explicit activation expands; composing keeps syntax hidden", () {
    const raw = "前//^<重點>{note}//後";
    final collapsed = InlineAnnotationProjection.build(raw);
    final annotation = collapsed.annotations.single;
    final active = InlineAnnotationProjection.build(
      raw,
      activeAnnotationStart: annotation.sourceRange.start,
    );
    final composing = InlineAnnotationProjection.build(
      raw,
      composingRawRange: annotation.displayTextSourceRange,
    );

    expect(active.displayText, raw);
    expect(active.projectedAnnotations.single.isExpanded, isTrue);
    expect(composing.displayText, "前$inlineAnnotationPlaceholder重點後");
    expect(composing.projectedAnnotations.single.isExpanded, isFalse);
  });

  test("does not hide an escape sequence while IME is composing it", () {
    final composing = InlineAnnotationProjection.build(
      r"文字\/",
      composingRawRange: const TextRange(start: 2, end: 4),
    );
    final committed = InlineAnnotationProjection.build(r"文字\/");

    expect(composing.displayText, r"文字\/");
    expect(composing.rawOffsetToDisplay(4), 4);
    expect(committed.displayText, "文字/");
    expect(committed.rawOffsetToDisplay(4), 3);
  });

  test("cross-annotation selections preserve direction", () {
    const raw = "a//^<甲>//b//^<乙>//c";
    final projection = InlineAnnotationProjection.build(raw);
    const displaySelection = TextSelection(baseOffset: 4, extentOffset: 1);
    final rawSelection = projection.displaySelectionToRaw(displaySelection);
    final roundTrip = projection.rawSelectionToDisplay(rawSelection);

    expect(roundTrip.baseOffset, displaySelection.baseOffset);
    expect(roundTrip.extentOffset, displaySelection.extentOffset);
  });
}
