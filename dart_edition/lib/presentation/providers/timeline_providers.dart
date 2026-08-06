import "dart:collection";

import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../models/chapter_selection_data.dart";
import "../../models/outline_data.dart";
import "../../models/timeline_data.dart";
import "project_state_providers.dart";

class TimelineSceneReference {
  final StorylineData storyline;
  final StoryEventData event;
  final SceneData scene;
  final int outlineOrder;

  const TimelineSceneReference({
    required this.storyline,
    required this.event,
    required this.scene,
    required this.outlineOrder,
  });
}

final timelineSceneIndexProvider =
    Provider<Map<String, TimelineSceneReference>>((ref) {
      final outline = ref.watch(outlineDataProvider);
      final result = <String, TimelineSceneReference>{};
      var order = 0;
      for (final storyline in outline) {
        for (final event in storyline.scenes) {
          for (final scene in event.scenes) {
            result[scene.sceneUUID] = TimelineSceneReference(
              storyline: storyline,
              event: event,
              scene: scene,
              outlineOrder: order++,
            );
          }
        }
      }
      return UnmodifiableMapView(result);
    });

final timelineChapterIndexProvider = Provider<Map<String, ChapterLocation>>((
  ref,
) {
  final segments = ref.watch(segmentsDataProvider);
  return UnmodifiableMapView({
    for (final location in ChapterTree.chaptersDepthFirst(segments))
      location.chapter.chapterUUID: location,
  });
});

class TimelineViewState {
  static const _unset = Object();

  final String? scopePlacementUUID;
  final String? selectedPlacementUUID;
  final double pixelsPerTick;
  final String query;
  final bool onlyCurrentChapter;
  final bool onlyUnlinked;

  const TimelineViewState({
    this.scopePlacementUUID,
    this.selectedPlacementUUID,
    this.pixelsPerTick = 72,
    this.query = "",
    this.onlyCurrentChapter = false,
    this.onlyUnlinked = false,
  });

  TimelineViewState copyWith({
    Object? scopePlacementUUID = _unset,
    Object? selectedPlacementUUID = _unset,
    double? pixelsPerTick,
    String? query,
    bool? onlyCurrentChapter,
    bool? onlyUnlinked,
  }) {
    return TimelineViewState(
      scopePlacementUUID: identical(scopePlacementUUID, _unset)
          ? this.scopePlacementUUID
          : scopePlacementUUID as String?,
      selectedPlacementUUID: identical(selectedPlacementUUID, _unset)
          ? this.selectedPlacementUUID
          : selectedPlacementUUID as String?,
      pixelsPerTick: pixelsPerTick ?? this.pixelsPerTick,
      query: query ?? this.query,
      onlyCurrentChapter: onlyCurrentChapter ?? this.onlyCurrentChapter,
      onlyUnlinked: onlyUnlinked ?? this.onlyUnlinked,
    );
  }
}

class TimelineViewNotifier extends Notifier<TimelineViewState> {
  @override
  TimelineViewState build() => const TimelineViewState();

  void select(String? placementUUID) {
    state = state.copyWith(selectedPlacementUUID: placementUUID);
  }

  void enterScope(String? placementUUID) {
    state = state.copyWith(
      scopePlacementUUID: placementUUID,
      selectedPlacementUUID: null,
    );
  }

  void setPixelsPerTick(double value) {
    state = state.copyWith(pixelsPerTick: value.clamp(36, 144));
  }

  void setQuery(String value) => state = state.copyWith(query: value);

  void setOnlyCurrentChapter(bool value) {
    state = state.copyWith(onlyCurrentChapter: value);
  }

  void setOnlyUnlinked(bool value) {
    state = state.copyWith(onlyUnlinked: value);
  }

  void reset() => state = const TimelineViewState();
}

final timelineViewProvider =
    NotifierProvider<TimelineViewNotifier, TimelineViewState>(
      TimelineViewNotifier.new,
    );

class OutlineSelectionRequest {
  final int requestId;
  final String? sceneUUID;

  const OutlineSelectionRequest({this.requestId = 0, this.sceneUUID});
}

class OutlineSelectionRequestNotifier
    extends Notifier<OutlineSelectionRequest> {
  @override
  OutlineSelectionRequest build() => const OutlineSelectionRequest();

  void requestScene(String sceneUUID) {
    state = OutlineSelectionRequest(
      requestId: state.requestId + 1,
      sceneUUID: sceneUUID,
    );
  }
}

