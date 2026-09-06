#![forbid(unsafe_code)]

mod filler;

pub use filler::{
    FillerBudget, FillerError, FillerHit, FillerMatcher, FillerRequest, FillerResult,
    DEFAULT_MAX_FILLER_ANNOTATIONS,
};

use std::collections::BTreeMap;
use std::error::Error;
use std::fmt;

use regex::Regex;
use rhodanthe_core::{
    Annotation, FontWeight, Revision, RhodantheEngine, RhodantheError, Ring, StylePatch,
    Utf16Range, VersionedRenderPlan,
};

pub const DEFAULT_MAX_SEARCH_RESULTS: usize = 2_048;
pub const DEFAULT_MAX_SEARCH_INPUT_CODE_UNITS: usize = 2 * 1024 * 1024;
pub const DEFAULT_MAX_REGEXP_CODE_UNITS: usize = 512;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct SearchOptions {
    pub match_case: bool,
    pub whole_word: bool,
    pub use_regexp: bool,
    pub match_width: bool,
    pub ignore_punctuation: bool,
    pub ignore_whitespace: bool,
}

impl Default for SearchOptions {
    fn default() -> Self {
        Self {
            match_case: true,
            whole_word: false,
            use_regexp: false,
            match_width: true,
            ignore_punctuation: false,
            ignore_whitespace: false,
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SearchRequest {
    pub query: String,
    pub query_revision: Revision,
    pub options: SearchOptions,
    pub max_results: usize,
    pub active_match_index: Option<usize>,
    pub max_input_code_units: usize,
    pub max_regexp_code_units: usize,
}

impl SearchRequest {
    pub fn new(query: String, query_revision: Revision) -> Self {
        Self {
            query,
            query_revision,
            options: SearchOptions::default(),
            max_results: DEFAULT_MAX_SEARCH_RESULTS,
            active_match_index: None,
            max_input_code_units: DEFAULT_MAX_SEARCH_INPUT_CODE_UNITS,
            max_regexp_code_units: DEFAULT_MAX_REGEXP_CODE_UNITS,
        }
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct SearchResult {
    pub annotations: Vec<Annotation>,
    pub total_matches: usize,
    pub truncated: bool,
    pub active_match_id: Option<String>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct DocumentSearchResult {
    pub search: SearchResult,
    pub render_plan: VersionedRenderPlan,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct DocumentAnalysisRequest {
    pub search: Option<SearchRequest>,
    pub filler: Option<FillerRequest>,
    pub external_annotations: Vec<Annotation>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct DocumentAnalysisResult {
    pub search: Option<SearchResult>,
    pub filler: Option<FillerResult>,
    pub render_plan: VersionedRenderPlan,
}

#[derive(Clone, Debug, PartialEq)]
pub enum SearchError {
    InvalidRegularExpression { message: String },
    RegularExpressionTooLong { actual: usize, max: usize },
    InputTooLong { actual: usize, max: usize },
    TextTooLong,
    Core(RhodantheError),
}

#[derive(Clone, Debug, PartialEq)]
pub enum AnalysisError {
    Search(SearchError),
    Filler(FillerError),
    Core(RhodantheError),
}

impl fmt::Display for SearchError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidRegularExpression { message } => {
                write!(formatter, "invalid regular expression: {message}")
            }
            Self::RegularExpressionTooLong { actual, max } => write!(
                formatter,
                "regular expression has {actual} UTF-16 code units; maximum is {max}"
            ),
            Self::InputTooLong { actual, max } => write!(
                formatter,
                "search input has {actual} UTF-16 code units; maximum is {max}"
            ),
            Self::TextTooLong => write!(formatter, "text exceeds the UTF-16 u32 range"),
            Self::Core(error) => write!(formatter, "{error}"),
        }
    }
}

impl Error for SearchError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            Self::Core(error) => Some(error),
            _ => None,
        }
    }
}

impl fmt::Display for AnalysisError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Search(error) => write!(formatter, "{error}"),
            Self::Filler(error) => write!(formatter, "{error}"),
            Self::Core(error) => write!(formatter, "{error}"),
        }
    }
}

