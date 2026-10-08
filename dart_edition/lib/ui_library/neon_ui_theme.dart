import "package:flutter/material.dart";

enum NeonStatus {
  idle,
  error,
  warning,
  notice,
  active,
  connected,
  info,
  preview,
}

enum NeonAccent { neutral, green, teal }

/// Flat icon colors stay independent of the application's accent color.
@immutable
class NeonUiTheme extends ThemeExtension<NeonUiTheme> {
  final Map<NeonStatus, Color> colors;
  final Color surface;
  final Color hover;
  final Color pressed;
  final Color disabled;

  NeonUiTheme(
    Map<NeonStatus, Color> colors, {
    this.surface = const Color(0xFF191C20),
    this.hover = const Color(0xFF292C2F),
    this.pressed = const Color(0xFF34373B),
    this.disabled = const Color(0xFF65676C),
  }) : colors = Map.unmodifiable(colors);

  factory NeonUiTheme.resolve(BuildContext context) {
    final theme = Theme.of(context);
    final configured = theme.extension<NeonUiTheme>();
    if (configured != null) return configured;
    final dark = theme.brightness == Brightness.dark;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final values = dark
        ? [
            highContrast ? 0xFFFFFFFF : 0xFFE1E2E8,
            0xFFFF5D6C,
            0xFFFF9F43,
            0xFFFFD84D,
            highContrast ? 0xFF81C784 : 0xFF4CAF50,
            highContrast ? 0xFF80CBC4 : 0xFF26A69A,
            0xFF52A8FF,
            0xFFBA8CFF,
          ]
        : [
            highContrast ? 0xFF000000 : 0xFF303238,
            0xFFB42336,
            0xFF9A4700,
            0xFF806000,
            0xFF147D43,
            0xFF007873,
            0xFF0969B5,
            0xFF7844B5,
          ];
    return NeonUiTheme(
      {
        for (final status in NeonStatus.values)
          status: Color(values[status.index]),
      },
      surface: dark ? const Color(0xFF191C20) : theme.colorScheme.surface,
      hover: dark ? const Color(0xFF292C2F) : const Color(0xFFE4E5E7),
      pressed: dark ? const Color(0xFF34373B) : const Color(0xFFD7D9DC),
      disabled: dark
          ? Color(highContrast ? 0xFF909297 : 0xFF65676C)
          : Color(highContrast ? 0xFF65676C : 0xFF909297),
    );
  }

  Color color(NeonStatus status) => colors[status]!;

  Color accent(NeonAccent accent) => color(switch (accent) {
    NeonAccent.neutral => NeonStatus.idle,
    NeonAccent.green => NeonStatus.active,
    NeonAccent.teal => NeonStatus.connected,
  });

  Color foreground({
    NeonStatus status = NeonStatus.idle,
    bool disabled = false,
    bool destructive = false,
    bool selected = false,
    NeonAccent accent = NeonAccent.neutral,
    NeonAccent selectedAccent = NeonAccent.green,
  }) {
    if (disabled) return this.disabled;
    if (status != NeonStatus.idle) return color(status);
    if (destructive) return color(NeonStatus.error);
    return this.accent(selected ? selectedAccent : accent);
  }

  @override
  NeonUiTheme copyWith({
    Map<NeonStatus, Color>? colors,
    Color? surface,
    Color? hover,
    Color? pressed,
    Color? disabled,
  }) => NeonUiTheme(
    colors ?? this.colors,
    surface: surface ?? this.surface,
    hover: hover ?? this.hover,
    pressed: pressed ?? this.pressed,
    disabled: disabled ?? this.disabled,
  );

  @override
  NeonUiTheme lerp(covariant NeonUiTheme? other, double t) => other == null
      ? this
      : NeonUiTheme(
          {
            for (final status in NeonStatus.values)
              status: Color.lerp(color(status), other.color(status), t)!,
          },
          surface: Color.lerp(surface, other.surface, t)!,
          hover: Color.lerp(hover, other.hover, t)!,
          pressed: Color.lerp(pressed, other.pressed, t)!,
          disabled: Color.lerp(disabled, other.disabled, t)!,
        );
}
