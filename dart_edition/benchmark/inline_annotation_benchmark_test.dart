import "dart:convert";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation_parser.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation_projection.dart";

const bool _enabled = bool.fromEnvironment("MOSAIC_BENCHMARK");
const String _uuid = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";

void main() {
  test("100 KB parser and projection benchmark", () {
    const parser = InlineAnnotationParser();
    final source = _documentOfSize(100 * 1024);
    final parseSamples = <int>[];
    final projectionSamples = <int>[];

    for (var iteration = 0; iteration < 30; iteration++) {
      final parseWatch = Stopwatch()..start();
      final annotations = parser.parse(source);
      parseWatch.stop();
      parseSamples.add(parseWatch.elapsedMicroseconds);

      final projectionWatch = Stopwatch()..start();
      final projection = InlineAnnotationProjection.build(
        source,
        annotations: annotations,
      );
      projectionWatch.stop();
      projectionSamples.add(projectionWatch.elapsedMicroseconds);
      expect(projection.displayText, isNotEmpty);
    }

    _printSamples("parse", source.length, parseSamples);
    _printSamples("projection", source.length, projectionSamples);
  }, skip: !_enabled);
}

String _documentOfSize(int targetSize) {
  const line = "她看見 //@+^CE<$_uuid|艾莉絲>{主角首次登場}//，然後走向 //^E<舊教堂>//。\n";
  final output = StringBuffer();
  while (output.length < targetSize) {
    output.write(line);
  }
  return output.toString().substring(0, targetSize);
}

void _printSamples(String stage, int textLength, List<int> samples) {
  samples.sort();
  int percentile(double value) =>
      samples[((samples.length - 1) * value).round()];
  stdout.writeln(
    jsonEncode(<String, Object>{
      "stage": stage,
      "textLenUtf16": textLength,
      "iterations": samples.length,
      "p50Micros": percentile(0.50),
      "p95Micros": percentile(0.95),
      "maxMicros": samples.last,
    }),
  );
}
