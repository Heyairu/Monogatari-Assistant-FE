/*
 * Copyright 2025-2026 Heyairu（部屋伊琉）
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 ************************************************************/

import "package:flutter/services.dart";

import "inline_annotation.dart";
import "inline_annotation_parser.dart";

enum MosaicOffsetAffinity { upstream, downstream }

/// One UTF-16 object slot reserved for the painted annotation-kind badge.
const inlineAnnotationPlaceholder = "\uFFFC";

final class ProjectedInlineAnnotation {
  final InlineAnnotation annotation;
  final TextRange displayRange;
  final TextRange badgeRange;
  final TextRange labelRange;
  final bool isExpanded;

  const ProjectedInlineAnnotation({
    required this.annotation,
    required this.displayRange,
    required this.badgeRange,
    required this.labelRange,
    required this.isExpanded,
  });
}

/// Immutable raw/display projection. Every offset is a UTF-16 offset.
final class InlineAnnotationProjection {
  final String rawText;
  final String displayText;
  final List<InlineAnnotation> annotations;
  final List<ProjectedInlineAnnotation> projectedAnnotations;
  final List<int> _rawToDisplay;
  final List<int> _displayToRawUpstream;
  final List<int> _displayToRawDownstream;

  const InlineAnnotationProjection._({
    required this.rawText,
    required this.displayText,
    required this.annotations,
    required this.projectedAnnotations,
    required List<int> rawToDisplay,
    required List<int> displayToRawUpstream,
    required List<int> displayToRawDownstream,
  }) : _rawToDisplay = rawToDisplay,
       _displayToRawUpstream = displayToRawUpstream,
       _displayToRawDownstream = displayToRawDownstream;

