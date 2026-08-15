import "dart:convert";

import "../../domain/collaboration/collaboration_operation.dart";
import "../../domain/collaboration/typed_operation_log.dart";
import "../../models/base_info_data.dart";
import "../../models/chapter_selection_data.dart";
import "../../models/character_data.dart";
import "../../models/character_snapshot_data.dart";
import "../../models/outline_data.dart";
import "../../models/plan_data.dart";
import "../../models/project_data.dart";
import "../../models/timeline_data.dart";
import "../../models/world_settings_data.dart";

/// Converts ProjectData models to versioned, stable-id collaboration records.
/// Chapter content is intentionally absent; it belongs exclusively to CRDT.
abstract final class ProjectRecordCodec {
  static const int schemaVersion = 1;
  static const String baseInfoRecordId = "project-base-info";
  static const String timelineGridRecordId = "timeline-grid";

  static Map<ProjectRecordKey, ProjectRecordOperation> snapshot(
    ProjectData data, {
    bool omitCollaborativeText = false,
  }) {
    final records = <ProjectRecordKey, ProjectRecordOperation>{};

    void put({
      required ProjectRecordKind kind,
      required String id,
      required Map<String, Object?> fields,
      String? parentId,
      String? afterRecordId,
    }) {
      records[ProjectRecordKey(
        kind: kind,
        recordId: id,
      )] = ProjectRecordOperation(
        recordKind: kind,
        mutation: ProjectRecordMutation.put,
        recordId: id,
        parentId: parentId,
        afterRecordId: afterRecordId,
        fields: <String, Object?>{"schemaVersion": schemaVersion, ...fields},
      );
    }

    final baseInfo = data.baseInfoData;
    put(
      kind: ProjectRecordKind.baseInfo,
      id: baseInfoRecordId,
      fields: <String, Object?>{
        "bookName": baseInfo.bookName,
        "author": baseInfo.author,
        "purpose": baseInfo.purpose,
        "toRecap": baseInfo.toRecap,
        "storyType": baseInfo.storyType,
        "intro": baseInfo.intro,
        "tags": baseInfo.tags,
      },
    );

    void addFolders(List<SegmentData> folders, String? parentId) {
      String? previousId;
      for (
        var folderIndex = 0;
        folderIndex < folders.length;
        folderIndex += 1
      ) {
        final folder = folders[folderIndex];
        put(
          kind: ProjectRecordKind.chapterFolder,
          id: folder.segmentUUID,
          parentId: parentId,
          afterRecordId: previousId,
          fields: <String, Object?>{
            "name": folder.segmentName,
            "order": folderIndex,
          },
        );
        final chaptersById = <String, ChapterData>{
          for (final chapter in folder.chapters) chapter.chapterUUID: chapter,
        };
        final childrenById = <String, SegmentData>{
          for (final child in folder.childSegments) child.segmentUUID: child,
        };
        String? previousChildId;
        for (
          var index = 0;
          index < folder.resolvedChildNodeOrder.length;
          index += 1
        ) {
          final childId = folder.resolvedChildNodeOrder[index];
          final chapter = chaptersById[childId];
          if (chapter != null) {
            put(
              kind: ProjectRecordKind.chapterMetadata,
              id: chapter.chapterUUID,
              parentId: folder.segmentUUID,
              afterRecordId: previousChildId,
              fields: <String, Object?>{
                "name": chapter.chapterName,
                "order": index,
              },
            );
            previousChildId = childId;
            continue;
          }
          final childFolder = childrenById[childId];
          if (childFolder != null) {
            addFolders(<SegmentData>[childFolder], folder.segmentUUID);
            put(
              kind: ProjectRecordKind.chapterFolder,
              id: childFolder.segmentUUID,
              parentId: folder.segmentUUID,
              afterRecordId: previousChildId,
              fields: <String, Object?>{
                "name": childFolder.segmentName,
                "order": index,
              },
            );
            previousChildId = childId;
          }
        }
        previousId = folder.segmentUUID;
      }
    }

    addFolders(data.segmentsData, null);

    String? previousStorylineId;
    for (
      var storylineIndex = 0;
      storylineIndex < data.outlineData.length;
      storylineIndex += 1
    ) {
      final storyline = data.outlineData[storylineIndex];
      put(
        kind: ProjectRecordKind.outlineStoryline,
        id: storyline.chapterUUID,
        afterRecordId: previousStorylineId,
        fields: <String, Object?>{
          "order": storylineIndex,
          "name": omitCollaborativeText ? "" : storyline.storylineName,
          "type": omitCollaborativeText ? "" : storyline.storylineType,
          "memo": omitCollaborativeText ? "" : storyline.memo,
          "conflictPoint": omitCollaborativeText ? "" : storyline.conflictPoint,
          "people": storyline.people,
          "items": storyline.item,
        },
      );
      String? previousEventId;
      for (
        var eventIndex = 0;
        eventIndex < storyline.scenes.length;
        eventIndex += 1
      ) {
        final event = storyline.scenes[eventIndex];
        put(
          kind: ProjectRecordKind.outlineEvent,
          id: event.storyEventUUID,
          parentId: storyline.chapterUUID,
          afterRecordId: previousEventId,
          fields: <String, Object?>{
            "order": eventIndex,
            "event": omitCollaborativeText ? "" : event.storyEvent,
            "memo": omitCollaborativeText ? "" : event.memo,
            "conflictPoint": omitCollaborativeText ? "" : event.conflictPoint,
            "people": event.people,
            "items": event.item,
          },
        );
        String? previousSceneId;
        for (
          var sceneIndex = 0;
          sceneIndex < event.scenes.length;
          sceneIndex += 1
        ) {
          final scene = event.scenes[sceneIndex];
          put(
            kind: ProjectRecordKind.outlineScene,
            id: scene.sceneUUID,
            parentId: event.storyEventUUID,
            afterRecordId: previousSceneId,
            fields: <String, Object?>{
              "order": sceneIndex,
              "name": omitCollaborativeText ? "" : scene.sceneName,
              "time": omitCollaborativeText ? "" : scene.time,
              "timePointIso8601": scene.timePointIso8601,
              "location": omitCollaborativeText ? "" : scene.location,
              "focusPoint": omitCollaborativeText ? "" : scene.focusPoint,
              "conflictPoint": omitCollaborativeText ? "" : scene.conflictPoint,
              "people": scene.people,
              "items": scene.item,
              "doingThings": scene.doingThings,
              "memo": omitCollaborativeText ? "" : scene.memo,
            },
          );
          previousSceneId = scene.sceneUUID;
        }
        previousEventId = event.storyEventUUID;
      }
      previousStorylineId = storyline.chapterUUID;
    }

    for (var index = 0; index < data.foreshadowData.length; index += 1) {
      final item = data.foreshadowData[index];
      put(
        kind: ProjectRecordKind.foreshadow,
        id: item.id,
        fields: <String, Object?>{
          "order": index,
          "title": item.title,
          "note": item.note,
          "isRevealed": item.isRevealed,
        },
      );
    }
    for (var index = 0; index < data.updatePlanData.length; index += 1) {
      final item = data.updatePlanData[index];
      put(
        kind: ProjectRecordKind.updatePlan,
        id: item.id,
        fields: <String, Object?>{
          "order": index,
          "title": item.title,
          "note": item.note,
          "isDone": item.isDone,
        },
      );
    }

    void addWorldNodes(List<LocationData> nodes, String? parentId) {
      for (var index = 0; index < nodes.length; index += 1) {
        final node = nodes[index];
        put(
          kind: ProjectRecordKind.worldNode,
          id: node.id,
          parentId: parentId,
          fields: <String, Object?>{
            "order": index,
            "name": omitCollaborativeText ? "" : node.localName,
            "localType": omitCollaborativeText ? "" : node.localType,
            "nodeType": node.nodeType.name,
            "customValues": node.customVal
                .map(
                  (value) => omitCollaborativeText
                      ? <String, Object?>{"id": value.id, "key": "", "val": ""}
                      : value.toJson(),
                )
                .toList(growable: false),
            "note": omitCollaborativeText ? "" : node.note,
          },
        );
        addWorldNodes(node.child, node.id);
      }
    }

    addWorldNodes(data.worldSettingsData, null);

    for (final entry in data.characterData.entries) {
      put(
        kind: ProjectRecordKind.character,
        id: entry.key,
        fields: _characterToJson(
          entry.value,
          omitCollaborativeText: omitCollaborativeText,
        ),
      );
    }
    for (var index = 0; index < data.characterStates.length; index += 1) {
      final characterState = data.characterStates[index];
      final recordId = _characterStateRecordId(characterState, index);
      put(
        kind: ProjectRecordKind.characterState,
        id: recordId,
        fields: <String, Object?>{
          "order": index,
          "characterId": characterState.characterId,
          "storyTimePointId": characterState.storyTimePointId,
          "location": characterState.location,
          "healthStatus": characterState.healthStatus,
          "emotion": characterState.emotion,
          "alignment": characterState.alignment,
          "possessions": characterState.possessions,
        },
      );
    }
    for (final entry in data.characterStateBaselines.entries) {
      final baseline = entry.value;
      put(
        kind: ProjectRecordKind.characterStateBaseline,
        id: entry.key,
        fields: <String, Object?>{
          "characterId": baseline.characterId,
          "note": baseline.note,
          "patch": _patchToJson(baseline.patch),
        },
      );
    }
    for (final change in data.characterStateChanges) {
      put(
        kind: ProjectRecordKind.characterStateChange,
        id: change.stateChangeId,
        fields: <String, Object?>{
          "characterId": change.characterId,
          "sceneUUID": change.sceneUUID,
          "sourcePlacementUUID": change.sourcePlacementUUID,
          "fallbackTick": change.fallbackTick,
          "sequence": change.sequence,
          "patch": _patchToJson(change.patch),
          "note": change.note,
        },
      );
    }

    final grid = data.timelineDocument.grid;
    put(
      kind: ProjectRecordKind.timelineGrid,
      id: timelineGridRecordId,
      fields: <String, Object?>{
        "ticksPerLittleBox": <String, Object?>{
          "value": grid.ticksPerLittleBox.value,
          "unit": grid.ticksPerLittleBox.unit.name,
          "customLabel": grid.ticksPerLittleBox.customLabel,
        },
        "ticksPerSmallBox": grid.ticksPerSmallBox,
        "ticksPerMiddleBox": grid.ticksPerMiddleBox,
        "middleBoxesPerLargeBox": grid.middleBoxesPerLargeBox,
        "autoSortOutline": grid.autoSortOutline,
        "originLabel": grid.originLabel,
        "originIso8601": grid.originIso8601,
      },
    );
    for (final track in data.timelineDocument.tracks) {
      put(
        kind: ProjectRecordKind.timelineTrack,
        id: track.trackUUID,
        fields: <String, Object?>{
          "name": track.name,
          "order": track.order,
          "colorToken": track.colorToken,
          "isCollapsed": track.isCollapsed,
        },
      );
    }
    for (final placement in data.timelineDocument.placements) {
      put(
        kind: ProjectRecordKind.timelinePlacement,
        id: placement.placementUUID,
        parentId: placement.parentPlacementUUID,
        fields: <String, Object?>{
          "storylineUUID": placement.storylineUUID,
          "eventUUID": placement.eventUUID,
          "sceneUUID": placement.sceneUUID,
          "level": placement.level.name,
          "trackUUID": placement.trackUUID,
          "startTick": placement.startTick,
          "durationTicks": placement.durationTicks,
          "order": placement.order,
          "label": placement.label,
        },
      );
    }
    for (final link in data.outlineChapterLinks) {
      put(
        kind: ProjectRecordKind.outlineChapterLink,
        id: link.linkUUID,
        fields: <String, Object?>{
          "sceneUUID": link.sceneUUID,
          "chapterUUID": link.chapterUUID,
          "sequence": link.sequence,
          "coverage": link.coverage.name,
          "note": link.note,
        },
      );
    }
    return records;
  }