final outlineSelectionRequestProvider =
    NotifierProvider<OutlineSelectionRequestNotifier, OutlineSelectionRequest>(
      OutlineSelectionRequestNotifier.new,
    );

class TimelineMutationResult {
  final bool changed;
  final String? message;

  const TimelineMutationResult({required this.changed, this.message});
  const TimelineMutationResult.unchanged([String? message])
    : this(changed: false, message: message);
  const TimelineMutationResult.changed([String? message])
    : this(changed: true, message: message);
}

class TimelineActions {
  final Ref ref;

  const TimelineActions(this.ref);

  TimelineDocumentData get _document => ref.read(timelineDocumentProvider);
  TimelineDocumentNotifier get _notifier =>
      ref.read(timelineDocumentProvider.notifier);

  void updateGrid(TimelineGridConfig grid) {
    final normalized = grid.copyWith(
      tickDuration: grid.tickDuration.copyWith(
        value: grid.tickDuration.value < 1 ? 1 : grid.tickDuration.value,
      ),
      ticksPerMiddleBox: grid.ticksPerMiddleBox < 1
          ? 1
          : grid.ticksPerMiddleBox,
      middleBoxesPerLargeBox: grid.middleBoxesPerLargeBox < 1
          ? 1
          : grid.middleBoxesPerLargeBox,
    );
    _notifier.updateDocument((document) => document.copyWith(grid: normalized));
  }

  TimelineTrackData addTrack([String? requestedName]) {
    final document = _document;
    final track = TimelineTrackData.create(
      name: requestedName?.trim().isNotEmpty == true
          ? requestedName!.trim()
          : "時間軸 ${document.tracks.length + 1}",
      order: document.tracks.length,
    );
    _notifier.setDocument(
      document.copyWith(tracks: [...document.tracks, track]),
    );
    return track;
  }

  void renameTrack(String trackUUID, String name) {
    final normalized = name.trim();
    if (normalized.isEmpty) return;
    _notifier.updateDocument(
      (document) => document.copyWith(
        tracks: [
          for (final track in document.tracks)
            track.trackUUID == trackUUID
                ? track.copyWith(name: normalized)
                : track,
        ],
      ),
    );
  }

  void toggleTrack(String trackUUID) {
    _notifier.updateDocument(
      (document) => document.copyWith(
        tracks: [
          for (final track in document.tracks)
            track.trackUUID == trackUUID
                ? track.copyWith(isCollapsed: !track.isCollapsed)
                : track,
        ],
      ),
    );
  }

  void moveTrack(String trackUUID, int delta) {
    final tracks = [..._document.tracks]
      ..sort((a, b) => a.order.compareTo(b.order));
    final index = tracks.indexWhere((track) => track.trackUUID == trackUUID);
    final target = (index + delta).clamp(0, tracks.length - 1);
    if (index < 0 || index == target) return;
    final track = tracks.removeAt(index);
    tracks.insert(target, track);
    _notifier.updateDocument(
      (document) => document.copyWith(
        tracks: [
          for (var i = 0; i < tracks.length; i++) tracks[i].copyWith(order: i),
        ],
      ),
    );
  }

  TimelineMutationResult deleteTrack(String trackUUID) {
    final document = _document;
    if (document.tracks.length <= 1) {
      return const TimelineMutationResult.unchanged("至少需要保留一條軌道。");
    }
    final fallback = document.tracks.firstWhere(
      (track) => track.trackUUID != trackUUID,
    );
    final tracks = document.tracks
        .where((track) => track.trackUUID != trackUUID)
        .toList(growable: false);
    final movedCount = document.placements
        .where((placement) => placement.trackUUID == trackUUID)
        .length;
    _notifier.setDocument(
      document.copyWith(
        tracks: [
          for (var index = 0; index < tracks.length; index++)
            tracks[index].copyWith(order: index),
        ],
        placements: [
          for (final placement in document.placements)
            placement.trackUUID == trackUUID
                ? placement.copyWith(trackUUID: fallback.trackUUID)
                : placement,
        ],
      ),
    );
    return TimelineMutationResult.changed(
      movedCount == 0 ? null : "$movedCount 個節點已移至「${fallback.name}」。",
    );
  }

