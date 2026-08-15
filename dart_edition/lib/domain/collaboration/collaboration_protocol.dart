import "dart:collection";

import "collaboration_operation.dart";
import "collaborative_text.dart";

sealed class CollaborationCursorTarget {
  const CollaborationCursorTarget();

  bool get isCollapsed;

  factory CollaborationCursorTarget.fromJson(Map<String, Object?> json) {
    final kind = json["kind"];
    return switch (kind) {
      "chapterText" => ChapterTextCursorTarget.fromJson(json),
      "projectText" => ProjectTextCursorTarget.fromJson(json),
      "projectField" => ProjectFieldCursorTarget.fromJson(json),
      _ => throw const FormatException("presence cursor target kind 無效。"),
    };
  }

  Map<String, Object?> toJson();
}

final class ProjectTextCursorTarget extends CollaborationCursorTarget {
  final String documentId;
  final TextCursorAnchor anchor;
  final TextCursorAnchor focus;

  const ProjectTextCursorTarget({
    required this.documentId,
    required this.anchor,
    required this.focus,
  });

  factory ProjectTextCursorTarget.fromJson(Map<String, Object?> json) {
    _expectExactKeys(json, const <String>{
      "kind",
      "documentId",
      "anchor",
      "focus",
    });
    final documentId = _requiredString(json, "documentId");
    if (!documentId.startsWith(CollaborationSchema.projectTextDocumentPrefix)) {
      throw const FormatException("project text cursor document id 無效。");
    }
    return ProjectTextCursorTarget(
      documentId: documentId,
      anchor: TextCursorAnchor.fromJson(
        _jsonObject(json["anchor"], "presence.target.anchor"),
      ),
      focus: TextCursorAnchor.fromJson(
        _jsonObject(json["focus"], "presence.target.focus"),
      ),
    );
  }

  @override
  bool get isCollapsed =>
      anchor.atomId == focus.atomId &&
      anchor.fallbackOffset == focus.fallbackOffset;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    "kind": "projectText",
    "documentId": documentId,
    "anchor": anchor.toJson(),
    "focus": focus.toJson(),
  };
}

final class ChapterTextCursorTarget extends CollaborationCursorTarget {
  final String chapterId;
  final TextCursorAnchor anchor;
  final TextCursorAnchor focus;

  const ChapterTextCursorTarget({
    required this.chapterId,
    required this.anchor,
    required this.focus,
  });

  factory ChapterTextCursorTarget.fromJson(Map<String, Object?> json) {
    _expectExactKeys(json, const <String>{
      "kind",
      "chapterId",
      "anchor",
      "focus",
    });
    return ChapterTextCursorTarget(
      chapterId: _requiredString(json, "chapterId"),
      anchor: TextCursorAnchor.fromJson(
        _jsonObject(json["anchor"], "presence.target.anchor"),
      ),
      focus: TextCursorAnchor.fromJson(
        _jsonObject(json["focus"], "presence.target.focus"),
      ),
    );
  }

  @override
  bool get isCollapsed =>
      anchor.atomId == focus.atomId &&
      anchor.fallbackOffset == focus.fallbackOffset;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    "kind": "chapterText",
    "chapterId": chapterId,
    "anchor": anchor.toJson(),
    "focus": focus.toJson(),
  };
}

final class ProjectFieldCursorTarget extends CollaborationCursorTarget {
  final String fieldId;
  final int anchorOffset;
  final int focusOffset;

  const ProjectFieldCursorTarget({
    required this.fieldId,
    required this.anchorOffset,
    required this.focusOffset,
  });

  factory ProjectFieldCursorTarget.fromJson(Map<String, Object?> json) {
    _expectExactKeys(json, const <String>{
      "kind",
      "fieldId",
      "anchorOffset",
      "focusOffset",
    });
    final anchorOffset = json["anchorOffset"];
    final focusOffset = json["focusOffset"];
    if (anchorOffset is! int ||
        focusOffset is! int ||
        anchorOffset < 0 ||
        focusOffset < 0) {
      throw const FormatException("project field cursor offset 無效。");
    }
    return ProjectFieldCursorTarget(
      fieldId: _requiredString(json, "fieldId"),
      anchorOffset: anchorOffset,
      focusOffset: focusOffset,
    );
  }

