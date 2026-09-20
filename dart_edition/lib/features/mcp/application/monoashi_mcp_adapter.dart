import "dart:convert";

import "../../story_read/application/project_read_service.dart";
import "../../story_read/domain/project_read_models.dart";
import "../domain/mcp_gateway.dart";
import "../domain/mcp_protocol_models.dart";
import "mcp_cursor_codec.dart";

typedef MonoAshiMcpCancellationCheck = bool Function();

final class MonoAshiMcpAdapter {
  final MonoAshiMcpGateway gateway;
  final MonoAshiMcpCursorCodec cursorCodec;

  MonoAshiMcpAdapter({
    required this.gateway,
    MonoAshiMcpCursorCodec? cursorCodec,
  }) : cursorCodec = cursorCodec ?? MonoAshiMcpCursorCodec.random();

  Future<Map<String, dynamic>> callTool(
    String name,
    Map<String, dynamic> arguments, {
    MonoAshiMcpCancellationCheck? isCancelled,
  }) async {
    _throwIfCancelled(isCancelled);
    final session = await _requireSession();
    _throwIfCancelled(isCancelled);
    final result = switch (name) {
      MonoAshiMcpContract.getProjectSummary => _getProjectSummary(
        session,
        arguments,
      ),
      MonoAshiMcpContract.listChapters => _listChapters(session, arguments),
      MonoAshiMcpContract.getChapter => _getChapter(session, arguments),
      MonoAshiMcpContract.searchProjectEntities => _searchEntities(
        session,
        arguments,
      ),
      MonoAshiMcpContract.getProjectEntity => _getEntity(session, arguments),
      MonoAshiMcpContract.getContextBundle => _getContextBundle(
        session,
        arguments,
      ),
      _ => throw const MonoAshiMcpException(
        MonoAshiMcpErrorCode.invalidArgument,
        "不支援的 MCP tool。",
      ),
    };
    final resolved = await result;
    _throwIfCancelled(isCancelled);
    return _boundedResult(resolved);
  }

  Future<List<MonoAshiMcpResourceDescriptor>> listResources() async {
    final session = await _requireSession();
    final snapshot = session.snapshot;
    return List<MonoAshiMcpResourceDescriptor>.unmodifiable(<
      MonoAshiMcpResourceDescriptor
    >[
      MonoAshiMcpResourceDescriptor(
        uri: _resourceUri(session, ProjectReadResourceType.project, "summary"),
        name: "project-summary",
        title: snapshot.overview.title,
        description: "目前授權 MonoAshi 專案的受限摘要，不含其他章節正文。",
      ),
      for (final chapter in snapshot.chapters)
        MonoAshiMcpResourceDescriptor(
          uri: _resourceUri(
            session,
            ProjectReadResourceType.chapter,
            chapter.chapterId,
          ),
          name: "chapter-${chapter.chapterId}",
          title: chapter.title,
          description: "受 UTF-8 byte budget 限制的章節正文。",
        ),
      for (final entity in snapshot.entities)
        MonoAshiMcpResourceDescriptor(
          uri: _resourceUri(session, entity.resourceType, entity.resourceId),
          name: "${entity.resourceType}-${entity.resourceId}",
          title: entity.title,
          description: entity.description,
        ),
    ]);
  }

