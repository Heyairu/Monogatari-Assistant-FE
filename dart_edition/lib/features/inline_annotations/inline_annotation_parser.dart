/*
 * Copyright 2025-2026 Heyairu（部屋伊琉）
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 ************************************************************/

import "package:flutter/services.dart";

import "inline_annotation.dart";

typedef InlineAnnotationTargetExists =
    bool Function(InlineAnnotationKind kind, String targetId);

/// Single-pass, recovery-oriented parser for MonoAshi Mosaic annotations.
///
/// Invalid and unfinished annotations are omitted from the result, so their
/// source remains ordinary visible text in the projection.
final class InlineAnnotationParser {
  const InlineAnnotationParser();

  List<InlineAnnotation> parse(
    String source, {
    InlineAnnotationTargetExists? targetExists,
  }) {
    final annotations = <InlineAnnotation>[];
    var cursor = 0;

    while (cursor + 1 < source.length) {
      if (source.codeUnitAt(cursor) != 0x2f ||
          source.codeUnitAt(cursor + 1) != 0x2f ||
          _isEscaped(source, cursor)) {
        cursor++;
        continue;
      }

      final parsed = _tryParseAt(source, cursor, targetExists: targetExists);
      if (parsed == null) {
        cursor += 2;
        continue;
      }

      annotations.add(parsed);
      cursor = parsed.sourceRange.end;
    }

    return List<InlineAnnotation>.unmodifiable(annotations);
  }

  InlineAnnotation? _tryParseAt(
    String source,
    int start, {
    InlineAnnotationTargetExists? targetExists,
  }) {
    var cursor = start + 2;
    if (cursor >= source.length) return null;

    final kind = _kindFor(source.codeUnitAt(cursor));
    final InlineAnnotationKind parsedKind;
    if (kind != null) {
      parsedKind = kind;
      cursor++;
    } else if (source.codeUnitAt(cursor) == 0x5e) {
      parsedKind = InlineAnnotationKind.emphasis;
    } else {
      return null;
    }

    var state = InlineAnnotationState.none;
    if (parsedKind != InlineAnnotationKind.emphasis && cursor < source.length) {
      final stateUnit = source.codeUnitAt(cursor);
      if (stateUnit == 0x2b || stateUnit == 0x2d) {
        state = stateUnit == 0x2b
            ? InlineAnnotationState.start
            : InlineAnnotationState.end;
        cursor++;
      }
    }

    var colors = const InlineAnnotationColorCode(
      background: "B",
      foreground: "0",
    );
    if (cursor < source.length && source.codeUnitAt(cursor) == 0x5e) {
      cursor++;
      final colorStart = cursor;
      while (cursor < source.length && _isColor(source.codeUnitAt(cursor))) {
        cursor++;
      }
      final colorLength = cursor - colorStart;
      if (colorLength > 2 ||
          cursor >= source.length ||
          source.codeUnitAt(cursor) != 0x3c) {
        return null;
      }
      if (colorLength == 1) {
        colors = InlineAnnotationColorCode(
          background: source[colorStart].toUpperCase(),
          foreground: "0",
        );
      } else if (colorLength == 2) {
        colors = InlineAnnotationColorCode(
          background: source[colorStart].toUpperCase(),
          foreground: source[colorStart + 1].toUpperCase(),
        );
      }
    } else if (parsedKind == InlineAnnotationKind.emphasis) {
      return null;
    }

    if (cursor >= source.length || source.codeUnitAt(cursor) != 0x3c) {
      return null;
    }
    final contentStart = ++cursor;
    final contentEnd = _findUnescaped(source, cursor, 0x3e);
    if (contentEnd < 0) return null;

    String? targetId;
    late final int displayStart;
    if (parsedKind == InlineAnnotationKind.emphasis) {
      displayStart = contentStart;
    } else {
      final separator = _findUnescaped(
        source,
        contentStart,
        0x7c,
        end: contentEnd,
      );
      if (separator < 0) return null;
      final encodedTarget = source.substring(contentStart, separator);
      targetId = unescape(encodedTarget);
      if (!_isUuid(targetId)) return null;
      targetId = targetId.toLowerCase();
      displayStart = separator + 1;
    }

    final displayText = unescape(source.substring(displayStart, contentEnd));
    cursor = contentEnd + 1;

    String? note;
    TextRange? noteRange;
    if (cursor < source.length && source.codeUnitAt(cursor) == 0x7b) {
      final noteStart = cursor + 1;
      final noteEnd = _findUnescaped(source, noteStart, 0x7d);
      if (noteEnd < 0) return null;
      final decodedNote = unescape(source.substring(noteStart, noteEnd));
      note = decodedNote.isEmpty ? null : decodedNote;
      noteRange = TextRange(start: noteStart, end: noteEnd);
      cursor = noteEnd + 1;
    }

    if (cursor + 1 >= source.length ||
        source.codeUnitAt(cursor) != 0x2f ||
        source.codeUnitAt(cursor + 1) != 0x2f ||
        _isEscaped(source, cursor)) {
      return null;
    }
    final end = cursor + 2;

    final InlineAnnotationTargetStatus targetStatus;
    if (parsedKind == InlineAnnotationKind.emphasis) {
      targetStatus = InlineAnnotationTargetStatus.notApplicable;
    } else if (targetExists == null || targetId == null) {
      targetStatus = InlineAnnotationTargetStatus.unchecked;
    } else {
      targetStatus = targetExists(parsedKind, targetId)
          ? InlineAnnotationTargetStatus.resolved
          : InlineAnnotationTargetStatus.missing;
    }

    return InlineAnnotation(
      kind: parsedKind,
      state: state,
      colors: colors,
      targetId: targetId,
      targetStatus: targetStatus,
      displayText: displayText,
      note: note,
      sourceRange: TextRange(start: start, end: end),
      displayTextSourceRange: TextRange(start: displayStart, end: contentEnd),
      noteSourceRange: noteRange,
    );
  }

