import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_theme.dart";

void main() {
  test("search colors keep normal text at WCAG AA contrast", () {
    final light = RhodantheTheme.light();
    final dark = RhodantheTheme.dark();

    expect(
      _contrast(
        light.resolveColor("search.current.foreground")!,
        light.resolveColor("search.current.background")!,
      ),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(
        const Color(0xFF1B1B1F),
        light.resolveColor("search.match.background")!,
      ),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(
        dark.resolveColor("search.current.foreground")!,
        dark.resolveColor("search.current.background")!,
      ),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(Colors.white, dark.resolveColor("search.match.background")!),
      greaterThanOrEqualTo(4.5),
    );
  });
}

double _contrast(Color foreground, Color background) {
  final lighter = foreground.computeLuminance() > background.computeLuminance()
      ? foreground
      : background;
  final darker = identical(lighter, foreground) ? background : foreground;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}
