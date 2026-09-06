import "rhodanthe_editor_session.dart";
import "rhodanthe_rollout_guard.dart";

final class RhodantheAuditCheckResult {
  final bool ok;
  final String code;
  final String buildId;
  final RhodantheRolloutMode currentMode;
  final RhodantheRolloutMode actualRecommendation;
  final RhodantheRolloutMode requiredRecommendation;
  final String decisionReason;
  final String requiredDecisionReason;

  const RhodantheAuditCheckResult({
    required this.ok,
    required this.code,
    required this.buildId,
    required this.currentMode,
    required this.actualRecommendation,
    required this.requiredRecommendation,
    required this.decisionReason,
    required this.requiredDecisionReason,
  });

  Map<String, Object?> toJson() => <String, Object?>{
    "stage": "rolloutAuditGate",
    "ok": ok,
    "code": code,
    "buildId": buildId,
    "currentMode": currentMode.name,
    "actualRecommendation": actualRecommendation.name,
    "requiredRecommendation": requiredRecommendation.name,
    "decisionReason": decisionReason,
    "requiredDecisionReason": requiredDecisionReason,
  };
}

RhodantheAuditCheckResult checkRhodantheRolloutAudit({
  required Map<String, Object?> report,
  required String expectedBuildId,
  required RhodantheRolloutMode currentMode,
  required RhodantheRolloutMode requiredRecommendation,
}) {
  final buildId = _string(report["buildId"], "buildId");
  if (report["version"] != RhodantheRolloutGuard.evidenceVersion) {
    throw const FormatException("unsupported rollout audit version");
  }
  final modes = _map(report["modes"], "modes");
  final policy = _map(report["policy"], "policy");
  final shadowSamplesRequired = _positiveInt(
    policy["shadowSamplesRequired"],
    "policy.shadowSamplesRequired",
  );
  final canarySamplesRequired = _positiveInt(
    policy["canarySamplesRequired"],
    "policy.canarySamplesRequired",
  );
  final p95BudgetMicros = _positiveInt(
    policy["p95BudgetMicros"],
    "policy.p95BudgetMicros",
  );
  if (shadowSamplesRequired < rhodantheShadowSamplesRequired ||
      canarySamplesRequired < rhodantheCanarySamplesRequired ||
      p95BudgetMicros > rhodantheP95BudgetMicros) {
    throw const FormatException(
      "rollout audit policy is weaker than the production minimum",
    );
  }
  final decision = _map(modes[currentMode.name], "modes.${currentMode.name}");
  final reportedCurrent = _mode(
    decision["currentMode"],
    "modes.${currentMode.name}.currentMode",
  );
  if (reportedCurrent != currentMode) {
    throw FormatException(
      "audit mode ${reportedCurrent.name} does not match ${currentMode.name}",
    );
  }
  final actualRecommendation = _mode(
    decision["recommendedMode"],
    "modes.${currentMode.name}.recommendedMode",
  );
  final decisionReason = _reason(
    decision["reason"],
    "modes.${currentMode.name}.reason",
  );
  final completedSamples = _nonNegativeInt(
    decision["completedSamples"],
    "modes.${currentMode.name}.completedSamples",
  );
  final failures = _nonNegativeInt(
    decision["failures"],
    "modes.${currentMode.name}.failures",
  );
  final mismatches = _nonNegativeInt(
    decision["mismatches"],
    "modes.${currentMode.name}.mismatches",
  );
  final p95Micros = _nonNegativeInt(
    decision["p95Micros"],
    "modes.${currentMode.name}.p95Micros",
  );
  final samplesRequired = currentMode == RhodantheRolloutMode.shadow
      ? shadowSamplesRequired
      : canarySamplesRequired;
  _validateDecisionMetrics(
    reason: decisionReason,
    completedSamples: completedSamples,
    samplesRequired: samplesRequired,
    failures: failures,
    mismatches: mismatches,
    p95Micros: p95Micros,
    p95BudgetMicros: p95BudgetMicros,
  );
  final expectedRecommendation = _recommendationForReason(
    currentMode,
    decisionReason,
  );
  if (actualRecommendation != expectedRecommendation) {
    throw const FormatException(
      "rollout recommendation is inconsistent with its decision reason",
    );
  }
  final buildMatches = buildId == expectedBuildId;
  final recommendationMatches = actualRecommendation == requiredRecommendation;
  final requiredDecisionReason = _requiredDecisionReason(
    currentMode,
    requiredRecommendation,
  );
  final reasonMatches = switch (requiredDecisionReason) {
    "rollback" =>
      decisionReason == RhodantheRolloutDecisionReason.failure ||
          decisionReason == RhodantheRolloutDecisionReason.mismatch ||
          decisionReason == RhodantheRolloutDecisionReason.latency,
    _ => decisionReason.name == requiredDecisionReason,
  };
  return RhodantheAuditCheckResult(
    ok: buildMatches && recommendationMatches && reasonMatches,
    code: !buildMatches
        ? "buildIdMismatch"
        : !recommendationMatches
        ? "recommendationMismatch"
        : !reasonMatches
        ? "decisionReasonMismatch"
        : "accepted",
    buildId: buildId,
    currentMode: currentMode,
    actualRecommendation: actualRecommendation,
    requiredRecommendation: requiredRecommendation,
    decisionReason: decisionReason.name,
    requiredDecisionReason: requiredDecisionReason,
  );
}

