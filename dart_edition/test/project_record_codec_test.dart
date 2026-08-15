import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/application/collaboration/project_record_codec.dart";
import "package:monogatari_assistant/domain/collaboration/collaboration_operation.dart";
import "package:monogatari_assistant/models/base_info_data.dart";
import "package:monogatari_assistant/models/chapter_selection_data.dart";
import "package:monogatari_assistant/models/character_data.dart";
import "package:monogatari_assistant/models/character_snapshot_data.dart";
import "package:monogatari_assistant/models/outline_data.dart";
import "package:monogatari_assistant/models/plan_data.dart";
import "package:monogatari_assistant/models/project_data.dart";
import "package:monogatari_assistant/models/timeline_data.dart";
import "package:monogatari_assistant/models/world_settings_data.dart";

void main() {
  test("ProjectData typed records round-trip without chapter text or XML", () {
    final project = _complexProject();
    final records = ProjectRecordCodec.snapshot(project);
    final encoded = jsonEncode(
      records.map(
        (key, value) =>
            MapEntry("${key.kind.name}:${key.recordId}", value.toJson()),
      ),
    );

    expect(encoded, isNot(contains("chapter body")));
    expect(encoded, isNot(contains("xmlContent")));
    expect(encoded, isNot(contains("<Project")));

    final rebuilt = ProjectData(
      projectUUID: project.projectUUID,
      baseInfoData: ProjectRecordCodec.decodeBaseInfo(records),
      segmentsData: ProjectRecordCodec.decodeSegments(
        records,
        const <String, String>{"chapter-1": "chapter body"},
      ),
      outlineData: ProjectRecordCodec.decodeOutline(records),
      foreshadowData: ProjectRecordCodec.decodeForeshadows(records),
      updatePlanData: ProjectRecordCodec.decodeUpdatePlans(records),
      worldSettingsData: ProjectRecordCodec.decodeWorldSettings(records),
      characterData: ProjectRecordCodec.decodeCharacters(records),
      characterStates: ProjectRecordCodec.decodeCharacterStates(records),
      characterStateBaselines: ProjectRecordCodec.decodeCharacterBaselines(
        records,
      ),
      characterStateChanges: ProjectRecordCodec.decodeCharacterChanges(records),
      timelineDocument: ProjectRecordCodec.decodeTimeline(records),
      outlineChapterLinks: ProjectRecordCodec.decodeOutlineChapterLinks(
        records,
      ),
    );
    final rebuiltRecords = ProjectRecordCodec.snapshot(rebuilt);

    expect(
      rebuilt.segmentsData.single.chapters.single.chapterContent,
      "chapter body",
    );
    expect(rebuiltRecords.keys, unorderedEquals(records.keys));
    for (final entry in records.entries) {
      expect(
        jsonEncode(rebuiltRecords[entry.key]?.toJson()),
        jsonEncode(entry.value.toJson()),
        reason: "record ${entry.key.kind.name}:${entry.key.recordId}",
      );
    }
  });

  test("collaboration receiver shell invents no structural record ids", () {
    const projectUuid = "33333333-3333-4333-8333-333333333333";
    final records = ProjectRecordCodec.snapshot(
      ProjectData.collaborationShell(projectUUID: projectUuid),
      omitCollaborativeText: true,
    );

    expect(records.keys.map((key) => key.kind).toSet(), <ProjectRecordKind>{
      ProjectRecordKind.baseInfo,
      ProjectRecordKind.timelineGrid,
    });
  });

  test(
    "chapter body changes produce CRDT only, metadata changes produce typed op",
    () {
      final before = _complexProject();
      final contentOnly = _complexProject();
      contentOnly.segmentsData = <SegmentData>[
        contentOnly.segmentsData.single.copyWith(
          chapters: <ChapterData>[
            contentOnly.segmentsData.single.chapters.single.copyWith(
              chapterContent: "new CRDT text",
            ),
          ],
        ),
      ];
      final renamed = _complexProject();
      renamed.segmentsData = <SegmentData>[
        renamed.segmentsData.single.copyWith(
          chapters: <ChapterData>[
            renamed.segmentsData.single.chapters.single.copyWith(
              chapterName: "Renamed",
            ),
          ],
        ),
      ];

      expect(
        ProjectRecordCodec.diff(
          ProjectRecordCodec.snapshot(before),
          ProjectRecordCodec.snapshot(contentOnly),
        ),
        isEmpty,
      );
      final metadataOperations = ProjectRecordCodec.diff(
        ProjectRecordCodec.snapshot(before),
        ProjectRecordCodec.snapshot(renamed),
      );
      expect(metadataOperations, hasLength(1));
      expect(
        metadataOperations.single.recordKind,
        ProjectRecordKind.chapterMetadata,
      );
    },
  );
}