  TimelinePlacementData addPlacement({
    required TimelineElementLevel level,
    String? parentPlacementUUID,
    String? sceneUUID,
    String? label,
  }) {
    final document = _document;
    var placements = [...document.placements];
    var outline = [...ref.read(outlineDataProvider)];
    var outlineChanged = false;
    var parent = parentPlacementUUID == null
        ? null
        : _findPlacement(placements, parentPlacementUUID);

    void patchPlacement(
      String placementUUID,
      TimelinePlacementData Function(TimelinePlacementData placement) update,
    ) {
      final index = placements.indexWhere(
        (placement) => placement.placementUUID == placementUUID,
      );
      if (index < 0) return;
      placements[index] = update(placements[index]);
      if (parent?.placementUUID == placementUUID) {
        parent = placements[index];
      }
    }

    String ensureStoryline(TimelinePlacementData large) {
      final linkedIndex = large.storylineUUID == null
          ? -1
          : outline.indexWhere(
              (storyline) => storyline.chapterUUID == large.storylineUUID,
            );
      if (linkedIndex >= 0) return outline[linkedIndex].chapterUUID;
      final storyline = StorylineData(storylineName: large.label.trim());
      outline.add(storyline);
      outlineChanged = true;
      patchPlacement(
        large.placementUUID,
        (placement) => placement.copyWith(storylineUUID: storyline.chapterUUID),
      );
      return storyline.chapterUUID;
    }

    ({String storylineUUID, String eventUUID}) ensureEvent(
      TimelinePlacementData middle,
    ) {
      if (middle.eventUUID != null) {
        for (final storyline in outline) {
          if (storyline.scenes.any(
            (event) => event.storyEventUUID == middle.eventUUID,
          )) {
            patchPlacement(
              middle.placementUUID,
              (placement) =>
                  placement.copyWith(storylineUUID: storyline.chapterUUID),
            );
            return (
              storylineUUID: storyline.chapterUUID,
              eventUUID: middle.eventUUID!,
            );
          }
        }
      }
      final large = middle.parentPlacementUUID == null
          ? null
          : _findPlacement(placements, middle.parentPlacementUUID!);
      if (large == null || large.level != TimelineElementLevel.large) {
        throw StateError("中箱缺少可連結的大箱。");
      }
      final storylineUUID = ensureStoryline(large);
      final storylineIndex = outline.indexWhere(
        (storyline) => storyline.chapterUUID == storylineUUID,
      );
      final event = StoryEventData(storyEvent: middle.label.trim());
      outline[storylineIndex] = outline[storylineIndex].copyWith(
        scenes: [...outline[storylineIndex].scenes, event],
      );
      outlineChanged = true;
      patchPlacement(
        middle.placementUUID,
        (placement) => placement.copyWith(
          storylineUUID: storylineUUID,
          eventUUID: event.storyEventUUID,
        ),
      );
      return (storylineUUID: storylineUUID, eventUUID: event.storyEventUUID);
    }

    String? storylineUUID;
    String? eventUUID;
    var resolvedSceneUUID = sceneUUID;
    if (level == TimelineElementLevel.middle &&
        parent?.level == TimelineElementLevel.large) {
      storylineUUID = ensureStoryline(parent!);
      final storylineIndex = outline.indexWhere(
        (storyline) => storyline.chapterUUID == storylineUUID,
      );
      final event = StoryEventData(storyEvent: label?.trim() ?? "");
      outline[storylineIndex] = outline[storylineIndex].copyWith(
        scenes: [...outline[storylineIndex].scenes, event],
      );
      outlineChanged = true;
      eventUUID = event.storyEventUUID;
    } else if (level == TimelineElementLevel.small &&
        parent?.level == TimelineElementLevel.middle) {
      final existingScene = sceneUUID == null
          ? null
          : ref.read(timelineSceneIndexProvider)[sceneUUID];
      if (existingScene != null) {
        storylineUUID = existingScene.storyline.chapterUUID;
        eventUUID = existingScene.event.storyEventUUID;
      } else {
        final links = ensureEvent(parent!);
        storylineUUID = links.storylineUUID;
        eventUUID = links.eventUUID;
        final storylineIndex = outline.indexWhere(
          (storyline) => storyline.chapterUUID == storylineUUID,
        );
        final eventIndex = outline[storylineIndex].scenes.indexWhere(
          (event) => event.storyEventUUID == eventUUID,
        );
        final scene = SceneData(sceneName: label?.trim() ?? "");
        final events = [...outline[storylineIndex].scenes];
        events[eventIndex] = events[eventIndex].copyWith(
          scenes: [...events[eventIndex].scenes, scene],
        );
        outline[storylineIndex] = outline[storylineIndex].copyWith(
          scenes: events,
        );
        outlineChanged = true;
        resolvedSceneUUID = scene.sceneUUID;
      }
    }

    final siblings = placements
        .where((item) => item.parentPlacementUUID == parentPlacementUUID)
        .toList(growable: false);
    final startTick = siblings.isEmpty
        ? (parent?.startTick ?? 0)
        : siblings.map((item) => item.endTick).reduce((a, b) => a > b ? a : b);
    final duration = switch (level) {
      TimelineElementLevel.large =>
        document.grid.ticksPerMiddleBox * document.grid.middleBoxesPerLargeBox,
      TimelineElementLevel.middle => document.grid.ticksPerMiddleBox,
      TimelineElementLevel.small => 1,
    };
    final placement = TimelinePlacementData.create(
      storylineUUID: storylineUUID,
      eventUUID: eventUUID,
      sceneUUID: resolvedSceneUUID,
      parentPlacementUUID: parentPlacementUUID,
      level: level,
      trackUUID: parent?.trackUUID ?? document.tracks.first.trackUUID,
      startTick: startTick,
      durationTicks: duration,
      order: siblings.length,
      label: label?.trim() ?? "",
    );
    placements.add(placement);
    placements = _extendAncestors(placements, placement.placementUUID);
    if (outlineChanged) {
      ref
          .read(outlineDataProvider.notifier)
          .setOutlineData(outline, synchronizeTimeline: false);
    }
    _notifier.setDocument(document.copyWith(placements: placements));
    return placement;
  }