  Future<Map<String, dynamic>> readResource(
    Uri uri, {
    MonoAshiMcpCancellationCheck? isCancelled,
  }) async {
    _throwIfCancelled(isCancelled);
    final session = await _requireSession();
    if (uri.scheme != "monoashi" || uri.host != "session") {
      throw const MonoAshiMcpException(
        MonoAshiMcpErrorCode.notFound,
        "找不到指定 resource。",
      );
    }
    final segments = uri.pathSegments;
    if (segments.length != 3 || segments[0] != session.sessionId) {
      throw const MonoAshiMcpException(
        MonoAshiMcpErrorCode.notFound,
        "Resource 不屬於目前授權 session。",
      );
    }
    final type = segments[1];
    final id = segments[2];
    late final ProjectReadResource resource;
    if (type == ProjectReadResourceType.project && id == "summary") {
      resource = session.snapshot.overview;
    } else if (type == ProjectReadResourceType.chapter) {
      resource =
          ProjectReadService.getChapter(session.snapshot, chapterId: id) ??
          (throw const MonoAshiMcpException(
            MonoAshiMcpErrorCode.notFound,
            "找不到指定章節。",
          ));
    } else {
      _validateEntityType(type);
      resource =
          ProjectReadService.getEntity(
            session.snapshot,
            ref: ProjectReadResourceRef(resourceType: type, resourceId: id),
          ) ??
          (throw const MonoAshiMcpException(
            MonoAshiMcpErrorCode.notFound,
            "找不到指定作品資源。",
          ));
    }
    _throwIfCancelled(isCancelled);
    return _boundedResult(<String, dynamic>{
      ..._envelope(session),
      "resource": _resourceJson(
        session,
        resource,
        externalId: type == ProjectReadResourceType.project
            ? session.projectId
            : null,
        sourceId: id,
      ),
    });
  }

  Future<Map<String, dynamic>> _getProjectSummary(
    MonoAshiMcpSession session,
    Map<String, dynamic> arguments,
  ) async {
    _expectKeys(arguments, const <String>{});
    final snapshot = session.snapshot;
    final counts = <String, int>{
      ProjectReadResourceType.chapter: snapshot.chapters.length,
      for (final type in ProjectReadResourceType.v1.where(
        (type) =>
            type != ProjectReadResourceType.project &&
            type != ProjectReadResourceType.chapter,
      ))
        type: snapshot.entities
            .where((entity) => entity.resourceType == type)
            .length,
    };
    return <String, dynamic>{
      ..._envelope(session),
      "resource": _resourceJson(
        session,
        snapshot.overview,
        externalId: session.projectId,
        sourceId: "summary",
      ),
      "counts": counts,
      "omitted": <Map<String, dynamic>>[
        for (final omission in snapshot.omissions)
          <String, dynamic>{
            "type": omission.resourceType,
            "sourceKey": omission.sourceKey,
            "reason": omission.reason,
          },
      ],
    };
  }

  Future<Map<String, dynamic>> _listChapters(
    MonoAshiMcpSession session,
    Map<String, dynamic> arguments,
  ) async {
    _expectKeys(arguments, const <String>{"cursor", "limit"});
    final limit = _pageLimit(arguments["limit"]);
    final scope = "${session.sessionId}:${session.generation}:chapters";
    final offset = await _offset(arguments["cursor"], "chapters", scope);
    final page = ProjectReadService.listChapters(
      session.snapshot,
      offset: offset,
      limit: limit,
    );
    return <String, dynamic>{
      ..._envelope(session),
      "items": <Map<String, dynamic>>[
        for (final chapter in page.items)
          <String, dynamic>{
            "schemaVersion": MonoAshiMcpContract.schemaVersion,
            "type": ProjectReadResourceType.chapter,
            "id": chapter.chapterId,
            "title": chapter.title,
            "order": chapter.order,
            "truncated": false,
            "fingerprint": _metadataFingerprint(<String, Object?>{
              "id": chapter.chapterId,
              "title": chapter.title,
              "order": chapter.order,
            }),
            "sourceUri": _resourceUri(
              session,
              ProjectReadResourceType.chapter,
              chapter.chapterId,
            ),
          },
      ],
      "total": page.total,
      "nextCursor": page.nextOffset == null
          ? null
          : await cursorCodec.encode(
              kind: "chapters",
              offset: page.nextOffset!,
              scope: scope,
            ),
      "omitted": const <Object?>[],
    };
  }

