import "../domain/copilot_models.dart";

final class CopilotModelRequestTicket<T> {
  final int generation;
  final T configuration;

  const CopilotModelRequestTicket({
    required this.generation,
    required this.configuration,
  });
}

final class CopilotConversationRequestTicket<T> {
  final int generation;
  final T configuration;
  final CopilotMode mode;

  const CopilotConversationRequestTicket({
    required this.generation,
    required this.configuration,
    required this.mode,
  });
}

/// Owns latest-wins request generations without depending on Flutter widgets.
final class CopilotRequestCoordinator<T> {
  int _modelGeneration = 0;
  int _conversationGeneration = 0;

  CopilotModelRequestTicket<T> beginModelRequest(T configuration) {
    return CopilotModelRequestTicket<T>(
      generation: ++_modelGeneration,
      configuration: configuration,
    );
  }

  CopilotConversationRequestTicket<T> beginConversationRequest({
    required T configuration,
    required CopilotMode mode,
  }) {
    return CopilotConversationRequestTicket<T>(
      generation: ++_conversationGeneration,
      configuration: configuration,
      mode: mode,
    );
  }

  bool ownsModelRequest(CopilotModelRequestTicket<T> ticket) {
    return ticket.generation == _modelGeneration;
  }

  bool canPublishModelRequest(
    CopilotModelRequestTicket<T> ticket, {
    required T currentConfiguration,
  }) {
    return ownsModelRequest(ticket) &&
        ticket.configuration == currentConfiguration;
  }

  bool ownsConversationRequest(CopilotConversationRequestTicket<T> ticket) {
    return ticket.generation == _conversationGeneration;
  }

  bool canPublishConversationRequest(
    CopilotConversationRequestTicket<T> ticket, {
    required T currentConfiguration,
    required CopilotMode currentMode,
  }) {
    return ownsConversationRequest(ticket) &&
        ticket.configuration == currentConfiguration &&
        ticket.mode == currentMode;
  }

  void cancelModelRequests() => _modelGeneration++;

  void cancelConversationRequests() => _conversationGeneration++;

  void cancelAll() {
    cancelModelRequests();
    cancelConversationRequests();
  }
}
