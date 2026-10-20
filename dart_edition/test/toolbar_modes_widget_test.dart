import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ribbon/material_ribbon.dart";
import "package:monogatari_assistant/bin/appbar.dart";
import "package:monogatari_assistant/models/toolbar_mode.dart";

void main() {
  Widget app(
    ToolbarMode mode, {
    Future<void> Function(String)? onFileAction,
    Future<void> Function(String)? onEditorAction,
    bool isBusy = false,
    double textScale = 1,
    ValueChanged<ToolbarMode?>? onModeChanged,
  }) => MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      appBar: MonogatariTopAppBar(
        iconSize: 22,
        mode: mode,
        modePreference: mode,
        onModeChanged: onModeChanged ?? (_) {},
        isProjectIoBusy: isBusy,
        showPunctuationPanel: false,
        showFindReplaceWindow: false,
        onFileAction: onFileAction ?? (_) async {},
        onEditorAction: onEditorAction ?? (_) async {},
        onEditorActionPointerDown: () {},
        onEditorActionInteractionEnd: () {},
        onTogglePunctuationPanel: () {},
        onToggleFindReplaceWindow: () {},
      ),
    ),
  );

  testWidgets("Full uses ribbon tabs and groups", (tester) async {
    final actions = <String>[];
    await tester.pumpWidget(
      app(ToolbarMode.full, onFileAction: (id) async => actions.add(id)),
    );
    expect(find.byType(MaterialRibbon), findsOneWidget);
    expect(find.text("剪貼簿"), findsOneWidget);
    await tester.tap(find.byTooltip("儲存檔案"));
    await tester.pump();
    expect(actions, ["save"]);
    await tester.tap(find.text("檔案"));
    await tester.pump();
    expect(find.byTooltip("另存新檔"), findsOneWidget);
  });

  testWidgets("Moderate shows inline labels; Concise keeps only icons", (
    tester,
  ) async {
    for (final mode in [ToolbarMode.moderate, ToolbarMode.concise]) {
      await tester.pumpWidget(app(mode));
      expect(find.byType(MaterialRibbon), findsOneWidget);
      expect(
        tester.widget<MaterialRibbon>(find.byType(MaterialRibbon)).collapsed,
        isTrue,
      );
      expect(find.text("常用"), findsOneWidget);
      expect(find.text("檔案"), findsOneWidget);
      expect(find.byTooltip("複製"), findsOneWidget);
      final copy = find.byKey(const ValueKey("toolbar-command-copy"));
      expect(
        find.descendant(of: copy, matching: find.text("複製")),
        mode == ToolbarMode.moderate ? findsOneWidget : findsNothing,
      );
      expect(tester.getSize(find.byType(MonogatariTopAppBar)).height, 108);
    }
  });

  for (final mode in ToolbarMode.values) {
    testWidgets("${mode.name} fits a narrow viewport with large text", (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app(mode, textScale: 2));
      expect(tester.takeException(), isNull);
      if (mode != ToolbarMode.full) {
        final scroll = find.byKey(const Key("toolbar-command-scroll"));
        final before = tester.getTopLeft(find.byTooltip("搜尋")).dx;
        await tester.drag(scroll, const Offset(-1200, 0));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.byTooltip("搜尋")).dx, lessThan(before));
        await tester.ensureVisible(find.byTooltip("搜尋"));
        await tester.tap(find.byTooltip("搜尋"));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      expect(find.byTooltip("工具列模式"), findsOneWidget);
    });
  }

  testWidgets("mode picker remains reachable and selects all three modes", (
    tester,
  ) async {
    for (final mode in ToolbarMode.values) {
      ToolbarMode? selected;
      await tester.pumpWidget(
        app(mode, onModeChanged: (value) => selected = value),
      );
      await tester.tap(find.byTooltip("工具列模式"));
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(
          of: find.text("Concise"),
          matching: find.byType(CheckedPopupMenuItem<String>),
        ),
      );
      await tester.pumpAndSettle();
      expect(selected, ToolbarMode.concise);
    }
  });

  testWidgets("Full command groups start at the left on every page", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(ToolbarMode.full));
    final left = tester.getTopLeft(find.byType(MonogatariTopAppBar)).dx;
    expect(tester.getTopLeft(find.byTooltip("貼上")).dx, lessThan(left + 40));
    await tester.tap(find.text("檔案"));
    await tester.pump();
    expect(
      tester.getTopLeft(find.byTooltip("儲存檔案").last).dx,
      lessThan(left + 40),
    );
    final newPosition = tester.getTopLeft(find.byTooltip("新建檔案"));
    final openPosition = tester.getTopLeft(find.byTooltip("開啟檔案"));
    final saveAsPosition = tester.getTopLeft(find.byTooltip("另存新檔"));
    expect(openPosition.dx, newPosition.dx);
    expect(saveAsPosition.dx, newPosition.dx);
    expect(openPosition.dy, greaterThan(newPosition.dy));
    expect(saveAsPosition.dy, greaterThan(openPosition.dy));
    expect(
      tester.getTopLeft(find.byTooltip("儲存檔案").last).dx,
      lessThan(newPosition.dx),
    );
  });

  testWidgets(
    "every mode switches Ribbon pages and retains the page across modes",
    (tester) async {
      final files = <String>[];
      final edits = <String>[];
      for (final mode in ToolbarMode.values) {
        await tester.pumpWidget(
          app(
            mode,
            onFileAction: (id) async => files.add(id),
            onEditorAction: (id) async => edits.add(id),
          ),
        );
        await tester.tap(find.text("檔案"));
        await tester.pump();
        expect(find.byTooltip("複製"), findsNothing);
        await tester.tap(find.byTooltip("另存新檔"));
        await tester.pump();
        expect(files.last, "saveAs");
        final next =
            ToolbarMode.values[(mode.index + 1) % ToolbarMode.values.length];
        await tester.pumpWidget(
          app(
            next,
            onFileAction: (id) async => files.add(id),
            onEditorAction: (id) async => edits.add(id),
          ),
        );
        expect(
          tester
              .widget<MaterialRibbon>(find.byType(MaterialRibbon))
              .selectedTabId,
          "file",
        );
        expect(find.byTooltip("另存新檔"), findsOneWidget);
        await tester.tap(find.text("常用"));
        await tester.pump();
        await tester.tap(find.byTooltip("複製"));
        await tester.pump();
        expect(edits.last, "copy");
      }
      expect(files, ["saveAs", "saveAs", "saveAs"]);
      expect(edits, ["copy", "copy", "copy"]);
    },
  );

  testWidgets(
    "File is first, Home is default, and only Full prioritizes Save",
    (tester) async {
      for (final mode in ToolbarMode.values) {
        await tester.pumpWidget(app(mode));
        final ribbon = tester.widget<MaterialRibbon>(
          find.byType(MaterialRibbon),
        );
        expect(ribbon.tabs.map((tab) => tab.id), ["file", "home", "search"]);
        expect(ribbon.selectedTabId, "home");
        final file = ribbon.tabs.firstWhere((tab) => tab.id == "file");
        expect(
          file.groups.first.commands.map((command) => command.id),
          mode == ToolbarMode.full
              ? ["save", "new", "open", "saveAs"]
              : ["new", "open", "save", "saveAs"],
        );
        expect(
          tester.getTopLeft(find.text("檔案")).dx,
          lessThan(tester.getTopLeft(find.text("常用")).dx),
        );
      }
    },
  );

  testWidgets("file commands wait and prevent repeated execution", (
    tester,
  ) async {
    final complete = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      app(
        ToolbarMode.moderate,
        onFileAction: (_) {
          calls++;
          return complete.future;
        },
      ),
    );
    await tester.tap(find.byTooltip("儲存檔案"));
    await tester.pump();
    await tester.tap(find.byTooltip("儲存檔案"));
    await tester.pump();
    expect(calls, 1);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) => widget is IconButton && widget.tooltip == "儲存檔案",
            ),
          )
          .onPressed,
      isNull,
    );
    complete.complete();
    await tester.pump();
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) => widget is IconButton && widget.tooltip == "儲存檔案",
            ),
          )
          .onPressed,
      isNotNull,
    );
  });
}
