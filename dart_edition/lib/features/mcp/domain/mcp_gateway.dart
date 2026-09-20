import "dart:convert";

import "../../story_read/domain/project_read_models.dart";

final class MonoAshiMcpSession {
  final String sessionId;
  final String projectId;
  final int generation;
  final ProjectReadSnapshot snapshot;

  const MonoAshiMcpSession({
    required this.sessionId,
    required this.projectId,
    required this.generation,
    required this.snapshot,
  });

  factory MonoAshiMcpSession.forSnapshot({
    required String sessionId,
    required int generation,
    required ProjectReadSnapshot snapshot,
  }) {
    final scopedId = projectReadFingerprint(
      utf8.encode("$sessionId:$generation:${snapshot.projectId}"),
    );
    return MonoAshiMcpSession(
      sessionId: sessionId,
      projectId: "project-$scopedId",
      generation: generation,
      snapshot: snapshot,
    );
  }
}

abstract interface class MonoAshiMcpGateway {
  Future<MonoAshiMcpSession?> currentSession();
}

final class FixedMonoAshiMcpGateway implements MonoAshiMcpGateway {
  final MonoAshiMcpSession? session;

  const FixedMonoAshiMcpGateway(this.session);

  @override
  Future<MonoAshiMcpSession?> currentSession() async => session;
}

final class DisconnectedMonoAshiMcpGateway implements MonoAshiMcpGateway {
  const DisconnectedMonoAshiMcpGateway();

  @override
  Future<MonoAshiMcpSession?> currentSession() async => null;
}