  static List<ProjectRecordOperation> diff(
    Map<ProjectRecordKey, ProjectRecordOperation> previous,
    Map<ProjectRecordKey, ProjectRecordOperation> next,
  ) {
    final operations = <ProjectRecordOperation>[];
    for (final entry in next.entries) {
      final old = previous[entry.key];
      if (old == null ||
          _canonical(old.toJson()) != _canonical(entry.value.toJson())) {
        operations.add(entry.value);
      }
    }
    for (final entry in previous.entries) {
      if (next.containsKey(entry.key)) continue;
      operations.add(
        ProjectRecordOperation(
          recordKind: entry.key.kind,
          mutation: ProjectRecordMutation.remove,
          recordId: entry.key.recordId,
        ),
      );
    }
    operations.sort((left, right) {
      final byKind = left.recordKind.index.compareTo(right.recordKind.index);
      return byKind != 0 ? byKind : left.recordId.compareTo(right.recordId);
    });
    return List<ProjectRecordOperation>.unmodifiable(operations);
  }

  static BaseInfoData decodeBaseInfo(
    Map<ProjectRecordKey, ProjectRecordOperation> records,
  ) {
    final fields = _requiredRecord(
      records,
      ProjectRecordKind.baseInfo,
      baseInfoRecordId,
    ).fields;
    return BaseInfoData(
      bookName: _string(fields, "bookName"),
      author: _string(fields, "author"),
      purpose: _string(fields, "purpose"),
      toRecap: _string(fields, "toRecap"),
      storyType: _string(fields, "storyType"),
      intro: _string(fields, "intro"),
      tags: _stringList(fields, "tags"),
    );
  }