RhodantheRolloutMode _recommendationForReason(
  RhodantheRolloutMode currentMode,
  RhodantheRolloutDecisionReason reason,
) => switch (reason) {
  RhodantheRolloutDecisionReason.eligible => switch (currentMode) {
    RhodantheRolloutMode.disabled => RhodantheRolloutMode.shadow,
    RhodantheRolloutMode.shadow => RhodantheRolloutMode.searchCanary,
    RhodantheRolloutMode.searchCanary => RhodantheRolloutMode.full,
    RhodantheRolloutMode.full => RhodantheRolloutMode.full,
  },
  RhodantheRolloutDecisionReason.failure ||
  RhodantheRolloutDecisionReason.mismatch ||
  RhodantheRolloutDecisionReason.latency => switch (currentMode) {
    RhodantheRolloutMode.disabled || RhodantheRolloutMode.shadow => currentMode,
    RhodantheRolloutMode.searchCanary => RhodantheRolloutMode.shadow,
    RhodantheRolloutMode.full => RhodantheRolloutMode.searchCanary,
  },
  RhodantheRolloutDecisionReason.insufficientSamples => currentMode,
  RhodantheRolloutDecisionReason.alreadyFull => RhodantheRolloutMode.full,
};

String _requiredDecisionReason(
  RhodantheRolloutMode currentMode,
  RhodantheRolloutMode requiredRecommendation,
) {
  if (requiredRecommendation.index > currentMode.index) return "eligible";
  if (requiredRecommendation.index < currentMode.index) return "rollback";
  if (currentMode == RhodantheRolloutMode.full) return "alreadyFull";
  return "insufficientSamples";
}

void _validateDecisionMetrics({
  required RhodantheRolloutDecisionReason reason,
  required int completedSamples,
  required int samplesRequired,
  required int failures,
  required int mismatches,
  required int p95Micros,
  required int p95BudgetMicros,
}) {
  final valid = switch (reason) {
    RhodantheRolloutDecisionReason.failure => failures > 0,
    RhodantheRolloutDecisionReason.mismatch => failures == 0 && mismatches > 0,
    RhodantheRolloutDecisionReason.insufficientSamples =>
      failures == 0 && mismatches == 0 && completedSamples < samplesRequired,
    RhodantheRolloutDecisionReason.latency =>
      failures == 0 &&
          mismatches == 0 &&
          completedSamples >= samplesRequired &&
          p95Micros > p95BudgetMicros,
    RhodantheRolloutDecisionReason.eligible ||
    RhodantheRolloutDecisionReason.alreadyFull =>
      failures == 0 &&
          mismatches == 0 &&
          completedSamples >= samplesRequired &&
          p95Micros <= p95BudgetMicros,
  };
  if (!valid) {
    throw const FormatException(
      "rollout decision reason is inconsistent with its metrics",
    );
  }
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException("$field must be an object");
  return Map<String, Object?>.from(value);
}

String _string(Object? value, String field) {
  if (value is! String || value.isEmpty) {
    throw FormatException("$field must be a non-empty string");
  }
  return value;
}

int _nonNegativeInt(Object? value, String field) {
  if (value is! int || value < 0) {
    throw FormatException("$field must be >= 0");
  }
  return value;
}

int _positiveInt(Object? value, String field) {
  final parsed = _nonNegativeInt(value, field);
  if (parsed == 0) throw FormatException("$field must be > 0");
  return parsed;
}

RhodantheRolloutDecisionReason _reason(Object? value, String field) {
  final name = _string(value, field);
  try {
    return RhodantheRolloutDecisionReason.values.byName(name);
  } on ArgumentError {
    throw FormatException("$field contains unknown reason $name");
  }
}

RhodantheRolloutMode _mode(Object? value, String field) {
  final name = _string(value, field);
  try {
    return RhodantheRolloutMode.values.byName(name);
  } on ArgumentError {
    throw FormatException("$field contains unknown mode $name");
  }
}