ProjectData _complexProject() {
  const projectUuid = "33333333-3333-4333-8333-333333333333";
  const conflict = CharacterConflict(obstacle: "wall", resolution: "climb");
  const relationship = CharacterRelationship(
    person: "friend",
    relationship: "ally",
  );
  const profile = CharacterProfileTableEntry(
    name: "guild",
    description: "member",
  );
  const possession = CharacterPossessionEntry(
    name: "key",
    quantity: "1",
    description: "old",
  );
  final character = CharacterEntryData(
    characterId: "character-1",
    displayName: "Alice",
    aliases: const <CharacterAlias>[
      CharacterAlias(type: "nickname", values: <String>["A"]),
    ],
    roleOrOccupation: "Writer",
    age: "20",
    gender: "F",
    appearanceSummary: "appearance",
    personalitySummary: "personality",
    speechStyle: "quiet",
    motivation: "finish",
    goal: "publish",
    conflicts: const <CharacterConflict>[conflict],
    valuesAndBeliefs: "truth",
    fear: "failure",
    relationshipSummary: "friends",
    relationships: const <CharacterRelationship>[relationship],
    characterType: "主角",
    organizations: const <CharacterProfileTableEntry>[profile],
    possessions: const <CharacterPossessionEntry>[possession],
    statusEntries: const <CharacterProfileTableEntry>[profile],
    notes: "notes",
    advanced: const CharacterAdvancedProfile(
      commonAbilities: <String, double>{"writing": 0.8},
      socialTraits: <String, double>{"social": 0.2},
      approaches: <String, double>{"direct": 0.5},
      personalityTraits: <String, double>{"calm": 0.7},
    ),
    customFields: const <String, CustomFieldValue>{
      "voice": CustomFieldValue(rawValue: "soft"),
    },
    legacyFields: const <String, String>{"nanoId": "Abcd_123"},
    textFields: const <String, String>{"name": "Alice"},
    alignment: "good",
    hinderEvents: const <CharacterHinderEvent>[
      CharacterHinderEvent(event: "wall", solve: "climb"),
    ],
    loveToDoList: const <String>["write"],
    hateToDoList: const <String>["wait"],
    wantToDoList: const <String>["publish"],
    fearToDoList: const <String>["fail"],
    proficientToDoList: const <String>["edit"],
    unProficientToDoList: const <String>["draw"],
    commonAbilityValues: const <double>[0.8],
    howToShowLove: const <String, bool>{"help": true},
    howToShowGoodwill: const <String, bool>{"smile": true},
    handleHatePeople: const <String, bool>{"avoid": true},
    socialItemValues: const <double>[0.2],
    relationship: "single",
    isFindNewLove: true,
    isHarem: false,
    approachValues: const <double>[0.5],
    traitsValues: const <double>[0.7],
    likeItemList: const <String>["book"],
    admireItemList: const <String>["pen"],
    hateItemList: const <String>["noise"],
    fearItemList: const <String>["fire"],
    familiarItemList: const <String>["desk"],
  );
  final patch = CharacterStatePatch(
    conflicts: const <CharacterConflict>[conflict],
    relationships: const <CharacterRelationship>[relationship],
    organizations: const <CharacterProfileTableEntry>[profile],
    statusEntries: const <CharacterProfileTableEntry>[profile],
    possessions: const <CharacterPossessionEntry>[possession],
    customFields: const <String, CustomFieldValue>{
      "voice": CustomFieldValue(rawValue: "loud"),
    },
  );
  return ProjectData(
    projectUUID: projectUuid,
    baseInfoData: const BaseInfoData(
      bookName: "Book",
      author: "Author",
      purpose: "Novel",
      toRecap: "Recap",
      storyType: "Fantasy",
      intro: "Intro",
      tags: <String>["tag"],
    ),
    segmentsData: <SegmentData>[
      SegmentData(
        segmentUUID: "folder-1",
        segmentName: "Folder",
        chapters: <ChapterData>[
          ChapterData(
            chapterUUID: "chapter-1",
            chapterName: "Chapter",
            chapterContent: "chapter body",
          ),
        ],
        childNodeOrder: const <String>["chapter-1"],
      ),
    ],
    outlineData: <StorylineData>[
      StorylineData(
        chapterUUID: "storyline-1",
        storylineName: "Line",
        storylineType: "Main",
        memo: "memo",
        conflictPoint: "conflict",
        people: const <String>["Alice"],
        item: const <String>["Key"],
        scenes: <StoryEventData>[
          StoryEventData(
            storyEventUUID: "event-1",
            storyEvent: "Event",
            memo: "memo",
            conflictPoint: "conflict",
            people: const <String>["Alice"],
            item: const <String>["Key"],
            scenes: <SceneData>[
              SceneData(
                sceneUUID: "scene-1",
                sceneName: "Scene",
                time: "noon",
                timePointIso8601: "2026-01-01T12:00:00.000",
                location: "Town",
                focusPoint: "focus",
                conflictPoint: "conflict",
                people: const <String>["Alice"],
                item: const <String>["Key"],
                doingThings: const <String>["Walk"],
                memo: "memo",
              ),
            ],
          ),
        ],
      ),
    ],
    foreshadowData: <ForeshadowItem>[
      ForeshadowItem(id: "foreshadow-1", title: "Hint", note: "note"),
    ],
    updatePlanData: <UpdatePlanItem>[
      UpdatePlanItem(id: "plan-1", title: "Plan", note: "note"),
    ],
    worldSettingsData: <LocationData>[
      LocationData(
        id: "world-1",
        localName: "Town",
        localType: "City",
        nodeType: WorldNodeType.location,
        customVal: <LocationCustomize>[
          LocationCustomize(id: "custom-1", key: "weather", val: "rain"),
        ],
        note: "note",
      ),
    ],
    characterData: <String, CharacterEntryData>{"character-1": character},
    characterStates: const <CharacterState>[
      CharacterState(
        characterId: "character-1",
        storyTimePointId: "scene-1",
        location: "Town",
        healthStatus: "good",
        emotion: "happy",
        alignment: "good",
        possessions: <String>["key"],
      ),
    ],
    characterStateBaselines: <String, CharacterStateBaseline>{
      "character-1": CharacterStateBaseline(
        characterId: "character-1",
        patch: patch,
        note: "baseline",
      ),
    },
    characterStateChanges: <CharacterStateChange>[
      CharacterStateChange(
        stateChangeId: "change-1",
        characterId: "character-1",
        sceneUUID: "scene-1",
        sourcePlacementUUID: "placement-1",
        fallbackTick: 10,
        sequence: 1,
        patch: patch,
        note: "change",
      ),
    ],
    timelineDocument: const TimelineDocumentData(
      grid: TimelineGridConfig(
        ticksPerLittleBox: TickDurationData(
          value: 2,
          unit: TickDurationUnit.hour,
          customLabel: "",
        ),
        ticksPerSmallBox: 2,
        ticksPerMiddleBox: 4,
        middleBoxesPerLargeBox: 6,
        autoSortOutline: false,
        originLabel: "Start",
        originIso8601: "2026-01-01T00:00:00.000",
      ),
      tracks: <TimelineTrackData>[
        TimelineTrackData(
          trackUUID: "track-1",
          name: "Track",
          order: 0,
          colorToken: "blue",
        ),
      ],
      placements: <TimelinePlacementData>[
        TimelinePlacementData(
          placementUUID: "placement-1",
          storylineUUID: "storyline-1",
          eventUUID: "event-1",
          sceneUUID: "scene-1",
          level: TimelineElementLevel.small,
          trackUUID: "track-1",
          startTick: 10,
          durationTicks: 2,
          order: 0,
          label: "Scene",
        ),
      ],
    ),
    outlineChapterLinks: const <OutlineChapterLinkData>[
      OutlineChapterLinkData(
        linkUUID: "link-1",
        sceneUUID: "scene-1",
        chapterUUID: "chapter-1",
        sequence: 0,
        coverage: ChapterLinkCoverage.full,
        note: "note",
      ),
    ],
  );
}
