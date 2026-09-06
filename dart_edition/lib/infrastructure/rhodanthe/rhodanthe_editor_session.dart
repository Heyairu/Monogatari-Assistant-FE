import "dart:async";

import "rhodanthe_latest_coordinator.dart";
import "rhodanthe_protocol.dart";
import "rhodanthe_worker_executor.dart";

enum RhodantheRolloutMode {
  disabled,
  shadow,
  searchCanary,
  full;

  static RhodantheRolloutMode parse(String value) => switch (value) {
    "shadow" => shadow,
    "search" || "searchCanary" => searchCanary,
    "full" => full,
    _ => disabled,
  };
}

enum RhodantheReleaseStage {
  off,
  shadow,
  searchCanary,
  fullCanary,
  defaultOn;

  static RhodantheReleaseStage parse(String value) => switch (value) {
    "shadow" => shadow,
    "search" || "searchCanary" => searchCanary,
    "full" || "fullCanary" => fullCanary,
    "default-on" || "defaultOn" => defaultOn,
    _ => off,
  };

  RhodantheRolloutMode get rolloutMode => switch (this) {
    RhodantheReleaseStage.off => RhodantheRolloutMode.disabled,
    RhodantheReleaseStage.shadow => RhodantheRolloutMode.shadow,
    RhodantheReleaseStage.searchCanary => RhodantheRolloutMode.searchCanary,
    RhodantheReleaseStage.fullCanary ||
    RhodantheReleaseStage.defaultOn => RhodantheRolloutMode.full,
  };

  String get defineValue => switch (this) {
    RhodantheReleaseStage.off => "off",
    RhodantheReleaseStage.shadow => "shadow",
    RhodantheReleaseStage.searchCanary => "search",
    RhodantheReleaseStage.fullCanary => "full",
    RhodantheReleaseStage.defaultOn => "default-on",
  };
}

const String _configuredRhodantheMode = String.fromEnvironment(
  "RHODANTHE_MODE",
  defaultValue: "",
);

const String _configuredRhodantheReleaseStage = String.fromEnvironment(
  "RHODANTHE_RELEASE_STAGE",
  defaultValue: "default-on",
);

const bool _configuredRhodantheKillSwitch = bool.fromEnvironment(
  "RHODANTHE_KILL_SWITCH",
  defaultValue: false,
);

bool get isRhodantheKillSwitchActive => _configuredRhodantheKillSwitch;

RhodantheReleaseStage get configuredRhodantheReleaseStage =>
    _configuredRhodantheKillSwitch
    ? RhodantheReleaseStage.off
    : RhodantheReleaseStage.parse(_configuredRhodantheReleaseStage);

bool get hasConfiguredRhodantheModeOverride =>
    _configuredRhodantheMode.isNotEmpty;

RhodantheRolloutMode resolveRhodantheRuntimeMode({
  required String modeOverride,
  required String releaseStage,
  required bool killSwitch,
}) {
  if (killSwitch) return RhodantheRolloutMode.disabled;
  if (modeOverride.isNotEmpty) {
    return RhodantheRolloutMode.parse(modeOverride);
  }
  return RhodantheReleaseStage.parse(releaseStage).rolloutMode;
}

RhodantheRolloutMode get configuredRhodantheRolloutMode =>
    resolveRhodantheRuntimeMode(
      modeOverride: _configuredRhodantheMode,
      releaseStage: _configuredRhodantheReleaseStage,
      killSwitch: _configuredRhodantheKillSwitch,
    );

enum RhodantheSessionStatus { idle, ready, circuitOpen, degraded, disposed }

final class RhodantheHealthSnapshot {
  final RhodantheSessionStatus status;
  final int consecutiveAnalysisFailures;
  final DateTime? circuitOpenedAt;
  final DateTime? lastSuccessAt;
  final RhodantheFailure? lastFailure;
  final RhodantheCapabilities capabilities;

  const RhodantheHealthSnapshot({
    required this.status,
    required this.consecutiveAnalysisFailures,
    required this.circuitOpenedAt,
    required this.lastSuccessAt,
    required this.lastFailure,
    required this.capabilities,
  });
}

final class RhodantheShadowReport {
  final int revision;
  final List<RhodantheRange> nativeRanges;
  final List<RhodantheRange> dartRanges;

