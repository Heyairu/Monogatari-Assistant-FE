import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_ribbon/material_ribbon.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monogatari_assistant/bin/appbar.dart';
import 'package:monogatari_assistant/features/help/help_catalog.dart';
import 'package:monogatari_assistant/features/help/help_controller.dart';
import 'package:monogatari_assistant/features/help/help_scope.dart';
import 'package:monogatari_assistant/features/help/help_topic.dart';
import 'package:monogatari_assistant/features/help/help_viewer.dart';
import 'package:monogatari_assistant/models/toolbar_mode.dart';
import 'package:monogatari_assistant/ui_library/dialogs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final source = File('assets/help/zh_TW.json').readAsStringSync();
  final catalog = HelpCatalog.parse(source);

  test('offline topics cover every page, command and related link', () {
    expect(HelpTopicId.pages, hasLength(16));
    for (final id in [
      ...HelpTopicId.pages,
      ...HelpTopicId.commands.values,
      HelpTopicId.home,
      HelpTopicId.usingHelp,
      HelpTopicId.shortcuts,
      HelpTopicId.recovery,
      HelpTopicId.faq,
      HelpTopicId.editor,
      HelpTopicId.annotations,
      HelpTopicId.phrases,
      HelpTopicId.backup,
      HelpTopicId.backupDirectory,
      HelpTopicId.backupCapacity,
      HelpTopicId.autoSave,
      HelpTopicId.dialog,
      HelpTopicId.toolbarMode,
      HelpTopicId.findInput,
      HelpTopicId.replaceInput,
      HelpTopicId.previous,
      HelpTopicId.next,
      HelpTopicId.replace,
      HelpTopicId.replaceAll,
    ]) {
      expect(catalog.topics.containsKey(id), isTrue, reason: id);
      expect(catalog.topic(id).sections, isNotEmpty);
    }
    expect(catalog.topic('unknown').id, HelpTopicId.home);
    expect(HelpTopicId.forPage(114514), HelpTopicId.editor);
    expect(HelpTopicId.forPage(4), 'pages.timeline');
    expect(HelpTopicId.forPage(8), 'pages.items');
    expect(HelpTopicId.forPage(14), 'pages.settings');
  });

  test('catalog rejects duplicate IDs and broken links', () {
    final data = jsonDecode(source) as Map<String, dynamic>;
    (data['topics'] as List).add((data['topics'] as List).first);
    expect(() => HelpCatalog.parse(jsonEncode(data)), throwsFormatException);
    (data['topics'] as List).removeLast();
    data['topics'][0]['relatedIds'] = ['missing'];
    expect(() => HelpCatalog.parse(jsonEncode(data)), throwsFormatException);
  });

  test('search covers Chinese body, keywords and title ranking', () {
    expect(catalog.search(''), hasLength(catalog.topics.length));
    expect(catalog.search('大小寫').first.id, 'search.matchCase');
    expect(
      catalog.search('F1').map((t) => t.id),
      contains(HelpTopicId.shortcuts),
    );
    expect(
      catalog.search('backreference').map((t) => t.id),
      contains('search.useRegexp'),
    );
    expect(catalog.search('不存在的測試字串'), isEmpty);
    expect(
      catalog.search('正則 look-around').map((t) => t.id),
      contains('search.useRegexp'),
    );
  });

  Future<void> f1(WidgetTester tester, {bool shift = false}) async {
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f1);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
  }

  String currentTopic(WidgetTester tester) =>
      tester.widget<HelpViewer>(find.byType(HelpViewer)).topic.value;

  Future<HelpController> mount(
    WidgetTester tester,
    Widget child, {
    double scale = 1,
    Future<HelpCatalog> Function()? loader,
  }) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    late HelpController help;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, navigator) => AppHelpHost(
          navigatorKey: navigatorKey,
          loadCatalog: loader ?? () async => catalog,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: navigator!,
          ),
        ),
        home: Builder(
          builder: (context) {
            help = HelpController.maybeOf(context)!;
            help.pageTopic = 'pages.characters';
            return HelpScope(
              topicId: 'pages.characters',
              child: Scaffold(body: child),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return help;
  }

  testWidgets('the bundled asset can load without network', (tester) async {
    final loaded = await tester.runAsync(() => HelpCatalog.load());
    expect(loaded!.topics.length, catalog.topics.length);
  });

  testWidgets(
    'F1 resolves focus, reuses window, restores selection and focus',
    (tester) async {
      final focus = FocusNode();
      final text = TextEditingController(text: '甲乙丙');
      addTearDown(focus.dispose);
      addTearDown(text.dispose);
      await mount(
        tester,
        HelpTarget(
          topicId: HelpTopicId.findInput,
          child: TextField(focusNode: focus, controller: text),
        ),
      );
      focus.requestFocus();
      text.selection = const TextSelection(baseOffset: 1, extentOffset: 2);
      await tester.pump();
      await f1(tester);
      expect(currentTopic(tester), HelpTopicId.findInput);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.f1);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.f1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.f1);
      await tester.pumpAndSettle();
      expect(find.byType(HelpViewer), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(HelpViewer), findsNothing);
      expect(focus.hasFocus, isTrue);
      expect(text.text, '甲乙丙');
      expect(
        text.selection,
        const TextSelection(baseOffset: 1, extentOffset: 2),
      );
    },
  );

  testWidgets(
    'picker consumes clicks on destructive, disabled and toggle controls',
    (tester) async {
      int operations = 0;
      final help = await mount(
        tester,
        Column(
          children: [
            for (final label in ['儲存', '刪除', '取代', '停用'])
              HelpTarget(
                topicId: HelpTopicId.replaceAll,
                child: ElevatedButton(
                  onPressed: label == '停用' ? null : () => operations++,
                  child: Text(label),
                ),
              ),
            HelpTarget(
              topicId: HelpTopicId.backup,
              child: Checkbox(value: false, onChanged: (_) => operations++),
            ),
          ],
        ),
      );
      for (final label in ['儲存', '刪除', '取代', '停用']) {
        await f1(tester, shift: true);
        expect(help.isPicking, isTrue);
        await tester.tapAt(tester.getCenter(find.text(label)));
        await tester.pumpAndSettle();
        expect(help.isPicking, isFalse);
        expect(currentTopic(tester), HelpTopicId.replaceAll);
        expect(operations, 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }
      await f1(tester, shift: true);
      await tester.tapAt(tester.getCenter(find.byType(Checkbox)));
      await tester.pumpAndSettle();
      expect(currentTopic(tester), HelpTopicId.backup);
      expect(operations, 0);
    },
  );

  testWidgets(
    'picker blocks shortcuts, typing and Enter, and cancels cleanly',
    (tester) async {
      int commands = 0;
      final focus = FocusNode();
      final text = TextEditingController(text: '原文');
      addTearDown(focus.dispose);
      addTearDown(text.dispose);
      final help = await mount(
        tester,
        CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
                commands++,
            const SingleActivator(LogicalKeyboardKey.enter): () => commands++,
          },
          child: TextField(focusNode: focus, controller: text),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await f1(tester, shift: true);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      expect(commands, 0);
      expect(text.text, '原文');
      await f1(tester, shift: true);
      expect(help.isPicking, isFalse);
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      await f1(tester, shift: true);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(help.isPicking, isFalse);
      expect(focus.hasFocus, isTrue);
    },
  );

  testWidgets(
    'focus selects correct pane and hidden IndexedStack pages cannot be picked',
    (tester) async {
      final editorFocus = FocusNode();
      final pageFocus = FocusNode();
      addTearDown(editorFocus.dispose);
      addTearDown(pageFocus.dispose);
      await mount(
        tester,
        Row(
          children: [
            Expanded(
              child: HelpScope(
                topicId: HelpTopicId.editor,
                child: TextField(focusNode: editorFocus),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: 1,
                children: [
                  const HelpScope(topicId: 'pages.items', child: Text('隱藏物品')),
                  HelpScope(
                    topicId: 'pages.characters',
                    child: TextField(focusNode: pageFocus),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      for (final (focus, id) in [
        (editorFocus, HelpTopicId.editor),
        (pageFocus, 'pages.characters'),
      ]) {
        focus.requestFocus();
        await tester.pump();
        await f1(tester);
        expect(currentTopic(tester), id);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }
      await f1(tester, shift: true);
      await tester.tapAt(
        tester.getCenter(
          find.byWidgetPredicate(
            (w) => w is TextField && w.focusNode == pageFocus,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(currentTopic(tester), 'pages.characters');
    },
  );

  testWidgets('F1 and picker work in modals and preserve the original dialog', (
    tester,
  ) async {
    bool checked = false;
    await mount(
      tester,
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => AppDialog.showCustom<void>(
            context: context,
            builder: (_) => HelpScope(
              topicId: HelpTopicId.importFiles,
              child: StatefulBuilder(
                builder: (context, update) => AppDialog(
                  title: '匯入測試',
                  content: Checkbox(
                    value: checked,
                    onChanged: (value) => update(() => checked = value!),
                  ),
                ),
              ),
            ),
          ),
          child: const Text('開啟匯入'),
        ),
      ),
    );
    await tester.tap(find.text('開啟匯入'));
    await tester.pumpAndSettle();
    await f1(tester);
    expect(currentTopic(tester), HelpTopicId.importFiles);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('匯入測試'), findsOneWidget);
    await f1(tester, shift: true);
    await tester.tapAt(tester.getCenter(find.byType(Checkbox)));
    await tester.pumpAndSettle();
    expect(currentTopic(tester), HelpTopicId.importFiles);
    expect(checked, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HelpViewer), findsNothing);
    expect(find.text('匯入測試'), findsOneWidget);
  });

  testWidgets('F1 works on a popup item without executing it', (tester) async {
    int selected = 0;
    await mount(
      tester,
      PopupMenuButton<int>(
        itemBuilder: (_) => [
          HelpPopupMenuItem(
            topicId: HelpTopicId.exportFiles,
            value: 1,
            child: HelpTarget(
              topicId: HelpTopicId.exportFiles,
              child: const Text('測試匯出'),
            ),
          ),
        ],
        onSelected: (_) => selected++,
      ),
    );
    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();
    await f1(tester, shift: true);
    await tester.tapAt(tester.getCenter(find.text('測試匯出')));
    await tester.pumpAndSettle();
    expect(currentTopic(tester), HelpTopicId.exportFiles);
    expect(selected, 0);
  });

  for (final mode in ToolbarMode.values) {
    testWidgets(
      '${mode.name} exposes help and decorates commands without invoking them',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        int commands = 0;
        await mount(
          tester,
          MonogatariTopAppBar(
            iconSize: 22,
            mode: mode,
            modePreference: mode,
            onModeChanged: (_) {},
            showPunctuationPanel: false,
            showFindReplaceWindow: false,
            onFileAction: (_) async => commands++,
            onEditorAction: (_) async => commands++,
            onEditorActionPointerDown: () {},
            onEditorActionInteractionEnd: () {},
            onTogglePunctuationPanel: () {},
            onToggleFindReplaceWindow: () {},
          ),
        );
        await f1(tester, shift: true);
        await tester.tapAt(tester.getCenter(find.byTooltip('儲存檔案').first));
        await tester.pumpAndSettle();
        expect(currentTopic(tester), 'files.save');
        expect(commands, 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('說明'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('說明首頁'));
        await tester.pumpAndSettle();
        expect(currentTopic(tester), HelpTopicId.home);
      },
    );
  }

  testWidgets('modifier combinations do not open help', (tester) async {
    final help = await mount(tester, const TextField(autofocus: true));
    for (final modifier in [
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.metaLeft,
    ]) {
      await tester.sendKeyDownEvent(modifier);
      await f1(tester);
      await tester.sendKeyUpEvent(modifier);
      expect(help.isShowing, isFalse);
      expect(help.isPicking, isFalse);
    }
  });

  testWidgets('search, no results, history and narrow large text work', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final help = await mount(tester, const SizedBox(), scale: 2);
    help.showHome();
    await tester.pumpAndSettle();
    expect(find.text('目錄與搜尋'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '不存在的測試字串');
    await tester.pumpAndSettle();
    expect(find.text('找不到符合的說明'), findsOneWidget);
    await tester.tap(find.text('返回目錄'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '大小寫');
    await tester.pumpAndSettle();
    await tester.tap(find.text('大小寫需相同'));
    await tester.pumpAndSettle();
    expect(currentTopic(tester), 'search.matchCase');
    await tester.tap(find.byTooltip('上一頁'));
    await tester.pumpAndSettle();
    expect(currentTopic(tester), HelpTopicId.home);
    await tester.tap(find.byTooltip('下一頁'));
    await tester.pumpAndSettle();
    expect(currentTopic(tester), 'search.matchCase');
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed asset load offers retry', (tester) async {
    int calls = 0;
    final help = await mount(
      tester,
      const SizedBox(),
      loader: () async {
        if (++calls == 1) throw const FormatException('bad asset');
        return catalog;
      },
    );
    help.showHome();
    await tester.pumpAndSettle();
    expect(find.text('無法載入內建說明，請重試。'), findsOneWidget);
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();
    expect(find.text('無法載入內建說明，請重試。'), findsNothing);
    expect(find.text('快速開始與說明首頁'), findsWidgets);
  });

  testWidgets('entering picker cancels a gesture that already started', (
    tester,
  ) async {
    int commands = 0;
    final help = await mount(
      tester,
      HelpTarget(
        topicId: 'files.save',
        child: ElevatedButton(
          onPressed: () => commands++,
          child: const Text('儲存中的指標'),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('儲存中的指標')),
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.f1);
    // No intervening frame: the gate must already protect input.
    await gesture.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.f1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(commands, 0);
    expect(help.isPicking, isTrue);
    expect(help.isShowing, isFalse);
    await tester.tapAt(tester.getCenter(find.text('儲存中的指標')));
    await tester.pumpAndSettle();
    expect(currentTopic(tester), 'files.save');
    expect(commands, 0);
  });

  testWidgets('QAT overflow and normal ribbon commands receive help targets', (
    tester,
  ) async {
    int invoked = 0;
    final commands = [
      for (final id in ['save', 'open', 'new'])
        RibbonCommand(
          id: id,
          label: id,
          icon: Icons.save,
          onInvoke: () => invoked++,
        ),
    ];
    await mount(
      tester,
      SizedBox(
        height: 210,
        child: MaterialRibbon(
          context: const RibbonContext(),
          compact: false,
          quickAccessLimit: 1,
          quickAccessCommands: commands,
          commandWrapperBuilder: (context, command, child) => HelpTarget(
            topicId: HelpTopicId.forCommand(command.id),
            child: child,
          ),
          localizations: RibbonLocalizations.traditionalChinese,
          tabs: [
            RibbonTab(
              id: 'home',
              label: '常用',
              groups: [
                RibbonGroup(
                  id: 'files',
                  label: '檔案操作',
                  commands: [commands.last],
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await f1(tester, shift: true);
    await tester.tapAt(tester.getCenter(find.byTooltip('new')));
    await tester.pumpAndSettle();
    expect(currentTopic(tester), 'files.new');
    expect(invoked, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byTooltip(
        RibbonLocalizations.traditionalChinese.moreQuickAccessCommands,
      ),
    );
    await tester.pumpAndSettle();
    await f1(tester, shift: true);
    await tester.tapAt(tester.getCenter(find.text('open')));
    await tester.pumpAndSettle();
    expect(currentTopic(tester), 'files.open');
    expect(invoked, 0);
  });

  testWidgets('Ctrl+F1 still collapses the ribbon without opening Help', (
    tester,
  ) async {
    bool? collapsed;
    final ribbonFocus = FocusNode();
    addTearDown(ribbonFocus.dispose);
    final help = await mount(
      tester,
      SizedBox(
        height: 210,
        child: MaterialRibbon(
          context: const RibbonContext(),
          compact: false,
          focusNode: ribbonFocus,
          onCollapsedChanged: (value) => collapsed = value,
          tabs: [
            RibbonTab(
              id: 'home',
              label: '常用',
              groups: [
                RibbonGroup(
                  id: 'files',
                  label: '檔案',
                  commands: [
                    RibbonCommand(
                      id: 'save',
                      label: '儲存',
                      icon: Icons.save,
                      onInvoke: () {},
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
    ribbonFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(collapsed, isTrue);
    expect(help.isShowing, isFalse);
    collapsed = null;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(collapsed, isNull);
    expect(help.isPicking, isFalse);
  });

  testWidgets('keyboard-selected popup item resolves F1 to its own topic', (
    tester,
  ) async {
    await mount(
      tester,
      PopupMenuButton<int>(
        itemBuilder: (_) => [
          const HelpPopupMenuItem(
            value: 1,
            topicId: HelpTopicId.exportFiles,
            child: Text('鍵盤匯出'),
          ),
        ],
      ),
    );
    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await f1(tester);
    expect(currentTopic(tester), HelpTopicId.exportFiles);
  });

  testWidgets('picker cancels when the app loses focus', (tester) async {
    final help = await mount(tester, const TextField());
    await f1(tester, shift: true);
    expect(help.isPicking, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(help.isPicking, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}
