import "dart:collection";
import "dart:convert";

import "../domain/copilot_models.dart";

enum CopilotConversationRole { user, assistant, system }

final class CopilotConversationMessage {
  final CopilotConversationRole role;
  final String content;
  final String? modelContent;
  final DateTime createdAt;
  final CopilotMode mode;
  final CopilotContextSnapshot? contextSnapshot;
  final CopilotAskResponse? askResponse;
  final CopilotPlan? plan;
  final String? planValidationError;

  const CopilotConversationMessage({
    required this.role,
    required this.content,
    this.modelContent,
    required this.createdAt,
    required this.mode,
    this.contextSnapshot,
    this.askResponse,
    this.plan,
    this.planValidationError,
  });
}

/// In-memory, bounded conversation history shared by Chat, Ask, and Plan.
final class CopilotConversationBuffer {
  final int maxUiMessages;
  final int maxUiHistoryBytes;
  final int maxContextMessages;
  final int maxContextBytes;
  final List<CopilotConversationMessage> _messages =
      <CopilotConversationMessage>[];

  CopilotConversationBuffer({
    required this.maxUiMessages,
    required this.maxUiHistoryBytes,
    required this.maxContextMessages,
    required this.maxContextBytes,
  });

  UnmodifiableListView<CopilotConversationMessage> get messages =>
      UnmodifiableListView<CopilotConversationMessage>(_messages);

  bool get isEmpty => _messages.isEmpty;

  void add(CopilotConversationMessage message) {
    _messages.add(message);
    _trimUiHistory();
  }

  bool remove(CopilotConversationMessage message) => _messages.remove(message);

  CopilotConversationMessage? removeLastUserMessage() {
    if (_messages.isEmpty ||
        _messages.last.role != CopilotConversationRole.user) {
      return null;
    }
    return _messages.removeLast();
  }

  void clear() => _messages.clear();

  List<CopilotConversationMessage> modelContext(CopilotMode mode) {
    final selected = <CopilotConversationMessage>[];
    var totalBytes = 0;
    for (final message in _messages.reversed) {
      if (message.role == CopilotConversationRole.system ||
          message.mode != mode) {
        continue;
      }
      final modelContent = message.modelContent ?? message.content;
      final messageBytes = utf8.encode(modelContent).length + 32;
      if (selected.isNotEmpty &&
          (selected.length >= maxContextMessages ||
              totalBytes + messageBytes > maxContextBytes)) {
        break;
      }
      if (messageBytes > maxContextBytes && selected.isEmpty) {
        throw const FormatException("最新訊息超過模型 context 大小上限，請縮短內容。");
      }
      selected.add(message);
      totalBytes += messageBytes;
    }
    return List<CopilotConversationMessage>.unmodifiable(selected.reversed);
  }

  void _trimUiHistory() {
    var totalBytes = 0;
    var keepFrom = _messages.length;
    for (var index = _messages.length - 1; index >= 0; index--) {
      final nextBytes = utf8.encode(_messages[index].content).length + 32;
      final nextCount = _messages.length - index;
      if (nextCount > maxUiMessages ||
          (totalBytes + nextBytes > maxUiHistoryBytes &&
              keepFrom < _messages.length)) {
        break;
      }
      totalBytes += nextBytes;
      keepFrom = index;
    }
    if (keepFrom > 0) _messages.removeRange(0, keepFrom);
  }
}
