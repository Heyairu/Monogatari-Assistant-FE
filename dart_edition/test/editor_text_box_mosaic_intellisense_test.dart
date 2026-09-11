import "dart:ui" show SemanticsAction, Tristate;

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/content.dart";
import "package:monogatari_assistant/bin/findreplace.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation_projection.dart";
import "package:monogatari_assistant/models/character_data.dart";
import "package:monogatari_assistant/models/outline_data.dart" as outline_model;
import "package:monogatari_assistant/models/world_settings_data.dart"
    as world_model;
import "package:monogatari_assistant/presentation/providers/global_state_providers.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    "target completion supports keyboard selection and one insertion",
    (tester) async {
      const aliceId = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";
      const bobId = "65388495-7eb2-4a2c-9258-3af82aa27791";
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(characterDataProvider.notifier).setCharacterData(const {
        aliceId: CharacterEntryData(characterId: aliceId, displayName: "艾莉絲"),
        bobId: CharacterEntryData(characterId: bobId, displayName: "鮑伯"),
      });
      final controller = HighlightTextEditingController(text: "她看見 @");
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: EditorTextBox(controller: controller, focusNode: focusNode),
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey("mosaic-completion-panel")),
        findsOneWidget,
      );
      final editable = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      final caretBottom = editable.renderEditable.localToGlobal(
        editable.renderEditable
            .getLocalRectForCaret(
              TextPosition(offset: controller.selection.extentOffset),
            )
            .bottomLeft,
      );
      final panelTop = tester.getTopLeft(
        find.byKey(const ValueKey("mosaic-completion-panel")),
      );
      expect(panelTop.dx, closeTo(caretBottom.dx, 1));
      expect(panelTop.dy, closeTo(caretBottom.dy + 4, 1));
      expect(find.text("艾莉絲"), findsOneWidget);
      expect(find.text("鮑伯"), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(controller.rawText, "她看見 //@<$bobId|鮑伯>//");
      expect(controller.text, "她看見 $inlineAnnotationPlaceholder鮑伯");
      expect(
        find.byKey(const ValueKey("mosaic-completion-panel")),
        findsNothing,
      );
    },
  );

  testWidgets("keyboard selection scrolls the active candidate into view", (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final characters = <String, CharacterEntryData>{};
    for (var index = 0; index < 12; index++) {
      final id = "00000000-0000-4000-8000-${index.toString().padLeft(12, "0")}";
      characters[id] = CharacterEntryData(
        characterId: id,
        displayName: "人物${index.toString().padLeft(2, "0")}",
      );
    }
    container.read(characterDataProvider.notifier).setCharacterData(characters);
    final controller = HighlightTextEditingController(text: "正文@");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    controller.selection = const TextSelection.collapsed(offset: 3);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(controller: controller, focusNode: focusNode),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    await tester.pump();

    for (var index = 0; index < 9; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    await tester.pump();

    final selectedId =
        "00000000-0000-4000-8000-${9.toString().padLeft(12, "0")}";
    final listRect = tester.getRect(
      find.byKey(const ValueKey("mosaic-completion-list")),
    );
    final selectedRect = tester.getRect(
      find.byKey(ValueKey("mosaic-completion-$selectedId")),
    );
    expect(selectedRect.top, greaterThanOrEqualTo(listRect.top));
    expect(selectedRect.bottom, lessThanOrEqualTo(listRect.bottom));
  });

  testWidgets("escape closes completion without changing raw text", (
    tester,
  ) async {
    final controller = HighlightTextEditingController(text: "文字/");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(controller: controller, focusNode: focusNode),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    expect(
      find.byKey(const ValueKey("mosaic-completion-panel")),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(controller.rawText, "文字/");
    expect(find.byKey(const ValueKey("mosaic-completion-panel")), findsNothing);
  });

  testWidgets("typing slash, backslash, or hash opens IntelliSense", (
    tester,
  ) async {
    final controller = HighlightTextEditingController(text: "文字");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(controller: controller, focusNode: focusNode),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    await tester.enterText(find.byType(EditableText), "文字/");
    await tester.pump();
    expect(
      find.byKey(const ValueKey("mosaic-completion-panel")),
      findsOneWidget,
    );
    expect(find.text("@"), findsOneWidget);

    await tester.enterText(find.byType(EditableText), "文字");
    await tester.pump();
    expect(find.byKey(const ValueKey("mosaic-completion-panel")), findsNothing);

    await tester.enterText(find.byType(EditableText), "文字\\");
    await tester.pump();
    expect(
      find.byKey(const ValueKey("mosaic-completion-panel")),
      findsOneWidget,
    );
    expect(find.text("@"), findsOneWidget);

    await tester.enterText(find.byType(EditableText), "文字#");
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const ValueKey("mosaic-completion-panel")),
      findsOneWidget,
    );
    expect(find.text("新增事件…"), findsOneWidget);
  });

  testWidgets("disabled Poppin preserves trigger input without opening", (
    tester,
  ) async {
    final controller = HighlightTextEditingController(text: "文字");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsStateProvider.overrideWith(
            _DisabledPoppinSettingsNotifier.new,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(controller: controller, focusNode: focusNode),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    focusNode.requestFocus();
    await tester.enterText(find.byType(EditableText), "文字/");
    await tester.pump();

    expect(controller.rawText, "文字/");
    expect(controller.displayText, "文字/");
    expect(find.byKey(const ValueKey("mosaic-completion-panel")), findsNothing);
  });

  testWidgets("escaped manual input stays literal and is never eaten", (
    tester,
  ) async {
    final controller = HighlightTextEditingController(text: "文字");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(controller: controller, focusNode: focusNode),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    await tester.enterText(find.byType(EditableText), r"文字\/");
    await tester.pump();
    expect(controller.rawText, r"文字\/");
    expect(controller.displayText, "文字/");
    expect(find.byKey(const ValueKey("mosaic-completion-panel")), findsNothing);

    controller.setRawText("文字");
    await tester.enterText(find.byType(EditableText), r"文字\\");
    await tester.pump();
    expect(controller.rawText, r"文字\\");
    expect(controller.displayText, "文字\\");
    expect(find.byKey(const ValueKey("mosaic-completion-panel")), findsNothing);

    controller.setRawText("文字");
    await tester.enterText(find.byType(EditableText), "文字\\");
    await tester.pump();
    expect(
      find.byKey(const ValueKey("mosaic-completion-panel")),
      findsOneWidget,
    );
    await tester.enterText(find.byType(EditableText), "文字\\\\");
    await tester.pump();
    expect(controller.rawText, r"文字\\");
    expect(controller.displayText, "文字\\");
    expect(find.byKey(const ValueKey("mosaic-completion-panel")), findsNothing);
    await tester.enterText(find.byType(EditableText), r"文字\/");
    await tester.pump();
    expect(controller.rawText, r"文字\\/");
    expect(controller.displayText, r"文字\/");
    expect(find.byKey(const ValueKey("mosaic-completion-panel")), findsNothing);

    controller.setRawText("文字");
    await tester.enterText(find.byType(EditableText), "文字/x");
    await tester.pump();
    expect(controller.rawText, "文字/x");
    expect(find.byKey(const ValueKey("mosaic-completion-panel")), findsNothing);

    controller.setRawText("文字");
    await tester.enterText(find.byType(EditableText), "文字\\\\\\");
    await tester.pump();
    expect(controller.rawText, "文字\\\\\\");
    expect(controller.displayText, "文字\\\\");
    expect(
      find.byKey(const ValueKey("mosaic-completion-panel")),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(controller.rawText, "文字\\\\\\");

    controller.setRawText("文字");
    await tester.enterText(find.byType(EditableText), "文字\\\\/");
    await tester.pump();
    expect(controller.rawText, "文字\\\\/");
    expect(controller.displayText, "文字\\/");
    expect(find.byKey(const ValueKey("mosaic-completion-panel")), findsNothing);

    controller.setRawText("文字");
    await tester.enterText(find.byType(EditableText), r"文字\//");
    await tester.pump();
    expect(
      find.byKey(const ValueKey("mosaic-completion-panel")),
      findsOneWidget,
    );
    for (var index = 0; index < 6; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.rawText, "文字//@<");
  });

  testWidgets("IME composition suppresses Poppin until text is committed", (
    tester,
  ) async {
    final controller = HighlightTextEditingController(text: "文字");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(controller: controller, focusNode: focusNode),
          ),
        ),
      ),
    );
    await tester.showKeyboard(find.byType(EditableText));
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: "文字/",
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 2, end: 3),
      ),
    );
    await tester.pump();

    expect(controller.rawText, "文字/");
    expect(controller.value.composing, const TextRange(start: 2, end: 3));
    expect(find.byKey(const ValueKey("mosaic-completion-panel")), findsNothing);

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: "文字/",
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    await tester.pump();

    expect(controller.value.composing, TextRange.empty);
    expect(
      find.byKey(const ValueKey("mosaic-completion-panel")),
      findsOneWidget,
    );
  });

  testWidgets("completion exposes separate select and expand semantics", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = HighlightTextEditingController(text: "正文/");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    controller.selection = const TextSelection.collapsed(offset: 3);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(controller: controller, focusNode: focusNode),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    final characterCandidate = find.byKey(
      const ValueKey("mosaic-completion-manual-character"),
    );
    final candidateData = tester
        .getSemantics(characterCandidate)
        .getSemanticsData();
    expect(candidateData.label, "@，人物候選");
    expect(candidateData.hint, "按 Enter 選取，按向右鍵展開下一層");
    expect(candidateData.flagsCollection.isButton, isTrue);
    expect(candidateData.flagsCollection.isSelected, Tristate.isTrue);
    expect(candidateData.hasAction(SemanticsAction.tap), isTrue);
    expect(find.byTooltip("展開 @ 的下一層"), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey("mosaic-completion-expand-manual-character")),
    );
    await tester.pump();
    expect(find.bySemanticsLabel("返回 @"), findsOneWidget);
    semantics.dispose();
  });

  testWidgets("tab accepts the selected completion target", (tester) async {
    const aliceId = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(characterDataProvider.notifier).setCharacterData(const {
      aliceId: CharacterEntryData(characterId: aliceId, displayName: "艾莉絲"),
    });
    final controller = HighlightTextEditingController(text: "正文@");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    controller.selection = const TextSelection.collapsed(offset: 3);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(controller: controller, focusNode: focusNode),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(controller.rawText, "正文//@<$aliceId|艾莉絲>//");
    expect(find.byKey(const ValueKey("mosaic-completion-panel")), findsNothing);
  });

  testWidgets("typing after a category trigger incrementally filters targets", (
    tester,
  ) async {
    const aliceId = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";
    const bobId = "65388495-7eb2-4a2c-9258-3af82aa27791";
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(characterDataProvider.notifier).setCharacterData(const {
      aliceId: CharacterEntryData(characterId: aliceId, displayName: "艾莉絲"),
      bobId: CharacterEntryData(characterId: bobId, displayName: "鮑伯"),
    });
    final controller = HighlightTextEditingController(text: "正文@");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(controller: controller, focusNode: focusNode),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    await tester.enterText(find.byType(EditableText), "正文@艾");
    await tester.pump();

    expect(find.text("艾莉絲"), findsOneWidget);
    expect(find.text("鮑伯"), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(controller.rawText, "正文//@<$aliceId|艾莉絲>//");
    expect(controller.text, "正文$inlineAnnotationPlaceholder艾莉絲");
  });

  testWidgets("direct category state is retained when accepting a target", (
    tester,
  ) async {
    const aliceId = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(characterDataProvider.notifier).setCharacterData(const {
      aliceId: CharacterEntryData(characterId: aliceId, displayName: "艾莉絲"),
    });
    final controller = HighlightTextEditingController(text: "正文@+艾");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(controller: controller, focusNode: focusNode),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(controller.rawText, "正文//@+<$aliceId|艾莉絲>//");
    expect(controller.text, "正文$inlineAnnotationPlaceholder艾莉絲");
  });

  testWidgets("external less-than browses object types and inserts a target", (
    tester,
  ) async {
    const aliceId = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(characterDataProvider.notifier).setCharacterData(const {
      aliceId: CharacterEntryData(characterId: aliceId, displayName: "艾莉絲"),
    });
    final controller = HighlightTextEditingController(text: "正文<");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(controller: controller, focusNode: focusNode),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    await tester.pump();

    expect(find.text("@ 人物"), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey("mosaic-completion-expand-object-character")),
    );
    await tester.pump();
    expect(find.text("艾莉絲"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey("mosaic-completion-$aliceId")));
    await tester.pump();

    expect(controller.rawText, "正文//@<$aliceId|艾莉絲>//");
    expect(controller.text, "正文$inlineAnnotationPlaceholder艾莉絲");
  });

  testWidgets("escape from external less-than keeps its literal text", (
    tester,
  ) async {
    final controller = HighlightTextEditingController(text: "正文<");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(controller: controller, focusNode: focusNode),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(controller.rawText, "正文<");
    expect(find.byKey(const ValueKey("mosaic-completion-panel")), findsNothing);
  });

  testWidgets("highlight submenu writes background and foreground colors", (
    tester,
  ) async {
    final controller = HighlightTextEditingController(text: "正文^");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(controller: controller, focusNode: focusNode),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey("mosaic-completion-expand-highlight-C")),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey("mosaic-completion-back")),
      findsOneWidget,
    );
    for (var index = 0; index < 5; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(controller.rawText, "正文//^CE<");
    expect(find.byKey(const ValueKey("mosaic-completion-panel")), findsNothing);
  });

  testWidgets(
    "create character keeps cancellation safe and inserts the result",
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = HighlightTextEditingController(text: "正文@");
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: EditorTextBox(controller: controller, focusNode: focusNode),
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey("mosaic-completion-create-character")),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text("取消"));
      await tester.pumpAndSettle();
      expect(controller.rawText, "正文@");
      expect(container.read(characterDataProvider), isEmpty);

      await tester.tap(
        find.byKey(const ValueKey("mosaic-completion-create-character")),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey("mosaic-create-target-name")),
        "艾莉絲",
      );
      await tester.tap(
        find.byKey(const ValueKey("mosaic-create-target-submit")),
      );
      await tester.pumpAndSettle();

      final created = container.read(characterDataProvider).values.single;
      expect(created.displayName, "艾莉絲");
      expect(controller.rawText, "正文//@<${created.characterId}|艾莉絲>//");
      expect(
        find.byKey(const ValueKey("mosaic-completion-panel")),
        findsNothing,
      );
    },
  );

  testWidgets("create location inside the currently expanded parent", (
    tester,
  ) async {
    const rootId = "da268faa-95d6-477d-b2c9-6a4d6c1cb06d";
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(worldSettingsDataProvider.notifier).setWorldSettingsData([
      world_model.LocationData(id: rootId, localName: "王都"),
    ]);
    final controller = HighlightTextEditingController(text: "正文!");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(controller: controller, focusNode: focusNode),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey("mosaic-completion-expand-$rootId")),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey("mosaic-completion-create-location-$rootId-1")),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey("mosaic-create-target-name")),
      "舊城區",
    );
    await tester.tap(find.byKey(const ValueKey("mosaic-create-target-submit")));
    await tester.pumpAndSettle();

    final child = container.read(worldSettingsDataProvider).single.child.single;
    expect(child.localName, "舊城區");
    expect(controller.rawText, "正文//!<${child.id}|舊城區>//");
  });

  testWidgets("create event inside the currently expanded storyline", (
    tester,
  ) async {
    const storylineId = "b2a65ea0-40fe-4e31-8dd8-da8dff633410";
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(outlineDataProvider.notifier).setOutlineData([
      outline_model.StorylineData(
        chapterUUID: storylineId,
        storylineName: "第一卷",
      ),
    ]);
    final controller = HighlightTextEditingController(text: "正文#");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(controller: controller, focusNode: focusNode),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey("mosaic-completion-expand-$storylineId")),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(
        const ValueKey("mosaic-completion-create-event-$storylineId-1"),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey("mosaic-create-target-name")),
      "王都篇",
    );
    await tester.tap(find.byKey(const ValueKey("mosaic-create-target-submit")));
    await tester.pumpAndSettle();

    final event = container.read(outlineDataProvider).single.scenes.single;
    expect(event.storyEvent, "王都篇");
    expect(controller.rawText, "正文//#<${event.storyEventUUID}|王都篇>//");
  });

  testWidgets("hash can select both large and middle outline boxes", (
    tester,
  ) async {
    const storylineId = "b2a65ea0-40fe-4e31-8dd8-da8dff633410";
    const eventId = "3837044f-9a59-47f4-a917-d80765577861";
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(outlineDataProvider.notifier).setOutlineData(const [
      outline_model.StorylineData.raw(
        chapterUUID: storylineId,
        storylineName: "第一卷",
        scenes: [
          outline_model.StoryEventData.raw(
            storyEventUUID: eventId,
            storyEvent: "王都篇",
          ),
        ],
      ),
    ]);
    final controller = HighlightTextEditingController(text: "正文#");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    controller.selection = const TextSelection.collapsed(offset: 3);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(controller: controller, focusNode: focusNode),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey("mosaic-completion-$storylineId")),
    );
    await tester.pump();
    expect(controller.rawText, "正文//#<$storylineId|第一卷>//");

    controller.setRawText("正文#");
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey("mosaic-completion-expand-$storylineId")),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey("mosaic-completion-$eventId")));
    await tester.pump();
    expect(controller.rawText, "正文//#<$eventId|王都篇>//");
  });

  testWidgets("create scene inside the currently expanded event", (
    tester,
  ) async {
    const storylineId = "b2a65ea0-40fe-4e31-8dd8-da8dff633410";
    const eventId = "3837044f-9a59-47f4-a917-d80765577861";
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(outlineDataProvider.notifier).setOutlineData([
      outline_model.StorylineData(
        chapterUUID: storylineId,
        storylineName: "第一卷",
        scenes: [
          outline_model.StoryEventData(
            storyEventUUID: eventId,
            storyEvent: "王都篇",
          ),
        ],
      ),
    ]);
    final controller = HighlightTextEditingController(text: "正文#");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(controller: controller, focusNode: focusNode),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey("mosaic-completion-expand-$storylineId")),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey("mosaic-completion-expand-$eventId")),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey("mosaic-completion-create-event-$eventId-2")),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey("mosaic-create-target-name")),
      "城門衝突",
    );
    await tester.tap(find.byKey(const ValueKey("mosaic-create-target-submit")));
    await tester.pumpAndSettle();

    final scene = container
        .read(outlineDataProvider)
        .single
        .scenes
        .single
        .scenes
        .single;
    expect(scene.sceneName, "城門衝突");
    expect(controller.rawText, "正文//#<${scene.sceneUUID}|城門衝突>//");
  });

  testWidgets("right opens and left closes the manual category submenu", (
    tester,
  ) async {
    const characterId = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(characterDataProvider.notifier).setCharacterData(const {
      characterId: CharacterEntryData(
        characterId: characterId,
        displayName: "艾莉絲",
        aliases: [
          CharacterAlias(values: ["小艾"]),
        ],
      ),
    });
    final controller = HighlightTextEditingController(text: "正文/");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(controller: controller, focusNode: focusNode),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pump();
    await tester.pump();

    expect(find.text("@"), findsOneWidget);
    expect(find.text("小艾"), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey("mosaic-completion-expand-manual-character")),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey("mosaic-completion-back")),
      findsOneWidget,
    );
    expect(find.text("艾莉絲"), findsOneWidget);
    expect(find.text("小艾"), findsNothing);
    await tester.tap(
      find.byKey(ValueKey("mosaic-completion-expand-$characterId")),
    );
    await tester.pump();
    expect(find.text("@ › 艾莉絲"), findsOneWidget);
    expect(find.text("小艾"), findsOneWidget);
    expect(find.text("人物 · 艾莉絲的別名"), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.text("小艾"), findsNothing);
    expect(find.text("艾莉絲"), findsOneWidget);
    await tester.tap(
      find.byKey(ValueKey("mosaic-completion-expand-$characterId")),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(ValueKey("mosaic-completion-$characterId:alias:0")),
    );
    await tester.pump();

    expect(controller.rawText, "正文//@<$characterId|小艾>//");
  });

  testWidgets("collapsed annotation badge occupies its reserved Mention slot", (
    tester,
  ) async {
    const uuid = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";
    final controller = HighlightTextEditingController(
      text: "前//@<$uuid|艾莉絲>//後",
    );
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(controller: controller, focusNode: focusNode),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final semantics = tester.ensureSemantics();

    expect(
      find.byKey(const ValueKey("inline-annotation-symbol-1")),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel("人物標記：艾莉絲"), findsOneWidget);
    expect(find.text("@"), findsOneWidget);
    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    final slotCaret = editable.renderEditable.getLocalRectForCaret(
      const TextPosition(offset: 1),
    );
    final slotStart = editable.renderEditable.localToGlobal(slotCaret.topLeft);
    final slotEnd = editable.renderEditable.localToGlobal(
      editable.renderEditable
          .getLocalRectForCaret(const TextPosition(offset: 2))
          .topLeft,
    );
    final badgeFinder = find.byKey(
      const ValueKey("inline-annotation-symbol-1"),
    );
    expect(tester.getTopLeft(badgeFinder).dx, closeTo(slotStart.dx, 1));
    expect(tester.getTopLeft(badgeFinder).dy, closeTo(slotStart.dy, 1));
    expect(
      tester.getSize(badgeFinder).width,
      closeTo(slotEnd.dx - slotStart.dx, 1),
    );
    expect(tester.getSize(badgeFinder).height, closeTo(slotCaret.height, 1));
    semantics.dispose();
  });

  testWidgets("pointer click keeps Mention collapsed and reports its anchor", (
    tester,
  ) async {
    const uuid = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";
    final controller = HighlightTextEditingController(
      text: "前//@<$uuid|艾莉絲>//後",
    );
    final focusNode = FocusNode();
    EditorTextInteraction? interaction;
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(
              controller: controller,
              focusNode: focusNode,
              onInteractionOffset: (value) => interaction = value,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    final caret = editable.renderEditable.getLocalRectForCaret(
      const TextPosition(offset: 2),
    );
    final tapPosition = editable.renderEditable.localToGlobal(
      caret.centerLeft + const Offset(1, 0),
    );

    await tester.tapAt(tapPosition);
    await tester.pump();
    await tester.pump();

    expect(interaction, isNotNull);
    expect(interaction!.globalPosition, tapPosition);
    expect(controller.activeAnnotationStart, isNull);
    expect(controller.text, "前$inlineAnnotationPlaceholder艾莉絲後");
  });

  testWidgets("arrow keys skip and delete keys remove an atomic Mention", (
    tester,
  ) async {
    const uuid = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";
    const raw = "A//@<$uuid|艾莉絲>//B";
    final controller = HighlightTextEditingController(text: raw);
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EditorTextBox(controller: controller, focusNode: focusNode),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    var entry = controller.projection.projectedAnnotations.single;
    controller.selection = TextSelection.collapsed(
      offset: entry.displayRange.start,
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(controller.selection.extentOffset, entry.displayRange.end);
    expect(controller.text, "A$inlineAnnotationPlaceholder艾莉絲B");
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(controller.selection.extentOffset, entry.displayRange.end + 1);

    controller.selection = TextSelection.collapsed(
      offset: entry.displayRange.end - 1,
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(controller.selection.extentOffset, entry.displayRange.start);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(controller.selection.extentOffset, entry.displayRange.start - 1);

    controller.selection = TextSelection.collapsed(
      offset: entry.displayRange.end,
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(controller.rawText, "AB");

    controller.setRawText(raw);
    entry = controller.projection.projectedAnnotations.single;
    controller.selection = TextSelection.collapsed(
      offset: entry.displayRange.start,
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();
    expect(controller.rawText, "AB");
  });
}

final class _DisabledPoppinSettingsNotifier extends SettingsStateNotifier {
  @override
  Future<AppSettingsStateData> build() async =>
      const AppSettingsStateData(poppinEnabled: false);
}
