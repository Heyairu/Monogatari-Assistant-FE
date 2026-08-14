import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/data/p2p/p2p_project_merge.dart";
import "package:monogatari_assistant/domain/models/p2p_revision_models.dart";
import "package:monogatari_assistant/domain/models/p2p_sync_models.dart";
import "package:monogatari_assistant/models/character_data.dart";
import "package:monogatari_assistant/models/chapter_selection_data.dart";
import "package:monogatari_assistant/models/project_data.dart";

const _projectUuid = "11111111-1111-4111-8111-111111111111";
const _baseDevice = "22222222-2222-4222-8222-222222222222";
const _localDevice = "33333333-3333-4333-8333-333333333333";
const _remoteDevice = "44444444-4444-4444-8444-444444444444";

P2pRevisionMetadata _revision({
  required String idCharacter,
  required String deviceId,
  required Map<String, int> clock,
  List<String> parents = const <String>[],
}) => P2pRevisionMetadata(
  revisionId: idCharacter * 64,
  projectUuid: _projectUuid,
  parents: parents,
  clock: P2pVersionVector(clock),
  authorDeviceId: deviceId,
  createdAtEpochSeconds: 1,
  contentSha256: idCharacter * 64,
  formatVersion: "1",
);

ProjectData _project(CharacterEntryData character) {
  final project = ProjectData.empty(projectUUID: _projectUuid);
  project.characterData = <String, CharacterEntryData>{
    character.displayName: character,
  };
  return project;
}

