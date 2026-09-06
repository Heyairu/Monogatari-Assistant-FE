# Rhodanthe bridge

`rhodanthe-bridge` exposes the stateful Rust engine through a small C ABI. The
wire payload is UTF-8 JSON; all editor offsets inside the payload are UTF-16
code-unit offsets.

## ABI

The public declarations are in `include/rhodanthe_bridge.h`:

1. Check `rhodanthe_abi_version()`.
2. Create one opaque engine with `rhodanthe_engine_new()`.
3. Submit commands with `rhodanthe_engine_request()`.
4. Copy/decode the returned bytes, then call `rhodanthe_buffer_free()` exactly once.
5. Close all documents and call `rhodanthe_engine_free()` exactly once.

The bridge contains Rust panics and returns an `internal` JSON error. Invalid
raw pointers are outside the C ABI contract and cannot be detected safely.
Calls on the same live engine are serialized, but freeing an engine concurrently
with a request is invalid.

## Envelope

Every request carries the core contract version and may carry a correlation ID:

```json
{
  "contractVersion": 1,
  "requestId": 42,
  "command": "openDocument",
  "arguments": {
    "documentId": "chapter-1",
    "revision": 1,
    "fullText": "本文"
  }
}
```

Supported commands are `handshake`, `openDocument`, `applyEdits`, `analyze`,
and `closeDocument`. `analyze` accepts optional `search` and `filler` objects in
one request and returns one combined `renderPlan`.

Successful and failed responses have one stable top-level shape:

```json
{"ok":true,"contractVersion":1,"requestId":42,"result":{}}
```

```json
{
  "ok": false,
  "contractVersion": 1,
  "requestId": 42,
  "error": {"code": "revisionMismatch", "message": "..."}
}
```

The request limit is 8 MiB. Error codes currently include `invalidRequest`,
`incompatibleContract`, `documentNotOpen`, `documentAlreadyOpen`,
`revisionMismatch`, `invalidRevision`, `invalidRange`, `budgetExceeded`,
`regexRejected`, `invalidAnnotation`, `invalidHandle`, and `internal`.
