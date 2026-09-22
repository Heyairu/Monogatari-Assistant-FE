import "dart:convert";
import "dart:io";

import "package:cryptography/cryptography.dart";
import "package:monogatari_assistant/features/mcp/domain/mcp_protocol_models.dart";

Future<void> main(List<String> arguments) async {
  final outputDirectory = Directory(
    arguments.isEmpty ? "build/mcp-sidecar" : arguments.first,
  );
  await outputDirectory.create(recursive: true);
  final executableName = Platform.isWindows
      ? "monoashi-mcp.exe"
      : "monoashi-mcp";
  final executable = File(
    "${outputDirectory.path}${Platform.pathSeparator}$executableName",
  );
  final result = await Process.run(Platform.resolvedExecutable, <String>[
    "compile",
    "exe",
    "bin/monoashi_mcp.dart",
    "-o",
    executable.path,
  ]);
  if (result.exitCode != 0) {
    stderr.write(result.stdout);
    stderr.write(result.stderr);
    exitCode = result.exitCode;
    return;
  }
  final digest = await Sha256().hash(await executable.readAsBytes());
  final manifest = <String, Object?>{
    "name": "monoashi-mcp",
    "contractVersion": MonoAshiMcpContract.serverVersion,
    "platform": Platform.operatingSystem,
    "architecture": _architecture(),
    "artifact": executableName,
    "bytes": await executable.length(),
    "sha256": digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, "0"))
        .join(),
  };
  await File(
    "${outputDirectory.path}${Platform.pathSeparator}manifest.json",
  ).writeAsString(const JsonEncoder.withIndent("  ").convert(manifest));
  stdout.writeln(jsonEncode(manifest));
}

String _architecture() {
  final version = Platform.version.toLowerCase();
  if (version.contains("arm64") || version.contains("aarch64")) return "arm64";
  if (version.contains("x64") || version.contains("x86_64")) return "x64";
  return "unknown";
}
