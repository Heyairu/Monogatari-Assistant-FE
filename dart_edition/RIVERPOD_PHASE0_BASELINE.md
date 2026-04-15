# Riverpod Migration Phase 0 Baseline

## Scope
This baseline protects core behavior before architecture migration.
Target phases covered by this document: Phase 0 guardrails, Phase 1 bootstrap, Phase 2 abstraction layer.

## Core Regression Checklist
- App launch and initialization loading screen behavior remains unchanged.
- Theme mode and theme color are restored correctly after restart.
- Font size and word-count mode are restored correctly after restart.
- Recent projects list can be added and removed correctly.
- New project creation works.
- Open project from picker works.
- Open project from path works.
- Save project and Save As work.
- Export as markdown/xml works.
- Chapter selection and editor content sync behavior remains unchanged.
- Word count update still works for editor content changes.

## Risk Watchpoints
- Any behavior changes around SharedPreferences keys are treated as blockers.
- Any path or permission regression in file open/save flows is treated as blockers.
- Initialization order must stay deterministic for theme/settings to avoid visual flicker.
- No large UI state refactor is allowed in Phase 1-2.

## Done Criteria (Phase 0-2)
- Dependencies for Riverpod are added and resolved.
- App root is wrapped by ProviderScope and app still launches.
- Repository abstraction files exist for theme/settings/file/glossary.
- UseCase files exist for bootstrap and project file flows.
- Provider registration file exists for repository and usecase wiring.
- flutter analyze has no new errors caused by Phase 0-2 changes.

## Rollback Strategy
- Keep existing ChangeNotifier managers active.
- New abstraction layer must be additive and not yet mandatory for runtime paths.
- If startup regression occurs, revert ProviderScope wrapping and dependency additions first.