  static List<SegmentData> decodeSegments(
    Map<ProjectRecordKey, ProjectRecordOperation> records,
    Map<String, String> chapterTexts,
  ) {
    final folders = _recordsOf(records, ProjectRecordKind.chapterFolder);
    final chapters = _recordsOf(records, ProjectRecordKind.chapterMetadata);
    final foldersByParent = _groupByParent(folders);
    final chaptersByParent = _groupByParent(chapters);
    final visiting = <String>{};

    SegmentData buildFolder(ProjectRecordOperation record) {
      if (!visiting.add(record.recordId)) {
        throw const FormatException("chapter folder operation 形成循環。");
      }
      final childFolders =
          foldersByParent[record.recordId] ?? const <ProjectRecordOperation>[];
      final childChapters =
          chaptersByParent[record.recordId] ?? const <ProjectRecordOperation>[];
      final mixed = <ProjectRecordOperation>[...childFolders, ...childChapters]
        ..sort(_compareOrder);
      final result = SegmentData(
        segmentUUID: record.recordId,
        segmentName: _string(record.fields, "name"),
        chapters: childChapters
            .map(
              (chapter) => ChapterData(
                chapterUUID: chapter.recordId,
                chapterName: _string(chapter.fields, "name"),
                chapterContent: chapterTexts[chapter.recordId] ?? "",
              ),
            )
            .toList(growable: false),
        childSegments: childFolders.map(buildFolder).toList(growable: false),
        childNodeOrder: mixed
            .map((item) => item.recordId)
            .toList(growable: false),
      );
      visiting.remove(record.recordId);
      return result;
    }

    return (foldersByParent[null] ?? const <ProjectRecordOperation>[])
        .map(buildFolder)
        .toList(growable: false);
  }

