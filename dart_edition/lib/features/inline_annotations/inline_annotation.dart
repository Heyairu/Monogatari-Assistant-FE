/*
 * Copyright 2025-2026 Heyairu（部屋伊琉）
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 ************************************************************/

import "package:flutter/services.dart";

enum InlineAnnotationKind {
  character,
  location,
  event,
  foreshadowing,
  plan,
  emphasis,
}

enum InlineAnnotationState { none, start, end }

enum InlineAnnotationTargetStatus {
  notApplicable,
  unchecked,
  resolved,
  missing,
}

final class InlineAnnotationColorCode {
  final String background;
  final String foreground;

  const InlineAnnotationColorCode({
    required this.background,
    required this.foreground,
  });

  String get value => "$background$foreground";

  @override
  bool operator ==(Object other) {
    return other is InlineAnnotationColorCode &&
        other.background == background &&
        other.foreground == foreground;
  }

  @override
  int get hashCode => Object.hash(background, foreground);
}

final class InlineAnnotation {
  final InlineAnnotationKind kind;
  final InlineAnnotationState state;
  final InlineAnnotationColorCode colors;
  final String? targetId;
  final InlineAnnotationTargetStatus targetStatus;
  final String displayText;
  final String? note;

  /// Complete annotation range in raw UTF-16 offsets.
  final TextRange sourceRange;

  /// Encoded display-text range inside `<...>` in raw UTF-16 offsets.
  final TextRange displayTextSourceRange;

  /// Encoded note contents in raw UTF-16 offsets.
  final TextRange? noteSourceRange;

  const InlineAnnotation({
    required this.kind,
    required this.state,
    required this.colors,
    required this.targetId,
    required this.targetStatus,
    required this.displayText,
    required this.note,
    required this.sourceRange,
    required this.displayTextSourceRange,
    required this.noteSourceRange,
  });

  bool get hasTarget => targetId != null;
}
