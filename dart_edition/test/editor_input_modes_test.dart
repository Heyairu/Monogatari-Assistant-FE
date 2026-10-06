import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_localizations/flutter_localizations.dart";
import "package:flutter_quill/flutter_quill.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:monogatari_assistant/bin/content.dart";
import "package:monogatari_assistant/bin/findreplace.dart";
import "package:monogatari_assistant/presentation/providers/global_state_providers.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:monogatari_assistant/data/repositories/settings_repository.dart";
import "package:monogatari_assistant/features/editor/editor_input_rules.dart";
import "package:monogatari_assistant/features/editor/plain_text_quill_adapter.dart";
import "package:monogatari_assistant/features/editor/plain_text_quill_editor_poc.dart";
import "package:monogatari_assistant/features/inline_annotations/mosaic_editing_controller.dart";

void main() {
  test(
    "overwrite enable switch persists and immediately resets active OVR",
    () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final settings = await container.read(settingsStateProvider.future);
      expect(settings.overwriteModeEnabled, isTrue);
      container.read(editorOverwriteProvider.notifier).state = true;
      expect(container.read(editorEffectiveOverwriteProvider), isTrue);
      await container
          .read(settingsStateProvider.notifier)
          .setOverwriteModeEnabled(false);
      expect(container.read(editorOverwriteProvider), isFalse);
      expect(container.read(editorEffectiveOverwriteProvider), isFalse);
      expect(
        (await SharedPreferencesSettingsRepository().load())
            .overwriteModeEnabled,
        isFalse,
      );
      // Re-enabling permits future toggles without silently restoring OVR.
      await container
          .read(settingsStateProvider.notifier)
          .setOverwriteModeEnabled(true);
      expect(container.read(editorEffectiveOverwriteProvider), isFalse);
      container.read(editorOverwriteProvider.notifier).state = true;
      expect(container.read(editorEffectiveOverwriteProvider), isTrue);
    },
  );

  test("Tab defaults and settings persist with bounded counts", () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SharedPreferencesSettingsRepository();
    var settings = await repository.load();
    expect(
      editorTabSpaces(settings.tabSpaceCount, settings.tabFullWidth),
      "\u3000\u3000",
    );
    await repository.saveTabSpaceCount(4);
    await repository.saveTabFullWidth(false);
    settings = await repository.load();
    expect(
      editorTabSpaces(settings.tabSpaceCount, settings.tabFullWidth),
      "    ",
    );
    await repository.saveTabSpaceCount(100);
    expect((await repository.load()).tabSpaceCount, 8);
  });

  test("overwrite respects graphemes, line endings and protected ranges", () {
    expect(
      overwriteEnd("👨‍👩‍👧‍👦e\u0301尾", 0, "甲乙"),
      "👨‍👩‍👧‍👦e\u0301".length,
    );
    expect(overwriteEnd("甲\n乙", 0, "新文"), 1);
    expect(overwriteEnd("甲\r\n乙", 1, "新"), 1);
    expect(
      overwriteEnd(
        "甲乙丙",
        0,
        "新文",
        protectedRanges: [const TextRange(start: 1, end: 2)],
      ),
      1,
    );
    expect(overwriteEnd("👩尾", 1, "新"), 1);
    expect(overwriteEnd("甲乙", 0, "\n"), 0);
  });

  test("Mosaic defers OVR until IME commit and preserves annotations", () {
    final controller = MosaicEditingController(rawText: "甲乙//^<重點>//尾")
      ..overwriteEnabled = true;
    addTearDown(controller.dispose);
    final originalDisplay = controller.text;
    controller.value = TextEditingValue(
      text: "新$originalDisplay",
      selection: const TextSelection.collapsed(offset: 1),
      composing: const TextRange(start: 0, end: 1),
    );
    expect(controller.rawText, "甲乙//^<重點>//尾");
    controller.value = controller.value.copyWith(composing: TextRange.empty);
    expect(controller.rawText, "新乙//^<重點>//尾");
    controller.selection = const TextSelection.collapsed(offset: 1);
    controller.value = controller.value.copyWith(
      text: controller.text.replaceRange(1, 1, "文句"),
      selection: const TextSelection.collapsed(offset: 3),
    );
    expect(controller.rawText, "新文句//^<重點>//尾");
    controller.withoutOverwrite(() {
      controller.value = controller.value.copyWith(
        text: "貼上${controller.text}",
        selection: const TextSelection.collapsed(offset: 2),
      );
    });
    expect(controller.rawText, "貼上新文句//^<重點>//尾");
  });

  test("auto-indent defaults off and persists beside Tab settings", () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final initial = await container.read(settingsStateProvider.future);
    expect(initial.autoIndentLineStart, isFalse);
    await container
        .read(settingsStateProvider.notifier)
        .setAutoIndentLineStart(true);
    expect(
      (await SharedPreferencesSettingsRepository().load()).autoIndentLineStart,
      isTrue,
    );
    await container.read(settingsStateProvider.notifier).setTabSpaceCount(4);
    await container.read(settingsStateProvider.notifier).setTabFullWidth(false);
    final changed = container.read(settingsStateProvider).valueOrNull!;
    expect(
      editorTabSpaces(changed.tabSpaceCount, changed.tabFullWidth),
      "    ",
    );
    expect(changed.autoIndentLineStart, isTrue);
  });

  test(
    "Mosaic newline uses configured spaces and plain newline bypasses them",
    () {
      final controller = MosaicEditingController(rawText: "甲乙")
        ..autoIndentLineStart = true
        ..indentation = "  ";
      addTearDown(controller.dispose);
      controller.selection = const TextSelection.collapsed(offset: 1);
      controller.value = controller.value.copyWith(
        text: "甲\n乙",
        selection: const TextSelection.collapsed(offset: 2),
      );
      expect(controller.rawText, "甲\n  乙");
      expect(controller.selection.start, 4);
      controller.withoutAutoIndent(() {
        controller.value = controller.value.copyWith(
          text: "甲\n  \n乙",
          selection: const TextSelection.collapsed(offset: 5),
        );
      });
      expect(controller.rawText, "甲\n  \n乙");
    },
  );

  Widget editor({
    String content = "甲乙丙",
    bool overwrite = true,
    bool autoIndent = false,
    PlainTextQuillEditorCommands? commands,
    VoidCallback? toggle,
    bool Function()? acceptTab,
    String spaces = "\u3000\u3000",
    List<TextRange> protectedRanges = const [],
  }) => MaterialApp(
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      FlutterQuillLocalizations.delegate,
    ],
    home: Scaffold(
      body: PlainTextQuillEditorPoc(
        content: content,
        onChanged: (_) {},
        overwriteMode: overwrite,
        autoIndentLineStart: autoIndent,
        commands: commands,
        onToggleOverwrite: toggle,
        onTabPressed: acceptTab,
        tabSpaces: spaces,
        overwriteProtectedRanges: protectedRanges,
      ),
    ),
  );

  QuillController controllerOf(WidgetTester tester) => tester
      .widget<QuillEditor>(
        find.byKey(const ValueKey("plain-text-quill-editor")),
      )
      .controller;
  String textOf(WidgetTester tester) =>
      PlainTextQuillAdapter.toPlainText(controllerOf(tester).document);
  Future<void> focus(
    WidgetTester tester,
    PlainTextQuillEditorCommands commands,
  ) async {
    commands.requestFocus();
    await tester.pump();
  }

  void input(
    WidgetTester tester,
    String text,
    int caret, {
    TextRange composing = TextRange.empty,
  }) {
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: "$text\n",
        selection: TextSelection.collapsed(offset: caret),
        composing: composing,
      ),
    );
  }

  testWidgets(
    "Quill Tab inserts configured spaces in OVR and accepts completion first",
    (tester) async {
      final commands = PlainTextQuillEditorCommands();
      await tester.pumpWidget(editor(commands: commands));
      await focus(tester, commands);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(textOf(tester), "\u3000\u3000甲乙丙");
      expect(controllerOf(tester).selection.start, 2);
      commands.undo();
      expect(textOf(tester), "甲乙丙");
      var accepted = 0;
      await tester.pumpWidget(
        editor(
          commands: commands,
          acceptTab: () {
            accepted++;
            return true;
          },
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(accepted, 1);
      expect(textOf(tester), "甲乙丙");
    },
  );

  testWidgets("Quill OVR replaces typed graphemes with reversible history", (
    tester,
  ) async {
    final commands = PlainTextQuillEditorCommands();
    await tester.pumpWidget(
      editor(content: "👨‍👩‍👧‍👦乙丙", commands: commands),
    );
    await focus(tester, commands);
    input(tester, "新👨‍👩‍👧‍👦乙丙", 1);
    await tester.pump();
    expect(textOf(tester), "新乙丙");
    expect(controllerOf(tester).selection.start, 1);
    commands.undo();
    expect(textOf(tester), "👨‍👩‍👧‍👦乙丙");
    commands.redo();
    expect(textOf(tester), "新乙丙");
    commands.replaceSelectionWith("貼上");
    expect(textOf(tester), "新貼上乙丙");
  });

  testWidgets("Quill OVR commits IME once including composition-only changes", (
    tester,
  ) async {
    final commands = PlainTextQuillEditorCommands();
    await tester.pumpWidget(editor(commands: commands));
    await focus(tester, commands);
    input(tester, "n甲乙丙", 1, composing: const TextRange(start: 0, end: 1));
    await tester.pump();
    expect(textOf(tester), "n甲乙丙");
    input(tester, "新甲乙丙", 1, composing: const TextRange(start: 0, end: 1));
    await tester.pump();
    expect(textOf(tester), "新甲乙丙");
    input(tester, "新甲乙丙", 1);
    await tester.pump();
    expect(textOf(tester), "新乙丙");
    input(tester, "新乙丙", 1);
    await tester.pump();
    expect(textOf(tester), "新乙丙");
    commands.undo();
    expect(textOf(tester), "甲乙丙");
    commands.redo();
    expect(textOf(tester), "新乙丙");
  });

  testWidgets("Quill Ins toggles once and protected text stops overwrite", (
    tester,
  ) async {
    final commands = PlainTextQuillEditorCommands();
    var toggles = 0;
    await tester.pumpWidget(
      editor(
        commands: commands,
        toggle: () => toggles++,
        protectedRanges: [const TextRange(start: 1, end: 2)],
      ),
    );
    await focus(tester, commands);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.insert);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.insert);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.insert);
    expect(toggles, 1);
    input(tester, "新文甲乙丙", 2);
    await tester.pump();
    expect(textOf(tester), "新文乙丙");
  });
  testWidgets("CodeField uses spaces and OVR while keeping Tab insert-only", (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({"poppin_enabled": false});
    final controller = HighlightTextEditingController(text: "甲乙丙");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [editorOverwriteProvider.overrideWith((ref) => true)],
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(
              controller: controller,
              focusNode: focusNode,
              usePlainTextQuillEditor: false,
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: "新甲乙丙",
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();
    expect(controller.rawText, "新乙丙");
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(controller.rawText, "新\u3000\u3000乙丙");
    expect(controller.selection.start, 3);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(controller.rawText, "新\u3000\u3000乙丙");
  });

  testWidgets("Quill extends combining characters and keeps line boundaries", (
    tester,
  ) async {
    final commands = PlainTextQuillEditorCommands();
    await tester.pumpWidget(editor(content: "甲乙\n丙", commands: commands));
    await focus(tester, commands);
    input(tester, "e甲乙\n丙", 1);
    await tester.pump();
    expect(textOf(tester), "e乙\n丙");
    input(tester, "e\u0301乙\n丙", 2);
    await tester.pump();
    expect(textOf(tester), "e\u0301乙\n丙");
    input(tester, "e\u0301新文乙\n丙", 4);
    await tester.pump();
    expect(textOf(tester), "e\u0301新文\n丙");
    input(tester, "e\u0301新文尾\n丙", 5);
    await tester.pump();
    expect(textOf(tester), "e\u0301新文尾\n丙");
  });

  testWidgets(
    "Quill cancellation, selection replacement and INS do not delete neighbors",
    (tester) async {
      final commands = PlainTextQuillEditorCommands();
      await tester.pumpWidget(editor(commands: commands));
      await focus(tester, commands);
      input(tester, "n甲乙丙", 1, composing: const TextRange(start: 0, end: 1));
      await tester.pump();
      input(tester, "甲乙丙", 0);
      await tester.pump();
      expect(textOf(tester), "甲乙丙");
      controllerOf(tester).updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 2),
        ChangeSource.local,
      );
      await tester.pump();
      input(tester, "新丙", 1);
      await tester.pump();
      expect(textOf(tester), "新丙");
      await tester.pumpWidget(
        editor(content: "新丙", commands: commands, overwrite: false),
      );
      input(tester, "新文丙", 2);
      await tester.pump();
      expect(textOf(tester), "新文丙");
    },
  );
  for (final useQuill in [true, false]) {
    testWidgets(
      "disabled overwrite blocks Ins and keeps insertion in ${useQuill ? 'Quill' : 'CodeField'}",
      (tester) async {
        SharedPreferences.setMockInitialValues({
          "editor_overwrite_mode_enabled": false,
        });
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await container.read(settingsStateProvider.future);
        final controller = HighlightTextEditingController(text: "甲乙");
        final focusNode = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(focusNode.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                FlutterQuillLocalizations.delegate,
              ],
              home: Scaffold(
                body: EditorTextBox(
                  controller: controller,
                  focusNode: focusNode,
                  usePlainTextQuillEditor: useQuill,
                ),
              ),
            ),
          ),
        );
        focusNode.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.insert);
        await tester.pump();
        expect(container.read(editorOverwriteProvider), isFalse);
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: useQuill ? "新甲乙\n" : "新甲乙",
            selection: const TextSelection.collapsed(offset: 1),
          ),
        );
        await tester.pump();
        expect(controller.rawText, "新甲乙");
      },
    );
  }
  testWidgets(
    "Quill Enter indents, Shift+Enter stays plain, and Undo restores",
    (tester) async {
      final commands = PlainTextQuillEditorCommands();
      await tester.pumpWidget(
        editor(
          content: "甲乙",
          overwrite: false,
          autoIndent: true,
          spaces: "  ",
          commands: commands,
        ),
      );
      await focus(tester, commands);
      controllerOf(tester).updateSelection(
        const TextSelection.collapsed(offset: 1),
        ChangeSource.local,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(textOf(tester), "甲\n  乙");
      expect(controllerOf(tester).selection.start, 4);
      commands.undo();
      await tester.pump();
      expect(textOf(tester), "甲乙");
      commands.redo();
      await tester.pump();
      expect(textOf(tester), "甲\n  乙");
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(textOf(tester), "甲\n  \n乙");
    },
  );

  testWidgets(
    "Quill virtual newline indents; disabled mode keeps plain newline",
    (tester) async {
      final commands = PlainTextQuillEditorCommands();
      await tester.pumpWidget(
        editor(
          content: "甲乙",
          overwrite: false,
          autoIndent: true,
          commands: commands,
        ),
      );
      await focus(tester, commands);
      controllerOf(tester).updateSelection(
        const TextSelection.collapsed(offset: 1),
        ChangeSource.local,
      );
      input(tester, "甲\n乙", 2);
      await tester.pump();
      expect(textOf(tester), "甲\n\u3000\u3000乙");
      await tester.pumpWidget(
        editor(
          content: "甲\n\u3000\u3000乙",
          overwrite: false,
          autoIndent: false,
          commands: commands,
        ),
      );
      input(tester, "甲\n\u3000\u3000\n乙", 5);
      await tester.pump();
      expect(textOf(tester), "甲\n\u3000\u3000\n乙");
    },
  );

  testWidgets("Quill completion retains Enter priority", (tester) async {
    final commands = PlainTextQuillEditorCommands();
    var accepted = 0;
    await tester.pumpWidget(
      editor(
        content: "甲乙",
        autoIndent: true,
        commands: commands,
        acceptTab: () {
          accepted++;
          return true;
        },
      ),
    );
    await focus(tester, commands);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(accepted, 1);
    expect(textOf(tester), "甲乙");
  });

  testWidgets("CodeField Enter indents and Shift+Enter stays plain", (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      "editor_auto_indent_line_start": true,
      "editor_tab_full_width": false,
      "editor_tab_space_count": 2,
      "poppin_enabled": false,
    });
    final controller = HighlightTextEditingController(text: "甲乙");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(
              controller: controller,
              focusNode: focusNode,
              usePlainTextQuillEditor: false,
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    controller.selection = const TextSelection.collapsed(offset: 1);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.rawText, "甲\n  乙");
    expect(controller.selection.start, 4);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(controller.rawText, "甲\n  \n乙");
  });
}
