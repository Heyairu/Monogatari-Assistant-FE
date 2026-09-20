import "copilot_conversation_buffer.dart";
import "copilot_request_coordinator.dart";
import "../domain/copilot_models.dart";

final class CopilotConversationOperation<T> {
  final CopilotConversationRequestTicket<T> ticket;
  final CopilotConversationMessage userMessage;
  final String originalPrompt;

  const CopilotConversationOperation({
    required this.ticket,
    required this.userMessage,
    required this.originalPrompt,
  });
}

final class CopilotConversationFailure {
  final String restoredPrompt;
  final bool canReportError;

  const CopilotConversationFailure({
    required this.restoredPrompt,
    required this.canReportError,
  });
}

/// Coordinates the presentation lifecycle of one in-flight conversation.
///
/// Network I/O and response parsing deliberately remain outside this class.
/// This controller owns only the active operation, pending message rollback,
/// latest-wins publication checks, and the derived sending state.
final class CopilotConversationController<T> {
  final CopilotConversationBuffer buffer;
  final CopilotRequestCoordinator<T> requestCoordinator;

  CopilotConversationOperation<T>? _activeOperation;

  CopilotConversationController({
    required this.buffer,
    required this.requestCoordinator,
  });

  bool get isSending => _activeOperation != null;

  CopilotConversationOperation<T> begin({
    required T configuration,
    required CopilotMode mode,
    required String prompt,
    required String modelContent,
    required DateTime createdAt,
    CopilotContextSnapshot? contextSnapshot,
  }) {
    if (_activeOperation != null) {
      throw StateError("A Copilot conversation request is already active.");
    }
    final message = CopilotConversationMessage(
      role: CopilotConversationRole.user,
      content: prompt,
      modelContent: modelContent,
      createdAt: createdAt,
      mode: mode,
      contextSnapshot: contextSnapshot,
    );
    final operation = CopilotConversationOperation<T>(
      ticket: requestCoordinator.beginConversationRequest(
        configuration: configuration,
        mode: mode,
      ),
      userMessage: message,
      originalPrompt: prompt,
    );
    buffer.add(message);
    _activeOperation = operation;
    return operation;
  }

  bool owns(CopilotConversationOperation<T> operation) {
    return identical(_activeOperation, operation) &&
        requestCoordinator.ownsConversationRequest(operation.ticket);
  }

  bool canPublish(
    CopilotConversationOperation<T> operation, {
    required T currentConfiguration,
    required CopilotMode currentMode,
  }) {
    return owns(operation) &&
        requestCoordinator.canPublishConversationRequest(
          operation.ticket,
          currentConfiguration: currentConfiguration,
          currentMode: currentMode,
        );
  }

  String? rollbackIfStale(
    CopilotConversationOperation<T> operation, {
    required T currentConfiguration,
    required CopilotMode currentMode,
  }) {
    if (!owns(operation) ||
        canPublish(
          operation,
          currentConfiguration: currentConfiguration,
          currentMode: currentMode,
        )) {
      return null;
    }
    return _rollback(operation);
  }

  CopilotConversationFailure? fail(
    CopilotConversationOperation<T> operation, {
    required T currentConfiguration,
    required CopilotMode currentMode,
  }) {
    if (!owns(operation)) return null;
    final canReportError = canPublish(
      operation,
      currentConfiguration: currentConfiguration,
      currentMode: currentMode,
    );
    return CopilotConversationFailure(
      restoredPrompt: _rollback(operation),
      canReportError: canReportError,
    );
  }

  bool publish(
    CopilotConversationOperation<T> operation,
    CopilotConversationMessage assistantMessage, {
    required T currentConfiguration,
    required CopilotMode currentMode,
  }) {
    if (!canPublish(
      operation,
      currentConfiguration: currentConfiguration,
      currentMode: currentMode,
    )) {
      return false;
    }
    buffer.add(assistantMessage);
    _activeOperation = null;
    return true;
  }

  String? cancel() {
    final operation = _activeOperation;
    if (operation == null) return null;
    requestCoordinator.cancelConversationRequests();
    buffer.remove(operation.userMessage);
    _activeOperation = null;
    return operation.originalPrompt;
  }

  void complete(CopilotConversationOperation<T> operation) {
    if (owns(operation)) _activeOperation = null;
  }

  String _rollback(CopilotConversationOperation<T> operation) {
    buffer.remove(operation.userMessage);
    _activeOperation = null;
    return operation.originalPrompt;
  }
}
