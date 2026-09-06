import "dart:convert";
import "dart:io";

import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_native_client.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_protocol.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_worker_executor.dart";
import "package:path/path.dart" as path;

Future<void> main(List<String> arguments) async {
  final libraryPath = _libraryPath(arguments);
  if (libraryPath == null || !File(libraryPath).existsSync()) {
    stderr.writeln(
      "Build Rhodanthe first or pass --library <path-to-native-library>.",
    );
    exitCode = 64;
    return;
  }

  final measurements = <_Measurement>[];
  for (final size in const <int>[100 * 1024, 500 * 1024, 1024 * 1024]) {
    final text = _textOfSize(size);
    final iterations = size <= 100 * 1024
        ? 20
        : size <= 500 * 1024
        ? 10
        : 5;
    measurements.add(await _runRaw(libraryPath, text, iterations));
    measurements.add(await _runWorker(libraryPath, text, iterations));
  }
  if (arguments.contains("--gate")) {
    _applyGate(measurements);
  }
}

Future<_Measurement> _runRaw(
  String libraryPath,
  String text,
  int iterations,
) async {
  final client = RhodantheNativeClient.open(libraryPath: libraryPath);
  final documentId = "raw-${text.length}";
  try {
    client
        .sendSync(
          RhodantheRequest.openDocument(
            documentId: documentId,
            revision: 1,
            fullText: text,
          ),
        )
        .requireResult();
    final request = _analysisRequest(documentId);
    for (var index = 0; index < 2; index++) {
      client.sendSync(request).requireResult();
    }
    final rssBefore = ProcessInfo.currentRss;
    final samples = <int>[];
    for (var index = 0; index < iterations; index++) {
      final stopwatch = Stopwatch()..start();
      client.sendSync(request).requireResult();
      stopwatch.stop();
      samples.add(stopwatch.elapsedMicroseconds);
    }
    final measurement = _printResult(
      stage: "rawFfi",
      textLength: text.length,
      samples: samples,
      rssDelta: ProcessInfo.currentRss - rssBefore,
    );
    client
        .sendSync(RhodantheRequest.closeDocument(documentId: documentId))
        .requireResult();
    return measurement;
  } finally {
    client.dispose();
  }
}

Future<_Measurement> _runWorker(
  String libraryPath,
  String text,
  int iterations,
) async {
  final worker = await RhodantheWorkerExecutor.start(libraryPath: libraryPath);
  final documentId = "worker-${text.length}";
  try {
    (await worker.execute(
      RhodantheRequest.openDocument(
        documentId: documentId,
        revision: 1,
        fullText: text,
      ),
    )).requireResult();
    final request = _analysisRequest(documentId);
    for (var index = 0; index < 2; index++) {
      (await worker.execute(request)).requireResult();
    }
    final rssBefore = ProcessInfo.currentRss;
    final samples = <int>[];
    for (var index = 0; index < iterations; index++) {
      final stopwatch = Stopwatch()..start();
      (await worker.execute(request)).requireResult();
      stopwatch.stop();
      samples.add(stopwatch.elapsedMicroseconds);
    }
    final measurement = _printResult(
      stage: "workerRoundTrip",
      textLength: text.length,
      samples: samples,
      rssDelta: ProcessInfo.currentRss - rssBefore,
    );
    (await worker.execute(
      RhodantheRequest.closeDocument(documentId: documentId),
    )).requireResult();
    return measurement;
  } finally {
    await worker.dispose();
  }
}

RhodantheRequest _analysisRequest(String documentId) {
  return RhodantheRequest.analyze(
    documentId: documentId,
    revision: 1,
    search: const RhodantheSearchRequest(
      query: "target",
      queryRevision: 1,
      maxResults: 2048,
    ),
    filler: const RhodantheFillerRequest(
      dictionaryRevision: 1,
      words: <String>["really", "filler"],
    ),
  );
}

_Measurement _printResult({
  required String stage,
  required int textLength,
  required List<int> samples,
  required int rssDelta,
}) {
  samples.sort();
  int percentile(double value) =>
      samples[((samples.length - 1) * value).round()];
  final measurement = _Measurement(
    stage: stage,
    textLength: textLength,
    iterations: samples.length,
    p50Micros: percentile(0.50),
    p95Micros: percentile(0.95),
    maxMicros: samples.last,
    rssDeltaBytes: rssDelta,
  );
  stdout.writeln(jsonEncode(measurement.toJson()));
  return measurement;
}

void _applyGate(List<_Measurement> measurements) {
  const workerP95Budget = <int, int>{
    100 * 1024: 75000,
    500 * 1024: 100000,
    1024 * 1024: 150000,
  };
  final failures = <Map<String, Object?>>[];
  for (final measurement in measurements) {
    if (measurement.stage != "workerRoundTrip") continue;
    final budget = workerP95Budget[measurement.textLength];
    if (budget != null && measurement.p95Micros > budget) {
      failures.add(<String, Object?>{
        "textLenUtf16": measurement.textLength,
        "actualP95Micros": measurement.p95Micros,
        "budgetP95Micros": budget,
      });
    }
  }
  final passed = failures.isEmpty;
  stdout.writeln(
    jsonEncode(<String, Object?>{
      "stage": "releaseGate",
      "ok": passed,
      "failures": failures,
    }),
  );
  if (!passed) exitCode = 1;
}

final class _Measurement {
  final String stage;
  final int textLength;
  final int iterations;
  final int p50Micros;
  final int p95Micros;
  final int maxMicros;
  final int rssDeltaBytes;

  const _Measurement({
    required this.stage,
    required this.textLength,
    required this.iterations,
    required this.p50Micros,
    required this.p95Micros,
    required this.maxMicros,
    required this.rssDeltaBytes,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    "stage": stage,
    "textLenUtf16": textLength,
    "iterations": iterations,
    "p50Micros": p50Micros,
    "p95Micros": p95Micros,
    "maxMicros": maxMicros,
    "rssDeltaBytes": rssDeltaBytes,
  };
}

String _textOfSize(int size) {
  const pattern = "alpha really target filler。";
  final repetitions = (size / pattern.length).ceil();
  final buffer = StringBuffer();
  for (var index = 0; index < repetitions; index++) {
    buffer.write(pattern);
  }
  return buffer.toString().substring(0, size);
}

String? _libraryPath(List<String> arguments) {
  final index = arguments.indexOf("--library");
  if (index >= 0 && index + 1 < arguments.length) {
    return path.absolute(arguments[index + 1]);
  }
  final fileName = Platform.isWindows
      ? "rhodanthe_bridge.dll"
      : Platform.isMacOS
      ? "librhodanthe_bridge.dylib"
      : "librhodanthe_bridge.so";
  return path.join(
    Directory.current.path,
    "rust",
    "target",
    "release",
    fileName,
  );
}