  static List<StorylineData> decodeOutline(
    Map<ProjectRecordKey, ProjectRecordOperation> records,
  ) {
    final storylines = _recordsOf(records, ProjectRecordKind.outlineStoryline)
      ..sort(_compareOrder);
    final eventsByParent = _groupByParent(
      _recordsOf(records, ProjectRecordKind.outlineEvent),
    );
    final scenesByParent = _groupByParent(
      _recordsOf(records, ProjectRecordKind.outlineScene),
    );
    return storylines
        .map((storyline) {
          final events =
              eventsByParent[storyline.recordId] ??
              const <ProjectRecordOperation>[];
          return StorylineData(
            chapterUUID: storyline.recordId,
            storylineName: _string(storyline.fields, "name"),
            storylineType: _string(storyline.fields, "type"),
            memo: _string(storyline.fields, "memo"),
            conflictPoint: _string(storyline.fields, "conflictPoint"),
            people: _stringList(storyline.fields, "people"),
            item: _stringList(storyline.fields, "items"),
            scenes: events
                .map((event) {
                  final scenes =
                      scenesByParent[event.recordId] ??
                      const <ProjectRecordOperation>[];
                  return StoryEventData(
                    storyEventUUID: event.recordId,
                    storyEvent: _string(event.fields, "event"),
                    memo: _string(event.fields, "memo"),
                    conflictPoint: _string(event.fields, "conflictPoint"),
                    people: _stringList(event.fields, "people"),
                    item: _stringList(event.fields, "items"),
                    scenes: scenes
                        .map(
                          (scene) => SceneData(
                            sceneUUID: scene.recordId,
                            sceneName: _string(scene.fields, "name"),
                            time: _string(scene.fields, "time"),
                            timePointIso8601: _nullableString(
                              scene.fields,
                              "timePointIso8601",
                            ),
                            location: _string(scene.fields, "location"),
                            focusPoint: _string(scene.fields, "focusPoint"),
                            conflictPoint: _string(
                              scene.fields,
                              "conflictPoint",
                            ),
                            people: _stringList(scene.fields, "people"),
                            item: _stringList(scene.fields, "items"),
                            doingThings: _stringList(
                              scene.fields,
                              "doingThings",
                            ),
                            memo: _string(scene.fields, "memo"),
                          ),
                        )
                        .toList(growable: false),
                  );
                })
                .toList(growable: false),
          );
        })
        .toList(growable: false);
  }

  static List<ForeshadowItem> decodeForeshadows(
    Map<ProjectRecordKey, ProjectRecordOperation> records,
  ) => (_recordsOf(records, ProjectRecordKind.foreshadow)..sort(_compareOrder))
      .map(
        (record) => ForeshadowItem(
          id: record.recordId,
          title: _string(record.fields, "title"),
          note: _string(record.fields, "note"),
          isRevealed: _bool(record.fields, "isRevealed"),
        ),
      )
      .toList(growable: false);

  static List<UpdatePlanItem> decodeUpdatePlans(
    Map<ProjectRecordKey, ProjectRecordOperation> records,
  ) => (_recordsOf(records, ProjectRecordKind.updatePlan)..sort(_compareOrder))
      .map(
        (record) => UpdatePlanItem(
          id: record.recordId,
          title: _string(record.fields, "title"),
          note: _string(record.fields, "note"),
          isDone: _bool(record.fields, "isDone"),
        ),
      )
      .toList(growable: false);

  static List<LocationData> decodeWorldSettings(
    Map<ProjectRecordKey, ProjectRecordOperation> records,
  ) {
    final byParent = _groupByParent(
      _recordsOf(records, ProjectRecordKind.worldNode),
    );
    final visiting = <String>{};
    LocationData build(ProjectRecordOperation record) {
      if (!visiting.add(record.recordId)) {
        throw const FormatException("world node operation 形成循環。");
      }
      final customValues = _objectList(
        record.fields,
        "customValues",
      ).map(LocationCustomize.fromJson).toList(growable: false);
      final result = LocationData(
        id: record.recordId,
        localName: _string(record.fields, "name"),
        localType: _string(record.fields, "localType"),
        nodeType: _enumByName(
          WorldNodeType.values,
          _string(record.fields, "nodeType"),
        ),
        customVal: customValues,
        note: _string(record.fields, "note"),
        child: (byParent[record.recordId] ?? const <ProjectRecordOperation>[])
            .map(build)
            .toList(growable: false),
      );
      visiting.remove(record.recordId);
      return result;
    }

    return (byParent[null] ?? const <ProjectRecordOperation>[])
        .map(build)
        .toList(growable: false);
  }

  static Map<String, CharacterEntryData> decodeCharacters(
    Map<ProjectRecordKey, ProjectRecordOperation> records,
  ) => <String, CharacterEntryData>{
    for (final record in _recordsOf(records, ProjectRecordKind.character))
      record.recordId: _characterFromJson(record.recordId, record.fields),
  };

