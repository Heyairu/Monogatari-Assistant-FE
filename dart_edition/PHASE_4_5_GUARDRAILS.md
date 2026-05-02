# Phase 4/5 Guardrails

## Immutable Contracts
- `CharacterEntryData` and `LocationData` use immutable collection wrappers.
- Treat provider state as snapshots only.
- Never mutate collections returned from a provider or model getter in place.
- Build a new `List` or `Map`, then submit it through the notifier once.

## Cache Contracts
- Chapter word-count cache is bounded and pruned.
- The cache must be cleared on project switch.
- Segment updates must prune entries that no longer belong to active chapter IDs.
- Do not introduce new global caches without a clear lifecycle rule and a cap or invalidation path.

## Provider Update Rules
- UI code may keep a local draft for editing.
- Provider writes should happen at a single commit point, not on every field sync.
- If a rename or reorder touches keys, update local selection state before committing the provider snapshot to avoid listener fallback loops.
- Copy-on-write recursion is required for nested tree updates in world settings.

## Validation Routine
Run these checks before merging related changes:
- `flutter test test/phase4_phase5_guardrails_test.dart`
- `flutter analyze`
- A manual smoke run of the character editor, including add, rename, reorder, and delete.
- A repeated-edit stress pass for world settings and character editing to watch for immutability exceptions or obvious lag.

## Long-Session Observation
- Use the test suite as the default guard.
- For suspected memory growth, repeat the relevant edit loop in debug mode and observe the process with the IDE profiler or the OS task manager.
- If a future change adds a new mutable collection field, document the ownership and cleanup rule in the same file before shipping.
