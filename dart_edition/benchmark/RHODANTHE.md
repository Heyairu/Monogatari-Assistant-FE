# Rhodanthe benchmarks

Build the release bridge, then measure raw FFI and worker-isolate round trips:

```text
dart run tool/build_rhodanthe_native.dart --platform windows
dart run benchmark/rhodanthe_native_benchmark.dart
dart run benchmark/rhodanthe_native_benchmark.dart --gate
```

Measure `RenderPlan` conversion and Flutter `RichText` layout separately:

```text
flutter test benchmark/rhodanthe_text_span_benchmark_test.dart \
  --dart-define=RHODANTHE_BENCHMARK=true
```

Both harnesses emit JSON lines for 100 KiB, 500 KiB, and 1 MiB documents with
p50, p95, maximum duration, and (for native stages) RSS delta. Run release or
profile builds on the target device; debug timings are not rollout evidence.
The Flutter fixture uses 80-code-unit lines and performs one layout warm-up;
this models a chapter-sized editor document without conflating the result with
the pathological cost of laying out a one-million-character single line.

`--gate` exits non-zero when worker-isolate p95 exceeds 75 ms at 100 KiB,
100 ms at 500 KiB, or 150 ms at 1 MiB. Run it without competing CPU-heavy jobs;
contention is intentionally treated as a failed release signal.

The compact bridge capability (`compactAnalysisV1`) removes duplicated search
and filler annotations from the response. Search ranges use flat UTF-16 pairs
and render runs use flat start/end/token triples. Legacy map responses remain
available when `compactResponse` is false.

The acceptance gate remains: no input-path pause over 16 ms attributable to
Rhodanthe, no stale plan publication, bounded 2,048 visible results, and an
end-to-end improvement over the existing Dart path. If the full pipeline does
not improve the target workload, keep the corresponding rollout mode disabled.