  RhodantheShadowReport({
    required this.revision,
    required List<RhodantheRange> nativeRanges,
    required List<RhodantheRange> dartRanges,
  }) : nativeRanges = List<RhodantheRange>.unmodifiable(nativeRanges),
       dartRanges = List<RhodantheRange>.unmodifiable(dartRanges);

  bool get isExactMatch {
    if (nativeRanges.length != dartRanges.length) return false;
    for (var index = 0; index < nativeRanges.length; index++) {
      final native = nativeRanges[index];
      final dart = dartRanges[index];
      if (native.start != dart.start || native.end != dart.end) return false;
    }
    return true;
  }
}

final class RhodantheAnalysisObservation {
  final RhodantheRolloutMode mode;
  final DateTime observedAt;
  final int revision;
  final Duration elapsed;
  final RhodantheExecutionStatus status;
  final bool? shadowExactMatch;
  final bool published;

  const RhodantheAnalysisObservation({
    required this.mode,
    required this.observedAt,
    required this.revision,
    required this.elapsed,
    required this.status,
    required this.shadowExactMatch,
    required this.published,
  });
}

typedef RhodanthePlanCallback =
    void Function(RhodantheVersionedRenderPlan renderPlan);
typedef RhodantheShadowCallback = void Function(RhodantheShadowReport report);
typedef RhodantheFailureCallback = void Function(RhodantheFailure failure);
typedef RhodantheHealthCallback = void Function(RhodantheHealthSnapshot health);
typedef RhodantheObservationCallback =
    void Function(RhodantheAnalysisObservation observation);

/// Owns one editor document's ordered native lifecycle.
///
/// The worker owns the FFI handle. This session owns document/revision state,
/// latest-only analysis, rollout policy, and safe degradation. Widgets and text
/// controllers only receive immutable render plans.
final class RhodantheEditorSession {
  final RhodantheRolloutMode mode;
  final RhodantheCapabilities capabilities;
  final RhodantheAsyncExecutor _executor;
  late final RhodantheLatestCoordinator _latest;
  final RhodanthePlanCallback? onPlan;
  final RhodantheShadowCallback? onShadowReport;
  final RhodantheFailureCallback? onFailure;
  final RhodantheHealthCallback? onHealthChanged;
  final RhodantheObservationCallback? onObservation;
  final int maxConsecutiveAnalysisFailures;
  final Duration circuitCooldown;
  final DateTime Function() _now;

  Future<void> _lifecycle = Future<void>.value();
  String? _documentId;
  String _text = "";
  int _revision = 0;
  int _requestId = 0;
  RhodantheSessionStatus _status = RhodantheSessionStatus.idle;
  int _consecutiveAnalysisFailures = 0;
  DateTime? _circuitOpenedAt;
  DateTime? _lastSuccessAt;
  RhodantheFailure? _lastFailure;
  bool _disposed = false;

  RhodantheEditorSession({
    required RhodantheAsyncExecutor executor,
    required this.mode,
    RhodantheCapabilities? capabilities,
    this.onPlan,
    this.onShadowReport,
    this.onFailure,
    this.onHealthChanged,
    this.onObservation,
    this.maxConsecutiveAnalysisFailures = 3,
    this.circuitCooldown = const Duration(seconds: 30),
    DateTime Function()? now,
    Duration analysisTimeout = const Duration(seconds: 2),
  }) : assert(maxConsecutiveAnalysisFailures > 0),
       capabilities = capabilities ?? _assumedCapabilities,
       _executor = executor,
       _now = now ?? DateTime.now {
    _latest = RhodantheLatestCoordinator(
      executor: executor,
      timeout: analysisTimeout,
      onFallback: _recordAnalysisFailure,
    );
  }

