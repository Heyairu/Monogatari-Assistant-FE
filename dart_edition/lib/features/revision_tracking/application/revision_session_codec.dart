import 'dart:convert';

import '../../../domain/collaboration/collaboration_operation.dart';
import '../../../domain/collaboration/typed_operation_log.dart';
import '../domain/revision_models.dart';
import 'revision_field_registry.dart';

final class RevisionSessionData {
  final String selectedBaselineId;
  final List<RevisionBaseline> baselines;

  /// Exact event keys, including before and after values. A changed event no
  /// longer matches an accepted key and becomes pending again.
  final Set<String> acceptedEvents;
  const RevisionSessionData({
    required this.selectedBaselineId,
    required this.baselines,
    required this.acceptedEvents,
  });
}

abstract final class RevisionSessionCodec {
  static const int schemaVersion = 2;

  /// Only decisions participate in project Undo equality, not large baselines.
  static String decisionDigest(String? serialized) {
    if (serialized == null) return '[]';
    try {
      final root = jsonDecode(serialized);
      final values = root is Map ? root['acceptedEvents'] : null;
      if (values is! List || values.any((value) => value is! String)) {
        return '[]';
      }
      return jsonEncode(values.cast<String>().toList()..sort());
    } catch (_) {
      return '[]';
    }
  }

  static String encode(RevisionSessionData session) => jsonEncode({
    'schemaVersion': schemaVersion,
    'selectedBaselineId': session.selectedBaselineId,
    'baselines': session.baselines.map(_baselineToJson).toList(),
    'acceptedEvents': session.acceptedEvents.toList()..sort(),
  });

  static RevisionSessionData decode(String json, {required String projectId}) {
    final root = jsonDecode(json);
    if (root is! Map ||
        (root['schemaVersion'] != 1 &&
            root['schemaVersion'] != schemaVersion) ||
        root['baselines'] is! List ||
        root['acceptedEvents'] is! List ||
        root['selectedBaselineId'] is! String) {
      throw const FormatException('Unsupported revision tracking session');
    }
    final baselines = <RevisionBaseline>[
      for (final item in root['baselines'] as List)
        _baselineFromJson(item, projectId),
    ];
    final selected = root['selectedBaselineId'] as String;
    if (baselines.isEmpty ||
        !baselines.any((item) => item.id == selected) ||
        baselines.map((item) => item.id).toSet().length != baselines.length) {
      throw const FormatException('Invalid revision tracking baseline IDs');
    }
    final rawAccepted = root['acceptedEvents'] as List;
    if (rawAccepted.any((value) => value is! String)) {
      throw const FormatException('Invalid revision decision');
    }
    return RevisionSessionData(
      selectedBaselineId: selected,
      baselines: List.unmodifiable(baselines),
      acceptedEvents: Set.unmodifiable(rawAccepted.cast<String>()),
    );
  }

  static Map<String, Object?> _baselineToJson(RevisionBaseline baseline) => {
    'id': baseline.id,
    'label': baseline.label,
    'createdAt': baseline.createdAt.toUtc().toIso8601String(),
    'readOnly': baseline.readOnly,
    if (baseline.sourceRevisionId != null)
      'sourceRevisionId': baseline.sourceRevisionId,
    'snapshot': {
      'projectId': baseline.snapshot.projectId,
      'version': baseline.snapshot.version,
      'chapters': baseline.snapshot.chapterTexts,
      'records': [
        for (final record in baseline.snapshot.records.values)
          {
            'kind': record.key.kind.name,
            'id': record.key.recordId,
            'parentId': record.parentId,
            'fields': record.fields,
          },
      ],
    },
  };

  static RevisionBaseline _baselineFromJson(Object? raw, String projectId) {
    if (raw is! Map ||
        raw['id'] is! String ||
        raw['label'] is! String ||
        raw['createdAt'] is! String ||
        (raw['readOnly'] != null && raw['readOnly'] is! bool) ||
        (raw['sourceRevisionId'] != null &&
            raw['sourceRevisionId'] is! String) ||
        raw['snapshot'] is! Map) {
      throw const FormatException('Invalid revision baseline');
    }
    final snapshot = raw['snapshot'] as Map;
    if (snapshot['projectId'] != projectId ||
        snapshot['version'] is! String ||
        snapshot['chapters'] is! Map ||
        snapshot['records'] is! List) {
      throw const FormatException(
        'Revision baseline belongs to another project',
      );
    }
    final chapterTexts = <String, String>{};
    for (final entry in (snapshot['chapters'] as Map).entries) {
      if (entry.key is! String ||
          entry.value is! String ||
          chapterTexts.containsKey(entry.key)) {
        throw const FormatException('Invalid chapter baseline');
      }
      chapterTexts[entry.key as String] = entry.value as String;
    }
    final records = <ProjectRecordKey, RevisionRecord>{};
    for (final entry in snapshot['records'] as List) {
      if (entry is! Map ||
          entry['kind'] is! String ||
          entry['id'] is! String ||
          entry['fields'] is! Map ||
          (entry['parentId'] != null && entry['parentId'] is! String)) {
        throw const FormatException('Invalid record baseline');
      }
      final kind = ProjectRecordKind.values
          .where((kind) => kind.name == entry['kind'])
          .firstOrNull;
      if (kind == null) throw const FormatException('Unknown record kind');
      final key = ProjectRecordKey(kind: kind, recordId: entry['id'] as String);
      if (records.containsKey(key)) {
        throw const FormatException('Duplicate record baseline');
      }
      records[key] = RevisionRecord(
        key: key,
        parentId: entry['parentId'] as String?,
        fields: Map<String, Object?>.from(entry['fields'] as Map),
      );
    }
    DateTime createdAt;
    try {
      createdAt = DateTime.parse(raw['createdAt'] as String).toUtc();
    } on FormatException {
      throw const FormatException('Invalid baseline time');
    }
    return RevisionBaseline(
      id: raw['id'] as String,
      label: raw['label'] as String,
      createdAt: createdAt,
      snapshot: RevisionSnapshot(
        projectId: projectId,
        version: snapshot['version'] as String,
        chapterTexts: chapterTexts,
        records: records,
        unsupportedKinds: ProjectRecordKind.values.toSet().difference(
          RevisionFieldRegistry.supportedKinds,
        ),
      ),
      readOnly: raw['readOnly'] == true,
      sourceRevisionId: raw['sourceRevisionId'] as String?,
    );
  }
}
