import "dart:convert";
import "dart:io";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_protocol.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_text_span_adapter.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_theme.dart";

const bool _enabled = bool.fromEnvironment("RHODANTHE_BENCHMARK");

void main() {
  testWidgets("RenderPlan adapter and RichText layout benchmark", (
    tester,
  ) async {
    const adapter = RhodantheTextSpanAdapter();
    for (final size in const <int>[100 * 1024, 500 * 1024, 1024 * 1024]) {
      final text = _textOfSize(size);
      final plan = _plan(text.length);
      final iterations = size <= 100 * 1024
          ? 20
          : size <= 500 * 1024
          ? 10
          : 5;
      final buildSamples = <int>[];
      RhodantheSpanBuildResult? result;
      for (var index = 0; index < iterations; index++) {
        final stopwatch = Stopwatch()..start();
        result = adapter.build(
          text: text,
          currentRevision: 1,
          renderPlan: plan,
          theme: RhodantheTheme.light(),
        );
        stopwatch.stop();
        expect(result.applied, isTrue);
        buildSamples.add(stopwatch.elapsedMicroseconds);
      }
      _print("textSpanBuild", size, buildSamples);

      await tester.pumpWidget(_benchmarkWidget(result!.span));
      await tester.pump();
      final layoutSamples = <int>[];
      for (var index = 0; index < 3; index++) {
        final stopwatch = Stopwatch()..start();
        await tester.pumpWidget(_benchmarkWidget(result.span));
        await tester.pump();
        stopwatch.stop();
        layoutSamples.add(stopwatch.elapsedMicroseconds);
      }
      _print("richTextLayout", size, layoutSamples);
    }
  }, skip: !_enabled);
}

Widget _benchmarkWidget(InlineSpan span) {
  return MaterialApp(
    home: SizedBox(
      width: 800,
      height: 600,
      child: SingleChildScrollView(child: RichText(text: span)),
    ),
  );
}

String _textOfSize(int size) {
  final line = "${List<String>.filled(79, "a").join()}\n";
  final repetitions = (size / line.length).ceil();
  return List<String>.filled(repetitions, line).join().substring(0, size);
}

RhodantheVersionedRenderPlan _plan(int textLength) {
  const runCount = 2048;
  final stride = textLength ~/ runCount;
  return RhodantheVersionedRenderPlan(
    documentId: "benchmark",
    revision: 1,
    plan: RhodantheRenderPlan(
      contractVersion: 1,
      textLenUtf16: textLength,
      runs: <RhodantheRenderRun>[
        for (var index = 0; index < runCount; index++)
          RhodantheRenderRun(
            range: RhodantheRange(index * stride, index * stride + 4),
            styleTokenSetId: 0,
            annotationIds: <String>["search:$index"],
          ),
      ],
      tokenSets: const <RhodantheStyleTokenSet>[
        RhodantheStyleTokenSet(background: "search.match.background"),
      ],
    ),
  );
}

void _print(String stage, int textLength, List<int> samples) {
  samples.sort();
  int percentile(double value) =>
      samples[((samples.length - 1) * value).round()];
  stdout.writeln(
    jsonEncode(<String, Object?>{
      "stage": stage,
      "textLenUtf16": textLength,
      "iterations": samples.length,
      "p50Micros": percentile(0.50),
      "p95Micros": percentile(0.95),
      "maxMicros": samples.last,
    }),
  );
}
