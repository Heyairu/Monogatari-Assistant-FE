import "package:uuid/uuid.dart";

import "character_data.dart";
import "chapter_selection_data.dart";
import "project_data.dart";
import "timeline_data.dart";

class ProjectMigrationResult {
  final ProjectData data;
  final List<ProjectMigrationWarning> warnings;
  final bool wasMigrated;

  const ProjectMigrationResult({
    required this.data,
    required this.warnings,
    required this.wasMigrated,
  });
}

/// Owns all project-format upgrades. Module codecs only decode their XML shape;
/// they never guess which historical project version they received.
class ProjectMigrator {
  static const currentVersion = "1.10";
  static const _legacyMigrationCutoff = "1.08";
  static const _timelineProjectionCutoff = "1.10";
  static const _uuid = Uuid();

  /// Whether the source still needs the destructive legacy normalization.
  ///
  /// Timeline projection upgrades are handled separately so a 1.08/1.09 file
  /// never re-runs the destructive 1.06/1.07 character migration.
  static bool requiresMigration(String? sourceVersion) {
    final version = sourceVersion?.trim();
    if (version == null || version.isEmpty) return true;
    // A short-lived development build wrote 0.10. Treat it as structured data
    // rather than sending it through the legacy character migration.
    if (_compareVersion(version, "0.10") >= 0 &&
        _compareVersion(version, "1.0") < 0) {
      return false;
    }
    return _compareVersion(version, _legacyMigrationCutoff) < 0;
  }

  static ProjectMigrationResult migrate({
    required String? sourceVersion,
    required ProjectData parsedData,
  }) {
    if (requiresMigration(sourceVersion)) {
      final legacy = _migrateLegacyTo108(parsedData);
      final timelineUpgrade = _upgradeTimelineProjection(
        sourceVersion: sourceVersion,
        source: legacy.data,
      );
      return ProjectMigrationResult(
        data: timelineUpgrade.data,
        warnings: legacy.warnings,
        wasMigrated: true,
      );
    }

    final timelineUpgrade = _upgradeTimelineProjection(
      sourceVersion: sourceVersion,
      source: parsedData,
    );
    return ProjectMigrationResult(
      data: timelineUpgrade.data,
      warnings: _validateReferences(timelineUpgrade.data),
      wasMigrated: timelineUpgrade.changed,
    );
  }

  static ({ProjectData data, bool changed}) _upgradeTimelineProjection({
    required String? sourceVersion,
    required ProjectData source,
  }) {
    final version = sourceVersion?.trim();
    if (version != null &&
        version.isNotEmpty &&
        _compareVersion(version, _timelineProjectionCutoff) >= 0) {
      return (data: source, changed: false);
    }

    var document = source.timelineDocument;
    var placements = [...document.placements];
    final placementIndex = <String, int>{
      for (var index = 0; index < placements.length; index++)
        placements[index].placementUUID: index,
    };

    // Version 1.09 placements only linked small boxes. Recover the enclosing
    // middle/large outline UUIDs from the authoritative scene hierarchy before
    // filling any missing boxes.
    for (final storyline in source.outlineData) {
      for (final event in storyline.scenes) {
        for (final scene in event.scenes) {
          final smallIndex = placements.indexWhere(
            (placement) => placement.sceneUUID == scene.sceneUUID,
          );
          if (smallIndex < 0) continue;
          final small = placements[smallIndex].copyWith(
            storylineUUID: storyline.chapterUUID,
            eventUUID: event.storyEventUUID,
          );
          placements[smallIndex] = small;

          final middleUUID = small.parentPlacementUUID;
          final middleIndex = middleUUID == null
              ? null
              : placementIndex[middleUUID];
          if (middleIndex == null) continue;
          final middle = placements[middleIndex].copyWith(
            storylineUUID: storyline.chapterUUID,
            eventUUID: event.storyEventUUID,
          );
          placements[middleIndex] = middle;

          final largeUUID = middle.parentPlacementUUID;
          final largeIndex = largeUUID == null
              ? null
              : placementIndex[largeUUID];
          if (largeIndex == null) continue;
          placements[largeIndex] = placements[largeIndex].copyWith(
            storylineUUID: storyline.chapterUUID,
          );
        }
      }
    }
    document = document.copyWith(placements: placements);

    // Do not seed the parser's synthetic empty default outline in files that
    // contain no outline content. Genuine old outlines with events are rebuilt
    // as a complete large → middle → small projection.
    final meaningfulOutline = source.outlineData
        .where((storyline) => storyline.scenes.isNotEmpty)
        .toList(growable: false);
    if (meaningfulOutline.isNotEmpty) {
      document = TimelineOutlineMapper.seedFromOutline(
        document,
        meaningfulOutline,
      );
    }

    if (document == source.timelineDocument) {
      return (data: source, changed: false);
    }
    return (
      data: ProjectData(
        baseInfoData: source.baseInfoData,
        segmentsData: source.segmentsData,
        outlineData: source.outlineData,
        foreshadowData: source.foreshadowData,
        updatePlanData: source.updatePlanData,
        worldSettingsData: source.worldSettingsData,
        characterData: source.characterData,
        characterStates: source.characterStates,
        timelineDocument: document,
        outlineChapterLinks: source.outlineChapterLinks,
        totalWords: source.totalWords,
        contentText: source.contentText,
        isDirty: source.isDirty,
      ),
      changed: true,
    );
  }