impl Error for AnalysisError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self {
            Self::Search(error) => Some(error),
            Self::Filler(error) => Some(error),
            Self::Core(error) => Some(error),
        }
    }
}

impl From<RhodantheError> for SearchError {
    fn from(value: RhodantheError) -> Self {
        Self::Core(value)
    }
}

impl From<SearchError> for AnalysisError {
    fn from(value: SearchError) -> Self {
        Self::Search(value)
    }
}

impl From<FillerError> for AnalysisError {
    fn from(value: FillerError) -> Self {
        Self::Filler(value)
    }
}

impl From<RhodantheError> for AnalysisError {
    fn from(value: RhodantheError) -> Self {
        Self::Core(value)
    }
}

pub fn analyze_document(
    engine: &RhodantheEngine,
    document_id: &str,
    revision: Revision,
    request: &DocumentAnalysisRequest,
) -> Result<DocumentAnalysisResult, AnalysisError> {
    let filler_matcher = request
        .filler
        .as_ref()
        .map(|filler| FillerMatcher::new(filler.dictionary_revision, &filler.words))
        .transpose()?;
    analyze_document_with_filler_matcher(
        engine,
        document_id,
        revision,
        request,
        filler_matcher.as_ref(),
    )
}

pub fn analyze_document_with_filler_matcher(
    engine: &RhodantheEngine,
    document_id: &str,
    revision: Revision,
    request: &DocumentAnalysisRequest,
    filler_matcher: Option<&FillerMatcher>,
) -> Result<DocumentAnalysisResult, AnalysisError> {
    let current_revision = engine.document_revision(document_id)?;
    if current_revision != revision {
        return Err(RhodantheError::RevisionMismatch {
            document_id: document_id.to_owned(),
            expected: current_revision,
            actual: revision,
        }
        .into());
    }
    let text = engine.document_text(document_id)?;
    let search = request
        .search
        .as_ref()
        .map(|search| analyze_search(text, search))
        .transpose()?;
    let filler = request
        .filler
        .as_ref()
        .map(|filler| {
            if let Some(matcher) = filler_matcher {
                if matcher.dictionary_revision() == filler.dictionary_revision {
                    return matcher.analyze(text, filler.budget);
                }
            }
            FillerMatcher::new(filler.dictionary_revision, &filler.words)?
                .analyze(text, filler.budget)
        })
        .transpose()?;

    let mut annotations = Vec::new();
    if let Some(search) = &search {
        annotations.extend(search.annotations.iter().cloned());
    }
    if let Some(filler) = &filler {
        annotations.extend(filler.annotations.iter().cloned());
    }
    annotations.extend(request.external_annotations.iter().cloned());
    let render_plan = engine.analyze(document_id, revision, &annotations)?;
    Ok(DocumentAnalysisResult {
        search,
        filler,
        render_plan,
    })
}

pub fn analyze_document_search(
    engine: &RhodantheEngine,
    document_id: &str,
    revision: Revision,
    request: &SearchRequest,
) -> Result<DocumentSearchResult, SearchError> {
    let current_revision = engine.document_revision(document_id)?;
    if current_revision != revision {
        return Err(RhodantheError::RevisionMismatch {
            document_id: document_id.to_owned(),
            expected: current_revision,
            actual: revision,
        }
        .into());
    }

    let search = analyze_search(engine.document_text(document_id)?, request)?;
    let render_plan = engine.analyze(document_id, revision, &search.annotations)?;
    Ok(DocumentSearchResult {
        search,
        render_plan,
    })
}

