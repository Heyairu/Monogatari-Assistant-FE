import "dart:collection";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

import "package:monogatari_assistant/modules/glossaryview.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";

Widget _buildHarness({required ProviderContainer container}) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: GlossaryView(),
    ),
  );
}

Finder _textFieldByHint(String hintText) {
  return find.byWidgetPredicate((widget) {
    return widget is TextField && widget.decoration?.hintText == hintText;
  });
}

Finder _categoryNodeById(String categoryId) {
  return find.byKey(ValueKey<String>(categoryId));
}

Future<void> _selectCategoryById(WidgetTester tester, String categoryId) async {
  final Finder finder = _categoryNodeById(categoryId);
  expect(finder, findsOneWidget);
  final Offset tapTarget = tester.getTopLeft(finder) + const Offset(12, 12);
  await tester.tapAt(tapTarget);
  await tester.pumpAndSettle();
}

GlossaryStateData _makeGlossaryState({
  required String categoryId,
  required String categoryName,
  required String entryId,
  required String term,
}) {
  final HashMap<String, GlossaryEntry> entryIndex = HashMap();
  entryIndex[entryId] = GlossaryEntry(
    id: entryId,
    term: term,
    partOfSpeech: GlossaryPartOfSpeech.unspecified,
    customPartOfSpeech: "",
    polarity: GlossaryPolarity.neutral,
    pairs: [GlossaryPair(meaning: "意義", example: "例句")],
  );

  return GlossaryStateData(
    categoryTree: [
      GlossaryCategory(
        id: categoryId,
        name: categoryName,
        entryIds: [entryId],
        children: [],
      ),
    ],
    entryIndex: entryIndex,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("Phase 3 Glossary migration and regression", () {
    test("glossaryStateProvider uses synchronous initial state", () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final GlossaryStateData state = container.read(glossaryStateProvider);
      expect(state.categoryTree, isEmpty);
      expect(state.entryIndex, isEmpty);
    });

    testWidgets("initialization uses preloaded provider state without async loading", (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(glossaryStateProvider.notifier).setGlossaryState(
            _makeGlossaryState(
              categoryId: "cat-initial",
              categoryName: "初始化分類",
              entryId: "entry-initial",
              term: "初始化詞條",
            ),
          );

      await tester.pumpWidget(_buildHarness(container: container));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text("初始化分類"), findsOneWidget);

      await _selectCategoryById(tester, "cat-initial");

      expect(find.text("初始化詞條"), findsAtLeastNWidgets(1));

      final GlossaryStateData state = container.read(glossaryStateProvider);
      expect(state.categoryTree.length, 1);
      expect(state.categoryTree.first.name, "初始化分類");
      expect(state.entryIndex["entry-initial"]?.term, "初始化詞條");
    });

    testWidgets("add/edit/delete category and entry updates provider state", (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(glossaryStateProvider.notifier).setGlossaryState(
            _makeGlossaryState(
              categoryId: "cat-base",
              categoryName: "基礎分類",
              entryId: "entry-base",
              term: "基礎詞條",
            ),
          );

      await tester.pumpWidget(_buildHarness(container: container));
      await tester.pumpAndSettle();

      await _selectCategoryById(tester, "cat-base");

      await tester.tap(find.byTooltip("新增根分類"));
      await tester.pumpAndSettle();
      final Finder addDialog = find.byType(AlertDialog);
      expect(addDialog, findsOneWidget);
      final Finder categoryNameField = find.descendant(
        of: addDialog,
        matching: find.byType(TextFormField),
      );
      expect(categoryNameField, findsOneWidget);
      await tester.enterText(categoryNameField, "測試分類");
      await tester.tap(find.descendant(of: addDialog, matching: find.text("確定")));
      await tester.pumpAndSettle();

      expect(find.text("測試分類"), findsAtLeastNWidgets(1));
      expect(
        container
            .read(glossaryStateProvider)
            .categoryTree
            .any((category) => category.name == "測試分類"),
        isTrue,
      );

      await tester.enterText(_textFieldByHint("新增詞條名稱").first, "原始詞條");
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text("原始詞條"), findsAtLeastNWidgets(1));

      await tester.tap(find.text("原始詞條").first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, "修改後詞條");
      await tester.pumpAndSettle();

      final bool hasRenamed = container
          .read(glossaryStateProvider)
          .entryIndex
          .values
          .any((entry) => entry.term == "修改後詞條");
      expect(hasRenamed, isTrue);

      final GlossaryStateData currentState = container.read(glossaryStateProvider);
      final List<GlossaryCategory> filteredCategories = currentState.categoryTree
          .where((category) => category.name != "測試分類")
          .toList();
      container.read(glossaryStateProvider.notifier).setGlossaryState(
            GlossaryStateData(
              categoryTree: filteredCategories,
              entryIndex: currentState.entryIndex,
            ),
          );
      await tester.pumpAndSettle();

      expect(find.text("測試分類"), findsNothing);
      final List<GlossaryCategory> categories = container.read(glossaryStateProvider).categoryTree;
      expect(categories.any((category) => category.name == "測試分類"), isFalse);
    });

    testWidgets("external provider sync updates glossary UI after load", (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(glossaryStateProvider.notifier).setGlossaryState(
            _makeGlossaryState(
              categoryId: "cat-a",
              categoryName: "初始分類",
              entryId: "entry-a",
              term: "初始詞條",
            ),
          );

      await tester.pumpWidget(_buildHarness(container: container));
      await tester.pumpAndSettle();

      expect(find.text("初始分類"), findsOneWidget);

      await _selectCategoryById(tester, "cat-a");
      expect(find.text("初始詞條"), findsAtLeastNWidgets(1));

      container.read(glossaryStateProvider.notifier).setGlossaryState(
            _makeGlossaryState(
              categoryId: "cat-b",
              categoryName: "同步分類",
              entryId: "entry-b",
              term: "同步詞條",
            ),
          );

      await tester.pumpAndSettle();

      expect(find.text("同步分類"), findsOneWidget);

      await _selectCategoryById(tester, "cat-b");
      expect(find.text("同步詞條"), findsAtLeastNWidgets(1));
      expect(find.text("初始分類"), findsNothing);
    });
  });
}