  static int _compareVersion(String left, String right) {
    final leftParts = left.split(".").map((part) => int.tryParse(part) ?? 0);
    final rightParts = right.split(".").map((part) => int.tryParse(part) ?? 0);
    final a = leftParts.toList();
    final b = rightParts.toList();
    final length = a.length > b.length ? a.length : b.length;
    for (var index = 0; index < length; index++) {
      final leftValue = index < a.length ? a[index] : 0;
      final rightValue = index < b.length ? b[index] : 0;
      if (leftValue != rightValue) return leftValue.compareTo(rightValue);
    }
    return 0;
  }

  static ProjectMigrationResult _migrateLegacyTo108(ProjectData source) {
    final warnings = <ProjectMigrationWarning>[];
    final characters = <String, CharacterEntryData>{};

    for (final sourceEntry in source.characterData.entries) {
      var character = sourceEntry.value;
      var id = character.characterId.trim();
      if (id.isEmpty || characters.containsKey(id)) {
        if (id.isNotEmpty) {
          warnings.add(
            ProjectMigrationWarning(
              code: "duplicate-character-id",
              message: "角色 ID 重複，已產生新的 UUID。",
              originalText: id,
            ),
          );
        }
        id = _uuid.v4();
      }

      final displayName = character.displayName.trim().isNotEmpty
          ? character.displayName.trim()
          : (character.textFields["name"] ?? sourceEntry.key).trim();
      character = character
          .copyWith(characterId: id, displayName: displayName)
          .withTextField("name", displayName);
      characters[id] = character;
    }

    final ids = characters.keys.toSet();
    final idsByName = <String, List<String>>{};
    for (final entry in characters.entries) {
      idsByName
          .putIfAbsent(entry.value.displayName, () => <String>[])
          .add(entry.key);
    }

    List<String> migratePeople(List<String> people, String owner) {
      return people
          .map((raw) {
            final value = raw.trim();
            if (value.isEmpty || ids.contains(value)) {
              return value;
            }
            final matches = idsByName[value] ?? const <String>[];
            if (matches.length == 1) {
              return matches.single;
            }
            warnings.add(
              ProjectMigrationWarning(
                code: matches.isEmpty
                    ? "character-reference-not-found"
                    : "ambiguous-character-reference",
                message: matches.isEmpty
                    ? "$owner 的人物「$value」找不到對應角色，已保留原始文字。"
                    : "$owner 的人物「$value」有多個同名角色，已保留原始文字。",
                originalText: raw,
              ),
            );
            return raw;
          })
          .toList(growable: false);
    }

    final outline = source.outlineData
        .map((storyline) {
          return storyline.copyWith(
            people: migratePeople(
              storyline.people,
              "故事線 ${storyline.storylineName}",
            ),
            scenes: storyline.scenes
                .map((event) {
                  return event.copyWith(
                    people: migratePeople(
                      event.people,
                      "事件 ${event.storyEvent}",
                    ),
                    scenes: event.scenes
                        .map((scene) {
                          return scene.copyWith(
                            people: migratePeople(
                              scene.people,
                              "場景 ${scene.sceneName}",
                            ),
                            timePointIso8601:
                                scene.timePointIso8601 ??
                                DateTime.tryParse(
                                  scene.time,
                                )?.toIso8601String(),
                          );
                        })
                        .toList(growable: false),
                  );
                })
                .toList(growable: false),
          );
        })
        .toList(growable: false);

    final migratedData = ProjectData(
      baseInfoData: source.baseInfoData,
      segmentsData: source.segmentsData,
      outlineData: outline,
      foreshadowData: source.foreshadowData,
      updatePlanData: source.updatePlanData,
      worldSettingsData: source.worldSettingsData,
      characterData: characters,
      characterStates: source.characterStates,
      timelineDocument: source.timelineDocument,
      outlineChapterLinks: source.outlineChapterLinks,
      totalWords: source.totalWords,
      contentText: source.contentText,
      isDirty: source.isDirty,
    );
    warnings.addAll(_validateReferences(migratedData));
    return ProjectMigrationResult(
      data: migratedData,
      warnings: warnings,
      wasMigrated: true,
    );
  }

