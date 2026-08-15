import "package:flutter/material.dart";
import "package:flutter_svg/flutter_svg.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/presentation/widgets/splash_screen.dart";

void main() {
  testWidgets("desktop splash keeps the reference content and SVG decoration", (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashWindow()));
    await tester.pumpAndSettle();

    expect(find.text("物語 Assistant"), findsOneWidget);
    expect(find.text("Monogatari Assistant"), findsOneWidget);
    expect(find.text("120×360\n裝飾區"), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key("desktop-splash-decoration")),
        matching: find.byType(SvgPicture),
      ),
      findsOneWidget,
    );
  });

  testWidgets("mobile splash uses the mobile composition", (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplachScreen()));

    expect(find.text("物語 Assistant"), findsOneWidget);
    expect(find.text("版本號碼 0.1.0    Build 1"), findsOneWidget);
  });
}
