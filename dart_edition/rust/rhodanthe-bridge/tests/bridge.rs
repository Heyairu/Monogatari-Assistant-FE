use std::ptr::NonNull;
use std::slice;

use rhodanthe_bridge::{
    rhodanthe_abi_version, rhodanthe_buffer_free, rhodanthe_engine_free, rhodanthe_engine_new,
    rhodanthe_engine_request, RhodantheBridge, RhodantheHandle, ABI_VERSION, MAX_FFI_REQUEST_BYTES,
};
use serde_json::{json, Value};

fn send(handle: *const RhodantheHandle, request: Value) -> Value {
    let input = serde_json::to_vec(&request).expect("request should serialize");
    // SAFETY: The handle is live and input remains allocated for the call.
    let buffer = unsafe { rhodanthe_engine_request(handle, input.as_ptr(), input.len()) };
    assert!(!buffer.data.is_null());
    // SAFETY: The returned buffer is live until the matching free below.
    let output = unsafe { slice::from_raw_parts(buffer.data, buffer.len) }.to_vec();
    // SAFETY: The exact returned buffer is released once after copying its bytes.
    unsafe { rhodanthe_buffer_free(buffer) };
    serde_json::from_slice(&output).expect("response should be valid JSON")
}

fn envelope(request_id: u64, command: &str, arguments: Option<Value>) -> Value {
    let mut value = json!({
        "contractVersion": 1,
        "requestId": request_id,
        "command": command,
    });
    if let Some(arguments) = arguments {
        value["arguments"] = arguments;
    }
    value
}

#[test]
fn handshake_reports_abi_contract_and_capabilities() {
    assert_eq!(rhodanthe_abi_version(), ABI_VERSION);
    let handle = rhodanthe_engine_new();
    assert!(!handle.is_null());

    let response = send(handle, envelope(1, "handshake", None));

    assert_eq!(response["ok"], true);
    assert_eq!(response["requestId"], 1);
    assert_eq!(response["result"]["abiVersion"], 1);
    assert_eq!(response["result"]["contractVersion"], 1);
    assert_eq!(response["result"]["capabilities"][2], "analyzeSearch");
    assert!(response["result"]["capabilities"]
        .as_array()
        .expect("capabilities should be an array")
        .iter()
        .any(|value| value == "compactAnalysisV1"));

    // SAFETY: The handle is live and is released exactly once after all requests.
    unsafe { rhodanthe_engine_free(handle) };
}

#[test]
fn compact_analysis_omits_duplicate_annotations_and_map_keys() {
    let handle = rhodanthe_engine_new();
    assert!(!handle.is_null());
    let opened = send(
        handle,
        envelope(
            15,
            "openDocument",
            Some(json!({
                "documentId": "compact",
                "revision": 1,
                "fullText": "target filler target",
            })),
        ),
    );
    assert_eq!(opened["ok"], true);

    let analysis = send(
        handle,
        envelope(
            16,
            "analyze",
            Some(json!({
                "documentId": "compact",
                "revision": 1,
                "compactResponse": true,
                "search": {"query": "target", "queryRevision": 1},
                "filler": {"dictionaryRevision": 1, "words": ["filler"]},
            })),
        ),
    );

    assert_eq!(analysis["ok"], true);
    assert_eq!(analysis["result"]["responseFormat"], "compactV1");
    assert_eq!(
        analysis["result"]["search"]["rangesUtf16"],
        json!([0, 6, 14, 20])
    );
    assert!(analysis["result"]["search"].get("annotations").is_none());
    assert!(analysis["result"]["filler"].get("annotations").is_none());
    assert!(analysis["result"]["renderPlan"]["plan"]
        .get("runs")
        .is_none());
    assert!(analysis["result"]["renderPlan"]["plan"]["runsUtf16"].is_array());

    // SAFETY: The handle is live and is released exactly once.
    unsafe { rhodanthe_engine_free(handle) };
}

