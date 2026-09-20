import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/copilot/data/copilot_http_transport.dart";
import "package:monogatari_assistant/features/copilot/data/copilot_provider_adapter.dart";
import "package:monogatari_assistant/features/copilot/domain/copilot_errors.dart";

void main() {
  test("real HTTP client does not follow provider redirects", () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var redirectedTargetHits = 0;
    server.listen((request) async {
      if (request.uri.path == "/redirect") {
        request.response
          ..statusCode = HttpStatus.found
          ..headers.set(HttpHeaders.locationHeader, "/target");
      } else {
        redirectedTargetHits++;
        request.response
          ..statusCode = HttpStatus.ok
          ..write("unexpected");
      }
      await request.response.close();
    });
    final transport = CopilotHttpTransport(maxRequestBytes: 1024);
    addTearDown(transport.dispose);

    final response = await transport.sendJson(
      "GET",
      Uri.parse("http://127.0.0.1:${server.port}/redirect"),
      headers: const <String, String>{},
      timeout: const Duration(seconds: 2),
      maxResponseBytes: 1024,
    );

    expect(response.statusCode, HttpStatus.found);
    expect(redirectedTargetHits, 0);
  });

  test(
    "provider adapter and transport round-trip against a mock server",
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      Map<String, Object?>? receivedBody;
      String? receivedAuthorization;
      server.listen((request) async {
        receivedAuthorization = request.headers.value(
          HttpHeaders.authorizationHeader,
        );
        receivedBody =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, Object?>;
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode(<String, Object?>{
              "choices": <Object?>[
                <String, Object?>{
                  "message": <String, Object?>{"content": "mock answer"},
                },
              ],
            }),
          );
        await request.response.close();
      });
      final request = CopilotProviderAdapter.chatRequest(
        protocol: CopilotProviderProtocol.openAiCompatible,
        apiKey: "test-key",
        model: "mock-model",
        systemInstruction: "read-only policy",
        messages: const <CopilotProviderMessage>[
          CopilotProviderMessage(
            role: CopilotProviderMessageRole.user,
            content: "question",
          ),
        ],
        ollamaUsesOpenAiApi: false,
        maxOutputTokens: 256,
      );
      final transport = CopilotHttpTransport(maxRequestBytes: 8 * 1024);
      addTearDown(transport.dispose);

      final response = await transport.sendJson(
        request.method,
        Uri.parse("http://127.0.0.1:${server.port}${request.path}"),
        headers: request.headers,
        jsonBody: request.body,
        timeout: const Duration(seconds: 2),
        maxResponseBytes: 8 * 1024,
      );
      final reply = CopilotProviderAdapter.extractAssistantReply(
        jsonDecode(response.body),
        CopilotProviderProtocol.openAiCompatible,
        ollamaUsesOpenAiApi: false,
      );

      expect(receivedAuthorization, "Bearer test-key");
      expect(receivedBody!["model"], "mock-model");
      expect(receivedBody!["max_tokens"], 256);
      expect(receivedBody!["messages"], isA<List<Object?>>());
      expect(reply, "mock answer");
    },
  );

  test("timeout recreates the client for the next request", () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      if (request.uri.path == "/slow") {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      try {
        request.response
          ..statusCode = HttpStatus.ok
          ..write("ok");
        await request.response.close();
      } on Object {
        // The timeout intentionally closes the first request's client.
      }
    });
    final transport = CopilotHttpTransport(maxRequestBytes: 1024);
    addTearDown(transport.dispose);

    await expectLater(
      transport.sendJson(
        "GET",
        Uri.parse("http://127.0.0.1:${server.port}/slow"),
        headers: const <String, String>{},
        timeout: const Duration(milliseconds: 30),
        maxResponseBytes: 1024,
      ),
      throwsA(isA<TimeoutException>()),
    );

    final recovered = await transport.sendJson(
      "GET",
      Uri.parse("http://127.0.0.1:${server.port}/fast"),
      headers: const <String, String>{},
      timeout: const Duration(seconds: 2),
      maxResponseBytes: 1024,
    );
    expect(recovered.body, "ok");
  });

  test(
    "provider status failures are mapped without exposing response bodies",
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response
          ..statusCode = int.parse(request.uri.pathSegments.single)
          ..write('secret response body with key="provider-key"');
        await request.response.close();
      });
      final transport = CopilotHttpTransport(maxRequestBytes: 1024);
      addTearDown(transport.dispose);
      final expected = <int, CopilotFailureCode>{
        HttpStatus.unauthorized: CopilotFailureCode.authenticationFailed,
        HttpStatus.tooManyRequests: CopilotFailureCode.rateLimited,
        HttpStatus.internalServerError: CopilotFailureCode.serviceUnavailable,
      };

      for (final entry in expected.entries) {
        final response = await transport.sendJson(
          "GET",
          Uri.parse("http://127.0.0.1:${server.port}/${entry.key}"),
          headers: const <String, String>{},
          timeout: const Duration(seconds: 2),
          maxResponseBytes: 1024,
        );
        CopilotFailure? failure;
        try {
          CopilotErrorPolicy.ensureSuccessfulStatus(
            response.statusCode,
            operation: CopilotOperation.conversation,
          );
        } on CopilotFailure catch (error) {
          failure = error;
        }

        expect(failure?.code, entry.value, reason: "HTTP ${entry.key}");
        expect(failure?.statusCode, entry.key);
        expect(failure?.userMessage, isNot(contains("provider-key")));
        expect(failure?.userMessage, isNot(contains("secret response body")));
      }
    },
  );

  test("oversized real response is rejected and the client recovers", () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      try {
        request.response
          ..statusCode = HttpStatus.ok
          ..write(request.uri.path == "/large" ? "x" * 4096 : "ok");
        await request.response.close();
      } on Object {
        // Exceeding the response budget intentionally closes the first client.
      }
    });
    final transport = CopilotHttpTransport(maxRequestBytes: 1024);
    addTearDown(transport.dispose);

    Object? error;
    try {
      await transport.sendJson(
        "GET",
        Uri.parse("http://127.0.0.1:${server.port}/large"),
        headers: const <String, String>{},
        timeout: const Duration(seconds: 2),
        maxResponseBytes: 128,
      );
    } on Object catch (caught) {
      error = caught;
    }
    expect(
      CopilotErrorPolicy.fromError(error!).code,
      CopilotFailureCode.responseTooLarge,
    );

    final recovered = await transport.sendJson(
      "GET",
      Uri.parse("http://127.0.0.1:${server.port}/small"),
      headers: const <String, String>{},
      timeout: const Duration(seconds: 2),
      maxResponseBytes: 128,
    );
    expect(recovered.body, "ok");
  });

  test(
    "cancelling a real request allows the next request to succeed",
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final slowRequestStarted = Completer<void>();
      server.listen((request) async {
        if (request.uri.path == "/slow") {
          if (!slowRequestStarted.isCompleted) slowRequestStarted.complete();
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        try {
          request.response
            ..statusCode = HttpStatus.ok
            ..write("ok");
          await request.response.close();
        } on Object {
          // Cancellation intentionally closes the active connection.
        }
      });
      final transport = CopilotHttpTransport(maxRequestBytes: 1024);
      addTearDown(transport.dispose);

      final cancelledRequest = transport.sendJson(
        "GET",
        Uri.parse("http://127.0.0.1:${server.port}/slow"),
        headers: const <String, String>{},
        timeout: const Duration(seconds: 2),
        maxResponseBytes: 1024,
      );
      final cancellationExpectation = expectLater(
        cancelledRequest,
        throwsA(anything),
      );
      await slowRequestStarted.future.timeout(const Duration(seconds: 2));
      transport.cancel();
      await cancellationExpectation;

      final recovered = await transport.sendJson(
        "GET",
        Uri.parse("http://127.0.0.1:${server.port}/fast"),
        headers: const <String, String>{},
        timeout: const Duration(seconds: 2),
        maxResponseBytes: 1024,
      );
      expect(recovered.body, "ok");
    },
  );
}
