mod protocol;

use std::panic::{catch_unwind, AssertUnwindSafe};
use std::ptr;
use std::slice;
use std::sync::Mutex;

use protocol::{
    compact_filler_result_value, compact_render_plan_value, compact_search_result_value,
    error_response, filler_result_value, handshake_value, render_plan_value, search_result_value,
    success_response, Command, RequestEnvelope, MAX_REQUEST_BYTES,
};
use rhodanthe_analyzers::{
    analyze_document_with_filler_matcher, AnalysisError, DocumentAnalysisRequest, FillerError,
    FillerMatcher, FillerRequest, SearchError,
};
use rhodanthe_core::{RhodantheEngine, RhodantheError, CONTRACT_VERSION};
use serde_json::json;

pub const ABI_VERSION: u32 = 1;
pub const MAX_FFI_REQUEST_BYTES: usize = MAX_REQUEST_BYTES;

pub struct RhodantheBridge {
    engine: RhodantheEngine,
    filler_cache: Option<FillerCache>,
}

struct FillerCache {
    dictionary_revision: u64,
    words: Vec<String>,
    matcher: FillerMatcher,
}

impl Default for RhodantheBridge {
    fn default() -> Self {
        Self::new()
    }
}

impl RhodantheBridge {
    pub fn new() -> Self {
        Self {
            engine: RhodantheEngine::new(),
            filler_cache: None,
        }
    }

    pub fn dispatch_json(&mut self, input: &[u8]) -> Vec<u8> {
        if input.len() > MAX_REQUEST_BYTES {
            return error_response(
                None,
                "budgetExceeded",
                &format!(
                    "request has {} bytes; maximum is {MAX_REQUEST_BYTES}",
                    input.len()
                ),
            );
        }

        let request: RequestEnvelope = match serde_json::from_slice(input) {
            Ok(request) => request,
            Err(error) => return error_response(None, "invalidRequest", &error.to_string()),
        };
        let request_id = request.request_id;
        if request.contract_version != CONTRACT_VERSION {
            return error_response(
                request_id,
                "incompatibleContract",
                &format!(
                    "contract version {} is not supported; expected {CONTRACT_VERSION}",
                    request.contract_version
                ),
            );
        }

        match self.dispatch(request.command) {
            Ok(result) => success_response(request_id, result),
            Err(error) => error_response(request_id, error.code, &error.message),
        }
    }

    fn dispatch(&mut self, command: Command) -> Result<serde_json::Value, BridgeError> {
        match command {
            Command::Handshake => Ok(handshake_value()),
            Command::OpenDocument(arguments) => {
                self.engine.open_document(
                    arguments.document_id.clone(),
                    arguments.revision,
                    arguments.full_text,
                )?;
                Ok(json!({
                    "kind": "opened",
                    "documentId": arguments.document_id,
                    "revision": arguments.revision,
                }))
            }
            Command::ApplyEdits(arguments) => {
                let edits = arguments
                    .edits
                    .into_iter()
                    .map(Into::into)
                    .collect::<Vec<_>>();
                self.engine.apply_edits(
                    &arguments.document_id,
                    arguments.base_revision,
                    arguments.revision,
                    &edits,
                )?;
                Ok(json!({
                    "kind": "edited",
                    "documentId": arguments.document_id,
                    "revision": arguments.revision,
                }))
            }
            Command::Analyze(arguments) => {
                let compact_response = arguments.compact_response;
                let external_annotations = arguments
                    .external_annotations
                    .into_iter()
                    .map(TryInto::try_into)
                    .collect::<Result<Vec<_>, RhodantheError>>()?;
                let filler = arguments.filler.map(Into::into);
                self.prepare_filler_cache(filler.as_ref())?;
                let request = DocumentAnalysisRequest {
                    search: arguments.search.map(Into::into),
                    filler,
                    external_annotations,
                };
                let filler_matcher = self.filler_cache.as_ref().and_then(|cache| {
                    request.filler.as_ref().and_then(|filler| {
                        (cache.dictionary_revision == filler.dictionary_revision
                            && cache.words == filler.words)
                            .then_some(&cache.matcher)
                    })
                });
                let result = analyze_document_with_filler_matcher(
                    &self.engine,
                    &arguments.document_id,
                    arguments.revision,
                    &request,
                    filler_matcher,
                )?;
                if compact_response {
                    Ok(json!({
                        "kind": "analysis",
                        "responseFormat": "compactV1",
                        "search": result.search.as_ref().map(compact_search_result_value),
                        "filler": result.filler.as_ref().map(compact_filler_result_value),
                        "renderPlan": compact_render_plan_value(&result.render_plan),
                    }))
                } else {
                    Ok(json!({
                        "kind": "analysis",
                        "search": result.search.as_ref().map(search_result_value),
                        "filler": result.filler.as_ref().map(filler_result_value),
                        "renderPlan": render_plan_value(&result.render_plan),
                    }))
                }
            }
            Command::CloseDocument(arguments) => {
                self.engine.close_document(&arguments.document_id)?;
                Ok(json!({
                    "kind": "closed",
                    "documentId": arguments.document_id,
                }))
            }
        }
    }

