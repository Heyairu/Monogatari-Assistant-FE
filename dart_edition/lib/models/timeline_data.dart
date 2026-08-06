import "package:freezed_annotation/freezed_annotation.dart";
import "package:uuid/uuid.dart";

import "outline_data.dart";

part "timeline_data.freezed.dart";

String _timelineUuid() => const Uuid().v4();

enum TickDurationUnit { second, minute, hour, day, week, custom }

enum TimelineElementLevel { large, middle, small }

enum ChapterLinkCoverage { full, opening, middle, ending, reference }

@freezed
class TickDurationData with _$TickDurationData {
  const factory TickDurationData({
    @Default(1) int value,
    @Default(TickDurationUnit.day) TickDurationUnit unit,
    @Default("") String customLabel,
  }) = _TickDurationData;
}

@freezed
class TimelineGridConfig with _$TimelineGridConfig {
  const factory TimelineGridConfig({
    @Default(TickDurationData()) TickDurationData tickDuration,
    @Default(4) int ticksPerMiddleBox,
    @Default(6) int middleBoxesPerLargeBox,
    @Default(false) bool autoSortOutline,
    @Default("故事開始") String originLabel,
    String? originIso8601,
  }) = _TimelineGridConfig;
}

@freezed
class TimelineTrackData with _$TimelineTrackData {
  const factory TimelineTrackData({
    required String trackUUID,
    required String name,
    @Default(0) int order,
    String? colorToken,
    @Default(false) bool isCollapsed,
  }) = _TimelineTrackData;

  factory TimelineTrackData.create({
    required String name,
    required int order,
    String? colorToken,
  }) {
    return TimelineTrackData(
      trackUUID: _timelineUuid(),
      name: name,
      order: order,
      colorToken: colorToken,
    );
  }
}

@freezed
class TimelinePlacementData with _$TimelinePlacementData {
  const TimelinePlacementData._();

  const factory TimelinePlacementData({
    required String placementUUID,
    String? storylineUUID,
    String? eventUUID,
    String? sceneUUID,
    String? parentPlacementUUID,
    @Default(TimelineElementLevel.small) TimelineElementLevel level,
    required String trackUUID,
    @Default(0) int startTick,
    @Default(1) int durationTicks,
    @Default(0) int order,
    @Default("") String label,
  }) = _TimelinePlacementData;

  factory TimelinePlacementData.create({
    String? storylineUUID,
    String? eventUUID,
    String? sceneUUID,
    String? parentPlacementUUID,
    required TimelineElementLevel level,
    required String trackUUID,
    int startTick = 0,
    int durationTicks = 1,
    int order = 0,
    String label = "",
  }) {
    return TimelinePlacementData(
      placementUUID: _timelineUuid(),
      storylineUUID: storylineUUID,
      eventUUID: eventUUID,
      sceneUUID: sceneUUID,
      parentPlacementUUID: parentPlacementUUID,
      level: level,
      trackUUID: trackUUID,
      startTick: startTick,
      durationTicks: durationTicks < 1 ? 1 : durationTicks,
      order: order,
      label: label,
    );
  }

  int get endTick => startTick + durationTicks;
}

@freezed
class OutlineChapterLinkData with _$OutlineChapterLinkData {
  const factory OutlineChapterLinkData({
    required String linkUUID,
    required String sceneUUID,
    required String chapterUUID,
    @Default(0) int sequence,
    @Default(ChapterLinkCoverage.full) ChapterLinkCoverage coverage,
    String? note,
  }) = _OutlineChapterLinkData;

  factory OutlineChapterLinkData.create({
    required String sceneUUID,
    required String chapterUUID,
    int sequence = 0,
    ChapterLinkCoverage coverage = ChapterLinkCoverage.full,
    String? note,
  }) {
    return OutlineChapterLinkData(
      linkUUID: _timelineUuid(),
      sceneUUID: sceneUUID,
      chapterUUID: chapterUUID,
      sequence: sequence,
      coverage: coverage,
      note: note,
    );
  }
}

@freezed
class TimelineDocumentData with _$TimelineDocumentData {
  const factory TimelineDocumentData({
    @Default(TimelineGridConfig()) TimelineGridConfig grid,
    @Default(<TimelineTrackData>[]) List<TimelineTrackData> tracks,
    @Default(<TimelinePlacementData>[]) List<TimelinePlacementData> placements,
  }) = _TimelineDocumentData;

