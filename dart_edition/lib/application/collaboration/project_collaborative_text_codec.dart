import "../../models/character_data.dart";
import "../../models/outline_data.dart";
import "../../models/project_data.dart";
import "../../models/world_settings_data.dart";
import "../../domain/collaboration/collaboration_operation.dart";

enum ProjectCollaborativeTextKind {
  outlineStoryline,
  outlineEvent,
  outlineScene,
  character,
  characterCustomField,
  worldNode,
  worldCustomValue,
}

final class ProjectCollaborativeTextAddress {
  final ProjectCollaborativeTextKind kind;
  final String ownerId;
  final String field;

  const ProjectCollaborativeTextAddress({
    required this.kind,
    required this.ownerId,
    required this.field,
  });
}

/// Owns the stable document ids and ProjectData projection for non-chapter
/// text that participates in CRDT collaboration.
///
/// Collection membership, ordering, enums and numeric values remain in the
/// typed operation log. Only scalar text with a stable owner id is represented
/// here.
abstract final class ProjectCollaborativeTextCodec {
  static const String documentPrefix =
      CollaborationSchema.projectTextDocumentPrefix;

  static String outlineStorylineFieldId(String storylineId, String field) =>
      _documentId(
        ProjectCollaborativeTextKind.outlineStoryline,
        storylineId,
        field,
      );

  static String outlineEventFieldId(String eventId, String field) =>
      _documentId(ProjectCollaborativeTextKind.outlineEvent, eventId, field);

  static String outlineSceneFieldId(String sceneId, String field) =>
      _documentId(ProjectCollaborativeTextKind.outlineScene, sceneId, field);

  static String characterFieldId(String characterId, String field) =>
      _documentId(ProjectCollaborativeTextKind.character, characterId, field);

  static String characterCustomFieldId(String characterId, String field) =>
      _documentId(
        ProjectCollaborativeTextKind.characterCustomField,
        characterId,
        field,
      );

  static String worldNodeFieldId(String nodeId, String field) =>
      _documentId(ProjectCollaborativeTextKind.worldNode, nodeId, field);

  static String worldCustomValueFieldId(String valueId, String field) =>
      _documentId(
        ProjectCollaborativeTextKind.worldCustomValue,
        valueId,
        field,
      );

  static bool isProjectTextDocumentId(String documentId) =>
      documentId.startsWith(documentPrefix);

  static ProjectCollaborativeTextAddress? tryParse(String documentId) {
    final parts = documentId.split(":");
    if (parts.length != 4 || "${parts[0]}:" != documentPrefix) return null;
    final kind = ProjectCollaborativeTextKind.values
        .where((value) => value.name == parts[1])
        .firstOrNull;
    if (kind == null) return null;
    try {
      final ownerId = Uri.decodeComponent(parts[2]);
      final field = Uri.decodeComponent(parts[3]);
      if (ownerId.trim().isEmpty || field.trim().isEmpty) return null;
      return ProjectCollaborativeTextAddress(
        kind: kind,
        ownerId: ownerId,
        field: field,
      );
    } on FormatException {
      return null;
    }
  }

  static Map<String, String> snapshot(ProjectData data) {
    final result = <String, String>{};
    for (final storyline in data.outlineData) {
      _putOutlineStoryline(result, storyline);
      for (final event in storyline.scenes) {
        _putOutlineEvent(result, event);
        for (final scene in event.scenes) {
          _putOutlineScene(result, scene);
        }
      }
    }
    for (final entry in data.characterData.entries) {
      _putCharacter(result, entry.key, entry.value);
    }
    void addWorldNodes(List<LocationData> nodes) {
      for (final node in nodes) {
        result[worldNodeFieldId(node.id, "localName")] = node.localName;
        result[worldNodeFieldId(node.id, "localType")] = node.localType;
        result[worldNodeFieldId(node.id, "note")] = node.note;
        for (final customValue in node.customVal) {
          result[worldCustomValueFieldId(customValue.id, "key")] =
              customValue.key;
          result[worldCustomValueFieldId(customValue.id, "val")] =
              customValue.val;
        }
        addWorldNodes(node.child);
      }
    }

    addWorldNodes(data.worldSettingsData);
    return Map<String, String>.unmodifiable(result);
  }

