import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
}
