import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/main.dart";
import "package:shared_preferences/shared_preferences.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("desktop resize freezes layout until metrics settle", (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await tester.binding.setSurfaceSize(const Size(3600, 1200));
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ContentView())),
    );
    await tester.pump();

    final stableContent = find.byKey(const Key("window-resize-stable-content"));
    expect(stableContent, findsOneWidget);
    final initialLayoutSize = tester.getSize(stableContent);

    for (var frame = 1; frame <= 20; frame++) {
      await tester.binding.setSurfaceSize(
        Size(3600 - (frame * 20), 1200 - (frame * 10)),
      );
      tester.binding.handleMetricsChanged();
      await tester.pump();

      expect(
        tester.getSize(stableContent),
        initialLayoutSize,
        reason: "intermediate resize frames must reuse fixed constraints",
      );
    }

    await tester.pump(const Duration(milliseconds: 170));
    expect(tester.getSize(stableContent), isNot(initialLayoutSize));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });
}
