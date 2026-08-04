import "dart:collection";

import "../../models/base_info_data.dart" as base_info_module;
import "../../models/chapter_selection_data.dart" as chapter_module;
import "../../models/character_data.dart" as character_model;
import "../../models/outline_data.dart" as outline_module;
import "../../models/plan_data.dart" as plan_module;
import "../../models/project_data.dart";
import "../../models/world_settings_data.dart" as world_settings_module;

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
  chapter_module.SegmentData freezeSegment(chapter_module.SegmentData segment) {
    final frozenChapters = _freezeListCopy(segment.chapters);
    final frozenChildren = _freezeListView(
      segment.childSegments.map(freezeSegment).toList(growable: false),
    );
    final frozenOrder = _freezeListCopy(segment.resolvedChildNodeOrder);
    return identical(frozenChapters, segment.chapters) &&
            identical(frozenChildren, segment.childSegments) &&
            identical(frozenOrder, segment.childNodeOrder)
        ? segment
        : segment.copyWith(
            chapters: frozenChapters,
            childSegments: frozenChildren,
            childNodeOrder: frozenOrder,
          );
  }

  return _freezeListView(source.map(freezeSegment).toList(growable: false));
}

List<outline_module.StorylineData> snapshotOutlineData(
  List<outline_module.StorylineData> source,
) {
  outline_module.SceneData freezeScene(outline_module.SceneData scene) {
    if (scene.people is UnmodifiableListView<String> &&
        scene.item is UnmodifiableListView<String> &&
        scene.doingThings is UnmodifiableListView<String>) {
      return scene;
    }
    final people = _freezeListCopy(scene.people);
    final item = _freezeListCopy(scene.item);
    final doingThings = _freezeListCopy(scene.doingThings);
    if (identical(people, scene.people) &&
        identical(item, scene.item) &&
        identical(doingThings, scene.doingThings)) {
      return scene;
    }
    return scene.copyWith(people: people, item: item, doingThings: doingThings);
  }

  outline_module.StoryEventData freezeEvent(
    outline_module.StoryEventData event,
  ) {
    if (event.people is UnmodifiableListView<String> &&
        event.item is UnmodifiableListView<String> &&
        event.scenes is UnmodifiableListView<outline_module.SceneData>) {
      return event;
    }
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
    return event.copyWith(people: people, item: item, scenes: frozenScenes);
  }

  final List<outline_module.StorylineData> frozen = [];
  for (final storyline in source) {
    if (storyline.people is UnmodifiableListView<String> &&
        storyline.item is UnmodifiableListView<String> &&
        storyline.scenes
            is UnmodifiableListView<outline_module.StoryEventData>) {
      frozen.add(storyline);
      continue;
    }
    final people = _freezeListCopy(storyline.people);
    final item = _freezeListCopy(storyline.item);
    final List<outline_module.StoryEventData> events = [];
    for (final event in storyline.scenes) {
      events.add(freezeEvent(event));
    }
    final frozenEvents = _freezeListView(events);

    final nextStoryline =
        identical(people, storyline.people) &&
            identical(item, storyline.item) &&
            identical(frozenEvents, storyline.scenes)
        ? storyline
        : storyline.copyWith(people: people, item: item, scenes: frozenEvents);
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
  world_settings_module.LocationData freezeLocation(
    world_settings_module.LocationData location,
  ) {
    if (location.customVal
            is UnmodifiableListView<world_settings_module.LocationCustomize> &&
        location.child
            is UnmodifiableListView<world_settings_module.LocationData>) {
      return location;
    }
    final customValues = _freezeListCopy(location.customVal);
    final children = _freezeListView(
      location.child.map(freezeLocation).toList(growable: false),
    );
    if (identical(customValues, location.customVal) &&
        identical(children, location.child)) {
      return location;
    }
    return location.copyWith(customVal: customValues, child: children);
  }

  if (source is UnmodifiableListView<world_settings_module.LocationData>) {
    return source;
  }
  return _freezeListView(source.map(freezeLocation).toList(growable: false));
}

Map<String, character_model.CharacterEntryData> snapshotCharacterData(
  Map<String, character_model.CharacterEntryData> source,
) {
  if (source
      is UnmodifiableMapView<String, character_model.CharacterEntryData>) {
    return source;
  }
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
    characterStates: List<character_model.CharacterState>.unmodifiable(
      source.characterStates.map(
        (state) => state.copyWith(
          possessions: List<String>.unmodifiable(state.possessions),
        ),
      ),
    ),
    totalWords: source.totalWords,
    contentText: source.contentText,
    isDirty: source.isDirty,
  );
}
