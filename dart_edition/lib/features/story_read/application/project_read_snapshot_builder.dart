import "dart:convert";

import "../../../models/chapter_selection_data.dart";
import "../../../models/glossary_data.dart";
import "../../../models/project_data.dart";
import "../../../models/world_settings_data.dart";
import "../domain/project_read_models.dart";

final class ProjectReadSnapshotBuilder {
  const ProjectReadSnapshotBuilder._();

  static ProjectReadSnapshot build(
    ProjectData project, {
    Map<String, GlossaryEntry> glossaryEntries =
        const <String, GlossaryEntry>{},
  }) {
    final catalog = _buildSelectableResources(
      project,
      glossaryEntries: glossaryEntries,
    );
    final chapterCatalog = _buildChapters(project.segmentsData);
    return ProjectReadSnapshot(
      projectId: project.projectUUID,
      overview: buildOverview(project),
      chapters: chapterCatalog.chapters,
      entities: catalog.resources,
      omissions: <ProjectReadOmission>[
        ...chapterCatalog.omissions,
        ...catalog.omissions,
      ],
    );
  }

  static List<ProjectReadSelectableResource> selectableResources(
    ProjectData project, {
    Map<String, GlossaryEntry> glossaryEntries =
        const <String, GlossaryEntry>{},
  }) {
    return _buildSelectableResources(
      project,
      glossaryEntries: glossaryEntries,
    ).resources;
  }

  static ProjectReadResource buildOverview(ProjectData project) {
    final chapters = <Map<String, String>>[];
    void collectChapters(List<SegmentData> folders) {
      for (final folder in folders) {
        for (final chapter in folder.chapters) {
          if (chapters.length >= ProjectReadBudget.maxChapterIndexItems) return;
          chapters.add(<String, String>{
            "id": chapter.chapterUUID,
            "title": chapter.chapterName,
          });
        }
        if (chapters.length >= ProjectReadBudget.maxChapterIndexItems) return;
        collectChapters(folder.childSegments);
      }
    }

    collectChapters(project.segmentsData);
    final world = <Map<String, String>>[];
    void collectWorld(List<LocationData> nodes) {
      for (final node in nodes) {
        if (world.length >= ProjectReadBudget.maxWorldItems) return;
        world.add(<String, String>{
          "id": node.id,
          "name": node.localName,
          "type": node.nodeType.xmlValue,
        });
        collectWorld(node.child);
      }
    }

    collectWorld(project.worldSettingsData);
    final content = jsonEncode(<String, Object?>{
      "book": <String, Object?>{
        "name": project.baseInfoData.bookName,
        "storyType": project.baseInfoData.storyType,
        "intro": project.baseInfoData.intro,
        "tags": project.baseInfoData.tags,
        "totalWords": project.totalWords,
      },
      "chapters": chapters,
      "characters": project.characterData.values
          .take(ProjectReadBudget.maxCharacterItems)
          .map(
            (character) => <String, String>{
              "id": character.characterId,
              "name": character.displayName,
              "type": character.characterType,
              "goal": character.goal,
            },
          )
          .toList(growable: false),
      "outline": project.outlineData
          .take(ProjectReadBudget.maxOutlineItems)
          .map(
            (storyline) => <String, Object?>{
              "id": storyline.chapterUUID,
              "name": storyline.storylineName,
              "type": storyline.storylineType,
              "events": storyline.scenes
                  .map(
                    (event) => <String, String>{
                      "id": event.storyEventUUID,
                      "name": event.storyEvent,
                    },
                  )
                  .toList(growable: false),
            },
          )
          .toList(growable: false),
      "world": world,
    });
    return ProjectReadResource.bounded(
      resourceType: ProjectReadResourceType.project,
      resourceId: "project-overview",
      title: project.baseInfoData.bookName.trim().isEmpty
          ? "專案摘要"
          : project.baseInfoData.bookName.trim(),
      content: content,
      maxBytes: ProjectReadBudget.maxOverviewBytes,
    );
  }

