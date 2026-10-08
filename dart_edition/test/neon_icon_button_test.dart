import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/ui_library.dart";

void main() {
  testWidgets("toggle supports keyboard activation and descriptive tooltip", (
    tester,
  ) async {
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => NeonIconButton(
              icon: Icons.sync,
              label: "跟隨主時間軸",
              selected: selected,
              onPressed: () => setState(() => selected = !selected),
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selected, isTrue);
    expect(find.byTooltip("跟隨主時間軸，已啟用"), findsOneWidget);
    expect(
      tester.getSize(find.byType(IconButton)).width,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets(
    "disabled and busy actions cannot run; reduced motion stays static",
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                disableAnimations: true,
                highContrast: true,
              ),
              child: Column(
                children: [
                  const NeonIconButton(
                    icon: Icons.sync,
                    label: "無法切換",
                    selected: true,
                    onPressed: null,
                  ),
                  NeonIconButton(
                    icon: Icons.copy,
                    label: "複製",
                    busy: true,
                    onPressed: () => calls++,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      for (final button in find.byType(IconButton).evaluate()) {
        await tester.tap(find.byWidget(button.widget));
      }
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.byTooltip("複製，處理中"), findsOneWidget);
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("desktop toolbar stays flat across selection and hover", (
    tester,
  ) async {
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: Brightness.dark,
          platform: TargetPlatform.windows,
        ),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => NeonIconButton(
              icon: Icons.filter_list,
              label: "篩選",
              selected: selected,
              selectedAccent: NeonAccent.teal,
              onPressed: () => setState(() => selected = !selected),
            ),
          ),
        ),
      ),
    );
    final button = find.byType(NeonIconButton);
    final icon = find.descendant(of: button, matching: find.byType(Icon));
    expect(tester.getSize(find.byType(IconButton)), const Size.square(40));
    expect(tester.widget<Icon>(icon).size, 24);
    expect(tester.widget<Icon>(icon).color, const Color(0xFFE1E2E8));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(tester.widget<Icon>(icon).color, const Color(0xFF26A69A));
    expect(find.byTooltip("篩選，已啟用"), findsOneWidget);
    final style = tester.widget<IconButton>(find.byType(IconButton)).style!;
    expect(
      style.backgroundColor!.resolve({WidgetState.selected}),
      Colors.transparent,
    );
    expect(
      style.overlayColor!.resolve({WidgetState.hovered}),
      const Color(0xFF292C2F),
    );
    expect(style.overlayColor!.resolve({}), Colors.transparent);
    expect(style.side!.resolve({WidgetState.hovered}), BorderSide.none);
    expect(style.side!.resolve({WidgetState.focused})!.width, 2);
    expect(
      find.descendant(of: button, matching: find.byType(Stack)),
      findsNothing,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(tester.widget<Icon>(icon).color, const Color(0xFFE1E2E8));
    expect(tester.getSize(find.byType(IconButton)), const Size.square(40));
  });

  testWidgets(
    "warning and disabled colors preserve toggle and reason semantics",
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: Row(
              children: [
                NeonIconButton(
                  key: const ValueKey("warning-toggle"),
                  icon: Icons.filter_list,
                  label: "篩選",
                  selected: true,
                  status: NeonStatus.warning,
                  onPressed: () {},
                ),
                const NeonIconButton(
                  key: ValueKey("disabled-delete"),
                  icon: Icons.delete_outline,
                  label: "刪除快照",
                  selected: true,
                  status: NeonStatus.error,
                  destructive: true,
                  statusLabel: "尚未選取快照",
                  onPressed: null,
                ),
                NeonIconButton(
                  key: const ValueKey("add-action"),
                  icon: Icons.add,
                  label: "新增",
                  accent: NeonAccent.green,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );
      Color? foreground(String key) => tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(Icon),
            ),
          )
          .color;
      expect(foreground("warning-toggle"), const Color(0xFFFF9F43));
      expect(foreground("disabled-delete"), const Color(0xFF65676C));
      expect(foreground("add-action"), const Color(0xFF4CAF50));
      expect(find.byTooltip("篩選，已啟用，異常需要處理"), findsOneWidget);
      expect(find.byTooltip("刪除快照，已啟用，尚未選取快照"), findsOneWidget);
      final warningButton = tester.widget<IconButton>(
        find.descendant(
          of: find.byKey(const ValueKey("warning-toggle")),
          matching: find.byType(IconButton),
        ),
      );
      expect(warningButton.isSelected, isTrue);
      expect(
        tester.getSize(find.byType(IconButton).first),
        const Size.square(48),
      );
    },
  );

  testWidgets("text menu displays current choice and applies a selection", (
    tester,
  ) async {
    var value = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AppMenuButton<bool>(
              value: value,
              labelText: "Scene 顯示範圍",
              options: const [
                DropdownOption(value: false, label: "相關 Scene"),
                DropdownOption(value: true, label: "完整 Scene"),
              ],
              onChanged: (next) => setState(() => value = next!),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, "完整 Scene"));
    await tester.pumpAndSettle();
    expect(value, isTrue);
    expect(find.widgetWithText(TextButton, "完整 Scene"), findsOneWidget);
    expect(find.byType(MenuItemButton), findsNothing);
  });
}
