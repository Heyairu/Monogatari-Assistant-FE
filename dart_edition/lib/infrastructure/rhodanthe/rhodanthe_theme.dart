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
      "annotation.green.background": Color(0xFFD7F5DD),
      "annotation.green.foreground": Color(0xFF14532D),
      "annotation.blue.background": Color(0xFFDCEBFF),
      "annotation.blue.foreground": Color(0xFF183B66),
      "annotation.pink.background": Color(0xFFF8DCE3),
      "annotation.pink.foreground": Color(0xFF6F1D35),
      "annotation.purple.background": Color(0xFFE9DDFB),
      "annotation.purple.foreground": Color(0xFF42216E),
      "annotation.yellow.background": Color(0xFFFFF1B8),
      "annotation.yellow.foreground": Color(0xFF5F4700),
      "annotation.gray.background": Color(0xFFE5E7EB),
      "annotation.gray.foreground": Color(0xFF30343B),
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
      "annotation.green.background": Color(0xFF24543A),
      "annotation.green.foreground": Color(0xFFC7F9D4),
      "annotation.blue.background": Color(0xFF274B73),
      "annotation.blue.foreground": Color(0xFFD7EAFF),
      "annotation.pink.background": Color(0xFF71364B),
      "annotation.pink.foreground": Color(0xFFFFD9E3),
      "annotation.purple.background": Color(0xFF503B72),
      "annotation.purple.foreground": Color(0xFFEBDDFF),
      "annotation.yellow.background": Color(0xFF66551F),
      "annotation.yellow.foreground": Color(0xFFFFEFAD),
      "annotation.gray.background": Color(0xFF454A52),
      "annotation.gray.foreground": Color(0xFFF1F3F5),
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
              ..._highContrastAnnotationColors,
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
              ..._highContrastAnnotationColors,
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

const Map<String, Color> _highContrastAnnotationColors = <String, Color>{
  "annotation.green.background": Color(0xFF005C20),
  "annotation.green.foreground": Colors.white,
  "annotation.blue.background": Color(0xFF004C8C),
  "annotation.blue.foreground": Colors.white,
  "annotation.pink.background": Color(0xFF8B1740),
  "annotation.pink.foreground": Colors.white,
  "annotation.purple.background": Color(0xFF561391),
  "annotation.purple.foreground": Colors.white,
  "annotation.yellow.background": Color(0xFF705900),
  "annotation.yellow.foreground": Colors.white,
  "annotation.gray.background": Color(0xFF343A40),
  "annotation.gray.foreground": Colors.white,
};
