use rhodanthe_analyzers::{
    analyze_document_search, analyze_search, SearchError, SearchOptions, SearchRequest,
};
use rhodanthe_core::{FontWeight, RhodantheEngine, RhodantheError, Ring, Utf16Range};

fn request(query: &str) -> SearchRequest {
    SearchRequest::new(query.to_owned(), 1)
}

#[test]
fn exact_search_returns_utf16_ranges_after_emoji() {
    let result =
        analyze_search("😀test TEST", &request("test")).expect("literal search should succeed");

    assert_eq!(result.total_matches, 1);
    assert_eq!(result.annotations.len(), 1);
    assert_eq!(result.annotations[0].range, Utf16Range::new(2, 6));
    assert_eq!(result.annotations[0].ring, Ring::Search);
}

#[test]
fn case_insensitive_search_matches_supported_scripts() {
    let mut search = request("test αβγ привет");
    search.options.match_case = false;

    let result =
        analyze_search("TEST ΑΒΓ ПРИВЕТ", &search).expect("case normalization should succeed");

    assert_eq!(result.total_matches, 1);
    assert_eq!(result.annotations[0].range, Utf16Range::new(0, 15));
}

#[test]
fn width_insensitive_search_matches_fullwidth_ascii() {
    let mut search = request("abc");
    search.options.match_case = false;
    search.options.match_width = false;

    let result = analyze_search("ＡＢＣ abc", &search).expect("width normalization should succeed");

    assert_eq!(result.total_matches, 2);
    assert_eq!(result.annotations[0].range, Utf16Range::new(0, 3));
    assert_eq!(result.annotations[1].range, Utf16Range::new(4, 7));
}

#[test]
fn width_insensitive_search_matches_hiragana_and_katakana_forms() {
    let mut search = request("ｶﾞ");
    search.options.match_width = false;

    let result =
        analyze_search("がガｶﾞ", &search).expect("kana width normalization should succeed");

    assert_eq!(result.total_matches, 3);
    assert_eq!(result.annotations[0].range, Utf16Range::new(0, 1));
    assert_eq!(result.annotations[1].range, Utf16Range::new(1, 2));
    assert_eq!(result.annotations[2].range, Utf16Range::new(2, 4));
}

#[test]
fn ignored_punctuation_and_whitespace_remain_inside_the_original_range() {
    let mut search = request("a-b");
    search.options.ignore_punctuation = true;
    search.options.ignore_whitespace = true;

    let result =
        analyze_search("a, \nb", &search).expect("ignored characters should be transparent");

    assert_eq!(result.total_matches, 1);
    assert_eq!(result.annotations[0].range, Utf16Range::new(0, 5));
}

#[test]
fn whole_word_uses_the_existing_latin_boundary_contract() {
    let mut search = request("café");
    search.options.whole_word = true;

    let result = analyze_search("café scatter café caféx", &search)
        .expect("whole-word search should succeed");

    assert_eq!(result.total_matches, 2);
    assert_eq!(result.annotations[0].range, Utf16Range::new(0, 4));
    assert_eq!(result.annotations[1].range, Utf16Range::new(13, 17));
}

#[test]
fn active_match_stays_visible_without_exceeding_the_result_cap() {
    let mut search = SearchRequest::new("x".to_owned(), 9);
    search.max_results = 2;
    search.active_match_index = Some(4);

    let result = analyze_search("x x x x x", &search).expect("bounded search should succeed");

    assert_eq!(result.total_matches, 5);
    assert!(result.truncated);
    assert_eq!(result.annotations.len(), 2);
    assert_eq!(result.annotations[0].annotation_id, "search:9:0");
    assert_eq!(result.annotations[1].annotation_id, "search:9:4");
    assert_eq!(result.annotations[1].range, Utf16Range::new(8, 9));
    assert_eq!(result.annotations[1].ring, Ring::Critical);
    assert_eq!(
        result.annotations[1].style.weight,
        Some(FontWeight::Semibold)
    );
    assert_eq!(result.active_match_id.as_deref(), Some("search:9:4"));
}

#[test]
fn empty_effective_query_returns_no_matches() {
    let mut search = request("--- \n");
    search.options.ignore_punctuation = true;
    search.options.ignore_whitespace = true;

    let result = analyze_search("text", &search).expect("empty effective query is valid");

    assert_eq!(result.total_matches, 0);
    assert!(!result.truncated);
    assert!(result.annotations.is_empty());
}

