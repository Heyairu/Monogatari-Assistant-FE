import "dart:async";
import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:monogatari_assistant/bin/ui_library.dart";
import "package:monogatari_assistant/features/copilot/application/copilot_conversation_buffer.dart";
import "package:monogatari_assistant/features/copilot/application/copilot_project_context_builder.dart";
import "package:monogatari_assistant/features/copilot/data/copilot_http_transport.dart";
import "package:monogatari_assistant/features/copilot/data/copilot_settings_store.dart";
import "package:monogatari_assistant/features/copilot/domain/copilot_models.dart";
import "package:monogatari_assistant/modules/copliot.dart";
import "package:shared_preferences/shared_preferences.dart";

final class _MemorySecureStore implements CopilotSecureKeyValueStore {
  final Map<String, String> values = <String, String>{};
  Object? deleteError;

  @override
  Future<void> delete(String key) async {
    if (deleteError case final error?) throw error;
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

final class _BlockingSecureStore implements CopilotSecureKeyValueStore {
  final Completer<String?> readCompleter = Completer<String?>();

  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) => readCompleter.future;

  @override
  Future<void> write(String key, String value) async {}
}

final class _BlockingHttpClient extends http.BaseClient {
  final Completer<void> requestStarted = Completer<void>();
  final Completer<http.StreamedResponse> _response =
      Completer<http.StreamedResponse>();
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (!requestStarted.isCompleted) requestStarted.complete();
    return _response.future;
  }

