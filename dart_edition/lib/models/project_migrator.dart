import "package:uuid/uuid.dart";

import "character_data.dart";
import "project_data.dart";

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
  static const currentVersion = "1.08";
  static const _uuid = Uuid();

  static bool requiresMigration(String? sourceVersion) {
    final version = sourceVersion?.trim();
    return version == null || _compareVersion(version, currentVersion) < 0;
  }

  static ProjectMigrationResult migrate({
    required String? sourceVersion,
    required ProjectData parsedData,
  }) {
    if (requiresMigration(sourceVersion)) {
      return _migrateLegacyTo108(parsedData);
    }

    return ProjectMigrationResult(
      data: parsedData,
      warnings: _validateReferences(parsedData),
      wasMigrated: false,
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
    return warnings;
  }

  static bool _looksLikeUuid(String value) {
    return RegExp(
      r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$",
    ).hasMatch(value);
  }
}
