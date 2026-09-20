import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/copilot/application/copilot_project_context_builder.dart";
import "package:monogatari_assistant/features/copilot/domain/copilot_models.dart";
import "package:monogatari_assistant/features/story_read/application/project_read_service.dart";
import "package:monogatari_assistant/features/story_read/application/project_read_snapshot_builder.dart";
import "package:monogatari_assistant/features/story_read/domain/project_read_models.dart";
import "package:monogatari_assistant/models/base_info_data.dart";
import "package:monogatari_assistant/models/character_data.dart";
import "package:monogatari_assistant/models/project_data.dart";

import "fixtures/mcp_phase0_project_fixtures.dart";

void main() {
  group("ProjectReadSnapshotBuilder", () {
    test("captures an immutable read snapshot", () {
      final fixture = McpPhase0ProjectFixtures.small();
      final snapshot = ProjectReadSnapshotBuilder.build(
        fixture.project,
        glossaryEntries: fixture.glossaryEntries,
      );
      final originalOverview = snapshot.overview.content;
      final originalCharacter = snapshot.entities.firstWhere(
        (entity) => entity.resourceId == "character-small-001",
      );

      fixture.project.baseInfoData = const BaseInfoData(bookName: "修改後作品");
      fixture.project.characterData = <String, CharacterEntryData>{};

      expect(snapshot.overview.content, originalOverview);
      expect(originalCharacter.content, contains("找出星紋鑰匙的來源"));
      expect(snapshot.chapters, hasLength(2));
      expect(
        () => snapshot.chapters.add(snapshot.chapters.first),
        throwsUnsupportedError,
      );
    });

    test("omits duplicate stable IDs and records the reason", () {
      final project =
          ProjectData.empty(projectUUID: "00000000-0000-4000-8000-000000000004")
            ..characterData = <String, CharacterEntryData>{
              "source-a": const CharacterEntryData(
                characterId: "duplicate-character",
                displayName: "A",
              ),
              "source-b": const CharacterEntryData(
                characterId: "duplicate-character",
                displayName: "B",
              ),
            };

      final snapshot = ProjectReadSnapshotBuilder.build(project);

      expect(
        snapshot.entities.where(
          (entity) => entity.resourceId == "duplicate-character",
        ),
        hasLength(1),
      );
      expect(snapshot.omissions, hasLength(1));
      expect(snapshot.omissions.single.reason, "duplicate_id");
      expect(snapshot.omissions.single.sourceKey, "source-b");
    });
  });

  group("ProjectReadService", () {
    late McpPhase0ProjectFixture fixture;
    late ProjectReadSnapshot snapshot;

    setUp(() {
      fixture = McpPhase0ProjectFixtures.small();
      snapshot = ProjectReadSnapshotBuilder.build(
        fixture.project,
        glossaryEntries: fixture.glossaryEntries,
      );
    });

    test("lists chapters without exposing bodies and paginates", () {
      final first = ProjectReadService.listChapters(snapshot, limit: 1);
      final second = ProjectReadService.listChapters(
        snapshot,
        offset: first.nextOffset!,
        limit: 1,
      );

      expect(first.total, 2);
      expect(first.items.single.chapterId, fixture.primaryChapterId);
      expect(first.nextOffset, 1);
      expect(second.items.single.chapterId, "chapter-small-002");
      expect(second.nextOffset, isNull);
    });

    test("searches by title, description, ID, and type", () {
      final byTitle = ProjectReadService.searchEntities(snapshot, query: "旅人");
      final byType = ProjectReadService.searchEntities(
        snapshot,
        query: "",
        resourceTypes: const <String>{ProjectReadResourceType.glossaryTerm},
      );
      final byId = ProjectReadService.searchEntities(
        snapshot,
        query: "world-small-002",
      );

      expect(byTitle.items.single.resourceId, "character-small-001");
      expect(byType.items.single.resourceId, "glossary-small-001");
      expect(byId.items.single.title, "舊燈塔");
      expect(
        () => ProjectReadService.searchEntities(
          snapshot,
          query: "",
          resourceTypes: const <String>{"unsupported"},
        ),
        throwsFormatException,
      );
    });

    test("resolves one bounded entity and rejects excess budgets", () {
      const ref = ProjectReadResourceRef(
        resourceType: ProjectReadResourceType.character,
        resourceId: "character-small-001",
      );
      final resource = ProjectReadService.getEntity(
        snapshot,
        ref: ref,
        maxBytes: 128,
      );

      expect(resource, isNotNull);
      expect(resource!.resourceId, ref.resourceId);
      expect(resource.truncated, isTrue);
      expect(
        () => ProjectReadService.getEntity(
          snapshot,
          ref: ref,
          maxBytes: ProjectReadBudget.maxSelectedResourceBytes + 1,
        ),
        throwsRangeError,
      );
    });

    test("builds the project-overview scope with Copilot parity", () {
      final bundle = ProjectReadService.buildContextBundle(
        snapshot,
        chapterId: fixture.primaryChapterId,
        includeProjectOverview: true,
      );
      final copilotOverview = CopilotProjectContextBuilder.buildOverview(
        fixture.project,
      );
      final copilot = CopilotContextSnapshot.currentChapter(
        chapterId: bundle.primary.resourceId,
        title: bundle.primary.title,
        content: bundle.primary.content,
        supplementalResources: <CopilotContextResource>[copilotOverview],
      );

      expect(bundle.supplementalResources.single.toContextJson(), {
        "type": copilotOverview.resourceType,
        "id": copilotOverview.resourceId,
        "title": copilotOverview.title,
        "truncated": copilotOverview.truncated,
        "content": copilotOverview.content,
      });
      expect(bundle.fingerprint, copilot.fingerprint);
    });

    test("builds selected resources with byte-identical Copilot parity", () {
      const refs = <ProjectReadResourceRef>[
        ProjectReadResourceRef(
          resourceType: ProjectReadResourceType.character,
          resourceId: "character-small-001",
        ),
        ProjectReadResourceRef(
          resourceType: ProjectReadResourceType.worldSetting,
          resourceId: "world-small-002",
        ),
      ];
      final bundle = ProjectReadService.buildContextBundle(
        snapshot,
        chapterId: fixture.primaryChapterId,
        resourceRefs: refs,
      );
      final reversedBundle = ProjectReadService.buildContextBundle(
        snapshot,
        chapterId: fixture.primaryChapterId,
        resourceRefs: refs.reversed,
      );
      final copilotResources =
          CopilotProjectContextBuilder.buildSelectedResources(
            fixture.project,
            selectionKeys: refs.map((ref) => ref.selectionKey).toSet(),
            glossaryEntries: fixture.glossaryEntries,
          );
      final copilot = CopilotContextSnapshot.currentChapter(
        chapterId: bundle.primary.resourceId,
        title: bundle.primary.title,
        content: bundle.primary.content,
        supplementalResources: copilotResources,
      );

      expect(
        bundle.supplementalResources.map(
          (resource) => resource.toContextJson(),
        ),
        copilotResources.map((resource) => resource.toJson()),
      );
      expect(bundle.fingerprint, copilot.fingerprint);
      expect(reversedBundle.fingerprint, bundle.fingerprint);
    });

    test("rejects mixed scopes and optionally rejects missing refs", () {
      const missing = ProjectReadResourceRef(
        resourceType: ProjectReadResourceType.character,
        resourceId: "missing",
      );

      expect(
        () => ProjectReadService.buildContextBundle(
          snapshot,
          chapterId: fixture.primaryChapterId,
          includeProjectOverview: true,
          resourceRefs: const <ProjectReadResourceRef>[missing],
        ),
        throwsFormatException,
      );
      expect(
        () => ProjectReadService.buildContextBundle(
          snapshot,
          chapterId: fixture.primaryChapterId,
          resourceRefs: const <ProjectReadResourceRef>[missing],
          rejectMissing: true,
        ),
        throwsFormatException,
      );
    });
  });
}
