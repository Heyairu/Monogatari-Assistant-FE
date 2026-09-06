# Rhodanthe Dart infrastructure

This directory is the Dart side of the Rhodanthe contract:

- `rhodanthe_protocol.dart` owns versioned command DTOs and strict response decoding.
- `rhodanthe_native_client.dart` conditionally exports a native or unsupported-platform client.
- `rhodanthe_native_client_io.dart` owns raw FFI allocation, copying, and buffer release.
- `rhodanthe_worker_executor.dart` owns the native client in a long-lived isolate and correlates ordered requests.
- `rhodanthe_latest_coordinator.dart` owns latest-only generations, logical invalidation, deadlines, and fallback selection.
- `rhodanthe_editor_session.dart` owns the ordered editor document lifecycle and shadow/canary/full rollout policy.
- `rhodanthe_rollout_guard.dart` evaluates bounded Shadow and Search canary evidence without changing mode at runtime.
- `rhodanthe_rollout_store.dart` persists privacy-safe, build-scoped evidence through SharedPreferences with delayed writes and shutdown flush.
- `rhodanthe_rollout_cohort.dart` persists one random 0–99 installation bucket and resolves stage-aware canary participation without storing an account or device identifier.
- `rhodanthe_release_plan.dart` maps the four release stages to immutable build arguments and refuses promotions without evidence from the preceding binary.
- `rhodanthe_annotations.dart` owns external-annotation DTOs and Ring 8 diagnostics. Ring 4 compatibility types remain inert; no Mention UI, persistence, or editor interaction is enabled.
- `rhodanthe_theme.dart` resolves semantic color tokens for light, dark, and high-contrast themes.
- `rhodanthe_text_span_adapter.dart` validates a versioned render plan and converts its non-overlapping UTF-16 runs into Flutter `TextSpan` segments.

`RhodantheNativeClient.sendSync` is intentionally synchronous and must not run on
the Flutter UI isolate. `RhodantheWorkerExecutor` is the supported asynchronous
adapter for `RhodantheLatestCoordinator`. Timeout and invalidation stop waiting
and prevent stale publication; they do not interrupt an already-running raw
native call inside the worker.

The span adapter only publishes a plan when its contract version, document
revision, UTF-16 text length, run ordering, token references, semantic colors,
and surrogate-pair boundaries are all valid. Otherwise it returns one plain
fallback span. IME composing boundaries participate in the same segmentation,
and the composing decoration is merged with Rhodanthe's decoration. Interaction
tokens and annotation IDs are returned as metadata; the adapter deliberately
does not allocate gesture recognizers or own editor interaction state.

Web uses the stub client and remains on the Dart fallback path.

Rhodanthe is enabled by default in Full mode. Release tooling should use
`RHODANTHE_RELEASE_STAGE`; the older `RHODANTHE_MODE` remains an explicit
compatibility and local-diagnostics override:

- `--dart-define=RHODANTHE_RELEASE_STAGE=shadow` compares Dart and Rust search ranges without publishing native styles.
- `--dart-define=RHODANTHE_RELEASE_STAGE=search` publishes Ring 0/2 search plans while retaining the Dart fallback.
- `--dart-define=RHODANTHE_RELEASE_STAGE=full` combines search, the cached Ring 6 filler dictionary, and Ring 8 proofreading diagnostics.
- `--dart-define=RHODANTHE_RELEASE_STAGE=default-on` uses the same Full runtime path but identifies the artifact as the formally enabled release stage. Mention is intentionally excluded from both Full stages.

The default stage is `default-on`, which resolves to Full. Set
`--dart-define=RHODANTHE_KILL_SWITCH=true` for the highest-priority immediate
shutdown, or `--dart-define=RHODANTHE_MODE=disabled` for a diagnostic override.
Native load, lifecycle, timeout, contract, or render validation failures stay
off the input path and leave the existing Dart highlighter active.

Desktop builds invoke Cargo and install the resulting native library beside the
application (`windows/CMakeLists.txt`) or in the bundle `lib` directory
(`linux/CMakeLists.txt`). `tool/build_rhodanthe_native.dart` provides explicit
staging for CI, Android, and Apple targets; see `rust/PACKAGING.md`.

Startup performs an ABI/contract/capability preflight. Three consecutive
analysis failures open a 30-second circuit breaker; the editor immediately
keeps using the Dart highlighter and makes one half-open native retry after the
cooldown. Health changes never block input or publish a stale render plan.

