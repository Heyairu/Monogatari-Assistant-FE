import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/ui_library.dart";

void main() {
  test("raw input fallback uses the same surface as shared fields", () {
    for (final theme in [
      AppTheme.getLightTheme(14, Colors.green),
      AppTheme.getDarkTheme(14, Colors.green),
    ]) {
      expect(
        theme.inputDecorationTheme.fillColor,
        theme.colorScheme.surfaceContainerLowest,
      );
    }
  });

  testWidgets("mixed controls share their visible height at each font size", (
    tester,
  ) async {
    for (final fontSize in [14.0, 16.0, 20.0]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getDarkTheme(fontSize, Colors.green),
          home: Scaffold(
            body: Column(
              children: [
                const AppControlChip(
                  avatar: Icon(Icons.lan_outlined, size: 16),
                  label: "192.168.1.198",
                ),
                IconButton(onPressed: () {}, icon: const Icon(Icons.refresh)),
                ItemActionBar.editDelete(onEdit: () {}, onDelete: () {}),
                const AppTextField(labelText: "本機 Port", initialValue: "45510"),
                const AppTextField(hintText: "對方 IP"),
                FilledButton.tonalIcon(
                  onPressed: () {},
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text("開啟服務"),
                ),
                AppDropdownField<String>(
                  value: "JP",
                  options: const [DropdownOption(value: "JP", label: "日式")],
                  onChanged: (_) {},
                ),
                TextButton(
                  onPressed: () {},
                  child: const MediumTitle(icon: Icons.east, text: "生成"),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final height = AppControlSize.heightForFontSize(fontSize);
      for (final type in [
        AppControlChip,
        ItemActionBar,
        FilledButton,
        AppDropdownField<String>,
        TextButton,
      ]) {
        expect(
          tester.getSize(find.byType(type)).height,
          height,
          reason: "$type at $fontSize",
        );
      }
      for (final button in find.byType(IconButton).evaluate()) {
        expect(
          tester.getSize(find.byWidget(button.widget)),
          Size.square(height),
        );
      }
      for (final decorator in find.byType(InputDecorator).evaluate()) {
        final container = InputDecorator.containerOf(
          tester.element(
            find
                .descendant(
                  of: find.byWidget(decorator.widget),
                  matching: find.byType(Text),
                )
                .first,
          ),
        );
        expect(
          container!.size.height,
          height,
          reason: "field border at $fontSize",
        );
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets("standard controls render at 40dp in both themes", (
    tester,
  ) async {
    for (final theme in [
      AppTheme.getLightTheme(14, Colors.blue),
      AppTheme.getDarkTheme(14, Colors.blue),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Column(
              children: [
                IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
                FilledButton(onPressed: () {}, child: const Text("Add")),
                OutlinedButton(onPressed: () {}, child: const Text("Edit")),
                ElevatedButton(onPressed: () {}, child: const Text("Save")),
                TextButton(onPressed: () {}, child: const Text("Cancel")),
                const AppTextField(initialValue: "Story"),
              ],
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(IconButton)), const Size.square(40));
      for (final type in [
        FilledButton,
        OutlinedButton,
        ElevatedButton,
        TextButton,
        AppTextField,
      ]) {
        expect(tester.getSize(find.byType(type)).height, 40);
      }
      expect(tester.takeException(), isNull);
    }
  });

  test("single-line controls share a height at standard and large fonts", () {
    for (final fontSize in [14.0, 20.0]) {
      final height = AppControlSize.heightForFontSize(fontSize);
      for (final theme in [
        AppTheme.getLightTheme(fontSize, Colors.blue),
        AppTheme.getDarkTheme(fontSize, Colors.blue),
      ]) {
        expect(
          theme.inputDecorationTheme.constraints,
          BoxConstraints(minHeight: height),
        );
        for (final style in [
          theme.filledButtonTheme.style,
          theme.outlinedButtonTheme.style,
          theme.elevatedButtonTheme.style,
          theme.textButtonTheme.style,
          theme.iconButtonTheme.style,
          theme.segmentedButtonTheme.style,
        ]) {
          expect(style?.minimumSize?.resolve({})?.height, height);
        }
      }
    }
  });

  testWidgets("action buttons use square 40dp targets by default", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.getLightTheme(14, Colors.blue),
        home: Scaffold(
          body: ItemActionBar.editDelete(onEdit: () {}, onDelete: () {}),
        ),
      ),
    );
    for (final button in find.byType(IconButton).evaluate()) {
      final size = tester.getSize(find.byWidget(button.widget));
      expect(size, const Size.square(40));
    }
  });

  testWidgets("fields and table rows grow for system text scaling", (
    tester,
  ) async {
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getLightTheme(14, Colors.blue),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(
            body: Column(
              children: [
                AppTextField(labelText: "Name", initialValue: "Story"),
                AppTwoColumnTableRow(
                  firstCell: Text("Title"),
                  secondCell: Text("Details"),
                ),
              ],
            ),
          ),
        ),
      );
      final minHeight = AppControlSize.heightForFontSize(14 * scale);
      expect(
        tester.getSize(find.byType(AppTextField)).height,
        greaterThanOrEqualTo(minHeight),
      );
      expect(
        tester.getSize(find.byType(AppTwoColumnTableRow)).height,
        greaterThanOrEqualTo(minHeight),
      );
      expect(tester.takeException(), isNull);
    }
  });

  test("text fields share the 12dp control radius in both themes", () {
    for (final theme in [
      AppTheme.getLightTheme(14, Colors.blue),
      AppTheme.getDarkTheme(14, Colors.blue),
    ]) {
      final border = theme.inputDecorationTheme.border as OutlineInputBorder;
      expect(border.borderRadius, AppControlShape.borderRadius);
    }
  });

  test("controls use 12dp and surfaces use 16dp in both themes", () {
    for (final theme in [
      AppTheme.getLightTheme(14, Colors.blue),
      AppTheme.getDarkTheme(14, Colors.blue),
    ]) {
      final buttonShapes = [
        theme.filledButtonTheme.style?.shape?.resolve({}),
        theme.outlinedButtonTheme.style?.shape?.resolve({}),
        theme.elevatedButtonTheme.style?.shape?.resolve({}),
        theme.textButtonTheme.style?.shape?.resolve({}),
        theme.iconButtonTheme.style?.shape?.resolve({}),
        theme.segmentedButtonTheme.style?.shape?.resolve({}),
      ];
      final chipShape = theme.chipTheme.shape;

      for (final shape in [
        ...buttonShapes,
        chipShape,
        theme.popupMenuTheme.shape,
        theme.menuTheme.style?.shape?.resolve({}),
        theme.snackBarTheme.shape,
        theme.navigationBarTheme.indicatorShape,
        theme.navigationRailTheme.indicatorShape,
        theme.floatingActionButtonTheme.shape,
      ]) {
        expect(shape, isA<RoundedRectangleBorder>());
        final radius = (shape! as RoundedRectangleBorder).borderRadius;
        expect(radius, BorderRadius.circular(12));
      }

      final cardShape = theme.cardTheme.shape as RoundedRectangleBorder;
      final dialogShape = theme.dialogTheme.shape as RoundedRectangleBorder;
      expect(cardShape.borderRadius, AppSurfaceShape.borderRadius);
      expect(dialogShape.borderRadius, AppSurfaceShape.borderRadius);
    }
  });

  group("Material 3 typography", () {
    test("light and dark themes use the Material 3 type scale", () {
      for (final theme in [
        AppTheme.getLightTheme(14, Colors.blue),
        AppTheme.getDarkTheme(14, Colors.blue),
      ]) {
        final type = theme.textTheme;
        expect(type.displayLarge?.fontSize, 57);
        expect(type.displayMedium?.fontSize, 45);
        expect(type.displaySmall?.fontSize, 36);
        expect(type.headlineLarge?.fontSize, 32);
        expect(type.headlineMedium?.fontSize, 28);
        expect(type.headlineSmall?.fontSize, 24);
        expect(type.titleLarge?.fontSize, 22);
        expect(type.titleMedium?.fontSize, 16);
        expect(type.titleSmall?.fontSize, 14);
        expect(type.bodyLarge?.fontSize, 16);
        expect(type.bodyMedium?.fontSize, 14);
        expect(type.bodySmall?.fontSize, 12);
        expect(type.labelLarge?.fontSize, 14);
        expect(type.labelMedium?.fontSize, 12);
        expect(type.labelSmall?.fontSize, 11);
      }
    });

    test("font preference scales roles without changing their hierarchy", () {
      final standard = AppTheme.getLightTheme(14, Colors.blue).textTheme;
      final enlarged = AppTheme.getLightTheme(20, Colors.blue).textTheme;

      expect(enlarged.bodyMedium?.fontSize, 20);
      expect(enlarged.displaySmall?.fontSize, closeTo(36 * 20 / 14, 0.001));
      expect(enlarged.labelSmall?.fontSize, closeTo(11 * 20 / 14, 0.001));
      expect(enlarged.bodyMedium?.fontWeight, standard.bodyMedium?.fontWeight);
      expect(enlarged.bodyMedium?.height, standard.bodyMedium?.height);
    });

    test("compact labels inherit labelSmall styling and font preference", () {
      for (final theme in [
        AppTheme.getLightTheme(14, Colors.blue),
        AppTheme.getDarkTheme(14, Colors.blue),
      ]) {
        final type = theme.textTheme;
        expect(type.labelTiny?.fontSize, 10);
        expect(type.labelNano?.fontSize, 9);
        expect(type.labelTiny?.fontWeight, type.labelSmall?.fontWeight);
        expect(type.labelNano?.color, type.labelSmall?.color);
        expect(type.labelTiny?.fontFamily, type.labelSmall?.fontFamily);
      }

      final enlarged = AppTheme.getLightTheme(20, Colors.blue).textTheme;
      expect(enlarged.labelTiny?.fontSize, closeTo(10 * 20 / 14, 0.001));
      expect(enlarged.labelNano?.fontSize, closeTo(9 * 20 / 14, 0.001));
    });
  });

  testWidgets("unstyled icons follow theme switches and local overrides", (
    tester,
  ) async {
    for (final seed in [Colors.blue, Colors.green, Colors.grey]) {
      for (final theme in [
        AppTheme.getLightTheme(14, seed),
        AppTheme.getDarkTheme(14, seed),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            themeAnimationDuration: Duration.zero,
            home: Scaffold(
              body: Column(
                children: [
                  const Icon(Icons.info_outline, key: ValueKey("plain-icon")),
                  const SmallTitle(icon: Icons.folder, text: "Heading"),
                  IconTheme.merge(
                    data: IconThemeData(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                    child: const Icon(
                      Icons.analytics,
                      key: ValueKey("local-icon"),
                    ),
                  ),
                  Icon(
                    Icons.warning_amber,
                    key: const ValueKey("semantic-icon"),
                    color: theme.colorScheme.error,
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.edit, key: ValueKey("enabled-icon")),
                  ),
                  const IconButton(
                    onPressed: null,
                    icon: Icon(Icons.delete, key: ValueKey("disabled-icon")),
                  ),
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add, key: ValueKey("filled-icon")),
                    label: const Text("Add"),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        Color? renderedColor(String key) {
          final glyph = find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(RichText),
          );
          return tester.widget<RichText>(glyph).text.style?.color;
        }

        expect(renderedColor("plain-icon"), theme.colorScheme.onSurface);
        expect(
          renderedColor("local-icon"),
          theme.colorScheme.onTertiaryContainer,
        );
        expect(renderedColor("semantic-icon"), theme.colorScheme.error);
        expect(renderedColor("enabled-icon"), theme.colorScheme.onSurface);
        expect(
          renderedColor("disabled-icon"),
          theme.colorScheme.onSurface.withValues(alpha: 0.38),
        );
        expect(renderedColor("filled-icon"), theme.colorScheme.onPrimary);
        expect(tester.takeException(), isNull);
      }
    }
  });

  group("AppTheme IconButton colors", () {
    test("hover uses a circle in both themes", () {
      for (final theme in [
        AppTheme.getLightTheme(14, Colors.blue),
        AppTheme.getDarkTheme(14, Colors.blue),
      ]) {
        final shape = theme.iconButtonTheme.style!.shape!;
        expect(shape.resolve({}), isA<RoundedRectangleBorder>());
        expect(shape.resolve({WidgetState.hovered}), isA<CircleBorder>());
        expect(
          shape.resolve({WidgetState.hovered, WidgetState.pressed}),
          isA<CircleBorder>(),
        );
      }
    });

    test("dark theme uses a light on-surface foreground", () {
      final theme = AppTheme.getDarkTheme(14, Colors.blue);
      final foregroundColor = theme.iconButtonTheme.style?.foregroundColor;

      expect(foregroundColor?.resolve({}), theme.colorScheme.onSurface);
      expect(
        foregroundColor?.resolve({WidgetState.disabled}),
        theme.colorScheme.onSurface.withValues(alpha: 0.38),
      );
      expect(
        foregroundColor?.resolve({})?.computeLuminance(),
        greaterThan(theme.colorScheme.surface.computeLuminance()),
      );
    });
  });
}
