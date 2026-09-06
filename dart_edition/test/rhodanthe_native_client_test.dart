import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as path;
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_native_client.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_protocol.dart";

void main() {
  final libraryPath = _developmentLibraryPath();

  test(
    "Dart FFI client executes the native document lifecycle",
    () {
      final client = RhodantheNativeClient.open(libraryPath: libraryPath!);
      addTearDown(client.dispose);

      final handshake = client.sendSync(
        RhodantheRequest.handshake(requestId: 1),
      );
      expect(handshake.ok, isTrue);
      expect(handshake.requireResult()["abiVersion"], 1);

      expect(
        client
            .sendSync(
              RhodantheRequest.openDocument(
                requestId: 2,
                documentId: "dart-test",
                revision: 1,
                fullText: "😀test test",
              ),
            )
            .ok,
        isTrue,
      );
      final response = client.sendSync(
        RhodantheRequest.analyze(
          requestId: 3,
          documentId: "dart-test",
          revision: 1,
          search: const RhodantheSearchRequest(
            query: "test",
            queryRevision: 5,
            activeMatchIndex: 1,
          ),
          externalAnnotations: const <RhodantheExternalAnnotation>[
            RhodantheExternalAnnotation(
              annotationId: "mention:first-test",
              source: "mention",
              sourceOrder: 0,
              ring: 4,
              range: RhodantheRange(2, 6),
              style: RhodantheStyleTokenSet(
                foreground: "mention.resolved.foreground",
                interaction: "mention:first-test",
              ),
              payloadId: "character:test",
            ),
          ],
        ),
      );
      final analysis = RhodantheAnalysisResult.fromResponse(response);
      expect(analysis.renderPlan.plan.textLenUtf16, 11);
      expect(analysis.renderPlan.plan.runs.first.range.start, 2);
      expect(analysis.search?["activeMatchId"], "search:5:1");
      final firstRun = analysis.renderPlan.plan.runs.first;
      final firstStyle =
          analysis.renderPlan.plan.tokenSets[firstRun.styleTokenSetId];
      expect(firstStyle.background, "search.match.background");
      expect(firstStyle.foreground, "mention.resolved.foreground");
      expect(firstStyle.interaction, "mention:first-test");

      expect(
        client
            .sendSync(
              RhodantheRequest.closeDocument(
                requestId: 4,
                documentId: "dart-test",
              ),
            )
            .ok,
        isTrue,
      );
    },
    skip: libraryPath == null
        ? "Build rust/rhodanthe-bridge in release mode first"
        : false,
  );
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
