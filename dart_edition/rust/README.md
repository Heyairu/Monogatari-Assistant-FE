# Rhodanthe Rust workspace

This workspace contains the platform-neutral core, text analyzers, and C ABI
bridge of MonoAshi™ Rhodanthe*. The Flutter adapter is not connected yet.

## Implemented

- Contract version 1 and Ring 0/2/4/6/8 decoding.
- Reserved Ring 1/3/5/7 rejection.
- UTF-16 range validation, including surrogate-pair boundaries.
- Per-channel foreground, background, weight, slant, decoration, and interaction arbitration.
- Deterministic same-Ring tie-breaking.
- Semantic style token interning and adjacent `RenderRun` merging.
- Decoration normalization and structured validation errors.
- Stateful open, analyze, edit, revision, and close document lifecycle.
- Atomic UTF-16 edit batches with stale-revision, ordering, overlap, and surrogate-pair guards.
- Versioned render plans for rejecting stale asynchronous results at the Flutter boundary.
- Literal search with case, width, kana, whole-word, ignored-punctuation, and ignored-whitespace options.
- Strict regular-expression search with UTF-16 offset conversion, invalid-pattern errors, and zero-length match filtering.
- Regular-expression budgets aligned with the Dart path: 512 UTF-16 query code units and 2 Mi UTF-16 input code units by default.
- Stable search annotation IDs, a 2,048-result default cap, and active-match Ring 0 promotion.
- Document search that returns match metadata and a versioned render plan in one operation.
- Reusable filler-word trie with failure links and a single-pass multi-pattern scan.
- Global leftmost-longest filler arbitration, Ring 6 annotations, ratios, ranked hits, and independent budgets.
- Combined search and filler analysis that produces one versioned render plan.
- Versioned UTF-8 JSON bridge over a five-function C ABI with an opaque engine handle.
- Panic containment, structured bridge errors, an 8 MiB request cap, serialized engine access, and explicit response-buffer ownership.

## Local verification

```powershell
cd dart_edition/rust
cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
```

The pinned minimal toolchain is declared in `rust-toolchain.toml`.

## Verification status

Verified on 2026-08-26 with Rust/Cargo 1.75.0:

- `cargo fmt --all --check`: passed.
- `cargo test --workspace`: 53 passed, 0 failed.
- `cargo clippy --workspace --all-targets -- -D warnings`: passed with zero warnings.

The regular-expression syntax is Rust `regex` syntax. Look-around and
backreferences are intentionally unsupported. End-to-end deadline cancellation
will be enforced by the future Dart worker adapter; the current synchronous API
enforces pattern, input, and visible-result limits.
