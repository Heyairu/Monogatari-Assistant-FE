enum CopilotProviderProtocol { openAiCompatible, gemini, anthropic, ollama }

enum CopilotProviderMessageRole { user, assistant }

final class CopilotProviderMessage {
  final CopilotProviderMessageRole role;
  final String content;

  const CopilotProviderMessage({required this.role, required this.content});
}

final class CopilotProviderRequest {
  final String method;
  final String path;
  final Map<String, String> query;
  final Map<String, String> headers;
  final Map<String, Object?>? body;

  const CopilotProviderRequest({
    required this.method,
    required this.path,
    this.query = const <String, String>{},
    required this.headers,
    this.body,
  });
}

/// Pure provider-specific request/response mapping.
///
/// Networking, destination validation, byte limits, redirects, and timeouts
/// intentionally remain the transport layer's responsibility.
final class CopilotProviderAdapter {
  const CopilotProviderAdapter._();

  static Map<String, String> headers(
    CopilotProviderProtocol protocol, {
    required String apiKey,
  }) {
    switch (protocol) {
      case CopilotProviderProtocol.gemini:
      case CopilotProviderProtocol.ollama:
        return const <String, String>{"Content-Type": "application/json"};
      case CopilotProviderProtocol.anthropic:
        return <String, String>{
          "Content-Type": "application/json",
          "anthropic-version": "2023-06-01",
          if (apiKey.trim().isNotEmpty) "x-api-key": apiKey.trim(),
        };
      case CopilotProviderProtocol.openAiCompatible:
        return <String, String>{
          "Content-Type": "application/json",
          if (apiKey.trim().isNotEmpty)
            "Authorization": "Bearer ${apiKey.trim()}",
        };
    }
  }

  static CopilotProviderRequest modelsRequest({
    required CopilotProviderProtocol protocol,
    required String apiKey,
    required bool ollamaUsesOpenAiApi,
  }) {
    final requestHeaders = headers(protocol, apiKey: apiKey);
    return switch (protocol) {
      CopilotProviderProtocol.gemini => CopilotProviderRequest(
        method: "GET",
        path: "/v1beta/models",
        query: apiKey.trim().isEmpty
            ? const <String, String>{}
            : <String, String>{"key": apiKey.trim()},
        headers: requestHeaders,
      ),
      CopilotProviderProtocol.ollama => CopilotProviderRequest(
        method: "GET",
        path: ollamaUsesOpenAiApi ? "/models" : "/api/tags",
        headers: requestHeaders,
      ),
      CopilotProviderProtocol.anthropic ||
      CopilotProviderProtocol.openAiCompatible => CopilotProviderRequest(
        method: "GET",
        path: "/models",
        headers: requestHeaders,
      ),
    };
  }

  static CopilotProviderRequest chatRequest({
    required CopilotProviderProtocol protocol,
    required String apiKey,
    required String model,
    required String systemInstruction,
    required List<CopilotProviderMessage> messages,
    required bool ollamaUsesOpenAiApi,
    required int maxOutputTokens,
  }) {
    final requestHeaders = headers(protocol, apiKey: apiKey);
    final openAiMessages = <Map<String, String>>[
      <String, String>{"role": "system", "content": systemInstruction},
      ...messages.map(_openAiMessage),
    ];
    switch (protocol) {
      case CopilotProviderProtocol.gemini:
        return CopilotProviderRequest(
          method: "POST",
          path:
              "/v1beta/models/${Uri.encodeComponent(_normalizeGeminiModelName(model))}:generateContent",
          query: apiKey.trim().isEmpty
              ? const <String, String>{}
              : <String, String>{"key": apiKey.trim()},
          headers: requestHeaders,
          body: <String, Object?>{
            "systemInstruction": <String, Object?>{
              "parts": <Object?>[
                <String, Object?>{"text": systemInstruction},
              ],
            },
            "contents": messages.map(_geminiMessage).toList(growable: false),
            "generationConfig": <String, Object?>{
              "temperature": 0.7,
              "maxOutputTokens": maxOutputTokens,
            },
          },
        );
      case CopilotProviderProtocol.anthropic:
        return CopilotProviderRequest(
          method: "POST",
          path: "/messages",
          headers: requestHeaders,
          body: <String, Object?>{
            "model": model,
            "max_tokens": maxOutputTokens,
            "system": systemInstruction,
            "messages": messages.map(_openAiMessage).toList(growable: false),
          },
        );
      case CopilotProviderProtocol.ollama:
        if (!ollamaUsesOpenAiApi) {
          return CopilotProviderRequest(
            method: "POST",
            path: "/api/chat",
            headers: requestHeaders,
            body: <String, Object?>{
              "model": model,
              "messages": openAiMessages,
              "stream": false,
              "options": <String, Object?>{
                "temperature": 0.7,
                "num_predict": maxOutputTokens,
              },
            },
          );
        }
        return _openAiChatRequest(
          headers: requestHeaders,
          model: model,
          messages: openAiMessages,
          maxOutputTokens: maxOutputTokens,
        );
      case CopilotProviderProtocol.openAiCompatible:
        return _openAiChatRequest(
          headers: requestHeaders,
          model: model,
          messages: openAiMessages,
          maxOutputTokens: maxOutputTokens,
        );
    }
  }

