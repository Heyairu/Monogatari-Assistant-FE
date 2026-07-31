import "dart:async";

class ProjectIoSessionToken {
  final int generation;
  final String projectIdentity;

  const ProjectIoSessionToken(this.generation, this.projectIdentity);
}

class ProjectIoRunResult<T> {
  final T? value;
  final bool didRun;

  const ProjectIoRunResult.completed(T this.value) : didRun = true;
  const ProjectIoRunResult.stale() : value = null, didRun = false;
}

/// Serializes project I/O and invalidates callbacks from an older project
/// session before they can mutate the active editor state.
class ProjectIoSessionCoordinator {
  Future<void> _tail = Future<void>.value();
  int _generation = 0;
  String _projectIdentity = "";
  int? _cachedRevision;
  Object? _cachedPayload;

  ProjectIoSessionToken beginSession(String projectIdentity) {
    _generation++;
    _projectIdentity = projectIdentity;
    _cachedRevision = null;
    _cachedPayload = null;
    return currentToken;
  }

  ProjectIoSessionToken get currentToken =>
      ProjectIoSessionToken(_generation, _projectIdentity);

  bool isCurrent(ProjectIoSessionToken token) {
    return token.generation == _generation &&
        token.projectIdentity == _projectIdentity;
  }

  Future<ProjectIoRunResult<T>> run<T>(
    ProjectIoSessionToken token,
    Future<T> Function() operation,
  ) async {
    final previous = _tail;
    final turnDone = Completer<void>();
    _tail = turnDone.future;
    await previous;
    try {
      if (!isCurrent(token)) return ProjectIoRunResult<T>.stale();
      return ProjectIoRunResult<T>.completed(await operation());
    } finally {
      turnDone.complete();
    }
  }

  Future<T> sharedPayload<T>({
    required ProjectIoSessionToken token,
    required int revision,
    required Future<T> Function() create,
  }) async {
    if (!isCurrent(token)) {
      throw StateError("Project I/O session is no longer current");
    }
    if (_cachedRevision == revision && _cachedPayload is T) {
      return _cachedPayload! as T;
    }
    final payload = await create();
    if (isCurrent(token)) {
      _cachedRevision = revision;
      _cachedPayload = payload;
    }
    return payload;
  }
}
