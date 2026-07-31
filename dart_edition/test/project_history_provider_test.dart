import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

import "package:monogatari_assistant/bin/file.dart";
import "package:monogatari_assistant/presentation/providers/project_history_provider.dart";

ProjectData _copyProject(
  ProjectData source, {
  required String chapterContent,
  DateTime? latestSave,
}) {
  final segment = source.segmentsData.single;
  final chapter = segment.chapters.single;
  return ProjectData(
    baseInfoData: source.baseInfoData.copyWith(
      bookName: "History test",
      latestSave: latestSave,
    ),
    segmentsData: [
      segment.copyWith(
        chapters: [chapter.copyWith(chapterContent: chapterContent)],
      ),
    ],
    outlineData: source.outlineData,
    foreshadowData: source.foreshadowData,
    updatePlanData: source.updatePlanData,
    worldSettingsData: source.worldSettingsData,
    characterData: source.characterData,
    totalWords: chapterContent.length,
    contentText: chapterContent,
    isDirty: source.isDirty,
  );
}

ProjectHistoryEntry _entry(ProjectData data, {bool pageTransition = false}) {
  return ProjectHistoryEntry(
    data: data,
    pageIndex: 2,
    selectedSegID: data.segmentsData.single.segmentUUID,
    selectedChapID: data.segmentsData.single.chapters.single.chapterUUID,
    cursorOffset: data.contentText.length,
    isPageTransition: pageTransition,
  );
}