  factory TimelineDocumentData.initial() {
    return const TimelineDocumentData(
      tracks: <TimelineTrackData>[
        TimelineTrackData(trackUUID: "timeline-track-default", name: "時間軸 1"),
      ],
    );
  }
}

@freezed
class TimelineProjectData with _$TimelineProjectData {
  const factory TimelineProjectData({
    required TimelineDocumentData document,
    @Default(<OutlineChapterLinkData>[])
    List<OutlineChapterLinkData> chapterLinks,
  }) = _TimelineProjectData;
}

/// Builds and repairs the projection from Outline boxes to Timeline boxes.
/// Outline content remains authoritative; only placement and track data live
/// in the timeline document.
abstract final class TimelineOutlineMapper {
  static TimelineDocumentData seedFromOutline(
    TimelineDocumentData source,
    List<StorylineData> outline,
  ) {
    var document = source;
    for (final storyline in outline) {
      document = syncStoryline(document, storyline).document;
    }
    return document;
  }

  static ({TimelineDocumentData document, String largePlacementUUID})
  syncStoryline(TimelineDocumentData source, StorylineData storyline) {
    final track = source.tracks.isEmpty
        ? const TimelineTrackData(
            trackUUID: "timeline-track-default",
            name: "時間軸 1",
          )
        : ([
            ...source.tracks,
          ]..sort((a, b) => a.order.compareTo(b.order))).first;
    final tracks = source.tracks.isEmpty ? [track] : source.tracks;
    var placements = [...source.placements];
    TimelinePlacementData? large = _firstWhereOrNull(
      placements,
      (placement) =>
          placement.level == TimelineElementLevel.large &&
          placement.parentPlacementUUID == null &&
          placement.storylineUUID == storyline.chapterUUID,
    );

    if (large == null) {
      final rootEnd = placements
          .where((placement) => placement.parentPlacementUUID == null)
          .fold<int>(
            0,
            (end, placement) =>
                placement.endTick > end ? placement.endTick : end,
          );
      large = TimelinePlacementData.create(
        storylineUUID: storyline.chapterUUID,
        level: TimelineElementLevel.large,
        trackUUID: track.trackUUID,
        startTick: rootEnd,
        durationTicks:
            source.grid.ticksPerMiddleBox * source.grid.middleBoxesPerLargeBox,
        order: placements
            .where((placement) => placement.parentPlacementUUID == null)
            .length,
        label: storyline.storylineName,
      );
      placements.add(large);
    }

    for (final event in storyline.scenes) {
      TimelinePlacementData? middle = _firstWhereOrNull(
        placements,
        (placement) =>
            placement.level == TimelineElementLevel.middle &&
            placement.parentPlacementUUID == large!.placementUUID &&
            placement.eventUUID == event.storyEventUUID,
      );
      if (middle == null) {
        final childEnd = placements
            .where(
              (placement) =>
                  placement.parentPlacementUUID == large!.placementUUID,
            )
            .fold<int>(
              large.startTick,
              (end, placement) =>
                  placement.endTick > end ? placement.endTick : end,
            );
        middle = TimelinePlacementData.create(
          storylineUUID: storyline.chapterUUID,
          eventUUID: event.storyEventUUID,
          parentPlacementUUID: large.placementUUID,
          level: TimelineElementLevel.middle,
          trackUUID: large.trackUUID,
          startTick: childEnd,
          durationTicks: source.grid.ticksPerMiddleBox,
          order: placements
              .where(
                (placement) =>
                    placement.parentPlacementUUID == large!.placementUUID,
              )
              .length,
          label: event.storyEvent,
        );
        placements.add(middle);
      }

      for (final scene in event.scenes) {
        final existingScene = _firstWhereOrNull(
          placements,
          (placement) => placement.sceneUUID == scene.sceneUUID,
        );
        if (existingScene != null) {
          final sceneIndex = placements.indexWhere(
            (placement) =>
                placement.placementUUID == existingScene.placementUUID,
          );
          placements[sceneIndex] = existingScene.copyWith(
            storylineUUID: storyline.chapterUUID,
            eventUUID: event.storyEventUUID,
            parentPlacementUUID: middle.placementUUID,
            level: TimelineElementLevel.small,
          );
          continue;
        }
        final childEnd = placements
            .where(
              (placement) =>
                  placement.parentPlacementUUID == middle!.placementUUID,
            )
            .fold<int>(
              middle.startTick,
              (end, placement) =>
                  placement.endTick > end ? placement.endTick : end,
            );
        placements.add(
          TimelinePlacementData.create(
            storylineUUID: storyline.chapterUUID,
            eventUUID: event.storyEventUUID,
            sceneUUID: scene.sceneUUID,
            parentPlacementUUID: middle.placementUUID,
            level: TimelineElementLevel.small,
            trackUUID: middle.trackUUID,
            startTick: childEnd,
            durationTicks: 1,
            order: placements
                .where(
                  (placement) =>
                      placement.parentPlacementUUID == middle!.placementUUID,
                )
                .length,
            label: scene.sceneName,
          ),
        );
      }
      placements = _enclose(placements, middle.placementUUID);
    }

    placements = _encloseGeneratedHierarchy(placements, large.placementUUID);
    return (
      document: source.copyWith(tracks: tracks, placements: placements),
      largePlacementUUID: large.placementUUID,
    );
  }

