import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/revision_tracking/application/revision_comparison_service.dart';
import '../../features/revision_tracking/application/revision_snapshot_builder.dart';
import '../../features/revision_tracking/application/revision_session_codec.dart';
import '../../features/revision_tracking/application/revision_review_service.dart';
import '../../features/revision_tracking/domain/revision_models.dart';
import '../../features/revision_tracking/domain/revision_target.dart';
import '../../models/project_data.dart';
import 'project_state_providers.dart';

enum RevisionViewFilter { all, text, settings }

enum RevisionViewScope { allProject, current }

const Object _revisionUnset = Object();

final class RevisionEditorDraft {
  final String projectId;
  final String chapterId;
  final String text;
  const RevisionEditorDraft(this.projectId, this.chapterId, this.text);
}

final class RevisionEditorDraftNotifier extends Notifier<RevisionEditorDraft?> {
  @override
  RevisionEditorDraft? build() => null;

  void update(String projectId, String? chapterId, String text) {
    if (chapterId == null) return;
    final current = state;
    if (current?.projectId == projectId &&
        current?.chapterId == chapterId &&
        current?.text == text) {
      return;
    }
    state = RevisionEditorDraft(projectId, chapterId, text);
  }

  void clear() => state = null;
}

final revisionEditorDraftProvider =
    NotifierProvider<RevisionEditorDraftNotifier, RevisionEditorDraft?>(
      RevisionEditorDraftNotifier.new,
    );

final class RevisionTrackingState {
  final RevisionBaseline? baseline;
  final RevisionComparisonStatus status;
  final RevisionComparison? comparison;
  final RevisionSnapshot? targetSnapshot;
  final String? error;
  final RevisionViewFilter filter;
  final RevisionViewScope scope;
  final RevisionTarget? selectedTarget;
  final List<RevisionBaseline> baselines;
  final Set<String> acceptedEvents;
  final bool showAccepted;

  const RevisionTrackingState({
    this.baseline,
    this.status = RevisionComparisonStatus.notStarted,
    this.comparison,
    this.targetSnapshot,
    this.error,
    this.filter = RevisionViewFilter.all,
    this.scope = RevisionViewScope.current,
    this.selectedTarget,
    this.baselines = const [],
    this.acceptedEvents = const {},
    this.showAccepted = false,
  });

  RevisionTrackingState copyWith({
    RevisionBaseline? baseline,
    RevisionComparisonStatus? status,
    Object? comparison = _revisionUnset,
    Object? targetSnapshot = _revisionUnset,
    Object? error = _revisionUnset,
    RevisionViewFilter? filter,
    RevisionViewScope? scope,
    Object? selectedTarget = _revisionUnset,
    List<RevisionBaseline>? baselines,
    Set<String>? acceptedEvents,
    bool? showAccepted,
  }) => RevisionTrackingState(
    baseline: baseline ?? this.baseline,
    status: status ?? this.status,
    comparison: identical(comparison, _revisionUnset)
        ? this.comparison
        : comparison as RevisionComparison?,
    targetSnapshot: identical(targetSnapshot, _revisionUnset)
        ? this.targetSnapshot
        : targetSnapshot as RevisionSnapshot?,
    error: identical(error, _revisionUnset) ? this.error : error as String?,
    filter: filter ?? this.filter,
    scope: scope ?? this.scope,
    selectedTarget: identical(selectedTarget, _revisionUnset)
        ? this.selectedTarget
        : selectedTarget as RevisionTarget?,
    baselines: baselines ?? this.baselines,
    acceptedEvents: acceptedEvents ?? this.acceptedEvents,
    showAccepted: showAccepted ?? this.showAccepted,
  );
}

final class _RevisionComputeJob {
  final RevisionBaseline baseline;
  final RevisionSnapshot target;
  final Map<String, RevisionTextDiff> reusableTexts;
  const _RevisionComputeJob(this.baseline, this.target, this.reusableTexts);
}

RevisionComparison _computeRevision(_RevisionComputeJob job) =>
    const RevisionComparisonService().compare(
      job.baseline,
      job.target,
      reusableTexts: job.reusableTexts,
    );