  static List<StorylineData> applyToOutline(
    List<StorylineData> source,
    String documentId,
    String text,
  ) {
    final address = tryParse(documentId);
    if (address == null ||
        !const <ProjectCollaborativeTextKind>{
          ProjectCollaborativeTextKind.outlineStoryline,
          ProjectCollaborativeTextKind.outlineEvent,
          ProjectCollaborativeTextKind.outlineScene,
        }.contains(address.kind)) {
      return source;
    }
    var changed = false;
    final next = source
        .map((storyline) {
          var updatedStoryline = storyline;
          if (address.kind == ProjectCollaborativeTextKind.outlineStoryline &&
              storyline.chapterUUID == address.ownerId) {
            updatedStoryline = _updateStorylineField(
              storyline,
              address.field,
              text,
            );
          }
          final events = updatedStoryline.scenes
              .map((event) {
                var updatedEvent = event;
                if (address.kind == ProjectCollaborativeTextKind.outlineEvent &&
                    event.storyEventUUID == address.ownerId) {
                  updatedEvent = _updateEventField(event, address.field, text);
                }
                final scenes = updatedEvent.scenes
                    .map((scene) {
                      if (address.kind !=
                              ProjectCollaborativeTextKind.outlineScene ||
                          scene.sceneUUID != address.ownerId) {
                        return scene;
                      }
                      return _updateSceneField(scene, address.field, text);
                    })
                    .toList(growable: false);
                if (!_sameIdentityList(scenes, updatedEvent.scenes)) {
                  updatedEvent = updatedEvent.copyWith(scenes: scenes);
                }
                return updatedEvent;
              })
              .toList(growable: false);
          if (!_sameIdentityList(events, updatedStoryline.scenes)) {
            updatedStoryline = updatedStoryline.copyWith(scenes: events);
          }
          if (!identical(updatedStoryline, storyline)) changed = true;
          return updatedStoryline;
        })
        .toList(growable: false);
    return changed ? List<StorylineData>.unmodifiable(next) : source;
  }

  static Map<String, CharacterEntryData> applyToCharacters(
    Map<String, CharacterEntryData> source,
    String documentId,
    String text,
  ) {
    final address = tryParse(documentId);
    if (address == null ||
        (address.kind != ProjectCollaborativeTextKind.character &&
            address.kind !=
                ProjectCollaborativeTextKind.characterCustomField)) {
      return source;
    }
    final current = source[address.ownerId];
    if (current == null) return source;
    final updated = address.kind == ProjectCollaborativeTextKind.character
        ? _updateCharacterField(current, address.field, text)
        : _updateCharacterCustomField(current, address.field, text);
    if (identical(updated, current)) return source;
    return Map<String, CharacterEntryData>.unmodifiable(
      <String, CharacterEntryData>{...source, address.ownerId: updated},
    );
  }

  static List<LocationData> applyToWorldSettings(
    List<LocationData> source,
    String documentId,
    String text,
  ) {
    final address = tryParse(documentId);
    if (address == null ||
        (address.kind != ProjectCollaborativeTextKind.worldNode &&
            address.kind != ProjectCollaborativeTextKind.worldCustomValue)) {
      return source;
    }
    var changed = false;
    List<LocationData> updateNodes(List<LocationData> nodes) {
      return nodes
          .map((node) {
            var updated = node;
            if (address.kind == ProjectCollaborativeTextKind.worldNode &&
                node.id == address.ownerId) {
              updated = switch (address.field) {
                "localName" when node.localName != text => node.copyWith(
                  localName: text,
                ),
                "localType" when node.localType != text => node.copyWith(
                  localType: text,
                ),
                "note" when node.note != text => node.copyWith(note: text),
                _ => node,
              };
            }
            if (address.kind == ProjectCollaborativeTextKind.worldCustomValue) {
              final values = updated.customVal
                  .map((value) {
                    if (value.id != address.ownerId) return value;
                    return switch (address.field) {
                      "key" when value.key != text => value.copyWith(key: text),
                      "val" when value.val != text => value.copyWith(val: text),
                      _ => value,
                    };
                  })
                  .toList(growable: false);
              if (!_sameIdentityList(values, updated.customVal)) {
                updated = updated.copyWith(customVal: values);
              }
            }
            final children = updateNodes(updated.child);
            if (!_sameIdentityList(children, updated.child)) {
              updated = updated.copyWith(child: children);
            }
            if (!identical(updated, node)) changed = true;
            return updated;
          })
          .toList(growable: false);
    }

    final next = updateNodes(source);
    return changed ? List<LocationData>.unmodifiable(next) : source;
  }