pub fn analyze_search(text: &str, request: &SearchRequest) -> Result<SearchResult, SearchError> {
    if request.options.use_regexp {
        return analyze_regexp_search(text, request);
    }

    let normalized_text = normalize_with_offsets(text, request.options)?;
    let normalized_query = normalize_with_offsets(&request.query, request.options)?.value;
    if normalized_query.is_empty() {
        return Ok(SearchResult {
            annotations: Vec::new(),
            total_matches: 0,
            truncated: false,
            active_match_id: None,
        });
    }

    let mut accumulator = SearchAccumulator::new(request);

    for (normalized_start, _) in normalized_text.value.match_indices(&normalized_query) {
        let normalized_end = normalized_start + normalized_query.len();
        let Some(original_range) = normalized_text.original_range(normalized_start, normalized_end)
        else {
            continue;
        };
        if request.options.whole_word
            && !is_whole_word(text, original_range.start_byte, original_range.end_byte)
        {
            continue;
        }

        accumulator.push(original_range.utf16)?;
    }

    Ok(accumulator.finish())
}

fn analyze_regexp_search(text: &str, request: &SearchRequest) -> Result<SearchResult, SearchError> {
    let query_code_units = request.query.encode_utf16().count();
    if query_code_units > request.max_regexp_code_units {
        return Err(SearchError::RegularExpressionTooLong {
            actual: query_code_units,
            max: request.max_regexp_code_units,
        });
    }
    let input_code_units = text.encode_utf16().count();
    if input_code_units > request.max_input_code_units {
        return Err(SearchError::InputTooLong {
            actual: input_code_units,
            max: request.max_input_code_units,
        });
    }
    if request.query.is_empty() {
        return Ok(SearchAccumulator::new(request).finish());
    }

    let regexp =
        Regex::new(&request.query).map_err(|error| SearchError::InvalidRegularExpression {
            message: error.to_string(),
        })?;
    let boundaries = utf16_boundaries(text)?;
    let mut accumulator = SearchAccumulator::new(request);
    for matched in regexp.find_iter(text) {
        // Rhodanthe ranges must be non-empty. This also preserves the current
        // Dart highlighter contract for patterns such as `^`, `$` and `a*`.
        if matched.is_empty() {
            continue;
        }
        let start = *boundaries
            .get(&matched.start())
            .expect("regex matches always start on a UTF-8 character boundary");
        let end = *boundaries
            .get(&matched.end())
            .expect("regex matches always end on a UTF-8 character boundary");
        accumulator.push(Utf16Range::new(start, end))?;
    }
    Ok(accumulator.finish())
}

fn utf16_boundaries(text: &str) -> Result<BTreeMap<usize, u32>, SearchError> {
    let mut boundaries = BTreeMap::from([(0, 0)]);
    let mut utf16_offset = 0_u32;
    for (byte_start, character) in text.char_indices() {
        let width = u32::try_from(character.len_utf16()).map_err(|_| SearchError::TextTooLong)?;
        utf16_offset = utf16_offset
            .checked_add(width)
            .ok_or(SearchError::TextTooLong)?;
        boundaries.insert(byte_start + character.len_utf8(), utf16_offset);
    }
    Ok(boundaries)
}

struct SearchAccumulator {
    query_revision: Revision,
    max_results: usize,
    active_match_index: Option<usize>,
    annotations: Vec<Annotation>,
    total_matches: usize,
    active_match_id: Option<String>,
}

impl SearchAccumulator {
    fn new(request: &SearchRequest) -> Self {
        Self {
            query_revision: request.query_revision,
            max_results: request.max_results,
            active_match_index: request.active_match_index,
            annotations: Vec::with_capacity(request.max_results.min(64)),
            total_matches: 0,
            active_match_id: None,
        }
    }

    fn push(&mut self, range: Utf16Range) -> Result<(), SearchError> {
        let match_index = self.total_matches;
        self.total_matches = self
            .total_matches
            .checked_add(1)
            .ok_or(SearchError::TextTooLong)?;
        let is_active = self.active_match_index == Some(match_index);
        let annotation = search_annotation(self.query_revision, match_index, range, is_active);

        if is_active {
            self.active_match_id = Some(annotation.annotation_id.clone());
        }
        if self.annotations.len() < self.max_results {
            self.annotations.push(annotation);
        } else if is_active && self.max_results > 0 {
            self.annotations[self.max_results - 1] = annotation;
        }
        Ok(())
    }

