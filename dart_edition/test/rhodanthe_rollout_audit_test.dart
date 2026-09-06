import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_editor_session.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_latest_coordinator.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_rollout_audit.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_rollout_guard.dart";

final DateTime _testNow = DateTime.utc(2026, 8, 28, 12);

void main() {
  test("audit gate accepts the expected build and promotion", () {
    final report = _promotionReport();

    final result = checkRhodantheRolloutAudit(
      report: report,
      expectedBuildId: "build-a",
      currentMode: RhodantheRolloutMode.shadow,
      requiredRecommendation: RhodantheRolloutMode.searchCanary,
    );

    expect(result.ok, isTrue);
    expect(result.code, "accepted");
  });

  test("audit gate rejects another build ID", () {
    final result = checkRhodantheRolloutAudit(
      report: _promotionReport(),
      expectedBuildId: "build-b",
      currentMode: RhodantheRolloutMode.shadow,
      requiredRecommendation: RhodantheRolloutMode.searchCanary,
    );

    expect(result.ok, isFalse);
    expect(result.code, "buildIdMismatch");
  });

  test("audit gate rejects an insufficient recommendation", () {
    final guard = _guard();
    final result = checkRhodantheRolloutAudit(
      report: <String, Object?>{"buildId": "build-a", ...guard.auditSummary()},
      expectedBuildId: "build-a",
      currentMode: RhodantheRolloutMode.shadow,
      requiredRecommendation: RhodantheRolloutMode.searchCanary,
    );

    expect(result.ok, isFalse);
    expect(result.code, "recommendationMismatch");
    expect(result.decisionReason, "insufficientSamples");
  });

  test("audit gate accepts a canary rollback recommendation", () {
    final guard = _guard();
    guard.record(
      _observation(
        mode: RhodantheRolloutMode.searchCanary,
        status: RhodantheExecutionStatus.timedOut,
      ),
    );

    final result = checkRhodantheRolloutAudit(
      report: <String, Object?>{"buildId": "build-a", ...guard.auditSummary()},
      expectedBuildId: "build-a",
      currentMode: RhodantheRolloutMode.searchCanary,
      requiredRecommendation: RhodantheRolloutMode.shadow,
    );

    expect(result.ok, isTrue);
    expect(result.decisionReason, "failure");
  });

  test("audit gate rejects malformed metrics", () {
    final report = _promotionReport();
    final modes = report["modes"]! as Map<String, Object?>;
    final shadow = modes["shadow"]! as Map<String, Object?>;
    shadow["p95Micros"] = -1;

    expect(
      () => checkRhodantheRolloutAudit(
        report: report,
        expectedBuildId: "build-a",
        currentMode: RhodantheRolloutMode.shadow,
        requiredRecommendation: RhodantheRolloutMode.searchCanary,
      ),
      throwsFormatException,
    );
  });

  test("audit gate rejects a policy weaker than production", () {
    final report = _promotionReport();
    final policy = report["policy"]! as Map<String, Object?>;
    policy["shadowSamplesRequired"] = rhodantheShadowSamplesRequired - 1;

    expect(
      () => checkRhodantheRolloutAudit(
        report: report,
        expectedBuildId: "build-a",
        currentMode: RhodantheRolloutMode.shadow,
        requiredRecommendation: RhodantheRolloutMode.searchCanary,
      ),
      throwsFormatException,
    );
  });

  test("full default-on gate rejects an insufficient soak window", () {
    final guard = _guard();
    final result = checkRhodantheRolloutAudit(
      report: <String, Object?>{"buildId": "build-a", ...guard.auditSummary()},
      expectedBuildId: "build-a",
      currentMode: RhodantheRolloutMode.full,
      requiredRecommendation: RhodantheRolloutMode.full,
    );

    expect(result.ok, isFalse);
    expect(result.code, "decisionReasonMismatch");
    expect(result.requiredDecisionReason, "alreadyFull");
  });

  test("full default-on gate accepts a healthy soak window", () {
    final guard = _guard();
    for (var index = 0; index < rhodantheCanarySamplesRequired; index++) {
      guard.record(_observation(mode: RhodantheRolloutMode.full));
    }

    final result = checkRhodantheRolloutAudit(
      report: <String, Object?>{"buildId": "build-a", ...guard.auditSummary()},
      expectedBuildId: "build-a",
      currentMode: RhodantheRolloutMode.full,
      requiredRecommendation: RhodantheRolloutMode.full,
    );

    expect(result.ok, isTrue);
    expect(result.decisionReason, "alreadyFull");
  });
}

Map<String, Object?> _promotionReport() {
  final guard = _guard();
  for (var index = 0; index < rhodantheShadowSamplesRequired; index++) {
    guard.record(_observation());
  }
  return <String, Object?>{"buildId": "build-a", ...guard.auditSummary()};
}

RhodantheRolloutGuard _guard() =>
    RhodantheRolloutGuard(maxWindowSamples: 1000, now: () => _testNow);

RhodantheAnalysisObservation _observation({
  RhodantheRolloutMode mode = RhodantheRolloutMode.shadow,
  RhodantheExecutionStatus status = RhodantheExecutionStatus.applied,
}) {
  return RhodantheAnalysisObservation(
    mode: mode,
    observedAt: _testNow,
    revision: 1,
    elapsed: const Duration(milliseconds: 10),
    status: status,
    shadowExactMatch: mode == RhodantheRolloutMode.shadow ? true : null,
    published: mode != RhodantheRolloutMode.shadow,
  );
}
