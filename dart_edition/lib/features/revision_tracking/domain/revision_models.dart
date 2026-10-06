import '../../../domain/collaboration/collaboration_operation.dart';
import '../../../domain/collaboration/typed_operation_log.dart';
import 'revision_target.dart';

enum RevisionChangeKind { added, removed, modified }

enum RevisionComparisonStatus {
  notStarted,
  computing,
  complete,
  failed,
  unavailable,
}

/// Owns its values recursively, including nested maps and lists.
Object? freezeRevisionValue(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable(
      value.map(
        (key, item) => MapEntry(key as String, freezeRevisionValue(item)),
      ),
    );
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(freezeRevisionValue));
  }
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  throw ArgumentError.value(value, 'value', 'Expected a JSON-compatible value');
}

final class RevisionRecord {
  final ProjectRecordKey key;
  final String? parentId;
  final Map<String, Object?> fields;

  RevisionRecord({
    required this.key,
    this.parentId,
    required Map<String, Object?> fields,
  }) : fields = freezeRevisionValue(fields) as Map<String, Object?>;
}

/// Detached comparison projection; no mutable ProjectData or wire operations.
final class RevisionSnapshot {
  final String projectId;
  final String version;
  final Map<String, String> chapterTexts;
  final Map<ProjectRecordKey, RevisionRecord> records;
  final Set<ProjectRecordKind> unsupportedKinds;

  RevisionSnapshot({
    required this.projectId,
    required this.version,
    required Map<String, String> chapterTexts,
    required Map<ProjectRecordKey, RevisionRecord> records,
    required Set<ProjectRecordKind> unsupportedKinds,
  }) : chapterTexts = Map.unmodifiable(chapterTexts),
       records = Map.unmodifiable(records),
       unsupportedKinds = Set.unmodifiable(unsupportedKinds);
}

final class RevisionBaseline {
  final String id;
  final String label;
  final DateTime createdAt;
  final RevisionSnapshot snapshot;

  /// Historical sources are comparison-only and never expose review mutations.
  final bool readOnly;
  final String? sourceRevisionId;

  const RevisionBaseline({
    required this.id,
    required this.label,
    required this.createdAt,
    required this.snapshot,
    this.readOnly = false,
    this.sourceRevisionId,
  });
}

final class RevisionFieldChange {
  final RevisionTarget target;
  final RevisionChangeKind kind;

  /// Distinguishes an absent field from a present null value.
  final bool oldExists;
  final bool newExists;
  final Object? oldValue;
  final Object? newValue;

  RevisionFieldChange({
    required this.target,
    required this.kind,
    required this.oldExists,
    required this.newExists,
    required Object? oldValue,
    required Object? newValue,
  }) : oldValue = freezeRevisionValue(oldValue),
       newValue = freezeRevisionValue(newValue);
}

final class RevisionRecordChange {
  final ProjectRecordKey key;
  final RevisionChangeKind kind;
  final RevisionRecord? before;
  final RevisionRecord? after;
  final List<RevisionFieldChange> fields;

  RevisionRecordChange({
    required this.key,
    required this.kind,
    this.before,
    this.after,
    Iterable<RevisionFieldChange> fields = const [],
  }) : fields = List.unmodifiable(fields);
}

final class RevisionLogicalLine {
  final String text;
  final int number;

  /// UTF-16 offsets in the original, possibly CRLF, document.
  final int startOffset;
  final int endOffset;
  const RevisionLogicalLine(
    this.text,
    this.number,
    this.startOffset,
    this.endOffset,
  );
}

enum RevisionLineKind { equal, added, removed }

final class RevisionLineChange {
  final RevisionLineKind kind;
  final RevisionLogicalLine? before;
  final RevisionLogicalLine? after;
  const RevisionLineChange(this.kind, {this.before, this.after});
}

final class RevisionTextHunk {
  final List<RevisionLineChange> lines;

  /// Zero-based line insertion boundaries for both versions.
  final int oldStart;
  final int newStart;
  final int oldOffset;
  final int newOffset;
  RevisionTextHunk({
    required Iterable<RevisionLineChange> lines,
    required this.oldStart,
    required this.newStart,
    required this.oldOffset,
    required this.newOffset,
  }) : lines = List.unmodifiable(lines);
}

final class RevisionTextDiff {
  final String chapterId;
  final List<RevisionLineChange> lines;
  final List<RevisionTextHunk> hunks;
  final bool oldTrailingNewline;
  final bool newTrailingNewline;

  /// Budget fallback remains correct but may not be a minimal edit script.
  final bool isCoarse;
  RevisionTextDiff({
    required this.chapterId,
    required Iterable<RevisionLineChange> lines,
    required Iterable<RevisionTextHunk> hunks,
    required this.oldTrailingNewline,
    required this.newTrailingNewline,
    required this.isCoarse,
  }) : lines = List.unmodifiable(lines),
       hunks = List.unmodifiable(hunks);
  int get addedLines =>
      lines.where((line) => line.kind == RevisionLineKind.added).length;
  int get removedLines =>
      lines.where((line) => line.kind == RevisionLineKind.removed).length;
  bool get trailingNewlineChanged => oldTrailingNewline != newTrailingNewline;
  bool get hasChanges => hunks.isNotEmpty || trailingNewlineChanged;
}

final class RevisionComparison {
  final String baselineVersion;
  final String targetVersion;
  final List<RevisionTextDiff> texts;
  final List<RevisionRecordChange> records;
  final Set<ProjectRecordKind> unsupportedKinds;
  RevisionComparison({
    required this.baselineVersion,
    required this.targetVersion,
    required Iterable<RevisionTextDiff> texts,
    required Iterable<RevisionRecordChange> records,
    required Set<ProjectRecordKind> unsupportedKinds,
  }) : texts = List.unmodifiable(texts),
       records = List.unmodifiable(records),
       unsupportedKinds = Set.unmodifiable(unsupportedKinds);
  int get addedLines => texts.fold(0, (count, text) => count + text.addedLines);
  int get removedLines =>
      texts.fold(0, (count, text) => count + text.removedLines);
  int recordCount(RevisionChangeKind kind) =>
      records.where((record) => record.kind == kind).length;
  bool get hasChanges => texts.isNotEmpty || records.isNotEmpty;
}