  static List<ProjectMigrationWarning> _validateReferences(ProjectData data) {
    final warnings = <ProjectMigrationWarning>[];
    final characterIds = data.characterData.keys.toSet();
    final sceneIds = <String>{};
    for (final storyline in data.outlineData) {
      for (final event in storyline.scenes) {
        sceneIds.addAll(event.scenes.map((scene) => scene.sceneUUID));
      }
    }
    final chapterIds = ChapterTree.chaptersDepthFirst(
      data.segmentsData,
    ).map((location) => location.chapter.chapterUUID).toSet();
    final trackIds = data.timelineDocument.tracks
        .map((track) => track.trackUUID)
        .toSet();
    final placementIds = data.timelineDocument.placements
        .map((placement) => placement.placementUUID)
        .toSet();

    void validatePeople(List<String> values, String owner) {
      for (final value in values) {
        if (_looksLikeUuid(value) && !characterIds.contains(value)) {
          warnings.add(
            ProjectMigrationWarning(
              code: "dangling-character-reference",
              message: "$owner 引用了不存在的角色 ID，原值已保留。",
              originalText: value,
            ),
          );
        }
      }
    }

    for (final storyline in data.outlineData) {
      validatePeople(storyline.people, "故事線 ${storyline.storylineName}");
      for (final event in storyline.scenes) {
        validatePeople(event.people, "事件 ${event.storyEvent}");
        for (final scene in event.scenes) {
          validatePeople(scene.people, "場景 ${scene.sceneName}");
        }
      }
    }
    for (final state in data.characterStates) {
      if (!characterIds.contains(state.characterId)) {
        warnings.add(
          ProjectMigrationWarning(
            code: "dangling-character-state",
            message: "角色狀態引用了不存在的角色 ID，原值已保留。",
            originalText: state.characterId,
          ),
        );
      }
    }
    final seenLinks = <String>{};
    for (final OutlineChapterLinkData link in data.outlineChapterLinks) {
      final pair = "${link.sceneUUID}\u0000${link.chapterUUID}";
      if (!seenLinks.add(pair)) {
        warnings.add(
          ProjectMigrationWarning(
            code: "duplicate-timeline-link",
            message: "時間軸中存在重複的場景與章節關聯。",
            originalText: pair,
          ),
        );
      }
      if (!sceneIds.contains(link.sceneUUID)) {
        warnings.add(
          ProjectMigrationWarning(
            code: "dangling-timeline-scene-link",
            message: "時間軸關聯引用了不存在的場景，原值已保留。",
            originalText: link.sceneUUID,
          ),
        );
      }
      if (!chapterIds.contains(link.chapterUUID)) {
        warnings.add(
          ProjectMigrationWarning(
            code: "dangling-timeline-chapter-link",
            message: "時間軸關聯引用了不存在的章節，原值已保留。",
            originalText: link.chapterUUID,
          ),
        );
      }
    }
    for (final placement in data.timelineDocument.placements) {
      if (!trackIds.contains(placement.trackUUID)) {
        warnings.add(
          ProjectMigrationWarning(
            code: "dangling-timeline-track-reference",
            message: "時間軸節點引用了不存在的軌道，原值已保留。",
            originalText: placement.trackUUID,
          ),
        );
      }
      if (placement.sceneUUID != null &&
          !sceneIds.contains(placement.sceneUUID)) {
        warnings.add(
          ProjectMigrationWarning(
            code: "dangling-timeline-placement-scene",
            message: "時間軸節點引用了不存在的場景，原值已保留。",
            originalText: placement.sceneUUID,
          ),
        );
      }
      if (placement.parentPlacementUUID != null &&
          !placementIds.contains(placement.parentPlacementUUID)) {
        warnings.add(
          ProjectMigrationWarning(
            code: "dangling-timeline-parent-reference",
            message: "時間軸節點引用了不存在的父節點，原值已保留。",
            originalText: placement.parentPlacementUUID,
          ),
        );
      }
    }
    return warnings;
  }

  static bool _looksLikeUuid(String value) {
    return RegExp(
      r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$",
    ).hasMatch(value);
  }
}
