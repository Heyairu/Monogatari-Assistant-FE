abstract final class MonoAshiMcpContract {
  static const String schemaVersion = "1";
  static const String serverName = "monoashi-mcp";
  static const String serverVersion = "0.1.0";

  static const String getProjectSummary = "get_project_summary";
  static const String listChapters = "list_chapters";
  static const String getChapter = "get_chapter";
  static const String searchProjectEntities = "search_project_entities";
  static const String getProjectEntity = "get_project_entity";
  static const String getContextBundle = "get_context_bundle";

  static const List<String> readToolNames = <String>[
    getProjectSummary,
    listChapters,
    getChapter,
    searchProjectEntities,
    getProjectEntity,
    getContextBundle,
  ];
}

enum MonoAshiMcpErrorCode {
  unavailable,
  invalidArgument,
  invalidCursor,
  notFound,
  cancelled,
  resultTooLarge,
  internal,
}

final class MonoAshiMcpException implements Exception {
  final MonoAshiMcpErrorCode code;
  final String message;

  const MonoAshiMcpException(this.code, this.message);

  @override
  String toString() => "MonoAshiMcpException(${code.name}, $message)";
}

final class MonoAshiMcpResourceDescriptor {
  final String uri;
  final String name;
  final String title;
  final String description;

  const MonoAshiMcpResourceDescriptor({
    required this.uri,
    required this.name,
    required this.title,
    required this.description,
  });
}
