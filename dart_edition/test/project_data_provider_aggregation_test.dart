import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

import "package:monogatari_assistant/modules/baseinfoview.dart"
    as base_info_module;
import "package:monogatari_assistant/modules/chapterselectionview.dart"
    as chapter_module;
import "package:monogatari_assistant/modules/outlineview.dart"
    as outline_module;
import "package:monogatari_assistant/modules/planview.dart" as plan_module;
import "package:monogatari_assistant/modules/worldsettingsview.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";

void main() {
  group("Phase 5 projectDataProvider aggregation", () {
    test("aggregates all migrated provider values", () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final baseInfo = base_info_module.BaseInfoData()..bookName = "聚合測試書名";
      final segments = <chapter_module.SegmentData>[
        chapter_module.SegmentData(
          segmentName: "Seg-A",
          chapters: <chapter_module.ChapterData>[
            chapter_module.ChapterData(
              chapterName: "Chapter-A",
              chapterContent: "內容A",
            ),
          ],
        ),
      ];
      final outline = <outline_module.StorylineData>[
        outline_module.StorylineData(
          storylineName: "主線A",
          storylineType: "主線",
          memo: "OutlineMemo",
        ),
      ];
      final foreshadow = <plan_module.ForeshadowItem>[
        plan_module.ForeshadowItem(title: "伏筆A", note: "伏筆備註"),
      ];
      final updatePlan = <plan_module.UpdatePlanItem>[
        plan_module.UpdatePlanItem(title: "更新A", note: "更新備註", isDone: true),
      ];
      final worldSettings = <LocationData>[
        LocationData(localName: "東京", localType: "城市"),
      ];
      final character = <String, Map<String, dynamic>>{
        "Alice": <String, dynamic>{"name": "Alice", "role": "主角"},
      };

      container.read(baseInfoDataProvider.notifier).setBaseInfoData(baseInfo);
      container.read(segmentsDataProvider.notifier).setSegmentsData(segments);
      container.read(outlineDataProvider.notifier).setOutlineData(outline);
      container.read(foreshadowDataProvider.notifier).setForeshadowData(foreshadow);
      container.read(updatePlanDataProvider.notifier).setUpdatePlanData(updatePlan);
      container
          .read(worldSettingsDataProvider.notifier)
          .setWorldSettingsData(worldSettings);
      container.read(characterDataProvider.notifier).setCharacterData(character);
      container.read(totalWordsProvider.notifier).setTotalWords(321);
      container.read(editorContentProvider.notifier).setContent("聚合內容");

      final aggregated = container.read(projectDataProvider);

      expect(aggregated.baseInfoData.bookName, "聚合測試書名");
      expect(aggregated.segmentsData.first.segmentName, "Seg-A");
      expect(aggregated.segmentsData.first.chapters.first.chapterName, "Chapter-A");
      expect(aggregated.outlineData.first.storylineName, "主線A");
      expect(aggregated.foreshadowData.first.title, "伏筆A");
      expect(aggregated.updatePlanData.first.title, "更新A");
      expect(aggregated.updatePlanData.first.isDone, isTrue);
      expect(aggregated.worldSettingsData.first.localName, "東京");
      expect(aggregated.characterData["Alice"]?["role"], "主角");
      expect(aggregated.totalWords, 321);
      expect(aggregated.contentText, "聚合內容");
    });

    test("reflects later source-provider updates", () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = container.read(projectDataProvider);
      expect(initial.totalWords, 0);
      expect(initial.contentText, "");

      container.read(totalWordsProvider.notifier).setTotalWords(999);
      container.read(editorContentProvider.notifier).setContent("after-update");

      final updated = container.read(projectDataProvider);
      expect(updated.totalWords, 999);
      expect(updated.contentText, "after-update");
    });
  });
}
