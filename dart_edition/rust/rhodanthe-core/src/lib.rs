#![forbid(unsafe_code)]

use std::cmp::Ordering;
use std::collections::{BTreeMap, BTreeSet};
use std::error::Error;
use std::fmt;

pub const CONTRACT_VERSION: u16 = 1;
pub type Revision = u64;

#[derive(Clone, Copy, Debug, Eq, Hash, Ord, PartialEq, PartialOrd)]
#[repr(u8)]
pub enum Ring {
    Critical = 0,
    Search = 2,
    Mention = 4,
    Filler = 6,
    Diagnostic = 8,
}

impl Ring {
    pub const fn priority(self) -> u8 {
        self as u8
    }
}

impl TryFrom<u8> for Ring {
    type Error = RhodantheError;

    fn try_from(value: u8) -> Result<Self, Self::Error> {
        match value {
            0 => Ok(Self::Critical),
            2 => Ok(Self::Search),
            4 => Ok(Self::Mention),
            6 => Ok(Self::Filler),
            8 => Ok(Self::Diagnostic),
            1 | 3 | 5 | 7 => Err(RhodantheError::ReservedRing(value)),
            _ => Err(RhodantheError::UnknownRing(value)),
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct Utf16Range {
    pub start: u32,
    pub end: u32,
}

impl Utf16Range {
    pub const fn new(start: u32, end: u32) -> Self {
        Self { start, end }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum FontWeight {
    Regular,
    Medium,
    Semibold,
    Bold,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum FontSlant {
    Normal,
    Italic,
}

#[derive(Clone, Copy, Debug, Eq, Ord, PartialEq, PartialOrd)]
pub enum DecorationLine {
    Underline,
    Overline,
    LineThrough,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum DecorationStyle {
    Solid,
    Double,
    Dotted,
    Dashed,
    Wavy,
}

#[derive(Clone, Debug, PartialEq)]
pub struct DecorationSpec {
    pub lines: Vec<DecorationLine>,
    pub style: DecorationStyle,
    pub color: String,
    pub thickness: f32,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct StylePatch {
    pub foreground: Option<String>,
    pub background: Option<String>,
    pub weight: Option<FontWeight>,
    pub slant: Option<FontSlant>,
    pub decoration: Option<DecorationSpec>,
    pub interaction: Option<String>,
}

impl StylePatch {
    pub fn is_empty(&self) -> bool {
        self.foreground.is_none()
            && self.background.is_none()
            && self.weight.is_none()
            && self.slant.is_none()
            && self.decoration.is_none()
            && self.interaction.is_none()
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct Annotation {
    pub annotation_id: String,
    pub source: String,
    pub source_order: u32,
    pub ring: Ring,
    pub range: Utf16Range,
    pub style: StylePatch,
    pub payload_id: Option<String>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RenderRun {
    pub range: Utf16Range,
    pub style_token_set_id: u32,
    pub annotation_ids: Vec<String>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct RenderPlan {
    pub contract_version: u16,
    pub text_len_utf16: u32,
    pub runs: Vec<RenderRun>,
    pub token_sets: Vec<StylePatch>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TextEdit {
    pub range: Utf16Range,
    pub replacement: String,
}

#[derive(Clone, Debug, PartialEq)]
pub struct VersionedRenderPlan {
    pub document_id: String,
    pub revision: Revision,
    pub plan: RenderPlan,
}

#[derive(Clone, Debug, Eq, PartialEq)]
struct DocumentState {
    revision: Revision,
    text: String,
}

#[derive(Debug, Default)]
pub struct RhodantheEngine {
    documents: BTreeMap<String, DocumentState>,
}

#[derive(Clone, Debug, PartialEq)]
pub enum RhodantheError {
    ReservedRing(u8),
    UnknownRing(u8),
    TextTooLong,
    EmptyAnnotationId {
        annotation_index: usize,
    },
    EmptyStyle {
        annotation_id: String,
    },
    EmptySemanticToken {
        annotation_id: String,
        channel: &'static str,
    },
    InvalidRange {
        annotation_id: String,
        range: Utf16Range,
        text_len_utf16: u32,
    },
    SplitsSurrogatePair {
        annotation_id: String,
        offset: u32,
    },
    EmptyDecorationLines {
        annotation_id: String,
    },
    InvalidDecorationThickness {
        annotation_id: String,
        thickness: f32,
    },
    EmptyDocumentId,
    DocumentAlreadyOpen {
        document_id: String,
    },
    DocumentNotOpen {
        document_id: String,
    },
    RevisionMismatch {
        document_id: String,
        expected: Revision,
        actual: Revision,
    },
    NonIncreasingRevision {
        base: Revision,
        next: Revision,
    },
    InvalidEditRange {
        edit_index: usize,
        range: Utf16Range,
        text_len_utf16: u32,
    },
    EditSplitsSurrogatePair {
        edit_index: usize,
        offset: u32,
    },
    EditsNotSorted {
        previous_index: usize,
        edit_index: usize,
    },
    OverlappingEdits {
        previous_index: usize,
        edit_index: usize,
    },
    TooManyTokenSets,
}

impl fmt::Display for RhodantheError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::ReservedRing(ring) => write!(formatter, "Ring {ring} is reserved"),
            Self::UnknownRing(ring) => write!(formatter, "Ring {ring} is outside 0..=8"),
            Self::TextTooLong => write!(formatter, "text exceeds the UTF-16 u32 range"),
            Self::EmptyAnnotationId { annotation_index } => {
                write!(formatter, "annotation {annotation_index} has an empty id")
            }
            Self::EmptyStyle { annotation_id } => {
                write!(
                    formatter,
                    "annotation {annotation_id} has no style channels"
                )
            }
            Self::EmptySemanticToken {
                annotation_id,
                channel,
            } => write!(
                formatter,
                "annotation {annotation_id} has an empty {channel} token"
            ),
            Self::InvalidRange {
                annotation_id,
                range,
                text_len_utf16,
            } => write!(
                formatter,
                "annotation {annotation_id} has invalid UTF-16 range {}..{} for text length {}",
                range.start, range.end, text_len_utf16
            ),
            Self::SplitsSurrogatePair {
                annotation_id,
                offset,
            } => write!(
                formatter,
                "annotation {annotation_id} splits a surrogate pair at UTF-16 offset {offset}"
            ),
            Self::EmptyDecorationLines { annotation_id } => write!(
                formatter,
                "annotation {annotation_id} has a decoration without any lines"
            ),
            Self::InvalidDecorationThickness {
                annotation_id,
                thickness,
            } => write!(
                formatter,
                "annotation {annotation_id} has invalid decoration thickness {thickness}"
            ),
            Self::EmptyDocumentId => write!(formatter, "document id must not be empty"),
            Self::DocumentAlreadyOpen { document_id } => {
                write!(formatter, "document {document_id} is already open")
            }
            Self::DocumentNotOpen { document_id } => {
                write!(formatter, "document {document_id} is not open")
            }
            Self::RevisionMismatch {
                document_id,
                expected,
                actual,
            } => write!(
                formatter,
                "document {document_id} revision mismatch: expected {expected}, got {actual}"
            ),
            Self::NonIncreasingRevision { base, next } => write!(
                formatter,
                "new revision {next} must be greater than base revision {base}"
            ),
            Self::InvalidEditRange {
                edit_index,
                range,
                text_len_utf16,
            } => write!(
                formatter,
                "edit {edit_index} has invalid UTF-16 range {}..{} for text length {}",
                range.start, range.end, text_len_utf16
            ),
            Self::EditSplitsSurrogatePair { edit_index, offset } => write!(
                formatter,
                "edit {edit_index} splits a surrogate pair at UTF-16 offset {offset}"
            ),
            Self::EditsNotSorted {
                previous_index,
                edit_index,
            } => write!(
                formatter,
                "edit {edit_index} is ordered before edit {previous_index}"
            ),
            Self::OverlappingEdits {
                previous_index,
                edit_index,
            } => write!(
                formatter,
                "edit {edit_index} overlaps edit {previous_index} in base revision coordinates"
            ),
            Self::TooManyTokenSets => write!(formatter, "render plan has more than u32 token sets"),
        }
    }
}

impl Error for RhodantheError {}

impl RhodantheEngine {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn open_document(
        &mut self,
        document_id: String,
        revision: Revision,
        text: String,
    ) -> Result<(), RhodantheError> {
        if document_id.is_empty() {
            return Err(RhodantheError::EmptyDocumentId);
        }
        if self.documents.contains_key(&document_id) {
            return Err(RhodantheError::DocumentAlreadyOpen { document_id });
        }
        utf16_index(&text)?;
        self.documents
            .insert(document_id, DocumentState { revision, text });
        Ok(())
    }

    pub fn apply_edits(
        &mut self,
        document_id: &str,
        base_revision: Revision,
        revision: Revision,
        edits: &[TextEdit],
    ) -> Result<(), RhodantheError> {
        let state = self.document(document_id)?;
        ensure_revision(document_id, state.revision, base_revision)?;
        if revision <= base_revision {
            return Err(RhodantheError::NonIncreasingRevision {
                base: base_revision,
                next: revision,
            });
        }

        let updated_text = apply_text_edits(&state.text, edits)?;
        let state =
            self.documents
                .get_mut(document_id)
                .ok_or_else(|| RhodantheError::DocumentNotOpen {
                    document_id: document_id.to_owned(),
                })?;
        state.text = updated_text;
        state.revision = revision;
        Ok(())
    }

    pub fn analyze(
        &self,
        document_id: &str,
        revision: Revision,
        annotations: &[Annotation],
    ) -> Result<VersionedRenderPlan, RhodantheError> {
        let state = self.document(document_id)?;
        ensure_revision(document_id, state.revision, revision)?;
        Ok(VersionedRenderPlan {
            document_id: document_id.to_owned(),
            revision,
            plan: build_render_plan(&state.text, annotations)?,
        })
    }

    pub fn close_document(&mut self, document_id: &str) -> Result<(), RhodantheError> {
        if self.documents.remove(document_id).is_none() {
            return Err(RhodantheError::DocumentNotOpen {
                document_id: document_id.to_owned(),
            });
        }
        Ok(())
    }

    pub fn document_revision(&self, document_id: &str) -> Result<Revision, RhodantheError> {
        Ok(self.document(document_id)?.revision)
    }

    pub fn document_text(&self, document_id: &str) -> Result<&str, RhodantheError> {
        Ok(&self.document(document_id)?.text)
    }

    fn document(&self, document_id: &str) -> Result<&DocumentState, RhodantheError> {
        self.documents
            .get(document_id)
            .ok_or_else(|| RhodantheError::DocumentNotOpen {
                document_id: document_id.to_owned(),
            })
    }
}

fn ensure_revision(
    document_id: &str,
    expected: Revision,
    actual: Revision,
) -> Result<(), RhodantheError> {
    if expected != actual {
        return Err(RhodantheError::RevisionMismatch {
            document_id: document_id.to_owned(),
            expected,
            actual,
        });
    }
    Ok(())
}

fn apply_text_edits(text: &str, edits: &[TextEdit]) -> Result<String, RhodantheError> {
    let index = utf16_index(text)?;
    validate_edits(edits, &index)?;

    let mut updated = text.to_owned();
    for edit in edits.iter().rev() {
        let start = index.byte_offset(edit.range.start);
        let end = index.byte_offset(edit.range.end);
        updated.replace_range(start..end, &edit.replacement);
    }
    Ok(updated)
}

fn validate_edits(edits: &[TextEdit], index: &Utf16Index) -> Result<(), RhodantheError> {
    for (edit_index, edit) in edits.iter().enumerate() {
        if edit.range.start > edit.range.end || edit.range.end > index.text_len_utf16 {
            return Err(RhodantheError::InvalidEditRange {
                edit_index,
                range: edit.range,
                text_len_utf16: index.text_len_utf16,
            });
        }
        for offset in [edit.range.start, edit.range.end] {
            if !index.byte_offsets.contains_key(&offset) {
                return Err(RhodantheError::EditSplitsSurrogatePair { edit_index, offset });
            }
        }

        if edit_index == 0 {
            continue;
        }
        let previous_index = edit_index - 1;
        let previous = &edits[previous_index];
        if previous.range.start > edit.range.start {
            return Err(RhodantheError::EditsNotSorted {
                previous_index,
                edit_index,
            });
        }
        if previous.range.end > edit.range.start || previous.range.start == edit.range.start {
            return Err(RhodantheError::OverlappingEdits {
                previous_index,
                edit_index,
            });
        }
    }
    Ok(())
}

pub fn build_render_plan(
    text: &str,
    annotations: &[Annotation],
) -> Result<RenderPlan, RhodantheError> {
    let (text_len_utf16, valid_offsets) = utf16_boundaries(text, annotations)?;
    let normalized = normalize_annotations(annotations, text_len_utf16, &valid_offsets)?;

    if normalized.is_empty() {
        return Ok(RenderPlan {
            contract_version: CONTRACT_VERSION,
            text_len_utf16,
            runs: Vec::new(),
            token_sets: Vec::new(),
        });
    }

    let mut boundaries = BTreeSet::from([0, text_len_utf16]);
    let mut starts: BTreeMap<u32, Vec<usize>> = BTreeMap::new();
    let mut ends: BTreeMap<u32, Vec<usize>> = BTreeMap::new();
    for (index, annotation) in normalized.iter().enumerate() {
        boundaries.insert(annotation.range.start);
        boundaries.insert(annotation.range.end);
        starts
            .entry(annotation.range.start)
            .or_default()
            .push(index);
        ends.entry(annotation.range.end).or_default().push(index);
    }
    let boundaries: Vec<u32> = boundaries.into_iter().collect();

    let mut runs: Vec<RenderRun> = Vec::new();
    let mut token_sets: Vec<StylePatch> = Vec::new();
    let mut active_indices: BTreeSet<usize> = BTreeSet::new();

    for boundary_pair in boundaries.windows(2) {
        let range = Utf16Range::new(boundary_pair[0], boundary_pair[1]);
        if range.start == range.end {
            continue;
        }

        if let Some(indices) = ends.get(&range.start) {
            for index in indices {
                active_indices.remove(index);
            }
        }
        if let Some(indices) = starts.get(&range.start) {
            active_indices.extend(indices);
        }
        let active: Vec<&Annotation> = active_indices
            .iter()
            .map(|index| &normalized[*index])
            .collect();
        if active.is_empty() {
            continue;
        }

        let (resolved_style, annotation_ids) = resolve_style(&active);
        if resolved_style.is_empty() {
            continue;
        }

        let style_token_set_id = match token_sets
            .iter()
            .position(|candidate| candidate == &resolved_style)
        {
            Some(index) => u32::try_from(index).map_err(|_| RhodantheError::TooManyTokenSets)?,
            None => {
                let index = u32::try_from(token_sets.len())
                    .map_err(|_| RhodantheError::TooManyTokenSets)?;
                token_sets.push(resolved_style);
                index
            }
        };

        if let Some(previous) = runs.last_mut() {
            if previous.range.end == range.start
                && previous.style_token_set_id == style_token_set_id
                && previous.annotation_ids == annotation_ids
            {
                previous.range.end = range.end;
                continue;
            }
        }

        runs.push(RenderRun {
            range,
            style_token_set_id,
            annotation_ids,
        });
    }

    Ok(RenderPlan {
        contract_version: CONTRACT_VERSION,
        text_len_utf16,
        runs,
        token_sets,
    })
}

#[derive(Debug)]
struct Utf16Index {
    text_len_utf16: u32,
    byte_offsets: BTreeMap<u32, usize>,
}

impl Utf16Index {
    fn byte_offset(&self, utf16_offset: u32) -> usize {
        self.byte_offsets[&utf16_offset]
    }
}

fn utf16_index(text: &str) -> Result<Utf16Index, RhodantheError> {
    let mut offset = 0_u32;
    let mut byte_offsets = BTreeMap::from([(offset, 0)]);
    for (byte_offset, character) in text.char_indices() {
        byte_offsets.insert(offset, byte_offset);
        let width =
            u32::try_from(character.len_utf16()).map_err(|_| RhodantheError::TextTooLong)?;
        offset = offset
            .checked_add(width)
            .ok_or(RhodantheError::TextTooLong)?;
    }
    byte_offsets.insert(offset, text.len());
    Ok(Utf16Index {
        text_len_utf16: offset,
        byte_offsets,
    })
}

fn utf16_boundaries(
    text: &str,
    annotations: &[Annotation],
) -> Result<(u32, BTreeSet<u32>), RhodantheError> {
    let requested: BTreeSet<u32> = annotations
        .iter()
        .flat_map(|annotation| [annotation.range.start, annotation.range.end])
        .collect();
    let mut valid = BTreeSet::new();
    let mut offset = 0_u32;
    if requested.contains(&offset) {
        valid.insert(offset);
    }
    for character in text.chars() {
        let width =
            u32::try_from(character.len_utf16()).map_err(|_| RhodantheError::TextTooLong)?;
        offset = offset
            .checked_add(width)
            .ok_or(RhodantheError::TextTooLong)?;
        if requested.contains(&offset) {
            valid.insert(offset);
        }
    }
    Ok((offset, valid))
}

fn normalize_annotations(
    annotations: &[Annotation],
    text_len_utf16: u32,
    valid_offsets: &BTreeSet<u32>,
) -> Result<Vec<Annotation>, RhodantheError> {
    annotations
        .iter()
        .enumerate()
        .map(|(index, annotation)| {
            normalize_annotation(annotation, index, text_len_utf16, valid_offsets)
        })
        .collect()
}

fn normalize_annotation(
    annotation: &Annotation,
    annotation_index: usize,
    text_len_utf16: u32,
    valid_offsets: &BTreeSet<u32>,
) -> Result<Annotation, RhodantheError> {
    if annotation.annotation_id.is_empty() {
        return Err(RhodantheError::EmptyAnnotationId { annotation_index });
    }
    if annotation.range.start >= annotation.range.end || annotation.range.end > text_len_utf16 {
        return Err(RhodantheError::InvalidRange {
            annotation_id: annotation.annotation_id.clone(),
            range: annotation.range,
            text_len_utf16,
        });
    }
    for offset in [annotation.range.start, annotation.range.end] {
        if !valid_offsets.contains(&offset) {
            return Err(RhodantheError::SplitsSurrogatePair {
                annotation_id: annotation.annotation_id.clone(),
                offset,
            });
        }
    }
    if annotation.style.is_empty() {
        return Err(RhodantheError::EmptyStyle {
            annotation_id: annotation.annotation_id.clone(),
        });
    }

    validate_token(
        annotation.style.foreground.as_deref(),
        annotation,
        "foreground",
    )?;
    validate_token(
        annotation.style.background.as_deref(),
        annotation,
        "background",
    )?;
    validate_token(
        annotation.style.interaction.as_deref(),
        annotation,
        "interaction",
    )?;

    let mut normalized = annotation.clone();
    if let Some(decoration) = &mut normalized.style.decoration {
        if decoration.lines.is_empty() {
            return Err(RhodantheError::EmptyDecorationLines {
                annotation_id: annotation.annotation_id.clone(),
            });
        }
        if decoration.color.is_empty() {
            return Err(RhodantheError::EmptySemanticToken {
                annotation_id: annotation.annotation_id.clone(),
                channel: "decoration color",
            });
        }
        if !decoration.thickness.is_finite() {
            return Err(RhodantheError::InvalidDecorationThickness {
                annotation_id: annotation.annotation_id.clone(),
                thickness: decoration.thickness,
            });
        }
        decoration.lines.sort_unstable();
        decoration.lines.dedup();
        decoration.thickness = decoration.thickness.clamp(1.0, 3.0);
    }

    Ok(normalized)
}

fn validate_token(
    token: Option<&str>,
    annotation: &Annotation,
    channel: &'static str,
) -> Result<(), RhodantheError> {
    if token.is_some_and(str::is_empty) {
        return Err(RhodantheError::EmptySemanticToken {
            annotation_id: annotation.annotation_id.clone(),
            channel,
        });
    }
    Ok(())
}

fn resolve_style(active: &[&Annotation]) -> (StylePatch, Vec<String>) {
    let foreground = winner(active, |style| style.foreground.is_some());
    let background = winner(active, |style| style.background.is_some());
    let weight = winner(active, |style| style.weight.is_some());
    let slant = winner(active, |style| style.slant.is_some());
    let decoration = winner(active, |style| style.decoration.is_some());
    let interaction = winner(active, |style| style.interaction.is_some());

    let style = StylePatch {
        foreground: foreground.and_then(|annotation| annotation.style.foreground.clone()),
        background: background.and_then(|annotation| annotation.style.background.clone()),
        weight: weight.and_then(|annotation| annotation.style.weight),
        slant: slant.and_then(|annotation| annotation.style.slant),
        decoration: decoration.and_then(|annotation| annotation.style.decoration.clone()),
        interaction: interaction.and_then(|annotation| annotation.style.interaction.clone()),
    };

    let mut annotation_ids: Vec<String> = [
        foreground,
        background,
        weight,
        slant,
        decoration,
        interaction,
    ]
    .into_iter()
    .flatten()
    .map(|annotation| annotation.annotation_id.clone())
    .collect();
    annotation_ids.sort_unstable();
    annotation_ids.dedup();

    (style, annotation_ids)
}

fn winner<'a, F>(active: &[&'a Annotation], has_channel: F) -> Option<&'a Annotation>
where
    F: Fn(&StylePatch) -> bool,
{
    active
        .iter()
        .copied()
        .filter(|annotation| has_channel(&annotation.style))
        .min_by(|left, right| compare_annotations(left, right))
}

fn compare_annotations(left: &Annotation, right: &Annotation) -> Ordering {
    left.ring
        .priority()
        .cmp(&right.ring.priority())
        .then_with(|| left.source_order.cmp(&right.source_order))
        .then_with(|| left.annotation_id.cmp(&right.annotation_id))
}
