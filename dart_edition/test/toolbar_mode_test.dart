import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/data/repositories/settings_repository.dart";
import "package:monogatari_assistant/models/toolbar_mode.dart";
import "package:monogatari_assistant/presentation/providers/global_state_providers.dart";
import "package:shared_preferences/shared_preferences.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("platform defaults select Full for desktop and Moderate for mobile", () {
    for (final platform in [
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
      TargetPlatform.fuchsia,
    ]) {
      expect(ToolbarMode.defaultFor(platform), ToolbarMode.full);
    }
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      expect(ToolbarMode.defaultFor(platform), ToolbarMode.moderate);
    }
  });

  test("mode overrides persist, reload, and reset to automatic", () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repository = SharedPreferencesSettingsRepository();
    expect((await repository.load()).toolbarMode, isNull);
    for (final mode in ToolbarMode.values) {
      final container = ProviderContainer();
      await container.read(toolbarModeProvider.future);
      await container.read(toolbarModeProvider.notifier).setMode(mode);
      expect(container.read(toolbarModeProvider).valueOrNull, mode);
      container.dispose();
      expect((await repository.load()).toolbarMode, mode);
    }
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(toolbarModeProvider.future);
    expect(
      container.read(toolbarModeProvider).valueOrNull,
      ToolbarMode.concise,
    );
    await container.read(toolbarModeProvider.notifier).setMode(null);
    expect(container.read(toolbarModeProvider).valueOrNull, isNull);
    expect((await repository.load()).toolbarMode, isNull);
  });

  test("unknown preferences restore automatic mode", () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      "toolbar_mode": "future-mode",
    });
    expect(
      (await SharedPreferencesSettingsRepository().load()).toolbarMode,
      isNull,
    );
  });
}