  static List<CharacterState> decodeCharacterStates(
    Map<ProjectRecordKey, ProjectRecordOperation> records,
  ) =>
      (_recordsOf(records, ProjectRecordKind.characterState)
            ..sort(_compareOrder))
          .map(
            (record) => CharacterState(
              characterId: _string(record.fields, "characterId"),
              storyTimePointId: _nullableString(
                record.fields,
                "storyTimePointId",
              ),
              location: _string(record.fields, "location"),
              healthStatus: _string(record.fields, "healthStatus"),
              emotion: _string(record.fields, "emotion"),
              alignment: _string(record.fields, "alignment"),
              possessions: _stringList(record.fields, "possessions"),
            ),
          )
          .toList(growable: false);

  static Map<String, CharacterStateBaseline> decodeCharacterBaselines(
    Map<ProjectRecordKey, ProjectRecordOperation> records,
  ) => <String, CharacterStateBaseline>{
    for (final record in _recordsOf(
      records,
      ProjectRecordKind.characterStateBaseline,
    ))
      record.recordId: CharacterStateBaseline(
        characterId: _string(record.fields, "characterId"),
        note: _string(record.fields, "note"),
        patch: _patchFromJson(_object(record.fields, "patch")),
      ),
  };

  static List<CharacterStateChange> decodeCharacterChanges(
    Map<ProjectRecordKey, ProjectRecordOperation> records,
  ) => _recordsOf(records, ProjectRecordKind.characterStateChange)
      .map(
        (record) => CharacterStateChange(
          stateChangeId: record.recordId,
          characterId: _string(record.fields, "characterId"),
          sceneUUID: _string(record.fields, "sceneUUID"),
          sourcePlacementUUID: _nullableString(
            record.fields,
            "sourcePlacementUUID",
          ),
          fallbackTick: _int(record.fields, "fallbackTick"),
          sequence: _int(record.fields, "sequence"),
          patch: _patchFromJson(_object(record.fields, "patch")),
          note: _string(record.fields, "note"),
        ),
      )
      .toList(growable: false);

  static TimelineDocumentData decodeTimeline(
    Map<ProjectRecordKey, ProjectRecordOperation> records,
  ) {
    final gridFields = _requiredRecord(
      records,
      ProjectRecordKind.timelineGrid,
      timelineGridRecordId,
    ).fields;
    final tick = _object(gridFields, "ticksPerLittleBox");
    return TimelineDocumentData(
      grid: TimelineGridConfig(
        ticksPerLittleBox: TickDurationData(
          value: _int(tick, "value"),
          unit: _enumByName(TickDurationUnit.values, _string(tick, "unit")),
          customLabel: _string(tick, "customLabel"),
        ),
        ticksPerSmallBox: _int(gridFields, "ticksPerSmallBox"),
        ticksPerMiddleBox: _int(gridFields, "ticksPerMiddleBox"),
        middleBoxesPerLargeBox: _int(gridFields, "middleBoxesPerLargeBox"),
        autoSortOutline: _bool(gridFields, "autoSortOutline"),
        originLabel: _string(gridFields, "originLabel"),
        originIso8601: _nullableString(gridFields, "originIso8601"),
      ),
      tracks:
          (_recordsOf(records, ProjectRecordKind.timelineTrack)
                ..sort(_compareOrder))
              .map(
                (record) => TimelineTrackData(
                  trackUUID: record.recordId,
                  name: _string(record.fields, "name"),
                  order: _int(record.fields, "order"),
                  colorToken: _nullableString(record.fields, "colorToken"),
                  isCollapsed: _bool(record.fields, "isCollapsed"),
                ),
              )
              .toList(growable: false),
      placements: _recordsOf(records, ProjectRecordKind.timelinePlacement)
          .map(
            (record) => TimelinePlacementData(
              placementUUID: record.recordId,
              storylineUUID: _nullableString(record.fields, "storylineUUID"),
              eventUUID: _nullableString(record.fields, "eventUUID"),
              sceneUUID: _nullableString(record.fields, "sceneUUID"),
              parentPlacementUUID: record.parentId,
              level: _enumByName(
                TimelineElementLevel.values,
                _string(record.fields, "level"),
              ),
              trackUUID: _string(record.fields, "trackUUID"),
              startTick: _int(record.fields, "startTick"),
              durationTicks: _int(record.fields, "durationTicks"),
              order: _int(record.fields, "order"),
              label: _string(record.fields, "label"),
            ),
          )
          .toList(growable: false),
    );
  }

  static List<OutlineChapterLinkData> decodeOutlineChapterLinks(
    Map<ProjectRecordKey, ProjectRecordOperation> records,
  ) => _recordsOf(records, ProjectRecordKind.outlineChapterLink)
      .map(
        (record) => OutlineChapterLinkData(
          linkUUID: record.recordId,
          sceneUUID: _string(record.fields, "sceneUUID"),
          chapterUUID: _string(record.fields, "chapterUUID"),
          sequence: _int(record.fields, "sequence"),
          coverage: _enumByName(
            ChapterLinkCoverage.values,
            _string(record.fields, "coverage"),
          ),
          note: _nullableString(record.fields, "note"),
        ),
      )
      .toList(growable: false);