class RevisionTrackingNotifier extends Notifier<RevisionTrackingState> {
  static bool _deepEqual(Object? left, Object? right) {
    if (identical(left, right)) return true;
    if (left is Map && right is Map) {
      if (left.length != right.length) return false;
      for (final entry in left.entries) {
        if (!right.containsKey(entry.key) ||
            !_deepEqual(entry.value, right[entry.key])) {
          return false;
        }
      }
      return true;
    }
    if (left is List && right is List) {
      if (left.length != right.length) return false;
      for (var index = 0; index < left.length; index++) {
        if (!_deepEqual(left[index], right[index])) return false;
      }
      return true;
    }
    return left == right;
  }

  Timer? _debounce;
  int _generation = 0;
  int _version = 0;
  bool _disposed = false;
  RevisionSnapshot? _lastTarget;
  RevisionComparison? _lastComparison;

  @override
  RevisionTrackingState build() {
    ref.onDispose(() {
      _disposed = true;
      _debounce?.cancel();
      _generation++;
    });
    ref.listen(projectDataProvider, (previous, next) {
      scheduleMicrotask(() {
        if (_disposed) return;
        final currentProject = ref.read(projectDataProvider);
        if (next.projectUUID != currentProject.projectUUID) return;
        final baseline = state.baseline;
        if (baseline == null) return;
        if (baseline.snapshot.projectId != currentProject.projectUUID) {
          stop();
        } else if (previous?.revisionTrackingJson ==
                next.revisionTrackingJson &&
            previous != next) {
          _schedule();
        }
      });
    });
    ref.listen(revisionEditorDraftProvider, (previous, next) {
      scheduleMicrotask(() {
        if (!_disposed && state.baseline != null) _schedule();
      });
    });
    return const RevisionTrackingState();
  }

  void start({String label = '開始追蹤'}) {
    _debounce?.cancel();
    _generation++;
    _lastTarget = null;
    _lastComparison = null;
    final now = DateTime.now();
    final source = RevisionSnapshotBuilder.capture(
      ref.read(projectDataProvider),
      version: 'base-${now.microsecondsSinceEpoch}',
    );
    final baseline = RevisionBaseline(
      id: 'tracking-${now.microsecondsSinceEpoch}',
      label: label,
      createdAt: now,
      snapshot: source,
    );
    state = RevisionTrackingState(
      baseline: baseline,
      baselines: [baseline],
      status: RevisionComparisonStatus.computing,
      filter: state.filter,
      scope: state.scope,
    );
    _persist();
    _schedule(immediate: true);
  }

  void stop() {
    _debounce?.cancel();
    _generation++;
    _lastTarget = null;
    _lastComparison = null;
    state = const RevisionTrackingState();
    ref.read(revisionTrackingJsonProvider.notifier).setJson(null);
    ref.read(revisionEditorDraftProvider.notifier).clear();
  }

  void restore(String? serialized, {required String projectId}) {
    if (serialized == null || serialized.isEmpty) return;
    try {
      final loaded = RevisionSessionCodec.decode(
        serialized,
        projectId: projectId,
      );
      final savedSelection = loaded.baselines.singleWhere(
        (entry) => entry.id == loaded.selectedBaselineId,
      );
      final checkpoints = loaded.baselines
          .where(
            (entry) => !entry.readOnly && entry.id.startsWith('checkpoint-'),
          )
          .toList();
      // Historical P2P comparisons remain explicitly selected. Local sessions
      // always resume from their newest checkpoint.
      final selected = savedSelection.readOnly || checkpoints.isEmpty
          ? savedSelection
          : checkpoints.reduce(
              (latest, next) =>
                  next.createdAt.isBefore(latest.createdAt) ? latest : next,
            );
      state = RevisionTrackingState(
        baseline: selected,
        baselines: loaded.baselines,
        acceptedEvents: loaded.acceptedEvents,
        status: RevisionComparisonStatus.computing,
      );
      _schedule(immediate: true);
    } catch (error) {
      state = RevisionTrackingState(
        status: RevisionComparisonStatus.unavailable,
        error: '追蹤資料無法讀取：$error',
      );
      // Preserve the raw payload so the next save cannot destroy unknown data.
    }
  }

