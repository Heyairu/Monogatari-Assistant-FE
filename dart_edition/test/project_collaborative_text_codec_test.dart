import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/application/collaboration/project_collaborative_text_codec.dart";
import "package:monogatari_assistant/application/collaboration/project_record_codec.dart";
import "package:monogatari_assistant/domain/collaboration/collaboration_operation.dart";
import "package:monogatari_assistant/domain/collaboration/typed_operation_log.dart";
import "package:monogatari_assistant/models/character_data.dart";
import "package:monogatari_assistant/models/outline_data.dart";
import "package:monogatari_assistant/models/project_data.dart";
import "package:monogatari_assistant/models/world_settings_data.dart";

void main() {
  test("stable ProjectData text documents project back to their owners", () {
    final project = ProjectData.empty(
      projectUUID: "44444444-4444-4444-8444-444444444444",
    );
    project.outlineData = <StorylineData>[
      StorylineData(
        chapterUUID: "storyline-1",
        storylineName: "主線",
        memo: "舊大綱",
      ),
    ];
    project.characterData = <String, CharacterEntryData>{
      "character-1": CharacterEntryData(
        characterId: "character-1",
        displayName: "Alice",
        notes: "舊角色描述",
        textFields: const <String, String>{"notes": "舊角色描述"},
      ),
    };
    project.worldSettingsData = <LocationData>[
      LocationData(id: "world-1", localName: "城鎮", note: "舊世界描述"),
    ];

    final snapshot = ProjectCollaborativeTextCodec.snapshot(project);
    final outlineId = ProjectCollaborativeTextCodec.outlineStorylineFieldId(
      "storyline-1",
      "memo",
    );
    final characterId = ProjectCollaborativeTextCodec.characterFieldId(
      "character-1",
      "notes",
    );
    final worldId = ProjectCollaborativeTextCodec.worldNodeFieldId(
      "world-1",
      "note",
    );

    expect(snapshot[outlineId], "舊大綱");
    expect(snapshot[characterId], "舊角色描述");
    expect(snapshot[worldId], "舊世界描述");
    expect(
      ProjectCollaborativeTextCodec.applyToOutline(
        project.outlineData,
        outlineId,
        "新大綱",
      ).single.memo,
      "新大綱",
    );
    expect(
      ProjectCollaborativeTextCodec.applyToCharacters(
        project.characterData,
        characterId,
        "新角色描述",
      )["character-1"]?.notes,
      "新角色描述",
    );
    expect(
      ProjectCollaborativeTextCodec.applyToWorldSettings(
        project.worldSettingsData,
        worldId,
        "新世界描述",
      ).single.note,
      "新世界描述",
    );
  });

  test("typed records ignore CRDT-owned text but retain structure", () {
    final before = ProjectData.empty(
      projectUUID: "55555555-5555-4555-8555-555555555555",
    );
    final storyline = before.outlineData.single;
    Map<ProjectRecordKey, ProjectRecordOperation> records(ProjectData data) =>
        ProjectRecordCodec.snapshot(data, omitCollaborativeText: true);

    final beforeRecords = records(before);
    before.outlineData = <StorylineData>[
      storyline.copyWith(memo: "concurrent CRDT text"),
    ];
    final textChangedRecords = records(before);
    expect(ProjectRecordCodec.diff(beforeRecords, textChangedRecords), isEmpty);
    before.outlineData = <StorylineData>[
      before.outlineData.single.copyWith(people: const <String>["character-1"]),
    ];
    final operations = ProjectRecordCodec.diff(
      textChangedRecords,
      records(before),
    );
    expect(operations, hasLength(1));
    expect(operations.single.fields["people"], <String>["character-1"]);
  });
}