Repeatable bridge, worker, TextSpan, and Flutter layout measurements live in
`benchmark/`; see `benchmark/RHODANTHE.md`. The target Windows Profile workload
meets the documented latency gates; rollout evidence and receipts remain
available for monitoring and rollback decisions after default enablement.

Analyze requests negotiate `compactAnalysisV1`: visible search ranges and
render runs are encoded as flat UTF-16 integer arrays, while duplicated analyzer
annotations are omitted. The legacy response remains available for compatibility.

Rollout promotion is deliberately manual:

- Shadow requires at least 100 completed samples, exact Dart/Rust ranges, no failures, and analysis p95 at or below 75 ms.
- Search canary requires at least 500 completed samples under the same failure and latency rules before recommending Full.
- Stale work is ignored. Timeout, fallback, mismatch, or latency regression holds the current build-time mode; the guard never promotes a running session automatically.

Evidence is stored per `RHODANTHE_BUILD_ID`. A different build ID, corrupt JSON,
or unsupported evidence version discards the old window rather than mixing
results across binaries. Persisted observations contain only mode, duration,
execution status, exact-match state, and publication state—never document text,
query, document ID, annotation payload, or revision. The controller exposes a
privacy-safe JSON audit summary and flushes its bounded window after five seconds
or during editor disposal.

Evidence schema v2 includes a UTC observation time. Only the latest seven days
are eligible, and samples more than five minutes in the future are discarded to
protect against stale data and clock skew. Samples remain isolated by rollout
mode. A Search canary failure/mismatch recommends Shadow; an unhealthy Full
window recommends Search canary. These are logged manual rollback recommendations,
never runtime mode mutations.

Give profile/release canaries an immutable build identifier:

```text
flutter build windows --profile \
  --dart-define=RHODANTHE_RELEASE_STAGE=shadow \
  --dart-define=RHODANTHE_BUILD_ID=<commit-or-release-id>
```

Save the JSON portion of a `Rhodanthe rollout audit:` log as an artifact, then
enforce the expected transition in CI:

```text
dart run tool/check_rhodanthe_rollout.dart \
  --input rollout-audit.json \
  --expected-build-id <commit-or-release-id> \
  --current-mode shadow \
  --require-mode searchCanary
```

The checker returns exit 0 only for the expected build and recommendation,
exit 1 for a failed gate, 64 for invalid arguments, 65 for malformed audit data,
and 66 when the input file cannot be read.

Prefer the rollout preparation tool for release artifacts. It emits the exact
Flutter arguments in dry-run mode and only starts the build with `--execute`:

```text
# Stage 1: no prior evidence; native output remains invisible.
dart run tool/prepare_rhodanthe_rollout.dart \
  --stage shadow --target-build-id <shadow-build-id>

# Stage 2: requires accepted Shadow evidence from the source binary.
dart run tool/prepare_rhodanthe_rollout.dart \
  --stage search --evidence rollout-audit.json \
  --source-build-id <shadow-build-id> \
  --target-build-id <search-build-id> --execute
```

Use `--stage full` after Search recommends Full. Use `--stage default-on` only
after the Full binary has its own 500-sample healthy soak window. The audit
checker rejects reports that weaken the production policy below 100 Shadow
samples, 500 canary/Full samples, or relax the 75 ms p95 budget.

Add `--receipt <path>` to save the approved preparation, source evidence,
immutable source/target build IDs, exact Flutter arguments, and UTC generation
time as a privacy-safe JSON release artifact. Decisions also report required,
remaining, and completed sample percentages. Runtime logging is limited to 25%,
50%, and 75% milestones plus one promotion, rollback, or Full default-on-ready
event; the terminal event includes the complete audit JSON.

Search and Full artifacts default to a 10% stable installation cohort. Set an
explicit percentage with `--canary-percent <1..100>`; the value is embedded as
`RHODANTHE_CANARY_PERCENT` and copied into the release receipt. Shadow and
default-on are always 100%. A Search installation outside the cohort remains in
Shadow; a Full installation outside the cohort remains on Search. The persisted
bucket is only an integer from 0 through 99 and is not derived from user,
project, document, hardware, or account data. The legacy `RHODANTHE_MODE`
override bypasses cohort selection for local diagnostics only.
