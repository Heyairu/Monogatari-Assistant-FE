import "dart:io";

import "package:flutter_test/flutter_test.dart";

void main() {
  test("Copilot keeps explicit transport and conversation budgets", () {
    final source = File("lib/modules/copliot.dart").readAsStringSync();
    final transportSource = File(
      "lib/features/copilot/data/copilot_http_transport.dart",
    ).readAsStringSync();
    final conversationSource = File(
      "lib/features/copilot/application/copilot_conversation_buffer.dart",
    ).readAsStringSync();
    final conversationControllerSource = File(
      "lib/features/copilot/application/copilot_conversation_controller.dart",
    ).readAsStringSync();

    expect(source, contains("_maxUiMessages = 200"));
    expect(source, contains("_maxContextMessages = 24"));
    expect(source, contains("_maxRequestBytes = 256 * 1024"));
    expect(source, contains("_maxChatResponseBytes = 2 * 1024 * 1024"));
    expect(source, contains("CopilotHttpTransport _transport"));
    expect(source, contains("CopilotRequestCoordinator"));
    expect(source, contains("CopilotConversationBuffer"));
    expect(source, contains("CopilotConversationController"));
    expect(source, contains("CopilotErrorPolicy"));
    expect(source, contains("_transport.dispose()"));
    expect(transportSource, contains("late http.Client _client"));
    expect(transportSource, contains("followRedirects = false"));
    expect(transportSource, contains("activeClient.close()"));
    expect(source, contains("CopilotSettingsStore"));
    expect(source, contains("COPILOT_ASK_ENABLED"));
    expect(source, contains("COPILOT_PLAN_ENABLED"));
    expect(source, contains("_cancelActiveRequest"));
    expect(source, contains("CopilotAskResponse.tryParse"));
    expect(source, contains("_describeCopilotError"));
    expect(source, isNot(contains("prefs.setString(_apiKeyPrefsKey")));
    expect(source, isNot(contains("return http.get(")));
    expect(source, isNot(contains("return http.post(")));
    expect(source, isNot(contains("_chatRequestGeneration")));
    expect(source, isNot(contains("void _trimUiHistory()")));
    expect(source, isNot(contains("beginConversationRequest(")));
    expect(source, isNot(contains("bool _isSending =")));
    expect(conversationSource, contains("void _trimUiHistory()"));
    expect(conversationControllerSource, contains("beginConversationRequest("));
  });
}
