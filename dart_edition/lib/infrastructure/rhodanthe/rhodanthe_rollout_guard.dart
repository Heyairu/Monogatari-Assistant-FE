import "rhodanthe_editor_session.dart";
import "rhodanthe_latest_coordinator.dart";

const int rhodantheShadowSamplesRequired = 100;
const int rhodantheCanarySamplesRequired = 500;
const int rhodantheP95BudgetMicros = 75000;

enum RhodantheRolloutDecisionReason {
  insufficientSamples,
  mismatch,
  failure,
  latency,
  eligible,
  alreadyFull,
}

final class RhodantheRolloutDecision {
  final RhodantheRolloutMode currentMode;
  final RhodantheRolloutMode recommendedMode;
  final RhodantheRolloutDecisionReason reason;
  final int completedSamples;
  final int failures;
  final int mismatches;
  final int p95Micros;
  final int requiredSamples;

  const RhodantheRolloutDecision({
    required this.currentMode,
    required this.recommendedMode,
    required this.reason,
    required this.completedSamples,
    required this.failures,
    required this.mismatches,
    required this.p95Micros,
    required this.requiredSamples,
  });

  bool get canPromote => recommendedMode.index > currentMode.index;
  bool get canRollback => recommendedMode.index < currentMode.index;
  bool get recommendsChange => recommendedMode != currentMode;
  bool get gateSatisfied =>
      reason == RhodantheRolloutDecisionReason.eligible ||
      reason == RhodantheRolloutDecisionReason.alreadyFull;
  int get remainingSamples =>
      (requiredSamples - completedSamples).clamp(0, requiredSamples);
  int get completionPercent => requiredSamples == 0
      ? 100
      : ((completedSamples * 100) ~/ requiredSamples).clamp(0, 100);

  Map<String, Object?> toJson() => <String, Object?>{
    "currentMode": currentMode.name,
    "recommendedMode": recommendedMode.name,
    "reason": reason.name,
    "completedSamples": completedSamples,
    "failures": failures,
    "mismatches": mismatches,
    "p95Micros": p95Micros,
    "requiredSamples": requiredSamples,
    "remainingSamples": remainingSamples,
    "completionPercent": completionPercent,
  };
}

enum RhodantheRolloutNoticeKind {
  progress,
  promotion,
  rollback,
  defaultOnReady,
}

final class RhodantheRolloutNotice {
  final RhodantheRolloutNoticeKind kind;
  final RhodantheRolloutDecision decision;
  final int? progressPercent;

  const RhodantheRolloutNotice({
    required this.kind,
    required this.decision,
    this.progressPercent,
  });
}

/// Converts a stream of decisions into sparse operational notices. Progress is
/// emitted at most once per 25% milestone, while terminal decisions are emitted
/// once until the mode returns to a non-terminal state.
final class RhodantheRolloutNoticeTracker {
  final Map<RhodantheRolloutMode, int> _lastMilestone =
      <RhodantheRolloutMode, int>{};
  String? _lastTerminalKey;

  RhodantheRolloutNotice? observe(RhodantheRolloutDecision decision) {
    final terminalKind = decision.canRollback
        ? RhodantheRolloutNoticeKind.rollback
        : decision.gateSatisfied
        ? decision.currentMode == RhodantheRolloutMode.full
              ? RhodantheRolloutNoticeKind.defaultOnReady
              : RhodantheRolloutNoticeKind.promotion
        : null;
    if (terminalKind != null) {
      final key = <Object?>[
        decision.currentMode.name,
        terminalKind.name,
        decision.reason.name,
        decision.recommendedMode.name,
      ].join(":");
      if (_lastTerminalKey == key) return null;
      _lastTerminalKey = key;
      return RhodantheRolloutNotice(kind: terminalKind, decision: decision);
    }
    _lastTerminalKey = null;
    if (decision.reason != RhodantheRolloutDecisionReason.insufficientSamples) {
      return null;
    }
    final milestone = (decision.completionPercent ~/ 25) * 25;
    if (milestone <= 0 || milestone >= 100) return null;
    final previous = _lastMilestone[decision.currentMode] ?? 0;
    if (milestone <= previous) return null;
    _lastMilestone[decision.currentMode] = milestone;
    return RhodantheRolloutNotice(
      kind: RhodantheRolloutNoticeKind.progress,
      decision: decision,
      progressPercent: milestone,
    );
  }
}

