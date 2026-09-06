import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_editor_session.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_latest_coordinator.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_rollout_guard.dart";

final DateTime _testNow = DateTime.utc(2026, 8, 28, 12);

void main() {
  test("exact low-latency shadow samples recommend search canary", () {
    final guard = RhodantheRolloutGuard(
      shadowSamplesRequired: 3,
      canarySamplesRequired: 4,
      maxWindowSamples: 8,
      now: () => _testNow,
    );
    for (var index = 0; index < 3; index++) {
      guard.record(_observation(exact: true));
    }

    final decision = guard.evaluate(RhodantheRolloutMode.shadow);
    expect(decision.canPromote, isTrue);
    expect(decision.recommendedMode, RhodantheRolloutMode.searchCanary);
    expect(decision.reason, RhodantheRolloutDecisionReason.eligible);
  });

  test("a shadow mismatch blocks promotion", () {
    final guard = _guard();
    guard.record(_observation(exact: true));
    guard.record(_observation(exact: false));

    final decision = guard.evaluate(RhodantheRolloutMode.shadow);
    expect(decision.canPromote, isFalse);
    expect(decision.reason, RhodantheRolloutDecisionReason.mismatch);
  });

  test("a timeout or fallback blocks promotion", () {
    final guard = _guard();
    guard.record(_observation(exact: true));
    guard.record(
      _observation(status: RhodantheExecutionStatus.timedOut, exact: null),
    );

    final decision = guard.evaluate(RhodantheRolloutMode.shadow);
    expect(decision.canPromote, isFalse);
    expect(decision.reason, RhodantheRolloutDecisionReason.failure);
  });

  test("p95 over budget blocks promotion", () {
    final guard = _guard(p95BudgetMicros: 1000);
    guard.record(_observation(exact: true, elapsedMicros: 2000));
    guard.record(_observation(exact: true, elapsedMicros: 2000));

    final decision = guard.evaluate(RhodantheRolloutMode.shadow);
    expect(decision.reason, RhodantheRolloutDecisionReason.latency);
  });

  test("stale work is ignored and canary can recommend full", () {
    final guard = _guard();
    guard.record(
      _observation(status: RhodantheExecutionStatus.stale, exact: null),
    );
    guard.record(
      _observation(mode: RhodantheRolloutMode.searchCanary, exact: null),
    );
    guard.record(
      _observation(mode: RhodantheRolloutMode.searchCanary, exact: null),
    );

    final decision = guard.evaluate(RhodantheRolloutMode.searchCanary);
    expect(decision.completedSamples, 2);
    expect(decision.recommendedMode, RhodantheRolloutMode.full);
  });

  test("expired and implausibly future evidence is pruned", () {
    final guard = _guard();
    guard.record(
      _observation(observedAt: _testNow.subtract(const Duration(days: 8))),
    );
    guard.record(
      _observation(observedAt: _testNow.add(const Duration(minutes: 6))),
    );

    expect(guard.retainedSamples, 0);
    expect(
      guard.evaluate(RhodantheRolloutMode.shadow).reason,
      RhodantheRolloutDecisionReason.insufficientSamples,
    );
  });

  test("canary failure recommends manual rollback to shadow", () {
    final guard = _guard();
    guard.record(
      _observation(
        mode: RhodantheRolloutMode.searchCanary,
        status: RhodantheExecutionStatus.timedOut,
      ),
    );

    final decision = guard.evaluate(RhodantheRolloutMode.searchCanary);
    expect(decision.canRollback, isTrue);
    expect(decision.recommendedMode, RhodantheRolloutMode.shadow);
    expect(decision.reason, RhodantheRolloutDecisionReason.failure);
  });

  test("decision exposes bounded rollout progress", () {
    final guard = _guard();
    guard.record(_observation(exact: true));

    final decision = guard.evaluate(RhodantheRolloutMode.shadow);
    expect(decision.requiredSamples, 2);
    expect(decision.remainingSamples, 1);
    expect(decision.completionPercent, 50);
  });

  test("notice tracker emits milestones once and reports Full readiness", () {
    final guard = _guard();
    final tracker = RhodantheRolloutNoticeTracker();
    guard.record(_observation(exact: true));

    final progress = tracker.observe(
      guard.evaluate(RhodantheRolloutMode.shadow),
    );
    expect(progress?.kind, RhodantheRolloutNoticeKind.progress);
    expect(progress?.progressPercent, 50);
    expect(
      tracker.observe(guard.evaluate(RhodantheRolloutMode.shadow)),
      isNull,
    );

    guard.record(_observation(mode: RhodantheRolloutMode.full, exact: null));
    guard.record(_observation(mode: RhodantheRolloutMode.full, exact: null));
    final ready = tracker.observe(guard.evaluate(RhodantheRolloutMode.full));
    expect(ready?.kind, RhodantheRolloutNoticeKind.defaultOnReady);
    expect(ready?.decision.gateSatisfied, isTrue);
    expect(tracker.observe(guard.evaluate(RhodantheRolloutMode.full)), isNull);
  });
}

RhodantheRolloutGuard _guard({int p95BudgetMicros = 75000}) {
  return RhodantheRolloutGuard(
    shadowSamplesRequired: 2,
    canarySamplesRequired: 2,
    maxWindowSamples: 8,
    p95BudgetMicros: p95BudgetMicros,
    now: () => _testNow,
  );
}

RhodantheAnalysisObservation _observation({
  RhodantheRolloutMode mode = RhodantheRolloutMode.shadow,
  RhodantheExecutionStatus status = RhodantheExecutionStatus.applied,
  bool? exact,
  int elapsedMicros = 100,
  DateTime? observedAt,
}) {
  return RhodantheAnalysisObservation(
    mode: mode,
    observedAt: observedAt ?? _testNow,
    revision: 1,
    elapsed: Duration(microseconds: elapsedMicros),
    status: status,
    shadowExactMatch: exact,
    published: false,
  );
}
