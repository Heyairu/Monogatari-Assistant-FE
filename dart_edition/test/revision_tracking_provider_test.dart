import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monogatari_assistant/features/revision_tracking/domain/revision_models.dart';
import 'package:monogatari_assistant/features/revision_tracking/presentation/revision_tracking_panel.dart';
import 'package:monogatari_assistant/features/revision_tracking/application/revision_review_service.dart';
import 'package:monogatari_assistant/features/revision_tracking/application/revision_session_codec.dart';
import 'package:monogatari_assistant/features/revision_tracking/application/revision_snapshot_builder.dart';
import 'package:monogatari_assistant/presentation/providers/project_state_providers.dart';
import 'package:monogatari_assistant/presentation/providers/project_history_provider.dart';
import 'package:monogatari_assistant/presentation/providers/revision_tracking_provider.dart';
import 'package:monogatari_assistant/models/project_data.dart';

Future<RevisionTrackingState> waitForComplete(
  ProviderContainer container,
) async {
  await Future<void>.delayed(Duration.zero);
  final current = container.read(revisionTrackingProvider);
  if (current.status == RevisionComparisonStatus.complete) return current;
  final done = Completer<RevisionTrackingState>();
  final subscription = container.listen(revisionTrackingProvider, (_, next) {
    if (next.status == RevisionComparisonStatus.complete && !done.isCompleted) {
      done.complete(next);
    }
    if (next.status == RevisionComparisonStatus.failed && !done.isCompleted) {
      done.completeError(next.error ?? 'failed');
    }
  });
  try {
    return await done.future.timeout(const Duration(seconds: 10));
  } finally {
    subscription.close();
  }
}