    fn prepare_filler_cache(&mut self, filler: Option<&FillerRequest>) -> Result<(), FillerError> {
        let Some(filler) = filler else {
            return Ok(());
        };
        let cache_matches = self.filler_cache.as_ref().is_some_and(|cache| {
            cache.dictionary_revision == filler.dictionary_revision && cache.words == filler.words
        });
        if !cache_matches {
            self.filler_cache = Some(FillerCache {
                dictionary_revision: filler.dictionary_revision,
                words: filler.words.clone(),
                matcher: FillerMatcher::new(filler.dictionary_revision, &filler.words)?,
            });
        }
        Ok(())
    }
}

struct BridgeError {
    code: &'static str,
    message: String,
}

impl BridgeError {
    fn new(code: &'static str, error: impl ToString) -> Self {
        Self {
            code,
            message: error.to_string(),
        }
    }
}

impl From<RhodantheError> for BridgeError {
    fn from(error: RhodantheError) -> Self {
        let code = match error {
            RhodantheError::DocumentNotOpen { .. } => "documentNotOpen",
            RhodantheError::DocumentAlreadyOpen { .. } => "documentAlreadyOpen",
            RhodantheError::RevisionMismatch { .. } => "revisionMismatch",
            RhodantheError::NonIncreasingRevision { .. } => "invalidRevision",
            RhodantheError::ReservedRing(_) | RhodantheError::UnknownRing(_) => "reservedRing",
            RhodantheError::InvalidRange { .. }
            | RhodantheError::SplitsSurrogatePair { .. }
            | RhodantheError::InvalidEditRange { .. }
            | RhodantheError::EditSplitsSurrogatePair { .. }
            | RhodantheError::EditsNotSorted { .. }
            | RhodantheError::OverlappingEdits { .. } => "invalidRange",
            RhodantheError::TextTooLong | RhodantheError::TooManyTokenSets => "budgetExceeded",
            RhodantheError::EmptyAnnotationId { .. }
            | RhodantheError::EmptyStyle { .. }
            | RhodantheError::EmptySemanticToken { .. }
            | RhodantheError::EmptyDecorationLines { .. }
            | RhodantheError::InvalidDecorationThickness { .. } => "invalidAnnotation",
            RhodantheError::EmptyDocumentId => "invalidRequest",
        };
        Self::new(code, error)
    }
}

impl From<SearchError> for BridgeError {
    fn from(error: SearchError) -> Self {
        match error {
            SearchError::InvalidRegularExpression { .. } => Self::new("regexRejected", error),
            SearchError::RegularExpressionTooLong { .. }
            | SearchError::InputTooLong { .. }
            | SearchError::TextTooLong => Self::new("budgetExceeded", error),
            SearchError::Core(error) => error.into(),
        }
    }
}

impl From<FillerError> for BridgeError {
    fn from(error: FillerError) -> Self {
        Self::new("budgetExceeded", error)
    }
}

impl From<AnalysisError> for BridgeError {
    fn from(error: AnalysisError) -> Self {
        match error {
            AnalysisError::Search(error) => error.into(),
            AnalysisError::Filler(error) => error.into(),
            AnalysisError::Core(error) => error.into(),
        }
    }
}