  static List<StorylineData> overlayOutline(
    List<StorylineData> source,
    Map<String, String> documents,
  ) {
    var result = source;
    for (final entry in documents.entries) {
      result = applyToOutline(result, entry.key, entry.value);
    }
    return result;
  }

  static Map<String, CharacterEntryData> overlayCharacters(
    Map<String, CharacterEntryData> source,
    Map<String, String> documents,
  ) {
    var result = source;
    for (final entry in documents.entries) {
      result = applyToCharacters(result, entry.key, entry.value);
    }
    return result;
  }

  static List<LocationData> overlayWorldSettings(
    List<LocationData> source,
    Map<String, String> documents,
  ) {
    var result = source;
    for (final entry in documents.entries) {
      result = applyToWorldSettings(result, entry.key, entry.value);
    }
    return result;
  }

  static String _documentId(
    ProjectCollaborativeTextKind kind,
    String ownerId,
    String field,
  ) {
    final normalizedOwnerId = ownerId.trim();
    final normalizedField = field.trim();
    if (normalizedOwnerId.isEmpty || normalizedField.isEmpty) {
      throw ArgumentError("Project CRDT text owner/field 不可為空。");
    }
    return "$documentPrefix${kind.name}:"
        "${Uri.encodeComponent(normalizedOwnerId)}:"
        "${Uri.encodeComponent(normalizedField)}";
  }

  static void _putOutlineStoryline(
    Map<String, String> result,
    StorylineData value,
  ) {
    result[outlineStorylineFieldId(value.chapterUUID, "storylineName")] =
        value.storylineName;
    result[outlineStorylineFieldId(value.chapterUUID, "storylineType")] =
        value.storylineType;
    result[outlineStorylineFieldId(value.chapterUUID, "memo")] = value.memo;
    result[outlineStorylineFieldId(value.chapterUUID, "conflictPoint")] =
        value.conflictPoint;
  }

  static void _putOutlineEvent(
    Map<String, String> result,
    StoryEventData value,
  ) {
    result[outlineEventFieldId(value.storyEventUUID, "storyEvent")] =
        value.storyEvent;
    result[outlineEventFieldId(value.storyEventUUID, "memo")] = value.memo;
    result[outlineEventFieldId(value.storyEventUUID, "conflictPoint")] =
        value.conflictPoint;
  }

  static void _putOutlineScene(Map<String, String> result, SceneData value) {
    result[outlineSceneFieldId(value.sceneUUID, "sceneName")] = value.sceneName;
    result[outlineSceneFieldId(value.sceneUUID, "time")] = value.time;
    result[outlineSceneFieldId(value.sceneUUID, "location")] = value.location;
    result[outlineSceneFieldId(value.sceneUUID, "focusPoint")] =
        value.focusPoint;
    result[outlineSceneFieldId(value.sceneUUID, "conflictPoint")] =
        value.conflictPoint;
    result[outlineSceneFieldId(value.sceneUUID, "memo")] = value.memo;
  }

  static void _putCharacter(
    Map<String, String> result,
    String characterId,
    CharacterEntryData value,
  ) {
    final controllerFields = <String>{
      ...CharacterDataKeys.allControllerKeys,
      ...value.textFields.keys,
    }..remove("nanoId");
    for (final field in controllerFields) {
      result[characterFieldId(characterId, field)] = _characterFieldValue(
        value,
        field,
      );
    }
    for (final entry in value.customFields.entries) {
      result[characterCustomFieldId(characterId, entry.key)] =
          entry.value.rawValue;
    }
  }