void main() {
  test("entry retains one snapshot and only a fixed-size digest", () {
    final source = _copyProject(
      ProjectData.empty(),
      chapterContent: "original",
    );
    final entry = _entry(source);

    source.segmentsData.clear();

    expect(entry.data.segmentsData, hasLength(1));
    expect(
      entry.data.segmentsData.single.chapters.single.chapterContent,
      "original",
    );
    expect(entry.contentDigest.toString().length, lessThan(40));
    expect(
      entry.approximateByteSize,
      greaterThan(entry.contentDigest.serializedCodeUnits * 2),
    );
  });

  test("digest is deterministic and ignores LatestSave", () {
    final seed = ProjectData.empty();
    final first = _entry(
      _copyProject(
        seed,
        chapterContent: "same content",
        latestSave: DateTime.utc(2024, 1, 1),
      ),
    );
    final second = _entry(
      _copyProject(
        seed,
        chapterContent: "same content",
        latestSave: DateTime.utc(2026, 7, 31),
      ),
    );
    final changed = _entry(
      _copyProject(
        seed,
        chapterContent: "different content",
        latestSave: DateTime.utc(2026, 7, 31),
      ),
    );

    expect(first.contentDigest, second.contentDigest);
    expect(first.contentDigest, isNot(changed.contentDigest));
  });

  test("record deduplicates content and enforces the total count limit", () {
    final seed = ProjectData.empty();
    final provider =
        NotifierProvider<ProjectHistoryNotifier, ProjectHistoryState>(
          () => ProjectHistoryNotifier(
            maxEntries: 3,
            maxApproximateBytes: 1024 * 1024,
          ),
        );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(provider.notifier);

    final entries = List<ProjectHistoryEntry>.generate(
      5,
      (index) => _entry(_copyProject(seed, chapterContent: "content $index")),
    );
    notifier.reset(entries.first);
    expect(
      notifier.record(_entry(_copyProject(seed, chapterContent: "content 0"))),
      isFalse,
    );
    for (final entry in entries.skip(1)) {
      expect(notifier.record(entry), isTrue);
    }

    final state = container.read(provider);
    expect(state.entryCount, 3);
    expect(
      state.undoStack.map((entry) => entry.contentDigest),
      entries.skip(2).map((entry) => entry.contentDigest),
    );
    expect(state.redoStack, isEmpty);
  });

  test("byte budget is shared by undo and redo and keeps nearest steps", () {
    final seed = ProjectData.empty();
    final entries = List<ProjectHistoryEntry>.generate(
      3,
      (index) => _entry(_copyProject(seed, chapterContent: "value-$index")),
    );
    final budget =
        entries[1].approximateByteSize + entries[2].approximateByteSize;
    final provider =
        NotifierProvider<ProjectHistoryNotifier, ProjectHistoryState>(
          () => ProjectHistoryNotifier(
            maxEntries: 10,
            maxApproximateBytes: budget,
          ),
        );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(provider.notifier);

    notifier.reset(entries[0]);
    notifier.record(entries[1]);
    notifier.record(entries[2]);

    final beforeUndo = container.read(provider);
    expect(beforeUndo.undoStack, hasLength(2));
    expect(beforeUndo.undoStack.first.contentDigest, entries[1].contentDigest);

    final target = notifier.undo(entries[2]);
    final afterUndo = container.read(provider);
    expect(target?.contentDigest, entries[1].contentDigest);
    expect(afterUndo.undoStack.single.contentDigest, entries[1].contentDigest);
    expect(afterUndo.redoStack.single.contentDigest, entries[2].contentDigest);
    expect(afterUndo.entryCount, 2);
    expect(afterUndo.approximateByteSize, lessThanOrEqualTo(budget));
  });

  test("undo and redo preserve the expected project states", () {
    final seed = ProjectData.empty();
    final a = _entry(_copyProject(seed, chapterContent: "A"));
    final b = _entry(_copyProject(seed, chapterContent: "B"));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(projectHistoryProvider.notifier);

    notifier.reset(a);
    notifier.record(b);

    expect(notifier.undo(b)?.contentDigest, a.contentDigest);
    expect(container.read(projectHistoryProvider).canRedo, isTrue);
    expect(notifier.redo(a)?.contentDigest, b.contentDigest);
    expect(container.read(projectHistoryProvider).canRedo, isFalse);
  });

  test("undo captures an unrecorded current state for redo", () {
    final seed = ProjectData.empty();
    final a = _entry(_copyProject(seed, chapterContent: "A"));
    final b = _entry(_copyProject(seed, chapterContent: "B"));
    final c = _entry(_copyProject(seed, chapterContent: "C"));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(projectHistoryProvider.notifier);

    notifier.reset(a);
    notifier.record(b);

    expect(notifier.undo(c)?.contentDigest, b.contentDigest);
    expect(
      container.read(projectHistoryProvider).redoStack.single.contentDigest,
      c.contentDigest,
    );
  });

  test("new content clears redo while a duplicate keeps it", () {
    final seed = ProjectData.empty();
    final a = _entry(_copyProject(seed, chapterContent: "A"));
    final b = _entry(_copyProject(seed, chapterContent: "B"));
    final c = _entry(_copyProject(seed, chapterContent: "C"));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(projectHistoryProvider.notifier);

    notifier.reset(a);
    notifier.record(b);
    notifier.undo(b);

    expect(notifier.record(a), isFalse);
    expect(container.read(projectHistoryProvider).canRedo, isTrue);

    expect(notifier.record(c), isTrue);
    expect(container.read(projectHistoryProvider).redoStack, isEmpty);
  });

  test("unchanged trailing page transition is removed on normal record", () {
    final seed = ProjectData.empty();
    final a = _entry(_copyProject(seed, chapterContent: "A"));
    final transition = _entry(
      _copyProject(seed, chapterContent: "A"),
      pageTransition: true,
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(projectHistoryProvider.notifier);

    notifier.reset(a);
    expect(notifier.record(transition), isTrue);
    expect(container.read(projectHistoryProvider).undoStack, hasLength(2));

    expect(
      notifier.record(_entry(_copyProject(seed, chapterContent: "A"))),
      isFalse,
    );
    expect(container.read(projectHistoryProvider).undoStack, hasLength(1));
  });

  test("a single oversized current state remains available", () {
    final entry = _entry(
      _copyProject(ProjectData.empty(), chapterContent: "large state"),
    );
    final provider =
        NotifierProvider<ProjectHistoryNotifier, ProjectHistoryState>(
          () => ProjectHistoryNotifier(maxEntries: 10, maxApproximateBytes: 1),
        );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(provider.notifier);

    notifier.reset(entry);

    final state = container.read(provider);
    expect(state.undoStack.single.contentDigest, entry.contentDigest);
    expect(state.approximateByteSize, greaterThan(1));
  });
}