void main() {
  final baseRevision = _revision(
    idCharacter: "a",
    deviceId: _baseDevice,
    clock: const <String, int>{_baseDevice: 1},
  );
  final localRevision = _revision(
    idCharacter: "b",
    deviceId: _localDevice,
    clock: const <String, int>{_baseDevice: 1, _localDevice: 1},
    parents: <String>[baseRevision.revisionId],
  );
  final remoteRevision = _revision(
    idCharacter: "c",
    deviceId: _remoteDevice,
    clock: const <String, int>{_baseDevice: 1, _remoteDevice: 1},
    parents: <String>[baseRevision.revisionId],
  );

  test(
    "ProjectData merge combines table rows and conflicts only same field",
    () {
      const characterId = "character-lia";
      const baseCharacter = CharacterEntryData(
        characterId: characterId,
        displayName: "莉亞",
        personalitySummary: "冷靜",
        relationships: <CharacterRelationship>[
          CharacterRelationship(person: "莉香", relationship: "朋友"),
        ],
        possessions: <CharacterPossessionEntry>[
          CharacterPossessionEntry(
            name: "懷錶",
            quantity: "1",
            description: "舊物",
          ),
        ],
      );
      final local = baseCharacter.copyWith(
        personalitySummary: "果斷",
        relationships: <CharacterRelationship>[
          ...baseCharacter.relationships,
          const CharacterRelationship(person: "洛可", relationship: "同伴"),
        ],
        possessions: <CharacterPossessionEntry>[
          baseCharacter.possessions.single.copyWith(quantity: "2"),
        ],
      );
      final remote = baseCharacter.copyWith(
        personalitySummary: "溫柔",
        relationships: <CharacterRelationship>[
          ...baseCharacter.relationships,
          const CharacterRelationship(person: "米雅", relationship: "導師"),
        ],
        possessions: <CharacterPossessionEntry>[
          baseCharacter.possessions.single.copyWith(description: "母親遺物"),
        ],
      );

      final plan = const P2pProjectMergeEngine().createPlan(
        sessionId: "session-1",
        baseRevision: baseRevision,
        localRevision: localRevision,
        remoteRevision: remoteRevision,
        base: _project(baseCharacter),
        local: _project(local),
        remote: _project(remote),
      );

      expect(plan.conflicts, hasLength(1));
      expect(plan.conflicts.single.groupLabel, "角色：莉亞");
      expect(plan.conflicts.single.fieldPath, "衝突欄位 > 性格");
      final merged = plan.apply(
        P2pConflictResolutionResult(<String, P2pConflictSide>{
          plan.conflicts.single.conflictId: P2pConflictSide.remote,
        }),
      );
      final result = merged.characterData.values.single;
      expect(result.personalitySummary, "溫柔");
      expect(
        result.relationships.map((item) => item.person),
        containsAll(<String>["莉香", "洛可", "米雅"]),
      );
      expect(result.possessions.single.quantity, "2");
      expect(result.possessions.single.description, "母親遺物");
      expect(merged.isDirty, isTrue);
    },
  );

  test("merge rejects duplicate normalized relationship keys", () {
    const character = CharacterEntryData(
      characterId: "character-lia",
      displayName: "莉亞",
      relationships: <CharacterRelationship>[
        CharacterRelationship(person: "莉香", relationship: "朋友"),
        CharacterRelationship(person: " 莉香 ", relationship: "敵人"),
      ],
    );
    expect(
      () => const P2pProjectMergeEngine().createPlan(
        sessionId: "session-1",
        baseRevision: baseRevision,
        localRevision: localRevision,
        remoteRevision: remoteRevision,
        base: _project(character),
        local: _project(character),
        remote: _project(character),
      ),
      throwsFormatException,
    );
  });

  test("merge plan rejects stale heads before apply", () {
    final plan = const P2pProjectMergeEngine().createPlan(
      sessionId: "session-1",
      baseRevision: baseRevision,
      localRevision: localRevision,
      remoteRevision: remoteRevision,
      base: _project(const CharacterEntryData(characterId: "lia")),
      local: _project(const CharacterEntryData(characterId: "lia")),
      remote: _project(const CharacterEntryData(characterId: "lia")),
    );
    expect(
      plan.matchesHeads(
        activeSessionId: "session-1",
        headRevisionIds: <String>[
          localRevision.revisionId,
          remoteRevision.revisionId,
        ],
      ),
      isTrue,
    );
    expect(
      plan.matchesHeads(
        activeSessionId: "session-2",
        headRevisionIds: <String>[localRevision.revisionId],
      ),
      isFalse,
    );
  });

  test("production merge session ID is accepted", () {
    final sessionId =
        "$_localDevice:${localRevision.revisionId}:${remoteRevision.revisionId}";
    expect(sessionId, hasLength(166));

    final plan = const P2pProjectMergeEngine().createPlan(
      sessionId: sessionId,
      baseRevision: baseRevision,
      localRevision: localRevision,
      remoteRevision: remoteRevision,
      base: _project(const CharacterEntryData(characterId: "lia")),
      local: _project(const CharacterEntryData(characterId: "lia")),
      remote: _project(const CharacterEntryData(characterId: "lia")),
    );

    expect(plan.sessionId, sessionId);
  });

  test("oversized merge session ID is rejected", () {
    final sessionId = "x" * (P2pProjectMergeEngine.maxSessionIdLength + 1);

    expect(
      () => const P2pProjectMergeEngine().createPlanWithoutCommonAncestor(
        sessionId: sessionId,
        localRevision: localRevision,
        remoteRevision: remoteRevision,
        local: _project(const CharacterEntryData(characterId: "lia")),
        remote: _project(const CharacterEntryData(characterId: "lia")),
        localRemainderSignature: "local",
        remoteRemainderSignature: "remote",
      ),
      throwsFormatException,
    );
  });

  test("one-sided non-character sections are preserved without conflict", () {
    final base = _project(const CharacterEntryData(characterId: "lia"));
    final local = _project(const CharacterEntryData(characterId: "lia"));
    final remote = _project(const CharacterEntryData(characterId: "lia"));
    remote.segmentsData = <SegmentData>[
      remote.segmentsData.single.copyWith(
        chapters: <ChapterData>[
          remote.segmentsData.single.chapters.single.copyWith(
            chapterContent: "遠端新增內容",
          ),
        ],
      ),
    ];
    final plan = const P2pProjectMergeEngine().createPlan(
      sessionId: "session-1",
      baseRevision: baseRevision,
      localRevision: localRevision,
      remoteRevision: remoteRevision,
      base: base,
      local: local,
      remote: remote,
      remainderSignatures: const P2pProjectRemainderSignatures(
        base: "base",
        local: "base",
        remote: "remote",
      ),
    );

    expect(plan.conflicts, isEmpty);
    final merged = plan.apply(
      P2pConflictResolutionResult(const <String, P2pConflictSide>{}),
    );
    expect(merged.segmentsData.single.chapters.single.chapterContent, "遠端新增內容");
  });

  test("unrelated histories merge fields and preserve distinct table keys", () {
    const characterId = "character-lia";
    final local = _project(
      const CharacterEntryData(
        characterId: characterId,
        displayName: "莉亞",
        personalitySummary: "冷靜",
        relationships: <CharacterRelationship>[
          CharacterRelationship(person: "洛可", relationship: "同伴"),
        ],
      ),
    );
    final remote = _project(
      const CharacterEntryData(
        characterId: characterId,
        displayName: "莉亞",
        personalitySummary: "果斷",
        relationships: <CharacterRelationship>[
          CharacterRelationship(person: "米雅", relationship: "導師"),
        ],
      ),
    );

    final plan = const P2pProjectMergeEngine().createPlanWithoutCommonAncestor(
      sessionId: "unrelated-session",
      localRevision: localRevision,
      remoteRevision: remoteRevision,
      local: local,
      remote: remote,
      localRemainderSignature: "same-remainder",
      remoteRemainderSignature: "same-remainder",
    );

    expect(plan.baseRevision, isNull);
    final personalityConflict = plan.conflicts.singleWhere(
      (item) => item.fieldPath == "衝突欄位 > 性格",
    );
    final merged = plan.apply(
      P2pConflictResolutionResult(<String, P2pConflictSide>{
        for (final conflict in plan.conflicts)
          conflict.conflictId: conflict == personalityConflict
              ? P2pConflictSide.remote
              : P2pConflictSide.local,
      }),
    );
    final character = merged.characterData.values.single;
    expect(character.personalitySummary, "果斷");
    expect(
      character.relationships.map((item) => item.person),
      containsAll(<String>["洛可", "米雅"]),
    );
  });
}
