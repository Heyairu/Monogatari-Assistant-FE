import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:monogatari_assistant/main.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("new project remounts project pages with a fresh session", (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.binding.setSurfaceSize(const Size(2400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ContentView())),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.byKey(const ValueKey("project-0-page-4"), skipOffstage: false),
      findsOneWidget,
    );

    final actionContext = tester.element(find.byTooltip("檔案"));
    final result = Actions.invoke(actionContext, const NewFileIntent());
    if (result is Future<void>) {
      await result;
    }
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.byKey(const ValueKey("project-0-page-4"), skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey("project-1-page-4"), skipOffstage: false),
      findsOneWidget,
    );
  });
}