  @override
  void close() {
    closed = true;
    if (!_response.isCompleted) {
      _response.completeError(http.ClientException("client closed"));
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpCopilot(
    WidgetTester tester, {
    required bool askEnabled,
    required bool planEnabled,
    CopilotSettingsStore? settingsStore,
    CopilotHttpTransport? transport,
    CopilotConversationBuffer? conversationBuffer,
    List<CopilotSelectableResource>? selectableResources,
  }) async {
    tester.view.physicalSize = const Size(1440, 1400);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: CopilotView(
            askEnabled: askEnabled,
            planEnabled: planEnabled,
            settingsStore:
                settingsStore ??
                CopilotSettingsStore(secureStore: _MemorySecureStore()),
            transport: transport,
            conversationBuffer: conversationBuffer,
            selectableResources: selectableResources,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("feature flags control Ask and Plan while Agent stays disabled", (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpCopilot(tester, askEnabled: false, planEnabled: false);

    final selector = tester.widget<AppDropdownField<CopilotMode>>(
      find.byKey(const ValueKey<String>("copilot-mode-selector")),
    );
    final enabledByMode = <CopilotMode, bool>{
      for (final option in selector.options) option.value: option.enabled,
    };

    expect(enabledByMode[CopilotMode.chat], isTrue);
    expect(enabledByMode[CopilotMode.ask], isFalse);
    expect(enabledByMode[CopilotMode.plan], isFalse);
    expect(enabledByMode[CopilotMode.agent], isFalse);
  });

  testWidgets("enabled Ask and Plan update composer policy and hints", (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpCopilot(tester, askEnabled: true, planEnabled: true);

    AppDropdownField<CopilotMode> selector() =>
        tester.widget<AppDropdownField<CopilotMode>>(
          find.byKey(const ValueKey<String>("copilot-mode-selector")),
        );
    AppTextField composer() => tester.widget<AppTextField>(
      find.byKey(const ValueKey<String>("copilot-message-field")),
    );

    expect(
      selector().options
          .firstWhere((item) => item.value == CopilotMode.ask)
          .enabled,
      isTrue,
    );
    expect(
      selector().options
          .firstWhere((item) => item.value == CopilotMode.plan)
          .enabled,
      isTrue,
    );

    selector().onChanged!(CopilotMode.ask);
    await tester.pump();
    expect(find.textContaining("Ask 會把目前章節"), findsOneWidget);
    expect(find.text("Ask 上下文"), findsOneWidget);
    expect(composer().decoration?.hintText, "詢問目前章節內容");
    expect(composer().enabled, isTrue);

    selector().onChanged!(CopilotMode.plan);
    await tester.pump();
    expect(find.textContaining("Plan 會把目前章節"), findsOneWidget);
    expect(find.text("Ask 上下文"), findsNothing);
    expect(composer().decoration?.hintText, "描述希望規劃的修改目標");
    expect(composer().enabled, isTrue);
  });

  testWidgets("privacy disclosure is explicit and API key can be removed", (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final secureStore = _MemorySecureStore()
      ..values[CopilotSettingsStore.secureApiKey] = "stored-secret";
    await pumpCopilot(
      tester,
      askEnabled: true,
      planEnabled: true,
      settingsStore: CopilotSettingsStore(secureStore: secureStore),
    );

    await tester.tap(find.text("隱私、第三方服務與已知限制"));
    await tester.pumpAndSettle();
    expect(find.textContaining("不經 Monogatari Assistant 伺服器"), findsOneWidget);
    expect(find.textContaining("依該服務的條款與帳號設定決定"), findsOneWidget);
    expect(find.textContaining("不會寫入專案"), findsOneWidget);
    expect(find.textContaining("Plan 僅供檢視與匯出"), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>("copilot-clear-api-key")),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>("copilot-clear-api-key")),
    );
    await tester.pumpAndSettle();
    expect(find.text("清除 API Key？"), findsOneWidget);
    expect(
      secureStore.values[CopilotSettingsStore.secureApiKey],
      "stored-secret",
    );

    await tester.tap(find.widgetWithText(FilledButton, "清除 Key"));
    await tester.pumpAndSettle();
    final keyField = tester.widget<AppTextField>(
      find.byKey(const ValueKey<String>("copilot-api-key-field")),
    );
    expect(keyField.controller?.text, isEmpty);
    expect(
      secureStore.values.containsKey(CopilotSettingsStore.secureApiKey),
      isFalse,
    );
    expect(find.text("API Key 已從此裝置移除。"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("API key removal failure is reported without a false success", (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final secureStore = _MemorySecureStore()
      ..values[CopilotSettingsStore.secureApiKey] = "stored-secret"
      ..deleteError = StateError("secure storage unavailable");
    await pumpCopilot(
      tester,
      askEnabled: true,
      planEnabled: true,
      settingsStore: CopilotSettingsStore(secureStore: secureStore),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>("copilot-clear-api-key")),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>("copilot-clear-api-key")),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, "清除 Key"));
    await tester.pumpAndSettle();

    expect(
      secureStore.values[CopilotSettingsStore.secureApiKey],
      "stored-secret",
    );
    expect(find.text("無法從此裝置移除 API Key，請稍後再試。"), findsOneWidget);
    expect(find.text("API Key 已從此裝置移除。"), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("late settings completion after dispose does not call setState", (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final secureStore = _BlockingSecureStore();
    tester.view.physicalSize = const Size(1440, 1400);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: CopilotView(
            settingsStore: CopilotSettingsStore(secureStore: secureStore),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    secureStore.readCompleter.complete(null);
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets("disposing an active HTTP request closes transport safely", (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(<String, Object>{
      CopilotSettingsStore.providerPreferencesKey: "OpenAI",
      CopilotSettingsStore.apiUrlPreferencesKey: "https://provider.example/v1",
      CopilotSettingsStore.modelPreferencesKey: "test-model",
    });
    final client = _BlockingHttpClient();
    final transport = CopilotHttpTransport(
      maxRequestBytes: 256 * 1024,
      clientFactory: () => client,
    );
    await pumpCopilot(
      tester,
      askEnabled: false,
      planEnabled: false,
      transport: transport,
    );

    final messageField = find.descendant(
      of: find.byKey(const ValueKey<String>("copilot-message-field")),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(messageField, "hello");
    await tester.ensureVisible(find.byTooltip("發送"));
    await tester.tap(find.byTooltip("發送"));
    await tester.pump();
    await client.requestStarted.future.timeout(const Duration(seconds: 2));

    expect(find.byTooltip("取消請求"), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();

    expect(client.closed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    "cancel restores the pending prompt and rotates the HTTP client",
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues(<String, Object>{
        CopilotSettingsStore.providerPreferencesKey: "OpenAI",
        CopilotSettingsStore.apiUrlPreferencesKey:
            "https://provider.example/v1",
        CopilotSettingsStore.modelPreferencesKey: "test-model",
      });
      final activeClient = _BlockingHttpClient();
      var clientsCreated = 0;
      final transport = CopilotHttpTransport(
        maxRequestBytes: 256 * 1024,
        clientFactory: () {
          clientsCreated++;
          if (clientsCreated == 1) return activeClient;
          return MockClient((request) async => http.Response("{}", 200));
        },
      );
      await pumpCopilot(
        tester,
        askEnabled: false,
        planEnabled: false,
        transport: transport,
      );

      final composerFinder = find.byKey(
        const ValueKey<String>("copilot-message-field"),
      );
      final messageField = find.descendant(
        of: composerFinder,
        matching: find.byType(TextFormField),
      );
      await tester.enterText(messageField, "restore me");
      await tester.ensureVisible(find.byTooltip("發送"));
      await tester.tap(find.byTooltip("發送"));
      await tester.pump();
      await activeClient.requestStarted.future.timeout(
        const Duration(seconds: 2),
      );

      await tester.tap(find.byTooltip("取消請求"));
      await tester.pump();
      await tester.pump();

      final composer = tester.widget<AppTextField>(composerFinder);
      expect(composer.controller?.text, "restore me");
      expect(find.text("已取消請求。"), findsOneWidget);
      expect(find.text("尚無對話紀錄"), findsOneWidget);
      expect(find.byTooltip("發送"), findsOneWidget);
      expect(activeClient.closed, isTrue);
      expect(clientsCreated, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("provider failure preserves the prompt and retry succeeds", (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(<String, Object>{
      CopilotSettingsStore.providerPreferencesKey: "OpenAI",
      CopilotSettingsStore.apiUrlPreferencesKey: "https://provider.example/v1",
      CopilotSettingsStore.modelPreferencesKey: "test-model",
    });
    var requestCount = 0;
    final transport = CopilotHttpTransport(
      maxRequestBytes: 256 * 1024,
      clientFactory: () => MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          return http.Response(
            '{"error":"secret provider detail","key":"do-not-show"}',
            429,
          );
        }
        return http.Response(
          '{"choices":[{"message":{"content":"recovered answer"}}]}',
          200,
          headers: const <String, String>{"content-type": "application/json"},
        );
      }),
    );
    await pumpCopilot(
      tester,
      askEnabled: false,
      planEnabled: false,
      transport: transport,
    );

    final composerFinder = find.byKey(
      const ValueKey<String>("copilot-message-field"),
    );
    final messageField = find.descendant(
      of: composerFinder,
      matching: find.byType(TextFormField),
    );
    await tester.enterText(messageField, "retry me");
    await tester.ensureVisible(find.byTooltip("發送"));
    await tester.tap(find.byTooltip("發送"));
    await tester.pumpAndSettle();

    AppTextField composer() => tester.widget<AppTextField>(composerFinder);
    expect(composer().controller?.text, "retry me");
    expect(find.text("模型服務目前請求過多或額度不足，請稍後重試。"), findsOneWidget);
    expect(find.textContaining("secret provider detail"), findsNothing);
    expect(find.text("尚無對話紀錄"), findsOneWidget);

    await tester.tap(find.byTooltip("發送"));
    await tester.pumpAndSettle();

    expect(requestCount, 2);
    expect(composer().controller?.text, isEmpty);
    expect(find.text("retry me"), findsOneWidget);
    expect(find.text("recovered answer"), findsOneWidget);
    expect(find.text("模型服務目前請求過多或額度不足，請稍後重試。"), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("changing provider host requires fresh credential consent", (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(<String, Object>{
      CopilotSettingsStore.providerPreferencesKey: "OpenAI",
      CopilotSettingsStore.apiUrlPreferencesKey:
          "https://first-provider.example/v1",
      CopilotSettingsStore.modelPreferencesKey: "test-model",
    });
    final secureStore = _MemorySecureStore()
      ..values[CopilotSettingsStore.secureApiKey] = "test-key";
    final requestedHosts = <String>[];
    final transport = CopilotHttpTransport(
      maxRequestBytes: 256 * 1024,
      clientFactory: () => MockClient((request) async {
        requestedHosts.add(request.url.host);
        return http.Response(
          '{"choices":[{"message":{"content":"ok"}}]}',
          200,
          headers: const <String, String>{"content-type": "application/json"},
        );
      }),
    );
    await pumpCopilot(
      tester,
      askEnabled: false,
      planEnabled: false,
      settingsStore: CopilotSettingsStore(secureStore: secureStore),
      transport: transport,
    );

    final composer = find.descendant(
      of: find.byKey(const ValueKey<String>("copilot-message-field")),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(composer, "first request");
    await tester.ensureVisible(find.byTooltip("發送"));
    await tester.tap(find.byTooltip("發送"));
    await tester.pumpAndSettle();

    expect(find.text("傳送 API Key？"), findsOneWidget);
    expect(
      find.text("API Key 將直接傳送到 https://first-provider.example。請確認這是你信任的模型服務。"),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, "允許本次連線"));
    await tester.pumpAndSettle();
    expect(requestedHosts, <String>["first-provider.example"]);

    final apiUrlField = find.descendant(
      of: find.byKey(const ValueKey<String>("copilot-api-url-field")),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(apiUrlField, "https://second-provider.example/v1");
    await tester.enterText(composer, "second request");
    await tester.ensureVisible(find.byTooltip("發送"));
    await tester.tap(find.byTooltip("發送"));
    await tester.pumpAndSettle();

    expect(find.text("傳送 API Key？"), findsOneWidget);
    expect(
      find.text(
        "API Key 將直接傳送到 https://second-provider.example。請確認這是你信任的模型服務。",
      ),
      findsOneWidget,
    );
    expect(requestedHosts, <String>["first-provider.example"]);
    expect(tester.takeException(), isNull);
  });

  testWidgets("loopback endpoint also requires credential consent", (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(<String, Object>{
      CopilotSettingsStore.providerPreferencesKey: "OpenAI",
      CopilotSettingsStore.apiUrlPreferencesKey: "http://127.0.0.1:11434/v1",
      CopilotSettingsStore.modelPreferencesKey: "test-model",
    });
    final secureStore = _MemorySecureStore()
      ..values[CopilotSettingsStore.secureApiKey] = "local-test-key";
    var requestCount = 0;
    final transport = CopilotHttpTransport(
      maxRequestBytes: 256 * 1024,
      clientFactory: () => MockClient((request) async {
        requestCount++;
        return http.Response(
          '{"choices":[{"message":{"content":"ok"}}]}',
          200,
          headers: const <String, String>{"content-type": "application/json"},
        );
      }),
    );
    await pumpCopilot(
      tester,
      askEnabled: false,
      planEnabled: false,
      settingsStore: CopilotSettingsStore(secureStore: secureStore),
      transport: transport,
    );

    final composer = find.descendant(
      of: find.byKey(const ValueKey<String>("copilot-message-field")),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(composer, "local request");
    await tester.ensureVisible(find.byTooltip("發送"));
    await tester.tap(find.byTooltip("發送"));
    await tester.pumpAndSettle();

    expect(find.text("傳送 API Key？"), findsOneWidget);
    expect(
      find.text("API Key 將直接傳送到 http://127.0.0.1:11434。請確認這是你信任的模型服務。"),
      findsOneWidget,
    );
    expect(requestCount, 0);
    await tester.tap(find.widgetWithText(FilledButton, "允許本次連線"));
    await tester.pumpAndSettle();
    expect(requestCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets("Ask context scopes update privacy summary and resource action", (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpCopilot(tester, askEnabled: true, planEnabled: true);

    final modeSelector = tester.widget<AppDropdownField<CopilotMode>>(
      find.byKey(const ValueKey<String>("copilot-mode-selector")),
    );
    modeSelector.onChanged!(CopilotMode.ask);
    await tester.pump();

    AppDropdownField<CopilotContextScope> scopeSelector() =>
        tester.widget<AppDropdownField<CopilotContextScope>>(
          find.byKey(const ValueKey<String>("copilot-context-scope-selector")),
        );

    expect(find.textContaining("Ask 會把目前章節直接傳送到你設定的模型服務"), findsOneWidget);
    expect(find.textContaining("選擇補充資源"), findsNothing);

    scopeSelector().onChanged!(
      CopilotContextScope.currentChapterWithProjectOverview,
    );
    await tester.pump();
    expect(
      find.textContaining("Ask 會把目前章節與專案索引摘要直接傳送到你設定的模型服務"),
      findsOneWidget,
    );
    expect(find.textContaining("選擇補充資源"), findsNothing);

    scopeSelector().onChanged!(
      CopilotContextScope.currentChapterWithSelectedResources,
    );
    await tester.pump();
    expect(
      find.textContaining("Ask 會把目前章節與勾選的補充資源直接傳送到你設定的模型服務"),
      findsOneWidget,
    );
    expect(find.text("選擇補充資源（0/12）"), findsOneWidget);
    expect(find.text("上下文：尚未選擇章節"), findsOneWidget);
  });

  testWidgets("Plan cards remain read-only and invalid replies stay raw", (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final context = CopilotContextSnapshot.currentChapter(
      chapterId: "chapter-1",
      title: "第一章",
      content: "original chapter",
    );
    final planSource = <String, Object?>{
      "schemaVersion": "1",
      "goal": "檢查伏筆",
      "summary": "唯讀檢查計畫",
      "contextFingerprint": context.fingerprint,
      "steps": <Object?>[
        <String, Object?>{
          "id": "step-1",
          "order": 1,
          "targetType": "chapter",
          "targetId": "chapter-1",
          "action": "review",
          "reason": "確認線索是否足夠",
          "proposal": "檢查開場對話",
          "dependsOn": <String>[],
        },
      ],
      "risks": <String>["可能過早揭露"],
      "questions": <String>["是否保留模糊性？"],
    };
    final plan = CopilotPlan.parse(jsonEncode(planSource), context: context);
    final buffer =
        CopilotConversationBuffer(
            maxUiMessages: 200,
            maxUiHistoryBytes: 1024 * 1024,
            maxContextMessages: 24,
            maxContextBytes: 128 * 1024,
          )
          ..add(
            CopilotConversationMessage(
              role: CopilotConversationRole.assistant,
              content: plan.summary,
              modelContent: jsonEncode(planSource),
              createdAt: DateTime.utc(2026),
              mode: CopilotMode.plan,
              contextSnapshot: context,
              plan: plan,
            ),
          )
          ..add(
            CopilotConversationMessage(
              role: CopilotConversationRole.assistant,
              content: "raw invalid plan response",
              modelContent: "raw invalid plan response",
              createdAt: DateTime.utc(2026),
              mode: CopilotMode.plan,
              contextSnapshot: context,
              planValidationError: "Plan schemaVersion 不受支援。",
            ),
          );

    await pumpCopilot(
      tester,
      askEnabled: true,
      planEnabled: true,
      conversationBuffer: buffer,
    );

    expect(find.text("檢查伏筆"), findsOneWidget);
    expect(find.textContaining("1. 檢查開場對話"), findsOneWidget);
    expect(find.text("風險：可能過早揭露"), findsOneWidget);
    expect(find.text("待確認：是否保留模糊性？"), findsOneWidget);
    expect(find.text("唯讀計畫・尚未套用任何變更"), findsOneWidget);
    expect(find.text("目前章節已變更，這份計畫可能已過期。"), findsOneWidget);
    expect(find.byTooltip("複製 Plan JSON"), findsOneWidget);
    expect(find.byTooltip("匯出 Plan JSON"), findsOneWidget);
    expect(find.text("raw invalid plan response"), findsOneWidget);
    expect(
      find.textContaining("無法驗證 Plan：Plan schemaVersion 不受支援。"),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, "套用"), findsNothing);
  });

  testWidgets("Ask citation chips navigate only to supported resources", (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final context = CopilotContextSnapshot.currentChapter(
      chapterId: "chapter-1",
      title: "第一章",
      content: "chapter evidence",
      supplementalResources: const <CopilotContextResource>[
        CopilotContextResource(
          resourceType: "character",
          resourceId: "character-1",
          title: "角色甲",
          content: "character evidence",
          truncated: false,
        ),
        CopilotContextResource(
          resourceType: "project",
          resourceId: "project-overview",
          title: "專案摘要",
          content: "project evidence",
          truncated: false,
        ),
      ],
    );
    final response = CopilotAskResponse.parse(
      jsonEncode(<String, Object?>{
        "answer": "有三個來源。",
        "citations": <Object?>[
          <String, Object?>{
            "resourceId": "chapter-1",
            "quoteHint": "chapter evidence",
          },
          <String, Object?>{
            "resourceId": "character-1",
            "quoteHint": "character evidence",
          },
          <String, Object?>{
            "resourceId": "project-overview",
            "quoteHint": "project evidence",
          },
          <String, Object?>{
            "resourceId": "not-supplied",
            "quoteHint": "invalid",
          },
        ],
        "uncertainties": <String>["時間點不明"],
      }),
      context: context,
    );
    final buffer =
        CopilotConversationBuffer(
          maxUiMessages: 200,
          maxUiHistoryBytes: 1024 * 1024,
          maxContextMessages: 24,
          maxContextBytes: 128 * 1024,
        )..add(
          CopilotConversationMessage(
            role: CopilotConversationRole.assistant,
            content: response.answer,
            createdAt: DateTime.utc(2026),
            mode: CopilotMode.ask,
            contextSnapshot: context,
            askResponse: response,
          ),
        );
    String? openedChapter;
    (String, String)? openedResource;

    tester.view.physicalSize = const Size(1440, 1400);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: CopilotView(
            askEnabled: true,
            planEnabled: true,
            settingsStore: CopilotSettingsStore(
              secureStore: _MemorySecureStore(),
            ),
            conversationBuffer: buffer,
            onOpenChapter: (id) => openedChapter = id,
            onOpenResource: (type, id) => openedResource = (type, id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ActionChip, "第一章"));
    await tester.tap(find.widgetWithText(ActionChip, "角色甲"));
    expect(openedChapter, "chapter-1");
    expect(openedResource, ("character", "character-1"));
    expect(find.widgetWithText(ActionChip, "專案摘要"), findsNothing);
    expect(find.widgetWithText(Chip, "專案摘要"), findsOneWidget);
    expect(find.text("不確定：時間點不明"), findsOneWidget);
    expect(find.text("已忽略模型提供的無效來源。"), findsOneWidget);
  });

  testWidgets("resource picker searches and enforces the twelve item limit", (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final resources = List<CopilotSelectableResource>.generate(
      13,
      (index) => CopilotSelectableResource(
        resourceType: "character",
        resourceId: "character-$index",
        title: "Unique character ${index.toString().padLeft(2, "0")}",
        description: "角色・測試 $index",
        contentBuilder: () => "content-$index",
      ),
      growable: false,
    );
    await pumpCopilot(
      tester,
      askEnabled: true,
      planEnabled: true,
      selectableResources: resources,
    );
    final modeSelector = tester.widget<AppDropdownField<CopilotMode>>(
      find.byKey(const ValueKey<String>("copilot-mode-selector")),
    );
    modeSelector.onChanged!(CopilotMode.ask);
    await tester.pump();
    final scopeSelector = tester.widget<AppDropdownField<CopilotContextScope>>(
      find.byKey(const ValueKey<String>("copilot-context-scope-selector")),
    );
    scopeSelector.onChanged!(
      CopilotContextScope.currentChapterWithSelectedResources,
    );
    await tester.pump();
    await tester.tap(find.text("選擇補充資源（0/12）"));
    await tester.pumpAndSettle();

    final searchField = find.byKey(
      const ValueKey<String>("copilot-resource-search-field"),
    );
    await tester.enterText(searchField, "does-not-exist");
    await tester.pump();
    expect(find.text("沒有符合的資源。"), findsOneWidget);

    for (var index = 0; index < 12; index++) {
      final title = "Unique character ${index.toString().padLeft(2, "0")}";
      await tester.enterText(searchField, title);
      await tester.pump();
      final tileFinder = find.byKey(
        ValueKey<String>("copilot-resource-character:character-$index"),
      );
      final tile = tester.widget<CheckboxListTile>(tileFinder);
      expect(tile.onChanged, isNotNull);
      tile.onChanged!(true);
      await tester.pump();
    }

    expect(find.text("已選 12/12；只會傳送勾選項目的內容。"), findsOneWidget);
    await tester.enterText(searchField, "Unique character 12");
    await tester.pump();
    final thirteenth = tester.widget<CheckboxListTile>(
      find.byKey(
        const ValueKey<String>("copilot-resource-character:character-12"),
      ),
    );
    expect(thirteenth.value, isFalse);
    expect(thirteenth.onChanged, isNull);

    await tester.tap(find.text("使用選取項目"));
    await tester.pumpAndSettle();
    expect(find.text("選擇補充資源（12/12）"), findsOneWidget);

    await pumpCopilot(
      tester,
      askEnabled: true,
      planEnabled: true,
      selectableResources: resources.sublist(1),
    );
    await tester.tap(find.text("選擇補充資源（12/12）"));
    await tester.pumpAndSettle();
    expect(find.text("已選 11/12；只會傳送勾選項目的內容。"), findsOneWidget);
    await tester.tap(find.text("使用選取項目"));
    await tester.pumpAndSettle();
    expect(find.text("選擇補充資源（11/12）"), findsOneWidget);
  });
}
