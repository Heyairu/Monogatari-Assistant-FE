import "dart:convert";
import "dart:io";

final class McpHostConfiguration {
  const McpHostConfiguration._();

  static String get executableName =>
      Platform.isWindows ? "monoashi-mcp.exe" : "monoashi-mcp";

  static String encode({
    required String sidecarPath,
    required String descriptorPath,
  }) {
    return const JsonEncoder.withIndent("  ").convert(<String, Object?>{
      "mcpServers": <String, Object?>{
        "monoashi": <String, Object?>{
          "command": sidecarPath,
          "args": <String>["--descriptor", descriptorPath],
        },
      },
    });
  }

  static Future<String?> locateSidecar({
    String? appExecutablePath,
    String? workingDirectory,
  }) async {
    final executable = File(appExecutablePath ?? Platform.resolvedExecutable);
    final candidates = <String>[];
    var directory = executable.absolute.parent;
    for (var depth = 0; depth < 7; depth++) {
      candidates
        ..add("${directory.path}${Platform.pathSeparator}$executableName")
        ..add(
          "${directory.path}${Platform.pathSeparator}mcp-sidecar"
          "${Platform.pathSeparator}$executableName",
        );
      final parent = directory.parent;
      if (parent.path == directory.path) break;
      directory = parent;
    }
    final working = Directory(
      workingDirectory ?? Directory.current.absolute.path,
    );
    candidates
      ..add(
        "${working.path}${Platform.pathSeparator}build"
        "${Platform.pathSeparator}mcp-sidecar"
        "${Platform.pathSeparator}$executableName",
      )
      ..add("${working.path}${Platform.pathSeparator}$executableName");

    final visited = <String>{};
    for (final path in candidates) {
      final file = File(path).absolute;
      if (visited.add(file.path) && await file.exists()) return file.path;
    }
    return null;
  }
}
