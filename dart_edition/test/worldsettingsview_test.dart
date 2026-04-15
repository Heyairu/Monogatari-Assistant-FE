import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monogatari_assistant/modules/worldsettingsview.dart';
import 'package:monogatari_assistant/presentation/providers/project_state_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('WorldSettingsView renders from provider state', (tester) async {
    final container = ProviderContainer();

    container.read(worldSettingsDataProvider.notifier).state = [
      LocationData(localName: '', localType: '', note: ''),
    ];

    await tester.pumpWidget(
      ProviderScope(
        parent: container,
        child: MaterialApp(
          home: Scaffold(
            body: WorldSettingsView(onChanged: (_) {}),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('世界設定'), findsOneWidget);
    expect(find.text('世界結構'), findsOneWidget);

    expect(
      container.read(worldSettingsDataProvider).first.localName,
      '',
    );
  });
}
