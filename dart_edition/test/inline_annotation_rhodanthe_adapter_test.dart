import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation_projection.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation_rhodanthe_adapter.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_theme.dart";

void main() {
  const uuid = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";
  const adapter = InlineAnnotationRhodantheAdapter();

  test("emits Ring 4 annotations against display UTF-16 ranges", () {
    final projection = InlineAnnotationProjection.build(
      "前//@^CE<$uuid|艾莉絲>{不可送出}//後",
    );
    final annotation = adapter
        .build(projection: projection, documentRevision: 7)
        .single;

    expect(annotation.ring, 4);
    expect(annotation.source, "inlineMarkup");
    expect(annotation.range.start, 2);
    expect(annotation.range.end, 5);
    expect(annotation.style.background, "annotation.pink.background");
    expect(annotation.style.foreground, "annotation.yellow.foreground");
    expect(annotation.payloadId, uuid);
    expect(annotation.annotationId, "inline:7:1:0");
    expect(jsonEncode(annotation.toJson()), isNot(contains("不可送出")));
    expect(jsonEncode(annotation.toJson()), isNot(contains("艾莉絲")));
  });

  test("automatic color channels do not emit Rhodanthe tokens", () {
    final projection = InlineAnnotationProjection.build("//^0<重點>//");
    final annotation = adapter
        .build(projection: projection, documentRevision: 1)
        .single;

    expect(annotation.style.background, isNull);
    expect(annotation.style.foreground, isNull);
    expect(annotation.payloadId, isNull);
  });

  test("all annotation tokens resolve in every Rhodanthe theme", () {
    final themes = <RhodantheTheme>[
      RhodantheTheme.light(),
      RhodantheTheme.dark(),
      RhodantheTheme.highContrast(),
    ];
    for (final theme in themes) {
      for (final color in const [
        "green",
        "blue",
        "pink",
        "purple",
        "yellow",
        "gray",
      ]) {
        expect(theme.resolveColor("annotation.$color.background"), isNotNull);
        expect(theme.resolveColor("annotation.$color.foreground"), isNotNull);
      }
    }
  });
}