  TimelineMutationResult syncStorylineHierarchy(String storylineUUID) {
    StorylineData? source;
    for (final storyline in ref.read(outlineDataProvider)) {
      if (storyline.chapterUUID == storylineUUID) {
        source = storyline;
        break;
      }
    }
    if (source == null) {
      return const TimelineMutationResult.unchanged("找不到對應的大綱大箱。");
    }
    final before = _document;
    final result = TimelineOutlineMapper.syncStoryline(before, source);
    _notifier.setDocument(result.document);
    ref.read(timelineViewProvider.notifier).enterScope(null);
    ref.read(timelineViewProvider.notifier).select(result.largePlacementUUID);
    final added = result.document.placements.length - before.placements.length;
    return TimelineMutationResult.changed(
      added == 0 ? "大箱已同步。" : "已同步大箱及其 $added 個時間軸節點。",
    );
  }

  void removePlacement(String placementUUID) {
    final document = _document;
    final removed = <String>{placementUUID};
    var changed = true;
    while (changed) {
      changed = false;
      for (final placement in document.placements) {
        if (placement.parentPlacementUUID != null &&
            removed.contains(placement.parentPlacementUUID) &&
            removed.add(placement.placementUUID)) {
          changed = true;
        }
      }
    }
    _notifier.setDocument(
      document.copyWith(
        placements: document.placements
            .where((placement) => !removed.contains(placement.placementUUID))
            .toList(growable: false),
      ),
    );
    final view = ref.read(timelineViewProvider);
    if (removed.contains(view.selectedPlacementUUID)) {
      ref.read(timelineViewProvider.notifier).select(null);
    }
    if (removed.contains(view.scopePlacementUUID)) {
      ref.read(timelineViewProvider.notifier).enterScope(null);
    }
  }

  TimelineMutationResult updatePlacement(
    String placementUUID, {
    int? startTick,
    int? durationTicks,
    String? trackUUID,
    String? label,
  }) {
    final document = _document;
    final current = _findPlacement(document.placements, placementUUID);
    if (current == null) return const TimelineMutationResult.unchanged();
    final nextStart = startTick ?? current.startTick;
    final delta = nextStart - current.startTick;
    final descendants = _descendantIds(document.placements, placementUUID);
    var placements = <TimelinePlacementData>[
      for (final placement in document.placements)
        if (placement.placementUUID == placementUUID)
          placement.copyWith(
            startTick: nextStart,
            durationTicks: (durationTicks ?? placement.durationTicks).clamp(
              1,
              1 << 30,
            ),
            trackUUID: trackUUID ?? placement.trackUUID,
            label: label ?? placement.label,
          )
        else if (descendants.contains(placement.placementUUID) &&
            (delta != 0 || trackUUID != null))
          placement.copyWith(
            startTick: placement.startTick + delta,
            trackUUID: trackUUID ?? placement.trackUUID,
          )
        else
          placement,
    ];
    placements = _encloseAroundChildren(placements, placementUUID);
    placements = _extendAncestors(placements, placementUUID);
    final split = _splitOverlaps(
      document.copyWith(placements: placements),
      preferredPlacementUUID: placementUUID,
    );
    _notifier.setDocument(split.document);
    return TimelineMutationResult.changed(split.message);
  }

