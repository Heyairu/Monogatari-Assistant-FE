# Revision tracking

This feature contains detached baseline snapshots, navigation targets, pure
comparison services, a Riverpod session, a desktop panel, persisted local
checkpoints and supported review actions.

## Entry points

1. Synchronize the editor draft to `ProjectData` using the existing coordinator.
2. Call `RevisionSnapshotBuilder.capture(project, version: contentVersion)`.
3. Keep that snapshot in a `RevisionBaseline`; saving must not replace it.
4. `revisionTrackingProvider` captures current project content and the current
   editor draft, then compares on a worker through `compute` after 350 ms of
   quiet time. It discards results whose generation or baseline has changed.
5. `RevisionComparisonService.compare` accepts same-chapter reusable diffs;
   the provider reuses them for unchanged chapter targets while computing
   changed chapters and record differences on the worker.

Captures recursively own their record values and copy chapter text by UUID.
They contain no mutable project reference. The record codec is called with
collaborative text included. Chapter content comes exclusively from each
chapter's `chapterContent`, including nested folders. Different project IDs
and duplicate chapter IDs are rejected.

## Supported schema and integration contracts

| Record kind | Sidebar destination | Source/update integration |
| --- | --- | --- |
| baseInfo | baseInfo | BaseInfoDataNotifier / existing base-info form |
| chapterFolder, chapterMetadata | chapters | SegmentsDataNotifier / chapter selection |
| character | characters | existing character provider/form; stable map key |
| worldNode | world | WorldSettingsDataNotifier / world form |
| outlineStoryline, outlineEvent, outlineScene, outlineChapterLink | outline | OutlineDataNotifier / outline editor |
| itemClass, itemInstance, itemRelation, itemClassStateChange, itemInstanceStateChange | items | ItemWorkspaceNotifier / item editor |

`RevisionTarget` carries chapter identity/hunk index or record identity plus
field path segments. UI labels and array indices never identify a target.
`RevisionFieldRegistry.pageFor` and `labelFor` provide the initial navigation
and display contracts. Untranslated fields use their original key; unknown
data is not omitted. The panel routes text hunks to the existing chapter
navigation and cursor mechanism, and settings to their Sidebar page/object.
Base-info scalar fields additionally focus and scroll the corresponding input.
Character, chapter, world, outline and item records show object badges. The
outline's collaborative text fields and the item's primary class fields also
show field badges. Other forms navigate to the object, with the exact field and
values visible in the panel; form-level field focusing remains future
integration.

Map fields recurse into changed leaves. Presence, null and empty string are
distinct. Added/deleted objects retain their entire snapshot for preview and
produce one record event, without duplicating every field event. World custom
values compare as unordered stable-ID members, including empty collections.
Other lists compare atomically (including ordering) until domain-specific
adapters are added. `schemaVersion` is ignored; absolute `order` is replaced by
relative surviving-sibling comparison, so insertion/deletion shifts are ignored.
`$order` contains zero-based ranks among surviving siblings, not raw wire indices.
`$parent` identifies a folder/parent change. Chapter folders and chapters share
the same sibling group. Whole-object and dependent-collection rejection is not
enabled until it can be applied as one integrity-checked transaction.
Mirrored item class name/description values in its default state are reported
once when they follow the class field; independent default-state changes remain
visible.

`unsupportedKinds` explicitly lists record types outside the initial schema;
an empty change list means no differences in supported data, not a complete
project comparison. Add adapters/registry support before declaring those types
covered. The comparison state enum separates not-started, computing, complete,
failed and unavailable for later provider integration.

## Text semantics and limits

Line numbers are one-based; hunk insertion boundaries are zero-based. Offsets
refer to original UTF-16 text, including CRLF and surrogate pairs. CRLF and LF
are equivalent in comparisons. Whitespace is preserved. A trailing newline
is represented separately instead of inventing a final empty line. An actual
blank line remains a line (including a document containing only `\n`).

`lines` includes the full edit script with old/new logical line mappings;
`hunks` includes adjacent non-equal groups and insertion offsets. A replacement
counts as deleted plus added lines. EOF-newline changes are available via
`trailingNewlineChanged` and do not inflate these counts. Comparison summaries
count text lines and record events separately.

The Myers implementation trims common prefixes/suffixes and limits its trace
to avoid unbounded quadratic memory on unrelated documents. When the budget
is exceeded, it emits an explicitly marked `isCoarse` middle replacement that
still reconstructs the target. The panel discloses approximate counts for
coarse results. EOF-only changes have their own selectable empty hunk card.

Validation lives in `test/revision_tracking_test.dart` and
`test/revision_tracking_provider_test.dart`, including randomized
reconstruction/minimality, Unicode/CRLF offsets, large local edits, baseline
isolation, stable identities, collection presence and ordering, latest-draft
publication, project reset, panel rendering and card selection.

## Desktop behavior and remaining stages

The desktop layout places a 40 px revision toggle between Sidebar and editor.
When space allows, the panel is an adjustable 280–480 px column; on narrower
desktop windows it overlays the editor. The panel has all/text/settings filters,
current chapter/page versus whole-project scope, change counts and previous/
next navigation. Starting tracking synchronizes the current editor draft into
the chapter model before capturing its fixed baseline. Ordinary saves preserve
the fixed baseline. Loading a project restores its saved session; undo/redo
within a project keeps it. IME composition is not published until commit.

Sessions are encoded in a versioned `RevisionTracking` XML section (schema 2,
with schema 1 read compatibility). It contains
the selected baseline, complete local checkpoints and exact accepted event
identities. Saves do not advance the baseline. A damaged section is retained
and displayed as unavailable. Creating a local checkpoint immediately selects
it as the comparison baseline. Reopening a local session selects its newest
checkpoint; a selected read-only P2P source remains selected. Older checkpoints
can still be selected manually. A verified, complete P2P snapshot from the active
authenticated session can also be downloaded and added as a read-only source;
project UUID and revision manifest are checked before comparison. P2P revision
metadata alone is not treated as full content and has no author attribution
at the individual edit level.

Accepting a hunk or field retains current content and hides that exact event;
editing it again yields a new pending event. The panel also accepts all pending
events in the visible filter/scope. Review decisions are included in project
Undo/Redo, while baseline selection alone is excluded. Rejecting a text hunk or supported scalar
field restores the baseline value through the editor/provider after checking
that the comparison still matches current content. Project history records the
restoration for Undo. Text hunks in the visible scope can be rejected in one
transaction after checking all target chapter content against one snapshot.
Rejection is available for chapter/folder names, base
info text, character scalar text, world node name/type/note, outline scalar
text and item class/instance scalar text. Added/deleted
objects and relationship collections can be accepted but not rejected yet.

The Quill overlay paints added lines and `+ / −` gutter markers from measured
document offsets; deleted lines remain in the panel and a separate read-only
full-markup dialog. Neither marker nor deleted preview enters the editable
document, word count, search or export. The legacy CodeField path retains the
panel but has no inline Quill markers. Remaining work: precise character/world
field focus, domain adapters for unsupported types and dependent collections,
dependent object restoration and a multi-user review policy.