  static List<TimelinePlacementData> _encloseGeneratedHierarchy(
    List<TimelinePlacementData> source,
    String largeUUID,
  ) {
    var placements = [...source];
    final middleIds = placements
        .where((placement) => placement.parentPlacementUUID == largeUUID)
        .map((placement) => placement.placementUUID)
        .toList(growable: false);
    for (final middleId in middleIds) {
      placements = _enclose(placements, middleId);
    }
    return _enclose(placements, largeUUID);
  }

  static List<TimelinePlacementData> _enclose(
    List<TimelinePlacementData> source,
    String placementUUID,
  ) {
    final parent = _firstWhereOrNull(
      source,
      (placement) => placement.placementUUID == placementUUID,
    );
    if (parent == null) return source;
    final children = source
        .where((placement) => placement.parentPlacementUUID == placementUUID)
        .toList(growable: false);
    if (children.isEmpty) return source;
    final minStart = children
        .map((placement) => placement.startTick)
        .reduce((a, b) => a < b ? a : b);
    final maxEnd = children
        .map((placement) => placement.endTick)
        .reduce((a, b) => a > b ? a : b);
    final start = parent.startTick < minStart ? parent.startTick : minStart;
    final end = parent.endTick > maxEnd ? parent.endTick : maxEnd;
    final updated = parent.copyWith(
      startTick: start,
      durationTicks: end - start,
    );
    return [
      for (final placement in source)
        placement.placementUUID == placementUUID ? updated : placement,
    ];
  }

  static T? _firstWhereOrNull<T>(
    Iterable<T> values,
    bool Function(T value) test,
  ) {
    for (final value in values) {
      if (test(value)) return value;
    }
    return null;
  }
}

