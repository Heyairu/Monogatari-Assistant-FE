import "../../bin/file.dart";
import "../../models/character_data.dart" as character_model;
import "../../modules/baseinfoview.dart" as base_info_module;
import "../../modules/chapterselectionview.dart" as chapter_module;
import "../../modules/outlineview.dart" as outline_module;
import "../../modules/planview.dart" as plan_module;
import "../../modules/worldsettingsview.dart" as world_settings_module;

base_info_module.BaseInfoData snapshotBaseInfoData(
  base_info_module.BaseInfoData value,
) {
  return value.copyWith(tags: [...value.tags]);
}

List<chapter_module.SegmentData> snapshotSegmentsData(
  List<chapter_module.SegmentData> source,
) {
  return source
      .map(
        (segment) => segment.copyWith(
          chapters: segment.chapters
              .map((chapter) => chapter.copyWith())
              .toList(growable: false),
        ),
      )
      .toList(growable: false);
}

List<outline_module.StorylineData> snapshotOutlineData(
  List<outline_module.StorylineData> source,
) {
  return source
      .map(
        (storyline) => storyline.copyWith(
          people: [...storyline.people],
          item: [...storyline.item],
          scenes: storyline.scenes
              .map(
                (event) => event.copyWith(
                  people: [...event.people],
                  item: [...event.item],
                  scenes: event.scenes
                      .map(
                        (scene) => scene.copyWith(
                          people: [...scene.people],
                          item: [...scene.item],
                          doingThings: [...scene.doingThings],
                        ),
                      )
                      .toList(growable: false),
                ),
              )
              .toList(growable: false),
        ),
      )
      .toList(growable: false);
}

List<plan_module.ForeshadowItem> snapshotForeshadowData(
  List<plan_module.ForeshadowItem> source,
) {
  return source.map((item) => item.copyWith()).toList(growable: false);
}

List<plan_module.UpdatePlanItem> snapshotUpdatePlanData(
  List<plan_module.UpdatePlanItem> source,
) {
  return source.map((item) => item.copyWith()).toList(growable: false);
}

List<world_settings_module.LocationData> snapshotWorldSettingsData(
  List<world_settings_module.LocationData> source,
) {
  return source.map((location) => location.deepCopy()).toList(growable: false);
}

Map<String, character_model.CharacterEntryData> snapshotCharacterData(
  Map<String, character_model.CharacterEntryData> source,
) {
  return character_model.copyCharacterDataMap(source);
}

ProjectData snapshotProjectData(
  ProjectData source, {
  base_info_module.BaseInfoData? baseInfoOverride,
}) {
  return ProjectData(
    baseInfoData: snapshotBaseInfoData(baseInfoOverride ?? source.baseInfoData),
    segmentsData: snapshotSegmentsData(source.segmentsData),
    outlineData: snapshotOutlineData(source.outlineData),
    foreshadowData: snapshotForeshadowData(source.foreshadowData),
    updatePlanData: snapshotUpdatePlanData(source.updatePlanData),
    worldSettingsData: snapshotWorldSettingsData(source.worldSettingsData),
    characterData: snapshotCharacterData(source.characterData),
    totalWords: source.totalWords,
    contentText: source.contentText,
    isDirty: source.isDirty,
  );
}
