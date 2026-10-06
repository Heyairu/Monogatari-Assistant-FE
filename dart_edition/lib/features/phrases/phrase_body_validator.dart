import 'package:flutter/services.dart';

import '../inline_annotations/inline_annotation.dart';
import '../inline_annotations/inline_annotation_parser.dart';
import '../inline_annotations/inline_annotation_projection.dart';

final class PhraseBodyIssue {
  final String code;
  final TextRange range;
  final String message;

  const PhraseBodyIssue(this.code, this.range, this.message);
}

final class PhraseBodyValidation {
  final List<InlineAnnotation> annotations;
  final List<PhraseBodyIssue> issues;
  final String preview;

  const PhraseBodyValidation({
    required this.annotations,
    required this.issues,
    required this.preview,
  });

  bool get isValid => issues.isEmpty;
}

/// Checks candidate Mosaic starts as well as parser output. The parser omits
/// malformed syntax, so its result alone cannot validate a reusable phrase.
final class PhraseBodyValidator {
  const PhraseBodyValidator();

  PhraseBodyValidation validate(String body) {
    const parser = InlineAnnotationParser();
    final annotations = parser.parse(body);
    final starts = {for (final item in annotations) item.sourceRange.start};
    final issues = <PhraseBodyIssue>[];
    for (var index = 0; index + 2 < body.length; index++) {
      if (body.codeUnitAt(index) != 0x2f ||
          body.codeUnitAt(index + 1) != 0x2f) {
        continue;
      }
      var slashes = 0;
      for (
        var previous = index - 1;
        previous >= 0 && body.codeUnitAt(previous) == 0x5c;
        previous--
      ) {
        slashes++;
      }
      if (slashes.isOdd) continue;
      if (!'@!#?&*^'.contains(body[index + 2])) continue;
      if (!starts.contains(index)) {
        issues.add(
          PhraseBodyIssue(
            'invalid_mosaic',
            TextRange(start: index, end: (index + 3).clamp(0, body.length)),
            'Mosaic 標記未完成或無效',
          ),
        );
      }
    }
    return PhraseBodyValidation(
      annotations: annotations,
      issues: List.unmodifiable(issues),
      preview: InlineAnnotationProjection.build(
        body,
        parser: parser,
      ).readerText,
    );
  }
}
