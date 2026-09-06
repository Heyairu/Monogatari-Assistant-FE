use rhodanthe_analyzers::{
    analyze_document, AnalysisError, DocumentAnalysisRequest, FillerBudget, FillerMatcher,
    FillerRequest, SearchRequest,
};
use rhodanthe_core::{RhodantheEngine, RhodantheError, Ring, Utf16Range};

fn words(values: &[&str]) -> Vec<String> {
    values.iter().map(|value| (*value).to_owned()).collect()
}

#[test]
fn dictionary_trims_deduplicates_and_ignores_empty_words() {
    let matcher = FillerMatcher::new(3, &words(&[" 的 ", "的", "", "  ", "然後"]))
        .expect("dictionary should build");

    assert_eq!(matcher.dictionary_revision(), 3);
    assert_eq!(matcher.word_count(), 2);
}

#[test]
fn matcher_returns_utf16_ranges_after_emoji() {
    let matcher = FillerMatcher::new(1, &words(&["然後", "的"])).expect("dictionary should build");
    let result = matcher
        .analyze("😀然後的", FillerBudget::default())
        .expect("analysis should succeed");

    assert_eq!(result.total_matches, 2);
    assert_eq!(result.annotations[0].range, Utf16Range::new(2, 4));
    assert_eq!(result.annotations[1].range, Utf16Range::new(4, 5));
}

#[test]
fn leftmost_longest_prefers_the_longer_word_at_the_same_start() {
    let matcher = FillerMatcher::new(1, &words(&["的", "的確"])).expect("dictionary should build");
    let result = matcher
        .analyze("的確的", FillerBudget::default())
        .expect("analysis should succeed");

    assert_eq!(result.total_matches, 2);
    assert_eq!(result.annotations[0].range, Utf16Range::new(0, 2));
    assert_eq!(result.annotations[1].range, Utf16Range::new(2, 3));
    assert_eq!(result.hits[0].word, "的");
    assert_eq!(result.hits[0].count, 1);
    assert_eq!(result.hits[1].word, "的確");
    assert_eq!(result.hits[1].count, 1);
}

#[test]
fn leftmost_match_wins_when_different_starts_overlap() {
    let matcher = FillerMatcher::new(1, &words(&["ab", "bc"])).expect("dictionary should build");
    let result = matcher
        .analyze("abc", FillerBudget::default())
        .expect("analysis should succeed");

    assert_eq!(result.total_matches, 1);
    assert_eq!(result.hits[0].word, "ab");
    assert_eq!(result.annotations[0].range, Utf16Range::new(0, 2));
}

#[test]
fn repeated_occurrences_of_one_word_do_not_overlap() {
    let matcher = FillerMatcher::new(1, &words(&["aa"])).expect("dictionary should build");
    let result = matcher
        .analyze("aaa", FillerBudget::default())
        .expect("analysis should succeed");

    assert_eq!(result.total_matches, 1);
    assert_eq!(result.annotations[0].range, Utf16Range::new(0, 2));
}

#[test]
fn budgets_bound_hits_positions_and_annotations_independently() {
    let matcher = FillerMatcher::new(7, &words(&["的", "然後"])).expect("dictionary should build");
    let budget = FillerBudget {
        max_words: 1,
        max_positions_per_word: 1,
        max_positions_total: 1,
        max_annotations: 1,
        ..FillerBudget::default()
    };
    let result = matcher
        .analyze("的的的然後然後", budget)
        .expect("bounded analysis should succeed");

    assert_eq!(result.total_matches, 5);
    assert!(result.truncated);
    assert_eq!(result.hits.len(), 1);
    assert_eq!(result.hits[0].word, "的");
    assert_eq!(result.hits[0].count, 3);
    assert_eq!(result.hits[0].positions, vec![Utf16Range::new(0, 1)]);
    assert_eq!(result.annotations.len(), 1);
}

#[test]
fn filler_annotations_use_ring_six_and_stable_semantic_tokens() {
    let matcher = FillerMatcher::new(11, &words(&["真的"])).expect("dictionary should build");
    let result = matcher
        .analyze("真的", FillerBudget::default())
        .expect("analysis should succeed");
    let annotation = &result.annotations[0];

    assert_eq!(annotation.annotation_id, "filler:11:0:0");
    assert_eq!(annotation.payload_id.as_deref(), Some("filler:11:0"));
    assert_eq!(annotation.ring, Ring::Filler);
    assert_eq!(
        annotation.style.foreground.as_deref(),
        Some("filler.foreground")
    );
    assert_eq!(annotation.style.interaction.as_deref(), Some("filler:11:0"));
    assert!(annotation.style.decoration.is_some());
}

#[test]
fn ratio_uses_cjk_and_ascii_alphanumeric_effective_characters() {
    let matcher = FillerMatcher::new(1, &words(&["的"])).expect("dictionary should build");
    let result = matcher
        .analyze("的! A1", FillerBudget::default())
        .expect("analysis should succeed");

    assert_eq!(result.total_matches, 1);
    assert_eq!(result.effective_chars, 3);
    assert!((result.ratio - (1.0 / 3.0)).abs() < f64::EPSILON);
}

#[test]
fn combined_document_analysis_composes_search_and_filler_channels() {
    let mut engine = RhodantheEngine::new();
    engine
        .open_document("chapter".to_owned(), 4, "真的".to_owned())
        .expect("document should open");
    let mut search = SearchRequest::new("真的".to_owned(), 2);
    search.active_match_index = Some(0);
    let request = DocumentAnalysisRequest {
        search: Some(search),
        filler: Some(FillerRequest::new(8, words(&["真的"]))),
        external_annotations: Vec::new(),
    };

    let result =
        analyze_document(&engine, "chapter", 4, &request).expect("analysis should succeed");

    assert_eq!(
        result.search.as_ref().map(|value| value.total_matches),
        Some(1)
    );
    assert_eq!(
        result.filler.as_ref().map(|value| value.total_matches),
        Some(1)
    );
    assert_eq!(result.render_plan.plan.runs.len(), 1);
    let run = &result.render_plan.plan.runs[0];
    assert_eq!(run.annotation_ids, vec!["filler:8:0:0", "search:2:0"]);
    let style = &result.render_plan.plan.token_sets[run.style_token_set_id as usize];
    assert_eq!(
        style.foreground.as_deref(),
        Some("search.current.foreground")
    );
    assert_eq!(
        style.background.as_deref(),
        Some("search.current.background")
    );
    assert!(style.decoration.is_some());
}

#[test]
fn combined_document_analysis_rejects_stale_revisions_before_scanning() {
    let mut engine = RhodantheEngine::new();
    engine
        .open_document("chapter".to_owned(), 5, "text".to_owned())
        .expect("document should open");

    assert_eq!(
        analyze_document(&engine, "chapter", 4, &DocumentAnalysisRequest::default(),),
        Err(AnalysisError::Core(RhodantheError::RevisionMismatch {
            document_id: "chapter".to_owned(),
            expected: 5,
            actual: 4,
        }))
    );
}

#[test]
fn candidate_budget_reports_a_truncated_partial_result() {
    let matcher = FillerMatcher::new(1, &words(&["x"])).expect("dictionary should build");
    let result = matcher
        .analyze(
            "xxx",
            FillerBudget {
                max_candidates: 1,
                ..FillerBudget::default()
            },
        )
        .expect("bounded analysis should succeed");

    assert_eq!(result.total_matches, 1);
    assert!(result.truncated);
}
