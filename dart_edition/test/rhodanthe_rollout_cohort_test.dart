import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_editor_session.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_rollout_cohort.dart";

void main() {
  test("Shadow creates and reuses a privacy-safe cohort bucket", () async {
    final store = _MemoryBucketStore();
    final controller = RhodantheRolloutCohortController(
      store: store,
      nextBucket: () => 73,
    );

    final first = await controller.resolve(stage: RhodantheReleaseStage.shadow);
    final second = await controller.resolve(
      stage: RhodantheReleaseStage.shadow,
    );

    expect(first.bucket, 73);
    expect(first.canaryPercent, 100);
    expect(first.effectiveMode, RhodantheRolloutMode.shadow);
    expect(second.bucket, 73);
    expect(store.writes, 1);
  });

  test("Search canary publishes only for selected buckets", () async {
    final selected = await RhodantheRolloutCohortController(
      store: _MemoryBucketStore(9),
    ).resolve(stage: RhodantheReleaseStage.searchCanary, canaryPercent: 10);
    final fallback = await RhodantheRolloutCohortController(
      store: _MemoryBucketStore(10),
    ).resolve(stage: RhodantheReleaseStage.searchCanary, canaryPercent: 10);

    expect(selected.selected, isTrue);
    expect(selected.effectiveMode, RhodantheRolloutMode.searchCanary);
    expect(fallback.selected, isFalse);
    expect(fallback.effectiveMode, RhodantheRolloutMode.shadow);
  });

  test("Full canary leaves non-selected installations on Search", () async {
    final fallback = await RhodantheRolloutCohortController(
      store: _MemoryBucketStore(50),
    ).resolve(stage: RhodantheReleaseStage.fullCanary, canaryPercent: 25);

    expect(fallback.selected, isFalse);
    expect(fallback.effectiveMode, RhodantheRolloutMode.searchCanary);
  });

  test(
    "invalid persisted bucket is replaced and stage limits are strict",
    () async {
      final store = _MemoryBucketStore(100);
      final repaired = await RhodantheRolloutCohortController(
        store: store,
        nextBucket: () => 42,
      ).resolve(stage: RhodantheReleaseStage.searchCanary);

      expect(repaired.bucket, 42);
      expect(store.writes, 1);
      expect(
        () => resolveRhodantheCanaryPercent(
          RhodantheReleaseStage.defaultOn,
          requestedPercent: 10,
        ),
        throwsArgumentError,
      );
    },
  );
}

final class _MemoryBucketStore implements RhodantheCohortBucketStore {
  int? value;
  int writes = 0;

  _MemoryBucketStore([this.value]);

  @override
  Future<int?> read() async => value;

  @override
  Future<void> write(int bucket) async {
    value = bucket;
    writes++;
  }
}
