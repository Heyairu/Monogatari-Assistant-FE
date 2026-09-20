import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/copilot/domain/copilot_errors.dart";

void main() {
  test("HTTP status codes map to stable failure categories", () {
    final expected = <int, CopilotFailureCode>{
      400: CopilotFailureCode.invalidConfiguration,
      401: CopilotFailureCode.authenticationFailed,
      403: CopilotFailureCode.permissionDenied,
      404: CopilotFailureCode.modelUnavailable,
      408: CopilotFailureCode.requestTimedOut,
      413: CopilotFailureCode.contextTooLarge,
      422: CopilotFailureCode.invalidConfiguration,
      429: CopilotFailureCode.rateLimited,
      500: CopilotFailureCode.serviceUnavailable,
      503: CopilotFailureCode.serviceUnavailable,
    };

    for (final entry in expected.entries) {
      final failure = CopilotErrorPolicy.fromHttpStatus(
        entry.key,
        operation: CopilotOperation.conversation,
      );
      expect(failure.code, entry.value, reason: "HTTP ${entry.key}");
      expect(failure.statusCode, entry.key);
      expect(failure.userMessage, isNotEmpty);
    }
  });

  test("successful status guard accepts 2xx and throws safe failures", () {
    expect(
      () => CopilotErrorPolicy.ensureSuccessfulStatus(
        204,
        operation: CopilotOperation.conversation,
      ),
      returnsNormally,
    );
    expect(
      () => CopilotErrorPolicy.ensureSuccessfulStatus(
        401,
        operation: CopilotOperation.conversation,
      ),
      throwsA(
        isA<CopilotFailure>().having(
          (failure) => failure.code,
          "code",
          CopilotFailureCode.authenticationFailed,
        ),
      ),
    );
  });

  test("timeout and bounded transport failures keep distinct categories", () {
    expect(
      CopilotErrorPolicy.fromError(TimeoutException("raw timeout")).code,
      CopilotFailureCode.requestTimedOut,
    );
    expect(
      CopilotErrorPolicy.fromError(
        const FormatException("Copilot request 超過 256 KiB 上限，請縮短訊息。"),
      ).code,
      CopilotFailureCode.contextTooLarge,
    );
    expect(
      CopilotErrorPolicy.fromError(
        const FormatException("Copilot response 超過允許的大小上限。"),
      ).code,
      CopilotFailureCode.responseTooLarge,
    );
  });

  test("known local validation remains actionable", () {
    const source = FormatException("請先選擇章節，再使用 Ask／Plan 模式。");
    expect(CopilotErrorPolicy.describe(source), source.message);
    expect(
      CopilotErrorPolicy.describe(const FormatException("請至少選擇一個仍存在的補充資源。")),
      "請至少選擇一個仍存在的補充資源。",
    );
  });

  test("unknown exceptions and parser details are redacted", () {
    const secret = "secret-api-key";
    final networkMessage = CopilotErrorPolicy.describe(
      Exception(
        "https://provider.test?key=$secret Authorization: Bearer $secret",
      ),
    );
    final parserMessage = CopilotErrorPolicy.describe(
      const FormatException(
        "Unexpected character",
        '{"prompt":"private manuscript","key":"secret-api-key"}',
      ),
    );

    expect(networkMessage, isNot(contains(secret)));
    expect(networkMessage, isNot(contains("provider.test")));
    expect(parserMessage, isNot(contains(secret)));
    expect(parserMessage, isNot(contains("private manuscript")));
  });
}