  static CopilotProviderRequest _openAiChatRequest({
    required Map<String, String> headers,
    required String model,
    required List<Map<String, String>> messages,
    required int maxOutputTokens,
  }) {
    return CopilotProviderRequest(
      method: "POST",
      path: "/chat/completions",
      headers: headers,
      body: <String, Object?>{
        "model": model,
        "messages": messages,
        "temperature": 0.7,
        "max_tokens": maxOutputTokens,
      },
    );
  }

  static Map<String, String> _openAiMessage(CopilotProviderMessage message) =>
      <String, String>{
        "role": message.role == CopilotProviderMessageRole.user
            ? "user"
            : "assistant",
        "content": message.content,
      };

  static Map<String, Object?> _geminiMessage(
    CopilotProviderMessage message,
  ) => <String, Object?>{
    "role": message.role == CopilotProviderMessageRole.user ? "user" : "model",
    "parts": <Object?>[
      <String, Object?>{"text": message.content},
    ],
  };

  static String _normalizeGeminiModelName(String model) {
    final trimmed = model.trim();
    return trimmed.startsWith("models/")
        ? trimmed.substring("models/".length)
        : trimmed;
  }

  static List<String> extractModelIds(
    Object? decoded,
    CopilotProviderProtocol protocol,
  ) {
    if (decoded is! Map<String, Object?>) return const <String>[];
    if (protocol == CopilotProviderProtocol.gemini) {
      final models = decoded["models"];
      if (models is List<Object?>) {
        return _sortedUnique(
          models
              .whereType<Map<String, Object?>>()
              .map((item) => item["name"])
              .whereType<String>()
              .map(_normalizeGeminiModelName),
        );
      }
    }

    final data = decoded["data"];
    if (data is List<Object?>) {
      return _sortedUnique(
        data
            .whereType<Map<String, Object?>>()
            .map((item) => item["id"])
            .whereType<String>(),
      );
    }

    final models = decoded["models"];
    if (models is List<Object?>) {
      return _sortedUnique(
        models
            .map(
              (item) => switch (item) {
                String value => value,
                Map<String, Object?> value => value["name"] as String?,
                _ => null,
              },
            )
            .whereType<String>(),
      );
    }
    return const <String>[];
  }

  static List<String> _sortedUnique(Iterable<String> values) {
    final result = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    result.sort();
    return result;
  }

  static String extractAssistantReply(
    Object? decoded,
    CopilotProviderProtocol protocol, {
    required bool ollamaUsesOpenAiApi,
  }) {
    if (decoded is Map<String, Object?>) {
      if (protocol == CopilotProviderProtocol.gemini) {
        final candidates = decoded["candidates"];
        if (candidates is List<Object?> && candidates.isNotEmpty) {
          final first = candidates.first;
          if (first is Map<String, Object?>) {
            final text = _extractTextParts(first["content"]);
            if (text.isNotEmpty) return text;
          }
        }
      }

      if (protocol == CopilotProviderProtocol.anthropic) {
        final text = _extractAnthropicText(decoded["content"]);
        if (text.isNotEmpty) return text;
      }

      if (protocol == CopilotProviderProtocol.ollama && !ollamaUsesOpenAiApi) {
        final message = decoded["message"];
        if (message is Map<String, Object?>) {
          final content = message["content"];
          if (content is String && content.trim().isNotEmpty) {
            return content.trim();
          }
        }
        final response = decoded["response"];
        if (response is String && response.trim().isNotEmpty) {
          return response.trim();
        }
      }

      final choices = decoded["choices"];
      if (choices is List<Object?> && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map<String, Object?>) {
          final message = first["message"];
          if (message is Map<String, Object?>) {
            final content = message["content"];
            if (content is String && content.trim().isNotEmpty) {
              return content.trim();
            }
          }
          final text = first["text"];
          if (text is String && text.trim().isNotEmpty) return text.trim();
        }
      }
    }
    return "模型已回應，但無法解析文字內容。";
  }

  static String _extractTextParts(Object? content) {
    if (content is! Map<String, Object?>) return "";
    final parts = content["parts"];
    if (parts is! List<Object?>) return "";
    return parts
        .whereType<Map<String, Object?>>()
        .map((part) => part["text"])
        .whereType<String>()
        .where((text) => text.trim().isNotEmpty)
        .join("\n")
        .trim();
  }

  static String _extractAnthropicText(Object? content) {
    if (content is! List<Object?>) return "";
    return content
        .whereType<Map<String, Object?>>()
        .where((part) => part["type"] == "text")
        .map((part) => part["text"])
        .whereType<String>()
        .where((text) => text.trim().isNotEmpty)
        .join("\n")
        .trim();
  }
}