  static Future<RhodantheEditorSession?> start({
    RhodantheRolloutMode? mode,
    String? libraryPath,
    RhodanthePlanCallback? onPlan,
    RhodantheShadowCallback? onShadowReport,
    RhodantheFailureCallback? onFailure,
    RhodantheHealthCallback? onHealthChanged,
    RhodantheObservationCallback? onObservation,
    int maxConsecutiveAnalysisFailures = 3,
    Duration circuitCooldown = const Duration(seconds: 30),
    Duration startupTimeout = const Duration(seconds: 5),
    Duration analysisTimeout = const Duration(seconds: 2),
  }) async {
    final rollout = mode ?? configuredRhodantheRolloutMode;
    if (rollout == RhodantheRolloutMode.disabled) return null;
    RhodantheWorkerExecutor? executor;
    try {
      executor = await RhodantheWorkerExecutor.start(
        libraryPath: libraryPath,
        startupTimeout: startupTimeout,
      );
      final handshake = await executor
          .execute(RhodantheRequest.handshake(requestId: 1))
          .timeout(startupTimeout);
      final capabilities = RhodantheCapabilities.fromResponse(handshake);
      final required = requiredCapabilitiesFor(rollout);
      if (!capabilities.isVersionCompatible ||
          !capabilities.supportsAll(required)) {
        final missing = required.difference(capabilities.values).join(", ");
        throw RhodantheFailure(
          code: "incompatibleCapabilities",
          message: missing.isEmpty
              ? "Rhodanthe ABI or contract version is incompatible"
              : "Rhodanthe is missing capabilities: $missing",
        );
      }
      return RhodantheEditorSession(
        executor: executor,
        mode: rollout,
        capabilities: capabilities,
        onPlan: onPlan,
        onShadowReport: onShadowReport,
        onFailure: onFailure,
        onHealthChanged: onHealthChanged,
        onObservation: onObservation,
        maxConsecutiveAnalysisFailures: maxConsecutiveAnalysisFailures,
        circuitCooldown: circuitCooldown,
        analysisTimeout: analysisTimeout,
      );
    } catch (error) {
      await executor?.dispose();
      onFailure?.call(
        error is RhodantheFailure
            ? error
            : RhodantheFailure(
                code: "startupFailed",
                message: error.toString(),
              ),
      );
      return null;
    }
  }

  RhodantheSessionStatus get status => _status;
  String? get documentId => _documentId;
  int get revision => _revision;
  RhodantheHealthSnapshot get health => RhodantheHealthSnapshot(
    status: _status,
    consecutiveAnalysisFailures: _consecutiveAnalysisFailures,
    circuitOpenedAt: _circuitOpenedAt,
    lastSuccessAt: _lastSuccessAt,
    lastFailure: _lastFailure,
    capabilities: capabilities,
  );

  Future<void> synchronizeDocument({
    required String documentId,
    required int revision,
    required String text,
  }) {
    if (_disposed) return Future<void>.value();
    return _enqueueLifecycle(() async {
      if (_documentId != documentId) {
        await _closeCurrentDocument();
        await _openDocument(
          documentId: documentId,
          revision: revision,
          text: text,
        );
        return;
      }
      if (_revision == revision && _text == text) return;
      if (revision <= _revision) {
        await _reopenDocument(
          documentId: documentId,
          revision: revision,
          text: text,
        );
        return;
      }

      final edit = _singleTextEdit(_text, text);
      await _executeLifecycle(
        RhodantheRequest.applyEdits(
          requestId: _nextRequestId(),
          documentId: documentId,
          baseRevision: _revision,
          revision: revision,
          edits: <RhodantheTextEdit>[edit],
        ),
      );
      _text = text;
      _revision = revision;
      if (_status != RhodantheSessionStatus.circuitOpen) {
        _status = RhodantheSessionStatus.ready;
      }
      _recordLifecycleSuccess();
    });
  }

