import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_editor_session.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_protocol.dart";

void main() {
  test("analyze request encodes the versioned combined-analyzer contract", () {
    final request = RhodantheRequest.analyze(
      requestId: 8,
      documentId: "chapter",
      revision: 4,
      search: const RhodantheSearchRequest(
        query: "test",
        queryRevision: 3,
        activeMatchIndex: 1,
      ),
      filler: const RhodantheFillerRequest(
        dictionaryRevision: 5,
        words: <String>["真的"],
        budget: RhodantheFillerBudget(maxAnnotations: 32),
      ),
    );

    final json = jsonDecode(request.encode()) as Map<String, Object?>;
    expect(json["contractVersion"], 1);
    expect(json["requestId"], 8);
    expect(json["command"], "analyze");
    final arguments = json["arguments"]! as Map<String, Object?>;
    expect(arguments["compactResponse"], isTrue);
    final search = arguments["search"]! as Map<String, Object?>;
    final options = search["options"]! as Map<String, Object?>;
    expect(options["matchCase"], isTrue);
    expect(options["matchWidth"], isTrue);
    expect(options["useRegexp"], isFalse);
    expect(search["activeMatchIndex"], 1);
    final filler = arguments["filler"]! as Map<String, Object?>;
    expect(filler["words"], <String>["真的"]);
    expect(filler["budget"], <String, Object?>{"maxAnnotations": 32});
  });

  test("analyze request encodes Ring 4 and Ring 8 external annotations", () {
    final request = RhodantheRequest.analyze(
      documentId: "chapter",
      revision: 9,
      externalAnnotations: const <RhodantheExternalAnnotation>[
        RhodantheExternalAnnotation(
          annotationId: "mention:alice",
          source: "mention",
          sourceOrder: 0,
          ring: 4,
          range: RhodantheRange(0, 5),
          style: RhodantheStyleTokenSet(
            foreground: "mention.resolved.foreground",
            weight: "medium",
            interaction: "mention:alice",
          ),
          payloadId: "alice",
        ),
        RhodantheExternalAnnotation(
          annotationId: "diagnostic:typo",
          source: "diagnostic",
          sourceOrder: 1,
          ring: 8,
          range: RhodantheRange(6, 10),
          style: RhodantheStyleTokenSet(
            decoration: RhodantheDecoration(
              lines: <String>["underline"],
              style: "dotted",
              color: "diagnostic.decoration",
              thickness: 1,
            ),
          ),
        ),
      ],
    );

    final json = jsonDecode(request.encode()) as Map<String, Object?>;
    final arguments = json["arguments"]! as Map<String, Object?>;
    final annotations = arguments["externalAnnotations"]! as List<Object?>;
    final mention = annotations.first as Map<String, Object?>;
    final diagnostic = annotations.last as Map<String, Object?>;
    expect(mention["ring"], 4);
    expect(mention["payloadId"], "alice");
    expect((mention["style"]! as Map<String, Object?>)["weight"], "medium");
    expect(diagnostic["ring"], 8);
  });

  test("handshake decodes versioned runtime capabilities", () {
    final capabilities = RhodantheCapabilities.fromResponse(
      RhodantheResponse.fromJson(<String, Object?>{
        "ok": true,
        "contractVersion": 1,
        "requestId": 1,
        "result": <String, Object?>{
          "kind": "handshake",
          "abiVersion": 1,
          "contractVersion": 1,
          "capabilities": <String>[
            "openDocument",
            "applyEdits",
            "analyzeSearch",
            "analyzeFiller",
            "analyzeExternalAnnotations",
            "compactAnalysisV1",
            "closeDocument",
          ],
        },
      }),
    );

    expect(capabilities.isVersionCompatible, isTrue);
    expect(
      capabilities.supportsAll(
        requiredCapabilitiesFor(RhodantheRolloutMode.full),
      ),
      isTrue,
    );
  });

  test("analysis response decodes render runs and semantic style tokens", () {
    final response = RhodantheResponse.decode(
      jsonEncode(<String, Object?>{
        "ok": true,
        "contractVersion": 1,
        "requestId": 2,
        "result": <String, Object?>{
          "kind": "analysis",
          "search": <String, Object?>{"totalMatches": 1},
          "filler": null,
          "renderPlan": <String, Object?>{
            "documentId": "chapter",
            "revision": 7,
            "plan": <String, Object?>{
              "contractVersion": 1,
              "textLenUtf16": 6,
              "runs": <Object?>[
                <String, Object?>{
                  "range": <String, Object?>{"start": 2, "end": 6},
                  "styleTokenSetId": 0,
                  "annotationIds": <String>["search:1:0"],
                },
              ],
              "tokenSets": <Object?>[
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
      }),
    );

    final analysis = RhodantheAnalysisResult.fromResponse(response);
    expect(analysis.renderPlan.documentId, "chapter");
    expect(analysis.renderPlan.revision, 7);
    expect(analysis.renderPlan.plan.textLenUtf16, 6);
    expect(analysis.renderPlan.plan.runs.single.range.start, 2);
    expect(analysis.renderPlan.plan.runs.single.range.end, 6);
    expect(
      analysis.renderPlan.plan.tokenSets.single.background,
      "search.match.background",
    );
  });

  test("compact analysis decodes flat search ranges and render runs", () {
    final response = RhodantheResponse.fromJson(<String, Object?>{
      "ok": true,
      "contractVersion": 1,
      "result": <String, Object?>{
        "kind": "analysis",
        "responseFormat": "compactV1",
        "search": <String, Object?>{
          "totalMatches": 2,
          "truncated": false,
          "activeMatchId": "search:1:1",
          "rangesUtf16": <int>[0, 4, 8, 12],
        },
        "filler": null,
        "renderPlan": <String, Object?>{
          "documentId": "chapter",
          "revision": 3,
          "plan": <String, Object?>{
            "contractVersion": 1,
            "textLenUtf16": 12,
            "runsUtf16": <int>[0, 4, 0, 8, 12, 0],
            "tokenSets": <Object?>[
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

    final analysis = RhodantheAnalysisResult.fromResponse(response);
    expect(
      analysis.searchRanges
          .map((range) => <int>[range.start, range.end])
          .toList(),
      <List<int>>[
        <int>[0, 4],
        <int>[8, 12],
      ],
    );
    expect(analysis.renderPlan.plan.runs, hasLength(2));
    expect(analysis.renderPlan.plan.runs.last.annotationIds, isEmpty);
  });

  test("failed response throws its structured error from requireResult", () {
    final response = RhodantheResponse.fromJson(<String, Object?>{
      "ok": false,
      "contractVersion": 1,
      "requestId": 9,
      "error": <String, Object?>{
        "code": "revisionMismatch",
        "message": "stale",
      },
    });

    expect(response.ok, isFalse);
    expect(
      response.requireResult,
      throwsA(
        isA<RhodantheFailure>().having(
          (error) => error.code,
          "code",
          "revisionMismatch",
        ),
      ),
    );
  });

  test("malformed response fields are rejected", () {
    expect(
      () => RhodantheResponse.decode(
        '{"ok":true,"contractVersion":"one","result":{}}',
      ),
      throwsFormatException,
    );
  });
}