  factory InlineAnnotationProjection.build(
    String rawText, {
    List<InlineAnnotation>? annotations,
    InlineAnnotationParser parser = const InlineAnnotationParser(),
    int? activeAnnotationStart,
    TextRange composingRawRange = TextRange.empty,
  }) {
    final parsed = annotations ?? parser.parse(rawText);
    final output = StringBuffer();
    final rawToDisplay = List<int>.filled(rawText.length + 1, 0);
    final upstream = <int>[0];
    final downstream = <int>[0];
    final entries = <ProjectedInlineAnnotation>[];
    var rawCursor = 0;
    var displayCursor = 0;
    final hasComposingRange =
        composingRawRange.isValid && !composingRawRange.isCollapsed;

    bool intersectsComposing(int start, int end) =>
        hasComposingRange &&
        start < composingRawRange.end &&
        end > composingRawRange.start;

    void appendLiteral(int start, int end) {
      var raw = start;
      while (raw < end) {
        rawToDisplay[raw] = displayCursor;
        final unit = rawText.codeUnitAt(raw);
        if (unit == 0x5c &&
            raw + 1 < end &&
            !intersectsComposing(raw, raw + 2) &&
            (rawText.codeUnitAt(raw + 1) == 0x2f ||
                rawText.codeUnitAt(raw + 1) == 0x5c)) {
          rawToDisplay[raw + 1] = displayCursor;
          output.writeCharCode(rawText.codeUnitAt(raw + 1));
          raw += 2;
        } else {
          output.writeCharCode(unit);
          raw++;
        }
        displayCursor++;
        upstream.add(raw);
        downstream.add(raw);
        rawToDisplay[raw] = displayCursor;
      }
    }

    for (final annotation in parsed) {
      if (annotation.sourceRange.start < rawCursor ||
          annotation.sourceRange.end > rawText.length) {
        continue;
      }
      appendLiteral(rawCursor, annotation.sourceRange.start);

      final composingTouchesHiddenSyntax =
          intersectsComposing(
            annotation.sourceRange.start,
            annotation.sourceRange.end,
          ) &&
          !(composingRawRange.start >=
                  annotation.displayTextSourceRange.start &&
              composingRawRange.end <= annotation.displayTextSourceRange.end);
      final isExpanded =
          annotation.sourceRange.start == activeAnnotationStart ||
          composingTouchesHiddenSyntax;
      final projectedStart = displayCursor;
      late final TextRange badgeRange;
      late final TextRange labelRange;

      if (isExpanded) {
        appendLiteral(annotation.sourceRange.start, annotation.sourceRange.end);
        badgeRange = TextRange.collapsed(projectedStart);
        labelRange = TextRange(
          start: rawToDisplay[annotation.displayTextSourceRange.start],
          end: rawToDisplay[annotation.displayTextSourceRange.end],
        );
      } else {
        final rawDisplay = annotation.displayTextSourceRange;
        rawToDisplay[annotation.sourceRange.start] = displayCursor;
        upstream[displayCursor] = annotation.sourceRange.start;
        downstream[displayCursor] = annotation.sourceRange.start;
        output.write(inlineAnnotationPlaceholder);
        displayCursor++;
        upstream.add(annotation.sourceRange.start);
        downstream.add(rawDisplay.start);
        badgeRange = TextRange(start: projectedStart, end: displayCursor);
        for (
          var raw = annotation.sourceRange.start + 1;
          raw <= rawDisplay.start;
          raw++
        ) {
          rawToDisplay[raw] = displayCursor;
        }

        // The badge owns the annotation boundary; the following caret enters
        // the editable display label from either affinity.
        upstream[displayCursor] = rawDisplay.start;
        downstream[displayCursor] = rawDisplay.start;

        final labelStart = displayCursor;
        var raw = rawDisplay.start;
        while (raw < rawDisplay.end) {
          rawToDisplay[raw] = displayCursor;
          final unit = rawText.codeUnitAt(raw);
          if (unit == 0x5c &&
              raw + 1 < rawDisplay.end &&
              !intersectsComposing(raw, raw + 2) &&
              _isEscapable(rawText.codeUnitAt(raw + 1))) {
            rawToDisplay[raw + 1] = displayCursor;
            output.writeCharCode(rawText.codeUnitAt(raw + 1));
            displayCursor++;
            raw += 2;
          } else {
            output.writeCharCode(unit);
            displayCursor++;
            raw++;
          }
          rawToDisplay[raw] = displayCursor;
          upstream.add(raw);
          downstream.add(raw);
        }

        for (
          var hidden = rawDisplay.end;
          hidden <= annotation.sourceRange.end;
          hidden++
        ) {
          rawToDisplay[hidden] = displayCursor;
        }
        upstream[displayCursor] = rawDisplay.end;
        downstream[displayCursor] = annotation.sourceRange.end;
        labelRange = TextRange(start: labelStart, end: displayCursor);
      }

      entries.add(
        ProjectedInlineAnnotation(
          annotation: annotation,
          displayRange: TextRange(start: projectedStart, end: displayCursor),
          badgeRange: badgeRange,
          labelRange: labelRange,
          isExpanded: isExpanded,
        ),
      );
      rawCursor = annotation.sourceRange.end;
    }

    appendLiteral(rawCursor, rawText.length);
    return InlineAnnotationProjection._(
      rawText: rawText,
      displayText: output.toString(),
      annotations: List<InlineAnnotation>.unmodifiable(parsed),
      projectedAnnotations: List<ProjectedInlineAnnotation>.unmodifiable(
        entries,
      ),
      rawToDisplay: List<int>.unmodifiable(rawToDisplay),
      displayToRawUpstream: List<int>.unmodifiable(upstream),
      displayToRawDownstream: List<int>.unmodifiable(downstream),
    );
  }

  int rawOffsetToDisplay(int rawOffset) {
    return _rawToDisplay[rawOffset.clamp(0, rawText.length)];
  }

  int displayOffsetToRaw(
    int displayOffset, {
    MosaicOffsetAffinity affinity = MosaicOffsetAffinity.downstream,
  }) {
    final offset = displayOffset.clamp(0, displayText.length);
    return affinity == MosaicOffsetAffinity.upstream
        ? _displayToRawUpstream[offset]
        : _displayToRawDownstream[offset];
  }

  TextSelection rawSelectionToDisplay(TextSelection selection) {
    return TextSelection(
      baseOffset: rawOffsetToDisplay(selection.baseOffset),
      extentOffset: rawOffsetToDisplay(selection.extentOffset),
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );
  }

