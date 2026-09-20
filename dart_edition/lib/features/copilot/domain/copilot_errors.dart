import "dart:async";

enum CopilotOperation { listModels, conversation }

enum CopilotFailureCode {
  invalidConfiguration,
  authenticationFailed,
  permissionDenied,
  rateLimited,
  modelUnavailable,
  contextTooLarge,
  responseTooLarge,
  requestTimedOut,
  invalidResponse,
  networkUnavailable,
  serviceUnavailable,
  cancelled,
  unknown,
}

final class CopilotFailure implements Exception {
  final CopilotFailureCode code;
  final String userMessage;
  final int? statusCode;

  const CopilotFailure({
    required this.code,
    required this.userMessage,
    this.statusCode,
  });

  @override
  String toString() => "CopilotFailure(${code.name})";
}

/// Converts provider and transport failures into user-safe messages.
///
/// Raw URLs, response bodies, headers, prompts, and exception strings are
/// deliberately excluded from every returned message.
final class CopilotErrorPolicy {
  const CopilotErrorPolicy._();

  static void ensureSuccessfulStatus(
    int statusCode, {
    required CopilotOperation operation,
  }) {
    if (statusCode >= 200 && statusCode < 300) return;
    throw fromHttpStatus(statusCode, operation: operation);
  }

  static CopilotFailure fromHttpStatus(
    int statusCode, {
    required CopilotOperation operation,
  }) {
    final operationLabel = operation == CopilotOperation.listModels
        ? "模型清單"
        : "Copilot 請求";
    return switch (statusCode) {
      400 || 422 => CopilotFailure(
        code: CopilotFailureCode.invalidConfiguration,
        statusCode: statusCode,
        userMessage: "$operationLabel格式或參數不受模型服務接受。",
      ),
      401 => CopilotFailure(
        code: CopilotFailureCode.authenticationFailed,
        statusCode: statusCode,
        userMessage: "API Key 無效或已失效，請檢查憑證設定。",
      ),
      403 => CopilotFailure(
        code: CopilotFailureCode.permissionDenied,
        statusCode: statusCode,
        userMessage: "模型服務拒絕此憑證或模型的存取權限。",
      ),
      404 => CopilotFailure(
        code: CopilotFailureCode.modelUnavailable,
        statusCode: statusCode,
        userMessage: "找不到指定模型或 API endpoint，請重新選擇模型。",
      ),
      408 || 504 => CopilotFailure(
        code: CopilotFailureCode.requestTimedOut,
        statusCode: statusCode,
        userMessage: "$operationLabel逾時，請稍後重試。",
      ),
      413 => CopilotFailure(
        code: CopilotFailureCode.contextTooLarge,
        statusCode: statusCode,
        userMessage: "傳送內容超過模型服務限制，請縮小上下文範圍。",
      ),
      429 => CopilotFailure(
        code: CopilotFailureCode.rateLimited,
        statusCode: statusCode,
        userMessage: "模型服務目前請求過多或額度不足，請稍後重試。",
      ),
      >= 500 => CopilotFailure(
        code: CopilotFailureCode.serviceUnavailable,
        statusCode: statusCode,
        userMessage: "模型服務暫時無法使用，請稍後重試。",
      ),
      _ => CopilotFailure(
        code: CopilotFailureCode.invalidResponse,
        statusCode: statusCode,
        userMessage: "$operationLabel失敗（HTTP $statusCode）。",
      ),
    };
  }

  static CopilotFailure fromError(Object error) {
    if (error is CopilotFailure) return error;
    if (error is TimeoutException) {
      return const CopilotFailure(
        code: CopilotFailureCode.requestTimedOut,
        userMessage: "Copilot 請求逾時，請稍後重試。",
      );
    }
    if (error is FormatException) {
      final message = error.message;
      if (message == "Copilot request 超過 256 KiB 上限，請縮短訊息。") {
        return const CopilotFailure(
          code: CopilotFailureCode.contextTooLarge,
          userMessage: "Copilot request 超過 256 KiB 上限，請縮短訊息。",
        );
      }
      if (message == "Copilot response 超過允許的大小上限。") {
        return const CopilotFailure(
          code: CopilotFailureCode.responseTooLarge,
          userMessage: "模型回覆超過允許的大小上限。",
        );
      }
      if (_isSafeValidationMessage(message)) {
        return CopilotFailure(
          code: CopilotFailureCode.invalidResponse,
          userMessage: message,
        );
      }
      return const CopilotFailure(
        code: CopilotFailureCode.invalidResponse,
        userMessage: "模型回覆格式無法解析，請重試或更換模型。",
      );
    }
    return const CopilotFailure(
      code: CopilotFailureCode.networkUnavailable,
      userMessage: "Copilot 請求失敗，請檢查網路、API URL、模型與憑證設定。",
    );
  }

  static String describe(Object error) => fromError(error).userMessage;

  static bool _isSafeValidationMessage(String message) {
    const prefixes = <String>[
      "請先",
      "請至少",
      "找不到目前章節",
      "雲端 API URL",
      "API URL 格式",
      "最新訊息超過",
      "模型回覆超過 UI history",
      "Ask／Plan 模式",
      "Ask 最多可選擇",
      "Plan ",
      "Plan.",
      "不支援的 Plan schema",
      "未知的 Plan",
      "目前章節 context",
      "每個 Plan step",
    ];
    return prefixes.any(message.startsWith);
  }
}
