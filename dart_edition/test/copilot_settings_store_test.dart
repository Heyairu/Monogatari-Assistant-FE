import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/copilot/data/copilot_settings_store.dart";
import "package:shared_preferences/shared_preferences.dart";

final class _MemorySecureStore implements CopilotSecureKeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("migrates a legacy API key into secure storage", () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      CopilotSettingsStore.providerPreferencesKey: "OpenAI",
      CopilotSettingsStore.legacyApiKeyPreferencesKey: "legacy-secret",
    });
    final secureStore = _MemorySecureStore();
    final store = CopilotSettingsStore(secureStore: secureStore);

    final settings = await store.load();
    final preferences = await SharedPreferences.getInstance();

    expect(settings.apiKey, "legacy-secret");
    expect(
      secureStore.values[CopilotSettingsStore.secureApiKey],
      "legacy-secret",
    );
    expect(
      preferences.containsKey(CopilotSettingsStore.legacyApiKeyPreferencesKey),
      isFalse,
    );
  });

  test("saves non-sensitive settings separately from the API key", () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final secureStore = _MemorySecureStore();
    final store = CopilotSettingsStore(secureStore: secureStore);

    await store.save(
      provider: "OpenAI",
      apiUrl: "https://api.openai.com/v1",
      model: "model",
      apiKey: "secret",
    );
    final preferences = await SharedPreferences.getInstance();

    expect(
      preferences.getString(CopilotSettingsStore.providerPreferencesKey),
      "OpenAI",
    );
    expect(
      preferences.containsKey(CopilotSettingsStore.legacyApiKeyPreferencesKey),
      isFalse,
    );
    expect(secureStore.values[CopilotSettingsStore.secureApiKey], "secret");
  });
}
