import 'dart:convert';
import '../../../domain/collaboration/collaboration_operation.dart';
import '../../../domain/collaboration/typed_operation_log.dart';
import '../domain/revision_models.dart';
import '../domain/revision_target.dart';
import 'revision_field_registry.dart';
import 'revision_text_diff_service.dart';

abstract final class RevisionRecordDiffService {
  static List<RevisionRecordChange> compare(
    RevisionSnapshot before,
    RevisionSnapshot after,
  ) {
    final result = <RevisionRecordChange>[];
    final moved = _movedRecords(before.records, after.records);
    final keys = {...before.records.keys, ...after.records.keys}.toList()
      ..sort((a, b) {
        final kind = a.kind.index.compareTo(b.kind.index);
        return kind != 0 ? kind : a.recordId.compareTo(b.recordId);
      });
    for (final key in keys) {
      final oldRecord = before.records[key];
      final newRecord = after.records[key];
      if (oldRecord == null || newRecord == null) {
        result.add(
          RevisionRecordChange(
            key: key,
            kind: oldRecord == null
                ? RevisionChangeKind.added
                : RevisionChangeKind.removed,
            before: oldRecord,
            after: newRecord,
          ),
        );
        continue;
      }
      final fields = <RevisionFieldChange>[];
      void walk(
        List<String> path,
        bool oldExists,
        Object? oldValue,
        bool newExists,
        Object? newValue,
      ) {
        if (key.kind == ProjectRecordKind.itemClass &&
            path.length == 2 &&
            path.first == 'defaultState' &&
            (path.last == 'name' || path.last == 'description') &&
            oldValue == oldRecord.fields[path.last] &&
            newValue == newRecord.fields[path.last]) {
          return;
        }
        if (oldExists && newExists && oldValue is Map && newValue is Map) {
          final names = {
            ...oldValue.keys.cast<String>(),
            ...newValue.keys.cast<String>(),
          }.toList()..sort();
          for (final name in names) {
            walk(
              [...path, name],
              oldValue.containsKey(name),
              oldValue[name],
              newValue.containsKey(name),
              newValue[name],
            );
          }
          return;
        }
        if (oldExists == newExists && _equal(oldValue, newValue)) return;
        fields.add(
          RevisionFieldChange(
            target: RevisionTarget.field(key, path),
            kind: !oldExists
                ? RevisionChangeKind.added
                : !newExists
                ? RevisionChangeKind.removed
                : RevisionChangeKind.modified,
            oldExists: oldExists,
            newExists: newExists,
            oldValue: oldValue,
            newValue: newValue,
          ),
        );
      }

      final names = {
        ...oldRecord.fields.keys,
        ...newRecord.fields.keys,
      }.toList()..sort();
      for (final name in names) {
        if (RevisionFieldRegistry.excluded(name)) continue;
        walk(
          [name],
          oldRecord.fields.containsKey(name),
          RevisionFieldRegistry.comparableField(name, oldRecord.fields[name]),
          newRecord.fields.containsKey(name),
          RevisionFieldRegistry.comparableField(name, newRecord.fields[name]),
        );
      }
      walk([r'$parent'], true, oldRecord.parentId, true, newRecord.parentId);
      if (moved.containsKey(key) && oldRecord.parentId == newRecord.parentId) {
        walk([r'$order'], true, moved[key]!.$1, true, moved[key]!.$2);
      }
      if (fields.isNotEmpty) {
        result.add(
          RevisionRecordChange(
            key: key,
            kind: RevisionChangeKind.modified,
            before: oldRecord,
            after: newRecord,
            fields: fields,
          ),
        );
      }
    }
    return List.unmodifiable(result);
  }

  static bool _equal(Object? a, Object? b) {
    if (a is Map && b is Map) {
      return a.length == b.length &&
          a.keys.every((key) => b.containsKey(key) && _equal(a[key], b[key]));
    }
    if (a is List && b is List) {
      return a.length == b.length &&
          Iterable<int>.generate(a.length).every((i) => _equal(a[i], b[i]));
    }
    return a == b;
  }

  /// Compare only surviving siblings; insert/delete index shifts are not moves.
  /// Chapter metadata and folders share one sibling order.
  static Map<ProjectRecordKey, (int, int)> _movedRecords(
    Map<ProjectRecordKey, RevisionRecord> before,
    Map<ProjectRecordKey, RevisionRecord> after,
  ) {
    String group(RevisionRecord record) => jsonEncode([
      RevisionFieldRegistry.pageFor(record.key.kind)?.name,
      record.parentId,
    ]);
    final groups = <String, List<RevisionRecord>>{};
    for (final record in before.values) {
      final current = after[record.key];
      if (current == null ||
          current.parentId != record.parentId ||
          record.fields['order'] is! int ||
          current.fields['order'] is! int) {
        continue;
      }
      groups.putIfAbsent(group(record), () => []).add(record);
    }
    final moved = <ProjectRecordKey, (int, int)>{};
    String identity(RevisionRecord record) =>
        jsonEncode([record.key.kind.name, record.key.recordId]);
    for (final siblings in groups.values) {
      siblings.sort(
        (a, b) =>
            (a.fields['order'] as int).compareTo(b.fields['order'] as int),
      );
      final current = siblings.map((record) => after[record.key]!).toList()
        ..sort(
          (a, b) =>
              (a.fields['order'] as int).compareTo(b.fields['order'] as int),
        );
      final diff = const RevisionTextDiffService().compare(
        chapterId: '',
        before: siblings.map(identity).join('\n'),
        after: current.map(identity).join('\n'),
      );
      final deleted = diff.lines
          .where((line) => line.kind == RevisionLineKind.removed)
          .map((line) => line.before!.text)
          .toSet();
      final newRanks = {
        for (var i = 0; i < current.length; i++) current[i].key: i,
      };
      for (var i = 0; i < siblings.length; i++) {
        final record = siblings[i];
        if (deleted.contains(identity(record))) {
          moved[record.key] = (i, newRanks[record.key]!);
        }
      }
    }
    return moved;
  }
}