  static InlineAnnotationKind? _kindFor(int unit) {
    return switch (unit) {
      0x40 => InlineAnnotationKind.character,
      0x21 => InlineAnnotationKind.location,
      0x23 => InlineAnnotationKind.event,
      0x3f => InlineAnnotationKind.foreshadowing,
      0x26 => InlineAnnotationKind.plan,
      _ => null,
    };
  }

  static bool _isColor(int unit) {
    final upper = unit >= 0x61 && unit <= 0x66 ? unit - 0x20 : unit;
    return upper == 0x30 || (upper >= 0x41 && upper <= 0x46);
  }

  static bool _isUuid(String value) {
    if (value.length != 36) return false;
    for (var index = 0; index < value.length; index++) {
      final unit = value.codeUnitAt(index);
      if (index == 8 || index == 13 || index == 18 || index == 23) {
        if (unit != 0x2d) return false;
        continue;
      }
      final isDigit = unit >= 0x30 && unit <= 0x39;
      final lower = unit | 0x20;
      final isHexLetter = lower >= 0x61 && lower <= 0x66;
      if (!isDigit && !isHexLetter) return false;
    }
    return true;
  }

  static int _findUnescaped(
    String source,
    int start,
    int delimiter, {
    int? end,
  }) {
    final limit = end ?? source.length;
    for (var i = start; i < limit; i++) {
      if (source.codeUnitAt(i) == delimiter && !_isEscaped(source, i)) {
        return i;
      }
      if (i + 1 < limit &&
          source.codeUnitAt(i) == 0x2f &&
          source.codeUnitAt(i + 1) == 0x2f &&
          !_isEscaped(source, i)) {
        return -1;
      }
    }
    return -1;
  }

  static bool _isEscaped(String source, int offset) {
    var slashes = 0;
    for (var i = offset - 1; i >= 0 && source.codeUnitAt(i) == 0x5c; i--) {
      slashes++;
    }
    return slashes.isOdd;
  }

  /// Decodes only Mosaic syntax escapes, preserving unrelated backslashes.
  static String unescape(String encoded) {
    if (!encoded.contains(r"\")) return encoded;
    final output = StringBuffer();
    var cursor = 0;
    while (cursor < encoded.length) {
      final unit = encoded.codeUnitAt(cursor);
      if (unit == 0x5c && cursor + 1 < encoded.length) {
        final next = encoded.codeUnitAt(cursor + 1);
        if (_isEscapable(next)) {
          output.writeCharCode(next);
          cursor += 2;
          continue;
        }
      }
      output.writeCharCode(unit);
      cursor++;
    }
    return output.toString();
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