  @override
  bool get isCollapsed => anchorOffset == focusOffset;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    "kind": "projectField",
    "fieldId": fieldId,
    "anchorOffset": anchorOffset,
    "focusOffset": focusOffset,
  };
}

final class CollaboratorPresence {
  final String replicaId;
  final String ipAddress;
  final CollaborationCursorTarget target;
  final int presenceSequence;
  final int sentAtEpochMs;

  const CollaboratorPresence({
    required this.replicaId,
    required this.ipAddress,
    required this.target,
    required this.presenceSequence,
    required this.sentAtEpochMs,
  });

  bool get isCollapsed => target.isCollapsed;

  String get cursorLabel => ipAddress;

  factory CollaboratorPresence.fromJson(Map<String, Object?> json) {
    const expected = <String>{
      "replicaId",
      "ipAddress",
      "target",
      "presenceSequence",
      "sentAtEpochMs",
    };
    _expectExactKeys(json, expected);
    final presenceSequence = json["presenceSequence"];
    final sentAtEpochMs = json["sentAtEpochMs"];
    if (presenceSequence is! int || presenceSequence < 1) {
      throw const FormatException("presence sequence 無效。");
    }
    if (sentAtEpochMs is! int || sentAtEpochMs < 0) {
      throw const FormatException("presence timestamp 無效。");
    }
    final ipAddress = _requiredString(json, "ipAddress");
    if (!_isIpv4(ipAddress)) {
      throw const FormatException("presence IP address 無效。");
    }
    return CollaboratorPresence(
      replicaId: _requiredString(json, "replicaId"),
      ipAddress: ipAddress,
      target: CollaborationCursorTarget.fromJson(
        _jsonObject(json["target"], "presence.target"),
      ),
      presenceSequence: presenceSequence,
      sentAtEpochMs: sentAtEpochMs,
    );
  }

  CollaboratorPresence withObservedIpAddress(String observedIpAddress) {
    if (!_isIpv4(observedIpAddress)) {
      throw const FormatException("socket observed IP address 無效。");
    }
    return CollaboratorPresence(
      replicaId: replicaId,
      ipAddress: observedIpAddress,
      target: target,
      presenceSequence: presenceSequence,
      sentAtEpochMs: sentAtEpochMs,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    "replicaId": replicaId,
    "ipAddress": ipAddress,
    "target": target.toJson(),
    "presenceSequence": presenceSequence,
    "sentAtEpochMs": sentAtEpochMs,
  };
}

/// One encrypted realtime exchange. It contains operations and acknowledgments
/// only; XML, file paths and whole-project snapshots are forbidden by schema.
final class CollaborationSyncBatch {
  final int schemaVersion;
  final String projectUuid;
  final String senderReplicaId;
  final Map<String, int> acknowledgedSequences;
  final List<CollaborationOperation> operations;
  final CollaboratorPresence? presence;

  CollaborationSyncBatch({
    this.schemaVersion = CollaborationSchema.currentVersion,
    required this.projectUuid,
    required this.senderReplicaId,
    Map<String, int> acknowledgedSequences = const <String, int>{},
    Iterable<CollaborationOperation> operations =
        const <CollaborationOperation>[],
    this.presence,
  }) : acknowledgedSequences = UnmodifiableMapView<String, int>(
         Map<String, int>.from(acknowledgedSequences),
       ),
       operations = List<CollaborationOperation>.unmodifiable(operations) {
    _validate();
  }