  /// Resizes one placement boundary without translating its descendants.
  /// Parent boxes are kept large enough to contain their existing children.
  TimelineMutationResult resizePlacement(
    String placementUUID, {
    int? startTick,
    int? endTick,
  }) {
    final document = _document;
    final current = _findPlacement(document.placements, placementUUID);
    if (current == null) return const TimelineMutationResult.unchanged();

    var nextStart = startTick ?? current.startTick;
    var nextEnd = endTick ?? current.endTick;
    if (startTick != null) {
      nextStart = nextStart.clamp(-(1 << 30), nextEnd - 1);
    } else {
      nextEnd = nextEnd.clamp(nextStart + 1, 1 << 30);
    }
    if (nextStart == current.startTick && nextEnd == current.endTick) {
      return const TimelineMutationResult.unchanged();
    }

    var placements = <TimelinePlacementData>[
      for (final placement in document.placements)
        if (placement.placementUUID == placementUUID)
          placement.copyWith(
            startTick: nextStart,
            durationTicks: nextEnd - nextStart,
          )
        else
          placement,
    ];
    placements = _encloseAroundChildren(placements, placementUUID);
    placements = _extendAncestors(placements, placementUUID);
    final split = _splitOverlaps(
      document.copyWith(placements: placements),
      preferredPlacementUUID: placementUUID,
    );
    _notifier.setDocument(split.document);
    return TimelineMutationResult.changed(split.message);
  }

  void addChapterLink(String sceneUUID, String chapterUUID) {
    final notifier = ref.read(outlineChapterLinksProvider.notifier);
    notifier.updateLinks((links) {
      if (links.any(
        (link) =>
            link.sceneUUID == sceneUUID && link.chapterUUID == chapterUUID,
      )) {
        return links;
      }
      return [
        ...links,
        OutlineChapterLinkData.create(
          sceneUUID: sceneUUID,
          chapterUUID: chapterUUID,
          sequence: links.where((link) => link.sceneUUID == sceneUUID).length,
        ),
      ];
    });
  }

  void removeChapterLink(String linkUUID) {
    ref
        .read(outlineChapterLinksProvider.notifier)
        .updateLinks(
          (links) => links
              .where((link) => link.linkUUID != linkUUID)
              .toList(growable: false),
        );
  }

  TimelinePlacementData? _findPlacement(
    List<TimelinePlacementData> placements,
    String placementUUID,
  ) {
    for (final placement in placements) {
      if (placement.placementUUID == placementUUID) return placement;
    }
    return null;
  }