  Future<RhodantheAnalysisResult?> analyze({
    RhodantheSearchRequest? search,
    RhodantheFillerRequest? filler,
    List<RhodantheExternalAnnotation> externalAnnotations =
        const <RhodantheExternalAnnotation>[],
    List<RhodantheRange>? dartSearchRanges,
  }) async {
    if (_disposed || mode == RhodantheRolloutMode.disabled) return null;
    await _lifecycle;
    final documentId = _documentId;
    if (documentId == null || !_canAnalyze()) {
      return null;
    }
    final requestedRevision = _revision;
    final stopwatch = Stopwatch()..start();
    final execution = await _latest.run(
      RhodantheRequest.analyze(
        requestId: _nextRequestId(),
        documentId: documentId,
        revision: requestedRevision,
        search: search,
        filler: filler,
        externalAnnotations: externalAnnotations,
      ),
    );
    if (!execution.shouldApply || execution.response == null) {
      onObservation?.call(
        RhodantheAnalysisObservation(
          mode: mode,
          observedAt: _now(),
          revision: requestedRevision,
          elapsed: stopwatch.elapsed,
          status: execution.status,
          shadowExactMatch: null,
          published: false,
        ),
      );
      return null;
    }

    try {
      final analysis = RhodantheAnalysisResult.fromResponse(
        execution.response!,
      );
      if (_disposed ||
          _documentId != documentId ||
          _revision != requestedRevision ||
          analysis.renderPlan.revision != requestedRevision) {
        onObservation?.call(
          RhodantheAnalysisObservation(
            mode: mode,
            observedAt: _now(),
            revision: requestedRevision,
            elapsed: stopwatch.elapsed,
            status: RhodantheExecutionStatus.stale,
            shadowExactMatch: null,
            published: false,
          ),
        );
        return null;
      }
      bool? shadowExactMatch;
      if (search != null && dartSearchRanges != null) {
        final report = RhodantheShadowReport(
          revision: requestedRevision,
          nativeRanges: analysis.searchRanges,
          dartRanges: dartSearchRanges,
        );
        shadowExactMatch = report.isExactMatch;
        onShadowReport?.call(report);
      }
      final published = _shouldPublish(
        search: search,
        filler: filler,
        externalAnnotations: externalAnnotations,
      );
      if (published) {
        onPlan?.call(analysis.renderPlan);
      }
      _recordAnalysisSuccess();
      onObservation?.call(
        RhodantheAnalysisObservation(
          mode: mode,
          observedAt: _now(),
          revision: requestedRevision,
          elapsed: stopwatch.elapsed,
          status: RhodantheExecutionStatus.applied,
          shadowExactMatch: shadowExactMatch,
          published: published,
        ),
      );
      return analysis;
    } catch (error) {
      _recordAnalysisFailure(
        RhodantheFailure(code: "invalidAnalysis", message: error.toString()),
      );
      onObservation?.call(
        RhodantheAnalysisObservation(
          mode: mode,
          observedAt: _now(),
          revision: requestedRevision,
          elapsed: stopwatch.elapsed,
          status: RhodantheExecutionStatus.fallback,
          shadowExactMatch: null,
          published: false,
        ),
      );
      return null;
    }
  }

  bool _shouldPublish({
    required RhodantheSearchRequest? search,
    required RhodantheFillerRequest? filler,
    required List<RhodantheExternalAnnotation> externalAnnotations,
  }) => switch (mode) {
    RhodantheRolloutMode.disabled || RhodantheRolloutMode.shadow => false,
    RhodantheRolloutMode.searchCanary =>
      search != null && filler == null && externalAnnotations.isEmpty,
    RhodantheRolloutMode.full => true,
  };

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _latest.invalidate();
    await _lifecycle;
    try {
      await _closeCurrentDocument();
    } catch (_) {
      // Disposal is best-effort; the worker is still terminated below.
    }
    await _latest.dispose();
    _status = RhodantheSessionStatus.disposed;
    _emitHealth();
  }

  Future<void> _openDocument({
    required String documentId,
    required int revision,
    required String text,
  }) async {
    await _executeLifecycle(
      RhodantheRequest.openDocument(
        requestId: _nextRequestId(),
        documentId: documentId,
        revision: revision,
        fullText: text,
      ),
    );
    _documentId = documentId;
    _revision = revision;
    _text = text;
    _status = RhodantheSessionStatus.ready;
    _recordLifecycleSuccess();
  }

  Future<void> _reopenDocument({
    required String documentId,
    required int revision,
    required String text,
  }) async {
    await _closeCurrentDocument();
    await _openDocument(documentId: documentId, revision: revision, text: text);
  }

  Future<void> _closeCurrentDocument() async {
    final documentId = _documentId;
    if (documentId == null) return;
    await _executeLifecycle(
      RhodantheRequest.closeDocument(
        requestId: _nextRequestId(),
        documentId: documentId,
      ),
    );
    _documentId = null;
    _revision = 0;
    _text = "";
    _status = RhodantheSessionStatus.idle;
    _emitHealth();
  }

  Future<void> _executeLifecycle(RhodantheRequest request) async {
    final response = await _executor.execute(request);
    response.requireResult();
  }

  Future<void> _enqueueLifecycle(Future<void> Function() operation) {
    final completion = Completer<void>();
    _lifecycle = _lifecycle.then((_) async {
      if (_disposed) {
        completion.complete();
        return;
      }
      try {
        await operation();
        completion.complete();
      } catch (error, stackTrace) {
        _degrade("lifecycleFailed", error);
        completion.completeError(error, stackTrace);
      }
    });
    // Keep the internal queue alive after a failed caller-visible operation.
    _lifecycle = _lifecycle.catchError((Object _) {});
    return completion.future;
  }

  void _degrade(String code, Object error) {
    _status = RhodantheSessionStatus.degraded;
    final failure = RhodantheFailure(code: code, message: error.toString());
    _lastFailure = failure;
    onFailure?.call(failure);
    _emitHealth();
  }

  bool _canAnalyze() {
    if (_status == RhodantheSessionStatus.ready) return true;
    if (_status != RhodantheSessionStatus.circuitOpen ||
        _circuitOpenedAt == null) {
      return false;
    }
    if (_now().difference(_circuitOpenedAt!) < circuitCooldown) return false;
    _status = RhodantheSessionStatus.ready;
    _emitHealth();
    return true;
  }

  void _recordAnalysisFailure(RhodantheFailure failure) {
    if (_disposed) return;
    _lastFailure = failure;
    _consecutiveAnalysisFailures++;
    if (_consecutiveAnalysisFailures >= maxConsecutiveAnalysisFailures) {
      _status = RhodantheSessionStatus.circuitOpen;
      _circuitOpenedAt = _now();
      _latest.invalidate();
    }
    onFailure?.call(failure);
    _emitHealth();
  }

  void _recordAnalysisSuccess() {
    _consecutiveAnalysisFailures = 0;
    _circuitOpenedAt = null;
    _lastFailure = null;
    _lastSuccessAt = _now();
    _status = RhodantheSessionStatus.ready;
    _emitHealth();
  }

  void _recordLifecycleSuccess() {
    _lastSuccessAt = _now();
    _lastFailure = null;
    _emitHealth();
  }

  void _emitHealth() => onHealthChanged?.call(health);

  int _nextRequestId() => ++_requestId;
}