  void saveCheckpoint({String? label}) {
    if (state.baseline == null) return;
    final now = DateTime.now();
    final source = RevisionSnapshotBuilder.capture(
      ref.read(projectDataProvider),
      version: 'checkpoint-${now.microsecondsSinceEpoch}',
    );
    final draft = ref.read(revisionEditorDraftProvider);
    final snapshot =
        draft != null &&
            draft.projectId == source.projectId &&
            source.chapterTexts.containsKey(draft.chapterId)
        ? RevisionSnapshot(
            projectId: source.projectId,
            version: source.version,
            chapterTexts: {...source.chapterTexts, draft.chapterId: draft.text},
            records: source.records,
            unsupportedKinds: source.unsupportedKinds,
          )
        : source;
    final checkpoint = RevisionBaseline(
      id: 'checkpoint-${now.microsecondsSinceEpoch}',
      label:
          label ??
          '檢查點 ${now.year}/${now.month}/${now.day} ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
      createdAt: now,
      snapshot: snapshot,
    );
    state = state.copyWith(baselines: [...state.baselines, checkpoint]);
    selectBaseline(checkpoint.id);
  }

  /// Adds a complete, already verified historical project as a read-only source.
  void addHistoricalSource(
    ProjectData project, {
    required String revisionId,
    required String label,
  }) {
    final currentId = ref.read(projectUuidProvider);
    if (project.projectUUID != currentId || revisionId.isEmpty) {
      throw StateError('Historical source belongs to another project');
    }
    if (state.baseline == null) start(label: '比較前工作版本');
    final id = 'p2p-$revisionId';
    if (state.baselines.any((entry) => entry.id == id)) {
      selectBaseline(id);
      return;
    }
    final historical = RevisionBaseline(
      id: id,
      label: label,
      createdAt: DateTime.now(),
      snapshot: RevisionSnapshotBuilder.capture(project, version: revisionId),
      readOnly: true,
      sourceRevisionId: revisionId,
    );
    state = state.copyWith(baselines: [...state.baselines, historical]);
    selectBaseline(id);
  }

  void selectBaseline(String id) {
    final matches = state.baselines.where((baseline) => baseline.id == id);
    if (matches.isEmpty) return;
    final selected = matches.first;
    if (identical(selected, state.baseline)) return;
    _debounce?.cancel();
    _generation++;
    _lastTarget = null;
    _lastComparison = null;
    state = RevisionTrackingState(
      baseline: selected,
      baselines: state.baselines,
      acceptedEvents: state.acceptedEvents,
      filter: state.filter,
      scope: state.scope,
      status: RevisionComparisonStatus.computing,
    );
    _persist();
    _schedule(immediate: true);
  }

  void setShowAccepted(bool value) =>
      state = state.copyWith(showAccepted: value);

  void acceptEvent(String eventKey) {
    acceptEvents([eventKey]);
  }

  void acceptEvents(Iterable<String> eventKeys) {
    if (state.baseline == null ||
        state.baseline!.readOnly ||
        state.status != RevisionComparisonStatus.complete) {
      return;
    }
    final comparison = state.comparison;
    final baseline = state.baseline!;
    if (comparison == null || !_matchesCurrentTarget()) {
      _schedule(immediate: true);
      return;
    }
    final known = <String>{
      for (final text in comparison.texts)
        for (final hunk in text.hunks)
          RevisionReviewService.textKey(baseline, text, hunk),
      for (final record in comparison.records)
        if (record.fields.isEmpty)
          RevisionReviewService.recordKey(baseline, record, null)
        else
          for (final field in record.fields)
            RevisionReviewService.recordKey(baseline, record, field),
    };
    final requested = eventKeys.toSet();
    if (requested.isEmpty || !known.containsAll(requested)) return;
    state = state.copyWith(
      acceptedEvents: {...state.acceptedEvents, ...requested},
    );
    _persist();
  }

  bool _matchesCurrentTarget() {
    final expected = state.targetSnapshot;
    if (expected == null) return false;
    final captured = RevisionSnapshotBuilder.capture(
      ref.read(projectDataProvider),
      version: expected.version,
    );
    final draft = ref.read(revisionEditorDraftProvider);
    final chapters = {...captured.chapterTexts};
    if (draft != null &&
        draft.projectId == captured.projectId &&
        chapters.containsKey(draft.chapterId)) {
      chapters[draft.chapterId] = draft.text;
    }
    if (!_deepEqual(chapters, expected.chapterTexts) ||
        captured.records.length != expected.records.length) {
      return false;
    }
    for (final entry in expected.records.entries) {
      final current = captured.records[entry.key];
      if (current == null ||
          current.parentId != entry.value.parentId ||
          !_deepEqual(current.fields, entry.value.fields)) {
        return false;
      }
    }
    return true;
  }