  factory CollaborationSyncBatch.fromJson(Map<String, Object?> json) {
    const expected = <String>{
      "schemaVersion",
      "projectUuid",
      "senderReplicaId",
      "acknowledgedSequences",
      "operations",
      "presence",
    };
    _expectExactKeys(json, expected);
    final schemaVersion = json["schemaVersion"];
    final rawAcks = json["acknowledgedSequences"];
    final rawOperations = json["operations"];
    if (schemaVersion is! int || rawAcks is! Map || rawOperations is! List) {
      throw const FormatException("collaboration sync batch 無效。");
    }
    final acks = <String, int>{};
    for (final entry in rawAcks.entries) {
      if (entry.key is! String || entry.value is! int || entry.value < 0) {
        throw const FormatException("collaboration ack vector 無效。");
      }
      acks[entry.key as String] = entry.value as int;
    }
    final rawPresence = json["presence"];
    return CollaborationSyncBatch(
      schemaVersion: schemaVersion,
      projectUuid: _requiredString(json, "projectUuid").toLowerCase(),
      senderReplicaId: _requiredString(json, "senderReplicaId"),
      acknowledgedSequences: acks,
      operations: rawOperations.map(
        (raw) => CollaborationOperation.fromJson(
          _jsonObject(raw, "collaboration operation"),
        ),
      ),
      presence: rawPresence == null
          ? null
          : CollaboratorPresence.fromJson(_jsonObject(rawPresence, "presence")),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    "schemaVersion": schemaVersion,
    "projectUuid": projectUuid,
    "senderReplicaId": senderReplicaId,
    "acknowledgedSequences": acknowledgedSequences,
    "operations": operations
        .map((operation) => operation.toJson())
        .toList(growable: false),
    "presence": presence?.toJson(),
  };

  CollaborationSyncBatch withObservedIpAddress(String ipAddress) {
    final currentPresence = presence;
    if (currentPresence == null) return this;
    return CollaborationSyncBatch(
      schemaVersion: schemaVersion,
      projectUuid: projectUuid,
      senderReplicaId: senderReplicaId,
      acknowledgedSequences: acknowledgedSequences,
      operations: operations,
      presence: currentPresence.withObservedIpAddress(ipAddress),
    );
  }

  void _validate() {
    if (schemaVersion != CollaborationSchema.currentVersion) {
      throw const FormatException("不支援的 collaboration schema version。");
    }
    if (!RegExp(
      r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
    ).hasMatch(projectUuid.toLowerCase())) {
      throw const FormatException("collaboration project UUID 無效。");
    }
    if (senderReplicaId.trim().isEmpty || senderReplicaId.length > 256) {
      throw const FormatException("collaboration sender replica 無效。");
    }
    if (operations.length > CollaborationSchema.maximumOperationsPerBatch) {
      throw const FormatException("collaboration batch operation 數量超限。");
    }
    final ids = <OperationId>{};
    for (final operation in operations) {
      if (!ids.add(operation.id)) {
        throw const FormatException("collaboration batch 含重複 operation id。");
      }
    }
    for (final entry in acknowledgedSequences.entries) {
      if (entry.key.trim().isEmpty || entry.value < 0) {
        throw const FormatException("collaboration ack vector 無效。");
      }
    }
    if (presence case final value?) {
      if (value.replicaId != senderReplicaId) {
        throw const FormatException("presence replica 與 batch sender 不符。");
      }
    }
  }
}

Map<String, Object?> _jsonObject(Object? value, String label) {
  if (value is! Map) throw FormatException("$label 必須是 JSON object。");
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException("$label 含非字串 key。");
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

void _expectExactKeys(Map<String, Object?> json, Set<String> expected) {
  if (json.length != expected.length || !json.keys.every(expected.contains)) {
    throw const FormatException("collaboration protocol schema 欄位不符。");
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty || value.length > 256) {
    throw FormatException("$key 無效。");
  }
  return value.trim();
}

bool _isIpv4(String value) {
  final parts = value.split(".");
  if (parts.length != 4) return false;
  for (final part in parts) {
    final number = int.tryParse(part);
    if (number == null || number < 0 || number > 255) return false;
    if (part != number.toString()) return false;
  }
  return true;
}
