import "dart:convert";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/mcp/application/mcp_bridge_server.dart";
import "package:monogatari_assistant/features/mcp/data/mcp_bridge_gateway.dart";
import "package:monogatari_assistant/features/story_read/domain/project_read_models.dart";

void main() {
  group("Phase 3 secure bridge", () {
    late Directory temporaryDirectory;
    late File descriptor;
    late McpBridgeServer server;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp(
        "monoashi-mcp-phase3-",
      );
      descriptor = File("${temporaryDirectory.path}/session.json");
      server = McpBridgeServer(descriptorFile: descriptor);
    });

    tearDown(() async {
      await server.stop();
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test(
      "one-time handshake returns the authorized immutable snapshot",
      () async {
        final snapshot = _snapshot("project-a", "Chapter A");
        await server.start(snapshot: snapshot, projectTitle: "Project A");
        expect(server.state.descriptorPath, descriptor.path);
        expect(server.state.descriptorAvailable, isTrue);
        final capturedDescriptor = await descriptor.readAsString();
        final gateway = IpcMonoAshiMcpGateway(descriptorFile: descriptor);

        final session = await gateway.currentSession();

        expect(session, isNotNull);
        expect(session!.snapshot.projectId, "project-a");
        expect(session.snapshot.chapters.single.title, "Chapter A");
        expect(session.generation, 1);
        expect(await descriptor.exists(), isFalse);
        expect(server.state.descriptorAvailable, isFalse);

        final replayDescriptor = File(
          "${temporaryDirectory.path}/captured-session.json",
        );
        await replayDescriptor.writeAsString(capturedDescriptor);
        final replayGateway = IpcMonoAshiMcpGateway(
          descriptorFile: replayDescriptor,
        );
        expect(await replayGateway.currentSession(), isNull);
        gateway.close();
        replayGateway.close();
      },
    );

    test("stop immediately revokes an issued access token", () async {
      await server.start(
        snapshot: _snapshot("project-a", "Chapter A"),
        projectTitle: "Project A",
      );
      final gateway = IpcMonoAshiMcpGateway(descriptorFile: descriptor);
      expect(await gateway.currentSession(), isNotNull);

      await server.stop();

      expect(await gateway.currentSession(), isNull);
      expect(await descriptor.exists(), isFalse);
      gateway.close();
    });

    test(
      "same-project refresh keeps capability and serves latest snapshot",
      () async {
        await server.start(
          snapshot: _snapshot("project-a", "Chapter A"),
          projectTitle: "Project A",
        );
        final gateway = IpcMonoAshiMcpGateway(descriptorFile: descriptor);
        final first = await gateway.currentSession();

        expect(
          server.updateSnapshot(_snapshot("project-a", "Chapter A revised")),
          isTrue,
        );
        final refreshed = await gateway.currentSession();

        expect(refreshed?.sessionId, first?.sessionId);
        expect(refreshed?.generation, first?.generation);
        expect(refreshed?.snapshot.chapters.single.title, "Chapter A revised");
        expect(
          server.updateSnapshot(_snapshot("project-b", "Leaked chapter")),
          isFalse,
        );
        gateway.close();
      },
    );

    test(
      "project rotation invalidates old endpoint, token and generation",
      () async {
        await server.start(
          snapshot: _snapshot("project-a", "Chapter A"),
          projectTitle: "Project A",
        );
        final oldGateway = IpcMonoAshiMcpGateway(descriptorFile: descriptor);
        final oldSession = await oldGateway.currentSession();
        expect(oldSession?.generation, 1);

        await server.rotate(
          snapshot: _snapshot("project-b", "Chapter B"),
          projectTitle: "Project B",
        );

        expect(await oldGateway.currentSession(), isNull);
        final newGateway = IpcMonoAshiMcpGateway(descriptorFile: descriptor);
        final newSession = await newGateway.currentSession();
        expect(newSession?.generation, 2);
        expect(newSession?.snapshot.projectId, "project-b");
        expect(newSession?.snapshot.chapters.single.title, "Chapter B");
        expect(newSession?.sessionId, isNot(oldSession?.sessionId));
        oldGateway.close();
        newGateway.close();
      },
    );

    test("Origin-bearing handshake is rejected", () async {
      await server.start(
        snapshot: _snapshot("project-a", "Chapter A"),
        projectTitle: "Project A",
      );
      final value = jsonDecode(await descriptor.readAsString()) as Map;
      final client = HttpClient();
      final request = await client.postUrl(
        Uri.parse(value["endpoint"] as String).resolve("/v1/handshake"),
      );
      request.headers.set(
        HttpHeaders.authorizationHeader,
        "Bearer ${value['bootstrapToken']}",
      );
      request.headers.set("origin", "https://attacker.invalid");
      request.contentLength = 0;

      final response = await request.close();

      expect(response.statusCode, HttpStatus.forbidden);
      await response.drain<void>();
      client.close(force: true);
    });
  });
}

ProjectReadSnapshot _snapshot(String projectId, String chapterTitle) {
  return ProjectReadSnapshot(
    projectId: projectId,
    overview: ProjectReadResource(
      resourceType: ProjectReadResourceType.project,
      resourceId: "project-overview",
      title: "Overview",
      content: '{"book":"$projectId"}',
      truncated: false,
    ),
    chapters: <ProjectReadChapter>[
      ProjectReadChapter(
        chapterId: "chapter-1",
        folderId: "folder-1",
        title: chapterTitle,
        content: "Body",
        order: 0,
      ),
    ],
    entities: const <ProjectReadSelectableResource>[
      ProjectReadSelectableResource(
        resourceType: ProjectReadResourceType.character,
        resourceId: "character-1",
        title: "Character",
        description: "Lead",
        content: "{}",
      ),
    ],
  );
}
