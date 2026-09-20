import "dart:async";
import "dart:io";

import "package:mcp_dart/mcp_dart.dart";
import "package:monogatari_assistant/features/mcp/application/monoashi_mcp_adapter.dart";
import "package:monogatari_assistant/features/mcp/application/monoashi_mcp_server.dart";
import "package:monogatari_assistant/features/mcp/domain/mcp_gateway.dart";

Future<void> main() async {
  await runZonedGuarded(
    () async {
      final adapter = MonoAshiMcpAdapter(
        gateway: const DisconnectedMonoAshiMcpGateway(),
      );
      final server = await buildMonoAshiMcpServer(adapter);
      await server.connect(StdioServerTransport());
    },
    (error, stackTrace) {
      stderr.writeln("MonoAshi MCP stopped because of an internal error.");
    },
  );
}
