import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";

import "../data/mcp_snapshot_codec.dart";
import "../domain/mcp_gateway.dart";
import "../domain/mcp_protocol_models.dart";
import "../../story_read/domain/project_read_models.dart";

enum McpBridgeStatus { stopped, starting, active, expired, failed }

final class McpBridgeState {
  final McpBridgeStatus status;
  final String? projectTitle;
  final int generation;
  final DateTime? expiresAt;
  final String? failure;
  final String? descriptorPath;
  final bool descriptorAvailable;

  const McpBridgeState({
    required this.status,
    this.projectTitle,
    this.generation = 0,
    this.expiresAt,
    this.failure,
    this.descriptorPath,
    this.descriptorAvailable = false,
  });

  static const stopped = McpBridgeState(status: McpBridgeStatus.stopped);
}

final class McpBridgeServer {
  static const Duration defaultLifetime = Duration(hours: 8);
  static const int maxConcurrentRequests = 4;
  static const int maxRequestBytes = 16 * 1024;
  static const int maxSnapshotBytes = 32 * 1024 * 1024;

  final File descriptorFile;
  final Duration lifetime;
  final void Function(McpBridgeState state)? onStateChanged;

  HttpServer? _server;
  Timer? _expiryTimer;
  ProjectReadSnapshot? _snapshot;
  String? _sessionId;
  String? _bootstrapToken;
  String? _accessToken;
  int _generation = 0;
  int _requests = 0;
  McpBridgeState _state = McpBridgeState.stopped;

  McpBridgeServer({
    required this.descriptorFile,
    this.lifetime = defaultLifetime,
    this.onStateChanged,
  });

  McpBridgeState get state => _state;

  Future<void> start({
    required ProjectReadSnapshot snapshot,
    required String projectTitle,
  }) async {
    await stop();
    _setState(const McpBridgeState(status: McpBridgeStatus.starting));
    try {
      _generation++;
      _snapshot = snapshot;
      _sessionId = _randomSecret(18);
      _bootstrapToken = _randomSecret(32);
      _accessToken = null;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _server = server;
      final expiresAt = DateTime.now().toUtc().add(lifetime);
      _expiryTimer = Timer(lifetime, () => unawaited(_expire()));
      unawaited(_serve(server));
      await _writeDescriptor(server.port, expiresAt);
      _setState(
        McpBridgeState(
          status: McpBridgeStatus.active,
          projectTitle: projectTitle,
          generation: _generation,
          expiresAt: expiresAt,
          descriptorPath: descriptorFile.path,
          descriptorAvailable: true,
        ),
      );
    } catch (_) {
      await _closeServer();
      _clearSecrets();
      _setState(
        const McpBridgeState(
          status: McpBridgeStatus.failed,
          failure: "無法啟動本機 MCP bridge。",
        ),
      );
      rethrow;
    }
  }

  Future<void> rotate({
    required ProjectReadSnapshot snapshot,
    required String projectTitle,
  }) => start(snapshot: snapshot, projectTitle: projectTitle);

  bool updateSnapshot(ProjectReadSnapshot snapshot) {
    final current = _snapshot;
    if (_state.status != McpBridgeStatus.active ||
        current == null ||
        current.projectId != snapshot.projectId) {
      return false;
    }
    _snapshot = snapshot;
    return true;
  }

  Future<void> stop() async {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    await _closeServer();
    _clearSecrets();
    await _deleteDescriptor();
    _setState(McpBridgeState.stopped);
  }

  Future<void> _expire() async {
    await stop();
    _setState(
      McpBridgeState(status: McpBridgeStatus.expired, generation: _generation),
    );
  }

  Future<void> _serve(HttpServer server) async {
    try {
      await for (final request in server) {
        unawaited(_handle(request));
      }
    } on Object {
      // Closing the server terminates the request stream normally.
    }
  }

