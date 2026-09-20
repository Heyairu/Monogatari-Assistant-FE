import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/copilot/application/copilot_conversation_buffer.dart";
import "package:monogatari_assistant/features/copilot/domain/copilot_models.dart";

void main() {
  CopilotConversationMessage message(
    String content, {
    CopilotConversationRole role = CopilotConversationRole.user,
    CopilotMode mode = CopilotMode.chat,
    String? modelContent,
  }) {
    return CopilotConversationMessage(
      role: role,
      content: content,
      modelContent: modelContent,
      createdAt: DateTime.utc(2026),
      mode: mode,
    );
  }

  test("UI history retains only the newest bounded message count", () {
    final buffer = CopilotConversationBuffer(
      maxUiMessages: 3,
      maxUiHistoryBytes: 1024,
      maxContextMessages: 3,
      maxContextBytes: 1024,
    );

    for (var index = 0; index < 5; index++) {
      buffer.add(message("message-$index"));
    }

    expect(buffer.messages.map((item) => item.content), <String>[
      "message-2",
      "message-3",
      "message-4",
    ]);
  });

  test("UI byte budget drops older entries but keeps the newest message", () {
    final buffer = CopilotConversationBuffer(
      maxUiMessages: 20,
      maxUiHistoryBytes: 100,
      maxContextMessages: 20,
      maxContextBytes: 1024,
    );

    buffer.add(message("a" * 60));
    buffer.add(message("b" * 60));

    expect(buffer.messages, hasLength(1));
    expect(buffer.messages.single.content, "b" * 60);
  });

  test("model context is isolated by mode and uses model content", () {
    final buffer = CopilotConversationBuffer(
      maxUiMessages: 20,
      maxUiHistoryBytes: 4096,
      maxContextMessages: 20,
      maxContextBytes: 4096,
    );
    buffer
      ..add(message("chat", mode: CopilotMode.chat))
      ..add(
        message(
          "visible ask",
          mode: CopilotMode.ask,
          modelContent: "ask with context block",
        ),
      )
      ..add(
        message(
          "ask answer",
          role: CopilotConversationRole.assistant,
          mode: CopilotMode.ask,
        ),
      )
      ..add(message("plan", mode: CopilotMode.plan));

    final context = buffer.modelContext(CopilotMode.ask);

    expect(context, hasLength(2));
    expect(context.first.modelContent, "ask with context block");
    expect(context.last.content, "ask answer");
  });

  test("model context enforces count and latest-message byte limits", () {
    final buffer = CopilotConversationBuffer(
      maxUiMessages: 20,
      maxUiHistoryBytes: 4096,
      maxContextMessages: 2,
      maxContextBytes: 100,
    );
    buffer
      ..add(message("old"))
      ..add(message("middle"))
      ..add(message("newest"));

    expect(
      buffer.modelContext(CopilotMode.chat).map((item) => item.content),
      <String>["middle", "newest"],
    );

    final oversized = CopilotConversationBuffer(
      maxUiMessages: 20,
      maxUiHistoryBytes: 4096,
      maxContextMessages: 20,
      maxContextBytes: 40,
    )..add(message("x" * 20));
    expect(
      () => oversized.modelContext(CopilotMode.chat),
      throwsFormatException,
    );
  });

  test("production UI limits survive 250 messages and more than 1 MiB", () {
    final buffer = CopilotConversationBuffer(
      maxUiMessages: 200,
      maxUiHistoryBytes: 1024 * 1024,
      maxContextMessages: 24,
      maxContextBytes: 128 * 1024,
    );

    for (var index = 0; index < 250; index++) {
      buffer.add(message("$index:${"x" * 5000}"));
    }
    final retainedBytes = buffer.messages.fold<int>(
      0,
      (total, item) => total + item.content.length + 32,
    );

    expect(buffer.messages.length, lessThanOrEqualTo(200));
    expect(retainedBytes, lessThanOrEqualTo(1024 * 1024));
    expect(buffer.messages.last.content, startsWith("249:"));
  });

  test("pending rollback removes only a trailing user message", () {
    final buffer = CopilotConversationBuffer(
      maxUiMessages: 20,
      maxUiHistoryBytes: 4096,
      maxContextMessages: 20,
      maxContextBytes: 4096,
    );
    buffer.add(message("assistant", role: CopilotConversationRole.assistant));
    expect(buffer.removeLastUserMessage(), isNull);

    buffer.add(message("pending"));
    expect(buffer.removeLastUserMessage()?.content, "pending");
    expect(buffer.messages.single.content, "assistant");
  });
}