  Future<Map<String, dynamic>> _getChapter(
    MonoAshiMcpSession session,
    Map<String, dynamic> arguments,
  ) async {
    _expectKeys(arguments, const <String>{"chapterId", "maxBytes"});
    final chapterId = _requiredString(arguments, "chapterId");
    final maxBytes = _maxBytes(
      arguments["maxBytes"],
      ProjectReadBudget.maxChapterBytes,
    );
    final resource = ProjectReadService.getChapter(
      session.snapshot,
      chapterId: chapterId,
      maxBytes: maxBytes,
    );
    if (resource == null) {
      throw const MonoAshiMcpException(
        MonoAshiMcpErrorCode.notFound,
        "找不到指定章節。",
      );
    }
    return <String, dynamic>{
      ..._envelope(session),
      "resource": _resourceJson(session, resource),
    };
  }

  Future<Map<String, dynamic>> _searchEntities(
    MonoAshiMcpSession session,
    Map<String, dynamic> arguments,
  ) async {
    _expectKeys(arguments, const <String>{"query", "types", "cursor", "limit"});
    final query = _optionalString(arguments["query"], "query", maxLength: 512);
    final types = _entityTypes(arguments["types"]);
    final limit = _pageLimit(arguments["limit"]);
    final sortedTypes = types.toList(growable: false)..sort();
    final scope = _metadataFingerprint(<String, Object?>{
      "session": session.sessionId,
      "generation": session.generation,
      "query": query,
      "types": sortedTypes,
    });
    final offset = await _offset(arguments["cursor"], "entities", scope);
    final page = ProjectReadService.searchEntities(
      session.snapshot,
      query: query,
      resourceTypes: types,
      offset: offset,
      limit: limit,
    );
    return <String, dynamic>{
      ..._envelope(session),
      "items": <Map<String, dynamic>>[
        for (final entity in page.items)
          <String, dynamic>{
            "schemaVersion": MonoAshiMcpContract.schemaVersion,
            "type": entity.resourceType,
            "id": entity.resourceId,
            "title": entity.title,
            "description": entity.description,
            "truncated": false,
            "fingerprint": _metadataFingerprint(<String, Object?>{
              "type": entity.resourceType,
              "id": entity.resourceId,
              "title": entity.title,
              "description": entity.description,
            }),
            "sourceUri": _resourceUri(
              session,
              entity.resourceType,
              entity.resourceId,
            ),
          },
      ],
      "total": page.total,
      "nextCursor": page.nextOffset == null
          ? null
          : await cursorCodec.encode(
              kind: "entities",
              offset: page.nextOffset!,
              scope: scope,
            ),
      "omitted": const <Object?>[],
    };
  }

  Future<Map<String, dynamic>> _getEntity(
    MonoAshiMcpSession session,
    Map<String, dynamic> arguments,
  ) async {
    _expectKeys(arguments, const <String>{"type", "id", "maxBytes"});
    final type = _requiredString(arguments, "type");
    _validateEntityType(type);
    final id = _requiredString(arguments, "id");
    final maxBytes = _maxBytes(
      arguments["maxBytes"],
      ProjectReadBudget.maxSelectedResourceBytes,
    );
    final resource = ProjectReadService.getEntity(
      session.snapshot,
      ref: ProjectReadResourceRef(resourceType: type, resourceId: id),
      maxBytes: maxBytes,
    );
    if (resource == null) {
      throw const MonoAshiMcpException(
        MonoAshiMcpErrorCode.notFound,
        "找不到指定作品資源。",
      );
    }
    return <String, dynamic>{
      ..._envelope(session),
      "resource": _resourceJson(session, resource),
    };
  }

