import "package:flutter/material.dart";

@immutable
final class RhodantheTheme extends ThemeExtension<RhodantheTheme> {
  final Map<String, Color> colors;

  RhodantheTheme({required Map<String, Color> colors})
    : colors = Map<String, Color>.unmodifiable(colors);

  factory RhodantheTheme.light() => RhodantheTheme(
    colors: const <String, Color>{
      "search.current.foreground": Color(0xFFFFFFFF),
      "search.current.background": Color(0xFF8C1D18),
      "search.match.background": Color(0xFFFFE082),
      "mention.resolved.foreground": Color(0xFF006A6A),
      "mention.resolved.decoration": Color(0xFF006A6A),
      "mention.unresolved.foreground": Color(0xFF6A1B9A),
      "mention.unresolved.decoration": Color(0xFF6A1B9A),
      "filler.foreground": Color(0xFFB3261E),
      "filler.decoration": Color(0xFFB3261E),
      "diagnostic.decoration": Color(0xFF5F6368),
    },
  );

  factory RhodantheTheme.dark() => RhodantheTheme(
    colors: const <String, Color>{
      "search.current.foreground": Color(0xFF1B1B1F),
      "search.current.background": Color(0xFFFFB4AB),
      "search.match.background": Color(0xFF665500),
      "mention.resolved.foreground": Color(0xFF4FD8D8),
      "mention.resolved.decoration": Color(0xFF4FD8D8),
      "mention.unresolved.foreground": Color(0xFFD7B5FF),
      "mention.unresolved.decoration": Color(0xFFD7B5FF),
      "filler.foreground": Color(0xFFFFB4AB),
      "filler.decoration": Color(0xFFFFB4AB),
      "diagnostic.decoration": Color(0xFFC4C7C5),
    },
  );

  factory RhodantheTheme.highContrast({
    Brightness brightness = Brightness.light,
  }) {
    return RhodantheTheme(
      colors: brightness == Brightness.dark
          ? const <String, Color>{
              "search.current.foreground": Color(0xFF000000),
              "search.current.background": Color(0xFFFFFF00),
              "search.match.background": Color(0xFF005A9C),
              "mention.resolved.foreground": Color(0xFF00FFFF),
              "mention.resolved.decoration": Color(0xFF00FFFF),
              "mention.unresolved.foreground": Color(0xFFFF80FF),
              "mention.unresolved.decoration": Color(0xFFFF80FF),
              "filler.foreground": Color(0xFFFF8080),
              "filler.decoration": Color(0xFFFF8080),
              "diagnostic.decoration": Color(0xFFFFFFFF),
            }
          : const <String, Color>{
              "search.current.foreground": Color(0xFFFFFFFF),
              "search.current.background": Color(0xFF000000),
              "search.match.background": Color(0xFFFFFF00),
              "mention.resolved.foreground": Color(0xFF005A00),
              "mention.resolved.decoration": Color(0xFF005A00),
              "mention.unresolved.foreground": Color(0xFF6A006A),
              "mention.unresolved.decoration": Color(0xFF6A006A),
              "filler.foreground": Color(0xFFB00000),
              "filler.decoration": Color(0xFFB00000),
              "diagnostic.decoration": Color(0xFF000000),
            },
    );
  }

  factory RhodantheTheme.resolve(BuildContext context) {
    final configured = Theme.of(context).extension<RhodantheTheme>();
    if (configured != null) return configured;
    final brightness = Theme.of(context).brightness;
    if (MediaQuery.maybeOf(context)?.highContrast ?? false) {
      return RhodantheTheme.highContrast(brightness: brightness);
    }
    return brightness == Brightness.dark
        ? RhodantheTheme.dark()
        : RhodantheTheme.light();
  }

  Color? resolveColor(String token) => colors[token];

  @override
  RhodantheTheme copyWith({Map<String, Color>? colors}) {
    return RhodantheTheme(colors: colors ?? this.colors);
  }

  @override
  RhodantheTheme lerp(covariant RhodantheTheme? other, double t) {
    if (other == null) return this;
    final tokens = <String>{...colors.keys, ...other.colors.keys};
    return RhodantheTheme(
      colors: <String, Color>{
        for (final token in tokens)
          token:
              Color.lerp(colors[token], other.colors[token], t) ??
              other.colors[token] ??
              colors[token]!,
      },
    );
  }
}
