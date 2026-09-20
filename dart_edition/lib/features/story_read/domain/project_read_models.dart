import "dart:convert";

abstract final class ProjectReadResourceType {
  static const String project = "project";
  static const String chapter = "chapter";
  static const String character = "character";
  static const String worldSetting = "worldSetting";
  static const String outlineEvent = "outlineEvent";
  static const String glossaryTerm = "glossaryTerm";

  static const Set<String> v1 = <String>{
    project,
    chapter,
    character,
    worldSetting,
    outlineEvent,
    glossaryTerm,
  };
}

final class ProjectReadBudget {
  static const int maxChapterBytes = 72 * 1024;
  static const int maxOverviewBytes = 24 * 1024;
  static const int maxChapterIndexItems = 300;
  static const int maxCharacterItems = 200;
  static const int maxOutlineItems = 200;
  static const int maxWorldItems = 200;
  static const int maxGlossaryItems = 200;
  static const int maxSelectedResources = 12;
  static const int maxSelectedResourceBytes = 8 * 1024;
  static const int maxSelectedResourcesBytes = 32 * 1024;
  static const int defaultPageSize = 50;
  static const int maxPageSize = 100;
  static const int maxToolResultBytes = 256 * 1024;

  const ProjectReadBudget._();
}

final class ProjectReadResourceRef {
  final String resourceType;
  final String resourceId;

  const ProjectReadResourceRef({
    required this.resourceType,
    required this.resourceId,
  });

  String get selectionKey => "$resourceType:$resourceId";
}

final class ProjectReadResource {
  final String resourceType;
  final String resourceId;
  final String title;
  final String content;
  final bool truncated;
  final String fingerprint;

  ProjectReadResource({
    required this.resourceType,
    required this.resourceId,
    required this.title,
    required this.content,
    required this.truncated,
    String? fingerprint,
  }) : fingerprint =
           fingerprint ??
           projectReadFingerprint(
             utf8.encode(
               jsonEncode(<String, Object?>{
                 "type": resourceType,
                 "id": resourceId,
                 "title": title,
                 "truncated": truncated,
                 "content": content,
               }),
             ),
           );

  factory ProjectReadResource.bounded({
    required String resourceType,
    required String resourceId,
    required String title,
    required String content,
    required int maxBytes,
  }) {
    final bounded = truncateProjectReadUtf8(content, maxBytes);
    return ProjectReadResource(
      resourceType: resourceType,
      resourceId: resourceId,
      title: title,
      content: bounded.value,
      truncated: bounded.truncated,
    );
  }

  ProjectReadResource bounded(int maxBytes) {
    return ProjectReadResource.bounded(
      resourceType: resourceType,
      resourceId: resourceId,
      title: title,
      content: content,
      maxBytes: maxBytes,
    );
  }

  Map<String, Object?> toContextJson() => <String, Object?>{
    "type": resourceType,
    "id": resourceId,
    "title": title,
    "truncated": truncated,
    "content": content,
  };
}

final class ProjectReadChapter {
  final String chapterId;
  final String folderId;
  final String title;
  final String content;
  final int order;

  const ProjectReadChapter({
    required this.chapterId,
    required this.folderId,
    required this.title,
    required this.content,
    required this.order,
  });

  ProjectReadResource toResource({
    int maxBytes = ProjectReadBudget.maxChapterBytes,
  }) {
    return ProjectReadResource.bounded(
      resourceType: ProjectReadResourceType.chapter,
      resourceId: chapterId,
      title: title,
      content: content,
      maxBytes: maxBytes,
    );
  }
}

final class ProjectReadChapterSummary {
  final String chapterId;
  final String folderId;
  final String title;
  final int order;

  const ProjectReadChapterSummary({
    required this.chapterId,
    required this.folderId,
    required this.title,
    required this.order,
  });
}

final class ProjectReadEntitySummary {
  final String resourceType;
  final String resourceId;
  final String title;
  final String description;

  const ProjectReadEntitySummary({
    required this.resourceType,
    required this.resourceId,
    required this.title,
    required this.description,
  });
}

final class ProjectReadPage<T> {
  final List<T> items;
  final int total;
  final int offset;
  final int? nextOffset;