  Future<Map<String, dynamic>> _getContextBundle(
    MonoAshiMcpSession session,
    Map<String, dynamic> arguments,
  ) async {
    _expectKeys(arguments, const <String>{
      "chapterId",
      "includeProjectOverview",
      "resourceRefs",
    });
    final chapterId = _requiredString(arguments, "chapterId");
    final includeOverview = arguments["includeProjectOverview"] ?? false;
    if (includeOverview is! bool) {
      throw const MonoAshiMcpException(
        MonoAshiMcpErrorCode.invalidArgument,
        "includeProjectOverview 必須是 boolean。",
      );
    }
    final rawRefs = arguments["resourceRefs"] ?? const <Object?>[];
    if (rawRefs is! List) {
      throw const MonoAshiMcpException(
        MonoAshiMcpErrorCode.invalidArgument,
        "resourceRefs 必須是 array。",
      );
    }
    if (rawRefs.length > ProjectReadBudget.maxSelectedResources) {
      throw const MonoAshiMcpException(
        MonoAshiMcpErrorCode.invalidArgument,
        "resourceRefs 最多可包含 12 筆。",
      );
    }
    final refs = <ProjectReadResourceRef>[];
    for (final rawRef in rawRefs) {
      if (rawRef is! Map) {
        throw const MonoAshiMcpException(
          MonoAshiMcpErrorCode.invalidArgument,
          "resourceRefs 項目必須是 object。",
        );
      }
      final ref = Map<String, dynamic>.from(rawRef);
      _expectKeys(ref, const <String>{"type", "id"});
      final type = _requiredString(ref, "type");
      _validateEntityType(type);
      refs.add(
        ProjectReadResourceRef(
          resourceType: type,
          resourceId: _requiredString(ref, "id"),
        ),
      );
    }
    try {
      final bundle = ProjectReadService.buildContextBundle(
        session.snapshot,
        chapterId: chapterId,
        includeProjectOverview: includeOverview,
        resourceRefs: refs,
        rejectMissing: true,
      );
      return <String, dynamic>{
        ..._envelope(session),
        "primary": _resourceJson(session, bundle.primary),
        "supplemental": <Map<String, dynamic>>[
          for (final resource in bundle.supplementalResources)
            _resourceJson(
              session,
              resource,
              externalId:
                  resource.resourceType == ProjectReadResourceType.project
                  ? session.projectId
                  : null,
              sourceId: resource.resourceType == ProjectReadResourceType.project
                  ? "summary"
                  : null,
            ),
        ],
        "fingerprint": bundle.fingerprint,
        "omitted": const <Object?>[],
      };
    } on FormatException catch (error) {
      throw MonoAshiMcpException(
        MonoAshiMcpErrorCode.invalidArgument,
        error.message,
      );
    }
  }

  Future<MonoAshiMcpSession> _requireSession() async {
    final session = await gateway.currentSession();
    if (session == null) {
      throw const MonoAshiMcpException(
        MonoAshiMcpErrorCode.unavailable,
        "MonoAshi 尚未提供已授權的作品 session。",
      );
    }
    return session;
  }

  Map<String, dynamic> _envelope(MonoAshiMcpSession session) =>
      <String, dynamic>{
        "schemaVersion": MonoAshiMcpContract.schemaVersion,
        "sessionId": session.sessionId,
        "projectId": session.projectId,
        "snapshotGeneration": session.generation,
      };

  Map<String, dynamic> _resourceJson(
    MonoAshiMcpSession session,
    ProjectReadResource resource, {
    String? externalId,
    String? sourceId,
  }) => <String, dynamic>{
    "schemaVersion": MonoAshiMcpContract.schemaVersion,
    "type": resource.resourceType,
    "id": externalId ?? resource.resourceId,
    "title": resource.title,
    "truncated": resource.truncated,
    "fingerprint": resource.fingerprint,
    "sourceUri": _resourceUri(
      session,
      resource.resourceType,
      sourceId ?? resource.resourceId,
    ),
    "content": resource.content,
  };

  String _resourceUri(MonoAshiMcpSession session, String type, String id) =>
      Uri(
        scheme: "monoashi",
        host: "session",
        pathSegments: <String>[session.sessionId, type, id],
      ).toString();

