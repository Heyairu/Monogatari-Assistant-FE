import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:monogatari_assistant/features/copilot/data/copilot_http_transport.dart";

void main() {
  test("transport disables redirects and encodes bounded JSON", () async {
    http.BaseRequest? captured;
    final transport = CopilotHttpTransport(
      maxRequestBytes: 1024,
      clientFactory: () => MockClient((request) async {
        captured = request;
        return http.Response('{"ok":true}', 200);
      }),
    );
    addTearDown(transport.dispose);

    final response = await transport.sendJson(
      "POST",
      Uri.parse("https://example.test/chat"),
      headers: const <String, String>{"Content-Type": "application/json"},
      jsonBody: const <String, Object?>{"message": "hello"},
      timeout: const Duration(seconds: 1),
      maxResponseBytes: 1024,
    );

    expect(response.statusCode, 200);
    expect(captured, isA<http.Request>());
    expect(captured!.followRedirects, isFalse);
    expect((captured! as http.Request).body, '{"message":"hello"}');
  });

  test("transport rejects an oversized request before sending", () async {
    var sent = false;
    final transport = CopilotHttpTransport(
      maxRequestBytes: 8,
      clientFactory: () => MockClient((request) async {
        sent = true;
        return http.Response("ok", 200);
      }),
    );
    addTearDown(transport.dispose);

    await expectLater(
      transport.sendJson(
        "POST",
        Uri.parse("https://example.test/chat"),
        headers: const <String, String>{},
        jsonBody: const <String, Object?>{"message": "too long"},
        timeout: const Duration(seconds: 1),
        maxResponseBytes: 1024,
      ),
      throwsA(isA<FormatException>()),
    );
    expect(sent, isFalse);
  });

  test("transport bounds responses and recreates its client", () async {
    var clientsCreated = 0;
    final transport = CopilotHttpTransport(
      maxRequestBytes: 1024,
      clientFactory: () {
        clientsCreated++;
        final body = clientsCreated == 1 ? "response-too-large" : "ok";
        return MockClient((request) async => http.Response(body, 200));
      },
    );
    addTearDown(transport.dispose);

    await expectLater(
      transport.sendJson(
        "GET",
        Uri.parse("https://example.test/models"),
        headers: const <String, String>{},
        timeout: const Duration(seconds: 1),
        maxResponseBytes: 4,
      ),
      throwsA(isA<FormatException>()),
    );
    expect(clientsCreated, 2);

    final recovered = await transport.sendJson(
      "GET",
      Uri.parse("https://example.test/models"),
      headers: const <String, String>{},
      timeout: const Duration(seconds: 1),
      maxResponseBytes: 4,
    );
    expect(recovered.body, "ok");
  });
}