#[test]
fn raw_ffi_lifecycle_preserves_utf16_ranges_and_revisions() {
    let handle = rhodanthe_engine_new();
    assert!(!handle.is_null());

    let opened = send(
        handle,
        envelope(
            10,
            "openDocument",
            Some(json!({
                "documentId": "chapter",
                "revision": 1,
                "fullText": "😀真的 test test",
            })),
        ),
    );
    assert_eq!(opened["result"]["kind"], "opened");

    let analysis = send(
        handle,
        envelope(
            11,
            "analyze",
            Some(json!({
                "documentId": "chapter",
                "revision": 1,
                "search": {
                    "query": "test",
                    "queryRevision": 4,
                    "activeMatchIndex": 1
                },
                "filler": {
                    "dictionaryRevision": 9,
                    "words": ["真的"]
                }
            })),
        ),
    );
    assert_eq!(analysis["ok"], true);
    assert_eq!(analysis["result"]["search"]["totalMatches"], 2);
    assert_eq!(
        analysis["result"]["search"]["annotations"][0]["range"],
        json!({"start": 5, "end": 9})
    );
    assert_eq!(
        analysis["result"]["filler"]["annotations"][0]["range"],
        json!({"start": 2, "end": 4})
    );
    assert_eq!(analysis["result"]["search"]["activeMatchId"], "search:4:1");
    assert_eq!(analysis["result"]["renderPlan"]["revision"], 1);

    let edited = send(
        handle,
        envelope(
            12,
            "applyEdits",
            Some(json!({
                "documentId": "chapter",
                "baseRevision": 1,
                "revision": 2,
                "edits": [{
                    "startUtf16": 2,
                    "endUtf16": 4,
                    "replacement": "很"
                }]
            })),
        ),
    );
    assert_eq!(edited["result"]["revision"], 2);

    let stale = send(
        handle,
        envelope(
            13,
            "analyze",
            Some(json!({"documentId": "chapter", "revision": 1})),
        ),
    );
    assert_eq!(stale["ok"], false);
    assert_eq!(stale["error"]["code"], "revisionMismatch");
    assert_eq!(stale["requestId"], 13);

    let closed = send(
        handle,
        envelope(14, "closeDocument", Some(json!({"documentId": "chapter"}))),
    );
    assert_eq!(closed["result"]["kind"], "closed");

    // SAFETY: The handle is live and is released exactly once after all requests.
    unsafe { rhodanthe_engine_free(handle) };
}

#[test]
fn external_mention_and_diagnostic_annotations_share_one_render_plan() {
    let mut bridge = RhodantheBridge::new();
    let opened: Value = serde_json::from_slice(
        &bridge.dispatch_json(
            &serde_json::to_vec(&envelope(
                20,
                "openDocument",
                Some(json!({
                    "documentId": "annotations",
                    "revision": 1,
                    "fullText": "Alice typo"
                })),
            ))
            .expect("open request should serialize"),
        ),
    )
    .expect("open response should deserialize");
    assert_eq!(opened["ok"], true);

    let analysis: Value = serde_json::from_slice(
        &bridge.dispatch_json(
            &serde_json::to_vec(&envelope(
                21,
                "analyze",
                Some(json!({
                    "documentId": "annotations",
                    "revision": 1,
                    "externalAnnotations": [
                        {
                            "annotationId": "mention:alice",
                            "source": "mention",
                            "sourceOrder": 0,
                            "ring": 4,
                            "range": {"start": 0, "end": 5},
                            "style": {
                                "foreground": "mention.resolved.foreground",
                                "weight": "medium",
                                "interaction": "mention:alice"
                            },
                            "payloadId": "alice"
                        },
                        {
                            "annotationId": "diagnostic:typo",
                            "source": "diagnostic",
                            "sourceOrder": 1,
                            "ring": 8,
                            "range": {"start": 6, "end": 10},
                            "style": {
                                "decoration": {
                                    "lines": ["underline"],
                                    "style": "dotted",
                                    "color": "diagnostic.decoration",
                                    "thickness": 1.0
                                }
                            }
                        }
                    ]
                })),
            ))
            .expect("analysis request should serialize"),
        ),
    )
    .expect("analysis response should deserialize");

    assert_eq!(analysis["ok"], true);
    assert_eq!(
        analysis["result"]["renderPlan"]["plan"]["runs"][0]["range"],
        json!({"start": 0, "end": 5})
    );
    assert_eq!(
        analysis["result"]["renderPlan"]["plan"]["runs"][1]["range"],
        json!({"start": 6, "end": 10})
    );
    assert_eq!(
        analysis["result"]["renderPlan"]["plan"]["tokenSets"][0]["interaction"],
        "mention:alice"
    );

    let reserved: Value = serde_json::from_slice(
        &bridge.dispatch_json(
            &serde_json::to_vec(&envelope(
                22,
                "analyze",
                Some(json!({
                    "documentId": "annotations",
                    "revision": 1,
                    "externalAnnotations": [{
                        "annotationId": "reserved",
                        "source": "test",
                        "sourceOrder": 0,
                        "ring": 3,
                        "range": {"start": 0, "end": 1},
                        "style": {"weight": "bold"}
                    }]
                })),
            ))
            .expect("reserved request should serialize"),
        ),
    )
    .expect("reserved response should deserialize");
    assert_eq!(reserved["ok"], false);
    assert_eq!(reserved["error"]["code"], "reservedRing");
}