  String _metadataFingerprint(Map<String, Object?> value) =>
      projectReadFingerprint(utf8.encode(jsonEncode(value)));

  Future<int> _offset(Object? cursor, String kind, String scope) async {
    if (cursor == null) return 0;
    if (cursor is! String || cursor.isEmpty || cursor.length > 2048) {
      throw const MonoAshiMcpException(
        MonoAshiMcpErrorCode.invalidCursor,
        "Cursor 格式無效。",
      );
    }
    return (await cursorCodec.decode(
      cursor,
      expectedKind: kind,
      expectedScope: scope,
    )).offset;
  }

  int _pageLimit(Object? value) {
    if (value == null) return ProjectReadBudget.defaultPageSize;
    if (value is! int || value < 1 || value > ProjectReadBudget.maxPageSize) {
      throw const MonoAshiMcpException(
        MonoAshiMcpErrorCode.invalidArgument,
        "limit 必須介於 1 到 100。",
      );
    }
    return value;
  }

  int _maxBytes(Object? value, int maximum) {
    if (value == null) return maximum;
    if (value is! int || value < 1 || value > maximum) {
      throw MonoAshiMcpException(
        MonoAshiMcpErrorCode.invalidArgument,
        "maxBytes 必須介於 1 到 $maximum。",
      );
    }
    return value;
  }

  String _requiredString(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is! String || value.trim().isEmpty || value.length > 256) {
      throw MonoAshiMcpException(
        MonoAshiMcpErrorCode.invalidArgument,
        "$key 必須是 1 到 256 字元的字串。",
      );
    }
    return value;
  }

  String _optionalString(Object? value, String key, {required int maxLength}) {
    if (value == null) return "";
    if (value is! String || value.length > maxLength) {
      throw MonoAshiMcpException(
        MonoAshiMcpErrorCode.invalidArgument,
        "$key 必須是最多 $maxLength 字元的字串。",
      );
    }
    return value;
  }

  Set<String> _entityTypes(Object? value) {
    if (value == null) return const <String>{};
    if (value is! List) {
      throw const MonoAshiMcpException(
        MonoAshiMcpErrorCode.invalidArgument,
        "types 必須是 array。",
      );
    }
    final result = <String>{};
    for (final type in value) {
      if (type is! String) {
        throw const MonoAshiMcpException(
          MonoAshiMcpErrorCode.invalidArgument,
          "types 只能包含字串。",
        );
      }
      _validateEntityType(type);
      result.add(type);
    }
    return result;
  }

  void _validateEntityType(String type) {
    if (!ProjectReadResourceType.v1.contains(type) ||
        type == ProjectReadResourceType.project ||
        type == ProjectReadResourceType.chapter) {
      throw const MonoAshiMcpException(
        MonoAshiMcpErrorCode.invalidArgument,
        "不支援的作品資源類型。",
      );
    }
  }

  void _expectKeys(Map<String, dynamic> source, Set<String> allowed) {
    final unexpected = source.keys.where((key) => !allowed.contains(key));
    if (unexpected.isNotEmpty) {
      throw MonoAshiMcpException(
        MonoAshiMcpErrorCode.invalidArgument,
        "輸入包含未預期欄位：${unexpected.first}",
      );
    }
  }

  void _throwIfCancelled(MonoAshiMcpCancellationCheck? isCancelled) {
    if (isCancelled?.call() ?? false) {
      throw const MonoAshiMcpException(
        MonoAshiMcpErrorCode.cancelled,
        "MCP request 已取消。",
      );
    }
  }

  Map<String, dynamic> _boundedResult(Map<String, dynamic> result) {
    if (utf8.encode(jsonEncode(result)).length >
        ProjectReadBudget.maxToolResultBytes) {
      throw const MonoAshiMcpException(
        MonoAshiMcpErrorCode.resultTooLarge,
        "MCP 結果超過 256 KiB 上限。",
      );
    }
    return result;
  }
}
