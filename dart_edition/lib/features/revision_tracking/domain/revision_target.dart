import '../../../domain/collaboration/collaboration_operation.dart';
import '../../../domain/collaboration/typed_operation_log.dart';

/// Navigation contract. Paths are segments, never translated labels or indices.
final class RevisionTarget {
  final String? chapterId;
  final int? hunkIndex;
  final ProjectRecordKey? recordKey;
  final List<String> fieldPath;

  RevisionTarget.chapter(String id, {this.hunkIndex})
    : chapterId = id,
      recordKey = null,
      fieldPath = const [];

  RevisionTarget.field(ProjectRecordKey key, Iterable<String> path)
    : chapterId = null,
      hunkIndex = null,
      recordKey = key,
      fieldPath = List.unmodifiable(path);

  ProjectRecordKind? get recordKind => recordKey?.kind;
}