  static Map<String, Object?> _characterToJson(
    CharacterEntryData value, {
    required bool omitCollaborativeText,
  }) {
    String text(String value) => omitCollaborativeText ? "" : value;
    return <String, Object?>{
      "characterId": value.characterId,
      "displayName": text(value.displayName),
      "aliases": value.aliases
          .map(
            (item) => <String, Object?>{
              "type": item.type,
              "values": item.values,
            },
          )
          .toList(),
      "roleOrOccupation": text(value.roleOrOccupation),
      "age": text(value.age),
      "gender": text(value.gender),
      "appearanceSummary": text(value.appearanceSummary),
      "personalitySummary": text(value.personalitySummary),
      "speechStyle": text(value.speechStyle),
      "motivation": text(value.motivation),
      "goal": text(value.goal),
      "conflicts": value.conflicts
          .map(
            (item) => <String, Object?>{
              "obstacle": item.obstacle,
              "resolution": item.resolution,
            },
          )
          .toList(),
      "valuesAndBeliefs": text(value.valuesAndBeliefs),
      "fear": text(value.fear),
      "relationshipSummary": text(value.relationshipSummary),
      "relationships": value.relationships
          .map(
            (item) => <String, Object?>{
              "person": item.person,
              "relationship": item.relationship,
            },
          )
          .toList(),
      "characterType": value.characterType,
      "organizations": value.organizations.map(_profileEntryToJson).toList(),
      "possessions": value.possessions.map(_possessionToJson).toList(),
      "statusEntries": value.statusEntries.map(_profileEntryToJson).toList(),
      "notes": text(value.notes),
      "advanced": <String, Object?>{
        "commonAbilities": value.advanced.commonAbilities,
        "socialTraits": value.advanced.socialTraits,
        "approaches": value.advanced.approaches,
        "personalityTraits": value.advanced.personalityTraits,
      },
      "customFields": value.customFields.map(
        (key, item) => MapEntry(key, <String, Object?>{
          "type": item.type.name,
          "rawValue": text(item.rawValue),
        }),
      ),
      "legacyFields": value.legacyFields.map(
        (key, item) =>
            MapEntry(key, omitCollaborativeText && key != "nanoId" ? "" : item),
      ),
      "textFields": value.textFields.map(
        (key, item) => MapEntry(key, text(item)),
      ),
      "alignment": value.alignment,
      "hinderEvents": value.hinderEvents
          .map(
            (item) => <String, Object?>{
              "event": item.event,
              "solve": item.solve,
            },
          )
          .toList(),
      "loveToDoList": value.loveToDoList,
      "hateToDoList": value.hateToDoList,
      "wantToDoList": value.wantToDoList,
      "fearToDoList": value.fearToDoList,
      "proficientToDoList": value.proficientToDoList,
      "unProficientToDoList": value.unProficientToDoList,
      "commonAbilityValues": value.commonAbilityValues,
      "howToShowLove": value.howToShowLove,
      "howToShowGoodwill": value.howToShowGoodwill,
      "handleHatePeople": value.handleHatePeople,
      "socialItemValues": value.socialItemValues,
      "relationship": value.relationship,
      "isFindNewLove": value.isFindNewLove,
      "isHarem": value.isHarem,
      "approachValues": value.approachValues,
      "traitsValues": value.traitsValues,
      "likeItemList": value.likeItemList,
      "admireItemList": value.admireItemList,
      "hateItemList": value.hateItemList,
      "fearItemList": value.fearItemList,
      "familiarItemList": value.familiarItemList,
    };
  }

  static CharacterEntryData _characterFromJson(
    String recordId,
    Map<String, Object?> value,
  ) => CharacterEntryData(
    characterId: recordId,
    displayName: _string(value, "displayName"),
    aliases: _objectList(value, "aliases")
        .map(
          (item) => CharacterAlias(
            type: _string(item, "type"),
            values: _stringList(item, "values"),
          ),
        )
        .toList(),
    roleOrOccupation: _string(value, "roleOrOccupation"),
    age: _string(value, "age"),
    gender: _string(value, "gender"),
    appearanceSummary: _string(value, "appearanceSummary"),
    personalitySummary: _string(value, "personalitySummary"),
    speechStyle: _string(value, "speechStyle"),
    motivation: _string(value, "motivation"),
    goal: _string(value, "goal"),
    conflicts: _objectList(value, "conflicts")
        .map(
          (item) => CharacterConflict(
            obstacle: _string(item, "obstacle"),
            resolution: _string(item, "resolution"),
          ),
        )
        .toList(),
    valuesAndBeliefs: _string(value, "valuesAndBeliefs"),
    fear: _string(value, "fear"),
    relationshipSummary: _string(value, "relationshipSummary"),
    relationships: _objectList(value, "relationships")
        .map(
          (item) => CharacterRelationship(
            person: _string(item, "person"),
            relationship: _string(item, "relationship"),
          ),
        )
        .toList(),
    characterType: _string(value, "characterType"),
    organizations: _objectList(
      value,
      "organizations",
    ).map(_profileEntryFromJson).toList(),
    possessions: _objectList(
      value,
      "possessions",
    ).map(_possessionFromJson).toList(),
    statusEntries: _objectList(
      value,
      "statusEntries",
    ).map(_profileEntryFromJson).toList(),
    notes: _string(value, "notes"),
    advanced: _advancedFromJson(_object(value, "advanced")),
    customFields: _object(value, "customFields").map((key, item) {
      final fields = _asObject(item, "custom field");
      return MapEntry(
        key,
        CustomFieldValue(
          type: _enumByName(CustomFieldType.values, _string(fields, "type")),
          rawValue: _string(fields, "rawValue"),
        ),
      );
    }),
    legacyFields: _stringMap(value, "legacyFields"),
    textFields: _stringMap(value, "textFields"),
    alignment: _nullableString(value, "alignment"),
    hinderEvents: _objectList(value, "hinderEvents")
        .map(
          (item) => CharacterHinderEvent(
            event: _string(item, "event"),
            solve: _string(item, "solve"),
          ),
        )
        .toList(),
    loveToDoList: _stringList(value, "loveToDoList"),
    hateToDoList: _stringList(value, "hateToDoList"),
    wantToDoList: _stringList(value, "wantToDoList"),
    fearToDoList: _stringList(value, "fearToDoList"),
    proficientToDoList: _stringList(value, "proficientToDoList"),
    unProficientToDoList: _stringList(value, "unProficientToDoList"),
    commonAbilityValues: _doubleList(value, "commonAbilityValues"),
    howToShowLove: _boolMap(value, "howToShowLove"),
    howToShowGoodwill: _boolMap(value, "howToShowGoodwill"),
    handleHatePeople: _boolMap(value, "handleHatePeople"),
    socialItemValues: _doubleList(value, "socialItemValues"),
    relationship: _nullableString(value, "relationship"),
    isFindNewLove: _bool(value, "isFindNewLove"),
    isHarem: _bool(value, "isHarem"),
    approachValues: _doubleList(value, "approachValues"),
    traitsValues: _doubleList(value, "traitsValues"),
    likeItemList: _stringList(value, "likeItemList"),
    admireItemList: _stringList(value, "admireItemList"),
    hateItemList: _stringList(value, "hateItemList"),
    fearItemList: _stringList(value, "fearItemList"),
    familiarItemList: _stringList(value, "familiarItemList"),
  );

