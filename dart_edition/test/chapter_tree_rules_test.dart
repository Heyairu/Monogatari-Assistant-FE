import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/ui_library.dart";
import "package:monogatari_assistant/modules/chapterselectionview.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";

SegmentData _folder(
  String id,
  List<String> chapterIds, {
  List<SegmentData> children = const [],
  List<String> order = const [],
}) {
  return SegmentData(
    segmentUUID: id,
    segmentName: id,
    chapters: chapterIds
        .map(
          (chapterId) =>
              ChapterData(chapterUUID: chapterId, chapterName: chapterId),
        )
        .toList(),
    childSegments: children,
    childNodeOrder: order,
  );
}

void main() {
  test("new folder contains a default chapter", () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(segmentsDataProvider.notifier);

    notifier.setSegmentsData([
      _folder("existing", ["chapter-1"]),
    ]);
    final added = notifier.addFolder(name: "第二部");

    expect(added!.segmentName, "第二部");
    expect(added.chapters, hasLength(1));
    expect(added.chapters.single.chapterName, "章節 1");
  });

  test("folders can be recursively created and traversed", () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(segmentsDataProvider.notifier);

    notifier.setSegmentsData([
      _folder("root", ["root-chapter"]),
    ]);
    final child = notifier.addFolder(name: "Child", parentFolderID: "root");
    final grandchild = notifier.addFolder(
      name: "Grandchild",
      parentFolderID: child!.segmentUUID,
    );

    final roots = container.read(segmentsDataProvider);
    expect(grandchild, isNotNull);
    expect(
      ChapterTree.foldersDepthFirst(roots).map((folder) => folder.segmentName),
      ["root", "Child", "Grandchild"],
    );
    expect(ChapterTree.chapterCount(roots), 3);
  });

  test("folders move as subtrees and cannot move into descendants", () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(segmentsDataProvider.notifier);

    notifier.setSegmentsData([
      _folder("folder-a", ["a-1"]),
      _folder("folder-b", ["b-1"]),
    ]);
    expect(
      notifier.moveFolder(
        sourceFolderID: "folder-b",
        targetFolderID: "folder-a",
        position: "child",
      ),
      isTrue,
    );
    expect(container.read(segmentsDataProvider), hasLength(1));
    expect(
      container
          .read(segmentsDataProvider)
          .single
          .childSegments
          .single
          .segmentUUID,
      "folder-b",
    );

    expect(
      notifier.moveFolder(
        sourceFolderID: "folder-a",
        targetFolderID: "folder-b",
        position: "child",
      ),
      isFalse,
    );
  });

  test("removing a folder cascades but never removes the final chapter", () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(segmentsDataProvider.notifier);

    notifier.setSegmentsData([
      _folder("folder-a", ["a-1", "a-2"]),
      _folder("folder-b", ["b-1"]),
    ]);
    notifier.removeSegmentById("folder-a");

    expect(container.read(segmentsDataProvider), hasLength(1));
    expect(container.read(segmentsDataProvider).single.segmentUUID, "folder-b");

    notifier.removeSegmentById("folder-b");
    expect(container.read(segmentsDataProvider), hasLength(1));
    expect(
      container.read(segmentsDataProvider).single.chapters.single.chapterUUID,
      "b-1",
    );
  });

  test("removing a parent folder cascades through its nested subtree", () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(segmentsDataProvider.notifier);
    notifier.setSegmentsData([
      _folder(
        "parent",
        ["parent-chapter"],
        children: [
          _folder("child", ["child-chapter"]),
        ],
      ),
      _folder("survivor", ["survivor-chapter"]),
    ]);

    expect(notifier.removeSegmentById("parent"), isTrue);
    final roots = container.read(segmentsDataProvider);
    expect(ChapterTree.findFolder(roots, "parent"), isNull);
    expect(ChapterTree.findFolder(roots, "child"), isNull);
    expect(ChapterTree.chapterCount(roots), 1);
    expect(notifier.removeSegmentById("survivor"), isFalse);
  });

  test("removing a folder's only chapter also removes that folder", () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(segmentsDataProvider.notifier);

    notifier.setSegmentsData([
      _folder("folder-a", ["a-1"]),
      _folder("folder-b", ["b-1"]),
    ]);
    notifier.removeChapter(segmentID: "folder-a", chapterID: "a-1");

    expect(container.read(segmentsDataProvider), hasLength(1));
    expect(container.read(segmentsDataProvider).single.segmentUUID, "folder-b");

    notifier.removeChapter(segmentID: "folder-b", chapterID: "b-1");
    expect(
      container.read(segmentsDataProvider).single.chapters.single.chapterUUID,
      "b-1",
    );
  });

  test(
    "moving a folder's only chapter removes the empty source atomically",
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(segmentsDataProvider.notifier);

      notifier.setSegmentsData([
        _folder("folder-a", ["a-1"]),
        _folder("folder-b", ["b-1"]),
      ]);
      notifier.moveChapterToSegment(
        chapterID: "a-1",
        targetSegmentID: "folder-b",
      );

      final folders = container.read(segmentsDataProvider);
      expect(folders, hasLength(1));
      expect(folders.single.segmentUUID, "folder-b");
      expect(folders.single.chapters.map((chapter) => chapter.chapterUUID), [
        "b-1",
        "a-1",
      ]);
    },
  );

  test("legacy chapter XML upgrades through the hidden-root schema seam", () {
    const legacyXml = """
<Type>
  <Name>ChapterSelection</Name>
  <Segment Name="Part 1" UUID="folder-1">
    <Chapter Name="Opening" UUID="chapter-1"><Content>Hello</Content></Chapter>
  </Segment>
</Type>
""";

    final loaded = ChapterSelectionCodec.loadXML(legacyXml)!;
    expect(loaded.single.segmentUUID, "folder-1");
    expect(loaded.single.chapters.single.chapterContent, "Hello");

    final saved = ChapterSelectionCodec.saveXML(loaded)!;
    expect(
      saved,
      contains('ChapterTreeVersion="${ChapterTreeSchema.currentVersion}"'),
    );
    expect(ChapterTreeSchema.hiddenRootId, isNotEmpty);
  });

  test(
    "schema v2 keeps its historical chapter-before-folder display order",
    () {
      const versionTwoXml = """
<Type ChapterTreeVersion="2">
  <Name>ChapterSelection</Name>
  <Segment Name="Root" UUID="root">
    <Segment Name="Child" UUID="child">
      <Chapter Name="Nested" UUID="nested"><Content /></Chapter>
    </Segment>
    <Chapter Name="Opening" UUID="opening"><Content /></Chapter>
  </Segment>
</Type>
""";

      final loaded = ChapterSelectionCodec.loadXML(versionTwoXml)!;
      expect(loaded.single.resolvedChildNodeOrder, ["opening", "child"]);
    },
  );

  test("recursive folders round-trip through chapter XML", () {
    final roots = [
      _folder(
        "root-folder",
        ["root-chapter"],
        children: [
          _folder(
            "child-folder",
            ["child-chapter"],
            children: [
              _folder("grandchild-folder", ["grandchild-chapter"]),
            ],
          ),
        ],
      ),
    ];

    final saved = ChapterSelectionCodec.saveXML(roots)!;
    final reopened = ChapterSelectionCodec.loadXML(saved)!;

    expect(
      ChapterTree.foldersDepthFirst(
        reopened,
      ).map((folder) => folder.segmentUUID),
      ["root-folder", "child-folder", "grandchild-folder"],
    );
    expect(
      ChapterTree.chaptersDepthFirst(
        reopened,
      ).map((location) => location.chapter.chapterUUID),
      ["root-chapter", "child-chapter", "grandchild-chapter"],
    );
  });

  test("folders and chapters preserve one mixed order through XML", () {
    final roots = [
      _folder(
        "root",
        ["chapter-a", "chapter-b"],
        children: [
          _folder("child", ["child-chapter"]),
        ],
        order: ["chapter-a", "child", "chapter-b"],
      ),
    ];

    final reopened = ChapterSelectionCodec.loadXML(
      ChapterSelectionCodec.saveXML(roots)!,
    )!;

    expect(reopened.single.resolvedChildNodeOrder, [
      "chapter-a",
      "child",
      "chapter-b",
    ]);
    expect(
      ChapterTree.chaptersDepthFirst(
        reopened,
      ).map((location) => location.chapter.chapterUUID),
      ["chapter-a", "child-chapter", "chapter-b"],
    );
  });

  test("a folder can be sorted before or after a chapter", () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(segmentsDataProvider.notifier);
    notifier.setSegmentsData([
      _folder(
        "root",
        ["chapter-a", "chapter-b"],
        children: [
          _folder("child", ["child-chapter"]),
        ],
        order: ["chapter-a", "chapter-b", "child"],
      ),
    ]);

    expect(
      notifier.moveFolderRelativeToChapter(
        sourceFolderID: "child",
        targetChapterID: "chapter-a",
        position: "after",
      ),
      isTrue,
    );
    expect(container.read(segmentsDataProvider).single.resolvedChildNodeOrder, [
      "chapter-a",
      "child",
      "chapter-b",
    ]);
  });

  test("a chapter can be sorted beside a nested folder", () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(segmentsDataProvider.notifier);
    notifier.setSegmentsData([
      _folder(
        "root",
        ["chapter-a", "chapter-b"],
        children: [
          _folder("child", ["child-chapter"]),
        ],
        order: ["chapter-a", "chapter-b", "child"],
      ),
    ]);

    expect(
      notifier.moveChapterRelativeToFolder(
        chapterID: "chapter-b",
        targetFolderID: "child",
        position: "after",
      ),
      isTrue,
    );
    expect(container.read(segmentsDataProvider).single.resolvedChildNodeOrder, [
      "chapter-a",
      "child",
      "chapter-b",
    ]);
  });

  testWidgets("chapter tree shows search and one combined add input", (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(520, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ChapterSelectionView())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byType(AddItemInput), findsOneWidget);
    expect(find.byKey(const ValueKey("chapter-create-type-chapter")), findsOne);
    expect(
      find.byKey(const ValueKey("chapter-create-type-childFolder")),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey("chapter-create-type-rootFolder")),
      findsOne,
    );
  });

  testWidgets("stopping a folder drag keeps scroll position and row tappable", (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(segmentsDataProvider.notifier).setSegmentsData([
      for (var index = 0; index < 12; index++)
        _folder("folder-$index", ["chapter-$index"]),
    ]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ChapterSelectionView()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final treeList = tester.widget<ListView>(find.byType(ListView));
    final controller = treeList.controller!;
    controller.jumpTo(260);
    await tester.pump();
    final offsetBeforeDrag = controller.offset;
    final folderFinder = find.byKey(const ValueKey("folder-2"));
    expect(folderFinder, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(folderFinder));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(find.byIcon(Icons.search)));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.offset, closeTo(offsetBeforeDrag, 1));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text("folder-2"));
    await tester.pumpAndSettle();
    expect(container.read(editorSelectionProvider).selectedSegID, "folder-2");
  });

  testWidgets("chapter icon is indented beyond its parent folder icon", (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(segmentsDataProvider.notifier).setSegmentsData([
      _folder("parent", ["child-chapter"]),
    ]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ChapterSelectionView()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final folderIcon = find.descendant(
      of: find.byKey(const ValueKey("parent")),
      matching: find.byIcon(Icons.folder_open_outlined),
    );
    final chapterIcon = find.descendant(
      of: find.byKey(const ValueKey("child-chapter")),
      matching: find.byIcon(Icons.article_outlined),
    );
    expect(folderIcon, findsOneWidget);
    expect(chapterIcon, findsOneWidget);
    expect(
      tester.getTopLeft(chapterIcon).dx,
      greaterThan(tester.getTopLeft(folderIcon).dx),
    );
  });
}
