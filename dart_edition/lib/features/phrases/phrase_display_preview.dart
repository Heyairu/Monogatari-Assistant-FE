import '../inline_annotations/inline_annotation.dart';
import '../inline_annotations/inline_annotation_projection.dart';

/// Mirrors Mosaic's collapsed presentation as a single line of text.
/// Each annotation keeps only its kind symbol and display text.
String phraseDisplayPreview(String rawBody) {
  final projection = InlineAnnotationProjection.build(rawBody);
  var display = projection.displayText;
  for (final entry in projection.projectedAnnotations.reversed) {
    if (entry.isExpanded || entry.badgeRange.isCollapsed) continue;
    display = display.replaceRange(
      entry.badgeRange.start,
      entry.badgeRange.end,
      phraseKindSymbol(entry.annotation.kind),
    );
  }
  return display;
}

String phraseKindSymbol(InlineAnnotationKind kind) => switch (kind) {
  InlineAnnotationKind.character => '@',
  InlineAnnotationKind.location => '!',
  InlineAnnotationKind.event => '#',
  InlineAnnotationKind.foreshadowing => '?',
  InlineAnnotationKind.plan => '&',
  InlineAnnotationKind.item => '*',
  InlineAnnotationKind.emphasis => '^',
};