  static Map<String, Object?> _patchToJson(CharacterStatePatch patch) =>
      <String, Object?>{
        "conflicts": patch.conflicts
            ?.map(
              (item) => <String, Object?>{
                "obstacle": item.obstacle,
                "resolution": item.resolution,
              },
            )
            .toList(),
        "relationships": patch.relationships
            ?.map(
              (item) => <String, Object?>{
                "person": item.person,
                "relationship": item.relationship,
              },
            )
            .toList(),
        "organizations": patch.organizations?.map(_profileEntryToJson).toList(),
        "statusEntries": patch.statusEntries?.map(_profileEntryToJson).toList(),
        "possessions": patch.possessions?.map(_possessionToJson).toList(),
        "customFields": patch.customFields?.map(
          (key, item) => MapEntry(key, <String, Object?>{
            "type": item.type.name,
            "rawValue": item.rawValue,
          }),
        ),
      };

  static CharacterStatePatch _patchFromJson(Map<String, Object?> value) =>
      CharacterStatePatch(
        conflicts: _nullableObjectList(value, "conflicts")?.map(
          (item) => CharacterConflict(
            obstacle: _string(item, "obstacle"),
            resolution: _string(item, "resolution"),
          ),
        ),
        relationships: _nullableObjectList(value, "relationships")?.map(
          (item) => CharacterRelationship(
            person: _string(item, "person"),
            relationship: _string(item, "relationship"),
          ),
        ),
        organizations: _nullableObjectList(
          value,
          "organizations",
        )?.map(_profileEntryFromJson),
        statusEntries: _nullableObjectList(
          value,
          "statusEntries",
        )?.map(_profileEntryFromJson),
        possessions: _nullableObjectList(
          value,
          "possessions",
        )?.map(_possessionFromJson),
        customFields: _nullableObject(value, "customFields")?.map((key, item) {
          final fields = _asObject(item, "patch custom field");
          return MapEntry(
            key,
            CustomFieldValue(
              type: _enumByName(
                CustomFieldType.values,
                _string(fields, "type"),
              ),
              rawValue: _string(fields, "rawValue"),
            ),
          );
        }),
      );

  static String _characterStateRecordId(CharacterState state, int index) =>
      "${state.characterId}|${state.storyTimePointId ?? "default"}|$index";
  static String _canonical(Map<String, Object?> value) => jsonEncode(value);
  static Map<String, Object?> _profileEntryToJson(
    CharacterProfileTableEntry value,
  ) => <String, Object?>{"name": value.name, "description": value.description};
  static CharacterProfileTableEntry _profileEntryFromJson(
    Map<String, Object?> value,
  ) => CharacterProfileTableEntry(
    name: _string(value, "name"),
    description: _string(value, "description"),
  );
  static Map<String, Object?> _possessionToJson(
    CharacterPossessionEntry value,
  ) => <String, Object?>{
    "name": value.name,
    "quantity": value.quantity,
    "description": value.description,
  };
  static CharacterPossessionEntry _possessionFromJson(
    Map<String, Object?> value,
  ) => CharacterPossessionEntry(
    name: _string(value, "name"),
    quantity: _string(value, "quantity"),
    description: _string(value, "description"),
  );
  static CharacterAdvancedProfile _advancedFromJson(
    Map<String, Object?> value,
  ) => CharacterAdvancedProfile(
    commonAbilities: _doubleMap(value, "commonAbilities"),
    socialTraits: _doubleMap(value, "socialTraits"),
    approaches: _doubleMap(value, "approaches"),
    personalityTraits: _doubleMap(value, "personalityTraits"),
  );

