import "dart:io";

import "package:flutter_test/flutter_test.dart";

void main() {
  test("Copilot keeps explicit transport and conversation budgets", () {
    final source = File("lib/modules/copliot.dart").readAsStringSync();

    expect(source, contains("_maxUiMessages = 200"));
    expect(source, contains("_maxContextMessages = 24"));
    expect(source, contains("_maxRequestBytes = 256 * 1024"));
    expect(source, contains("_maxChatResponseBytes = 2 * 1024 * 1024"));
    expect(source, contains("http.Client _httpClient"));
    expect(source, contains("_httpClient.close()"));
    expect(source, isNot(contains("return http.get(")));
    expect(source, isNot(contains("return http.post(")));
  });
}
