/*
 * Copyright 2025-2026 Heyairu（部屋伊琉）
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 ************************************************************/

import "../../infrastructure/rhodanthe/rhodanthe_protocol.dart";
import "inline_annotation_projection.dart";

final class InlineAnnotationRhodantheAdapter {
  const InlineAnnotationRhodantheAdapter();

  List<RhodantheExternalAnnotation> build({
    required InlineAnnotationProjection projection,
    required int documentRevision,
  }) {
    return List<RhodantheExternalAnnotation>.unmodifiable(<
      RhodantheExternalAnnotation
    >[
      for (
        var index = 0;
        index < projection.projectedAnnotations.length;
        index++
      )
        _buildAnnotation(projection, index, documentRevision: documentRevision),
    ]);
  }

  RhodantheExternalAnnotation _buildAnnotation(
    InlineAnnotationProjection projection,
    int index, {
    required int documentRevision,
  }) {
    final entry = projection.projectedAnnotations[index];
    final annotation = entry.annotation;
    final displayRange = entry.isExpanded
        ? RhodantheRange(
            projection.rawOffsetToDisplay(
              annotation.displayTextSourceRange.start,
            ),
            projection.rawOffsetToDisplay(
              annotation.displayTextSourceRange.end,
            ),
          )
        : RhodantheRange(entry.labelRange.start, entry.labelRange.end);
    final annotationId =
        "inline:$documentRevision:${annotation.sourceRange.start}:$index";
    return RhodantheExternalAnnotation(
      annotationId: annotationId,
      source: "inlineMarkup",
      sourceOrder: index,
      ring: 4,
      range: displayRange,
      style: RhodantheStyleTokenSet(
        foreground: _token(annotation.colors.foreground, "foreground"),
        background: _token(annotation.colors.background, "background"),
        interaction: annotationId,
      ),
      payloadId: annotation.targetId,
    );
  }

  String? _token(String code, String channel) {
    final color = switch (code) {
      "A" => "green",
      "B" => "blue",
      "C" => "pink",
      "D" => "purple",
      "E" => "yellow",
      "F" => "gray",
      _ => null,
    };
    return color == null ? null : "annotation.$color.$channel";
  }
}
