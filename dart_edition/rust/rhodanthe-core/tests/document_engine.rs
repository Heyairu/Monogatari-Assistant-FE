use rhodanthe_core::{
    Annotation, RhodantheEngine, RhodantheError, Ring, StylePatch, TextEdit, Utf16Range,
};

fn edit(start: u32, end: u32, replacement: &str) -> TextEdit {
    TextEdit {
        range: Utf16Range::new(start, end),
        replacement: replacement.to_owned(),
    }
}

fn search_annotation(start: u32, end: u32) -> Annotation {
    Annotation {
        annotation_id: "search:1:0".to_owned(),
        source: "search".to_owned(),
        source_order: 0,
        ring: Ring::Search,
        range: Utf16Range::new(start, end),
        style: StylePatch {
            background: Some("search.match.background".to_owned()),
            ..StylePatch::default()
        },
        payload_id: None,
    }
}

#[test]
fn document_lifecycle_produces_a_versioned_render_plan() {
    let mut engine = RhodantheEngine::new();
    engine
        .open_document("chapter-1".to_owned(), 7, "abcd".to_owned())
        .expect("document should open");

    let result = engine
        .analyze("chapter-1", 7, &[search_annotation(1, 3)])
        .expect("current revision should analyze");

    assert_eq!(result.document_id, "chapter-1");
    assert_eq!(result.revision, 7);
    assert_eq!(result.plan.text_len_utf16, 4);
    assert_eq!(result.plan.runs.len(), 1);
    assert_eq!(result.plan.runs[0].range, Utf16Range::new(1, 3));

    engine
        .close_document("chapter-1")
        .expect("open document should close");
    assert_eq!(
        engine.document_revision("chapter-1"),
        Err(RhodantheError::DocumentNotOpen {
            document_id: "chapter-1".to_owned(),
        })
    );
}

#[test]
fn opening_rejects_empty_and_duplicate_document_ids() {
    let mut engine = RhodantheEngine::new();
    assert_eq!(
        engine.open_document(String::new(), 0, String::new()),
        Err(RhodantheError::EmptyDocumentId)
    );

    engine
        .open_document("chapter".to_owned(), 0, String::new())
        .expect("document should open once");
    assert_eq!(
        engine.open_document("chapter".to_owned(), 1, "replacement".to_owned()),
        Err(RhodantheError::DocumentAlreadyOpen {
            document_id: "chapter".to_owned(),
        })
    );
    assert_eq!(engine.document_revision("chapter"), Ok(0));
    assert_eq!(engine.document_text("chapter"), Ok(""));
}

#[test]
fn apply_edits_uses_base_revision_utf16_coordinates() {
    let mut engine = RhodantheEngine::new();
    engine
        .open_document("chapter".to_owned(), 1, "abcd".to_owned())
        .expect("document should open");

    engine
        .apply_edits(
            "chapter",
            1,
            2,
            &[edit(0, 1, "A"), edit(2, 2, "X"), edit(3, 4, "D")],
        )
        .expect("ordered non-overlapping edits should apply atomically");

    assert_eq!(engine.document_text("chapter"), Ok("AbXcD"));
    assert_eq!(engine.document_revision("chapter"), Ok(2));
}

#[test]
fn apply_edits_replaces_complete_surrogate_pairs() {
    let mut engine = RhodantheEngine::new();
    engine
        .open_document("chapter".to_owned(), 10, "A😀B".to_owned())
        .expect("document should open");

    engine
        .apply_edits("chapter", 10, 11, &[edit(1, 3, "花")])
        .expect("the complete emoji range should be replaceable");

    assert_eq!(engine.document_text("chapter"), Ok("A花B"));
    assert_eq!(engine.document_revision("chapter"), Ok(11));
}

#[test]
fn stale_and_non_increasing_revisions_do_not_mutate_the_document() {
    let mut engine = RhodantheEngine::new();
    engine
        .open_document("chapter".to_owned(), 5, "text".to_owned())
        .expect("document should open");

    assert_eq!(
        engine.apply_edits("chapter", 4, 6, &[edit(0, 1, "T")]),
        Err(RhodantheError::RevisionMismatch {
            document_id: "chapter".to_owned(),
            expected: 5,
            actual: 4,
        })
    );
    assert_eq!(
        engine.apply_edits("chapter", 5, 5, &[edit(0, 1, "T")]),
        Err(RhodantheError::NonIncreasingRevision { base: 5, next: 5 })
    );
    assert_eq!(engine.document_text("chapter"), Ok("text"));
    assert_eq!(engine.document_revision("chapter"), Ok(5));
}

#[test]
fn edits_that_split_surrogate_pairs_are_rejected_atomically() {
    let mut engine = RhodantheEngine::new();
    engine
        .open_document("chapter".to_owned(), 1, "A😀B".to_owned())
        .expect("document should open");

    assert_eq!(
        engine.apply_edits("chapter", 1, 2, &[edit(1, 2, "x")]),
        Err(RhodantheError::EditSplitsSurrogatePair {
            edit_index: 0,
            offset: 2,
        })
    );
    assert_eq!(engine.document_text("chapter"), Ok("A😀B"));
    assert_eq!(engine.document_revision("chapter"), Ok(1));
}

#[test]
fn overlapping_and_unsorted_edits_are_rejected_atomically() {
    let mut engine = RhodantheEngine::new();
    engine
        .open_document("chapter".to_owned(), 1, "abcdef".to_owned())
        .expect("document should open");

    assert_eq!(
        engine.apply_edits("chapter", 1, 2, &[edit(1, 3, "x"), edit(2, 4, "y")]),
        Err(RhodantheError::OverlappingEdits {
            previous_index: 0,
            edit_index: 1,
        })
    );
    assert_eq!(
        engine.apply_edits("chapter", 1, 2, &[edit(4, 5, "x"), edit(1, 2, "y")]),
        Err(RhodantheError::EditsNotSorted {
            previous_index: 0,
            edit_index: 1,
        })
    );
    assert_eq!(engine.document_text("chapter"), Ok("abcdef"));
    assert_eq!(engine.document_revision("chapter"), Ok(1));
}

#[test]
fn analyze_rejects_stale_revisions() {
    let mut engine = RhodantheEngine::new();
    engine
        .open_document("chapter".to_owned(), 2, "text".to_owned())
        .expect("document should open");

    assert_eq!(
        engine.analyze("chapter", 1, &[]),
        Err(RhodantheError::RevisionMismatch {
            document_id: "chapter".to_owned(),
            expected: 2,
            actual: 1,
        })
    );
}

#[test]
fn an_empty_edit_batch_can_advance_the_revision() {
    let mut engine = RhodantheEngine::new();
    engine
        .open_document("chapter".to_owned(), 1, "text".to_owned())
        .expect("document should open");

    engine
        .apply_edits("chapter", 1, 2, &[])
        .expect("a metadata-only revision may advance");

    assert_eq!(engine.document_text("chapter"), Ok("text"));
    assert_eq!(engine.document_revision("chapter"), Ok(2));
}
