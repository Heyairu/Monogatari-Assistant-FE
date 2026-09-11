import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/modules/settingview.dart";
import "package:monogatari_assistant/presentation/providers/global_state_providers.dart";
import "package:shared_preferences/shared_preferences.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("settings page persists the Poppin IntelliSense switch", (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(settingsStateProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingView()),
      ),
    );
    await tester.pump();

    final setting = find.byKey(const Key("poppin-enabled-setting"));
    expect(setting, findsOneWidget);
    await tester.ensureVisible(setting);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester
          .widget<Switch>(
            find.descendant(of: setting, matching: find.byType(Switch)),
          )
          .value,
      isTrue,
    );

    await tester.tap(
      find.descendant(of: setting, matching: find.byType(Switch)),
    );
    await tester.pump();

    expect(
      container.read(settingsStateProvider).valueOrNull?.poppinEnabled,
      isFalse,
    );
    expect(
      (await SharedPreferences.getInstance()).getBool("poppin_enabled"),
      isFalse,
    );
  });
}