  ProjectReadPage({
    required List<T> items,
    required this.total,
    required this.offset,
    required this.nextOffset,
  }) : items = List<T>.unmodifiable(items);
}

final class ProjectReadSelectableResource {
  final String resourceType;
  final String resourceId;
  final String title;
  final String description;
  final String content;

  const ProjectReadSelectableResource({
    required this.resourceType,
    required this.resourceId,
    required this.title,
    required this.description,
    required this.content,
  });

  String get selectionKey => "$resourceType:$resourceId";

  ProjectReadResource toResource({required int maxBytes}) {
    return ProjectReadResource.bounded(
      resourceType: resourceType,
      resourceId: resourceId,
      title: title,
      content: content,
      maxBytes: maxBytes,
    );
  }
}

final class ProjectReadOmission {
  final String resourceType;
  final String sourceKey;
  final String reason;

  const ProjectReadOmission({
    required this.resourceType,
    required this.sourceKey,
    required this.reason,
  });
}

final class ProjectReadSnapshot {
  final String projectId;
  final ProjectReadResource overview;
  final List<ProjectReadChapter> chapters;
  final List<ProjectReadSelectableResource> entities;
  final List<ProjectReadOmission> omissions;

  ProjectReadSnapshot({
    required this.projectId,
    required this.overview,
    required List<ProjectReadChapter> chapters,
    required List<ProjectReadSelectableResource> entities,
    List<ProjectReadOmission> omissions = const <ProjectReadOmission>[],
  }) : chapters = List<ProjectReadChapter>.unmodifiable(chapters),
       entities = List<ProjectReadSelectableResource>.unmodifiable(entities),
       omissions = List<ProjectReadOmission>.unmodifiable(omissions);

  ProjectReadChapter? chapterById(String chapterId) {
    for (final chapter in chapters) {
      if (chapter.chapterId == chapterId) return chapter;
    }
    return null;
  }

  ProjectReadSelectableResource? entityByRef(ProjectReadResourceRef ref) {
    for (final entity in entities) {
      if (entity.resourceType == ref.resourceType &&
          entity.resourceId == ref.resourceId) {
        return entity;
      }
    }
    return null;
  }
}

final class ProjectReadContextBundle {
  final ProjectReadResource primary;
  final List<ProjectReadResource> supplementalResources;
  final String fingerprint;

  ProjectReadContextBundle({
    required this.primary,
    required List<ProjectReadResource> supplementalResources,
    String? fingerprint,
  }) : supplementalResources = List<ProjectReadResource>.unmodifiable(
         supplementalResources,
       ),
       fingerprint =
           fingerprint ??
           projectReadFingerprint(
             utf8.encode(
               jsonEncode(<String, Object?>{
                 "primary": <String, Object?>{
                   "type": primary.resourceType,
                   "id": primary.resourceId,
                   "title": primary.title,
                   "content": primary.content,
                 },
                 "supplemental": supplementalResources
                     .map((resource) => resource.toContextJson())
                     .toList(growable: false),
               }),
             ),
           );

  ProjectReadResource? resourceById(String id) {
    if (primary.resourceId == id) return primary;
    for (final resource in supplementalResources) {
      if (resource.resourceId == id) return resource;
    }
    return null;
  }
}

({String value, bool truncated}) truncateProjectReadUtf8(
  String source,
  int maxBytes,
) {
  if (maxBytes < 0) {
    throw ArgumentError.value(maxBytes, "maxBytes", "must not be negative");
  }
  if (utf8.encode(source).length <= maxBytes) {
    return (value: source, truncated: false);
  }
  var low = 0;
  var high = source.length;
  while (low < high) {
    final middle = (low + high + 1) ~/ 2;
    if (utf8.encode(source.substring(0, middle)).length <= maxBytes) {
      low = middle;
    } else {
      high = middle - 1;
    }
  }
  var end = low;
  if (end > 0 && end < source.length) {
    final previous = source.codeUnitAt(end - 1);
    if (previous >= 0xD800 && previous <= 0xDBFF) end -= 1;
  }
  return (value: source.substring(0, end), truncated: true);
}

String projectReadFingerprint(List<int> bytes) {
  var hash = 0x811c9dc5;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, "0");
}