  bool comparisonIsFresh() {
    if (state.status == RevisionComparisonStatus.complete &&
        _matchesCurrentTarget()) {
      return true;
    }
    _schedule(immediate: true);
    return false;
  }

  void unacceptEvent(String eventKey) {
    state = state.copyWith(
      acceptedEvents: {...state.acceptedEvents}..remove(eventKey),
    );
    _persist();
  }

  /// Undo/Redo restores review decisions while keeping the current baseline set.
  void restoreReviewDecisions(String? serialized) {
    if (state.baseline == null) return;
    Set<String> decisions = const {};
    if (serialized != null) {
      try {
        decisions = RevisionSessionCodec.decode(
          serialized,
          projectId: state.baseline!.snapshot.projectId,
        ).acceptedEvents;
      } catch (_) {
        return;
      }
    }
    state = state.copyWith(acceptedEvents: decisions);
    _persist();
  }

  void _persist() {
    final baseline = state.baseline;
    if (baseline == null) return;
    ref
        .read(revisionTrackingJsonProvider.notifier)
        .setJson(
          RevisionSessionCodec.encode(
            RevisionSessionData(
              selectedBaselineId: baseline.id,
              baselines: state.baselines,
              acceptedEvents: state.acceptedEvents,
            ),
          ),
        );
  }

  void setFilter(RevisionViewFilter filter) =>
      state = state.copyWith(filter: filter);
  void setScope(RevisionViewScope scope) =>
      state = state.copyWith(scope: scope);
  void select(RevisionTarget? target) =>
      state = state.copyWith(selectedTarget: target);

  void _schedule({bool immediate = false}) {
    _debounce?.cancel();
    final baseline = state.baseline;
    if (baseline == null) return;
    final generation = ++_generation;
    state = state.copyWith(
      status: RevisionComparisonStatus.computing,
      comparison: null,
      targetSnapshot: null,
      error: null,
    );
    if (immediate) {
      unawaited(_refresh(generation, baseline));
    } else {
      _debounce = Timer(
        const Duration(milliseconds: 350),
        () => unawaited(_refresh(generation, baseline)),
      );
    }
  }

  Future<void> _refresh(int generation, RevisionBaseline baseline) async {
    try {
      final project = ref.read(projectDataProvider);
      if (project.projectUUID != baseline.snapshot.projectId) {
        stop();
        return;
      }
      final captured = RevisionSnapshotBuilder.capture(
        project,
        version: 'target-${++_version}',
      );
      final draft = ref.read(revisionEditorDraftProvider);
      final target =
          draft != null &&
              draft.projectId == project.projectUUID &&
              captured.chapterTexts.containsKey(draft.chapterId)
          ? RevisionSnapshot(
              projectId: captured.projectId,
              version: captured.version,
              chapterTexts: {
                ...captured.chapterTexts,
                draft.chapterId: draft.text,
              },
              records: captured.records,
              unsupportedKinds: captured.unsupportedKinds,
            )
          : captured;
      final previousTexts = {
        for (final text in _lastComparison?.texts ?? <RevisionTextDiff>[])
          if (_lastTarget?.chapterTexts[text.chapterId] ==
              target.chapterTexts[text.chapterId])
            text.chapterId: text,
      };
      final result = await compute(
        _computeRevision,
        _RevisionComputeJob(baseline, target, previousTexts),
      );
      if (_disposed ||
          generation != _generation ||
          !identical(state.baseline, baseline)) {
        return;
      }
      _lastTarget = target;
      _lastComparison = result;
      state = state.copyWith(
        status: RevisionComparisonStatus.complete,
        comparison: result,
        targetSnapshot: target,
      );
    } catch (error) {
      if (_disposed ||
          generation != _generation ||
          !identical(state.baseline, baseline)) {
        return;
      }
      state = state.copyWith(
        status: RevisionComparisonStatus.failed,
        error: error.toString(),
      );
    }
  }
}

final revisionTrackingProvider =
    NotifierProvider<RevisionTrackingNotifier, RevisionTrackingState>(
      RevisionTrackingNotifier.new,
    );
