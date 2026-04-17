# Riverpod Migration Phase 9 Cleanup

## Goal
Remove remaining legacy listener chains and reduce high-risk `setState` hotspots after Phase 8.

## What Was Cleaned
- Removed nested/high-frequency `setState` coupling in editor text listener in `main.dart`.
- Added state-change guards for dirty-state updates to avoid unnecessary rebuilds.
- Cleaned `GlossaryView` warnings:
  - Removed unused `_addEntryToSelectedCategory`.
  - Replaced deprecated `DropdownButtonFormField.value` with `initialValue`.

## Listener Chain Status
- Legacy `SettingsManager` / `UILibrary` runtime `addListener/removeListener` chains are no longer used in app composition.
- Runtime state flow is provider-first via Riverpod subscriptions (`ref.listenManual`).
- Existing controller listeners (e.g., `TextEditingController`) are retained by design for local edit lifecycle and are disposed centrally.

## Risk Hotspots Addressed
- `main.dart` editor listener no longer calls `_markAsModified()` inside another `setState` block.
- Dirty-state writes now check value changes before calling `setState`.

## Validation
- `flutter test test/glossaryview_test.dart test/planview_test.dart test/characterview_test_simple.dart test/chapterselectionview_test.dart test/outlineview_test.dart test/worldsettingsview_test.dart`
- `flutter analyze lib/modules/glossaryview.dart lib/main.dart lib/presentation/providers/project_state_providers.dart`

## Phase 5 Addendum (Aggregation + Cleanup)
- Added aggregation verification test:
  - `test/project_data_provider_aggregation_test.dart`
  - Validates `projectDataProvider` still aggregates all migrated source providers after Notifier migration.
- Global cleanup search completed for old write style:
  - No remaining `ref.read(...notifier).state = ...` write-sites.
  - No remaining `StateProvider<...>` declarations in runtime project-state provider layer.
- Additional validation run:
  - `flutter test test/project_data_provider_aggregation_test.dart test/editor_text_box_test.dart test/phase2_widget_interaction_test.dart test/glossary_phase3_regression_test.dart`

## Residual Non-Blocking Items
- Analyze may still report style/info-level issues unrelated to migration behavior.
- These can be handled in a follow-up lint-cleaning pass without changing runtime logic.

## Phase 6 Addendum (Boundary + Guard Rules)

### Scope Cleanup
- Removed obsolete transition accessors from `main.dart` that were only kept during migration:
  - provider passthrough getter/setter wrappers for base/outline/world/character/plan payloads
  - unused selection setters (`selectedSegID` / `selectedChapID`)
  - unused `segmentsData` setter
- `main.dart` keeps only accessors still required by current UI flow (`contentText`, `totalWords`, `currentProject`, selection getters).

### Coordinator Responsibility Boundary
- `EditorCoordinator` owns coordination concerns:
  - sync/apply guards (`isSyncing`, `isApplyingProjectData`)
  - dirty/save lifecycle (`markAsModified`, `markAsSaved`, `hasUnsavedChanges`)
  - project load/save/open recent coordination and recent-project persistence
  - one-shot UI event channels (error/message/word-count-mode event ids)
- `ContentView` owns UI concerns:
  - widget rendering, local panel/overlay visibility, focus routing, window callbacks
  - controller/UI listeners that forward input events to coordinator

### Guard Usage Rules
- Always pair `beginSync()`/`endSync()` and `beginApplyingProjectData()`/`endApplyingProjectData()` with `try/finally`.
- During apply flow, suppress dirty transitions via coordinator guard (`isApplyingProjectData`) instead of local widget flags.
- For one-shot UI notifications, increment event ids in coordinator and consume via `ref.listenManual` in `main.dart` to avoid duplicate dialogs/snackbars on rebuild.
- Keep module-side `_isCommittingLocalChange` guards to prevent immediate provider echo reloads while editing.

### Explicit Out-of-Scope (This Phase)
- No refactor of `WelcomeView` / `SettingView` UI-only `setState` paths.
- No visual/interaction redesign in module-local UI state handling.
