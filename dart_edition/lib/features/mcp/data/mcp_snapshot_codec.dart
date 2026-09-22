import "../../story_read/domain/project_read_models.dart";

abstract final class McpSnapshotCodec {
  static Map<String, Object?> encode(ProjectReadSnapshot snapshot) =>
      <String, Object?>{
        "projectId": snapshot.projectId,
        "overview": _encodeResource(snapshot.overview),
        "chapters": snapshot.chapters
            .map(
              (chapter) => <String, Object?>{
                "chapterId": chapter.chapterId,
                "folderId": chapter.folderId,
                "title": chapter.title,
                "content": chapter.content,
                "order": chapter.order,
              },
            )
            .toList(growable: false),
        "entities": snapshot.entities
            .map(
              (entity) => <String, Object?>{
                "resourceType": entity.resourceType,
                "resourceId": entity.resourceId,
                "title": entity.title,
                "description": entity.description,
                "content": entity.content,
              },
            )
            .toList(growable: false),
        "omissions": snapshot.omissions
            .map(
              (omission) => <String, Object?>{
                "resourceType": omission.resourceType,
                "sourceKey": omission.sourceKey,
                "reason": omission.reason,
              },
            )
            .toList(growable: false),
      };

  static ProjectReadSnapshot decode(Map<String, Object?> json) {
    final overview = _map(json["overview"]);
    return ProjectReadSnapshot(
      projectId: _string(json, "projectId"),
      overview: ProjectReadResource(
        resourceType: _string(overview, "resourceType"),
        resourceId: _string(overview, "resourceId"),
        title: _string(overview, "title"),
        content: _string(overview, "content"),
        truncated: _bool(overview, "truncated"),
        fingerprint: _string(overview, "fingerprint"),
      ),
      chapters: _list(json["chapters"])
          .map((value) {
            final item = _map(value);
            return ProjectReadChapter(
              chapterId: _string(item, "chapterId"),
              folderId: _string(item, "folderId"),
              title: _string(item, "title"),
              content: _string(item, "content"),
              order: _int(item, "order"),
            );
          })
          .toList(growable: false),
      entities: _list(json["entities"])
          .map((value) {
            final item = _map(value);
            return ProjectReadSelectableResource(
              resourceType: _string(item, "resourceType"),
              resourceId: _string(item, "resourceId"),
              title: _string(item, "title"),
              description: _string(item, "description"),
              content: _string(item, "content"),
            );
          })
          .toList(growable: false),
      omissions: _list(json["omissions"])
          .map((value) {
            final item = _map(value);
            return ProjectReadOmission(
              resourceType: _string(item, "resourceType"),
              sourceKey: _string(item, "sourceKey"),
              reason: _string(item, "reason"),
            );
          })
          .toList(growable: false),
    );
  }

  static Map<String, Object?> _encodeResource(ProjectReadResource resource) =>
      <String, Object?>{
        "resourceType": resource.resourceType,
        "resourceId": resource.resourceId,
        "title": resource.title,
        "content": resource.content,
        "truncated": resource.truncated,
        "fingerprint": resource.fingerprint,
      };

  static Map<String, Object?> _map(Object? value) {
    if (value is! Map) {
      throw const FormatException("Invalid bridge payload.");
    }
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static List<Object?> _list(Object? value) {
    if (value is! List) {
      throw const FormatException("Invalid bridge payload.");
    }
    return List<Object?>.from(value);
  }

  static String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String) {
      throw const FormatException("Invalid bridge payload.");
    }
    return value;
  }

  static bool _bool(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! bool) {
      throw const FormatException("Invalid bridge payload.");
    }
    return value;
  }

  static int _int(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! int) {
      throw const FormatException("Invalid bridge payload.");
    }
    return value;
  }
}
