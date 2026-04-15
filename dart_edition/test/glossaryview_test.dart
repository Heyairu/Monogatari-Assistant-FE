import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/modules/glossaryview.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("GlossaryView renders from provider state", (tester) async {
    final container = ProviderContainer();

    container.read(glossaryStateProvider.notifier).state = GlossaryStateData(
      categoryTree: [
        GlossaryCategory(
          id: "cat-1",
          name: "分類A",
          entryIds: ["entry-1"],
          children: const [],
        ),
      ],
      entryIndex: {
        "entry-1": GlossaryEntry(
          id: "entry-1",
          term: "詞條A",
          partOfSpeech: GlossaryPartOfSpeech.noun,
          customPartOfSpeech: "",
          polarity: GlossaryPolarity.neutral,
          pairs: [GlossaryPair(meaning: "意義A", example: "例句A")],
        ),
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        parent: container,
        child: const MaterialApp(
          home: Scaffold(
            body: GlossaryView(),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text("詞語參考"), findsOneWidget);
    expect(find.text("分類A"), findsWidgets);
  });
}
