import "rhodanthe_editor_session.dart";
import "rhodanthe_rollout_audit.dart";
import "rhodanthe_rollout_cohort_policy.dart";

enum RhodantheBuildMode { profile, release }

enum RhodantheBuildPlatform {
  windows,
  linux,
  macos,
  apk,
  appbundle,
  ios;

  static RhodantheBuildPlatform? tryParse(String value) {
    try {
      return values.byName(value);
    } on ArgumentError {
      return null;
    }
  }
}

final class RhodantheRolloutPreparation {
  final RhodantheReleaseStage stage;
  final String targetBuildId;
  final RhodantheBuildPlatform platform;
  final RhodantheBuildMode buildMode;
  final int canaryPercent;
  final RhodantheAuditCheckResult? audit;

  const RhodantheRolloutPreparation({
    required this.stage,
    required this.targetBuildId,
    required this.platform,
    required this.buildMode,
    required this.canaryPercent,
    required this.audit,
  });

  bool get approved => audit?.ok ?? stage == RhodantheReleaseStage.shadow;

  List<String> get flutterArguments => <String>[
    "build",
    platform.name,
    "--${buildMode.name}",
    "--dart-define=RHODANTHE_RELEASE_STAGE=${stage.defineValue}",
    "--dart-define=RHODANTHE_BUILD_ID=$targetBuildId",
    "--dart-define=RHODANTHE_CANARY_PERCENT=$canaryPercent",
  ];

  Map<String, Object?> toJson() => <String, Object?>{
    "stage": stage.name,
    "runtimeMode": stage.rolloutMode.name,
    "targetBuildId": targetBuildId,
    "platform": platform.name,
    "buildMode": buildMode.name,
    "canaryPercent": canaryPercent,
    "approved": approved,
    "flutterArguments": flutterArguments,
    if (audit != null) "audit": audit!.toJson(),
  };
}

final class RhodantheRolloutReceipt {
  static const int version = 1;

  final DateTime generatedAt;
  final RhodantheRolloutPreparation preparation;
  final Map<String, Object?>? sourceEvidence;

  RhodantheRolloutReceipt({
    required DateTime generatedAt,
    required this.preparation,
    required Map<String, Object?>? sourceEvidence,
  }) : generatedAt = generatedAt.toUtc(),
       sourceEvidence = sourceEvidence == null
           ? null
           : Map<String, Object?>.unmodifiable(sourceEvidence) {
    if (!preparation.approved) {
      throw StateError("cannot issue a receipt for a rejected rollout");
    }
    if (preparation.stage == RhodantheReleaseStage.shadow) {
      if (sourceEvidence != null) {
        throw ArgumentError("Shadow receipts cannot contain source evidence");
      }
    } else if (sourceEvidence == null) {
      throw ArgumentError("promotion receipts require source evidence");
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    "receiptVersion": version,
    "generatedAtUtc": generatedAt.toIso8601String(),
    "release": preparation.toJson(),
    if (sourceEvidence != null) "sourceEvidence": sourceEvidence,
  };
}

RhodantheRolloutPreparation prepareRhodantheRollout({
  required RhodantheReleaseStage stage,
  required String targetBuildId,
  required RhodantheBuildPlatform platform,
  required RhodantheBuildMode buildMode,
  int? canaryPercent,
  Map<String, Object?>? evidenceReport,
  String? sourceBuildId,
}) {
  _validateBuildId(targetBuildId, "targetBuildId");
  if (stage == RhodantheReleaseStage.off) {
    throw ArgumentError("off is not a rollout build stage");
  }
  final resolvedCanaryPercent = resolveRhodantheCanaryPercent(
    stage,
    requestedPercent: canaryPercent,
  );
  if (stage == RhodantheReleaseStage.shadow) {
    if (evidenceReport != null || sourceBuildId != null) {
      throw ArgumentError("shadow does not accept promotion evidence");
    }
    return RhodantheRolloutPreparation(
      stage: stage,
      targetBuildId: targetBuildId,
      platform: platform,
      buildMode: buildMode,
      canaryPercent: resolvedCanaryPercent,
      audit: null,
    );
  }
  if (evidenceReport == null || sourceBuildId == null) {
    throw ArgumentError(
      "promotion stages require evidenceReport and sourceBuildId",
    );
  }
  _validateBuildId(sourceBuildId, "sourceBuildId");
  final transition = switch (stage) {
    RhodantheReleaseStage.searchCanary => (
      current: RhodantheRolloutMode.shadow,
      required: RhodantheRolloutMode.searchCanary,
    ),
    RhodantheReleaseStage.fullCanary => (
      current: RhodantheRolloutMode.searchCanary,
      required: RhodantheRolloutMode.full,
    ),
    RhodantheReleaseStage.defaultOn => (
      current: RhodantheRolloutMode.full,
      required: RhodantheRolloutMode.full,
    ),
    RhodantheReleaseStage.off || RhodantheReleaseStage.shadow =>
      throw StateError("unreachable rollout stage"),
  };
  final audit = checkRhodantheRolloutAudit(
    report: evidenceReport,
    expectedBuildId: sourceBuildId,
    currentMode: transition.current,
    requiredRecommendation: transition.required,
  );
  return RhodantheRolloutPreparation(
    stage: stage,
    targetBuildId: targetBuildId,
    platform: platform,
    buildMode: buildMode,
    canaryPercent: resolvedCanaryPercent,
    audit: audit,
  );
}

void _validateBuildId(String value, String field) {
  if (value.isEmpty ||
      value.length > 128 ||
      !RegExp(r"^[A-Za-z0-9][A-Za-z0-9._-]*$").hasMatch(value)) {
    throw ArgumentError.value(value, field, "invalid immutable build ID");
  }
}
