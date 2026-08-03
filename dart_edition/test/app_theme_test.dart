import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/ui_library.dart";

void main() {
  group("AppTheme IconButton colors", () {
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