/// Keeps Outline list order and Timeline placement order in sync when the
/// project's automatic ordering option is enabled.
abstract final class TimelineOutlineOrder {
  static List<StorylineData> sortOutlineByTimeline(
    List<StorylineData> source,
    TimelineDocumentData document,
  ) {
    final trackOrder = {
      for (final track in document.tracks) track.trackUUID: track.order,
    };
    final largeByStoryline = <String, TimelinePlacementData>{};
    final middleByEvent = <String, TimelinePlacementData>{};
    final smallByScene = <String, TimelinePlacementData>{};
    for (final placement in document.placements) {
      if (placement.level == TimelineElementLevel.large &&
          placement.storylineUUID != null) {
        largeByStoryline.putIfAbsent(placement.storylineUUID!, () => placement);
      } else if (placement.level == TimelineElementLevel.middle &&
          placement.eventUUID != null) {
        middleByEvent.putIfAbsent(placement.eventUUID!, () => placement);
      } else if (placement.level == TimelineElementLevel.small &&
          placement.sceneUUID != null) {
        smallByScene.putIfAbsent(placement.sceneUUID!, () => placement);
      }
    }

    var changed = false;
    final sortedStorylines = _sortByPlacement(
      source,
      (storyline) => largeByStoryline[storyline.chapterUUID],
      trackOrder,
    );
    if (!_sameIds(
      source.map((item) => item.chapterUUID),
      sortedStorylines.map((item) => item.chapterUUID),
    )) {
      changed = true;
    }

    final result = <StorylineData>[];
    for (final storyline in sortedStorylines) {
      final sortedEvents = _sortByPlacement(
        storyline.scenes,
        (event) => middleByEvent[event.storyEventUUID],
        trackOrder,
      );
      var storylineChanged = !_sameIds(
        storyline.scenes.map((item) => item.storyEventUUID),
        sortedEvents.map((item) => item.storyEventUUID),
      );
      final events = <StoryEventData>[];
      for (final event in sortedEvents) {
        final sortedScenes = _sortByPlacement(
          event.scenes,
          (scene) => smallByScene[scene.sceneUUID],
          trackOrder,
        );
        final eventChanged = !_sameIds(
          event.scenes.map((item) => item.sceneUUID),
          sortedScenes.map((item) => item.sceneUUID),
        );
        storylineChanged = storylineChanged || eventChanged;
        events.add(eventChanged ? event.copyWith(scenes: sortedScenes) : event);
      }
      changed = changed || storylineChanged;
      result.add(
        storylineChanged ? storyline.copyWith(scenes: events) : storyline,
      );
    }
    return changed ? result : source;
  }

  static TimelineDocumentData alignTimelineToOutline(
    TimelineDocumentData source,
    List<StorylineData> outline,
  ) {
    var placements = [...source.placements];
    final trackOrder = {
      for (final track in source.tracks) track.trackUUID: track.order,
    };

    String? linkedPlacement({
      required TimelineElementLevel level,
      String? storylineUUID,
      String? eventUUID,
      String? sceneUUID,
      String? parentUUID,
    }) {
      for (final placement in placements) {
        if (placement.level != level ||
            (storylineUUID != null &&
                placement.storylineUUID != storylineUUID) ||
            (eventUUID != null && placement.eventUUID != eventUUID) ||
            (sceneUUID != null && placement.sceneUUID != sceneUUID) ||
            (parentUUID != null &&
                placement.parentPlacementUUID != parentUUID)) {
          continue;
        }
        return placement.placementUUID;
      }
      return null;
    }

    final largeIds = outline
        .map(
          (storyline) => linkedPlacement(
            level: TimelineElementLevel.large,
            storylineUUID: storyline.chapterUUID,
          ),
        )
        .whereType<String>()
        .toList(growable: false);
    placements = _assignSlots(placements, largeIds, trackOrder);

    for (final storyline in outline) {
      final largeUUID = linkedPlacement(
        level: TimelineElementLevel.large,
        storylineUUID: storyline.chapterUUID,
      );
      if (largeUUID == null) continue;
      final middleIds = storyline.scenes
          .map(
            (event) => linkedPlacement(
              level: TimelineElementLevel.middle,
              eventUUID: event.storyEventUUID,
              parentUUID: largeUUID,
            ),
          )
          .whereType<String>()
          .toList(growable: false);
      placements = _assignSlots(placements, middleIds, trackOrder);

      for (final event in storyline.scenes) {
        final middleUUID = linkedPlacement(
          level: TimelineElementLevel.middle,
          eventUUID: event.storyEventUUID,
          parentUUID: largeUUID,
        );
        if (middleUUID == null) continue;
        final smallIds = event.scenes
            .map(
              (scene) => linkedPlacement(
                level: TimelineElementLevel.small,
                sceneUUID: scene.sceneUUID,
                parentUUID: middleUUID,
              ),
            )
            .whereType<String>()
            .toList(growable: false);
        placements = _assignSlots(placements, smallIds, trackOrder);
      }
    }

    for (final level in [
      TimelineElementLevel.middle,
      TimelineElementLevel.large,
    ]) {
      final parentIds = placements
          .where((placement) => placement.level == level)
          .map((placement) => placement.placementUUID)
          .toList(growable: false);
      for (final parentId in parentIds) {
        placements = _enclose(placements, parentId);
      }
    }
    return source.copyWith(placements: placements);
  }