/// Evaluates a bounded, in-memory canary window. It recommends a build-time
/// mode change but never mutates rollout mode at runtime.
final class RhodantheRolloutGuard {
  static const int evidenceVersion = 2;
  final int shadowSamplesRequired;
  final int canarySamplesRequired;
  final int maxWindowSamples;
  final int p95BudgetMicros;
  final Duration maxEvidenceAge;
  final Duration futureClockTolerance;
  final DateTime Function() _now;
  final List<RhodantheAnalysisObservation> _observations =
      <RhodantheAnalysisObservation>[];

  RhodantheRolloutGuard({
    this.shadowSamplesRequired = rhodantheShadowSamplesRequired,
    this.canarySamplesRequired = rhodantheCanarySamplesRequired,
    this.maxWindowSamples = 2000,
    this.p95BudgetMicros = rhodantheP95BudgetMicros,
    this.maxEvidenceAge = const Duration(days: 7),
    this.futureClockTolerance = const Duration(minutes: 5),
    DateTime Function()? now,
  }) : assert(shadowSamplesRequired > 0),
       assert(canarySamplesRequired > 0),
       assert(maxWindowSamples >= canarySamplesRequired),
       assert(p95BudgetMicros > 0),
       assert(maxEvidenceAge > Duration.zero),
       assert(!futureClockTolerance.isNegative),
       _now = now ?? DateTime.now;

  int get retainedSamples {
    _pruneExpired();
    return _observations.length;
  }

  void record(RhodantheAnalysisObservation observation) {
    _observations.add(observation);
    _pruneExpired();
    final overflow = _observations.length - maxWindowSamples;
    if (overflow > 0) _observations.removeRange(0, overflow);
  }

  Map<String, Object?> toEvidenceJson() {
    _pruneExpired();
    return <String, Object?>{
      "version": evidenceVersion,
      "observations": <Object?>[
        for (final observation in _observations)
          <String, Object?>{
            "mode": observation.mode.name,
            "observedAtEpochMillis": observation.observedAt
                .toUtc()
                .millisecondsSinceEpoch,
            "elapsedMicros": observation.elapsed.inMicroseconds,
            "status": observation.status.name,
            "shadowExactMatch": observation.shadowExactMatch,
            "published": observation.published,
          },
      ],
    };
  }

  void restoreEvidence(Map<String, Object?> json) {
    if (json["version"] != evidenceVersion) {
      throw const FormatException("unsupported Rhodanthe evidence version");
    }
    final rawObservations = json["observations"];
    if (rawObservations is! List || rawObservations.length > 10000) {
      throw const FormatException("invalid Rhodanthe evidence observations");
    }
    final decoded = <RhodantheAnalysisObservation>[];
    for (final raw in rawObservations) {
      if (raw is! Map) {
        throw const FormatException("invalid Rhodanthe evidence observation");
      }
      final value = Map<String, Object?>.from(raw);
      final modeName = value["mode"];
      final observedAtEpochMillis = value["observedAtEpochMillis"];
      final elapsedMicros = value["elapsedMicros"];
      final statusName = value["status"];
      final exact = value["shadowExactMatch"];
      final published = value["published"];
      if (modeName is! String ||
          observedAtEpochMillis is! int ||
          observedAtEpochMillis < 0 ||
          elapsedMicros is! int ||
          elapsedMicros < 0 ||
          elapsedMicros > const Duration(minutes: 10).inMicroseconds ||
          statusName is! String ||
          (exact != null && exact is! bool) ||
          published is! bool) {
        throw const FormatException("invalid Rhodanthe evidence fields");
      }
      RhodantheRolloutMode mode;
      RhodantheExecutionStatus status;
      try {
        mode = RhodantheRolloutMode.values.byName(modeName);
        status = RhodantheExecutionStatus.values.byName(statusName);
      } on ArgumentError {
        throw const FormatException("unknown Rhodanthe evidence enum");
      }
      decoded.add(
        RhodantheAnalysisObservation(
          mode: mode,
          observedAt: DateTime.fromMillisecondsSinceEpoch(
            observedAtEpochMillis,
            isUtc: true,
          ),
          revision: 0,
          elapsed: Duration(microseconds: elapsedMicros),
          status: status,
          shadowExactMatch: exact as bool?,
          published: published,
        ),
      );
    }
    _observations.clear();
    for (final observation in decoded) {
      record(observation);
    }
  }

