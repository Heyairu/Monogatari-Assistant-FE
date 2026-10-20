import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_localizations/flutter_localizations.dart";
import "package:flutter_quill/flutter_quill.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ribbon/material_ribbon.dart";
import "package:monogatari_assistant/bin/appbar.dart";
import "package:monogatari_assistant/bin/findreplace.dart";
import "package:monogatari_assistant/main.dart";
import "package:monogatari_assistant/models/toolbar_mode.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";
import "package:shared_preferences/shared_preferences.dart";

void main() {
  test("search option constraints preserve regex and whole-word rules", () {
    final options = FindReplaceOptions(
      matchCase: false,
      matchWidth: false,
      wholeWord: true,
    );
    options.setOption(FindReplaceOption.useRegexp, true, "cat");
    expect(options.matchCase, isTrue);
    expect(options.matchWidth, isTrue);
    expect(options.wholeWord, isFalse);
    options.setOption(FindReplaceOption.matchCase, false, "cat");
    expect(options.matchCase, isTrue);
    options.setOption(FindReplaceOption.useRegexp, false, "cat");
    options.setOption(FindReplaceOption.wholeWord, true, "cat");
    expect(options.wholeWord, isTrue);
    for (final query in ["cat dog", "cat!", "全形", "ｃａｔ"]) {
      final copy = options.copy()..normalizeForQuery(query);
      expect(copy.wholeWord, isFalse);
      expect(copy.enabledFor(FindReplaceOption.wholeWord, query), isFalse);
    }
    expect(options.wholeWord, isTrue);
  });

  for (final mode in ToolbarMode.values) {
    testWidgets("${mode.name} search page controls all six options", (
      tester,
    ) async {
      final options = FindReplaceOptions();
      final invoked = <FindReplaceOption>[];
      var open = false;
      await tester.binding.setSurfaceSize(const Size(1600, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, update) => Scaffold(
              appBar: MonogatariTopAppBar(
                iconSize: 22,
                mode: mode,
                modePreference: mode,
                onModeChanged: (_) {},
                showPunctuationPanel: false,
                showFindReplaceWindow: open,
                searchOptions: options.copy(),
                searchQuery: "cat",
                onSearchOptionChanged: (option) => update(() {
                  invoked.add(option);
                  options.setOption(option, !options.valueFor(option), "cat");
                }),
                onFileAction: (_) async {},
                onEditorAction: (_) async {},
                onEditorActionPointerDown: () {},
                onEditorActionInteractionEnd: () {},
                onTogglePunctuationPanel: () {},
                onToggleFindReplaceWindow: () => update(() => open = !open),
              ),
            ),
          ),
        ),
      );
      final searchTab = find.ancestor(
        of: find.text("搜尋"),
        matching: find.byType(ChoiceChip),
      );
      await tester.tap(searchTab);
      await tester.pump();
      expect(open, isTrue);
      void expectVisibleStates() {
        if (mode == ToolbarMode.full) return;
        for (final option in FindReplaceOption.values) {
          final button = find.byKey(
            ValueKey("toolbar-command-search.${option.name}"),
          );
          final selected = options.valueFor(option);
          expect(tester.widget<IconButton>(button).isSelected, selected);
          expect(
            find.descendant(
              of: button,
              matching: find.byIcon(selected ? Icons.check : Icons.close),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: button,
              matching: find.text(selected ? "開" : "關"),
            ),
            mode == ToolbarMode.moderate ? findsOneWidget : findsNothing,
          );
        }
      }

      expectVisibleStates();
      for (final label in [
        "大小寫需相同",
        "全字拼寫相符",
        "全半形須相符",
        "略過標點符號",
        "略過空白字元",
        "使用正則表示",
      ]) {
        await tester.tap(find.byTooltip(label));
        await tester.pump();
        expectVisibleStates();
      }
      expect(invoked.toSet(), FindReplaceOption.values.toSet());
      expect(options.ignorePunctuation, isTrue);
      expect(options.ignoreWhitespace, isTrue);
      expect(options.useRegexp, isTrue);
      final ribbon = tester.widget<MaterialRibbon>(find.byType(MaterialRibbon));
      final commands = ribbon.tabs
          .firstWhere((tab) => tab.id == "search")
          .groups
          .expand((group) => group.commands);
      for (final option in [
        FindReplaceOption.matchCase,
        FindReplaceOption.matchWidth,
        FindReplaceOption.wholeWord,
      ]) {
        expect(
          commands
              .firstWhere((command) => command.id == "search.${option.name}")
              .enabledFor(const RibbonContext()),
          isFalse,
        );
      }
    });

    testWidgets(
      "${mode.name} production search refreshes from Ribbon options",
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          "toolbar_mode": mode.name,
        });
        const backgroundChannel = MethodChannel(
          "com.heyairu.monogatari_assistant/background_execution",
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          backgroundChannel,
          (_) async => true,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            backgroundChannel,
            null,
          ),
        );
        await tester.binding.setSurfaceSize(const Size(2400, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: [
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                FlutterQuillLocalizations.delegate,
              ],
              home: ContentView(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        container
            .read(editorContentProvider.notifier)
            .setContent("cat CAT cat!");
        await tester.pump();
        await tester.tap(find.byTooltip("搜尋"));
        await tester.pump();
        expect(
          tester
              .widget<MaterialRibbon>(find.byType(MaterialRibbon))
              .selectedTabId,
          "search",
        );
        var bar = tester.widget<FindReplaceBar>(find.byType(FindReplaceBar));
        expect(bar.onOptionsRequested, isNotNull);
        bar.findController.text = "cat";

        Future<void> expectCount(int count) async {
          for (var attempt = 0; attempt < 40; attempt++) {
            await tester.pump(const Duration(milliseconds: 150));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump();
            if (tester
                    .widget<FindReplaceBar>(find.byType(FindReplaceBar))
                    .totalMatches ==
                count) {
              return;
            }
          }
          expect(
            tester
                .widget<FindReplaceBar>(find.byType(FindReplaceBar))
                .totalMatches,
            count,
          );
        }

        await expectCount(2);
        await tester.tap(find.byTooltip("大小寫需相同"));
        await tester.pump();
        await expectCount(3);
        bar = tester.widget<FindReplaceBar>(find.byType(FindReplaceBar));
        expect(bar.options.matchCase, isFalse);
        expect(container.read(editorContentProvider), "cat CAT cat!");
        await tester.tap(find.text("常用"));
        await tester.pump();
        await tester.tap(find.byTooltip("搜尋選項"));
        await tester.pump();
        expect(
          tester
              .widget<MaterialRibbon>(find.byType(MaterialRibbon))
              .selectedTabId,
          "search",
        );
        expect(find.byType(FilterChip), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}
