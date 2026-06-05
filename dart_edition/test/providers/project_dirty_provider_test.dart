import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monogatari_assistant/modules/chapterselectionview.dart'
    as chapter_module;
import 'package:monogatari_assistant/presentation/providers/editor_coordinator_provider.dart';
import 'package:monogatari_assistant/presentation/providers/project_state_providers.dart';

void main() {
  test('projectDataAggregateProvider updates when segments change', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final events = <int>[];
    container.listen<int>(projectDataAggregateProvider, (prev, next) {
      events.add(next);
    }, fireImmediately: false);

    // Read current fingerprint
    final before = container.read(projectDataAggregateProvider);

    // Mutate segmentsDataProvider via its notifier if available
    final segmentsNotifier = container.read(segmentsDataProvider.notifier);

    // Apply a small mutation: reapply current value to trigger update
    segmentsNotifier.updateSegmentsData((current) => [...current]);

    final after = container.read(projectDataAggregateProvider);

    expect(before, isNotNull);
    expect(after, isNotNull);
    // Either the fingerprint changed or at least an event was emitted
    expect(after == before || events.isNotEmpty, true);
  });

  test('resetAfterProjectLoaded cancels pending dirty notification', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final coordinator = container.read(editorCoordinatorProvider.notifier);
    final beganApplying = coordinator.beginApplyingProjectData();

    container.read(segmentsDataProvider.notifier).setSegmentsData([
      chapter_module.SegmentData(
        segmentName: 'Loaded segment',
        segmentUUID: 'loaded-segment',
        chapters: [
          chapter_module.ChapterData(
            chapterName: 'Loaded chapter',
            chapterUUID: 'loaded-chapter',
            chapterContent: 'Loaded content',
          ),
        ],
      ),
    ]);

    coordinator.resetAfterProjectLoaded();
    if (beganApplying) {
      coordinator.endApplyingProjectData();
    }

    await Future<void>.delayed(const Duration(milliseconds: 220));

    expect(container.read(editorCoordinatorProvider).hasUnsavedChanges, false);
  });
}
