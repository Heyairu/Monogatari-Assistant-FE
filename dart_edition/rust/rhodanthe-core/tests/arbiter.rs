use rhodanthe_core::{
    build_render_plan, Annotation, DecorationLine, DecorationSpec, DecorationStyle, FontSlant,
    FontWeight, RhodantheError, Ring, StylePatch, Utf16Range, CONTRACT_VERSION,
};

fn annotation(id: &str, ring: Ring, start: u32, end: u32, style: StylePatch) -> Annotation {
    Annotation {
        annotation_id: id.to_owned(),
        source: "test".to_owned(),
        source_order: 0,
        ring,
        range: Utf16Range::new(start, end),
        style,
        payload_id: None,
    }
}

fn background(token: &str) -> StylePatch {
    StylePatch {
        background: Some(token.to_owned()),
        ..StylePatch::default()
    }
}

fn foreground(token: &str) -> StylePatch {
    StylePatch {
        foreground: Some(token.to_owned()),
        ..StylePatch::default()
    }
}

fn decoration(token: &str, line_style: DecorationStyle) -> DecorationSpec {
    DecorationSpec {
        lines: vec![DecorationLine::Underline],
        style: line_style,
        color: token.to_owned(),
        thickness: 1.0,
    }
}

#[test]
fn ring_contract_accepts_even_values_and_rejects_reserved_values() {
    assert_eq!(Ring::try_from(0), Ok(Ring::Critical));
    assert_eq!(Ring::try_from(2), Ok(Ring::Search));
    assert_eq!(Ring::try_from(4), Ok(Ring::Mention));
    assert_eq!(Ring::try_from(6), Ok(Ring::Filler));
    assert_eq!(Ring::try_from(8), Ok(Ring::Diagnostic));
    assert_eq!(Ring::try_from(3), Err(RhodantheError::ReservedRing(3)));
    assert_eq!(Ring::try_from(9), Err(RhodantheError::UnknownRing(9)));
}

#[test]
fn empty_annotations_produce_an_empty_versioned_plan() {
    let plan = build_render_plan("plain text", &[]).expect("empty plan should be valid");

    assert_eq!(plan.contract_version, CONTRACT_VERSION);
    assert_eq!(plan.text_len_utf16, 10);
    assert!(plan.runs.is_empty());
    assert!(plan.token_sets.is_empty());
}

#[test]
fn lower_ring_wins_when_the_same_channel_overlaps() {
    let annotations = vec![
        annotation(
            "filler",
            Ring::Filler,
            0,
            4,
            foreground("filler.foreground"),
        ),
        annotation(
            "mention",
            Ring::Mention,
            0,
            4,
            foreground("mention.resolved.foreground"),
        ),
        annotation(
            "current",
            Ring::Critical,
            0,
            4,
            foreground("search.current.foreground"),
        ),
    ];

    let plan = build_render_plan("text", &annotations).expect("plan should build");

    assert_eq!(plan.runs.len(), 1);
    let style = &plan.token_sets[plan.runs[0].style_token_set_id as usize];
    assert_eq!(
        style.foreground.as_deref(),
        Some("search.current.foreground")
    );
    assert_eq!(plan.runs[0].annotation_ids, vec!["current"]);
}

#[test]
fn independent_channels_compose_across_rings() {
    let annotations = vec![
        annotation(
            "search",
            Ring::Search,
            0,
            4,
            background("search.match.background"),
        ),
        annotation(
            "mention",
            Ring::Mention,
            1,
            3,
            StylePatch {
                foreground: Some("mention.resolved.foreground".to_owned()),
                weight: Some(FontWeight::Medium),
                decoration: Some(decoration(
                    "mention.resolved.decoration",
                    DecorationStyle::Solid,
                )),
                interaction: Some("mention:character-1".to_owned()),
                ..StylePatch::default()
            },
        ),
        annotation(
            "filler",
            Ring::Filler,
            2,
            4,
            StylePatch {
                foreground: Some("filler.foreground".to_owned()),
                decoration: Some(decoration("filler.decoration", DecorationStyle::Wavy)),
                ..StylePatch::default()
            },
        ),
    ];

    let plan = build_render_plan("abcd", &annotations).expect("plan should build");

    assert_eq!(plan.runs.len(), 3);
    assert_eq!(plan.runs[0].range, Utf16Range::new(0, 1));
    assert_eq!(plan.runs[1].range, Utf16Range::new(1, 3));
    assert_eq!(plan.runs[2].range, Utf16Range::new(3, 4));

    let mention_style = &plan.token_sets[plan.runs[1].style_token_set_id as usize];
    assert_eq!(
        mention_style.background.as_deref(),
        Some("search.match.background")
    );
    assert_eq!(
        mention_style.foreground.as_deref(),
        Some("mention.resolved.foreground")
    );
    assert_eq!(mention_style.weight, Some(FontWeight::Medium));
    assert_eq!(
        mention_style.decoration.as_ref().map(|value| value.style),
        Some(DecorationStyle::Solid)
    );
    assert_eq!(
        mention_style.interaction.as_deref(),
        Some("mention:character-1")
    );
    assert_eq!(plan.runs[1].annotation_ids, vec!["mention", "search"]);

    let filler_style = &plan.token_sets[plan.runs[2].style_token_set_id as usize];
    assert_eq!(
        filler_style.background.as_deref(),
        Some("search.match.background")
    );
    assert_eq!(
        filler_style.foreground.as_deref(),
        Some("filler.foreground")
    );
}

