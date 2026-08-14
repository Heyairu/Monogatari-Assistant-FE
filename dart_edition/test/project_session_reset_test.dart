import "package:flutter/material.dart";
import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:monogatari_assistant/main.dart";
import "package:monogatari_assistant/domain/models/p2p_sync_models.dart";
import "package:monogatari_assistant/presentation/providers/p2p_sync_providers.dart";

class _LifecycleP2pSyncNotifier extends P2pSyncNotifier {
  @override
  P2pSyncState build() => const P2pSyncState();

  @override
  Future<void> initialize() async {
    state = state.copyWith(message: "initialized");
  }

  @override
  void updateLocalProjectStatus(P2pProjectStatus? status) {
    state = state.copyWith(
      localProjectOffer: P2pProjectOffer.fromStatus(status),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("ContentView defers initial P2P writes until after build", (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.binding.setSurfaceSize(const Size(2400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [
          p2pSyncProvider.overrideWith(_LifecycleP2pSyncNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ContentView()),
        ),
      );
      expect(
        tester.takeException(),
        isNull,
        reason: "P2P provider writes must not run during ContentView build.",
      );
      expect(container.read(p2pSyncProvider).message, "initialized");

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: "P2P resume recovery must also run after the widget frame.",
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets("new project remounts project pages with a fresh session", (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.binding.setSurfaceSize(const Size(2400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ContentView())),
    );
    expect(
      tester.takeException(),
      isNull,
      reason: "ContentView 啟動期間不可在 widget build 中修改 provider。",
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.byKey(const ValueKey("project-0-page-4"), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey("project-0-page-7"), skipOffstage: false),
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
      find.byKey(const ValueKey("project-0-page-7"), skipOffstage: false),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey("project-1-page-4"), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey("project-1-page-7"), skipOffstage: false),
      findsOneWidget,
    );
  });
}