    fn finish(self) -> SearchResult {
        SearchResult {
            truncated: self.total_matches > self.annotations.len(),
            annotations: self.annotations,
            total_matches: self.total_matches,
            active_match_id: self.active_match_id,
        }
    }
}

fn search_annotation(
    query_revision: Revision,
    match_index: usize,
    range: Utf16Range,
    is_active: bool,
) -> Annotation {
    let annotation_id = format!("search:{query_revision}:{match_index}");
    let style = if is_active {
        StylePatch {
            foreground: Some("search.current.foreground".to_owned()),
            background: Some("search.current.background".to_owned()),
            weight: Some(FontWeight::Semibold),
            ..StylePatch::default()
        }
    } else {
        StylePatch {
            background: Some("search.match.background".to_owned()),
            ..StylePatch::default()
        }
    };
    Annotation {
        annotation_id: annotation_id.clone(),
        source: "search".to_owned(),
        source_order: 0,
        ring: if is_active {
            Ring::Critical
        } else {
            Ring::Search
        },
        range,
        style,
        payload_id: Some(annotation_id),
    }
}

#[derive(Clone, Copy, Debug)]
struct OriginalBoundary {
    utf16: u32,
    byte: usize,
}

#[derive(Debug)]
struct OriginalRange {
    utf16: Utf16Range,
    start_byte: usize,
    end_byte: usize,
}

#[derive(Debug)]
struct NormalizedText {
    value: String,
    boundaries: Vec<(usize, OriginalBoundary)>,
    direct_ascii_offsets: bool,
}

impl NormalizedText {
    fn original_range(&self, start: usize, end: usize) -> Option<OriginalRange> {
        if self.direct_ascii_offsets {
            return Some(OriginalRange {
                utf16: Utf16Range::new(u32::try_from(start).ok()?, u32::try_from(end).ok()?),
                start_byte: start,
                end_byte: end,
            });
        }
        let start_index = self
            .boundaries
            .binary_search_by_key(&start, |(offset, _)| *offset)
            .ok()?;
        let end_index = self
            .boundaries
            .binary_search_by_key(&end, |(offset, _)| *offset)
            .ok()?;
        let start = &self.boundaries[start_index].1;
        let end = &self.boundaries[end_index].1;
        Some(OriginalRange {
            utf16: Utf16Range::new(start.utf16, end.utf16),
            start_byte: start.byte,
            end_byte: end.byte,
        })
    }
}

fn normalize_with_offsets(
    text: &str,
    options: SearchOptions,
) -> Result<NormalizedText, SearchError> {
    if text.is_ascii() && !options.ignore_punctuation && !options.ignore_whitespace {
        let value = if options.match_case {
            text.to_owned()
        } else {
            text.chars().map(normalize_case).collect()
        };
        return Ok(NormalizedText {
            value,
            boundaries: Vec::new(),
            direct_ascii_offsets: true,
        });
    }

    let mut value = String::with_capacity(text.len());
    let mut boundaries = vec![(0, OriginalBoundary { utf16: 0, byte: 0 })];
    let mut utf16_start = 0_u32;

    for (byte_start, character) in text.char_indices() {
        let width = u32::try_from(character.len_utf16()).map_err(|_| SearchError::TextTooLong)?;
        let utf16_end = utf16_start
            .checked_add(width)
            .ok_or(SearchError::TextTooLong)?;
        let byte_end = byte_start + character.len_utf8();

        if should_ignore(character, options) {
            utf16_start = utf16_end;
            continue;
        }

        let normalized_start = value.len();
        let has_boundary =
            matches!(boundaries.last(), Some((offset, _)) if *offset == normalized_start);
        if !has_boundary {
            boundaries.push((
                normalized_start,
                OriginalBoundary {
                    utf16: utf16_start,
                    byte: byte_start,
                },
            ));
        }

        let case_normalized = if options.match_case {
            character
        } else {
            normalize_case(character)
        };
        if options.match_width {
            value.push(case_normalized);
        } else {
            value.push_str(&normalize_width(case_normalized));
        }

        boundaries.push((
            value.len(),
            OriginalBoundary {
                utf16: utf16_end,
                byte: byte_end,
            },
        ));
        utf16_start = utf16_end;
    }

    Ok(NormalizedText {
        value,
        boundaries,
        direct_ascii_offsets: false,
    })
}

