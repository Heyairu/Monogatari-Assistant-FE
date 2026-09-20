import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/copilot/application/copilot_request_coordinator.dart";
import "package:monogatari_assistant/features/copilot/domain/copilot_models.dart";

void main() {
  test("new model request supersedes the previous ticket", () {
    final coordinator = CopilotRequestCoordinator<String>();
    final first = coordinator.beginModelRequest("provider-a");
    final second = coordinator.beginModelRequest("provider-a");

    expect(coordinator.ownsModelRequest(first), isFalse);
    expect(coordinator.ownsModelRequest(second), isTrue);
    expect(
      coordinator.canPublishModelRequest(
        first,
        currentConfiguration: "provider-a",
      ),
      isFalse,
    );
  });

  test("configuration changes prevent publication but preserve ownership", () {
    final coordinator = CopilotRequestCoordinator<String>();
    final ticket = coordinator.beginConversationRequest(
      configuration: "model-a",
      mode: CopilotMode.ask,
    );

    expect(coordinator.ownsConversationRequest(ticket), isTrue);
    expect(
      coordinator.canPublishConversationRequest(
        ticket,
        currentConfiguration: "model-b",
        currentMode: CopilotMode.ask,
      ),
      isFalse,
    );
  });

  test("mode changes prevent a stale conversation response", () {
    final coordinator = CopilotRequestCoordinator<String>();
    final ticket = coordinator.beginConversationRequest(
      configuration: "same-settings",
      mode: CopilotMode.ask,
    );

    expect(
      coordinator.canPublishConversationRequest(
        ticket,
        currentConfiguration: "same-settings",
        currentMode: CopilotMode.plan,
      ),
      isFalse,
    );
  });

  test("cancel invalidates active tickets on both channels", () {
    final coordinator = CopilotRequestCoordinator<String>();
    final modelTicket = coordinator.beginModelRequest("settings");
    final conversationTicket = coordinator.beginConversationRequest(
      configuration: "settings",
      mode: CopilotMode.chat,
    );

    coordinator.cancelAll();

    expect(coordinator.ownsModelRequest(modelTicket), isFalse);
    expect(coordinator.ownsConversationRequest(conversationTicket), isFalse);
  });
}