#[test]
fn regexp_search_returns_utf16_ranges_and_keeps_active_match_visible() {
    let mut search = SearchRequest::new(r"A\d".to_owned(), 7);
    search.options.use_regexp = true;
    search.max_results = 2;
    search.active_match_index = Some(2);

    let result = analyze_search("😀A1 A2 A3", &search).expect("regexp search should succeed");

    assert_eq!(result.total_matches, 3);
    assert!(result.truncated);
    assert_eq!(result.annotations.len(), 2);
    assert_eq!(result.annotations[0].range, Utf16Range::new(2, 4));
    assert_eq!(result.annotations[1].range, Utf16Range::new(8, 10));
    assert_eq!(result.annotations[1].annotation_id, "search:7:2");
    assert_eq!(result.annotations[1].ring, Ring::Critical);
    assert_eq!(result.active_match_id.as_deref(), Some("search:7:2"));
}

#[test]
fn regexp_search_reports_invalid_patterns() {
    let mut search = request("(");
    search.options.use_regexp = true;

    assert!(matches!(
        analyze_search("text", &search),
        Err(SearchError::InvalidRegularExpression { .. })
    ));
}

#[test]
fn regexp_search_skips_zero_length_matches() {
    let mut search = request(r"^|$");
    search.options.use_regexp = true;

    let result = analyze_search("text", &search).expect("zero-length matches are valid");

    assert_eq!(result.total_matches, 0);
    assert!(result.annotations.is_empty());
}

#[test]
fn regexp_search_uses_raw_case_and_width_sensitive_text() {
    let mut search = request("abc");
    search.options.use_regexp = true;
    search.options.match_case = false;
    search.options.match_width = false;
    search.options.ignore_punctuation = true;
    search.options.ignore_whitespace = true;

    let result = analyze_search("ＡＢＣ ABC a-b abc", &search)
        .expect("regexp mode should preserve the Dart strict contract");

    assert_eq!(result.total_matches, 1);
    assert_eq!(result.annotations[0].range, Utf16Range::new(12, 15));
}

#[test]
fn regexp_search_enforces_pattern_utf16_budget() {
    let mut search = request("😀😀");
    search.options.use_regexp = true;
    search.max_regexp_code_units = 3;

    assert_eq!(
        analyze_search("😀😀", &search),
        Err(SearchError::RegularExpressionTooLong { actual: 4, max: 3 })
    );
}

#[test]
fn regexp_search_enforces_input_utf16_budget() {
    let mut search = request("😀");
    search.options.use_regexp = true;
    search.max_input_code_units = 3;

    assert_eq!(
        analyze_search("😀😀", &search),
        Err(SearchError::InputTooLong { actual: 4, max: 3 })
    );
}

#[test]
fn document_search_combines_matches_with_a_versioned_render_plan() {
    let mut engine = RhodantheEngine::new();
    engine
        .open_document("chapter".to_owned(), 3, "text text".to_owned())
        .expect("document should open");
    let mut search = request("text");
    search.active_match_index = Some(1);

    let result = analyze_document_search(&engine, "chapter", 3, &search)
        .expect("document search should succeed");

    assert_eq!(result.search.total_matches, 2);
    assert_eq!(result.search.annotations[0].ring, Ring::Search);
    assert_eq!(result.search.annotations[1].ring, Ring::Critical);
    assert_eq!(result.render_plan.document_id, "chapter");
    assert_eq!(result.render_plan.revision, 3);
    assert_eq!(result.render_plan.plan.runs.len(), 2);

    assert_eq!(
        analyze_document_search(&engine, "chapter", 2, &search),
        Err(SearchError::Core(RhodantheError::RevisionMismatch {
            document_id: "chapter".to_owned(),
            expected: 3,
            actual: 2,
        }))
    );
}

#[test]
fn zero_result_cap_counts_matches_without_returning_annotations() {
    let mut search = request("x");
    search.max_results = 0;
    search.active_match_index = Some(1);

    let result = analyze_search("x x", &search).expect("count-only search should succeed");

    assert_eq!(result.total_matches, 2);
    assert!(result.truncated);
    assert!(result.annotations.is_empty());
    assert_eq!(result.active_match_id.as_deref(), Some("search:1:1"));
}

#[test]
fn search_options_default_to_the_existing_strict_mode() {
    assert_eq!(
        SearchOptions::default(),
        SearchOptions {
            match_case: true,
            whole_word: false,
            use_regexp: false,
            match_width: true,
            ignore_punctuation: false,
            ignore_whitespace: false,
        }
    );
}
