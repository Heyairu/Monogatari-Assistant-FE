import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/copilot/application/copilot_conversation_buffer.dart";
import "package:monogatari_assistant/features/copilot/application/copilot_conversation_controller.dart";
import "package:monogatari_assistant/features/copilot/application/copilot_request_coordinator.dart";
import "package:monogatari_assistant/features/copilot/domain/copilot_models.dart";

void main() {
  late CopilotConversationBuffer buffer;
  late CopilotRequestCoordinator<String> coordinator;
  late CopilotConversationController<String> controller;

  setUp(() {
    buffer = CopilotConversationBuffer(
      maxUiMessages: 20,
      maxUiHistoryBytes: 4096,
      maxContextMessages: 20,
      maxContextBytes: 4096,
    );
    coordinator = CopilotRequestCoordinator<String>();
    controller = CopilotConversationController<String>(
      buffer: buffer,
      requestCoordinator: coordinator,
    );
  });

  CopilotConversationOperation<String> begin({
    String configuration = "settings-a",
    CopilotMode mode = CopilotMode.ask,
  }) {
    return controller.begin(
      configuration: configuration,
      mode: mode,
      prompt: "question",
      modelContent: "question with context",
      createdAt: DateTime.utc(2026),
    );
  }

  CopilotConversationMessage assistant(CopilotMode mode) {
    return CopilotConversationMessage(
      role: CopilotConversationRole.assistant,
      content: "answer",
      createdAt: DateTime.utc(2026),
      mode: mode,
    );
  }

  test("begin owns the pending message and blocks a second request", () {
    final operation = begin();

    expect(controller.isSending, isTrue);
    expect(controller.owns(operation), isTrue);
    expect(buffer.messages.single.content, "question");
    expect(() => begin(), throwsStateError);
  });

  test("publish appends an assistant response and completes the request", () {
    final operation = begin();

    expect(
      controller.publish(
        operation,
        assistant(CopilotMode.ask),
        currentConfiguration: "settings-a",
        currentMode: CopilotMode.ask,
      ),
      isTrue,
    );

    expect(controller.isSending, isFalse);
    expect(buffer.messages.map((message) => message.content), <String>[
      "question",
      "answer",
    ]);
  });

  test("stale settings roll back the exact pending message", () {
    buffer.add(assistant(CopilotMode.chat));
    final operation = begin();

    final restored = controller.rollbackIfStale(
      operation,
      currentConfiguration: "settings-b",
      currentMode: CopilotMode.ask,
    );

    expect(restored, "question");
    expect(controller.isSending, isFalse);
    expect(buffer.messages.single.content, "answer");
  });

  test("failure reports errors only while configuration and mode match", () {
    final current = begin();
    final currentFailure = controller.fail(
      current,
      currentConfiguration: "settings-a",
      currentMode: CopilotMode.ask,
    );
    expect(currentFailure?.canReportError, isTrue);

    final stale = begin();
    final staleFailure = controller.fail(
      stale,
      currentConfiguration: "settings-a",
      currentMode: CopilotMode.plan,
    );
    expect(staleFailure?.canReportError, isFalse);
    expect(buffer.messages, isEmpty);
  });

  test("cancel invalidates the ticket and returns the original prompt", () {
    final operation = begin();

    expect(controller.cancel(), "question");
    expect(controller.isSending, isFalse);
    expect(buffer.messages, isEmpty);
    expect(coordinator.ownsConversationRequest(operation.ticket), isFalse);
    expect(controller.cancel(), isNull);
  });

  test("superseded operations cannot mutate presentation state", () {
    final operation = begin();
    coordinator.cancelConversationRequests();

    expect(
      controller.publish(
        operation,
        assistant(CopilotMode.ask),
        currentConfiguration: "settings-a",
        currentMode: CopilotMode.ask,
      ),
      isFalse,
    );
    expect(
      controller.fail(
        operation,
        currentConfiguration: "settings-a",
        currentMode: CopilotMode.ask,
      ),
      isNull,
    );
    expect(buffer.messages.single.content, "question");
  });
}
