import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monogatari_assistant/bin/content.dart';
import 'package:monogatari_assistant/bin/findreplace.dart';
import 'package:monogatari_assistant/bin/ui_library.dart';
import 'package:monogatari_assistant/features/phrases/phrase_entry.dart';
import 'package:monogatari_assistant/features/phrases/global_phrases_provider.dart';
import 'package:monogatari_assistant/features/phrases/phrase_library_dialog.dart';
import 'package:monogatari_assistant/features/inline_annotations/mosaic_editing_controller.dart';
import 'package:monogatari_assistant/features/inline_annotations/inline_annotation.dart';
import 'package:monogatari_assistant/models/character_data.dart';
import 'package:monogatari_assistant/models/item_data.dart';
import 'package:monogatari_assistant/models/outline_data.dart';
import 'package:monogatari_assistant/models/world_settings_data.dart';
import 'package:monogatari_assistant/presentation/providers/project_state_providers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final target in const [
    (trigger: '*', kind: InlineAnnotationKind.item, name: '銀鑰匙'),
    (trigger: '!', kind: InlineAnnotationKind.location, name: '鐘樓'),
    (trigger: '#', kind: InlineAnnotationKind.event, name: '遠行'),
  ]) {
    testWidgets('${target.kind.name} toolbar inserts a project phrase', (
      tester,
    ) async {
      const id = '4e251fc2-1e2b-4f78-93da-91f8c76d9a92';
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(globalPhrasesProvider.future);
      container
          .read(itemWorkspaceProvider.notifier)
          .putClass(ItemClassData(classId: id, name: '銀鑰匙'));
      container.read(worldSettingsDataProvider.notifier).setWorldSettingsData([
        LocationData(id: id, localName: '鐘樓'),
      ]);
      container.read(outlineDataProvider.notifier).setOutlineData([
        StorylineData(chapterUUID: id, storylineName: '遠行'),
      ]);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: PhraseLibraryDialog(initialBody: '抵達 ')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('phrase-shortcut')),
        'go',
      );
      await tester.tap(find.byKey(const ValueKey('phrase-global-scope')));
      final bodyField = find.descendant(
        of: find.byKey(const ValueKey('phrase-body')),
        matching: find.byType(CodeField),
      );
      final body =
          tester.widget<CodeField>(bodyField).controller
              as MosaicEditingController;
      body.selection = TextSelection.collapsed(offset: body.displayText.length);
      await tester.tap(find.byKey(ValueKey('phrase-insert-${target.trigger}')));
      await tester.pumpAndSettle();
      final candidate = find.text(target.name).first;
      await tester.ensureVisible(candidate);
      await tester.tap(candidate);
      await tester.pumpAndSettle();
      expect(body.annotations.single.kind, target.kind);
      expect(body.rawText, '抵達 //${target.trigger}<$id|${target.name}>//');
      expect(
        tester
            .widget<Switch>(find.byKey(const ValueKey('phrase-global-scope')))
            .onChanged,
        isNull,
      );
      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();
      expect(container.read(phrasesProvider).single.body, body.rawText);
      expect(container.read(globalPhrasesProvider).value, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('text mark replaces selection and can be saved globally', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(globalPhrasesProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: PhraseLibraryDialog(initialBody: '前重點後')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('phrase-shortcut')),
      'mark',
    );
    final bodyField = find.descendant(
      of: find.byKey(const ValueKey('phrase-body')),
      matching: find.byType(CodeField),
    );
    final body =
        tester.widget<CodeField>(bodyField).controller
            as MosaicEditingController;
    body.selection = const TextSelection(baseOffset: 1, extentOffset: 3);
    await tester.tap(find.byKey(const ValueKey('phrase-insert-mark')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('inline-annotation-save')),
    );
    await tester.tap(find.byKey(const ValueKey('inline-annotation-save')));
    await tester.pumpAndSettle();
    expect(body.rawText, '前//^<重點>//後');
    expect(body.annotations.single.hasTarget, isFalse);
    await tester.tap(find.byKey(const ValueKey('phrase-global-scope')));
    await tester.pump();
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();
    expect(container.read(phrasesProvider), isEmpty);
    expect(
      container.read(globalPhrasesProvider).value!.single.body,
      '前//^<重點>//後',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('phrase footer has padding and stays visible with many tags', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 650));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.getDarkTheme(20, Colors.green),
          home: const Scaffold(body: PhraseLibraryDialog(initialBody: '內容')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, '儲存');
    final back = find.widgetWithText(TextButton, '返回');
    final footer = tester.getRect(save);
    final dialog = tester.getRect(
      find
          .descendant(of: find.byType(Dialog), matching: find.byType(Material))
          .first,
    );
    expect(footer.right, closeTo(dialog.right - 20, 0.5));
    expect(footer.bottom, closeTo(dialog.bottom - 20, 0.5));
    expect(footer.left - tester.getRect(back).right, greaterThanOrEqualTo(8));
    final formScroll = find
        .ancestor(
          of: find.byKey(const ValueKey('phrase-shortcut')),
          matching: find.byType(SingleChildScrollView),
        )
        .first;
    expect(
      footer.top - tester.getRect(formScroll).bottom,
      greaterThanOrEqualTo(12),
    );
    for (var i = 0; i < 8; i++) {
      await tester.ensureVisible(
        find.byKey(const ValueKey('phrase-tag-input')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('phrase-tag-input')),
        '標籤 $i',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }
    expect(find.byType(InputChip), findsNWidgets(8));
    expect(tester.getRect(save), footer);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plain phrase can be saved for every project', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = HighlightTextEditingController(text: '正文');
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(
              controller: controller,
              focusNode: focus,
              usePlainTextQuillEditor: false,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('phrase-library-button')));
    await tester.pumpAndSettle();
    final importButton = tester.getRect(
      find.widgetWithText(OutlinedButton, '匯入'),
    );
    final exportButton = tester.getRect(
      find.widgetWithText(OutlinedButton, '匯出'),
    );
    final addButton = tester.getRect(find.widgetWithText(FilledButton, '新增短語'));
    final closeButton = tester.getRect(find.byTooltip('關閉'));
    final searchField = tester.getRect(
      find
          .descendant(of: find.byType(Dialog), matching: find.byType(TextField))
          .first,
    );
    expect(exportButton.left - importButton.right, inInclusiveRange(0, 8));
    expect(addButton.left - exportButton.right, inInclusiveRange(0, 8));
    expect(closeButton.left - addButton.right, inInclusiveRange(0, 12));
    expect(closeButton.right, closeTo(searchField.right, 5));
    expect(searchField.top - addButton.bottom, greaterThanOrEqualTo(12));
    await tester.tap(find.text('新增短語'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('phrase-shortcut')), 'hi');
    await tester.tap(find.byKey(const ValueKey('phrase-global-scope')));
    await tester.pump();
    final bodyField = find.descendant(
      of: find.byKey(const ValueKey('phrase-body')),
      matching: find.byType(CodeField),
    );
    await tester.enterText(bodyField, '你好');
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();
    expect(container.read(phrasesProvider), isEmpty);
    expect(
      (await container.read(globalPhrasesProvider.future)).single.body,
      '你好',
    );
    expect(container.read(availablePhrasesProvider).single.shortcut, 'hi');
  });

  testWidgets('Mention disables all-project scope', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = HighlightTextEditingController(text: '正文');
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(
              controller: controller,
              focusNode: focus,
              usePlainTextQuillEditor: false,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('phrase-library-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增短語'));
    await tester.pumpAndSettle();
    final bodyField = find.descendant(
      of: find.byKey(const ValueKey('phrase-body')),
      matching: find.byType(CodeField),
    );
    final body =
        tester.widget<CodeField>(bodyField).controller
            as MosaicEditingController;
    body.setRawText('//@<4e251fc2-1e2b-4f78-93da-91f8c76d9a92|艾莉絲>//');
    await tester.pump();
    expect(find.text('含 Mention，只能用於目前專案'), findsOneWidget);
    expect(
      tester
          .widget<Switch>(find.byKey(const ValueKey('phrase-global-scope')))
          .onChanged,
      isNull,
    );
  });

  testWidgets(
    'pasted phrase trigger stays literal and Esc keeps typed trigger',
    (tester) async {
      final container = ProviderContainer();
      final now = DateTime.utc(2026, 10, 1);
      container.read(phrasesProvider.notifier).setPhrases([
        PhraseEntry(
          id: '8f680e3c-90c1-4f37-ae35-f70c4dc7fe8f',
          name: '抵達',
          shortcut: 'arrive',
          body: '她抵達了。',
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final controller = HighlightTextEditingController(text: '前文 ');
      final focus = FocusNode();
      addTearDown(container.dispose);
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      controller.selection = const TextSelection.collapsed(offset: 3);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: EditorTextBox(
                controller: controller,
                focusNode: focus,
                usePlainTextQuillEditor: false,
              ),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pumpAndSettle();
      controller.value = controller.value.copyWith(
        text: '前文 ;;arr',
        selection: const TextSelection.collapsed(offset: 8),
      );
      await tester.pumpAndSettle();
      expect(find.text('arrive · 她抵達了。'), findsNothing);
      controller.setRawText('前文 ');
      await tester.pumpAndSettle();
      controller.value = controller.value.copyWith(
        text: '前文 ;;',
        selection: const TextSelection.collapsed(offset: 5),
        composing: const TextRange(start: 3, end: 5),
      );
      await tester.pump();
      expect(find.text('arrive · 她抵達了。'), findsNothing);
      controller.value = controller.value.copyWith(composing: TextRange.empty);
      await tester.pump();
      expect(find.text('arrive · 她抵達了。'), findsNothing);
      controller.setRawText('前文 ');
      await tester.pumpAndSettle();
      for (final character in ';;arr'.split('')) {
        final text = '${controller.text}$character';
        controller.value = controller.value.copyWith(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        await tester.pump();
      }
      expect(find.text('arrive · 她抵達了。'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(controller.rawText, '前文 ;;arr');
      expect(find.text('arrive · 她抵達了。'), findsNothing);
    },
  );

  testWidgets('phrase tag input and add button align at large font size', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    final controller = HighlightTextEditingController(text: '正文');
    final focus = FocusNode();
    addTearDown(container.dispose);
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.getDarkTheme(20, Colors.green),
          home: Scaffold(
            body: EditorTextBox(
              controller: controller,
              focusNode: focus,
              usePlainTextQuillEditor: false,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('phrase-library-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增短語'));
    await tester.pumpAndSettle();
    final tagInput = find.byKey(const ValueKey('phrase-tag-input'));
    final addTagButton = find.ancestor(
      of: find.byTooltip('新增標籤'),
      matching: find.byType(IconButton),
    );
    final controlHeight = AppControlSize.heightForFontSize(20);
    expect(tester.getSize(tagInput).height, closeTo(controlHeight, 0.5));
    expect(tester.getSize(addTagButton).height, closeTo(controlHeight, 0.5));
    expect(
      tester.getCenter(addTagButton).dy,
      closeTo(tester.getCenter(tagInput).dy, 0.5),
    );
    expect(
      tester
          .getCenter(
            find.descendant(of: addTagButton, matching: find.byType(Icon)),
          )
          .dy,
      closeTo(
        tester
            .getCenter(
              find.descendant(
                of: tagInput,
                matching: find.byType(EditableText),
              ),
            )
            .dy,
        0.5,
      ),
    );
    await tester.enterText(tagInput, '場景');
    await tester.tap(addTagButton);
    await tester.pump();
    expect(find.widgetWithText(InputChip, '場景'), findsOneWidget);
  });

  testWidgets('library creates a phrase and direct ;; inserts it', (
    tester,
  ) async {
    final container = ProviderContainer();
    final controller = HighlightTextEditingController(text: '前文 ');
    final focus = FocusNode();
    addTearDown(container.dispose);
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(
              controller: controller,
              focusNode: focus,
              usePlainTextQuillEditor: false,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('phrase-library-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增短語'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('phrase-shortcut')),
      'arrive',
    );
    await tester.enterText(
      find.byKey(const ValueKey('phrase-tag-input')),
      '場景',
    );
    await tester.tap(find.byTooltip('新增標籤'));
    await tester.pump();
    expect(find.widgetWithText(InputChip, '場景'), findsOneWidget);
    tester.widget<InputChip>(find.widgetWithText(InputChip, '場景')).onDeleted!();
    await tester.pump();
    expect(find.widgetWithText(InputChip, '場景'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('phrase-tag-input')),
      '場景',
    );
    await tester.tap(find.byTooltip('新增標籤'));
    await tester.pump();
    final bodyField = find.descendant(
      of: find.byKey(const ValueKey('phrase-body')),
      matching: find.byType(CodeField),
    );
    await tester.tap(bodyField);
    await tester.pump();
    tester.testTextInput.enterText('她抵達了。');
    await tester.pump();
    expect(
      (tester.widget<CodeField>(bodyField).controller
              as MosaicEditingController)
          .rawText,
      '她抵達了。',
    );
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();
    expect(container.read(phrasesProvider), hasLength(1));
    expect(container.read(phrasesProvider).single.body, '她抵達了。');
    expect(container.read(phrasesProvider).single.tags, ['場景']);
    await tester.tap(find.byTooltip('關閉'));
    await tester.pumpAndSettle();
    focus.requestFocus();
    for (final character in ';;arr'.split('')) {
      final text = '${controller.text}$character';
      controller.value = controller.value.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('arrive · 她抵達了。'));
    await tester.pumpAndSettle();
    expect(controller.rawText, '前文 她抵達了。');
  });

  testWidgets('slash menu enters phrase search and keeps query', (
    tester,
  ) async {
    final container = ProviderContainer();
    final now = DateTime.utc(2026, 10, 1);
    container.read(phrasesProvider.notifier).setPhrases([
      PhraseEntry(
        id: '8f680e3c-90c1-4f37-ae35-f70c4dc7fe8f',
        name: '抵達',
        shortcut: 'arrive',
        body: '她抵達了。',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    final controller = HighlightTextEditingController(text: '前文 /');
    final focus = FocusNode();
    addTearDown(container.dispose);
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    controller.selection = const TextSelection.collapsed(offset: 4);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(
              controller: controller,
              focusNode: focus,
              usePlainTextQuillEditor: false,
            ),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('短語'));
    await tester.pumpAndSettle();
    for (final character in 'arr'.split('')) {
      final text = '${controller.text}$character';
      controller.value = controller.value.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('arrive · 她抵達了。'), findsOneWidget);
    await tester.tap(find.text('arrive · 她抵達了。'));
    await tester.pumpAndSettle();
    expect(controller.rawText, '前文 她抵達了。');
  });

  testWidgets('selection saves the complete Mosaic raw Mention', (
    tester,
  ) async {
    const mention = '//@<4e251fc2-1e2b-4f78-93da-91f8c76d9a92|艾莉絲>//';
    final controller = HighlightTextEditingController(text: '前$mention後');
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(
              controller: controller,
              focusNode: focus,
              usePlainTextQuillEditor: false,
            ),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    final range =
        controller.projection.projectedAnnotations.single.displayRange;
    tester
        .state<EditableTextState>(find.byType(EditableText))
        .userUpdateTextEditingValue(
          controller.value.copyWith(
            selection: TextSelection(
              baseOffset: range.start,
              extentOffset: range.end,
            ),
          ),
          SelectionChangedCause.longPress,
        );
    await tester.pump();
    tester.state<EditableTextState>(find.byType(EditableText)).showToolbar();
    await tester.pumpAndSettle();
    await tester.tap(find.text('存成短語'));
    await tester.pumpAndSettle();
    final body =
        tester
                .widget<CodeField>(
                  find.descendant(
                    of: find.byKey(const ValueKey('phrase-body')),
                    matching: find.byType(CodeField),
                  ),
                )
                .controller
            as MosaicEditingController;
    expect(body.rawText, mention);
  });

  testWidgets(
    'phrase content uses PoppinSense and projects Mosaic as symbol plus label',
    (tester) async {
      const id = '4e251fc2-1e2b-4f78-93da-91f8c76d9a92';
      final container = ProviderContainer();
      container.read(characterDataProvider.notifier).setCharacterData(const {
        id: CharacterEntryData(characterId: id, displayName: '艾莉絲'),
      });
      final controller = HighlightTextEditingController(text: '正文');
      final focus = FocusNode();
      addTearDown(container.dispose);
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: EditorTextBox(
                controller: controller,
                focusNode: focus,
                usePlainTextQuillEditor: false,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('phrase-library-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('新增短語'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('phrase-shortcut')),
        'alias',
      );
      final bodyField = find.descendant(
        of: find.byKey(const ValueKey('phrase-body')),
        matching: find.byType(CodeField),
      );
      final body =
          tester.widget<CodeField>(bodyField).controller
              as MosaicEditingController;
      body.setRawText('她遇見 ');
      body.selection = TextSelection.collapsed(offset: body.displayText.length);
      await tester.tap(bodyField);
      await tester.pump();
      body.value = body.value.copyWith(
        text: '${body.displayText}@',
        selection: TextSelection.collapsed(offset: body.displayText.length + 1),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('艾莉絲').first);
      await tester.pumpAndSettle();
      expect(body.rawText, '她遇見 //@<$id|艾莉絲>//');
      expect(body.displayText, contains('艾莉絲'));
      expect(body.displayText, isNot(contains('//@<')));
      expect(
        find.byKey(const ValueKey('inline-annotation-symbol-4')),
        findsOneWidget,
      );
      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();
      expect(find.text('她遇見 @艾莉絲'), findsOneWidget);
    },
  );
}
