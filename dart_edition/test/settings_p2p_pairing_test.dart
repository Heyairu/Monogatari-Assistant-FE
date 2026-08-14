import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/data/repositories/settings_repository.dart";
import "package:shared_preferences/shared_preferences.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("single-device pairing confirmation defaults on and persists", () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repository = SharedPreferencesSettingsRepository();

    expect(
      (await repository.load()).allowSingleDevicePairingConfirmation,
      isTrue,
    );

    await repository.saveAllowSingleDevicePairingConfirmation(false);

    expect(
      (await repository.load()).allowSingleDevicePairingConfirmation,
      isFalse,
    );
  });

  test("persistent P2P verification defaults off and persists", () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repository = SharedPreferencesSettingsRepository();

    expect((await repository.load()).allowPersistentP2pVerification, isFalse);

    await repository.saveAllowPersistentP2pVerification(true);

    expect((await repository.load()).allowPersistentP2pVerification, isTrue);
  });
}
