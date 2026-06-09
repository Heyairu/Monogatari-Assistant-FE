import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monogatari_assistant/bin/file.dart';
import 'package:monogatari_assistant/modules/chapterselectionview.dart'
    as chapter_module;
import 'package:monogatari_assistant/presentation/providers/project_history_provider.dart';

ProjectData _projectWithChapterContent(String content) {
  return ProjectData.empty()
    ..segmentsData = [
      chapter_module.SegmentData(
        segmentName: 'Segment',
        segmentUUID: 'segment-1',
        chapters: [
          chapter_module.ChapterData(
            chapterName: 'Chapter',
            chapterUUID: 'chapter-1',
            chapterContent: content,
          ),
        ],
      ),
    ]
    ..contentText = content;
}

ProjectHistoryEntry _entry(
  String content, {
  int pageIndex = 0,
  bool isPageTransition = false,
}) {
  return _entryFromData(
    _projectWithChapterContent(content),
    pageIndex: pageIndex,
    cursorOffset: content.length,
    isPageTransition: isPageTransition,
  );
}

ProjectHistoryEntry _entryFromData(
  ProjectData data, {
  int pageIndex = 0,
  int cursorOffset = 0,
  bool isPageTransition = false,
}) {
  return ProjectHistoryEntry(
    data: data,
    pageIndex: pageIndex,
    selectedSegID: 'segment-1',
    selectedChapID: 'chapter-1',
    cursorOffset: cursorOffset,
    isPageTransition: isPageTransition,
  );
}

void main() {
  test('record skips unchanged XML snapshots without page transition', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final history = container.read(projectHistoryProvider.notifier);
    final baseEntry = _entry('one');
    history.reset(baseEntry);

    expect(history.record(_entryFromData(baseEntry.data)), false);
    expect(container.read(projectHistoryProvider).undoStack, hasLength(1));

    expect(history.record(_entry('two')), true);
    expect(container.read(projectHistoryProvider).undoStack, hasLength(2));
  });

  test(
    'record keeps unchanged XML snapshots when page transition is marked',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final history = container.read(projectHistoryProvider.notifier);
      final baseEntry = _entry('one', pageIndex: 1);
      history.reset(baseEntry);

      expect(
        history.record(
          _entryFromData(baseEntry.data, pageIndex: 2, isPageTransition: true),
        ),
        true,
      );
      expect(container.read(projectHistoryProvider).undoStack, hasLength(2));
    },
  );

  test('undo and redo return full project snapshots with page metadata', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final history = container.read(projectHistoryProvider.notifier);
    history.reset(_entry('one', pageIndex: 1));
    history.record(_entry('two', pageIndex: 2));
    history.record(_entry('three', pageIndex: 3));

    final currentEntry = container.read(projectHistoryProvider).undoStack.last;
    final undoTarget = history.undo(currentEntry);
    expect(undoTarget, isNotNull);
    expect(undoTarget!.pageIndex, 2);
    expect(
      undoTarget.data.segmentsData.first.chapters.first.chapterContent,
      'two',
    );
    expect(container.read(projectHistoryProvider).canRedo, true);

    final redoTarget = history.redo(undoTarget);
    expect(redoTarget, isNotNull);
    expect(redoTarget!.pageIndex, 3);
    expect(
      redoTarget.data.segmentsData.first.chapters.first.chapterContent,
      'three',
    );
  });

  test('undo stack keeps the newest 50 XML snapshots', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final history = container.read(projectHistoryProvider.notifier);
    history.reset(_entry('0'));
    for (var i = 1; i <= 60; i++) {
      history.record(_entry('$i'));
    }

    final state = container.read(projectHistoryProvider);
    expect(state.undoStack, hasLength(50));
    expect(
      state
          .undoStack
          .first
          .data
          .segmentsData
          .first
          .chapters
          .first
          .chapterContent,
      '11',
    );
    expect(
      state
          .undoStack
          .last
          .data
          .segmentsData
          .first
          .chapters
          .first
          .chapterContent,
      '60',
    );
  });

  test('record removes previous unchanged page transition snapshot', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final history = container.read(projectHistoryProvider.notifier);
    final baseEntry = _entry('one', pageIndex: 1);
    history.reset(baseEntry);
    history.record(
      _entryFromData(baseEntry.data, pageIndex: 2, isPageTransition: true),
    );
    history.record(_entry('two', pageIndex: 2));

    final state = container.read(projectHistoryProvider);
    expect(state.undoStack, hasLength(2));
    expect(state.undoStack.first.pageIndex, 1);
    expect(state.undoStack.last.pageIndex, 2);
    expect(
      state
          .undoStack
          .last
          .data
          .segmentsData
          .first
          .chapters
          .first
          .chapterContent,
      'two',
    );
  });

  test(
    'record removes previous unchanged page transition then skips no-op',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final history = container.read(projectHistoryProvider.notifier);
      final baseEntry = _entry('one', pageIndex: 1);
      history.reset(baseEntry);
      history.record(
        _entryFromData(baseEntry.data, pageIndex: 2, isPageTransition: true),
      );

      expect(
        history.record(_entryFromData(baseEntry.data, pageIndex: 2)),
        false,
      );

      final state = container.read(projectHistoryProvider);
      expect(state.undoStack, hasLength(1));
      expect(state.undoStack.single.pageIndex, 1);
    },
  );
}
