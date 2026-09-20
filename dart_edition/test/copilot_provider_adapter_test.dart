import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/copilot/data/copilot_provider_adapter.dart";

void main() {
  const messages = <CopilotProviderMessage>[
    CopilotProviderMessage(
      role: CopilotProviderMessageRole.user,
      content: "question",
    ),
    CopilotProviderMessage(
      role: CopilotProviderMessageRole.assistant,
      content: "answer",
    ),
  ];

  test("OpenAI-compatible request keeps system and bearer auth", () {
    final request = CopilotProviderAdapter.chatRequest(
      protocol: CopilotProviderProtocol.openAiCompatible,
      apiKey: " secret ",
      model: "model-a",
      systemInstruction: "system policy",
      messages: messages,
      ollamaUsesOpenAiApi: false,
      maxOutputTokens: 2048,
    );

    expect(request.path, "/chat/completions");
    expect(request.headers["Authorization"], "Bearer secret");
    final payloadMessages = request.body!["messages"] as List<Object?>;
    expect(payloadMessages.first, <String, String>{
      "role": "system",
      "content": "system policy",
    });
    expect(request.body!["max_tokens"], 2048);
  });

  test("Gemini request normalizes model and uses native roles", () {
    final request = CopilotProviderAdapter.chatRequest(
      protocol: CopilotProviderProtocol.gemini,
      apiKey: "gem-key",
      model: "models/gemini-test",
      systemInstruction: "system policy",
      messages: messages,
      ollamaUsesOpenAiApi: false,
      maxOutputTokens: 512,
    );

    expect(request.path, "/v1beta/models/gemini-test:generateContent");
    expect(request.query, <String, String>{"key": "gem-key"});
    expect(request.headers.containsKey("Authorization"), isFalse);
    final contents = request.body!["contents"] as List<Object?>;
    expect((contents.first as Map<String, Object?>)["role"], "user");
    expect((contents.last as Map<String, Object?>)["role"], "model");
    expect(request.body!["systemInstruction"], isA<Map<String, Object?>>());
  });

  test("Anthropic request uses top-level system and x-api-key", () {
    final request = CopilotProviderAdapter.chatRequest(
      protocol: CopilotProviderProtocol.anthropic,
      apiKey: "anthropic-key",
      model: "claude-test",
      systemInstruction: "system policy",
      messages: messages,
      ollamaUsesOpenAiApi: false,
      maxOutputTokens: 1024,
    );

    expect(request.path, "/messages");
    expect(request.headers["x-api-key"], "anthropic-key");
    expect(request.headers["anthropic-version"], "2023-06-01");
    expect(request.body!["system"], "system policy");
    final payloadMessages = request.body!["messages"] as List<Object?>;
    expect(payloadMessages, hasLength(2));
  });

  test("native Ollama request selects api/chat and disables streaming", () {
    final request = CopilotProviderAdapter.chatRequest(
      protocol: CopilotProviderProtocol.ollama,
      apiKey: "ignored",
      model: "llama-test",
      systemInstruction: "system policy",
      messages: messages,
      ollamaUsesOpenAiApi: false,
      maxOutputTokens: 300,
    );

    expect(request.path, "/api/chat");
    expect(request.body!["stream"], isFalse);
    expect(request.headers.keys, <String>["Content-Type"]);
    final options = request.body!["options"] as Map<String, Object?>;
    expect(options["num_predict"], 300);
  });

  test("model requests select provider-specific endpoints", () {
    final gemini = CopilotProviderAdapter.modelsRequest(
      protocol: CopilotProviderProtocol.gemini,
      apiKey: "key",
      ollamaUsesOpenAiApi: false,
    );
    final ollamaNative = CopilotProviderAdapter.modelsRequest(
      protocol: CopilotProviderProtocol.ollama,
      apiKey: "",
      ollamaUsesOpenAiApi: false,
    );
    final ollamaV1 = CopilotProviderAdapter.modelsRequest(
      protocol: CopilotProviderProtocol.ollama,
      apiKey: "",
      ollamaUsesOpenAiApi: true,
    );

    expect(gemini.path, "/v1beta/models");
    expect(gemini.query, <String, String>{"key": "key"});
    expect(ollamaNative.path, "/api/tags");
    expect(ollamaV1.path, "/models");
  });

  test("model id extraction normalizes, deduplicates, and sorts", () {
    final gemini = CopilotProviderAdapter.extractModelIds(<String, Object?>{
      "models": <Object?>[
        <String, Object?>{"name": "models/zeta"},
        <String, Object?>{"name": "models/alpha"},
        <String, Object?>{"name": "models/alpha"},
      ],
    }, CopilotProviderProtocol.gemini);
    final openAi = CopilotProviderAdapter.extractModelIds(<String, Object?>{
      "data": <Object?>[
        <String, Object?>{"id": "b"},
        <String, Object?>{"id": "a"},
      ],
    }, CopilotProviderProtocol.openAiCompatible);

    expect(gemini, <String>["alpha", "zeta"]);
    expect(openAi, <String>["a", "b"]);
  });

  test("assistant reply extraction supports all provider fixtures", () {
    expect(
      CopilotProviderAdapter.extractAssistantReply(
        <String, Object?>{
          "choices": <Object?>[
            <String, Object?>{
              "message": <String, Object?>{"content": " openai "},
            },
          ],
        },
        CopilotProviderProtocol.openAiCompatible,
        ollamaUsesOpenAiApi: false,
      ),
      "openai",
    );
    expect(
      CopilotProviderAdapter.extractAssistantReply(
        <String, Object?>{
          "candidates": <Object?>[
            <String, Object?>{
              "content": <String, Object?>{
                "parts": <Object?>[
                  <String, Object?>{"text": "gemini"},
                ],
              },
            },
          ],
        },
        CopilotProviderProtocol.gemini,
        ollamaUsesOpenAiApi: false,
      ),
      "gemini",
    );
    expect(
      CopilotProviderAdapter.extractAssistantReply(
        <String, Object?>{
          "content": <Object?>[
            <String, Object?>{"type": "text", "text": "anthropic"},
          ],
        },
        CopilotProviderProtocol.anthropic,
        ollamaUsesOpenAiApi: false,
      ),
      "anthropic",
    );
    expect(
      CopilotProviderAdapter.extractAssistantReply(
        <String, Object?>{
          "message": <String, Object?>{"content": "ollama"},
        },
        CopilotProviderProtocol.ollama,
        ollamaUsesOpenAiApi: false,
      ),
      "ollama",
    );
  });
}
