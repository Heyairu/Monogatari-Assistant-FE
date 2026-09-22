import "dart:convert";
import "dart:io";

import "../domain/mcp_gateway.dart";
import "../domain/mcp_protocol_models.dart";
import "mcp_snapshot_codec.dart";

final class IpcMonoAshiMcpGateway implements MonoAshiMcpGateway {
  static const int maxDescriptorBytes = 16 * 1024;
  static const int maxResponseBytes = 32 * 1024 * 1024;
  static const Duration requestTimeout = Duration(seconds: 5);

  final File descriptorFile;
  final HttpClient _client;
  Uri? _endpoint;
  String? _sessionId;
  String? _accessToken;
  int? _generation;

  IpcMonoAshiMcpGateway({required this.descriptorFile, HttpClient? client})
    : _client = client ?? HttpClient() {
    _client.connectionTimeout = requestTimeout;
  }

  @override
  Future<MonoAshiMcpSession?> currentSession() async {
    try {
      if (_accessToken == null) await _handshake();
      final endpoint = _endpoint;
      final sessionId = _sessionId;
      final generation = _generation;
      final token = _accessToken;
      if (endpoint == null ||
          sessionId == null ||
          generation == null ||
          token == null) {
        return null;
      }
      final request = await _client
          .getUrl(endpoint.resolve("/v1/session"))
          .timeout(requestTimeout);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, "Bearer $token");
      request.headers.set("x-monoashi-session", sessionId);
      request.headers.set("x-monoashi-generation", generation.toString());
      final response = await request.close().timeout(requestTimeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        _clear();
        return null;
      }
      final payload = await _readJson(response, maxResponseBytes);
      if (payload["sessionId"] != sessionId ||
          payload["generation"] != generation) {
        _clear();
        return null;
      }
      final snapshot = McpSnapshotCodec.decode(_map(payload["snapshot"]));
      final session = MonoAshiMcpSession.forSnapshot(
        sessionId: sessionId,
        generation: generation,
        snapshot: snapshot,
      );
      if (payload["projectId"] != session.projectId) {
        _clear();
        return null;
      }
      return session;
    } on Object {
      _clear();
      return null;
    }
  }

  Future<void> _handshake() async {
    final stat = await descriptorFile.stat();
    if (stat.size <= 0 || stat.size > maxDescriptorBytes) {
      throw const FormatException("Invalid descriptor.");
    }
    final descriptor = _map(
      jsonDecode(await descriptorFile.readAsString()) as Object?,
    );
    if (descriptor["version"] != 1) throw const FormatException();
    if (descriptor["contractVersion"] != MonoAshiMcpContract.serverVersion) {
      throw const FormatException("Incompatible bridge contract.");
    }
    final endpoint = Uri.parse(_string(descriptor, "endpoint"));
    if (endpoint.scheme != "http" ||
        endpoint.host != InternetAddress.loopbackIPv4.address ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment ||
        endpoint.path.isNotEmpty) {
      throw const FormatException("Invalid endpoint.");
    }
    final expiresAt = DateTime.parse(_string(descriptor, "expiresAt"));
    if (!expiresAt.isAfter(DateTime.now().toUtc())) {
      throw const FormatException("Expired descriptor.");
    }
    final sessionId = _string(descriptor, "sessionId");
    final generation = descriptor["generation"];
    final bootstrapToken = _string(descriptor, "bootstrapToken");
    if (generation is! int) throw const FormatException();
    final request = await _client
        .postUrl(endpoint.resolve("/v1/handshake"))
        .timeout(requestTimeout);
    request.followRedirects = false;
    request.headers.set(
      HttpHeaders.authorizationHeader,
      "Bearer $bootstrapToken",
    );
    request.contentLength = 0;
    final response = await request.close().timeout(requestTimeout);
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw const HttpException("Handshake rejected.");
    }
    final payload = await _readJson(response, maxDescriptorBytes);
    if (payload["sessionId"] != sessionId ||
        payload["generation"] != generation) {
      throw const FormatException("Session mismatch.");
    }
    _endpoint = endpoint;
    _sessionId = sessionId;
    _generation = generation;
    _accessToken = _string(payload, "accessToken");
  }

  Future<Map<String, Object?>> _readJson(
    HttpClientResponse response,
    int maxBytes,
  ) async {
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
      if (bytes.length > maxBytes) throw const FormatException();
    }
    return _map(jsonDecode(utf8.decode(bytes)) as Object?);
  }

  void close() {
    _clear();
    _client.close(force: true);
  }

  void _clear() {
    _endpoint = null;
    _sessionId = null;
    _accessToken = null;
    _generation = null;
  }

  static Map<String, Object?> _map(Object? value) {
    if (value is! Map) throw const FormatException();
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) throw const FormatException();
    return value;
  }
}