#[test]
fn filler_session_cache_is_reused_and_invalidated_by_dictionary_content() {
    let mut bridge = RhodantheBridge::new();
    let open_request = envelope(
        30,
        "openDocument",
        Some(json!({
            "documentId": "filler-cache",
            "revision": 1,
            "fullText": "alpha beta"
        })),
    );
    let opened: Value = serde_json::from_slice(
        &bridge.dispatch_json(&serde_json::to_vec(&open_request).expect("serialize open")),
    )
    .expect("deserialize open");
    assert_eq!(opened["ok"], true);

    let analyze = |request_id: u64, word: &str| {
        envelope(
            request_id,
            "analyze",
            Some(json!({
                "documentId": "filler-cache",
                "revision": 1,
                "filler": {
                    "dictionaryRevision": 7,
                    "words": [word]
                }
            })),
        )
    };
    let alpha: Value = serde_json::from_slice(
        &bridge.dispatch_json(&serde_json::to_vec(&analyze(31, "alpha")).expect("serialize alpha")),
    )
    .expect("deserialize alpha");
    let alpha_again: Value = serde_json::from_slice(&bridge.dispatch_json(
        &serde_json::to_vec(&analyze(32, "alpha")).expect("serialize cached alpha"),
    ))
    .expect("deserialize cached alpha");
    let beta: Value = serde_json::from_slice(
        &bridge.dispatch_json(&serde_json::to_vec(&analyze(33, "beta")).expect("serialize beta")),
    )
    .expect("deserialize beta");

    assert_eq!(alpha["result"]["filler"]["hits"][0]["word"], "alpha");
    assert_eq!(alpha_again["result"]["filler"]["hits"][0]["word"], "alpha");
    assert_eq!(beta["result"]["filler"]["hits"][0]["word"], "beta");
}

#[test]
fn protocol_rejects_malformed_and_incompatible_requests() {
    let mut bridge = RhodantheBridge::new();
    let malformed: Value = serde_json::from_slice(&bridge.dispatch_json(b"not-json"))
        .expect("malformed response should still be JSON");
    assert_eq!(malformed["error"]["code"], "invalidRequest");

    let incompatible: Value = serde_json::from_slice(
        &bridge.dispatch_json(br#"{"contractVersion":2,"requestId":7,"command":"handshake"}"#),
    )
    .expect("version response should be JSON");
    assert_eq!(incompatible["error"]["code"], "incompatibleContract");
    assert_eq!(incompatible["requestId"], 7);
}

#[test]
fn raw_ffi_rejects_null_handles_and_oversized_inputs_before_dereferencing() {
    let input = b"{}";
    // SAFETY: Null handles are explicitly accepted as a structured error path.
    let null_buffer =
        unsafe { rhodanthe_engine_request(std::ptr::null(), input.as_ptr(), input.len()) };
    // SAFETY: The returned buffer is live until it is freed below.
    let null_output = unsafe { slice::from_raw_parts(null_buffer.data, null_buffer.len) };
    let null_response: Value =
        serde_json::from_slice(null_output).expect("null-handle response should be JSON");
    assert_eq!(null_response["error"]["code"], "invalidHandle");
    // SAFETY: The exact returned buffer is released once.
    unsafe { rhodanthe_buffer_free(null_buffer) };

    let handle = rhodanthe_engine_new();
    assert!(!handle.is_null());
    let unreadable = NonNull::<u8>::dangling().as_ptr();
    // SAFETY: The bridge checks the byte budget before reading the pointer.
    let oversized =
        unsafe { rhodanthe_engine_request(handle, unreadable, MAX_FFI_REQUEST_BYTES + 1) };
    // SAFETY: The returned buffer is live until it is freed below.
    let oversized_output = unsafe { slice::from_raw_parts(oversized.data, oversized.len) };
    let oversized_response: Value =
        serde_json::from_slice(oversized_output).expect("oversized response should be JSON");
    assert_eq!(oversized_response["error"]["code"], "budgetExceeded");
    // SAFETY: The exact returned buffer and handle are each released once.
    unsafe {
        rhodanthe_buffer_free(oversized);
        rhodanthe_engine_free(handle);
    }
}
