import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:shared_preferences/shared_preferences.dart";

abstract interface class CopilotSecureKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

final class FlutterCopilotSecureKeyValueStore
    implements CopilotSecureKeyValueStore {
  final FlutterSecureStorage _storage;

  const FlutterCopilotSecureKeyValueStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

final class CopilotStoredSettings {
  final String? provider;
  final String? apiUrl;
  final String? model;
  final String apiKey;

  const CopilotStoredSettings({
    required this.provider,
    required this.apiUrl,
    required this.model,
    required this.apiKey,
  });
}

final class CopilotSettingsStore {
  static const String providerPreferencesKey = "copilot_provider";
  static const String apiUrlPreferencesKey = "copilot_api_url";
  static const String modelPreferencesKey = "copilot_model";
  static const String legacyApiKeyPreferencesKey = "copilot_api_key";
  static const String secureApiKey = "copilot.api_key.v1";

  final CopilotSecureKeyValueStore _secureStore;

  const CopilotSettingsStore({
    CopilotSecureKeyValueStore secureStore =
        const FlutterCopilotSecureKeyValueStore(),
  }) : _secureStore = secureStore;

  Future<CopilotStoredSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    var apiKey = await _secureStore.read(secureApiKey);
    final legacyApiKey = preferences.getString(legacyApiKeyPreferencesKey);
    if (apiKey == null && legacyApiKey != null && legacyApiKey.isNotEmpty) {
      await _secureStore.write(secureApiKey, legacyApiKey);
      final verified = await _secureStore.read(secureApiKey);
      if (verified != legacyApiKey) {
        throw StateError("Copilot API key 無法安全遷移。");
      }
      apiKey = verified;
    }
    if (apiKey != null || legacyApiKey?.isEmpty == true) {
      await preferences.remove(legacyApiKeyPreferencesKey);
    }
    return CopilotStoredSettings(
      provider: preferences.getString(providerPreferencesKey),
      apiUrl: preferences.getString(apiUrlPreferencesKey),
      model: preferences.getString(modelPreferencesKey),
      apiKey: apiKey ?? "",
    );
  }

  Future<void> save({
    required String provider,
    required String apiUrl,
    required String model,
    required String apiKey,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait(<Future<bool>>[
      preferences.setString(providerPreferencesKey, provider),
      preferences.setString(apiUrlPreferencesKey, apiUrl),
      preferences.setString(modelPreferencesKey, model),
    ]);
    if (apiKey.isEmpty) {
      await _secureStore.delete(secureApiKey);
    } else {
      await _secureStore.write(secureApiKey, apiKey);
    }
    await preferences.remove(legacyApiKeyPreferencesKey);
  }
}
