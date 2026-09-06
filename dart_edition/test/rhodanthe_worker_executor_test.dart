import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_protocol.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_worker_executor.dart";
import "package:path/path.dart" as path;

void main() {
  final libraryPath = _developmentLibraryPath();

  test(
    "persistent worker owns the native engine and preserves command order",
    () async {
      final executor = await RhodantheWorkerExecutor.start(
        libraryPath: libraryPath!,
      );
      addTearDown(executor.dispose);

      var eventLoopAdvanced = false;
      final open = executor.execute(
        RhodantheRequest.openDocument(
          requestId: 1,
          documentId: "worker-test",
          revision: 1,
          fullText: "😀test test",
        ),
      );
      final analyze = executor.execute(
        RhodantheRequest.analyze(
          requestId: 2,
          documentId: "worker-test",
          revision: 1,
          search: const RhodantheSearchRequest(
            query: "test",
            queryRevision: 6,
            activeMatchIndex: 1,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero, () {
        eventLoopAdvanced = true;
      });

      expect(eventLoopAdvanced, isTrue);
      expect((await open).ok, isTrue);
      final analysis = RhodantheAnalysisResult.fromResponse(await analyze);
      expect(analysis.renderPlan.revision, 1);
      expect(analysis.renderPlan.plan.textLenUtf16, 11);
      expect(analysis.renderPlan.plan.runs.first.range.start, 2);
      expect(analysis.search?["activeMatchId"], "search:6:1");

      final close = await executor.execute(
        RhodantheRequest.closeDocument(requestId: 3, documentId: "worker-test"),
      );
      expect(close.ok, isTrue);

      await executor.dispose();
      await expectLater(
        executor.execute(RhodantheRequest.handshake()),
        throwsA(
          isA<RhodantheWorkerException>().having(
            (error) => error.code,
            "code",
            "workerDisposed",
          ),
        ),
      );
    },
    skip: libraryPath == null
        ? "Build rust/rhodanthe-bridge in release mode first"
        : false,
  );

  test(
    "worker forwards structured native errors without terminating",
    () async {
      final executor = await RhodantheWorkerExecutor.start(
        libraryPath: libraryPath!,
      );
      addTearDown(executor.dispose);

      final missing = await executor.execute(
        RhodantheRequest.analyze(
          requestId: 4,
          documentId: "missing",
          revision: 1,
        ),
      );
      expect(missing.ok, isFalse);
      expect(missing.error?.code, "documentNotOpen");

      final handshake = await executor.execute(
        RhodantheRequest.handshake(requestId: 5),
      );
      expect(handshake.ok, isTrue);
    },
    skip: libraryPath == null
        ? "Build rust/rhodanthe-bridge in release mode first"
        : false,
  );

  test("worker startup reports a bad native library path", () async {
    if (!Platform.isWindows) return;
    await expectLater(
      RhodantheWorkerExecutor.start(
        libraryPath: path.join(
          Directory.current.path,
          "does-not-exist",
          "rhodanthe_bridge.dll",
        ),
        startupTimeout: const Duration(seconds: 2),
      ),
      throwsA(
        isA<RhodantheWorkerException>().having(
          (error) => error.code,
          "code",
          "nativeUnavailable",
        ),
      ),
    );
  });
}

String? _developmentLibraryPath() {
  if (!Platform.isWindows) return null;
  final candidate = path.join(
    Directory.current.path,
    "rust",
    "target",
    "release",
    "rhodanthe_bridge.dll",
  );
  return File(candidate).existsSync() ? candidate : null;
}