#[test]
fn same_ring_uses_source_order_then_annotation_id() {
    let mut later_source = annotation("a-id", Ring::Search, 0, 1, background("later-source"));
    later_source.source_order = 2;
    let mut earlier_source = annotation("z-id", Ring::Search, 0, 1, background("earlier-source"));
    earlier_source.source_order = 1;

    let plan = build_render_plan("x", &[later_source, earlier_source])
        .expect("source order should arbitrate");
    let style = &plan.token_sets[plan.runs[0].style_token_set_id as usize];
    assert_eq!(style.background.as_deref(), Some("earlier-source"));

    let first_id = annotation("a-id", Ring::Search, 0, 1, background("first-id"));
    let second_id = annotation("b-id", Ring::Search, 0, 1, background("second-id"));
    let plan =
        build_render_plan("x", &[second_id, first_id]).expect("annotation id should arbitrate");
    let style = &plan.token_sets[plan.runs[0].style_token_set_id as usize];
    assert_eq!(style.background.as_deref(), Some("first-id"));
}

#[test]
fn adjacent_runs_merge_only_when_style_and_metadata_match() {
    let style = background("search.match.background");
    let same_metadata = vec![
        annotation("search", Ring::Search, 0, 1, style.clone()),
        annotation("search", Ring::Search, 1, 2, style.clone()),
    ];
    let merged = build_render_plan("ab", &same_metadata).expect("plan should build");
    assert_eq!(merged.runs.len(), 1);
    assert_eq!(merged.runs[0].range, Utf16Range::new(0, 2));

    let different_metadata = vec![
        annotation("search-1", Ring::Search, 0, 1, style.clone()),
        annotation("search-2", Ring::Search, 1, 2, style),
    ];
    let split = build_render_plan("ab", &different_metadata).expect("plan should build");
    assert_eq!(split.runs.len(), 2);
}

#[test]
fn unstyled_gaps_are_omitted_from_the_plan() {
    let plan = build_render_plan(
        "abc",
        &[annotation(
            "mention",
            Ring::Mention,
            1,
            2,
            foreground("mention.resolved.foreground"),
        )],
    )
    .expect("plan should build");

    assert_eq!(plan.runs.len(), 1);
    assert_eq!(plan.runs[0].range, Utf16Range::new(1, 2));
}

#[test]
fn utf16_ranges_must_not_split_surrogate_pairs() {
    let valid = build_render_plan(
        "a😀b",
        &[annotation(
            "emoji",
            Ring::Search,
            1,
            3,
            background("search.match.background"),
        )],
    )
    .expect("a full emoji range should be valid");
    assert_eq!(valid.text_len_utf16, 4);
    assert_eq!(valid.runs[0].range, Utf16Range::new(1, 3));

    let error = build_render_plan(
        "a😀b",
        &[annotation(
            "broken-emoji",
            Ring::Search,
            1,
            2,
            background("search.match.background"),
        )],
    )
    .expect_err("a split surrogate pair must be rejected");
    assert_eq!(
        error,
        RhodantheError::SplitsSurrogatePair {
            annotation_id: "broken-emoji".to_owned(),
            offset: 2,
        }
    );
}

#[test]
fn decoration_is_normalized_and_invalid_values_are_rejected() {
    let plan = build_render_plan(
        "x",
        &[annotation(
            "decorated",
            Ring::Diagnostic,
            0,
            1,
            StylePatch {
                slant: Some(FontSlant::Italic),
                decoration: Some(DecorationSpec {
                    lines: vec![
                        DecorationLine::Underline,
                        DecorationLine::Underline,
                        DecorationLine::Overline,
                    ],
                    style: DecorationStyle::Dotted,
                    color: "diagnostic.decoration".to_owned(),
                    thickness: 9.0,
                }),
                ..StylePatch::default()
            },
        )],
    )
    .expect("finite thickness should be clamped");
    let decoration = plan.token_sets[0]
        .decoration
        .as_ref()
        .expect("decoration should exist");
    assert_eq!(
        decoration.lines,
        vec![DecorationLine::Underline, DecorationLine::Overline]
    );
    assert_eq!(decoration.thickness, 3.0);

    let error = build_render_plan(
        "x",
        &[annotation(
            "invalid",
            Ring::Diagnostic,
            0,
            1,
            StylePatch {
                decoration: Some(DecorationSpec {
                    lines: vec![DecorationLine::Underline],
                    style: DecorationStyle::Solid,
                    color: "diagnostic.decoration".to_owned(),
                    thickness: f32::NAN,
                }),
                ..StylePatch::default()
            },
        )],
    )
    .expect_err("NaN thickness must be rejected");
    assert!(matches!(
        error,
        RhodantheError::InvalidDecorationThickness { .. }
    ));
}

#[test]
fn invalid_ranges_and_empty_styles_are_rejected() {
    let invalid_range = build_render_plan(
        "x",
        &[annotation(
            "outside",
            Ring::Search,
            0,
            2,
            background("search.match.background"),
        )],
    )
    .expect_err("out-of-bounds ranges must be rejected");
    assert!(matches!(invalid_range, RhodantheError::InvalidRange { .. }));

    let empty_style = build_render_plan(
        "x",
        &[annotation(
            "empty",
            Ring::Search,
            0,
            1,
            StylePatch::default(),
        )],
    )
    .expect_err("empty styles must be rejected");
    assert!(matches!(empty_style, RhodantheError::EmptyStyle { .. }));
}