  Future<void> _handle(HttpRequest request) async {
    if (_requests >= maxConcurrentRequests) {
      return _reply(request.response, HttpStatus.tooManyRequests);
    }
    _requests++;
    try {
      final expectedHost = "127.0.0.1:${_server?.port}";
      if (request.headers.value(HttpHeaders.hostHeader) != expectedHost ||
          request.headers.value("origin") != null) {
        return _reply(request.response, HttpStatus.forbidden);
      }
      if (request.method == "POST" && request.uri.path == "/v1/handshake") {
        await _drainBounded(request);
        if (!_authorized(request, _bootstrapToken)) {
          return _reply(request.response, HttpStatus.unauthorized);
        }
        _accessToken = _randomSecret(32);
        _bootstrapToken = null;
        await _deleteDescriptor();
        final current = _state;
        _setState(
          McpBridgeState(
            status: McpBridgeStatus.active,
            projectTitle: current.projectTitle,
            generation: current.generation,
            expiresAt: current.expiresAt,
            descriptorPath: descriptorFile.path,
            descriptorAvailable: false,
          ),
        );
        return _json(request.response, <String, Object?>{
          "sessionId": _sessionId,
          "generation": _generation,
          "accessToken": _accessToken,
        });
      }
      if (request.method == "GET" && request.uri.path == "/v1/session") {
        if (!_authorized(request, _accessToken) ||
            request.headers.value("x-monoashi-session") != _sessionId ||
            request.headers.value("x-monoashi-generation") !=
                _generation.toString()) {
          return _reply(request.response, HttpStatus.unauthorized);
        }
        final snapshot = _snapshot;
        if (snapshot == null) {
          return _reply(request.response, HttpStatus.gone);
        }
        final session = MonoAshiMcpSession.forSnapshot(
          sessionId: _sessionId!,
          generation: _generation,
          snapshot: snapshot,
        );
        return _json(request.response, <String, Object?>{
          "sessionId": session.sessionId,
          "projectId": session.projectId,
          "generation": session.generation,
          "snapshot": McpSnapshotCodec.encode(snapshot),
        }, maxBytes: maxSnapshotBytes);
      }
      return _reply(request.response, HttpStatus.notFound);
    } on FormatException {
      return _reply(request.response, HttpStatus.badRequest);
    } catch (_) {
      return _reply(request.response, HttpStatus.internalServerError);
    } finally {
      _requests--;
    }
  }

  bool _authorized(HttpRequest request, String? expected) {
    final header = request.headers.value(HttpHeaders.authorizationHeader);
    if (expected == null || header == null || !header.startsWith("Bearer ")) {
      return false;
    }
    return _constantTimeEquals(header.substring(7), expected);
  }

  Future<void> _drainBounded(HttpRequest request) async {
    var length = 0;
    await for (final chunk in request) {
      length += chunk.length;
      if (length > maxRequestBytes) throw const FormatException();
    }
  }

  Future<void> _writeDescriptor(int port, DateTime expiresAt) async {
    await descriptorFile.parent.create(recursive: true);
    final temporary = File("${descriptorFile.path}.tmp");
    await temporary.writeAsString(
      jsonEncode(<String, Object?>{
        "version": 1,
        "contractVersion": MonoAshiMcpContract.serverVersion,
        "endpoint": "http://127.0.0.1:$port",
        "sessionId": _sessionId,
        "generation": _generation,
        "expiresAt": expiresAt.toIso8601String(),
        "bootstrapToken": _bootstrapToken,
      }),
      flush: true,
    );
    if (await descriptorFile.exists()) await descriptorFile.delete();
    await temporary.rename(descriptorFile.path);
  }

  Future<void> _deleteDescriptor() async {
    try {
      if (await descriptorFile.exists()) await descriptorFile.delete();
    } on FileSystemException {
      // A stale descriptor contains a rotated token and cannot authorize.
    }
  }

  Future<void> _closeServer() async {
    final server = _server;
    _server = null;
    if (server != null) await server.close(force: true);
  }

  void _clearSecrets() {
    _snapshot = null;
    _sessionId = null;
    _bootstrapToken = null;
    _accessToken = null;
  }

  void _setState(McpBridgeState value) {
    _state = value;
    onStateChanged?.call(value);
  }

  static String _randomSecret(int bytes) {
    final random = Random.secure();
    return base64Url
        .encode(List<int>.generate(bytes, (_) => random.nextInt(256)))
        .replaceAll("=", "");
  }

  static bool _constantTimeEquals(String left, String right) {
    final a = utf8.encode(left);
    final b = utf8.encode(right);
    var difference = a.length ^ b.length;
    final length = max(a.length, b.length);
    for (var i = 0; i < length; i++) {
      difference |= (i < a.length ? a[i] : 0) ^ (i < b.length ? b[i] : 0);
    }
    return difference == 0;
  }

  static Future<void> _reply(HttpResponse response, int status) async {
    response.statusCode = status;
    response.headers.contentLength = 0;
    await response.close();
  }

  static Future<void> _json(
    HttpResponse response,
    Map<String, Object?> value, {
    int maxBytes = maxRequestBytes,
  }) async {
    final bytes = utf8.encode(jsonEncode(value));
    if (bytes.length > maxBytes) {
      return _reply(response, HttpStatus.requestEntityTooLarge);
    }
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType.json;
    response.headers.contentLength = bytes.length;
    response.add(bytes);
    await response.close();
  }
}
