import "rhodanthe_editor_session.dart";

const int _configuredRhodantheCanaryPercent = int.fromEnvironment(
  "RHODANTHE_CANARY_PERCENT",
  defaultValue: -1,
);

int configuredRhodantheCanaryPercent(RhodantheReleaseStage stage) {
  return resolveRhodantheCanaryPercent(
    stage,
    requestedPercent: _configuredRhodantheCanaryPercent == -1
        ? null
        : _configuredRhodantheCanaryPercent,
  );
}

int resolveRhodantheCanaryPercent(
  RhodantheReleaseStage stage, {
  int? requestedPercent,
}) {
  final percent =
      requestedPercent ??
      switch (stage) {
        RhodantheReleaseStage.off => 0,
        RhodantheReleaseStage.shadow || RhodantheReleaseStage.defaultOn => 100,
        RhodantheReleaseStage.searchCanary ||
        RhodantheReleaseStage.fullCanary => 10,
      };
  _validatePercent(stage, percent);
  return percent;
}

void _validatePercent(RhodantheReleaseStage stage, int percent) {
  if (stage == RhodantheReleaseStage.off) {
    if (percent != 0) throw ArgumentError("off requires a 0% cohort");
    return;
  }
  if (percent < 1 || percent > 100) {
    throw ArgumentError.value(percent, "canaryPercent", "must be 1..100");
  }
  if ((stage == RhodantheReleaseStage.shadow ||
          stage == RhodantheReleaseStage.defaultOn) &&
      percent != 100) {
    throw ArgumentError("${stage.name} requires a 100% cohort");
  }
}
