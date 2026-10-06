import 'dart:convert';
import '../../../domain/collaboration/collaboration_operation.dart';

import '../domain/revision_models.dart';

/// Review identity includes both sides, so a later edit is pending again.
abstract final class RevisionReviewService {
  static String _withoutTrailingNewline(String text) => text.endsWith('\r\n')
      ? text.substring(0, text.length - 2)
      : text.endsWith('\n')
      ? text.substring(0, text.length - 1)
      : text;

  static bool canRejectField(
    RevisionRecordChange record,
    RevisionFieldChange field,
  ) {
    if (field.target.fieldPath.length != 1 ||
        !field.oldExists ||
        field.oldValue is! String ||
        field.newValue is! String) {
      return false;
    }
    final name = field.target.fieldPath.single;
    return switch (record.key.kind) {
      ProjectRecordKind.baseInfo => const {
        'bookName',
        'author',
        'purpose',
        'toRecap',
        'storyType',
        'intro',
      }.contains(name),
      ProjectRecordKind.chapterFolder ||
      ProjectRecordKind.chapterMetadata => name == 'name',
      ProjectRecordKind.worldNode => const {
        'name',
        'localType',
        'note',
      }.contains(name),
      ProjectRecordKind.character => const {
        'displayName',
        'roleOrOccupation',
        'age',
        'gender',
        'appearanceSummary',
        'personalitySummary',
        'speechStyle',
        'motivation',
        'goal',
        'valuesAndBeliefs',
        'fear',
        'relationshipSummary',
        'notes',
      }.contains(name),
      ProjectRecordKind.outlineStoryline => const {
        'name',
        'type',
        'memo',
        'conflictPoint',
      }.contains(name),
      ProjectRecordKind.outlineEvent => const {
        'event',
        'memo',
        'conflictPoint',
      }.contains(name),
      ProjectRecordKind.outlineScene => const {
        'name',
        'time',
        'location',
        'focusPoint',
        'conflictPoint',
        'memo',
      }.contains(name),
      ProjectRecordKind.itemClass => const {
        'name',
        'description',
        'category',
        'unit',
      }.contains(name),
      ProjectRecordKind.itemInstance => name == 'name',
      _ => false,
    };
  }

  static String textKey(
    RevisionBaseline baseline,
    RevisionTextDiff text,
    RevisionTextHunk hunk,
  ) => jsonEncode([
    baseline.id,
    'text',
    text.chapterId,
    hunk.oldStart,
    hunk.newStart,
    for (final line in hunk.lines)
      [line.kind.name, line.before?.text, line.after?.text],
    if (hunk.lines.isEmpty) [text.oldTrailingNewline, text.newTrailingNewline],
  ]);

  static String recordKey(
    RevisionBaseline baseline,
    RevisionRecordChange record,
    RevisionFieldChange? field,
  ) => jsonEncode([
    baseline.id,
    'record',
    record.key.kind.name,
    record.key.recordId,
    if (field == null) ...[
      record.kind.name,
      record.before?.parentId,
      record.before?.fields,
      record.after?.parentId,
      record.after?.fields,
    ] else ...[
      field.target.fieldPath,
      field.oldExists,
      field.oldValue,
      field.newExists,
      field.newValue,
    ],
  ]);

  /// Reverts one current-text hunk. Requires the exact text used by the diff.
  /// The caller must independently check that this is still the live chapter.
  static String rejectTextHunk({
    required String before,
    required String after,
    required RevisionTextDiff diff,
    required RevisionTextHunk hunk,
  }) {
    if (!diff.hunks.contains(hunk)) throw StateError('Stale revision hunk');
    if (hunk.lines.isEmpty) {
      if (!diff.trailingNewlineChanged) {
        throw StateError('No trailing newline revision');
      }
      if (diff.oldTrailingNewline) {
        final ending = before.endsWith('\r\n') ? '\r\n' : '\n';
        return after.endsWith('\n') ? after : '$after$ending';
      }
      return _withoutTrailingNewline(after);
    }
    final oldEndLine =
        hunk.oldStart +
        hunk.lines.where((line) => line.kind != RevisionLineKind.added).length;
    final newEndLine =
        hunk.newStart +
        hunk.lines
            .where((line) => line.kind != RevisionLineKind.removed)
            .length;
    final nextEqual = diff.lines
        .where(
          (line) =>
              line.kind == RevisionLineKind.equal &&
              line.before!.number - 1 >= oldEndLine &&
              line.after!.number - 1 >= newEndLine,
        )
        .firstOrNull;
    var oldStart = hunk.oldOffset;
    var newStart = hunk.newOffset;
    final oldEnd = nextEqual?.before?.startOffset ?? before.length;
    final newEnd = nextEqual?.after?.startOffset ?? after.length;
    if (nextEqual == null && hunk.oldStart > 0 && hunk.newStart > 0) {
      final preceding = diff.lines.lastWhere(
        (line) =>
            line.kind == RevisionLineKind.equal &&
            line.before!.number - 1 < hunk.oldStart &&
            line.after!.number - 1 < hunk.newStart,
      );
      oldStart = preceding.before!.endOffset;
      newStart = preceding.after!.endOffset;
    }
    if (oldStart < 0 ||
        newStart < 0 ||
        oldEnd < oldStart ||
        newEnd < newStart ||
        oldEnd > before.length ||
        newEnd > after.length) {
      throw StateError('Invalid revision offsets');
    }
    var restored = after.replaceRange(
      newStart,
      newEnd,
      before.substring(oldStart, oldEnd),
    );
    if (diff.trailingNewlineChanged && nextEqual == null) {
      if (after.endsWith('\n') && !restored.endsWith('\n')) {
        restored += after.endsWith('\r\n') ? '\r\n' : '\n';
      } else if (!after.endsWith('\n') && restored.endsWith('\n')) {
        restored = _withoutTrailingNewline(restored);
      }
    }
    return restored;
  }

  /// Applies all selected hunks against one unchanged comparison snapshot.
  /// Right-to-left edits keep every earlier UTF-16 offset valid.
  static String rejectTextHunks({
    required String before,
    required String after,
    required RevisionTextDiff diff,
    required Iterable<RevisionTextHunk> hunks,
  }) {
    final selected = hunks.toSet();
    if (selected.isEmpty || !diff.hunks.toSet().containsAll(selected)) {
      throw StateError('Invalid revision selection');
    }
    if (selected.length == diff.hunks.length) return before;
    final trailing = selected.where((hunk) => hunk.lines.isEmpty).toList();
    final content = selected.where((hunk) => hunk.lines.isNotEmpty).toList()
      ..sort((left, right) => right.newOffset.compareTo(left.newOffset));
    var result = after;
    for (final hunk in content) {
      result = rejectTextHunk(
        before: before,
        after: result,
        diff: diff,
        hunk: hunk,
      );
    }
    for (final hunk in trailing) {
      result = rejectTextHunk(
        before: before,
        after: result,
        diff: diff,
        hunk: hunk,
      );
    }
    return result;
  }
}