  Set<String> _descendantIds(
    List<TimelinePlacementData> placements,
    String parentUUID,
  ) {
    final result = <String>{};
    var parents = <String>{parentUUID};
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

  List<TimelinePlacementData> _extendAncestors(
    List<TimelinePlacementData> source,
    String childUUID,
  ) {
    var placements = [...source];
    var child = _findPlacement(placements, childUUID);
    final visited = <String>{};
    while (child?.parentPlacementUUID != null &&
        visited.add(child!.parentPlacementUUID!)) {
      final parent = _findPlacement(placements, child.parentPlacementUUID!);
      if (parent == null) break;
      final children = placements
          .where((item) => item.parentPlacementUUID == parent.placementUUID)
          .toList(growable: false);
      final minStart = children
          .map((item) => item.startTick)
          .reduce((a, b) => a < b ? a : b);
      final maxEnd = children
          .map((item) => item.endTick)
          .reduce((a, b) => a > b ? a : b);
      final newStart = minStart < parent.startTick
          ? minStart
          : parent.startTick;
      final newEnd = maxEnd > parent.endTick ? maxEnd : parent.endTick;
      final updated = parent.copyWith(
        startTick: newStart,
        durationTicks: newEnd - newStart,
      );
      placements = [
        for (final item in placements)
          item.placementUUID == parent.placementUUID ? updated : item,
      ];
      child = updated;
    }
    return placements;
  }

  List<TimelinePlacementData> _encloseAroundChildren(
    List<TimelinePlacementData> source,
    String placementUUID,
  ) {
    final placement = _findPlacement(source, placementUUID);
    if (placement == null) return source;
    final children = source
        .where((item) => item.parentPlacementUUID == placementUUID)
        .toList(growable: false);
    if (children.isEmpty) return source;
    final minStart = children
        .map((item) => item.startTick)
        .reduce((a, b) => a < b ? a : b);
    final maxEnd = children
        .map((item) => item.endTick)
        .reduce((a, b) => a > b ? a : b);
    final start = placement.startTick > minStart
        ? minStart
        : placement.startTick;
    final end = placement.endTick < maxEnd ? maxEnd : placement.endTick;
    final updated = placement.copyWith(
      startTick: start,
      durationTicks: end - start,
    );
    return [
      for (final item in source)
        item.placementUUID == placementUUID ? updated : item,
    ];
  }

  ({TimelineDocumentData document, String? message}) _splitOverlaps(
    TimelineDocumentData source, {
    required String preferredPlacementUUID,
  }) {
    var placements = [...source.placements];
    var tracks = [...source.tracks];
    final moved = <TimelinePlacementData>[];
    var reusedTrackCount = 0;
    var createdTrackCount = 0;
    final scopes = placements.map((item) => item.parentPlacementUUID).toSet();
    for (final scope in scopes) {
      for (final track in [...tracks]) {
        final lane =
            placements
                .where(
                  (item) =>
                      item.parentPlacementUUID == scope &&
                      item.trackUUID == track.trackUUID,
                )
                .toList()
              ..sort((a, b) {
                final byStart = a.startTick.compareTo(b.startTick);
                if (byStart != 0) return byStart;
                if (a.placementUUID == preferredPlacementUUID) return -1;
                if (b.placementUUID == preferredPlacementUUID) return 1;
                return a.order.compareTo(b.order);
              });
        var previousEnd = -0x7fffffff;
        for (final item in lane) {
          if (item.startTick >= previousEnd) {
            previousEnd = item.endTick;
            continue;
          }
          final subtree = <String>{
            item.placementUUID,
            ..._descendantIds(placements, item.placementUUID),
          };
          final lowerTracks =
              tracks
                  .where((candidate) => candidate.order > track.order)
                  .toList(growable: false)
                ..sort((a, b) => a.order.compareTo(b.order));
          TimelineTrackData? targetTrack;
          for (final candidate in lowerTracks) {
            if (_subtreeFitsTrack(placements, subtree, candidate.trackUUID)) {
              targetTrack = candidate;
              reusedTrackCount++;
              break;
            }
          }
          if (targetTrack == null) {
            targetTrack = TimelineTrackData.create(
              name: "時間軸 ${tracks.length + 1}",
              order: tracks.length,
            );
            tracks.add(targetTrack);
            createdTrackCount++;
          }
          placements = [
            for (final placement in placements)
              subtree.contains(placement.placementUUID)
                  ? placement.copyWith(trackUUID: targetTrack.trackUUID)
                  : placement,
          ];
          moved.add(item);
        }
      }
    }
    return (
      document: source.copyWith(tracks: tracks, placements: placements),
      message: moved.isEmpty
          ? null
          : createdTrackCount == 0
          ? "偵測到同軌重疊，${moved.length} 個後續節點已自動移至下方既有軌道。"
          : reusedTrackCount == 0
          ? "偵測到同軌重疊，${moved.length} 個後續節點已自動移至新軌道。"
          : "偵測到同軌重疊，已優先使用 $reusedTrackCount 條下方既有軌道，並新增 $createdTrackCount 條軌道。",
    );
  }

  bool _subtreeFitsTrack(
    List<TimelinePlacementData> placements,
    Set<String> subtree,
    String trackUUID,
  ) {
    final moving = placements
        .where((placement) => subtree.contains(placement.placementUUID))
        .toList(growable: false);
    for (final item in moving) {
      final collides = placements.any(
        (other) =>
            !subtree.contains(other.placementUUID) &&
            other.trackUUID == trackUUID &&
            other.parentPlacementUUID == item.parentPlacementUUID &&
            item.startTick < other.endTick &&
            other.startTick < item.endTick,
      );
      if (collides) return false;
    }
    return true;
  }
}

final timelineActionsProvider = Provider<TimelineActions>(TimelineActions.new);
