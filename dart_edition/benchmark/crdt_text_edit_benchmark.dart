import "dart:io";

import "package:monogatari_assistant/domain/collaboration/collaboration_document.dart";
import "package:monogatari_assistant/domain/collaboration/collaborative_text.dart";

const _projectUuid = "11111111-1111-4111-8111-111111111111";

void main() {
  for (final scenario in const <({int characters, int edits})>[
    (characters: 10000, edits: 1000),
    (characters: 100000, edits: 200),
    (characters: 1000000, edits: 20),
  ]) {
    _runScenario(scenario.characters, scenario.edits);
  }
}

void _runScenario(int characterCount, int editCount) {
  var document = CollaborationDocument.seeded(
    projectUuid: _projectUuid,
    replicaId: "benchmark",
    chapterTexts: <String, String>{
      "chapter": List<String>.filled(characterCount, "a").join(),
    },
  );
  // Warm and retain the initial ordered view before measuring edits.
  document.text("chapter");
  final rssBefore = ProcessInfo.currentRss;
  final samples = <int>[];
  for (var index = 0; index < editCount; index += 1) {
    final length = characterCount + index;
    final stopwatch = Stopwatch()..start();
    document = document.createLocalTextDelta(
      documentId: "chapter",
      delta: CollaborativeTextDelta(
        baseTextLength: length,
        startOffset: length,
        endOffset: length,
        replacementText: "b",
      ),
    );
    stopwatch.stop();
    samples.add(stopwatch.elapsedMicroseconds);
  }
  samples.sort();
  final p50 = samples[((samples.length - 1) * 0.50).round()];
  final p95 = samples[((samples.length - 1) * 0.95).round()];
  final rssDelta = ProcessInfo.currentRss - rssBefore;
  final text = document.textDocument("chapter")!;
  stdout.writeln(
    "$characterCount chars / $editCount edits: "
    "p50=${p50}us p95=${p95}us rssDelta=$rssDelta "
    "atoms=${document.atomCount} tombstones=${document.tombstoneCount} "
    "operations=${document.operationCount} "
    "fullViewBuilds=${text.fullViewBuildCount}",
  );
}