fn should_ignore(character: char, options: SearchOptions) -> bool {
    (options.ignore_punctuation && is_punctuation(character))
        || (options.ignore_whitespace && character.is_whitespace())
}

fn is_punctuation(character: char) -> bool {
    character.is_ascii_punctuation()
        || matches!(
            character,
            '、' | '。'
                | '，'
                | '！'
                | '？'
                | '；'
                | '：'
                | '「'
                | '」'
                | '『'
                | '』'
                | '（'
                | '）'
                | '《'
                | '》'
                | '〈'
                | '〉'
                | '【'
                | '】'
                | '〔'
                | '〕'
                | '…'
                | '—'
                | '～'
                | '·'
                | '．'
                | '｜'
                | '／'
                | '－'
                | '＿'
                | '＼'
        )
}

fn is_whole_word(text: &str, start_byte: usize, end_byte: usize) -> bool {
    let previous_is_word = text[..start_byte]
        .chars()
        .next_back()
        .is_some_and(is_word_character);
    let next_is_word = text[end_byte..]
        .chars()
        .next()
        .is_some_and(is_word_character);
    !previous_is_word && !next_is_word
}

fn is_word_character(character: char) -> bool {
    let code = character as u32;
    (0x0030..=0x0039).contains(&code)
        || (0x0041..=0x005A).contains(&code)
        || (0x0061..=0x007A).contains(&code)
        || (0x00C0..=0x00FF).contains(&code)
        || code == 0x005F
}

fn normalize_case(character: char) -> char {
    let code = character as u32;
    let normalized = if (0x0041..=0x005A).contains(&code)
        || ((0x00C0..=0x00DE).contains(&code) && code != 0x00D7)
        || (0x0391..=0x03A9).contains(&code)
        || (0x0410..=0x042F).contains(&code)
        || (0xFF21..=0xFF3A).contains(&code)
    {
        code + 32
    } else if code == 0x0386 {
        0x03AC
    } else if (0x0388..=0x038A).contains(&code) {
        code + 37
    } else if code == 0x038C {
        0x03CC
    } else if (0x038E..=0x038F).contains(&code) {
        code + 63
    } else if (0x0100..=0x017F).contains(&code) && code % 2 == 0 {
        code + 1
    } else {
        code
    };
    char::from_u32(normalized).unwrap_or(character)
}

fn normalize_width(character: char) -> String {
    let code = character as u32;
    if (0xFF01..=0xFF5E).contains(&code) {
        return char::from_u32(code - 0xFEE0)
            .unwrap_or(character)
            .to_string();
    }
    if code == 0x3000 {
        return " ".to_owned();
    }
    if (0x30A1..=0x30FE).contains(&code) {
        return full_katakana_to_half(character)
            .map(str::to_owned)
            .unwrap_or_else(|| character.to_string());
    }
    if (0xFF61..=0xFF9F).contains(&code) {
        return character.to_string();
    }
    if (0x3041..=0x309F).contains(&code) {
        let katakana = char::from_u32(code + 0x60).unwrap_or(character);
        return full_katakana_to_half(katakana)
            .map(str::to_owned)
            .unwrap_or_else(|| katakana.to_string());
    }
    match character {
        '、' => ",".to_owned(),
        '。' => ".".to_owned(),
        '「' | '」' => "\"".to_owned(),
        '『' | '』' => "'".to_owned(),
        '〔' => "[".to_owned(),
        '〕' => "]".to_owned(),
        _ => character.to_string(),
    }
}