Set<String> requiredCapabilitiesFor(RhodantheRolloutMode mode) =>
    switch (mode) {
      RhodantheRolloutMode.disabled => const <String>{},
      RhodantheRolloutMode.shadow ||
      RhodantheRolloutMode.searchCanary => const <String>{
        "openDocument",
        "applyEdits",
        "analyzeSearch",
        "compactAnalysisV1",
        "closeDocument",
      },
      RhodantheRolloutMode.full => const <String>{
        "openDocument",
        "applyEdits",
        "analyzeSearch",
        "analyzeFiller",
        "analyzeExternalAnnotations",
        "compactAnalysisV1",
        "closeDocument",
      },
    };

final RhodantheCapabilities _assumedCapabilities = RhodantheCapabilities(
  abiVersion: rhodantheAbiVersion,
  contractVersion: rhodantheContractVersion,
  values: requiredCapabilitiesFor(RhodantheRolloutMode.full),
);

RhodantheTextEdit _singleTextEdit(String previous, String next) {
  var start = 0;
  final sharedLength = previous.length < next.length
      ? previous.length
      : next.length;
  while (start < sharedLength &&
      previous.codeUnitAt(start) == next.codeUnitAt(start)) {
    start++;
  }

  var previousEnd = previous.length;
  var nextEnd = next.length;
  while (previousEnd > start &&
      nextEnd > start &&
      previous.codeUnitAt(previousEnd - 1) == next.codeUnitAt(nextEnd - 1)) {
    previousEnd--;
    nextEnd--;
  }

  if (!_isUtf16Boundary(previous, start) ||
      !_isUtf16Boundary(next, start) ||
      !_isUtf16Boundary(previous, previousEnd) ||
      !_isUtf16Boundary(next, nextEnd)) {
    return RhodantheTextEdit(
      startUtf16: 0,
      endUtf16: previous.length,
      replacement: next,
    );
  }
  return RhodantheTextEdit(
    startUtf16: start,
    endUtf16: previousEnd,
    replacement: next.substring(start, nextEnd),
  );
}

bool _isUtf16Boundary(String text, int offset) {
  if (offset <= 0 || offset >= text.length) return true;
  final previous = text.codeUnitAt(offset - 1);
  final next = text.codeUnitAt(offset);
  return !(previous >= 0xD800 &&
      previous <= 0xDBFF &&
      next >= 0xDC00 &&
      next <= 0xDFFF);
}
