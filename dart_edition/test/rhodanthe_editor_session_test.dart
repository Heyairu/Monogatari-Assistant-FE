import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/findreplace.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_editor_session.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_latest_coordinator.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_protocol.dart";

void main() {
  test("session serializes open, Unicode-safe edit, and close", () async {
    final executor = _RecordingExecutor();
    final session = RhodantheEditorSession(
      executor: executor,
      mode: RhodantheRolloutMode.shadow,
    );

    await session.synchronizeDocument(
      documentId: "chapter",
      revision: 1,
      text: "A😀B",
    );
    await session.synchronizeDocument(
      documentId: "chapter",
      revision: 2,
      text: "A😺B",
    );

    expect(executor.requests.map((request) => request.command), <String>[
      "openDocument",
      "applyEdits",
    ]);
    final editArguments = executor.requests[1].arguments!;
    expect(editArguments["baseRevision"], 1);
    expect(editArguments["revision"], 2);
    expect(editArguments["edits"], <Map<String, Object?>>[
      <String, Object?>{"startUtf16": 0, "endUtf16": 4, "replacement": "A😺B"},
    ]);
    expect(session.status, RhodantheSessionStatus.ready);

    await session.dispose();
    expect(executor.requests.last.command, "closeDocument");
    expect(executor.disposed, isTrue);
  });

  test("switching document closes the previous native document", () async {
    final executor = _RecordingExecutor();
    final session = RhodantheEditorSession(
      executor: executor,
      mode: RhodantheRolloutMode.shadow,
    );

    await session.synchronizeDocument(
      documentId: "one",
      revision: 1,
      text: "first",
    );
    await session.synchronizeDocument(
      documentId: "two",
      revision: 4,
      text: "second",
    );

    expect(executor.requests.map((request) => request.command), <String>[
      "openDocument",
      "closeDocument",
      "openDocument",
    ]);
    expect(session.documentId, "two");
    expect(session.revision, 4);
    await session.dispose();
  });

  test("shadow mode compares ranges without publishing a plan", () async {
    final executor = _RecordingExecutor(
      analysisRanges: const <RhodantheRange>[RhodantheRange(0, 4)],
    );
    final plans = <RhodantheVersionedRenderPlan>[];
    final reports = <RhodantheShadowReport>[];
    final observations = <RhodantheAnalysisObservation>[];
    final session = RhodantheEditorSession(
      executor: executor,
      mode: RhodantheRolloutMode.shadow,
      onPlan: plans.add,
      onShadowReport: reports.add,
      onObservation: observations.add,
    );
    await session.synchronizeDocument(
      documentId: "chapter",
      revision: 3,
      text: "test",
    );

    final analysis = await session.analyze(
      search: const RhodantheSearchRequest(query: "test", queryRevision: 2),
      dartSearchRanges: const <RhodantheRange>[RhodantheRange(0, 4)],
    );

    expect(analysis, isNotNull);
    expect(reports.single.isExactMatch, isTrue);
    expect(plans, isEmpty);
    expect(observations.single.status, RhodantheExecutionStatus.applied);
    expect(observations.single.shadowExactMatch, isTrue);
    expect(observations.single.published, isFalse);
    await session.dispose();
  });

  test("search canary publishes search plans", () async {
    final executor = _RecordingExecutor(
      analysisRanges: const <RhodantheRange>[RhodantheRange(0, 4)],
    );
    final plans = <RhodantheVersionedRenderPlan>[];
    final session = RhodantheEditorSession(
      executor: executor,
      mode: RhodantheRolloutMode.searchCanary,
      onPlan: plans.add,
    );
    await session.synchronizeDocument(
      documentId: "chapter",
      revision: 1,
      text: "test",
    );

    await session.analyze(
      search: const RhodantheSearchRequest(query: "test", queryRevision: 1),
    );

    expect(plans, hasLength(1));
    expect(plans.single.revision, 1);
    await session.dispose();
  });

  test("lifecycle errors degrade safely and report failure", () async {
    final executor = _RecordingExecutor(failOpen: true);
    final failures = <RhodantheFailure>[];
    final session = RhodantheEditorSession(
      executor: executor,
      mode: RhodantheRolloutMode.full,
      onFailure: failures.add,
    );

    await expectLater(
      session.synchronizeDocument(
        documentId: "chapter",
        revision: 1,
        text: "text",
      ),
      throwsA(isA<RhodantheFailure>()),
    );

    expect(session.status, RhodantheSessionStatus.degraded);
    expect(failures.single.code, "lifecycleFailed");
    await session.dispose();
  });

  test(
    "analysis circuit breaker pauses native work and retries after cooldown",
    () async {
      final executor = _RecordingExecutor(analysisFailuresRemaining: 2);
      var now = DateTime.utc(2026, 8, 27);
      final health = <RhodantheHealthSnapshot>[];
      final session = RhodantheEditorSession(
        executor: executor,
        mode: RhodantheRolloutMode.searchCanary,
        maxConsecutiveAnalysisFailures: 2,
        circuitCooldown: const Duration(seconds: 10),
        now: () => now,
        onHealthChanged: health.add,
      );
      await session.synchronizeDocument(
        documentId: "chapter",
        revision: 1,
        text: "test",
      );

      const search = RhodantheSearchRequest(query: "test", queryRevision: 1);
      expect(await session.analyze(search: search), isNull);
      expect(await session.analyze(search: search), isNull);
      expect(session.status, RhodantheSessionStatus.circuitOpen);
      final requestsBeforePause = executor.requests.length;

      expect(await session.analyze(search: search), isNull);
      expect(executor.requests, hasLength(requestsBeforePause));

      now = now.add(const Duration(seconds: 11));
      expect(await session.analyze(search: search), isNotNull);
      expect(session.status, RhodantheSessionStatus.ready);
      expect(session.health.consecutiveAnalysisFailures, 0);
      expect(
        health.any(
          (value) => value.status == RhodantheSessionStatus.circuitOpen,
        ),
        isTrue,
      );
      await session.dispose();
    },
  );

  testWidgets("controller publishes only a current Rhodanthe plan", (
    tester,
  ) async {
    final controller = HighlightTextEditingController(text: "test");
    addTearDown(controller.dispose);
    final plan = _versionedPlan(
      revision: controller.textRevision,
      text: "test",
    );
    expect(controller.publishRhodantheRenderPlan(plan), isTrue);

    late TextSpan span;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            span = controller.buildTextSpan(
              context: context,
              style: const TextStyle(fontSize: 14),
              withComposing: true,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    final highlighted = span.children!.single as TextSpan;
    expect(highlighted.style!.backgroundColor, isNotNull);
    expect(controller.rhodantheMetadataAt(2)?.annotationIds, <String>[
      "search",
    ]);

    controller.text = "changed";
    expect(controller.rhodantheRenderPlan, isNull);
    expect(controller.rhodantheMetadata, isEmpty);
    expect(controller.publishRhodantheRenderPlan(plan), isFalse);
  });
}

final class _RecordingExecutor implements RhodantheAsyncExecutor {
  final List<RhodantheRequest> requests = <RhodantheRequest>[];
  final List<RhodantheRange> analysisRanges;
  final bool failOpen;
  int analysisFailuresRemaining;
  bool disposed = false;
  int _documentRevision = 0;
  String _documentId = "";
  int _textLength = 0;

  _RecordingExecutor({
    this.analysisRanges = const <RhodantheRange>[],
    this.failOpen = false,
    this.analysisFailuresRemaining = 0,
  });

  @override
  Future<RhodantheResponse> execute(RhodantheRequest request) async {
    requests.add(request);
    if (request.command == "openDocument" && failOpen) {
      return _failure(request.requestId, "unavailable");
    }
    switch (request.command) {
      case "openDocument":
        _documentId = request.arguments!["documentId"]! as String;
        _documentRevision = request.arguments!["revision"]! as int;
        _textLength = (request.arguments!["fullText"]! as String).length;
        return _success(request.requestId, <String, Object?>{
          "kind": "opened",
          "documentId": _documentId,
          "revision": _documentRevision,
        });
      case "applyEdits":
        _documentRevision = request.arguments!["revision"]! as int;
        final edit =
            (request.arguments!["edits"]! as List<Object?>).single
                as Map<String, Object?>;
        _textLength =
            _textLength -
            (edit["endUtf16"]! as int) +
            (edit["startUtf16"]! as int) +
            (edit["replacement"]! as String).length;
        return _success(request.requestId, <String, Object?>{
          "kind": "edited",
          "documentId": _documentId,
          "revision": _documentRevision,
        });
      case "analyze":
        if (analysisFailuresRemaining > 0) {
          analysisFailuresRemaining--;
          return _failure(request.requestId, "temporaryFailure");
        }
        return _analysis(request.requestId);
      case "closeDocument":
        return _success(request.requestId, <String, Object?>{
          "kind": "closed",
          "documentId": _documentId,
        });
      default:
        return _success(request.requestId, const <String, Object?>{});
    }
  }

  RhodantheResponse _analysis(int? requestId) {
    return RhodantheResponse.fromJson(<String, Object?>{
      "ok": true,
      "contractVersion": 1,
      "requestId": requestId,
      "result": <String, Object?>{
        "kind": "analysis",
        "search": <String, Object?>{
          "totalMatches": analysisRanges.length,
          "annotations": <Object?>[
            for (var index = 0; index < analysisRanges.length; index++)
              <String, Object?>{"range": analysisRanges[index].toJson()},
          ],
        },
        "filler": null,
        "renderPlan": <String, Object?>{
          "documentId": _documentId,
          "revision": _documentRevision,
          "plan": <String, Object?>{
            "contractVersion": 1,
            "textLenUtf16": _textLength,
            "runs": <Object?>[
              for (final range in analysisRanges)
                <String, Object?>{
                  "range": range.toJson(),
                  "styleTokenSetId": 0,
                  "annotationIds": <String>["search"],
                },
            ],
            "tokenSets": analysisRanges.isEmpty
                ? <Object?>[]
                : <Object?>[
                    <String, Object?>{
                      "foreground": null,
                      "background": "search.match.background",
                      "weight": null,
                      "slant": null,
                      "decoration": null,
                      "interaction": null,
                    },
                  ],
          },
        },
      },
    });
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

RhodantheResponse _success(int? requestId, Map<String, Object?> result) =>
    RhodantheResponse.fromJson(<String, Object?>{
      "ok": true,
      "contractVersion": 1,
      "requestId": requestId,
      "result": result,
    });

RhodantheResponse _failure(int? requestId, String code) =>
    RhodantheResponse.fromJson(<String, Object?>{
      "ok": false,
      "contractVersion": 1,
      "requestId": requestId,
      "error": <String, Object?>{"code": code, "message": code},
    });

RhodantheVersionedRenderPlan _versionedPlan({
  required int revision,
  required String text,
}) {
  return RhodantheVersionedRenderPlan(
    documentId: "chapter",
    revision: revision,
    plan: RhodantheRenderPlan(
      contractVersion: 1,
      textLenUtf16: text.length,
      runs: <RhodantheRenderRun>[
        RhodantheRenderRun(
          range: RhodantheRange(0, text.length),
          styleTokenSetId: 0,
          annotationIds: const <String>["search"],
        ),
      ],
      tokenSets: const <RhodantheStyleTokenSet>[
        RhodantheStyleTokenSet(background: "search.match.background"),
      ],
    ),
  );
}