fn full_katakana_to_half(character: char) -> Option<&'static str> {
    match character {
        'ァ' => Some("ｧ"),
        'ア' => Some("ｱ"),
        'ィ' => Some("ｨ"),
        'イ' => Some("ｲ"),
        'ゥ' => Some("ｩ"),
        'ウ' => Some("ｳ"),
        'ェ' => Some("ｪ"),
        'エ' => Some("ｴ"),
        'ォ' => Some("ｫ"),
        'オ' => Some("ｵ"),
        'カ' => Some("ｶ"),
        'ガ' => Some("ｶﾞ"),
        'キ' => Some("ｷ"),
        'ギ' => Some("ｷﾞ"),
        'ク' => Some("ｸ"),
        'グ' => Some("ｸﾞ"),
        'ケ' => Some("ｹ"),
        'ゲ' => Some("ｹﾞ"),
        'コ' => Some("ｺ"),
        'ゴ' => Some("ｺﾞ"),
        'サ' => Some("ｻ"),
        'ザ' => Some("ｻﾞ"),
        'シ' => Some("ｼ"),
        'ジ' => Some("ｼﾞ"),
        'ス' => Some("ｽ"),
        'ズ' => Some("ｽﾞ"),
        'セ' => Some("ｾ"),
        'ゼ' => Some("ｾﾞ"),
        'ソ' => Some("ｿ"),
        'ゾ' => Some("ｿﾞ"),
        'タ' => Some("ﾀ"),
        'ダ' => Some("ﾀﾞ"),
        'チ' => Some("ﾁ"),
        'ヂ' => Some("ﾁﾞ"),
        'ッ' => Some("ｯ"),
        'ツ' => Some("ﾂ"),
        'ヅ' => Some("ﾂﾞ"),
        'テ' => Some("ﾃ"),
        'デ' => Some("ﾃﾞ"),
        'ト' => Some("ﾄ"),
        'ド' => Some("ﾄﾞ"),
        'ナ' => Some("ﾅ"),
        'ニ' => Some("ﾆ"),
        'ヌ' => Some("ﾇ"),
        'ネ' => Some("ﾈ"),
        'ノ' => Some("ﾉ"),
        'ハ' => Some("ﾊ"),
        'バ' => Some("ﾊﾞ"),
        'パ' => Some("ﾊﾟ"),
        'ヒ' => Some("ﾋ"),
        'ビ' => Some("ﾋﾞ"),
        'ピ' => Some("ﾋﾟ"),
        'フ' => Some("ﾌ"),
        'ブ' => Some("ﾌﾞ"),
        'プ' => Some("ﾌﾟ"),
        'ヘ' => Some("ﾍ"),
        'ベ' => Some("ﾍﾞ"),
        'ペ' => Some("ﾍﾟ"),
        'ホ' => Some("ﾎ"),
        'ボ' => Some("ﾎﾞ"),
        'ポ' => Some("ﾎﾟ"),
        'マ' => Some("ﾏ"),
        'ミ' => Some("ﾐ"),
        'ム' => Some("ﾑ"),
        'メ' => Some("ﾒ"),
        'モ' => Some("ﾓ"),
        'ャ' => Some("ｬ"),
        'ヤ' => Some("ﾔ"),
        'ュ' => Some("ｭ"),
        'ユ' => Some("ﾕ"),
        'ョ' => Some("ｮ"),
        'ヨ' => Some("ﾖ"),
        'ラ' => Some("ﾗ"),
        'リ' => Some("ﾘ"),
        'ル' => Some("ﾙ"),
        'レ' => Some("ﾚ"),
        'ロ' => Some("ﾛ"),
        'ヮ' | 'ワ' => Some("ﾜ"),
        'ヰ' => Some("ｲ"),
        'ヱ' => Some("ｴ"),
        'ヲ' => Some("ｦ"),
        'ン' => Some("ﾝ"),
        'ヴ' => Some("ｳﾞ"),
        'ヵ' => Some("ｶ"),
        'ヶ' => Some("ｹ"),
        '・' => Some("･"),
        'ー' => Some("ｰ"),
        _ => None,
    }
}
