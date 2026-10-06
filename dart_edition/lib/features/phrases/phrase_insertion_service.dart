import 'package:flutter/services.dart';

import '../inline_annotations/inline_annotation.dart';
import '../inline_annotations/inline_annotation_syntax.dart';
import '../inline_annotations/mosaic_editing_controller.dart';
import 'phrase_body_validator.dart';
import 'phrase_entry.dart';

typedef PhraseTargetExists =
    bool Function(InlineAnnotationKind kind, String id);

/// One missing mention occurrence, identified by its offset in the phrase body.
final class MissingPhraseMention {
  final InlineAnnotation annotation;

  const MissingPhraseMention(this.annotation);
}

/// A prepared edit is bound to the exact raw text that was inspected.
final class PreparedPhraseInsertion {
  final PhraseEntry phrase;
  final String originalRawText;
  final int rawRevision;
  final TextRange rawRange;
  final List<MissingPhraseMention> missingMentions;

  const PreparedPhraseInsertion({
    required this.phrase,
    required this.originalRawText,
    required this.rawRevision,
    required this.rawRange,
    required this.missingMentions,
  });
}

/// Resolves one missing mention by replacing its target, flattening it, or
/// leaving it unresolved (null). The key is the mention's body source offset.
sealed class PhraseMentionResolution {
  const PhraseMentionResolution();
}

final class RelinkPhraseMention extends PhraseMentionResolution {
  final String targetId;
  const RelinkPhraseMention(this.targetId);
}

final class FlattenPhraseMention extends PhraseMentionResolution {
  const FlattenPhraseMention();
}

final class PhraseInsertionService {
  const PhraseInsertionService();

  PreparedPhraseInsertion prepare({
    required PhraseEntry phrase,
    required MosaicEditingController controller,
    required TextSelection displaySelection,
    required PhraseTargetExists targetExists,
    TextRange? triggerRawRange,
  }) {
    if (!phrase.enabled) throw StateError('phrase is disabled');
    if (!displaySelection.isValid ||
        displaySelection.start < 0 ||
        displaySelection.end > controller.displayText.length) {
      throw const FormatException('phrase display selection is invalid');
    }
    final validation = const PhraseBodyValidator().validate(phrase.body);
    if (!validation.isValid) {
      throw const FormatException('phrase body is invalid');
    }
    var range =
        triggerRawRange ??
        controller.projection.displayRangeToRaw(
          TextRange(start: displaySelection.start, end: displaySelection.end),
        );
    if (range.start < 0 ||
        range.end > controller.rawText.length ||
        range.start > range.end) {
      throw const FormatException('phrase insertion range is invalid');
    }
    for (final annotation in controller.annotations) {
      final source = annotation.sourceRange;
      if (range.isCollapsed &&
          range.start > source.start &&
          range.start < source.end) {
        throw StateError('cannot insert a phrase inside a Mention');
      }
      if (range.start < source.end && range.end > source.start) {
        range = TextRange(
          start: range.start < source.start ? range.start : source.start,
          end: range.end > source.end ? range.end : source.end,
        );
      }
    }
    final missing = <MissingPhraseMention>[
      for (final annotation in validation.annotations)
        if (annotation.targetId case final id?
            when phrase.requiresRelink || !targetExists(annotation.kind, id))
          MissingPhraseMention(annotation),
    ];
    return PreparedPhraseInsertion(
      phrase: phrase,
      originalRawText: controller.rawText,
      rawRevision: controller.rawRevision,
      rawRange: range,
      missingMentions: List.unmodifiable(missing),
    );
  }

  /// Commits once. A caller must collect a decision for every missing mention.
  /// Returns false if the editor changed while a resolution UI was open.
  bool commit({
    required PreparedPhraseInsertion prepared,
    required MosaicEditingController controller,
    required PhraseTargetExists targetExists,
    Map<int, PhraseMentionResolution> resolutions = const {},
  }) {
    if (controller.rawRevision != prepared.rawRevision ||
        controller.rawText != prepared.originalRawText) {
      return false;
    }
    var body = prepared.phrase.body;
    for (final missing in prepared.missingMentions.reversed) {
      final annotation = missing.annotation;
      final decision = resolutions[annotation.sourceRange.start];
      if (decision == null) {
        throw StateError('missing Mention must be resolved before insertion');
      }
      final replacement = switch (decision) {
        FlattenPhraseMention() => annotation.displayText,
        RelinkPhraseMention(:final targetId) =>
          targetExists(annotation.kind, targetId)
              ? InlineAnnotationSyntax.format(
                  kind: annotation.kind,
                  state: annotation.state,
                  colors: annotation.colors,
                  targetId: targetId,
                  displayText: annotation.displayText,
                  note: annotation.note,
                )
              : throw StateError('replacement Mention target is missing'),
      };
      body = body.replaceRange(
        annotation.sourceRange.start,
        annotation.sourceRange.end,
        replacement,
      );
    }
    final validation = const PhraseBodyValidator().validate(body);
    if (!validation.isValid) {
      throw const FormatException('resolved phrase body is invalid');
    }
    for (final annotation in validation.annotations) {
      if (annotation.targetId case final id?
          when !targetExists(annotation.kind, id)) {
        throw StateError('Mention target changed before insertion');
      }
    }
    controller.replaceRawRange(prepared.rawRange, body);
    return true;
  }
}