  static ({
    List<ProjectReadChapter> chapters,
    List<ProjectReadOmission> omissions,
  })
  _buildChapters(List<SegmentData> segments) {
    final result = <ProjectReadChapter>[];
    final omissions = <ProjectReadOmission>[];
    final seenIds = <String>{};
    for (final location in ChapterTree.chaptersDepthFirst(segments)) {
      final chapterId = location.chapter.chapterUUID.trim();
      if (chapterId.isEmpty || !seenIds.add(chapterId)) {
        omissions.add(
          ProjectReadOmission(
            resourceType: ProjectReadResourceType.chapter,
            sourceKey: location.folder.segmentUUID,
            reason: chapterId.isEmpty ? "empty_id" : "duplicate_id",
          ),
        );
        continue;
      }
      result.add(
        ProjectReadChapter(
          chapterId: chapterId,
          folderId: location.folder.segmentUUID,
          title: location.chapter.chapterName,
          content: location.chapter.chapterContent,
          order: result.length,
        ),
      );
    }
    return (
      chapters: List<ProjectReadChapter>.unmodifiable(result),
      omissions: List<ProjectReadOmission>.unmodifiable(omissions),
    );
  }

  static ({
    List<ProjectReadSelectableResource> resources,
    List<ProjectReadOmission> omissions,
  })
  _buildSelectableResources(
    ProjectData project, {
    required Map<String, GlossaryEntry> glossaryEntries,
  }) {
    final resources = <ProjectReadSelectableResource>[];
    final omissions = <ProjectReadOmission>[];
    final seenKeys = <String>{};

    void addResource(
      ProjectReadSelectableResource resource, {
      required String sourceKey,
    }) {
      final id = resource.resourceId.trim();
      if (id.isEmpty) {
        omissions.add(
          ProjectReadOmission(
            resourceType: resource.resourceType,
            sourceKey: sourceKey,
            reason: "empty_id",
          ),
        );
        return;
      }
      if (!seenKeys.add(resource.selectionKey)) {
        omissions.add(
          ProjectReadOmission(
            resourceType: resource.resourceType,
            sourceKey: sourceKey,
            reason: "duplicate_id",
          ),
        );
        return;
      }
      resources.add(resource);
    }

    for (final characterEntry in project.characterData.entries.take(
      ProjectReadBudget.maxCharacterItems,
    )) {
      final character = characterEntry.value;
      final resourceId = character.characterId.trim().isEmpty
          ? characterEntry.key.trim()
          : character.characterId.trim();
      addResource(
        ProjectReadSelectableResource(
          resourceType: ProjectReadResourceType.character,
          resourceId: resourceId,
          title: character.displayName.trim().isEmpty
              ? "未命名角色"
              : character.displayName.trim(),
          description: "角色・${character.characterType}",
          content: jsonEncode(<String, Object?>{
            "id": resourceId,
            "name": character.displayName,
            "type": character.characterType,
            "roleOrOccupation": character.roleOrOccupation,
            "aliases": character.aliases
                .expand((alias) => alias.values)
                .toList(growable: false),
            "age": character.age,
            "gender": character.gender,
            "appearance": character.appearanceSummary,
            "personality": character.personalitySummary,
            "speechStyle": character.speechStyle,
            "motivation": character.motivation,
            "goal": character.goal,
            "conflicts": character.conflicts
                .map(
                  (conflict) => <String, String>{
                    "obstacle": conflict.obstacle,
                    "resolution": conflict.resolution,
                  },
                )
                .toList(growable: false),
            "valuesAndBeliefs": character.valuesAndBeliefs,
            "fear": character.fear,
            "relationshipSummary": character.relationshipSummary,
            "relationships": character.relationships
                .map(
                  (relationship) => <String, String>{
                    "person": relationship.person,
                    "relationship": relationship.relationship,
                    "internalRelationship": relationship.internalRelationship,
                  },
                )
                .toList(growable: false),
            "notes": character.notes,
          }),
        ),
        sourceKey: characterEntry.key,
      );
    }

    var worldCount = 0;
    void collectWorld(List<LocationData> nodes) {
      for (final node in nodes) {
        if (worldCount >= ProjectReadBudget.maxWorldItems) return;
        addResource(
          ProjectReadSelectableResource(
            resourceType: ProjectReadResourceType.worldSetting,
            resourceId: node.id,
            title: node.localName.trim().isEmpty
                ? "未命名世界觀項目"
                : node.localName.trim(),
            description: "世界觀・${node.nodeType.label}",
            content: jsonEncode(<String, Object?>{
              "id": node.id,
              "name": node.localName,
              "type": node.nodeType.xmlValue,
              "category": node.localType,
              "properties": <String, String>{
                for (final value in node.customVal) value.key: value.val,
              },
              "note": node.note,
            }),
          ),
          sourceKey: node.id,
        );
        worldCount++;
        collectWorld(node.child);
      }
    }

    collectWorld(project.worldSettingsData);

    var outlineCount = 0;
    for (final storyline in project.outlineData) {
      if (outlineCount >= ProjectReadBudget.maxOutlineItems) break;
      addResource(
        ProjectReadSelectableResource(
          resourceType: ProjectReadResourceType.outlineEvent,
          resourceId: storyline.chapterUUID,
          title: storyline.storylineName.trim().isEmpty
              ? "未命名大綱"
              : storyline.storylineName.trim(),
          description: "大綱・${storyline.storylineType}",
          content: jsonEncode(<String, Object?>{
            "kind": "storyline",
            "id": storyline.chapterUUID,
            "name": storyline.storylineName,
            "type": storyline.storylineType,
            "memo": storyline.memo,
            "conflictPoint": storyline.conflictPoint,
            "people": storyline.people,
            "items": storyline.item,
            "events": storyline.scenes
                .map(
                  (event) => <String, String>{
                    "id": event.storyEventUUID,
                    "name": event.storyEvent,
                  },
                )
                .toList(growable: false),
          }),
        ),
        sourceKey: storyline.chapterUUID,
      );
      outlineCount++;
      for (final event in storyline.scenes) {
        if (outlineCount >= ProjectReadBudget.maxOutlineItems) break;
        addResource(
          ProjectReadSelectableResource(
            resourceType: ProjectReadResourceType.outlineEvent,
            resourceId: event.storyEventUUID,
            title: event.storyEvent.trim().isEmpty
                ? "未命名事件"
                : event.storyEvent.trim(),
            description: "大綱事件・${storyline.storylineName}",
            content: jsonEncode(<String, Object?>{
              "kind": "event",
              "id": event.storyEventUUID,
              "name": event.storyEvent,
              "storylineId": storyline.chapterUUID,
              "storylineName": storyline.storylineName,
              "memo": event.memo,
              "conflictPoint": event.conflictPoint,
              "people": event.people,
              "items": event.item,
              "scenes": event.scenes
                  .map(
                    (scene) => <String, Object?>{
                      "id": scene.sceneUUID,
                      "name": scene.sceneName,
                      "time": scene.time,
                      "location": scene.location,
                      "focusPoint": scene.focusPoint,
                      "conflictPoint": scene.conflictPoint,
                      "people": scene.people,
                      "items": scene.item,
                      "actions": scene.doingThings,
                      "memo": scene.memo,
                    },
                  )
                  .toList(growable: false),
            }),
          ),
          sourceKey: event.storyEventUUID,
        );
        outlineCount++;
      }
    }

    for (final glossaryEntry in glossaryEntries.entries.take(
      ProjectReadBudget.maxGlossaryItems,
    )) {
      final entry = glossaryEntry.value;
      final resourceId = entry.id.trim().isEmpty
          ? glossaryEntry.key.trim()
          : entry.id.trim();
      addResource(
        ProjectReadSelectableResource(
          resourceType: ProjectReadResourceType.glossaryTerm,
          resourceId: resourceId,
          title: entry.term.trim().isEmpty ? "未命名詞條" : entry.term.trim(),
          description: "詞語・${entry.partOfSpeech.label}",
          content: jsonEncode(<String, Object?>{
            ...entry.toJson(),
            "id": resourceId,
          }),
        ),
        sourceKey: glossaryEntry.key,
      );
    }

    const typeOrder = <String, int>{
      ProjectReadResourceType.character: 0,
      ProjectReadResourceType.worldSetting: 1,
      ProjectReadResourceType.outlineEvent: 2,
      ProjectReadResourceType.glossaryTerm: 3,
    };
    resources.sort((left, right) {
      final typeComparison = (typeOrder[left.resourceType] ?? 99).compareTo(
        typeOrder[right.resourceType] ?? 99,
      );
      if (typeComparison != 0) return typeComparison;
      final titleComparison = left.title.toLowerCase().compareTo(
        right.title.toLowerCase(),
      );
      if (titleComparison != 0) return titleComparison;
      return left.resourceId.compareTo(right.resourceId);
    });
    return (
      resources: List<ProjectReadSelectableResource>.unmodifiable(resources),
      omissions: List<ProjectReadOmission>.unmodifiable(omissions),
    );
  }
}