  TextSelection displaySelectionToRaw(TextSelection selection) {
    if (selection.isCollapsed) {
      final displayOffset = selection.extentOffset.clamp(0, displayText.length);
      var rawOffset = displayOffsetToRaw(displayOffset);
      for (final entry in projectedAnnotations) {
        if (entry.isExpanded) continue;
        if (displayOffset == entry.displayRange.start) {
          rawOffset = entry.annotation.sourceRange.start;
          break;
        }
        if (displayOffset == entry.labelRange.start) {
          rawOffset = entry.annotation.displayTextSourceRange.start;
          break;
        }
        if (displayOffset == entry.displayRange.end) {
          rawOffset = entry.annotation.displayTextSourceRange.end;
          break;
        }
      }
      return TextSelection.collapsed(
        offset: rawOffset,
        affinity: selection.affinity,
      );
    }
    final isForward = selection.baseOffset <= selection.extentOffset;
    final baseAffinity = isForward
        ? MosaicOffsetAffinity.downstream
        : MosaicOffsetAffinity.upstream;
    final extentAffinity = isForward
        ? MosaicOffsetAffinity.upstream
        : MosaicOffsetAffinity.downstream;
    return TextSelection(
      baseOffset: displayOffsetToRaw(
        selection.baseOffset,
        affinity: baseAffinity,
      ),
      extentOffset: displayOffsetToRaw(
        selection.extentOffset,
        affinity: extentAffinity,
      ),
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );
  }

  TextRange displayRangeToRaw(TextRange range) {
    if (range.isCollapsed) {
      final selection = displaySelectionToRaw(
        TextSelection.collapsed(offset: range.start),
      );
      return TextRange.collapsed(selection.extentOffset);
    }
    var start = displayOffsetToRaw(
      range.start,
      affinity: MosaicOffsetAffinity.downstream,
    );
    var end = displayOffsetToRaw(
      range.end,
      affinity: MosaicOffsetAffinity.upstream,
    );
    for (final entry in projectedAnnotations) {
      if (!entry.isExpanded &&
          ((range.start <= entry.displayRange.start &&
                  range.end >= entry.displayRange.end) ||
              (range.start <= entry.badgeRange.start &&
                  range.end >= entry.badgeRange.end) ||
              (range.start <= entry.labelRange.start &&
                  range.end >= entry.labelRange.end))) {
        start = start.clamp(0, entry.annotation.sourceRange.start);
        end = end.clamp(entry.annotation.sourceRange.end, rawText.length);
      }
    }
    return TextRange(start: start, end: end);
  }

  String displayTextFor(TextRange range) {
    final start = range.start.clamp(0, displayText.length);
    final end = range.end.clamp(start, displayText.length);
    return displayText.substring(start, end);
  }

  /// Reader-facing text with annotation syntax and badge placeholders removed.
  String get readerText =>
      readerTextFor(TextRange(start: 0, end: displayText.length));

  static String readerTextFromRaw(String rawText) =>
      InlineAnnotationProjection.build(rawText).readerText;

  String readerTextFor(TextRange range) {
    final start = range.start.clamp(0, displayText.length);
    final end = range.end.clamp(start, displayText.length);
    final output = StringBuffer();
    var cursor = start;
    for (final entry in projectedAnnotations) {
      if (entry.isExpanded ||
          entry.badgeRange.end <= start ||
          entry.badgeRange.start >= end) {
        continue;
      }
      final badgeStart = entry.badgeRange.start.clamp(start, end);
      final badgeEnd = entry.badgeRange.end.clamp(start, end);
      if (cursor < badgeStart) {
        output.write(displayText.substring(cursor, badgeStart));
      }
      cursor = badgeEnd;
    }
    if (cursor < end) {
      output.write(displayText.substring(cursor, end));
    }
    return output.toString();
  }

  ProjectedInlineAnnotation? annotationAtDisplayOffset(int offset) {
    for (final entry in projectedAnnotations) {
      if (offset >= entry.displayRange.start &&
          offset <= entry.displayRange.end) {
        return entry;
      }
    }
    return null;
  }

  static bool _isEscapable(int unit) {
    return unit == 0x5c ||
        unit == 0x3c ||
        unit == 0x3e ||
        unit == 0x7b ||
        unit == 0x7d ||
        unit == 0x7c ||
        unit == 0x2f;
  }
}
