import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monogatari_assistant/modules/chapterselectionview.dart'
    as chapter_module;
import 'package:monogatari_assistant/presentation/providers/editor_coordinator_provider.dart';
import 'package:monogatari_assistant/presentation/providers/project_state_providers.dart';

void main() {
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
}
