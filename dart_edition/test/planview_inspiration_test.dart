import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monogatari_assistant/bin/ui_library.dart';
import 'package:monogatari_assistant/modules/planview.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _TestPathProvider extends PathProviderPlatform {
  final String supportPath;

  _TestPathProvider(this.supportPath);

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory supportDirectory;
  late File notesFile;
  late PathProviderPlatform originalPathProvider;

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'inspiration-test-',
    );
    notesFile = File('${supportDirectory.path}/Data/InspirationNotes.json');
    await notesFile.parent.create();
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TestPathProvider(supportDirectory.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPathProvider;
    await supportDirectory.delete(recursive: true);
  });

  Future<void> drainFileWrites(WidgetTester tester) async {
    // File I/O completes in real time, while its continuations run in the
    // widget test's fake async zone. Allow both to progress before reading.
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  Future<void> mount(
    WidgetTester tester, {
    List<Map<String, dynamic>> folders = const [],
    List<Map<String, dynamic>> notes = const [],
    List<String> rootOrder = const [],
    Size size = const Size(1100, 2200),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await drainFileWrites(tester);
    });
    await tester.runAsync(
      () => notesFile.writeAsString(
        jsonEncode({
          'folders': folders,
          'notes': notes,
          'rootOrder': rootOrder,
        }),
      ),
    );
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: PlanView())),
    );
    for (var attempt = 0; attempt < 50; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  }

  dynamic node(WidgetTester tester, String key) =>
      tester.widget(find.byKey(ValueKey(key)));

  Future<void> add(WidgetTester tester, String type, String title) async {
    final input = find.byWidgetPredicate(
      (widget) => widget is AddItemInput && widget.title == type,
    );
    final field = find.descendant(of: input, matching: find.byType(TextField));
    await tester.ensureVisible(field);
    await tester.enterText(field, title);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  Future<void> clearSelection(WidgetTester tester) async {
    final list = find.byKey(const ValueKey('inspiration-layer-list'));
    await tester.ensureVisible(list);
    // The right-hand list padding is blank even when all rows fill the viewport.
    final bounds = tester.getRect(list);
    await tester.tapAt(Offset(bounds.right - 2, bounds.top + 12));
    await tester.pumpAndSettle();
  }

  Future<Map<String, dynamic>> saved(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await drainFileWrites(tester);
    return (await tester.runAsync(
      () async =>
          jsonDecode(await notesFile.readAsString()) as Map<String, dynamic>,
    ))!;
  }

  test('folders read legacy data and round-trip parent and child order', () {
    final legacy = InspirationFolder.fromJson({'id': 'old', 'name': '舊資料夾'});
    expect(legacy.parentId, isNull);
    expect(legacy.childOrder, isEmpty);
    final nested = InspirationFolder(
      id: 'child',
      name: '子資料夾',
      parentId: 'old',
      childOrder: ['N:note'],
    );
    final restored = InspirationFolder.fromJson(nested.toJson());
    expect(restored.parentId, 'old');
    expect(restored.childOrder, ['N:note']);
  });

  testWidgets('nested creation, blank deselection and edited notes persist', (
    tester,
  ) async {
    await mount(tester);
    await add(tester, '資料夾', '第一層');
    await add(tester, '資料夾', '第二層');
    await add(tester, '資料夾', '第三層');
    await add(tester, '靈感', '深層靈感');
    final content = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '內容',
    );
    await tester.ensureVisible(content);
    await tester.enterText(content, '保留這段內容');
    await tester.pumpAndSettle();
    final noteCard = find.byWidgetPredicate(
      (widget) => widget is AppListCard && widget.selected,
    );
    expect(noteCard, findsOneWidget);
    await clearSelection(tester);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is AppListCard && widget.selected,
      ),
      findsNothing,
    );
    expect(find.text('請選擇一則靈感'), findsOneWidget);
    await add(tester, '資料夾', '另一個根資料夾');
    final data = await saved(tester);
    final folders = data['folders'] as List;
    expect(folders[0]['parentId'], isNull);
    expect(folders[1]['parentId'], folders[0]['id']);
    expect(folders[2]['parentId'], folders[1]['id']);
    expect(folders[3]['parentId'], isNull);
    expect(data['notes'][0]['folderId'], folders[2]['id']);
    expect(data['notes'][0]['content'], '保留這段內容');
    expect(tester.takeException(), isNull);
  });

  testWidgets('nested folders collapse and expand all descendants', (
    tester,
  ) async {
    await mount(
      tester,
      folders: [
        {'id': 'a', 'name': '外層'},
        {'id': 'b', 'name': '中層', 'parentId': 'a'},
        {'id': 'c', 'name': '內層', 'parentId': 'b'},
      ],
      notes: [
        {'id': 'n', 'title': '筆記', 'folderId': 'c'},
      ],
    );
    expect(node(tester, 'folder:a').indent, 0);
    expect(node(tester, 'folder:b').indent, 28);
    expect(node(tester, 'folder:c').indent, 56);
    expect(node(tester, 'note:n').indent, 84);
    final collapse = find.descendant(
      of: find.byKey(const ValueKey('folder:a')),
      matching: find.byTooltip('收合'),
    );
    await tester.tap(collapse);
    await tester.pumpAndSettle();
    expect(find.text('中層'), findsNothing);
    expect(find.text('筆記'), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('folder:a')),
        matching: find.byTooltip('展開'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('內層'), findsOneWidget);
    expect(find.text('筆記'), findsOneWidget);
    await saved(tester);
  });

  testWidgets(
    'folder drops reject cycles and move subtrees with sibling ordering',
    (tester) async {
      await mount(
        tester,
        folders: [
          {'id': 'a', 'name': '外層'},
          {'id': 'b', 'name': '子層', 'parentId': 'a'},
          {'id': 'c', 'name': '另一個資料夾'},
        ],
        notes: [
          {'id': 'n', 'title': '子層筆記', 'folderId': 'b'},
        ],
        rootOrder: ['F:a', 'F:c'],
      );
      final a = node(tester, 'folder:a');
      final b = node(tester, 'folder:b');
      final c = node(tester, 'folder:c');
      expect(b.onWillAccept(a.dragData, DropPosition.child), isFalse);
      expect(b.onWillAccept(a.dragData, DropPosition.before), isFalse);
      expect(a.onWillAccept(a.dragData, DropPosition.child), isFalse);
      expect(c.onWillAccept(b.dragData, DropPosition.child), isTrue);
      c.onAccept(b.dragData, DropPosition.child);
      await tester.pumpAndSettle();
      expect(node(tester, 'note:n').indent, 56);
      // A note can be ordered before a nested folder at the same level.
      final movedB = node(tester, 'folder:b');
      final n = node(tester, 'note:n');
      movedB.onAccept(n.dragData, DropPosition.before);
      await tester.pumpAndSettle();
      expect(node(tester, 'note:n').indent, 28);
      // Moving the folder beside a root folder promotes it back to the root.
      node(tester, 'folder:a').onAccept(movedB.dragData, DropPosition.after);
      await tester.pumpAndSettle();
      final data = await saved(tester);
      expect(data['rootOrder'], ['F:a', 'F:b', 'F:c']);
      expect(data['folders'][1]['parentId'], isNull);
      expect(data['folders'][2]['childOrder'], ['N:n']);
      expect(data['notes'][0]['folderId'], 'c');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('deleting a nested folder promotes its contents in place', (
    tester,
  ) async {
    await mount(
      tester,
      folders: [
        {
          'id': 'a',
          'name': '外層',
          'childOrder': ['F:b', 'N:last'],
        },
        {
          'id': 'b',
          'name': '待刪',
          'parentId': 'a',
          'childOrder': ['N:first', 'F:c'],
        },
        {'id': 'c', 'name': '保留子層', 'parentId': 'b'},
      ],
      notes: [
        {'id': 'first', 'title': '保留筆記', 'folderId': 'b'},
        {'id': 'last', 'title': '末尾筆記', 'folderId': 'a'},
      ],
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('folder:b')),
        matching: find.byTooltip('刪除'),
      ),
    );
    await tester.pumpAndSettle();
    final data = await saved(tester);
    expect(data['folders'].length, 2);
    expect(data['folders'][0]['childOrder'], ['N:first', 'F:c', 'N:last']);
    expect(data['folders'][1]['parentId'], 'a');
    expect(data['notes'][0]['folderId'], 'a');
    expect(tester.takeException(), isNull);
  });

  testWidgets('deep nesting remains scrollable on a narrow viewport', (
    tester,
  ) async {
    await mount(
      tester,
      size: const Size(600, 2200),
      folders: [
        for (var i = 0; i < 24; i++)
          {'id': 'f$i', 'name': '第$i層', if (i > 0) 'parentId': 'f${i - 1}'},
      ],
      notes: [
        {'id': 'deep', 'title': '深層筆記', 'folderId': 'f23'},
      ],
    );
    final list = find.byKey(const ValueKey('inspiration-layer-list'));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('note:deep')),
      250,
      scrollable: find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    expect(node(tester, 'note:deep').indent, 24 * 28);
    expect(tester.takeException(), isNull);
    await saved(tester);
  });

  testWidgets('legacy notes and malformed folder parents remain accessible', (
    tester,
  ) async {
    await mount(
      tester,
      folders: [
        {'id': 'old', 'name': '舊資料夾'},
        {'id': 'a', 'name': '循環一', 'parentId': 'b'},
        {'id': 'b', 'name': '循環二', 'parentId': 'a'},
        {'id': 'orphan', 'name': '失去父層', 'parentId': 'missing'},
      ],
      notes: [
        {'id': 'legacy', 'title': '舊筆記', 'folderId': 'old'},
        {'id': 'orphan-note', 'title': '失去資料夾的筆記', 'folderId': 'missing'},
      ],
      rootOrder: ['F:old', 'F:old'],
    );
    expect(find.text('舊筆記'), findsOneWidget);
    expect(node(tester, 'note:legacy').indent, 28);
    final data = await saved(tester);
    expect(data['rootOrder'].where((key) => key == 'F:old').length, 1);
    expect(data['folders'][1]['parentId'], isNull);
    expect(data['folders'][3]['parentId'], isNull);
    expect(data['notes'][1]['folderId'], isNull);
    expect(tester.takeException(), isNull);
  });
}
