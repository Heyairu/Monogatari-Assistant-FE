use rhodanthe_analyzers::{
    FillerBudget, FillerRequest, FillerResult, SearchOptions, SearchRequest, SearchResult,
};
use rhodanthe_core::{
    Annotation, DecorationLine, DecorationSpec, DecorationStyle, FontSlant, FontWeight, RenderPlan,
    RhodantheError, Ring, StylePatch, TextEdit, Utf16Range, VersionedRenderPlan, CONTRACT_VERSION,
};
use serde::Deserialize;
use serde_json::{json, Value};

pub const MAX_REQUEST_BYTES: usize = 8 * 1024 * 1024;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RequestEnvelope {
    pub contract_version: u16,
    #[serde(default)]
    pub request_id: Option<u64>,
    #[serde(flatten)]
    pub command: Command,
}

#[derive(Debug, Deserialize)]
#[serde(tag = "command", content = "arguments", rename_all = "camelCase")]
pub enum Command {
    Handshake,
    OpenDocument(OpenDocumentArgs),
    ApplyEdits(ApplyEditsArgs),
    Analyze(AnalyzeArgs),
    CloseDocument(CloseDocumentArgs),
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct OpenDocumentArgs {
    pub document_id: String,
    pub revision: u64,
    pub full_text: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ApplyEditsArgs {
    pub document_id: String,
    pub base_revision: u64,
    pub revision: u64,
    pub edits: Vec<TextEditDto>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct TextEditDto {
    pub start_utf16: u32,
    pub end_utf16: u32,
    pub replacement: String,
}

impl From<TextEditDto> for TextEdit {
    fn from(value: TextEditDto) -> Self {
        Self {
            range: Utf16Range::new(value.start_utf16, value.end_utf16),
            replacement: value.replacement,
        }
    }
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct AnalyzeArgs {
    pub document_id: String,
    pub revision: u64,
    #[serde(default)]
    pub compact_response: bool,
    #[serde(default)]
    pub search: Option<SearchRequestDto>,
    #[serde(default)]
    pub filler: Option<FillerRequestDto>,
    #[serde(default)]
    pub external_annotations: Vec<ExternalAnnotationDto>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ExternalAnnotationDto {
    pub annotation_id: String,
    pub source: String,
    pub source_order: u32,
    pub ring: u8,
    pub range: RangeDto,
    pub style: StylePatchDto,
    #[serde(default)]
    pub payload_id: Option<String>,
}

impl TryFrom<ExternalAnnotationDto> for Annotation {
    type Error = RhodantheError;

    fn try_from(value: ExternalAnnotationDto) -> Result<Self, Self::Error> {
        Ok(Self {
            annotation_id: value.annotation_id,
            source: value.source,
            source_order: value.source_order,
            ring: Ring::try_from(value.ring)?,
            range: value.range.into(),
            style: value.style.into(),
            payload_id: value.payload_id,
        })
    }
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct RangeDto {
    pub start: u32,
    pub end: u32,
}

impl From<RangeDto> for Utf16Range {
    fn from(value: RangeDto) -> Self {
        Self::new(value.start, value.end)
    }
}

#[derive(Debug, Default, Deserialize)]
#[serde(default, rename_all = "camelCase", deny_unknown_fields)]
pub struct StylePatchDto {
    pub foreground: Option<String>,
    pub background: Option<String>,
    pub weight: Option<FontWeightDto>,
    pub slant: Option<FontSlantDto>,
    pub decoration: Option<DecorationDto>,
    pub interaction: Option<String>,
}

impl From<StylePatchDto> for StylePatch {
    fn from(value: StylePatchDto) -> Self {
        Self {
            foreground: value.foreground,
            background: value.background,
            weight: value.weight.map(Into::into),
            slant: value.slant.map(Into::into),
            decoration: value.decoration.map(Into::into),
            interaction: value.interaction,
        }
    }
}

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum FontWeightDto {
    Regular,
    Medium,
    Semibold,
    Bold,
}

impl From<FontWeightDto> for FontWeight {
    fn from(value: FontWeightDto) -> Self {
        match value {
            FontWeightDto::Regular => Self::Regular,
            FontWeightDto::Medium => Self::Medium,
            FontWeightDto::Semibold => Self::Semibold,
            FontWeightDto::Bold => Self::Bold,
        }
    }
}

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum FontSlantDto {
    Normal,
    Italic,
}

impl From<FontSlantDto> for FontSlant {
    fn from(value: FontSlantDto) -> Self {
        match value {
            FontSlantDto::Normal => Self::Normal,
            FontSlantDto::Italic => Self::Italic,
        }
    }
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct DecorationDto {
    pub lines: Vec<DecorationLineDto>,
    pub style: DecorationStyleDto,
    pub color: String,
    pub thickness: f32,
}

impl From<DecorationDto> for DecorationSpec {
    fn from(value: DecorationDto) -> Self {
        Self {
            lines: value.lines.into_iter().map(Into::into).collect(),
            style: value.style.into(),
            color: value.color,
            thickness: value.thickness,
        }
    }
}

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum DecorationLineDto {
    Underline,
    Overline,
    LineThrough,
}

impl From<DecorationLineDto> for DecorationLine {
    fn from(value: DecorationLineDto) -> Self {
        match value {
            DecorationLineDto::Underline => Self::Underline,
            DecorationLineDto::Overline => Self::Overline,
            DecorationLineDto::LineThrough => Self::LineThrough,
        }
    }
}

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum DecorationStyleDto {
    Solid,
    Double,
    Dotted,
    Dashed,
    Wavy,
}

impl From<DecorationStyleDto> for DecorationStyle {
    fn from(value: DecorationStyleDto) -> Self {
        match value {
            DecorationStyleDto::Solid => Self::Solid,
            DecorationStyleDto::Double => Self::Double,
            DecorationStyleDto::Dotted => Self::Dotted,
            DecorationStyleDto::Dashed => Self::Dashed,
            DecorationStyleDto::Wavy => Self::Wavy,
        }
    }
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct SearchRequestDto {
    pub query: String,
    pub query_revision: u64,
    #[serde(default)]
    pub options: SearchOptionsDto,
    #[serde(default)]
    pub max_results: Option<usize>,
    #[serde(default)]
    pub active_match_index: Option<usize>,
    #[serde(default)]
    pub max_input_code_units: Option<usize>,
    #[serde(default)]
    pub max_regexp_code_units: Option<usize>,
}

impl From<SearchRequestDto> for SearchRequest {
    fn from(value: SearchRequestDto) -> Self {
        let mut request = SearchRequest::new(value.query, value.query_revision);
        request.options = value.options.into();
        request.active_match_index = value.active_match_index;
        if let Some(max_results) = value.max_results {
            request.max_results = max_results;
        }
        if let Some(max_input_code_units) = value.max_input_code_units {
            request.max_input_code_units = max_input_code_units;
        }
        if let Some(max_regexp_code_units) = value.max_regexp_code_units {
            request.max_regexp_code_units = max_regexp_code_units;
        }
        request
    }
}

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(default, rename_all = "camelCase", deny_unknown_fields)]
pub struct SearchOptionsDto {
    pub match_case: bool,
    pub whole_word: bool,
    pub use_regexp: bool,
    pub match_width: bool,
    pub ignore_punctuation: bool,
    pub ignore_whitespace: bool,
}

impl Default for SearchOptionsDto {
    fn default() -> Self {
        let options = SearchOptions::default();
        Self {
            match_case: options.match_case,
            whole_word: options.whole_word,
            use_regexp: options.use_regexp,
            match_width: options.match_width,
            ignore_punctuation: options.ignore_punctuation,
            ignore_whitespace: options.ignore_whitespace,
        }
    }
}

impl From<SearchOptionsDto> for SearchOptions {
    fn from(value: SearchOptionsDto) -> Self {
        Self {
            match_case: value.match_case,
            whole_word: value.whole_word,
            use_regexp: value.use_regexp,
            match_width: value.match_width,
            ignore_punctuation: value.ignore_punctuation,
            ignore_whitespace: value.ignore_whitespace,
        }
    }
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct FillerRequestDto {
    pub dictionary_revision: u64,
    pub words: Vec<String>,
    #[serde(default)]
    pub budget: FillerBudgetDto,
}

impl From<FillerRequestDto> for FillerRequest {
    fn from(value: FillerRequestDto) -> Self {
        Self {
            dictionary_revision: value.dictionary_revision,
            words: value.words,
            budget: value.budget.into(),
        }
    }
}

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(default, rename_all = "camelCase", deny_unknown_fields)]
pub struct FillerBudgetDto {
    pub max_words: usize,
    pub max_positions_per_word: usize,
    pub max_positions_total: usize,
    pub max_annotations: usize,
    pub max_candidates: usize,
}

impl Default for FillerBudgetDto {
    fn default() -> Self {
        let budget = FillerBudget::default();
        Self {
            max_words: budget.max_words,
            max_positions_per_word: budget.max_positions_per_word,
            max_positions_total: budget.max_positions_total,
            max_annotations: budget.max_annotations,
            max_candidates: budget.max_candidates,
        }
    }
}

impl From<FillerBudgetDto> for FillerBudget {
    fn from(value: FillerBudgetDto) -> Self {
        Self {
            max_words: value.max_words,
            max_positions_per_word: value.max_positions_per_word,
            max_positions_total: value.max_positions_total,
            max_annotations: value.max_annotations,
            max_candidates: value.max_candidates,
        }
    }
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CloseDocumentArgs {
    pub document_id: String,
}

pub fn success_response(request_id: Option<u64>, result: Value) -> Vec<u8> {
    serialize_response(json!({
        "ok": true,
        "contractVersion": CONTRACT_VERSION,
        "requestId": request_id,
        "result": result,
    }))
}

pub fn error_response(request_id: Option<u64>, code: &str, message: &str) -> Vec<u8> {
    serialize_response(json!({
        "ok": false,
        "contractVersion": CONTRACT_VERSION,
        "requestId": request_id,
        "error": {
            "code": code,
            "message": message,
        },
    }))
}

fn serialize_response(value: Value) -> Vec<u8> {
    serde_json::to_vec(&value).unwrap_or_else(|_| {
        br#"{"ok":false,"contractVersion":1,"requestId":null,"error":{"code":"internal","message":"response serialization failed"}}"#.to_vec()
    })
}

pub fn handshake_value() -> Value {
    json!({
        "kind": "handshake",
        "abiVersion": crate::ABI_VERSION,
        "contractVersion": CONTRACT_VERSION,
        "capabilities": ["openDocument", "applyEdits", "analyzeSearch", "analyzeFiller", "analyzeExternalAnnotations", "compactAnalysisV1", "closeDocument"],
    })
}

pub fn render_plan_value(value: &VersionedRenderPlan) -> Value {
    json!({
        "documentId": value.document_id,
        "revision": value.revision,
        "plan": render_plan(&value.plan),
    })
}

pub fn compact_render_plan_value(value: &VersionedRenderPlan) -> Value {
    json!({
        "documentId": value.document_id,
        "revision": value.revision,
        "plan": {
            "contractVersion": value.plan.contract_version,
            "textLenUtf16": value.plan.text_len_utf16,
            "runsUtf16": value.plan.runs.iter().flat_map(|run| [
                run.range.start,
                run.range.end,
                run.style_token_set_id,
            ]).collect::<Vec<_>>(),
            "tokenSets": value.plan.token_sets.iter().map(style_value).collect::<Vec<_>>(),
        },
    })
}

fn render_plan(value: &RenderPlan) -> Value {
    json!({
        "contractVersion": value.contract_version,
        "textLenUtf16": value.text_len_utf16,
        "runs": value.runs.iter().map(|run| json!({
            "range": range_value(run.range),
            "styleTokenSetId": run.style_token_set_id,
            "annotationIds": run.annotation_ids,
        })).collect::<Vec<_>>(),
        "tokenSets": value.token_sets.iter().map(style_value).collect::<Vec<_>>(),
    })
}

pub fn search_result_value(value: &SearchResult) -> Value {
    json!({
        "totalMatches": value.total_matches,
        "truncated": value.truncated,
        "activeMatchId": value.active_match_id,
        "annotations": value.annotations.iter().map(annotation_value).collect::<Vec<_>>(),
    })
}

pub fn compact_search_result_value(value: &SearchResult) -> Value {
    json!({
        "totalMatches": value.total_matches,
        "truncated": value.truncated,
        "activeMatchId": value.active_match_id,
        "rangesUtf16": value.annotations.iter().flat_map(|annotation| [
            annotation.range.start,
            annotation.range.end,
        ]).collect::<Vec<_>>(),
    })
}

pub fn filler_result_value(value: &FillerResult) -> Value {
    json!({
        "totalMatches": value.total_matches,
        "effectiveChars": value.effective_chars,
        "ratio": value.ratio,
        "truncated": value.truncated,
        "hits": value.hits.iter().map(|hit| json!({
            "word": hit.word,
            "count": hit.count,
            "positions": hit.positions.iter().copied().map(range_value).collect::<Vec<_>>(),
        })).collect::<Vec<_>>(),
        "annotations": value.annotations.iter().map(annotation_value).collect::<Vec<_>>(),
    })
}

pub fn compact_filler_result_value(value: &FillerResult) -> Value {
    json!({
        "totalMatches": value.total_matches,
        "effectiveChars": value.effective_chars,
        "ratio": value.ratio,
        "truncated": value.truncated,
        "hits": value.hits.iter().map(|hit| json!({
            "word": hit.word,
            "count": hit.count,
        })).collect::<Vec<_>>(),
    })
}

fn annotation_value(value: &Annotation) -> Value {
    json!({
        "annotationId": value.annotation_id,
        "source": value.source,
        "sourceOrder": value.source_order,
        "ring": value.ring.priority(),
        "range": range_value(value.range),
        "style": style_value(&value.style),
        "payloadId": value.payload_id,
    })
}

fn range_value(value: Utf16Range) -> Value {
    json!({"start": value.start, "end": value.end})
}

fn style_value(value: &StylePatch) -> Value {
    json!({
        "foreground": value.foreground,
        "background": value.background,
        "weight": value.weight.map(weight_name),
        "slant": value.slant.map(slant_name),
        "decoration": value.decoration.as_ref().map(|decoration| json!({
            "lines": decoration.lines.iter().copied().map(decoration_line_name).collect::<Vec<_>>(),
            "style": decoration_style_name(decoration.style),
            "color": decoration.color,
            "thickness": decoration.thickness,
        })),
        "interaction": value.interaction,
    })
}

fn weight_name(value: FontWeight) -> &'static str {
    match value {
        FontWeight::Regular => "regular",
        FontWeight::Medium => "medium",
        FontWeight::Semibold => "semibold",
        FontWeight::Bold => "bold",
    }
}

fn slant_name(value: FontSlant) -> &'static str {
    match value {
        FontSlant::Normal => "normal",
        FontSlant::Italic => "italic",
    }
}

fn decoration_line_name(value: DecorationLine) -> &'static str {
    match value {
        DecorationLine::Underline => "underline",
        DecorationLine::Overline => "overline",
        DecorationLine::LineThrough => "lineThrough",
    }
}

fn decoration_style_name(value: DecorationStyle) -> &'static str {
    match value {
        DecorationStyle::Solid => "solid",
        DecorationStyle::Double => "double",
        DecorationStyle::Dotted => "dotted",
        DecorationStyle::Dashed => "dashed",
        DecorationStyle::Wavy => "wavy",
    }
}
