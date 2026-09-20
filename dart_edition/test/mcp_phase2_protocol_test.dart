import "dart:async";
import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:mcp_dart/mcp_dart.dart";
import "package:monogatari_assistant/features/mcp/application/monoashi_mcp_adapter.dart";
import "package:monogatari_assistant/features/mcp/application/monoashi_mcp_server.dart";
import "package:monogatari_assistant/features/mcp/domain/mcp_gateway.dart";
import "package:monogatari_assistant/features/mcp/domain/mcp_protocol_models.dart";
import "package:monogatari_assistant/features/story_read/application/project_read_snapshot_builder.dart";

import "fixtures/mcp_phase0_project_fixtures.dart";

void main() {
  test(
    "stdio-compatible protocol exposes tools, structured output, and resources",
    () async {
      final fixture = McpPhase0ProjectFixtures.small();
      final snapshot = ProjectReadSnapshotBuilder.build(
        fixture.project,
        glossaryEntries: fixture.glossaryEntries,
      );
      final adapter = MonoAshiMcpAdapter(
        gateway: FixedMonoAshiMcpGateway(
          MonoAshiMcpSession.forSnapshot(
            sessionId: "protocol-test-session",
            generation: 1,
            snapshot: snapshot,
          ),
        ),
      );
      final server = await buildMonoAshiMcpServer(adapter);
      final client = McpClient(
        const Implementation(name: "phase2-test-client", version: "1.0.0"),
        options: const McpClientOptions(
          protocol: McpProtocol.legacy,
          capabilities: ClientCapabilities(),
        ),
      );
      final serverToClient = StreamController<List<int>>();
      final clientToServer = StreamController<List<int>>();
      final clientTransport = IOStreamTransport(
        stream: serverToClient.stream,
        sink: clientToServer.sink,
      );
      final serverTransport = IOStreamTransport(
        stream: clientToServer.stream,
        sink: serverToClient.sink,
      );

      addTearDown(() async {
        await client.close();
        await server.close();
        await clientToServer.close();
        await serverToClient.close();
      });

      await server.connect(serverTransport);
      await client.connect(clientTransport);

      final tools = await client.listTools();
      expect(
        tools.tools.map((tool) => tool.name),
        containsAll(MonoAshiMcpContract.readToolNames),
      );
      expect(
        tools.tools.every(
          (tool) =>
              tool.annotations?.readOnlyHint == true &&
              tool.outputSchema != null,
        ),
        isTrue,
      );

      final call = await client.callTool(
        const CallToolRequest(
          name: MonoAshiMcpContract.listChapters,
          arguments: <String, dynamic>{"limit": 1},
        ),
      );
      expect(call.isError, isFalse);
      expect(call.hasStructuredContent, isTrue);
      expect(call.structuredContent?["schemaVersion"], "1");
      expect(call.structuredContent?["nextCursor"], isA<String>());

      final invalid = await client.callTool(
        const CallToolRequest(
          name: MonoAshiMcpContract.getProjectSummary,
          arguments: <String, dynamic>{"unexpected": true},
        ),
      );
      expect(invalid.isError, isTrue);

      final resources = await client.listResources();
      expect(resources.resources, isNotEmpty);
      final summary = resources.resources.firstWhere(
        (resource) => resource.uri.endsWith("/project/summary"),
      );
      final read = await client.readResource(
        ReadResourceRequest(uri: summary.uri),
      );
      final content = read.contents.single as TextResourceContents;
      final decoded = jsonDecode(content.text) as Map<String, dynamic>;
      expect(decoded["schemaVersion"], "1");
      expect(decoded["resource"]["type"], "project");
    },
  );

  test(
    "disconnected server initializes but read calls fail without disclosure",
    () async {
      final server = await buildMonoAshiMcpServer(
        MonoAshiMcpAdapter(gateway: const DisconnectedMonoAshiMcpGateway()),
      );
      final client = McpClient(
        const Implementation(name: "phase2-test-client", version: "1.0.0"),
        options: const McpClientOptions(
          protocol: McpProtocol.legacy,
          capabilities: ClientCapabilities(),
        ),
      );
      final serverToClient = StreamController<List<int>>();
      final clientToServer = StreamController<List<int>>();
      final clientTransport = IOStreamTransport(
        stream: serverToClient.stream,
        sink: clientToServer.sink,
      );
      final serverTransport = IOStreamTransport(
        stream: clientToServer.stream,
        sink: serverToClient.sink,
      );

      addTearDown(() async {
        await client.close();
        await server.close();
        await clientToServer.close();
        await serverToClient.close();
      });

      await server.connect(serverTransport);
      await client.connect(clientTransport);
      final result = await client.callTool(
        const CallToolRequest(name: MonoAshiMcpContract.getProjectSummary),
      );

      expect(result.isError, isTrue);
      expect(result.content.single, isA<TextContent>());
      expect(
        (result.content.single as TextContent).text,
        contains("unavailable"),
      );
      expect(
        (result.content.single as TextContent).text,
        isNot(contains("UUID")),
      );
      expect((await client.listResources()).resources, isEmpty);
    },
  );
}