#[repr(C)]
#[derive(Debug)]
pub struct RhodantheBuffer {
    pub data: *mut u8,
    pub len: usize,
    pub capacity: usize,
}

impl RhodantheBuffer {
    fn from_vec(mut value: Vec<u8>) -> Self {
        let buffer = Self {
            data: value.as_mut_ptr(),
            len: value.len(),
            capacity: value.capacity(),
        };
        std::mem::forget(value);
        buffer
    }
}

pub struct RhodantheHandle {
    bridge: Mutex<RhodantheBridge>,
}

#[no_mangle]
pub extern "C" fn rhodanthe_abi_version() -> u32 {
    ABI_VERSION
}

#[no_mangle]
pub extern "C" fn rhodanthe_engine_new() -> *mut RhodantheHandle {
    catch_unwind(|| {
        Box::into_raw(Box::new(RhodantheHandle {
            bridge: Mutex::new(RhodantheBridge::new()),
        }))
    })
    .unwrap_or(ptr::null_mut())
}

/// Releases an engine returned by [`rhodanthe_engine_new`].
///
/// # Safety
///
/// `handle` must be null or a live pointer returned by `rhodanthe_engine_new`.
/// It must not be used after this call, freed twice, or freed while a request is running.
#[no_mangle]
pub unsafe extern "C" fn rhodanthe_engine_free(handle: *mut RhodantheHandle) {
    if handle.is_null() {
        return;
    }
    let _ = catch_unwind(AssertUnwindSafe(|| {
        // SAFETY: Guaranteed by this function's caller contract.
        drop(unsafe { Box::from_raw(handle) });
    }));
}

/// Executes one UTF-8 JSON request and returns a Rust-owned UTF-8 JSON buffer.
///
/// # Safety
///
/// `handle` must point to a live engine. When `input_len > 0`, `input` must be
/// readable for exactly `input_len` bytes for the duration of the call. Calls may
/// run concurrently on the same handle, but the handle must not be freed until
/// every call completes. The returned buffer must be released exactly once with
/// [`rhodanthe_buffer_free`].
#[no_mangle]
pub unsafe extern "C" fn rhodanthe_engine_request(
    handle: *const RhodantheHandle,
    input: *const u8,
    input_len: usize,
) -> RhodantheBuffer {
    let response = catch_unwind(AssertUnwindSafe(|| {
        request_from_raw_parts(handle, input, input_len)
    }))
    .unwrap_or_else(|_| error_response(None, "internal", "Rust bridge panic was contained"));
    RhodantheBuffer::from_vec(response)
}

fn request_from_raw_parts(
    handle: *const RhodantheHandle,
    input: *const u8,
    input_len: usize,
) -> Vec<u8> {
    if handle.is_null() {
        return error_response(None, "invalidHandle", "engine handle is null");
    }
    if input_len > MAX_REQUEST_BYTES {
        return error_response(
            None,
            "budgetExceeded",
            &format!("request has {input_len} bytes; maximum is {MAX_REQUEST_BYTES}"),
        );
    }
    let input = if input_len == 0 {
        &[]
    } else if input.is_null() {
        return error_response(None, "invalidRequest", "request pointer is null");
    } else {
        // SAFETY: The exported function's caller guarantees this memory range.
        unsafe { slice::from_raw_parts(input, input_len) }
    };
    // SAFETY: Null was rejected and the exported function's caller owns a live handle.
    let handle = unsafe { &*handle };
    match handle.bridge.lock() {
        Ok(mut bridge) => bridge.dispatch_json(input),
        Err(_) => error_response(None, "internal", "engine lock is poisoned"),
    }
}

/// Releases a response buffer returned by [`rhodanthe_engine_request`].
///
/// # Safety
///
/// `buffer` must be the exact, still-owned value returned by
/// `rhodanthe_engine_request`. It must not be freed twice or accessed afterward.
#[no_mangle]
pub unsafe extern "C" fn rhodanthe_buffer_free(buffer: RhodantheBuffer) {
    if buffer.data.is_null() {
        return;
    }
    let _ = catch_unwind(AssertUnwindSafe(|| {
        // SAFETY: Guaranteed by this function's caller contract.
        drop(unsafe { Vec::from_raw_parts(buffer.data, buffer.len, buffer.capacity) });
    }));
}