  static String _characterFieldValue(CharacterEntryData value, String field) {
    return switch (field) {
      "name" => value.displayName,
      "roleOrOccupation" => value.roleOrOccupation,
      "age" => value.age,
      "gender" => value.gender,
      "appearanceSummary" => value.appearanceSummary,
      "personalitySummary" => value.personalitySummary,
      "speechStyle" => value.speechStyle,
      "motivation" => value.motivation,
      "goal" => value.goal,
      "valuesAndBeliefs" => value.valuesAndBeliefs,
      "fear" => value.fear,
      "relationshipSummary" => value.relationshipSummary,
      "notes" => value.notes,
      _ => value.textFields[field] ?? "",
    };
  }

  static CharacterEntryData _updateCharacterField(
    CharacterEntryData value,
    String field,
    String text,
  ) {
    final current = _characterFieldValue(value, field);
    if (current == text) return value;
    var updated = value.withTextField(field, text);
    updated = switch (field) {
      "name" => updated.copyWith(displayName: text),
      "roleOrOccupation" => updated.copyWith(roleOrOccupation: text),
      "age" => updated.copyWith(age: text),
      "gender" => updated.copyWith(gender: text),
      "appearanceSummary" => updated.copyWith(appearanceSummary: text),
      "personalitySummary" => updated.copyWith(personalitySummary: text),
      "speechStyle" => updated.copyWith(speechStyle: text),
      "motivation" => updated.copyWith(motivation: text),
      "goal" => updated.copyWith(goal: text),
      "valuesAndBeliefs" => updated.copyWith(valuesAndBeliefs: text),
      "fear" => updated.copyWith(fear: text),
      "relationshipSummary" => updated.copyWith(relationshipSummary: text),
      "notes" => updated.copyWith(notes: text),
      _ => updated,
    };
    return updated;
  }

  static CharacterEntryData _updateCharacterCustomField(
    CharacterEntryData value,
    String field,
    String text,
  ) {
    final current = value.customFields[field];
    if (current == null || current.rawValue == text) return value;
    return value.copyWith(
      customFields: <String, CustomFieldValue>{
        ...value.customFields,
        field: CustomFieldValue(type: current.type, rawValue: text),
      },
    );
  }

  static StorylineData _updateStorylineField(
    StorylineData value,
    String field,
    String text,
  ) => switch (field) {
    "storylineName" when value.storylineName != text => value.copyWith(
      storylineName: text,
    ),
    "storylineType" when value.storylineType != text => value.copyWith(
      storylineType: text,
    ),
    "memo" when value.memo != text => value.copyWith(memo: text),
    "conflictPoint" when value.conflictPoint != text => value.copyWith(
      conflictPoint: text,
    ),
    _ => value,
  };

  static StoryEventData _updateEventField(
    StoryEventData value,
    String field,
    String text,
  ) => switch (field) {
    "storyEvent" when value.storyEvent != text => value.copyWith(
      storyEvent: text,
    ),
    "memo" when value.memo != text => value.copyWith(memo: text),
    "conflictPoint" when value.conflictPoint != text => value.copyWith(
      conflictPoint: text,
    ),
    _ => value,
  };

  static SceneData _updateSceneField(
    SceneData value,
    String field,
    String text,
  ) => switch (field) {
    "sceneName" when value.sceneName != text => value.copyWith(sceneName: text),
    "time" when value.time != text => value.copyWith(time: text),
    "location" when value.location != text => value.copyWith(location: text),
    "focusPoint" when value.focusPoint != text => value.copyWith(
      focusPoint: text,
    ),
    "conflictPoint" when value.conflictPoint != text => value.copyWith(
      conflictPoint: text,
    ),
    "memo" when value.memo != text => value.copyWith(memo: text),
    _ => value,
  };

  static bool _sameIdentityList<T>(List<T> left, List<T> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (!identical(left[index], right[index])) return false;
    }
    return true;
  }
}
