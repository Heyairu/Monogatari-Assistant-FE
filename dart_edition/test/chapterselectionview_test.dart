import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/modules/chapterselectionview.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("ChapterSelectionView initializes selection and editor content", (
    tester,
  ) async {
    final container = ProviderContainer();

    final segment = SegmentData(
      segmentName: "Seg A",
      chapters: [
        ChapterData(chapterName: "Chapter A1", chapterContent: "內容A1"),
      ],
    );

    container.read(segmentsDataProvider.notifier).state = [segment];

    await tester.pumpWidget(
      ProviderScope(
        parent: container,
        child: const MaterialApp(
          home: Scaffold(
            body: ChapterSelectionView(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text("章節選擇"), findsAtLeastNWidgets(1));

    final selection = container.read(editorSelectionProvider);
    expect(selection.selectedSegID, isNotNull);
    expect(selection.selectedChapID, isNotNull);
    expect(container.read(editorContentProvider), "內容A1");
  });
}
