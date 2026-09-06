import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_editor_session.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_latest_coordinator.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_rollout_guard.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_rollout_store.dart";

final DateTime _testNow = DateTime.utc(2026, 8, 28, 12);

void main() {
  test(
    "rollout evidence persists privacy-safe mode-specific samples",
    () async {
      final storage = _MemoryStore();
      final first = _controller(storage);
      first.record(_observation(RhodantheRolloutMode.shadow));
      first.record(_observation(RhodantheRolloutMode.shadow));
      first.record(_observation(RhodantheRolloutMode.searchCanary));
      await first.flush();

      final encoded = storage.values[RhodantheRolloutStore.storageKey]!;
      expect(encoded, isNot(contains("revision")));
      expect(encoded, isNot(contains("query")));
      expect(encoded, isNot(contains("document")));

      final restored = _controller(storage);
      expect(await restored.load(), isTrue);
      expect(
        restored.evaluate(RhodantheRolloutMode.shadow).recommendedMode,
        RhodantheRolloutMode.searchCanary,
      );
      expect(
        restored.evaluate(RhodantheRolloutMode.searchCanary).reason,
        RhodantheRolloutDecisionReason.insufficientSamples,
      );
      expect(restored.auditSummary(), contains('"buildId":"dev"'));
      expect(restored.auditSummary(), contains('"retainedSamples":3'));
      await first.dispose();
      await restored.dispose();
    },
  );

  test("corrupt evidence is deleted without blocking startup", () async {
    final storage = _MemoryStore()
      ..values[RhodantheRolloutStore.storageKey] = "not-json";
    final controller = _controller(storage);

    expect(await controller.load(), isFalse);
    expect(storage.values, isNot(contains(RhodantheRolloutStore.storageKey)));
    expect(controller.guard.retainedSamples, 0);
    await controller.dispose();
  });

  test("dispose flushes a pending observation", () async {
    final storage = _MemoryStore();
    final controller = _controller(storage);
    controller.record(_observation(RhodantheRolloutMode.shadow));

    await controller.dispose();

    expect(storage.values[RhodantheRolloutStore.storageKey], isNotNull);
  });

  test("evidence from another build is discarded", () async {
    final storage = _MemoryStore();
    final first = _controller(storage, buildId: "build-a");
    first.record(_observation(RhodantheRolloutMode.shadow));
    await first.flush();

    final nextBuild = _controller(storage, buildId: "build-b");
    expect(await nextBuild.load(), isFalse);
    expect(nextBuild.guard.retainedSamples, 0);
    await first.dispose();
    await nextBuild.dispose();
  });
}

RhodantheRolloutEvidenceController _controller(
  _MemoryStore storage, {
  String buildId = "dev",
}) {
  return RhodantheRolloutEvidenceController(
    guard: RhodantheRolloutGuard(
      shadowSamplesRequired: 2,
      canarySamplesRequired: 2,
      maxWindowSamples: 8,
      now: () => _testNow,
    ),
    store: RhodantheRolloutStore(storage: storage, buildId: buildId),
    flushDelay: const Duration(days: 1),
  );
}

RhodantheAnalysisObservation _observation(RhodantheRolloutMode mode) {
  return RhodantheAnalysisObservation(
    mode: mode,
    observedAt: _testNow,
    revision: 99,
    elapsed: const Duration(milliseconds: 10),
    status: RhodantheExecutionStatus.applied,
    shadowExactMatch: mode == RhodantheRolloutMode.shadow ? true : null,
    published: mode != RhodantheRolloutMode.shadow,
  );
}

final class _MemoryStore implements RhodantheEvidenceKeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