  static ProjectRecordOperation _requiredRecord(
    Map<ProjectRecordKey, ProjectRecordOperation> records,
    ProjectRecordKind kind,
    String id,
  ) {
    final value = records[ProjectRecordKey(kind: kind, recordId: id)];
    if (value == null) {
      throw FormatException("缺少 ${kind.name}:$id typed record。");
    }
    return value;
  }

  static List<ProjectRecordOperation> _recordsOf(
    Map<ProjectRecordKey, ProjectRecordOperation> records,
    ProjectRecordKind kind,
  ) => records.entries
      .where((entry) => entry.key.kind == kind)
      .map((entry) => entry.value)
      .toList(growable: false);
  static Map<String?, List<ProjectRecordOperation>> _groupByParent(
    List<ProjectRecordOperation> records,
  ) {
    final result = <String?, List<ProjectRecordOperation>>{};
    for (final record in records) {
      result
          .putIfAbsent(record.parentId, () => <ProjectRecordOperation>[])
          .add(record);
    }
    for (final list in result.values) {
      list.sort(_compareOrder);
    }
    return result;
  }

  static int _compareOrder(
    ProjectRecordOperation left,
    ProjectRecordOperation right,
  ) {
    final byOrder = _int(
      left.fields,
      "order",
    ).compareTo(_int(right.fields, "order"));
    return byOrder != 0 ? byOrder : left.recordId.compareTo(right.recordId);
  }

  static void _validateSchema(Map<String, Object?> value) {
    if (value["schemaVersion"] != schemaVersion) {
      throw const FormatException("Project record schema version 無效。");
    }
  }

  static String _string(Map<String, Object?> value, String key) {
    _validateSchemaIfPresent(value);
    final result = value[key];
    if (result is! String) throw FormatException("$key 必須是 String。");
    return result;
  }

  static String? _nullableString(Map<String, Object?> value, String key) {
    final result = value[key];
    if (result == null) return null;
    if (result is! String) throw FormatException("$key 必須是 String?。");
    return result;
  }

  static int _int(Map<String, Object?> value, String key) {
    final result = value[key];
    if (result is! int) throw FormatException("$key 必須是 int。");
    return result;
  }

  static bool _bool(Map<String, Object?> value, String key) {
    final result = value[key];
    if (result is! bool) throw FormatException("$key 必須是 bool。");
    return result;
  }

  static List<String> _stringList(Map<String, Object?> value, String key) {
    final result = value[key];
    if (result is! List || result.any((item) => item is! String)) {
      throw FormatException("$key 必須是 List<String>。");
    }
    return result.cast<String>().toList(growable: false);
  }

  static List<double> _doubleList(Map<String, Object?> value, String key) {
    final result = value[key];
    if (result is! List || result.any((item) => item is! num)) {
      throw FormatException("$key 必須是 List<double>。");
    }
    return result
        .cast<num>()
        .map((item) => item.toDouble())
        .toList(growable: false);
  }

  static Map<String, Object?> _object(Map<String, Object?> value, String key) =>
      _asObject(value[key], key);
  static Map<String, Object?>? _nullableObject(
    Map<String, Object?> value,
    String key,
  ) => value[key] == null ? null : _asObject(value[key], key);
  static Map<String, Object?> _asObject(Object? raw, String key) {
    if (raw is! Map) throw FormatException("$key 必須是 JSON object。");
    return raw.map((name, item) => MapEntry(name.toString(), item));
  }

  static List<Map<String, Object?>> _objectList(
    Map<String, Object?> value,
    String key,
  ) {
    final result = value[key];
    if (result is! List) throw FormatException("$key 必須是 object list。");
    return result.map((item) => _asObject(item, key)).toList(growable: false);
  }

  static List<Map<String, Object?>>? _nullableObjectList(
    Map<String, Object?> value,
    String key,
  ) => value[key] == null ? null : _objectList(value, key);
  static Map<String, String> _stringMap(
    Map<String, Object?> value,
    String key,
  ) => _object(value, key).map((name, item) {
    if (item is! String) throw FormatException("$key value 必須是 String。");
    return MapEntry(name, item);
  });
  static Map<String, bool> _boolMap(Map<String, Object?> value, String key) =>
      _object(value, key).map((name, item) {
        if (item is! bool) throw FormatException("$key value 必須是 bool。");
        return MapEntry(name, item);
      });
  static Map<String, double> _doubleMap(
    Map<String, Object?> value,
    String key,
  ) => _object(value, key).map((name, item) {
    if (item is! num) throw FormatException("$key value 必須是 number。");
    return MapEntry(name, item.toDouble());
  });
  static T _enumByName<T extends Enum>(List<T> values, String name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException("未知 enum value: $name");
  }

  static void _validateSchemaIfPresent(Map<String, Object?> value) {
    if (value.containsKey("schemaVersion")) {
      _validateSchema(value);
    }
  }
}
