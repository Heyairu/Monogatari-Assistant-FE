import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monogatari_assistant/bin/content.dart';
import 'package:monogatari_assistant/bin/findreplace.dart';
import 'package:monogatari_assistant/features/help/help_catalog.dart';
import 'package:monogatari_assistant/features/help/help_controller.dart';
import 'package:monogatari_assistant/features/help/help_topic.dart';
import 'package:monogatari_assistant/features/help/help_viewer.dart';
import 'package:monogatari_assistant/main.dart';
import 'package:monogatari_assistant/presentation/providers/editor_coordinator_provider.dart';
import 'package:monogatari_assistant/presentation/providers/project_history_provider.dart';
import 'package:monogatari_assistant/presentation/providers/project_state_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'real editor help preserves raw text, selection, dirty state and history',
    (tester) async {
      // ContentView's background I/O indicator can animate indefinitely in a
      // widget test. Advance route transitions without waiting for it to stop.
      Future<void> settleRoute() async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
      }

      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(2400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final navigator = GlobalKey<NavigatorState>();
      final catalog = HelpCatalog.parse(
        File('assets/help/zh_TW.json').readAsStringSync(),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: navigator,
            builder: (_, child) => AppHelpHost(
              navigatorKey: navigator,
              loadCatalog: () async => catalog,
              child: child!,
            ),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              FlutterQuillLocalizations.delegate,
            ],
            home: const ContentView(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      const source = '甲乙丙丁';
      container.read(editorContentProvider.notifier).setContent(source);
      await tester.pump(const Duration(seconds: 1));
      final host = tester.widget<EditorTextBox>(find.byType(EditorTextBox));
      final quill = tester.widget<QuillEditor>(
        find.byKey(const ValueKey('plain-text-quill-editor')),
      );
      host.focusNode.requestFocus();
      const selection = TextSelection(baseOffset: 1, extentOffset: 3);
      quill.controller.updateSelection(selection, ChangeSource.local);
      await tester.pump(const Duration(seconds: 1));
      final history = container.read(projectHistoryProvider);
      final dirty = container.read(editorCoordinatorProvider).hasUnsavedChanges;

      Future<void> verifyEditor() async {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await settleRoute();
        expect(host.focusNode.hasFocus, isTrue);
        expect(quill.controller.selection, selection);
        expect(host.controller.selection, selection);
        expect(container.read(editorContentProvider), source);
        expect(
          container.read(editorCoordinatorProvider).hasUnsavedChanges,
          dirty,
        );
        expect(
          container.read(projectHistoryProvider).undoStack.length,
          history.undoStack.length,
        );
        expect(
          container.read(projectHistoryProvider).redoStack.length,
          history.redoStack.length,
        );
      }

      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await settleRoute();
      expect(
        tester.widget<HelpViewer>(find.byType(HelpViewer)).topic.value,
        HelpTopicId.editor,
      );
      await verifyEditor();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await settleRoute();
      await tester.tapAt(tester.getCenter(find.byTooltip('儲存檔案').first));
      await settleRoute();
      expect(
        tester.widget<HelpViewer>(find.byType(HelpViewer)).topic.value,
        'files.save',
      );
      await verifyEditor();

      await tester.tap(find.byTooltip('說明'));
      await settleRoute();
      await tester.tap(find.text('目前功能說明（F1）'));
      await settleRoute();
      expect(
        tester.widget<HelpViewer>(find.byType(HelpViewer)).topic.value,
        HelpTopicId.editor,
      );
      await verifyEditor();

      // The root focus listener must also preserve selections in search fields.
      await tester.tap(find.byTooltip('搜尋'));
      await tester.pump();
      final search = tester.widget<FindReplaceBar>(find.byType(FindReplaceBar));
      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.controller == search.findController,
      );
      await tester.enterText(field, '乙丙');
      search.findController.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 2,
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await settleRoute();
      expect(
        tester.widget<HelpViewer>(find.byType(HelpViewer)).topic.value,
        HelpTopicId.findInput,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settleRoute();
      expect(search.findController.text, '乙丙');
      expect(
        search.findController.selection,
        const TextSelection(baseOffset: 0, extentOffset: 2),
      );
      expect(container.read(editorContentProvider), source);
      expect(tester.takeException(), isNull);
    },
  );
}
