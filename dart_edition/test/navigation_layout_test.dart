import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/slidebar.dart";
import "package:monogatari_assistant/data/repositories/settings_repository.dart";
import "package:monogatari_assistant/models/navigation_style.dart";
import "package:monogatari_assistant/modules/settingview.dart";
import "package:monogatari_assistant/presentation/providers/global_state_providers.dart";
import "package:shared_preferences/shared_preferences.dart";

Finder destination(int index) =>
    find.byKey(ValueKey("navigation-destination-$index"));
final toggle = find.byKey(const Key("navigation-toggle"));
final scrollArea = find.byKey(const Key("navigation-scroll-area"));
final surface = find.byKey(const Key("navigation-surface"));

bool isDrawerStyle(NavigationStyle style) =>
    style == NavigationStyle.railButtonDrawer ||
    style == NavigationStyle.railHoverDrawer;

Future<void> mountNavigation(
  WidgetTester tester, {
  NavigationStyle style = NavigationStyle.railLabel,
  bool modal = false,
  ValueChanged<int>? onSelected,
  Widget child = const SizedBox.expand(key: Key("content")),
  double height = 500,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: SizedBox(
            height: height,
            child: MonogatariNavigationLayout(
              style: style,
              modal: modal,
              selectedIndex: 0,
              onDestinationSelected: onSelected ?? (_) {},
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final style in NavigationStyle.values) {
    testWidgets("${style.name}: home and footer stay fixed while scrolling", (
      tester,
    ) async {
      await mountNavigation(tester, style: style);
      final fixed = [
        destination(0),
        if (isDrawerStyle(style)) toggle,
        destination(14),
        destination(15),
      ];
      expect(toggle, isDrawerStyle(style) ? findsOneWidget : findsNothing);
      final positions = fixed.map(tester.getTopLeft).toList();
      for (final item in fixed) {
        expect(find.descendant(of: scrollArea, matching: item), findsNothing);
      }
      expect(
        find.descendant(of: scrollArea, matching: destination(1)),
        findsOneWidget,
      );
      await tester.drag(scrollArea, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(fixed.map(tester.getTopLeft).toList(), positions);

      final scroll = tester
          .widget<SingleChildScrollView>(scrollArea)
          .controller!;
      final offset = scroll.offset;
      expect(offset, greaterThan(0));
      if (!isDrawerStyle(style)) {
        expect(tester.takeException(), isNull);
        return;
      }
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.getSize(surface).width, 256);
      expect(scroll.offset, offset);
      final drawerPositions = fixed.map(tester.getTopLeft).toList();
      await tester.drag(scrollArea, const Offset(0, 150));
      await tester.pumpAndSettle();
      expect(fixed.map(tester.getTopLeft).toList(), drawerPositions);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    "manual drawer pushes content aside while mode changes retain editor state",
    (tester) async {
      var style = NavigationStyle.railButtonDrawer;
      late StateSetter update;
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return MonogatariNavigationLayout(
                  style: style,
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                  child: SizedBox.expand(
                    key: const Key("content"),
                    child: TextField(controller: controller),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), "尚未儲存的正文");
      final size = tester.getSize(find.byKey(const Key("content")));
      final editorElement = tester.element(find.byType(TextField));
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const Key("content"))).width,
        size.width - 199,
      );
      expect(tester.getTopLeft(find.byKey(const Key("content"))).dx, 256);
      expect(find.byKey(const Key("navigation-dismiss-area")), findsNothing);
      await tester.enterText(find.byType(TextField), "展開導覽後仍可編輯");
      update(() => style = NavigationStyle.railTooltip);
      await tester.pumpAndSettle();
      expect(tester.getSize(surface).width, 57);
      expect(tester.getSize(find.byKey(const Key("content"))), size);
      expect(tester.element(find.byType(TextField)), same(editorElement));
      expect(controller.text, "展開導覽後仍可編輯");
    },
  );

  testWidgets(
    "pinned drawer keeps page indexes and stays open after selection",
    (tester) async {
      final selected = <int>[];
      await mountNavigation(
        tester,
        style: NavigationStyle.railButtonDrawer,
        onSelected: selected.add,
      );
      for (final index in [14, 15, 0]) {
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        await tester.tap(destination(index));
        await tester.pumpAndSettle();
        expect(tester.getSize(surface).width, 256);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(tester.getSize(surface).width, 57);
      }
      expect(selected, [14, 15, 0]);
    },
  );

  testWidgets("hover delays expansion and collapse, with a button to pin it", (
    tester,
  ) async {
    await mountNavigation(tester, style: NavigationStyle.railHoverDrawer);
    final content = find.byKey(const Key("content"));
    final contentSize = tester.getSize(content);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(500, 100));
    await mouse.moveTo(const Offset(40, 100));
    await tester.pump(const Duration(milliseconds: 249));
    expect(find.byKey(const Key("navigation-dismiss-area")), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(tester.getSize(surface).width, 256);
    expect(tester.getSize(content), contentSize);
    expect(tester.getTopLeft(content).dx, 57);
    await mouse.moveTo(const Offset(180, 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getSize(surface).width, 256);
    await mouse.moveTo(const Offset(500, 100));
    await tester.pump(const Duration(milliseconds: 349));
    expect(find.byKey(const Key("navigation-dismiss-area")), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(tester.getSize(surface).width, 57);

    await mouse.moveTo(const Offset(40, 100));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(content).dx, 256);
    expect(tester.getSize(content).width, contentSize.width - 199);
    expect(find.byKey(const Key("navigation-dismiss-area")), findsNothing);
    await mouse.moveTo(const Offset(500, 100));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.getSize(surface).width, 256);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.getSize(surface).width, 57);
    expect(tester.getSize(content), contentSize);
    await mouse.removePointer();
  });

  testWidgets("Escape closes hover preview while editor has focus", (
    tester,
  ) async {
    await mountNavigation(
      tester,
      style: NavigationStyle.railHoverDrawer,
      child: const TextField(),
    );
    await tester.tap(find.byType(TextField));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(500, 100));
    await mouse.moveTo(const Offset(40, 100));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(tester.getSize(surface).width, 256);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(tester.getSize(surface).width, 57);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.getSize(surface).width, 57);
    await mouse.moveTo(const Offset(500, 100));
    await mouse.moveTo(const Offset(40, 100));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(tester.getSize(surface).width, 256);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    "unfixed hover drawer collapses on exit even when a button has focus",
    (tester) async {
      await mountNavigation(tester, style: NavigationStyle.railHoverDrawer);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(40, 100));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      final ink = tester.widget<InkWell>(
        find.descendant(of: toggle, matching: find.byType(InkWell)),
      );
      ink.focusNode!.requestFocus();
      await tester.pump();
      await mouse.moveTo(const Offset(500, 100));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(tester.getSize(surface).width, 57);
      expect(ink.focusNode!.hasFocus, isTrue);
      await mouse.removePointer();
    },
  );

  testWidgets(
    "icon-only navigation shows tooltip on hover and keyboard focus",
    (tester) async {
      await mountNavigation(tester, style: NavigationStyle.railTooltip);
      expect(find.text("首頁"), findsNothing);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(destination(0)));
      await tester.pump(const Duration(milliseconds: 550));
      await tester.pumpAndSettle();
      expect(find.text("首頁"), findsOneWidget);
      await mouse.removePointer();
      await tester.pumpAndSettle();
      expect(toggle, findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(find.text("首頁"), findsOneWidget);
    },
  );

  testWidgets("modal drawer has fixed sections and restores launcher focus", (
    tester,
  ) async {
    var selected = -1;
    await mountNavigation(
      tester,
      modal: true,
      onSelected: (index) => selected = index,
    );
    expect(surface, findsNothing);
    final launcher = find.byKey(const Key("navigation-launcher"));
    await tester.tap(launcher);
    await tester.pumpAndSettle();
    for (final index in [0, 14, 15]) {
      expect(
        find.descendant(of: scrollArea, matching: destination(index)),
        findsNothing,
      );
    }
    await tester.tap(destination(14));
    await tester.pumpAndSettle();
    expect(selected, 14);
    expect(surface, findsNothing);
    expect(tester.widget<IconButton>(launcher).focusNode!.hasFocus, isTrue);
    await tester.tap(launcher);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(600, 100));
    await tester.pumpAndSettle();
    expect(surface, findsNothing);
  });

  testWidgets("short windows and enlarged labels do not overflow", (
    tester,
  ) async {
    for (final style in NavigationStyle.values) {
      for (final dimensions in [(320.0, 2.0), (400.0, 3.0)]) {
        await mountNavigation(
          tester,
          style: style,
          height: dimensions.$1,
          textScaler: TextScaler.linear(dimensions.$2),
        );
        expect(tester.takeException(), isNull);
        if (isDrawerStyle(style)) {
          await tester.tap(toggle);
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });

  testWidgets("non-label modes use smaller buttons and narrower rails", (
    tester,
  ) async {
    await mountNavigation(tester);
    final labelSize = tester.getSize(destination(0));
    final labelIcon = tester
        .widget<Icon>(
          find.descendant(of: destination(0), matching: find.byType(Icon)),
        )
        .size!;
    expect(tester.getSize(surface).width, 81);
    for (final style in NavigationStyle.values.where(
      (style) => style != NavigationStyle.railLabel,
    )) {
      await mountNavigation(tester, style: style);
      await tester.pumpAndSettle();
      expect(tester.getSize(destination(0)).height, 40);
      expect(tester.getSize(destination(0)).height, lessThan(labelSize.height));
      expect(tester.getSize(surface).width, 57);
      expect(
        tester
            .widget<Icon>(
              find.descendant(of: destination(0), matching: find.byType(Icon)),
            )
            .size,
        lessThan(labelIcon),
      );
      if (isDrawerStyle(style)) {
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(tester.getSize(destination(0)).height, 40);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  test(
    "navigation preference defaults safely and survives a fresh provider",
    () async {
      for (final invalid in [null, "removedStyle"]) {
        SharedPreferences.setMockInitialValues({
          if (invalid != null) "navigation_style": invalid,
        });
        expect(
          (await SharedPreferencesSettingsRepository().load()).navigationStyle,
          NavigationStyle.railLabel,
        );
      }
      for (final style in NavigationStyle.values) {
        final container = ProviderContainer();
        await container.read(settingsStateProvider.future);
        await container
            .read(settingsStateProvider.notifier)
            .setNavigationStyle(style);
        container.dispose();
        final reloaded = ProviderContainer();
        expect(
          (await reloaded.read(settingsStateProvider.future)).navigationStyle,
          style,
        );
        reloaded.dispose();
      }
    },
  );

  testWidgets("appearance setting switches and saves the navigation style", (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
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
    final setting = find.byKey(const Key("navigation-style-setting"));
    await tester.ensureVisible(setting);
    final dropdown = find.descendant(
      of: setting,
      matching: find.byType(DropdownButtonFormField<NavigationStyle>),
    );
    await tester.tap(dropdown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(NavigationStyle.railTooltip.label).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      container.read(settingsStateProvider).valueOrNull?.navigationStyle,
      NavigationStyle.railTooltip,
    );
    expect(
      (await SharedPreferences.getInstance()).getString("navigation_style"),
      "railTooltip",
    );
  });
}