void main() {
  test('tracks live draft, field edits and resets across projects', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final projectId = container.read(projectUuidProvider);
    final chapterId = container
        .read(segmentsDataProvider)
        .first
        .chapters
        .first
        .chapterUUID;
    container.read(revisionTrackingProvider.notifier).start();
    final empty = await waitForComplete(container);
    expect(empty.comparison!.hasChanges, isFalse);
    container
        .read(revisionEditorDraftProvider.notifier)
        .update(projectId, chapterId, '第一稿');
    container
        .read(revisionEditorDraftProvider.notifier)
        .update(projectId, chapterId, '第二稿');
    container.read(baseInfoDataProvider.notifier).setBookName('新書名');
    final changed = await waitForComplete(container);
    expect(changed.comparison!.addedLines, 1);
    expect(
      changed.comparison!.texts.single.lines
          .singleWhere((line) => line.after != null)
          .after!
          .text,
      '第二稿',
    );
    expect(changed.comparison!.records.single.fields.single.target.fieldPath, [
      'bookName',
    ]);
    expect(changed.baseline!.snapshot.chapterTexts[chapterId], '');
    container
        .read(revisionTrackingProvider.notifier)
        .setFilter(RevisionViewFilter.settings);
    expect(
      container.read(revisionTrackingProvider).comparison,
      same(changed.comparison),
    );
    container
        .read(projectUuidProvider.notifier)
        .setProjectUuid(ProjectData.createProjectUUID());
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(revisionTrackingProvider).status,
      RevisionComparisonStatus.notStarted,
    );
    expect(container.read(revisionEditorDraftProvider), isNull);
  });

  testWidgets('panel displays a read-only field revision', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    String? navigatedField;
    await tester.runAsync(() async {
      container.read(revisionTrackingProvider.notifier).start();
      await waitForComplete(container);
      container.read(baseInfoDataProvider.notifier).setBookName('新書名');
      await waitForComplete(container);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 280,
              child: RevisionTrackingPanel(
                onStart: () =>
                    container.read(revisionTrackingProvider.notifier).start(),
                onClose: () {},
                onNavigateText: (_, __, ___) {},
                onNavigateRecord: (_, field) {
                  navigatedField = field?.target.fieldPath.join('/');
                },
                sidebarPageIndex: 1,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('書名'), findsWidgets);
    expect(find.textContaining('新書名'), findsWidgets);
    expect(find.text('結束追蹤'), findsOneWidget);
    await tester.tap(find.textContaining('書名').first);
    await tester.pump();
    expect(navigatedField, 'bookName');
    await tester.tap(find.text('結束追蹤'));
    await tester.pump();
    expect(find.text('開始追蹤'), findsOneWidget);
  });

  testWidgets('start button creates a baseline', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 340,
              child: RevisionTrackingPanel(
                onStart: () =>
                    container.read(revisionTrackingProvider.notifier).start(),
                onClose: () {},
                onNavigateText: (_, __, ___) {},
                onNavigateRecord: (_, __) {},
                sidebarPageIndex: 1,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開始追蹤'));
    expect(container.read(revisionTrackingProvider).baseline, isNotNull);
  });

  test(
    'accepted field is exact, persists, and a later edit is pending',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(revisionTrackingProvider.notifier).start();
      await waitForComplete(container);
      container.read(baseInfoDataProvider.notifier).setBookName('第一個名稱');
      final first = await waitForComplete(container);
      final record = first.comparison!.records.single;
      final key = RevisionReviewService.recordKey(
        first.baseline!,
        record,
        record.fields.single,
      );
      container.read(revisionTrackingProvider.notifier).acceptEvent(key);
      expect(
        container.read(revisionTrackingProvider).acceptedEvents,
        contains(key),
      );
      final serialized = container.read(revisionTrackingJsonProvider);
      expect(serialized, contains('acceptedEvents'));
      expect(
        container.read(projectDataProvider).revisionTrackingJson,
        serialized,
      );
      container.read(baseInfoDataProvider.notifier).setBookName('第二個名稱');
      final second = await waitForComplete(container);
      final nextKey = RevisionReviewService.recordKey(
        second.baseline!,
        second.comparison!.records.single,
        second.comparison!.records.single.fields.single,
      );
      expect(nextKey, isNot(key));
      expect(second.acceptedEvents, isNot(contains(nextKey)));
      container
          .read(revisionTrackingProvider.notifier)
          .saveCheckpoint(label: '手動版本');
      expect(container.read(revisionTrackingProvider).baselines.length, 2);
      final checkpoint = await waitForComplete(container);
      expect(checkpoint.baseline?.label, '手動版本');
      expect(checkpoint.comparison!.hasChanges, isFalse);
      container
          .read(revisionTrackingProvider.notifier)
          .selectBaseline(checkpoint.baselines.first.id);
      final saved = container.read(revisionTrackingJsonProvider);
      container.read(revisionTrackingProvider.notifier).stop();
      container.read(revisionTrackingJsonProvider.notifier).setJson(saved);
      container
          .read(revisionTrackingProvider.notifier)
          .restore(saved, projectId: container.read(projectUuidProvider));
      final restored = await waitForComplete(container);
      expect(restored.baselines.map((item) => item.label), ['開始追蹤', '手動版本']);
      expect(restored.baseline?.label, '手動版本');
      expect(restored.acceptedEvents, contains(key));
      container
          .read(revisionTrackingProvider.notifier)
          .restoreReviewDecisions(null);
      expect(container.read(revisionTrackingProvider).acceptedEvents, isEmpty);
      container
          .read(revisionTrackingProvider.notifier)
          .restoreReviewDecisions(saved);
      expect(
        container.read(revisionTrackingProvider).acceptedEvents,
        contains(key),
      );
    },
  );

  test(
    'queued old-project updates cannot stop a restored new session',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(revisionTrackingProvider.notifier).start();
      await waitForComplete(container);
      final replacement = ProjectData.empty();
      final baseline = RevisionBaseline(
        id: 'new-session',
        label: '新專案',
        createdAt: DateTime.utc(2026),
        snapshot: RevisionSnapshotBuilder.capture(replacement, version: 'v1'),
      );
      final saved = RevisionSessionCodec.encode(
        RevisionSessionData(
          selectedBaselineId: baseline.id,
          baselines: [baseline],
          acceptedEvents: const {},
        ),
      );
      container.read(revisionTrackingProvider.notifier).stop();
      container
          .read(projectUuidProvider.notifier)
          .setProjectUuid(replacement.projectUUID);
      container.read(revisionTrackingJsonProvider.notifier).setJson(saved);
      container
          .read(revisionTrackingProvider.notifier)
          .restore(saved, projectId: replacement.projectUUID);
      final restored = await waitForComplete(container);
      expect(restored.baseline?.id, 'new-session');
    },
  );

  test(
    'verified historical source is read-only and persists its origin',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final projectId = container.read(projectUuidProvider);
      final historical = ProjectData.empty(projectUUID: projectId);
      historical.baseInfoData = historical.baseInfoData.copyWith(
        bookName: '舊版書名',
      );
      container
          .read(revisionTrackingProvider.notifier)
          .addHistoricalSource(
            historical,
            revisionId: 'remote-1',
            label: '遠端版本',
          );
      final state = await waitForComplete(container);
      expect(state.baseline!.readOnly, isTrue);
      expect(state.baseline!.sourceRevisionId, 'remote-1');
      expect(state.comparison!.records, isNotEmpty);
      final record = state.comparison!.records.first;
      final key = RevisionReviewService.recordKey(
        state.baseline!,
        record,
        record.fields.first,
      );
      container.read(revisionTrackingProvider.notifier).acceptEvent(key);
      expect(container.read(revisionTrackingProvider).acceptedEvents, isEmpty);
      final saved = container.read(revisionTrackingJsonProvider)!;
      final decoded = RevisionSessionCodec.decode(saved, projectId: projectId);
      expect(decoded.baselines.last.readOnly, isTrue);
      expect(decoded.baselines.last.sourceRevisionId, 'remote-1');
      container.read(revisionTrackingProvider.notifier).stop();
      container.read(revisionTrackingJsonProvider.notifier).setJson(saved);
      container
          .read(revisionTrackingProvider.notifier)
          .restore(saved, projectId: projectId);
      final restored = await waitForComplete(container);
      expect(restored.baseline?.sourceRevisionId, 'remote-1');
    },
  );

  test(
    'project history tracks decisions but ignores checkpoint-only changes',
    () {
      final project = ProjectData.empty();
      final snapshot = RevisionSnapshotBuilder.capture(project, version: 'v1');
      String session(String label, Set<String> accepted) =>
          RevisionSessionCodec.encode(
            RevisionSessionData(
              selectedBaselineId: 'first',
              baselines: [
                RevisionBaseline(
                  id: 'first',
                  label: label,
                  createdAt: DateTime.utc(2026),
                  snapshot: snapshot,
                ),
              ],
              acceptedEvents: accepted,
            ),
          );
      ProjectHistoryEntry entry() => ProjectHistoryEntry(
        data: project,
        pageIndex: 0,
        selectedSegID: null,
        selectedChapID: null,
        cursorOffset: 0,
      );
      project.revisionTrackingJson = session('第一版', {});
      final original = entry();
      project.revisionTrackingJson = session('新檢查點標籤', {});
      expect(entry().contentDigest, original.contentDigest);
      project.revisionTrackingJson = session('新檢查點標籤', {'accepted'});
      expect(entry().contentDigest, isNot(original.contentDigest));
    },
  );
}
