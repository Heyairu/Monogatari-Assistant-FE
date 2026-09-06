import "dart:math";

import "package:shared_preferences/shared_preferences.dart";

import "rhodanthe_editor_session.dart";
import "rhodanthe_rollout_cohort_policy.dart";

export "rhodanthe_rollout_cohort_policy.dart";

abstract interface class RhodantheCohortBucketStore {
  Future<int?> read();

  Future<void> write(int bucket);
}

final class SharedPreferencesRhodantheCohortBucketStore
    implements RhodantheCohortBucketStore {
  static const String storageKey = "rhodanthe.rollout.cohortBucket.v1";

  const SharedPreferencesRhodantheCohortBucketStore();

  @override
  Future<int?> read() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(storageKey);
  }

  @override
  Future<void> write(int bucket) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setInt(storageKey, bucket)) {
      throw StateError("Unable to persist Rhodanthe cohort bucket");
    }
  }
}

final class RhodantheCohortResolution {
  final RhodantheReleaseStage stage;
  final int? bucket;
  final int canaryPercent;
  final bool selected;
  final RhodantheRolloutMode effectiveMode;

  const RhodantheCohortResolution({
    required this.stage,
    required this.bucket,
    required this.canaryPercent,
    required this.selected,
    required this.effectiveMode,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    "stage": stage.name,
    "bucket": bucket,
    "canaryPercent": canaryPercent,
    "selected": selected,
    "effectiveMode": effectiveMode.name,
  };
}

final class RhodantheRolloutCohortController {
  final RhodantheCohortBucketStore _store;
  final int Function() _nextBucket;

  RhodantheRolloutCohortController({
    RhodantheCohortBucketStore store =
        const SharedPreferencesRhodantheCohortBucketStore(),
    int Function()? nextBucket,
  }) : _store = store,
       _nextBucket = nextBucket ?? (() => Random.secure().nextInt(100));

  Future<RhodantheCohortResolution> resolve({
    required RhodantheReleaseStage stage,
    int? canaryPercent,
  }) async {
    final percent = resolveRhodantheCanaryPercent(
      stage,
      requestedPercent: canaryPercent,
    );
    if (stage == RhodantheReleaseStage.off) {
      return const RhodantheCohortResolution(
        stage: RhodantheReleaseStage.off,
        bucket: null,
        canaryPercent: 0,
        selected: false,
        effectiveMode: RhodantheRolloutMode.disabled,
      );
    }
    var bucket = await _store.read();
    if (bucket == null || bucket < 0 || bucket >= 100) {
      bucket = _nextBucket();
      if (bucket < 0 || bucket >= 100) {
        throw StateError(
          "Rhodanthe cohort generator returned an invalid bucket",
        );
      }
      await _store.write(bucket);
    }
    final selected = bucket < percent;
    return RhodantheCohortResolution(
      stage: stage,
      bucket: bucket,
      canaryPercent: percent,
      selected: selected,
      effectiveMode: _effectiveMode(stage, selected),
    );
  }
}

RhodantheRolloutMode _effectiveMode(
  RhodantheReleaseStage stage,
  bool selected,
) => switch (stage) {
  RhodantheReleaseStage.off => RhodantheRolloutMode.disabled,
  RhodantheReleaseStage.shadow => RhodantheRolloutMode.shadow,
  RhodantheReleaseStage.searchCanary =>
    selected ? RhodantheRolloutMode.searchCanary : RhodantheRolloutMode.shadow,
  RhodantheReleaseStage.fullCanary =>
    selected ? RhodantheRolloutMode.full : RhodantheRolloutMode.searchCanary,
  RhodantheReleaseStage.defaultOn => RhodantheRolloutMode.full,
};