  static List<T> _sortByPlacement<T>(
    List<T> source,
    TimelinePlacementData? Function(T item) placementOf,
    Map<String, int> trackOrder,
  ) {
    final indexed = <({T item, int index, TimelinePlacementData? placement})>[
      for (var index = 0; index < source.length; index++)
        (
          item: source[index],
          index: index,
          placement: placementOf(source[index]),
        ),
    ];
    indexed.sort((a, b) {
      final left = a.placement;
      final right = b.placement;
      if (left == null || right == null) {
        if (left == null && right != null) return 1;
        if (left != null && right == null) return -1;
        return a.index.compareTo(b.index);
      }
      final byStart = left.startTick.compareTo(right.startTick);
      if (byStart != 0) return byStart;
      final byTrack = (trackOrder[left.trackUUID] ?? 0).compareTo(
        trackOrder[right.trackUUID] ?? 0,
      );
      if (byTrack != 0) return byTrack;
      final byOrder = left.order.compareTo(right.order);
      return byOrder != 0 ? byOrder : a.index.compareTo(b.index);
    });
    return indexed.map((entry) => entry.item).toList(growable: false);
  }

  static List<TimelinePlacementData> _assignSlots(
    List<TimelinePlacementData> source,
    List<String> desiredIds,
    Map<String, int> trackOrder,
  ) {
    if (desiredIds.length < 2) return source;
    var placements = [...source];
    final slotPlacements =
        source
            .where((placement) => desiredIds.contains(placement.placementUUID))
            .toList(growable: false)
          ..sort((a, b) {
            final byStart = a.startTick.compareTo(b.startTick);
            if (byStart != 0) return byStart;
            final byTrack = (trackOrder[a.trackUUID] ?? 0).compareTo(
              trackOrder[b.trackUUID] ?? 0,
            );
            return byTrack != 0 ? byTrack : a.order.compareTo(b.order);
          });
    for (var index = 0; index < desiredIds.length; index++) {
      final placementIndex = placements.indexWhere(
        (placement) => placement.placementUUID == desiredIds[index],
      );
      if (placementIndex < 0 || index >= slotPlacements.length) continue;
      final current = placements[placementIndex];
      final slot = slotPlacements[index];
      final delta = slot.startTick - current.startTick;
      final subtree = _descendantIds(placements, current.placementUUID)
        ..add(current.placementUUID);
      placements = [
        for (final placement in placements)
          if (subtree.contains(placement.placementUUID))
            placement.copyWith(
              startTick: placement.startTick + delta,
              trackUUID: slot.trackUUID,
              order: placement.placementUUID == current.placementUUID
                  ? index
                  : placement.order,
            )
          else
            placement,
      ];
    }
    return placements;
  }

  static Set<String> _descendantIds(
    List<TimelinePlacementData> placements,
    String placementUUID,
  ) {
    final result = <String>{};
    var parents = <String>{placementUUID};
    while (parents.isNotEmpty) {
      final next = <String>{};
      for (final placement in placements) {
        if (placement.parentPlacementUUID != null &&
            parents.contains(placement.parentPlacementUUID) &&
            result.add(placement.placementUUID)) {
          next.add(placement.placementUUID);
        }
      }
      parents = next;
    }
    return result;
  }

  static List<TimelinePlacementData> _enclose(
    List<TimelinePlacementData> source,
    String parentUUID,
  ) {
    final parentIndex = source.indexWhere(
      (placement) => placement.placementUUID == parentUUID,
    );
    if (parentIndex < 0) return source;
    final children = source
        .where((placement) => placement.parentPlacementUUID == parentUUID)
        .toList(growable: false);
    if (children.isEmpty) return source;
    final parent = source[parentIndex];
    final minStart = children
        .map((placement) => placement.startTick)
        .reduce((a, b) => a < b ? a : b);
    final maxEnd = children
        .map((placement) => placement.endTick)
        .reduce((a, b) => a > b ? a : b);
    final start = parent.startTick < minStart ? parent.startTick : minStart;
    final end = parent.endTick > maxEnd ? parent.endTick : maxEnd;
    final placements = [...source];
    placements[parentIndex] = parent.copyWith(
      startTick: start,
      durationTicks: end - start,
    );
    return placements;
  }

  static bool _sameIds(Iterable<String> left, Iterable<String> right) {
    final a = left.toList(growable: false);
    final b = right.toList(growable: false);
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}
