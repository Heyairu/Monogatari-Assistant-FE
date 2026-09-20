import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:http/http.dart" as http;

typedef CopilotHttpClientFactory = http.Client Function();

/// Bounded, cancellable HTTP transport shared by every Copilot provider.
final class CopilotHttpTransport {
  final int maxRequestBytes;
  final CopilotHttpClientFactory _clientFactory;
  late http.Client _client;
  bool _disposed = false;

  CopilotHttpTransport({
    required this.maxRequestBytes,
    CopilotHttpClientFactory? clientFactory,
  }) : _clientFactory = clientFactory ?? http.Client.new {
    _client = _clientFactory();
  }

  Future<http.Response> sendJson(
    String method,
    Uri uri, {
    required Map<String, String> headers,
    Object? jsonBody,
    required Duration timeout,
    required int maxResponseBytes,
  }) async {
    if (_disposed) {
      throw StateError("Copilot transport has been disposed.");
    }
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..headers.addAll(headers);
    if (jsonBody != null) {
      final body = jsonEncode(jsonBody);
      if (utf8.encode(body).length > maxRequestBytes) {
        throw const FormatException("Copilot request 超過 256 KiB 上限，請縮短訊息。");
      }
      request.body = body;
    }

    final activeClient = _client;
    try {
      return await (() async {
        final streamed = await activeClient.send(request);
        final bytes = BytesBuilder(copy: false);
        var received = 0;
        await for (final chunk in streamed.stream) {
          received += chunk.length;
          if (received > maxResponseBytes) {
            throw const FormatException("Copilot response 超過允許的大小上限。");
          }
          bytes.add(chunk);
        }
        return http.Response.bytes(
          bytes.takeBytes(),
          streamed.statusCode,
          request: request,
          headers: streamed.headers,
          reasonPhrase: streamed.reasonPhrase,
          isRedirect: streamed.isRedirect,
          persistentConnection: streamed.persistentConnection,
        );
      })().timeout(timeout);
    } on TimeoutException {
      _replaceClient(activeClient);
      rethrow;
    } on FormatException {
      _replaceClient(activeClient);
      rethrow;
    }
  }

  void cancel() {
    if (_disposed) return;
    final activeClient = _client;
    _client = _clientFactory();
    activeClient.close();
  }

  void _replaceClient(http.Client activeClient) {
    if (_disposed || !identical(activeClient, _client)) return;
    _client = _clientFactory();
    activeClient.close();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _client.close();
  }
}
