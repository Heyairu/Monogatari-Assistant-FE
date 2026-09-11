/*
 * Copyright 2025-2026 Heyairu（部屋伊琉）
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 ************************************************************/

import "inline_annotation.dart";
import "inline_annotation_parser.dart";

final class InlineAnnotationSyntax {
  const InlineAnnotationSyntax._();

  static String escape(String value) {
    final output = StringBuffer();
    for (var index = 0; index < value.length; index++) {
      final unit = value.codeUnitAt(index);
      if (_mustEscape(unit)) output.write(r"\");
      output.writeCharCode(unit);
    }
    return output.toString();
  }

  static String format({
    required InlineAnnotationKind kind,
    InlineAnnotationState state = InlineAnnotationState.none,
    InlineAnnotationColorCode colors = const InlineAnnotationColorCode(
      background: "B",
      foreground: "0",
    ),
    String? targetId,
    required String displayText,
    String? note,
  }) {
    if (kind == InlineAnnotationKind.emphasis &&
        state != InlineAnnotationState.none) {
      throw const FormatException("emphasis annotations cannot have a state");
    }
    final kindSymbol = switch (kind) {
      InlineAnnotationKind.character => "@",
      InlineAnnotationKind.location => "!",
      InlineAnnotationKind.event => "#",
      InlineAnnotationKind.foreshadowing => "?",
      InlineAnnotationKind.plan => "&",
      InlineAnnotationKind.emphasis => "",
    };
    final stateSymbol = switch (state) {
      InlineAnnotationState.none => "",
      InlineAnnotationState.start => "+",
      InlineAnnotationState.end => "-",
    };
    final colorSyntax = _colorSyntax(
      colors,
      required: kind == InlineAnnotationKind.emphasis,
    );
    final content = kind == InlineAnnotationKind.emphasis
        ? escape(displayText)
        : "${targetId?.toLowerCase() ?? ""}|${escape(displayText)}";
    final normalizedNote = note == null || note.isEmpty
        ? ""
        : "{${escape(note)}}";
    final source =
        "//$kindSymbol$stateSymbol$colorSyntax<$content>$normalizedNote//";
    if (const InlineAnnotationParser().parse(source).length != 1) {
      throw const FormatException("values do not form a valid annotation");
    }
    return source;
  }

  static String _colorSyntax(
    InlineAnnotationColorCode colors, {
    required bool required,
  }) {
    final background = colors.background.toUpperCase();
    final foreground = colors.foreground.toUpperCase();
    if (background == "B" && foreground == "0") {
      return required ? "^" : "";
    }
    if (foreground == "0") return "^$background";
    return "^$background$foreground";
  }

  static bool _mustEscape(int unit) {
    return unit == 0x5c ||
        unit == 0x3c ||
        unit == 0x3e ||
        unit == 0x7b ||
        unit == 0x7d ||
        unit == 0x7c ||
        unit == 0x2f;
  }
}
