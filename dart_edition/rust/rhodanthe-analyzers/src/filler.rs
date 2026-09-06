use std::collections::{BTreeMap, VecDeque};
use std::error::Error;
use std::fmt;

use rhodanthe_core::{
    Annotation, DecorationLine, DecorationSpec, DecorationStyle, Revision, Ring, StylePatch,
    Utf16Range,
};

pub const DEFAULT_MAX_FILLER_ANNOTATIONS: usize = 2_048;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct FillerBudget {
    pub max_words: usize,
    pub max_positions_per_word: usize,
    pub max_positions_total: usize,
    pub max_annotations: usize,
    pub max_candidates: usize,
}

impl Default for FillerBudget {
    fn default() -> Self {
        Self {
            max_words: 65_535,
            max_positions_per_word: 8_192,
            max_positions_total: 1_048_576,
            max_annotations: DEFAULT_MAX_FILLER_ANNOTATIONS,
            max_candidates: 1_048_576,
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct FillerRequest {
    pub dictionary_revision: Revision,
    pub words: Vec<String>,
    pub budget: FillerBudget,
}

impl FillerRequest {
    pub fn new(dictionary_revision: Revision, words: Vec<String>) -> Self {
        Self {
            dictionary_revision,
            words,
            budget: FillerBudget::default(),
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct FillerHit {
    pub word: String,
    pub count: usize,
    pub positions: Vec<Utf16Range>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct FillerResult {
    pub annotations: Vec<Annotation>,
    pub hits: Vec<FillerHit>,
    pub total_matches: usize,
    pub effective_chars: usize,
    pub ratio: f64,
    pub truncated: bool,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum FillerError {
    TextTooLong,
    MatchCountOverflow,
}

impl fmt::Display for FillerError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::TextTooLong => write!(formatter, "text exceeds the UTF-16 u32 range"),
            Self::MatchCountOverflow => write!(formatter, "filler match count exceeds usize"),
        }
    }
}

impl Error for FillerError {}

#[derive(Clone, Debug)]
struct Pattern {
    word: String,
    len_utf16: u32,
    dictionary_order: usize,
}

#[derive(Clone, Debug, Default)]
struct TrieNode {
    children: BTreeMap<char, usize>,
    fail: usize,
    outputs: Vec<usize>,
}

#[derive(Clone, Copy, Debug)]
struct Candidate {
    word_index: usize,
    range: Utf16Range,
}

#[derive(Clone, Debug)]
pub struct FillerMatcher {
    dictionary_revision: Revision,
    patterns: Vec<Pattern>,
    nodes: Vec<TrieNode>,
}

impl FillerMatcher {
    pub fn new(dictionary_revision: Revision, words: &[String]) -> Result<Self, FillerError> {
        let mut matcher = Self {
            dictionary_revision,
            patterns: Vec::new(),
            nodes: vec![TrieNode::default()],
        };
        let mut seen = BTreeMap::<String, ()>::new();

        for raw_word in words {
            let word = raw_word.trim();
            if word.is_empty() || seen.insert(word.to_owned(), ()).is_some() {
                continue;
            }
            let len_utf16 = utf16_len(word)?;
            let word_index = matcher.patterns.len();
            matcher.patterns.push(Pattern {
                word: word.to_owned(),
                len_utf16,
                dictionary_order: word_index,
            });
            matcher.add_pattern(word_index);
        }
        matcher.build_failure_links();
        Ok(matcher)
    }

    pub fn dictionary_revision(&self) -> Revision {
        self.dictionary_revision
    }

    pub fn word_count(&self) -> usize {
        self.patterns.len()
    }

    pub fn analyze(&self, text: &str, budget: FillerBudget) -> Result<FillerResult, FillerError> {
        let candidates = self.collect_candidates(text, budget.max_candidates)?;
        let mut selected = Vec::new();
        let mut next_allowed_start = 0_u32;
        for candidate in candidates.matches.into_values() {
            if candidate.range.start < next_allowed_start {
                continue;
            }
            next_allowed_start = candidate.range.end;
            selected.push(candidate);
        }

        let mut accumulators = vec![HitAccumulator::default(); self.patterns.len()];
        let mut stored_positions = 0_usize;
        let mut positions_truncated = false;
        for candidate in &selected {
            let accumulator = &mut accumulators[candidate.word_index];
            accumulator.count = accumulator
                .count
                .checked_add(1)
                .ok_or(FillerError::MatchCountOverflow)?;
            if accumulator.positions.len() < budget.max_positions_per_word
                && stored_positions < budget.max_positions_total
            {
                accumulator.positions.push(candidate.range);
                stored_positions += 1;
            } else {
                positions_truncated = true;
            }
        }

        let mut ranked: Vec<usize> = accumulators
            .iter()
            .enumerate()
            .filter_map(|(index, accumulator)| (accumulator.count > 0).then_some(index))
            .collect();
        ranked.sort_by(|left, right| {
            accumulators[*right]
                .count
                .cmp(&accumulators[*left].count)
                .then_with(|| {
                    self.patterns[*left]
                        .dictionary_order
                        .cmp(&self.patterns[*right].dictionary_order)
                })
        });
        let retained_word_count = ranked.len().min(budget.max_words);
        let retained_words = &ranked[..retained_word_count];
        let retained_lookup: BTreeMap<usize, usize> = retained_words
            .iter()
            .enumerate()
            .map(|(rank, word_index)| (*word_index, rank))
            .collect();

        let hits = retained_words
            .iter()
            .map(|word_index| FillerHit {
                word: self.patterns[*word_index].word.clone(),
                count: accumulators[*word_index].count,
                positions: accumulators[*word_index].positions.clone(),
            })
            .collect();

        let mut occurrence_by_word = vec![0_usize; self.patterns.len()];
        let mut annotations = Vec::with_capacity(budget.max_annotations.min(64));
        let mut annotation_truncated = false;
        for candidate in selected
            .iter()
            .filter(|candidate| retained_lookup.contains_key(&candidate.word_index))
        {
            let occurrence = occurrence_by_word[candidate.word_index];
            occurrence_by_word[candidate.word_index] += 1;
            if annotations.len() < budget.max_annotations {
                annotations.push(self.annotation(candidate, occurrence));
            } else {
                annotation_truncated = true;
            }
        }

        let total_matches = selected.len();
        let effective_chars = count_effective_chars(text);
        let ratio = if effective_chars == 0 {
            0.0
        } else {
            total_matches as f64 / effective_chars as f64
        };
        Ok(FillerResult {
            annotations,
            hits,
            total_matches,
            effective_chars,
            ratio,
            truncated: candidates.truncated
                || positions_truncated
                || annotation_truncated
                || ranked.len() > retained_word_count,
        })
    }

    fn add_pattern(&mut self, pattern_index: usize) {
        let mut state = 0_usize;
        for character in self.patterns[pattern_index].word.chars() {
            let next = self.nodes[state].children.get(&character).copied();
            state = match next {
                Some(next) => next,
                None => {
                    let next = self.nodes.len();
                    self.nodes.push(TrieNode::default());
                    self.nodes[state].children.insert(character, next);
                    next
                }
            };
        }
        self.nodes[state].outputs.push(pattern_index);
    }

    fn build_failure_links(&mut self) {
        let mut queue = VecDeque::new();
        for child in self.nodes[0].children.values().copied() {
            queue.push_back(child);
        }

        while let Some(state) = queue.pop_front() {
            let children: Vec<(char, usize)> = self.nodes[state]
                .children
                .iter()
                .map(|(character, child)| (*character, *child))
                .collect();
            for (character, child) in children {
                let mut fallback = self.nodes[state].fail;
                while fallback != 0 && !self.nodes[fallback].children.contains_key(&character) {
                    fallback = self.nodes[fallback].fail;
                }
                self.nodes[child].fail = self.nodes[fallback]
                    .children
                    .get(&character)
                    .copied()
                    .unwrap_or(0);
                let inherited = self.nodes[self.nodes[child].fail].outputs.clone();
                self.nodes[child].outputs.extend(inherited);
                queue.push_back(child);
            }
        }
    }

    fn collect_candidates(
        &self,
        text: &str,
        max_candidates: usize,
    ) -> Result<CandidateCollection, FillerError> {
        let mut matches = BTreeMap::<u32, Candidate>::new();
        let mut state = 0_usize;
        let mut utf16_end = 0_u32;
        let mut truncated = false;

        for character in text.chars() {
            let width =
                u32::try_from(character.len_utf16()).map_err(|_| FillerError::TextTooLong)?;
            utf16_end = utf16_end
                .checked_add(width)
                .ok_or(FillerError::TextTooLong)?;
            while state != 0 && !self.nodes[state].children.contains_key(&character) {
                state = self.nodes[state].fail;
            }
            state = self.nodes[state]
                .children
                .get(&character)
                .copied()
                .unwrap_or(0);

            for word_index in self.nodes[state].outputs.iter().copied() {
                let pattern = &self.patterns[word_index];
                let start = utf16_end - pattern.len_utf16;
                let candidate = Candidate {
                    word_index,
                    range: Utf16Range::new(start, utf16_end),
                };
                if let Some(current) = matches.get_mut(&start) {
                    if candidate_is_preferred(candidate, *current, &self.patterns) {
                        *current = candidate;
                    }
                } else if matches.len() < max_candidates {
                    matches.insert(start, candidate);
                } else {
                    truncated = true;
                }
            }
        }
        Ok(CandidateCollection { matches, truncated })
    }

    fn annotation(&self, candidate: &Candidate, occurrence: usize) -> Annotation {
        let pattern = &self.patterns[candidate.word_index];
        let payload_id = format!(
            "filler:{}:{}",
            self.dictionary_revision, pattern.dictionary_order
        );
        Annotation {
            annotation_id: format!("{payload_id}:{occurrence}"),
            source: "filler".to_owned(),
            source_order: 0,
            ring: Ring::Filler,
            range: candidate.range,
            style: StylePatch {
                foreground: Some("filler.foreground".to_owned()),
                decoration: Some(DecorationSpec {
                    lines: vec![DecorationLine::Underline],
                    style: DecorationStyle::Wavy,
                    color: "filler.decoration".to_owned(),
                    thickness: 1.0,
                }),
                interaction: Some(payload_id.clone()),
                ..StylePatch::default()
            },
            payload_id: Some(payload_id),
        }
    }
}

#[derive(Clone, Debug, Default)]
struct HitAccumulator {
    count: usize,
    positions: Vec<Utf16Range>,
}

#[derive(Debug)]
struct CandidateCollection {
    matches: BTreeMap<u32, Candidate>,
    truncated: bool,
}

fn candidate_is_preferred(candidate: Candidate, current: Candidate, patterns: &[Pattern]) -> bool {
    let candidate_length = candidate.range.end - candidate.range.start;
    let current_length = current.range.end - current.range.start;
    candidate_length > current_length
        || (candidate_length == current_length
            && patterns[candidate.word_index].dictionary_order
                < patterns[current.word_index].dictionary_order)
}

fn utf16_len(text: &str) -> Result<u32, FillerError> {
    text.chars().try_fold(0_u32, |length, character| {
        let width = u32::try_from(character.len_utf16()).map_err(|_| FillerError::TextTooLong)?;
        length.checked_add(width).ok_or(FillerError::TextTooLong)
    })
}

fn count_effective_chars(text: &str) -> usize {
    text.chars()
        .filter(|character| {
            let code = *character as u32;
            character.is_ascii_alphanumeric()
                || (0x3400..=0x4DBF).contains(&code)
                || (0x4E00..=0x9FFF).contains(&code)
                || (0xF900..=0xFAFF).contains(&code)
        })
        .count()
}
