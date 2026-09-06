import "dart:async";
import "dart:convert";

import "package:shared_preferences/shared_preferences.dart";

import "rhodanthe_editor_session.dart";
import "rhodanthe_rollout_guard.dart";

const String configuredRhodantheBuildId = String.fromEnvironment(
  "RHODANTHE_BUILD_ID",
  defaultValue: "dev",
);

abstract interface class RhodantheEvidenceKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

final class SharedPreferencesRhodantheEvidenceStore
    implements RhodantheEvidenceKeyValueStore {
  const SharedPreferencesRhodantheEvidenceStore();

  @override
  Future<String?> read(String key) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(key);
  }

  @override
  Future<void> write(String key, String value) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(key, value)) {
      throw StateError("Unable to persist Rhodanthe rollout evidence");
    }
  }

  @override
  Future<void> delete(String key) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(key);
  }
}

final class RhodantheRolloutStore {
  static const String storageKey = "rhodanthe.rollout.evidence.v1";
  static const int _storageVersion = 1;

  final RhodantheEvidenceKeyValueStore _storage;
  final String buildId;

  const RhodantheRolloutStore({
    RhodantheEvidenceKeyValueStore storage =
        const SharedPreferencesRhodantheEvidenceStore(),
    this.buildId = configuredRhodantheBuildId,
  }) : _storage = storage;

  Future<bool> loadInto(RhodantheRolloutGuard guard) async {
    final source = await _storage.read(storageKey);
    if (source == null) return false;
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map) {
        throw const FormatException("Rhodanthe evidence must be an object");
      }
      final envelope = Map<String, Object?>.from(decoded);
      if (envelope["storageVersion"] != _storageVersion ||
          envelope["buildId"] != buildId ||
          envelope["evidence"] is! Map) {
        throw const FormatException("incompatible Rhodanthe evidence");
      }
      guard.restoreEvidence(
        Map<String, Object?>.from(envelope["evidence"]! as Map),
      );
      return true;
    } on FormatException {
      await _storage.delete(storageKey);
      return false;
    }
  }

  Future<void> save(RhodantheRolloutGuard guard) {
    return _storage.write(
      storageKey,
      jsonEncode(<String, Object?>{
        "storageVersion": _storageVersion,
        "buildId": buildId,
        "evidence": guard.toEvidenceJson(),
      }),
    );
  }
}

final class RhodantheRolloutEvidenceController {
  final RhodantheRolloutGuard guard;
  final RhodantheRolloutStore store;
  final Duration flushDelay;

  Timer? _flushTimer;
  Future<void> _operationTail = Future<void>.value();
  bool _dirty = false;
  bool _disposed = false;

  RhodantheRolloutEvidenceController({
    RhodantheRolloutGuard? guard,
    RhodantheRolloutStore? store,
    this.flushDelay = const Duration(seconds: 5),
  }) : guard = guard ?? RhodantheRolloutGuard(),
       store = store ?? const RhodantheRolloutStore();

  Future<bool> load() {
    if (_disposed) return Future<bool>.value(false);
    return store.loadInto(guard);
  }

  void record(RhodantheAnalysisObservation observation) {
    if (_disposed) return;
    guard.record(observation);
    _dirty = true;
    _flushTimer ??= Timer(flushDelay, () {
      _flushTimer = null;
      unawaited(flush());
    });
  }

  RhodantheRolloutDecision evaluate(RhodantheRolloutMode mode) {
    return guard.evaluate(mode);
  }

  String auditSummary() => jsonEncode(<String, Object?>{
    "buildId": store.buildId,
    ...guard.auditSummary(),
  });

  Future<void> flush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (!_dirty) return _operationTail;
    _dirty = false;
    _operationTail = _operationTail.then((_) => store.save(guard));
    return _operationTail;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    await flush();
    _disposed = true;
  }
}
