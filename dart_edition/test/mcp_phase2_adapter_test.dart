import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/mcp/application/mcp_cursor_codec.dart";
import "package:monogatari_assistant/features/mcp/application/monoashi_mcp_adapter.dart";
import "package:monogatari_assistant/features/mcp/domain/mcp_gateway.dart";
import "package:monogatari_assistant/features/mcp/domain/mcp_protocol_models.dart";
import "package:monogatari_assistant/features/story_read/application/project_read_snapshot_builder.dart";
import "package:monogatari_assistant/features/story_read/domain/project_read_models.dart";

import "fixtures/mcp_phase0_project_fixtures.dart";

void main() {
  group("MonoAshiMcpAdapter", () {
    late McpPhase0ProjectFixture fixture;
    late MonoAshiMcpSession session;
    late MonoAshiMcpAdapter adapter;

    setUp(() {
      fixture = McpPhase0ProjectFixtures.small();
      final snapshot = ProjectReadSnapshotBuilder.build(
        fixture.project,
        glossaryEntries: fixture.glossaryEntries,
      );
      session = MonoAshiMcpSession.forSnapshot(
        sessionId: "test-session",
        generation: 7,
        snapshot: snapshot,
      );
      adapter = MonoAshiMcpAdapter(
        gateway: FixedMonoAshiMcpGateway(session),
        cursorCodec: MonoAshiMcpCursorCodec.forTesting(
          List<int>.generate(32, (index) => index),
        ),
      );
    });

    test("project summary uses a session-scoped project id", () async {
      final result = await adapter.callTool(
        MonoAshiMcpContract.getProjectSummary,
        const <String, dynamic>{},
      );
      final resource = result["resource"] as Map<String, dynamic>;

      expect(result["schemaVersion"], "1");
      expect(result["snapshotGeneration"], 7);
      expect(result["projectId"], startsWith("project-"));
      expect(result["projectId"], isNot(fixture.project.projectUUID));
      expect(resource["id"], result["projectId"]);
      expect(resource["fingerprint"], session.snapshot.overview.fingerprint);
      expect(resource["sourceUri"], contains("/project/summary"));
    });

    test("chapter pagination uses a signed query-scoped cursor", () async {
      final first = await adapter.callTool(
        MonoAshiMcpContract.listChapters,
        const <String, dynamic>{"limit": 1},
      );
      final cursor = first["nextCursor"] as String;
      final second = await adapter.callTool(
        MonoAshiMcpContract.listChapters,
        <String, dynamic>{"limit": 1, "cursor": cursor},
      );

      expect((first["items"] as List).single["id"], fixture.primaryChapterId);
      expect((second["items"] as List).single["id"], "chapter-small-002");
      expect(second["nextCursor"], isNull);

      final tampered = "${cursor.substring(0, cursor.length - 1)}A";
      await expectLater(
        adapter.callTool(MonoAshiMcpContract.listChapters, <String, dynamic>{
          "cursor": tampered,
        }),
        throwsA(
          isA<MonoAshiMcpException>().having(
            (error) => error.code,
            "code",
            MonoAshiMcpErrorCode.invalidCursor,
          ),
        ),
      );
    });

    test("entity search cursor cannot be replayed for another query", () async {
      final first = await adapter.callTool(
        MonoAshiMcpContract.searchProjectEntities,
        const <String, dynamic>{"query": "", "limit": 1},
      );
      final cursor = first["nextCursor"] as String;

      await expectLater(
        adapter.callTool(
          MonoAshiMcpContract.searchProjectEntities,
          <String, dynamic>{"query": "旅人", "limit": 1, "cursor": cursor},
        ),
        throwsA(
          isA<MonoAshiMcpException>().having(
            (error) => error.code,
            "code",
            MonoAshiMcpErrorCode.invalidCursor,
          ),
        ),
      );
    });

    test("all read tools return bounded structured envelopes", () async {
      final chapter = await adapter.callTool(
        MonoAshiMcpContract.getChapter,
        <String, dynamic>{
          "chapterId": fixture.primaryChapterId,
          "maxBytes": 32,
        },
      );
      final search = await adapter.callTool(
        MonoAshiMcpContract.searchProjectEntities,
        const <String, dynamic>{
          "query": "旅人",
          "types": <String>[ProjectReadResourceType.character],
        },
      );
      final entity = await adapter.callTool(
        MonoAshiMcpContract.getProjectEntity,
        const <String, dynamic>{
          "type": ProjectReadResourceType.character,
          "id": "character-small-001",
          "maxBytes": 128,
        },
      );
      final context = await adapter.callTool(
        MonoAshiMcpContract.getContextBundle,
        <String, dynamic>{
          "chapterId": fixture.primaryChapterId,
          "resourceRefs": const <Map<String, dynamic>>[
            <String, dynamic>{
              "type": ProjectReadResourceType.character,
              "id": "character-small-001",
            },
          ],
        },
      );

      expect((chapter["resource"] as Map)["truncated"], isTrue);
      expect((search["items"] as List), hasLength(1));
      expect((entity["resource"] as Map)["truncated"], isTrue);
      expect(
        context["fingerprint"],
        session.snapshot.chapterById(fixture.primaryChapterId) == null
            ? isNull
            : isA<String>(),
      );
      for (final result in <Map<String, dynamic>>[
        chapter,
        search,
        entity,
        context,
      ]) {
        expect(
          utf8.encode(jsonEncode(result)).length,
          lessThanOrEqualTo(ProjectReadBudget.maxToolResultBytes),
        );
      }
    });

    test("resources are traceable and reject stale sessions", () async {
      final resources = await adapter.listResources();
      final chapterDescriptor = resources.firstWhere(
        (resource) => resource.uri.contains("/chapter/"),
      );
      final result = await adapter.readResource(
        Uri.parse(chapterDescriptor.uri),
      );

      expect((result["resource"] as Map)["id"], fixture.primaryChapterId);
      await expectLater(
        adapter.readResource(
          Uri.parse(
            chapterDescriptor.uri.replaceFirst("test-session", "stale-session"),
          ),
        ),
        throwsA(
          isA<MonoAshiMcpException>().having(
            (error) => error.code,
            "code",
            MonoAshiMcpErrorCode.notFound,
          ),
        ),
      );
    });

    test(
      "strict input, cancellation, and disconnected gateway fail safely",
      () async {
        await expectLater(
          adapter.callTool(
            MonoAshiMcpContract.getProjectSummary,
            const <String, dynamic>{"unexpected": true},
          ),
          throwsA(isA<MonoAshiMcpException>()),
        );
        await expectLater(
          adapter.callTool(
            MonoAshiMcpContract.getProjectSummary,
            const <String, dynamic>{},
            isCancelled: () => true,
          ),
          throwsA(
            isA<MonoAshiMcpException>().having(
              (error) => error.code,
              "code",
              MonoAshiMcpErrorCode.cancelled,
            ),
          ),
        );
        final disconnected = MonoAshiMcpAdapter(
          gateway: const DisconnectedMonoAshiMcpGateway(),
        );
        await expectLater(
          disconnected.callTool(
            MonoAshiMcpContract.getProjectSummary,
            const <String, dynamic>{},
          ),
          throwsA(
            isA<MonoAshiMcpException>().having(
              (error) => error.code,
              "code",
              MonoAshiMcpErrorCode.unavailable,
            ),
          ),
        );
      },
    );
  });
}
