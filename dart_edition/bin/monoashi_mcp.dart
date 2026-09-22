import "dart:async";
import "dart:io";

import "package:mcp_dart/mcp_dart.dart";
import "package:monogatari_assistant/features/mcp/application/monoashi_mcp_adapter.dart";
import "package:monogatari_assistant/features/mcp/application/monoashi_mcp_server.dart";
import "package:monogatari_assistant/features/mcp/data/mcp_bridge_gateway.dart";
import "package:monogatari_assistant/features/mcp/domain/mcp_gateway.dart";

Future<void> main(List<String> arguments) async {
  await runZonedGuarded(
    () async {
      final descriptorPath = _descriptorPath(arguments);
      final MonoAshiMcpGateway gateway = descriptorPath == null
          ? const DisconnectedMonoAshiMcpGateway()
          : IpcMonoAshiMcpGateway(descriptorFile: File(descriptorPath));
      final adapter = MonoAshiMcpAdapter(gateway: gateway);
      final server = await buildMonoAshiMcpServer(adapter);
      await server.connect(StdioServerTransport());
    },
    (error, stackTrace) {
      stderr.writeln("MonoAshi MCP stopped because of an internal error.");
    },
  );
}

String? _descriptorPath(List<String> arguments) {
  for (var index = 0; index < arguments.length; index++) {
    if (arguments[index] == "--descriptor" && index + 1 < arguments.length) {
      final value = arguments[index + 1].trim();
      return value.isEmpty ? null : value;
    }
  }
  final value = Platform.environment["MONOASHI_MCP_DESCRIPTOR"]?.trim();
  return value == null || value.isEmpty ? null : value;
}
