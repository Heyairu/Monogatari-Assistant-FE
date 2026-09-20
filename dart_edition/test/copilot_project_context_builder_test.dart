import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/copilot/application/copilot_project_context_builder.dart";
import "package:monogatari_assistant/models/base_info_data.dart";
import "package:monogatari_assistant/models/chapter_selection_data.dart";
import "package:monogatari_assistant/models/character_data.dart";
import "package:monogatari_assistant/models/glossary_data.dart";
import "package:monogatari_assistant/models/outline_data.dart";
import "package:monogatari_assistant/models/project_data.dart";
import "package:monogatari_assistant/models/world_settings_data.dart";

void main() {
  test("builds an overview index without including chapter bodies", () {
    final project = ProjectData.empty()
      ..baseInfoData = const BaseInfoData(
        bookName: "測試作品",
        storyType: "奇幻",
        intro: "作品簡介",
      )
      ..segmentsData = <SegmentData>[
        SegmentData(
          segmentName: "第一部",
          chapters: <ChapterData>[
            ChapterData(
              chapterUUID: "chapter-1",
              chapterName: "第一章",
              chapterContent: "不應出現在專案摘要的正文秘密",
            ),
          ],
        ),
      ]
      ..characterData = <String, CharacterEntryData>{
        "character-1": const CharacterEntryData(
          characterId: "character-1",
          displayName: "小明",
          goal: "找到真相",
        ),
      };

    final overview = CopilotProjectContextBuilder.buildOverview(project);
    final decoded = jsonDecode(overview.content) as Map<String, Object?>;

    expect(overview.resourceId, "project-overview");
    expect(overview.truncated, isFalse);
    expect(overview.content, contains("測試作品"));
    expect(overview.content, contains("小明"));
    expect(overview.content, isNot(contains("正文秘密")));
    expect(decoded["chapters"], isA<List<Object?>>());
  });

  test("bounds a large project overview", () {
    final project = ProjectData.empty()
      ..baseInfoData = BaseInfoData(
        bookName: "大型作品",
        intro: "設定" * CopilotProjectContextBuilder.maxOverviewBytes,
      );

    final overview = CopilotProjectContextBuilder.buildOverview(project);

    expect(overview.truncated, isTrue);
    expect(
      utf8.encode(overview.content).length,
      lessThanOrEqualTo(CopilotProjectContextBuilder.maxOverviewBytes),
    );
  });

  test("selectable resource catalog is deterministic across data types", () {
    final project = ProjectData.empty()
      ..characterData = <String, CharacterEntryData>{
        "character-b": const CharacterEntryData(
          characterId: "character-b",
          displayName: "Beta",
        ),
        "character-a": const CharacterEntryData(
          characterId: "character-a",
          displayName: "Alpha",
        ),
      }
      ..worldSettingsData = <LocationData>[
        LocationData(id: "world-1", localName: "王城"),
      ]
      ..outlineData = <StorylineData>[
        StorylineData(
          chapterUUID: "outline-1",
          storylineName: "序章",
          scenes: <StoryEventData>[
            StoryEventData(storyEventUUID: "event-1", storyEvent: "相遇"),
          ],
        ),
      ];
    final glossary = <String, GlossaryEntry>{
      "term-1": GlossaryEntry(
        id: "term-1",
        term: "魔力",
        partOfSpeech: GlossaryPartOfSpeech.noun,
        customPartOfSpeech: "",
        polarity: GlossaryPolarity.neutral,
        pairs: <GlossaryPair>[GlossaryPair(meaning: "施法能量")],
      ),
    };

    final resources = CopilotProjectContextBuilder.selectableResources(
      project,
      glossaryEntries: glossary,
    );

    expect(resources.map((resource) => resource.selectionKey), <String>[
      "character:character-a",
      "character:character-b",
      "worldSetting:world-1",
      "outlineEvent:outline-1",
      "outlineEvent:event-1",
      "glossaryTerm:term-1",
    ]);
  });

  test("selected resources include only explicit choices", () {
    final project = ProjectData.empty()
      ..characterData = <String, CharacterEntryData>{
        "selected": const CharacterEntryData(
          characterId: "selected",
          displayName: "被選角色",
          notes: "允許傳送的角色秘密",
        ),
        "excluded": const CharacterEntryData(
          characterId: "excluded",
          displayName: "未選角色",
          notes: "不可傳送的角色秘密",
        ),
      }
      ..worldSettingsData = <LocationData>[
        LocationData(
          id: "world-selected",
          localName: "被選地點",
          note: "允許傳送的地點設定",
        ),
      ];

    final resources = CopilotProjectContextBuilder.buildSelectedResources(
      project,
      selectionKeys: const <String>{
        "character:selected",
        "worldSetting:world-selected",
      },
    );
    final combined = resources.map((resource) => resource.content).join();

    expect(resources, hasLength(2));
    expect(resources.map((resource) => resource.resourceId), <String>[
      "selected",
      "world-selected",
    ]);
    expect(combined, contains("允許傳送的角色秘密"));
    expect(combined, contains("允許傳送的地點設定"));
    expect(combined, isNot(contains("不可傳送的角色秘密")));
  });

  test("selected resources obey count and aggregate byte budgets", () {
    final project = ProjectData.empty()
      ..characterData = <String, CharacterEntryData>{
        for (var index = 0; index < 13; index++)
          "character-$index": CharacterEntryData(
            characterId: "character-$index",
            displayName: "角色 $index",
            notes: "資料" * CopilotProjectContextBuilder.maxSelectedResourceBytes,
          ),
      };
    final allowedKeys = <String>{
      for (
        var index = 0;
        index < CopilotProjectContextBuilder.maxSelectedResources;
        index++
      )
        "character:character-$index",
    };

    final resources = CopilotProjectContextBuilder.buildSelectedResources(
      project,
      selectionKeys: allowedKeys,
    );
    final totalBytes = resources.fold<int>(
      0,
      (total, resource) => total + utf8.encode(resource.content).length,
    );

    expect(resources.length, lessThanOrEqualTo(12));
    expect(
      totalBytes,
      lessThanOrEqualTo(CopilotProjectContextBuilder.maxSelectedResourcesBytes),
    );
    expect(
      () => CopilotProjectContextBuilder.buildSelectedResources(
        project,
        selectionKeys: <String>{...allowedKeys, "character:character-12"},
      ),
      throwsFormatException,
    );
  });
}
