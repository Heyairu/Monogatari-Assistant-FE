import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/ui_library.dart";
import "package:monogatari_assistant/modules/WelcomeView.dart";

void main() {
  testWidgets("WelcomeView keeps spacing around every section card", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: WelcomeView(recentProjects: [])),
      ),
    );

    final Finder sectionCards = find.byType(AppSectionCard);
    expect(sectionCards, findsNWidgets(5));

    for (final Element element in sectionCards.evaluate()) {
      final AppSectionCard sectionCard = element.widget as AppSectionCard;
      expect(sectionCard.margin, const EdgeInsets.all(4));
    }
  });
}
