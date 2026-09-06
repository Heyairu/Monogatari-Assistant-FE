import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_editor_session.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_latest_coordinator.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_release_plan.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_rollout_guard.dart";

final DateTime _testNow = DateTime.utc(2026, 8, 29, 12);

void main() {
  test("release stages map to the expected runtime mode", () {
    expect(
      RhodantheReleaseStage.shadow.rolloutMode,
      RhodantheRolloutMode.shadow,
    );
    expect(
      RhodantheReleaseStage.searchCanary.rolloutMode,
      RhodantheRolloutMode.searchCanary,
    );
    expect(
      RhodantheReleaseStage.fullCanary.rolloutMode,
      RhodantheRolloutMode.full,
    );
    expect(
      RhodantheReleaseStage.defaultOn.rolloutMode,
      RhodantheRolloutMode.full,
    );
  });

  test("shadow preparation needs no promotion evidence", () {
    final preparation = prepareRhodantheRollout(
      stage: RhodantheReleaseStage.shadow,
      targetBuildId: "shadow-001",
      platform: RhodantheBuildPlatform.windows,
      buildMode: RhodantheBuildMode.profile,
    );

    expect(preparation.approved, isTrue);
    expect(
      preparation.flutterArguments,
      contains("--dart-define=RHODANTHE_RELEASE_STAGE=shadow"),
    );
    expect(
      preparation.flutterArguments,
      contains("--dart-define=RHODANTHE_BUILD_ID=shadow-001"),
    );
    expect(preparation.canaryPercent, 100);
  });

  test("search canary requires accepted shadow evidence", () {
    final preparation = prepareRhodantheRollout(
      stage: RhodantheReleaseStage.searchCanary,
      targetBuildId: "search-001",
      platform: RhodantheBuildPlatform.windows,
      buildMode: RhodantheBuildMode.profile,
      evidenceReport: _reportFor(RhodantheRolloutMode.shadow),
      sourceBuildId: "source-001",
    );

    expect(preparation.approved, isTrue);
    expect(preparation.audit!.decisionReason, "eligible");
    expect(preparation.canaryPercent, 10);
    expect(
      preparation.flutterArguments,
      contains("--dart-define=RHODANTHE_CANARY_PERCENT=10"),
    );
  });

  test("default-on requires a healthy full soak window", () {
    final insufficient = prepareRhodantheRollout(
      stage: RhodantheReleaseStage.defaultOn,
      targetBuildId: "default-001",
      platform: RhodantheBuildPlatform.windows,
      buildMode: RhodantheBuildMode.release,
      evidenceReport: _emptyReport(),
      sourceBuildId: "source-001",
    );
    final healthy = prepareRhodantheRollout(
      stage: RhodantheReleaseStage.defaultOn,
      targetBuildId: "default-001",
      platform: RhodantheBuildPlatform.windows,
      buildMode: RhodantheBuildMode.release,
      evidenceReport: _reportFor(RhodantheRolloutMode.full),
      sourceBuildId: "source-001",
    );

    expect(insufficient.approved, isFalse);
    expect(insufficient.audit!.code, "decisionReasonMismatch");
    expect(healthy.approved, isTrue);
    expect(healthy.audit!.decisionReason, "alreadyFull");
  });

  test("promotion rejects evidence from a different binary", () {
    final preparation = prepareRhodantheRollout(
      stage: RhodantheReleaseStage.fullCanary,
      targetBuildId: "full-001",
      platform: RhodantheBuildPlatform.windows,
      buildMode: RhodantheBuildMode.profile,
      evidenceReport: _reportFor(RhodantheRolloutMode.searchCanary),
      sourceBuildId: "other-source",
    );

    expect(preparation.approved, isFalse);
    expect(preparation.audit!.code, "buildIdMismatch");
  });

  test("approved promotion emits a privacy-safe release receipt", () {
    final evidence = _reportFor(RhodantheRolloutMode.shadow);
    final preparation = prepareRhodantheRollout(
      stage: RhodantheReleaseStage.searchCanary,
      targetBuildId: "search-002",
      platform: RhodantheBuildPlatform.windows,
      buildMode: RhodantheBuildMode.profile,
      evidenceReport: evidence,
      sourceBuildId: "source-001",
    );
    final receipt = RhodantheRolloutReceipt(
      generatedAt: DateTime.utc(2026, 8, 29, 13),
      preparation: preparation,
      sourceEvidence: evidence,
    ).toJson();

    expect(receipt["receiptVersion"], RhodantheRolloutReceipt.version);
    expect(receipt["generatedAtUtc"], "2026-08-29T13:00:00.000Z");
    expect(receipt["sourceEvidence"], evidence);
    expect(receipt.toString(), isNot(contains("document")));
    expect(receipt.toString(), isNot(contains("query")));
  });

  test("release preparation rejects unsafe stage percentages", () {
    expect(
      () => prepareRhodantheRollout(
        stage: RhodantheReleaseStage.shadow,
        targetBuildId: "shadow-invalid",
        platform: RhodantheBuildPlatform.windows,
        buildMode: RhodantheBuildMode.profile,
        canaryPercent: 10,
      ),
      throwsArgumentError,
    );
  });
}

Map<String, Object?> _emptyReport() {
  final guard = _guard();
  return <String, Object?>{"buildId": "source-001", ...guard.auditSummary()};
}

Map<String, Object?> _reportFor(RhodantheRolloutMode mode) {
  final guard = _guard();
  final samples = mode == RhodantheRolloutMode.shadow
      ? rhodantheShadowSamplesRequired
      : rhodantheCanarySamplesRequired;
  for (var index = 0; index < samples; index++) {
    guard.record(
      RhodantheAnalysisObservation(
        mode: mode,
        observedAt: _testNow,
        revision: index,
        elapsed: const Duration(milliseconds: 10),
        status: RhodantheExecutionStatus.applied,
        shadowExactMatch: mode == RhodantheRolloutMode.shadow ? true : null,
        published: mode != RhodantheRolloutMode.shadow,
      ),
    );
  }
  return <String, Object?>{"buildId": "source-001", ...guard.auditSummary()};
}

RhodantheRolloutGuard _guard() =>
    RhodantheRolloutGuard(maxWindowSamples: 1000, now: () => _testNow);
