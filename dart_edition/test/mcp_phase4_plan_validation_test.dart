import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/copilot/domain/copilot_models.dart";
import "package:monogatari_assistant/features/mcp/application/monoashi_mcp_adapter.dart";
import "package:monogatari_assistant/features/mcp/domain/mcp_gateway.dart";
import "package:monogatari_assistant/features/mcp/domain/mcp_protocol_models.dart";
import "package:monogatari_assistant/features/story_read/application/project_read_service.dart";
import "package:monogatari_assistant/features/story_read/application/project_read_snapshot_builder.dart";
import "package:monogatari_assistant/features/story_read/domain/project_read_models.dart";

import "fixtures/mcp_phase0_project_fixtures.dart";

void main() {
  group("Phase 4 readonly plan parity", () {
    late McpPhase0ProjectFixture fixture;
    late MonoAshiMcpSession session;
    late MonoAshiMcpAdapter adapter;

    setUp(() {
      fixture = McpPhase0ProjectFixtures.small();
      session = MonoAshiMcpSession.forSnapshot(
        sessionId: "phase4-session",
        generation: 11,
        snapshot: ProjectReadSnapshotBuilder.build(
          fixture.project,
          glossaryEntries: fixture.glossaryEntries,
        ),
      );
      adapter = MonoAshiMcpAdapter(gateway: FixedMonoAshiMcpGateway(session));
    });

    test(
      "Copilot and MCP share canonical context fingerprint and allowlists",
      () async {
        final entity = session.snapshot.entityByRef(
          const ProjectReadResourceRef(
            resourceType: ProjectReadResourceType.character,
            resourceId: "character-small-001",
          ),
        )!;
        final bundle = ProjectReadService.buildContextBundle(
          session.snapshot,
          chapterId: fixture.primaryChapterId,
          resourceRefs: const <ProjectReadResourceRef>[
            ProjectReadResourceRef(
              resourceType: ProjectReadResourceType.character,
              resourceId: "character-small-001",
            ),
          ],
        );
        final copilot = CopilotContextSnapshot.currentChapter(
          chapterId: fixture.primaryChapterId,
          title: bundle.primary.title,
          content: bundle.primary.content,
          supplementalResources: <CopilotContextResource>[
            CopilotContextResource.bounded(
              resourceType: entity.resourceType,
              resourceId: entity.resourceId,
              title: entity.title,
              content: entity.content,
              maxBytes: ProjectReadBudget.maxSelectedResourceBytes,
            ),
          ],
        );
        final mcp = await _context(adapter, fixture);

        expect(mcp["fingerprint"], copilot.fingerprint);
        expect(
          CopilotPlan.allowedActions,
          containsAll(<String>["review", "create"]),
        );
        expect(
          MonoAshiMcpContract.readToolNames,
          contains("validate_readonly_plan"),
        );
      },
    );

    test(
      "valid plan returns canonical JSON and resolved target metadata",
      () async {
        final context = await _context(adapter, fixture);
        final fingerprint = context["fingerprint"]! as String;
        final plan = _plan(fingerprint, fixture.primaryChapterId);

        final result = await adapter.callTool(
          MonoAshiMcpContract.validateReadonlyPlan,
          <String, dynamic>{"contextFingerprint": fingerprint, "plan": plan},
        );

        expect(result["valid"], isTrue);
        expect(result["stale"], isFalse);
        expect(result["errors"], isEmpty);
        expect((result["resolvedTargets"] as List).single, <String, Object?>{
          "type": "chapter",
          "id": fixture.primaryChapterId,
          "title": isA<String>(),
        });
        final canonical = result["plan"] as Map;
        expect(canonical["schemaVersion"], "1");
        expect(jsonEncode(canonical), jsonEncode(plan));
      },
    );

    test("stale and unknown contexts fail as data without throwing", () async {
      final context = await _context(adapter, fixture);
      final fingerprint = context["fingerprint"]! as String;
      final stalePlan = _plan("old-fingerprint", fixture.primaryChapterId);

      final stale = await adapter.callTool(
        MonoAshiMcpContract.validateReadonlyPlan,
        <String, dynamic>{"contextFingerprint": fingerprint, "plan": stalePlan},
      );
      final missing = await adapter
          .callTool(MonoAshiMcpContract.validateReadonlyPlan, <String, dynamic>{
            "contextFingerprint": "missing",
            "plan": _plan("missing", fixture.primaryChapterId),
          });

      expect(stale["valid"], isFalse);
      expect(stale["stale"], isTrue);
      expect((stale["errors"] as List).single["code"], "staleContext");
      expect(missing["valid"], isFalse);
      expect(missing["stale"], isTrue);
    });

    test(
      "validation is read-only and rejects unknown fields and actions",
      () async {
        final before = jsonEncode(
          ProjectReadService.buildContextBundle(
            session.snapshot,
            chapterId: fixture.primaryChapterId,
          ).primary.toContextJson(),
        );
        final context = await _context(adapter, fixture);
        final fingerprint = context["fingerprint"]! as String;
        final plan = _plan(fingerprint, fixture.primaryChapterId);
        final step = (plan["steps"]! as List).single as Map<String, Object?>;
        step["action"] = "execute";
        step["unexpected"] = true;

        final result = await adapter.callTool(
          MonoAshiMcpContract.validateReadonlyPlan,
          <String, dynamic>{"contextFingerprint": fingerprint, "plan": plan},
        );
        final after = jsonEncode(
          ProjectReadService.buildContextBundle(
            session.snapshot,
            chapterId: fixture.primaryChapterId,
          ).primary.toContextJson(),
        );

        expect(result["valid"], isFalse);
        expect((result["errors"] as List).single["code"], "invalidField");
        expect(after, before);
      },
    );
  });
}

Future<Map<String, dynamic>> _context(
  MonoAshiMcpAdapter adapter,
  McpPhase0ProjectFixture fixture,
) => adapter.callTool(MonoAshiMcpContract.getContextBundle, <String, dynamic>{
  "chapterId": fixture.primaryChapterId,
  "resourceRefs": const <Map<String, dynamic>>[
    <String, dynamic>{
      "type": ProjectReadResourceType.character,
      "id": "character-small-001",
    },
  ],
});

Map<String, Object?> _plan(String fingerprint, String chapterId) =>
    <String, Object?>{
      "schemaVersion": "1",
      "goal": "檢查伏筆",
      "summary": "檢查目前章節的伏筆",
      "contextFingerprint": fingerprint,
      "steps": <Object?>[
        <String, Object?>{
          "id": "step-1",
          "order": 1,
          "targetType": "chapter",
          "targetId": chapterId,
          "action": "review",
          "reason": "確認線索是否足夠",
          "proposal": "檢查開場對話",
          "dependsOn": <String>[],
        },
      ],
      "risks": <String>["可能過早揭露"],
      "questions": <String>[],
    };
