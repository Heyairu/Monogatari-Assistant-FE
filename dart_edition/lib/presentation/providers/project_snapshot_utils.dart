import "dart:collection";

import "../../bin/file.dart";
import "../../models/character_data.dart" as character_model;
import "../../modules/baseinfoview.dart" as base_info_module;
import "../../modules/chapterselectionview.dart" as chapter_module;
import "../../modules/outlineview.dart" as outline_module;
import "../../modules/planview.dart" as plan_module;
import "../../modules/worldsettingsview.dart" as world_settings_module;

List<T> _freezeListCopy<T>(List<T> source) {
  if (source is UnmodifiableListView<T>) {
    return source;
  }
  return List<T>.unmodifiable(source);
}

List<T> _freezeListView<T>(List<T> source) {
  if (source is UnmodifiableListView<T>) {
    return source;
  }
  return UnmodifiableListView<T>(source);
}

Map<K, V> _freezeMapView<K, V>(Map<K, V> source) {
  if (source is UnmodifiableMapView<K, V>) {
    return source;
  }
  return UnmodifiableMapView<K, V>(source);
}

base_info_module.BaseInfoData snapshotBaseInfoData(
  base_info_module.BaseInfoData value,
) {
  final nextTags = _freezeListCopy(value.tags);
  if (identical(nextTags, value.tags)) {
    return value;
  }
  return value.copyWith(tags: nextTags);
}

List<chapter_module.SegmentData> snapshotSegmentsData(
  List<chapter_module.SegmentData> source,
) {
  final List<chapter_module.SegmentData> frozen = [];
  for (final segment in source) {
    final frozenChapters = _freezeListCopy(segment.chapters);
    final nextSegment = identical(frozenChapters, segment.chapters)
        ? segment
        : segment.copyWith(chapters: frozenChapters);
    frozen.add(nextSegment);
  }
  return _freezeListView(frozen);
}

List<outline_module.StorylineData> snapshotOutlineData(
  List<outline_module.StorylineData> source,
) {
  outline_module.SceneData freezeScene(outline_module.SceneData scene) {
    final people = _freezeListCopy(scene.people);
    final item = _freezeListCopy(scene.item);
    final doingThings = _freezeListCopy(scene.doingThings);
    if (identical(people, scene.people) &&
        identical(item, scene.item) &&
        identical(doingThings, scene.doingThings)) {
      return scene;
    }
    return scene.copyWith(
      people: people,
      item: item,
      doingThings: doingThings,
    );
  }

  outline_module.StoryEventData freezeEvent(
    outline_module.StoryEventData event,
  ) {
    final people = _freezeListCopy(event.people);
    final item = _freezeListCopy(event.item);
    final List<outline_module.SceneData> scenes = [];
    for (final scene in event.scenes) {
      scenes.add(freezeScene(scene));
    }
    final frozenScenes = _freezeListView(scenes);
    if (identical(people, event.people) &&
        identical(item, event.item) &&
        identical(frozenScenes, event.scenes)) {
      return event;
    }
    return event.copyWith(
      people: people,
      item: item,
      scenes: frozenScenes,
    );
  }

  final List<outline_module.StorylineData> frozen = [];
  for (final storyline in source) {
    final people = _freezeListCopy(storyline.people);
    final item = _freezeListCopy(storyline.item);
    final List<outline_module.StoryEventData> events = [];
    for (final event in storyline.scenes) {
      events.add(freezeEvent(event));
    }
    final frozenEvents = _freezeListView(events);

    final nextStoryline = identical(people, storyline.people) &&
            identical(item, storyline.item) &&
            identical(frozenEvents, storyline.scenes)
        ? storyline
        : storyline.copyWith(
            people: people,
            item: item,
            scenes: frozenEvents,
          );
    frozen.add(nextStoryline);
  }

  return _freezeListView(frozen);
}

List<plan_module.ForeshadowItem> snapshotForeshadowData(
  List<plan_module.ForeshadowItem> source,
) {
  return _freezeListCopy(source);
}

List<plan_module.UpdatePlanItem> snapshotUpdatePlanData(
  List<plan_module.UpdatePlanItem> source,
) {
  return _freezeListCopy(source);
}

List<world_settings_module.LocationData> snapshotWorldSettingsData(
  List<world_settings_module.LocationData> source,
) {
  final copied = source
      .map((location) => location.deepCopy())
      .toList(growable: false);
  return _freezeListView(copied);
}

Map<String, character_model.CharacterEntryData> snapshotCharacterData(
  Map<String, character_model.CharacterEntryData> source,
) {
  final copied = character_model.copyCharacterDataMap(source);
  return _freezeMapView(copied);
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
