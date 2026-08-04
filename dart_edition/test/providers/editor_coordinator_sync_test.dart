import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monogatari_assistant/modules/chapterselectionview.dart'
    as chapter_module;
import 'package:monogatari_assistant/presentation/providers/editor_coordinator_provider.dart';
import 'package:monogatari_assistant/presentation/providers/project_state_providers.dart';

void main() {
  test(
    'selected chapter content follows selection before editor content switches',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const segmentId = 'segment-1';
      const firstChapterId = 'chapter-1';
      const secondChapterId = 'chapter-2';
      const firstContent = 'first chapter editor text';
      const secondContent = 'second chapter stored text';

      container.read(segmentsDataProvider.notifier).setSegmentsData([
        chapter_module.SegmentData(
          segmentUUID: segmentId,
          chapters: [
            chapter_module.ChapterData(
              chapterUUID: firstChapterId,
              chapterContent: firstContent,
            ),
            chapter_module.ChapterData(
              chapterUUID: secondChapterId,
              chapterContent: secondContent,
            ),
          ],
        ),
      ]);
      container.read(editorContentProvider.notifier).setContent(firstContent);
      container
          .read(editorSelectionProvider.notifier)
          .setSelection(
            selectedSegID: segmentId,
            selectedChapID: firstChapterId,
          );
      expect(
        container.read(selectedChapterStoredContentProvider),
        firstContent,
      );

      container
          .read(editorSelectionProvider.notifier)
          .setSelection(
            selectedSegID: segmentId,
            selectedChapID: secondChapterId,
          );

      expect(container.read(editorContentProvider), firstContent);
      expect(
        container.read(selectedChapterStoredContentProvider),
        secondContent,
      );
    },
  );

  test('syncEditorToSelectedChapter skips unchanged editor content', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    const segmentId = 'segment-1';
    const chapterId = 'chapter-1';
    const content = 'unchanged content';
    final segments = [
      chapter_module.SegmentData(
        segmentUUID: segmentId,
        chapters: [
          chapter_module.ChapterData(
            chapterUUID: chapterId,
            chapterContent: content,
          ),
        ],
      ),
    ];

    container.read(segmentsDataProvider.notifier).setSegmentsData(segments);
    container
        .read(editorSelectionProvider.notifier)
        .setSelectionAndCursor(
          selectedSegID: segmentId,
          selectedChapID: chapterId,
          cursorOffset: 0,
        );

    final events = <List<chapter_module.SegmentData>>[];
    container.listen<List<chapter_module.SegmentData>>(
      segmentsDataProvider,
      (previous, next) => events.add(next),
      fireImmediately: false,
    );

    final controller = TextEditingController(text: content);
    addTearDown(controller.dispose);

    container
        .read(editorCoordinatorProvider.notifier)
        .syncEditorToSelectedChapter(textController: controller);

    expect(events, isEmpty);
    expect(container.read(editorContentProvider), isEmpty);
  });

  test('syncEditorToSelectedChapter publishes changed editor content', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    const segmentId = 'segment-1';
    const chapterId = 'chapter-1';
    const originalContent = 'original content';
    const editedContent = 'edited content';
    final segments = [
      chapter_module.SegmentData(
        segmentUUID: segmentId,
        chapters: [
          chapter_module.ChapterData(
            chapterUUID: chapterId,
            chapterContent: originalContent,
          ),
        ],
      ),
    ];

    container.read(segmentsDataProvider.notifier).setSegmentsData(segments);
    container
        .read(editorSelectionProvider.notifier)
        .setSelectionAndCursor(
          selectedSegID: segmentId,
          selectedChapID: chapterId,
          cursorOffset: 0,
        );

    final events = <List<chapter_module.SegmentData>>[];
    container.listen<List<chapter_module.SegmentData>>(
      segmentsDataProvider,
      (previous, next) => events.add(next),
      fireImmediately: false,
    );

    final controller = TextEditingController(text: editedContent);
    addTearDown(controller.dispose);

    container
        .read(editorCoordinatorProvider.notifier)
        .syncEditorToSelectedChapter(textController: controller);

    expect(events, hasLength(1));
    expect(
      container
          .read(segmentsDataProvider)
          .single
          .chapters
          .single
          .chapterContent,
      editedContent,
    );
    expect(container.read(editorContentProvider), editedContent);
  });

  test('syncEditorToSelectedChapter updates a recursively nested chapter', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    const folderId = 'nested-folder';
    const chapterId = 'nested-chapter';
    const editedContent = 'nested edited content';
    container.read(segmentsDataProvider.notifier).setSegmentsData([
      chapter_module.SegmentData(
        segmentUUID: 'root-folder',
        childSegments: [
          chapter_module.SegmentData(
            segmentUUID: folderId,
            chapters: [
              chapter_module.ChapterData(
                chapterUUID: chapterId,
                chapterContent: 'original',
              ),
            ],
          ),
        ],
      ),
    ]);
    container
        .read(editorSelectionProvider.notifier)
        .setSelectionAndCursor(
          selectedSegID: folderId,
          selectedChapID: chapterId,
          cursorOffset: 0,
        );
    final controller = TextEditingController(text: editedContent);
    addTearDown(controller.dispose);

    container
        .read(editorCoordinatorProvider.notifier)
        .syncEditorToSelectedChapter(textController: controller);

    final location = chapter_module.ChapterTree.findChapter(
      container.read(segmentsDataProvider),
      folderId: folderId,
      chapterId: chapterId,
    );
    expect(location?.chapter.chapterContent, editedContent);
  });
}
