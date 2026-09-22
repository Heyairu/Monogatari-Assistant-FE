import "dart:convert";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/mcp/application/mcp_host_configuration.dart";

void main() {
  test("host configuration contains only sidecar and descriptor paths", () {
    final encoded = McpHostConfiguration.encode(
      sidecarPath: r"C:\Program Files\MonoAshi\monoashi-mcp.exe",
      descriptorPath: r"C:\Users\writer\MonoAshi\mcp\session.json",
    );
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    final servers = decoded["mcpServers"] as Map<String, dynamic>;
    final monoashi = servers["monoashi"] as Map<String, dynamic>;

    expect(monoashi["command"], contains("monoashi-mcp"));
    expect(monoashi["args"], <String>[
      "--descriptor",
      r"C:\Users\writer\MonoAshi\mcp\session.json",
    ]);
    expect(encoded, isNot(contains("bootstrapToken")));
    expect(encoded, isNot(contains("endpoint")));
  });

  test("sidecar locator finds the development build path", () async {
    final root = await Directory.systemTemp.createTemp("mcp-host-config-");
    addTearDown(() => root.delete(recursive: true));
    final sidecar = File(
      "${root.path}${Platform.pathSeparator}build"
      "${Platform.pathSeparator}mcp-sidecar"
      "${Platform.pathSeparator}${McpHostConfiguration.executableName}",
    );
    await sidecar.parent.create(recursive: true);
    await sidecar.writeAsBytes(const <int>[0]);

    final resolved = await McpHostConfiguration.locateSidecar(
      appExecutablePath:
          "${root.path}${Platform.pathSeparator}unrelated"
          "${Platform.pathSeparator}app.exe",
      workingDirectory: root.path,
    );

    expect(resolved, sidecar.absolute.path);
  });
}
