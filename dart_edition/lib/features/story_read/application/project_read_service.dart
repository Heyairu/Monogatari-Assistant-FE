import "dart:convert";
import "dart:math" as math;

import "../domain/project_read_models.dart";

final class ProjectReadService {
  const ProjectReadService._();

  static ProjectReadPage<ProjectReadChapterSummary> listChapters(
    ProjectReadSnapshot snapshot, {
    int offset = 0,
    int limit = ProjectReadBudget.defaultPageSize,
  }) {
    _validatePage(offset: offset, limit: limit);
    final end = math.min(offset + limit, snapshot.chapters.length);
    final items = offset >= snapshot.chapters.length
        ? const <ProjectReadChapterSummary>[]
        : snapshot.chapters
              .sublist(offset, end)
              .map(
                (chapter) => ProjectReadChapterSummary(
                  chapterId: chapter.chapterId,
                  folderId: chapter.folderId,
                  title: chapter.title,
                  order: chapter.order,
                ),
              )
              .toList(growable: false);
    return ProjectReadPage<ProjectReadChapterSummary>(
      items: items,
      total: snapshot.chapters.length,
      offset: offset,
      nextOffset: end < snapshot.chapters.length ? end : null,
    );
  }

  static ProjectReadResource? getChapter(
    ProjectReadSnapshot snapshot, {
    required String chapterId,
    int maxBytes = ProjectReadBudget.maxChapterBytes,
  }) {
    if (maxBytes < 1 || maxBytes > ProjectReadBudget.maxChapterBytes) {
      throw RangeError.range(
        maxBytes,
        1,
        ProjectReadBudget.maxChapterBytes,
        "maxBytes",
      );
    }
    return snapshot.chapterById(chapterId)?.toResource(maxBytes: maxBytes);
  }

  static ProjectReadPage<ProjectReadEntitySummary> searchEntities(
    ProjectReadSnapshot snapshot, {
    required String query,
    Set<String> resourceTypes = const <String>{},
    int offset = 0,
    int limit = ProjectReadBudget.defaultPageSize,
  }) {
    _validatePage(offset: offset, limit: limit);
    if (resourceTypes.any(
      (type) =>
          !ProjectReadResourceType.v1.contains(type) ||
          type == ProjectReadResourceType.project ||
          type == ProjectReadResourceType.chapter,
    )) {
      throw const FormatException("搜尋包含不支援的 resource type。");
    }
    final normalizedQuery = query.trim().toLowerCase();
    final matches = snapshot.entities
        .where((entity) {
          if (resourceTypes.isNotEmpty &&
              !resourceTypes.contains(entity.resourceType)) {
            return false;
          }
          if (normalizedQuery.isEmpty) return true;
          return entity.title.toLowerCase().contains(normalizedQuery) ||
              entity.description.toLowerCase().contains(normalizedQuery) ||
              entity.resourceId.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);
    final end = math.min(offset + limit, matches.length);
    final items = offset >= matches.length
        ? const <ProjectReadEntitySummary>[]
        : matches
              .sublist(offset, end)
              .map(
                (entity) => ProjectReadEntitySummary(
                  resourceType: entity.resourceType,
                  resourceId: entity.resourceId,
                  title: entity.title,
                  description: entity.description,
                ),
              )
              .toList(growable: false);
    return ProjectReadPage<ProjectReadEntitySummary>(
      items: items,
      total: matches.length,
      offset: offset,
      nextOffset: end < matches.length ? end : null,
    );
  }

  static ProjectReadResource? getEntity(
    ProjectReadSnapshot snapshot, {
    required ProjectReadResourceRef ref,
    int maxBytes = ProjectReadBudget.maxSelectedResourceBytes,
  }) {
    if (maxBytes < 1 || maxBytes > ProjectReadBudget.maxSelectedResourceBytes) {
      throw RangeError.range(
        maxBytes,
        1,
        ProjectReadBudget.maxSelectedResourceBytes,
        "maxBytes",
      );
    }
    return snapshot.entityByRef(ref)?.toResource(maxBytes: maxBytes);
  }

  static List<ProjectReadResource> buildSelectedResources(
    ProjectReadSnapshot snapshot, {
    required Iterable<ProjectReadResourceRef> resourceRefs,
    bool rejectMissing = false,
  }) {
    final refs = resourceRefs.toList(growable: false);
    if (refs.length > ProjectReadBudget.maxSelectedResources) {
      throw const FormatException("Ask 最多可選擇 12 個補充資源。");
    }
    final requestedKeys = refs.map((ref) => ref.selectionKey).toSet();
    if (rejectMissing) {
      for (final ref in refs) {
        if (snapshot.entityByRef(ref) == null) {
          throw FormatException("找不到指定資源：${ref.selectionKey}");
        }
      }
    }
    final result = <ProjectReadResource>[];
    var usedBytes = 0;
    for (final entity in snapshot.entities) {
      if (!requestedKeys.contains(entity.selectionKey)) continue;
      final remaining = ProjectReadBudget.maxSelectedResourcesBytes - usedBytes;
      if (remaining <= 0) break;
      final resource = entity.toResource(
        maxBytes: math.min(
          ProjectReadBudget.maxSelectedResourceBytes,
          remaining,
        ),
      );
      result.add(resource);
      usedBytes += utf8.encode(resource.content).length;
    }
    return List<ProjectReadResource>.unmodifiable(result);
  }

  static ProjectReadContextBundle buildContextBundle(
    ProjectReadSnapshot snapshot, {
    required String chapterId,
    bool includeProjectOverview = false,
    Iterable<ProjectReadResourceRef> resourceRefs =
        const <ProjectReadResourceRef>[],
    bool rejectMissing = false,
  }) {
    final refs = resourceRefs.toList(growable: false);
    if (includeProjectOverview && refs.isNotEmpty) {
      throw const FormatException("專案摘要與選取資源是互斥的 context scope。");
    }
    final chapter = getChapter(snapshot, chapterId: chapterId);
    if (chapter == null) {
      throw const FormatException("找不到指定章節。");
    }
    final supplemental = includeProjectOverview
        ? <ProjectReadResource>[snapshot.overview]
        : buildSelectedResources(
            snapshot,
            resourceRefs: refs,
            rejectMissing: rejectMissing,
          );
    return ProjectReadContextBundle(
      primary: chapter,
      supplementalResources: supplemental,
    );
  }

  static void _validatePage({required int offset, required int limit}) {
    if (offset < 0) {
      throw RangeError.value(offset, "offset", "must not be negative");
    }
    if (limit < 1 || limit > ProjectReadBudget.maxPageSize) {
      throw RangeError.range(limit, 1, ProjectReadBudget.maxPageSize, "limit");
    }
  }
}