  Map<String, Object?> auditSummary() => <String, Object?>{
    "version": evidenceVersion,
    "retainedSamples": retainedSamples,
    "maxEvidenceAgeSeconds": maxEvidenceAge.inSeconds,
    "policy": <String, Object?>{
      "shadowSamplesRequired": shadowSamplesRequired,
      "canarySamplesRequired": canarySamplesRequired,
      "p95BudgetMicros": p95BudgetMicros,
    },
    "modes": <String, Object?>{
      RhodantheRolloutMode.shadow.name: evaluate(
        RhodantheRolloutMode.shadow,
      ).toJson(),
      RhodantheRolloutMode.searchCanary.name: evaluate(
        RhodantheRolloutMode.searchCanary,
      ).toJson(),
      RhodantheRolloutMode.full.name: evaluate(
        RhodantheRolloutMode.full,
      ).toJson(),
    },
  };

  RhodantheRolloutDecision evaluate(RhodantheRolloutMode currentMode) {
    _pruneExpired();
    final relevant = _observations
        .where(
          (value) =>
              value.mode == currentMode &&
              value.status != RhodantheExecutionStatus.stale,
        )
        .toList(growable: false);
    final completed = relevant
        .where((value) => value.status == RhodantheExecutionStatus.applied)
        .toList(growable: false);
    final failures = relevant.length - completed.length;
    final mismatches = completed
        .where((value) => value.shadowExactMatch == false)
        .length;
    final samplesRequired = switch (currentMode) {
      RhodantheRolloutMode.disabled ||
      RhodantheRolloutMode.shadow => shadowSamplesRequired,
      RhodantheRolloutMode.searchCanary ||
      RhodantheRolloutMode.full => canarySamplesRequired,
    };
    final durations =
        completed.map((value) => value.elapsed.inMicroseconds).toList()..sort();
    final p95 = durations.isEmpty
        ? 0
        : durations[((durations.length - 1) * 0.95).round()];

    RhodantheRolloutDecisionReason reason;
    var recommended = currentMode;
    if (failures > 0) {
      reason = RhodantheRolloutDecisionReason.failure;
      recommended = _rollbackMode(currentMode);
    } else if (mismatches > 0) {
      reason = RhodantheRolloutDecisionReason.mismatch;
      recommended = _rollbackMode(currentMode);
    } else if (relevant.length < samplesRequired) {
      reason = RhodantheRolloutDecisionReason.insufficientSamples;
    } else if (p95 > p95BudgetMicros) {
      reason = RhodantheRolloutDecisionReason.latency;
      recommended = _rollbackMode(currentMode);
    } else if (currentMode == RhodantheRolloutMode.full) {
      reason = RhodantheRolloutDecisionReason.alreadyFull;
    } else {
      reason = RhodantheRolloutDecisionReason.eligible;
      recommended = switch (currentMode) {
        RhodantheRolloutMode.disabled => RhodantheRolloutMode.shadow,
        RhodantheRolloutMode.shadow => RhodantheRolloutMode.searchCanary,
        RhodantheRolloutMode.searchCanary => RhodantheRolloutMode.full,
        RhodantheRolloutMode.full => RhodantheRolloutMode.full,
      };
    }
    return RhodantheRolloutDecision(
      currentMode: currentMode,
      recommendedMode: recommended,
      reason: reason,
      completedSamples: completed.length,
      failures: failures,
      mismatches: mismatches,
      p95Micros: p95,
      requiredSamples: samplesRequired,
    );
  }

  RhodantheRolloutMode _rollbackMode(RhodantheRolloutMode mode) =>
      switch (mode) {
        RhodantheRolloutMode.disabled || RhodantheRolloutMode.shadow => mode,
        RhodantheRolloutMode.searchCanary => RhodantheRolloutMode.shadow,
        RhodantheRolloutMode.full => RhodantheRolloutMode.searchCanary,
      };

  void _pruneExpired() {
    final now = _now().toUtc();
    final oldest = now.subtract(maxEvidenceAge);
    final newest = now.add(futureClockTolerance);
    _observations.removeWhere((observation) {
      final observedAt = observation.observedAt.toUtc();
      return observedAt.isBefore(oldest) || observedAt.isAfter(newest);
    });
  }
}
