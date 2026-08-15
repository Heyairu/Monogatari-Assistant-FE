import "dart:collection";
import "dart:convert";

import "package:characters/characters.dart";

/// Current realtime collaboration wire schema.
///
/// This version is deliberately independent from the XML project-file
/// version. XML is a checkpoint/persistence format and never appears in a
/// realtime operation.
abstract final class CollaborationSchema {
  static const int currentVersion = 4;
  static const String projectTextDocumentPrefix = "projectText:";
  static const int maximumOperationsPerBatch = 128;
  static const int maximumInsertedTextBytes = 24 * 1024;
  static const int preferredInsertedTextChunkBytes = 4 * 1024;
  static const int maximumDeletedAtomsPerOperation = 1000000;
}

final class OperationId implements Comparable<OperationId> {
  final String replicaId;
  final int sequence;

  const OperationId({required this.replicaId, required this.sequence});

  factory OperationId.fromJson(Map<String, Object?> json) {
    _expectExactKeys(json, const <String>{"replicaId", "sequence"});
    return OperationId(
      replicaId: _requiredId(json, "replicaId"),
      sequence: _requiredPositiveInt(json, "sequence"),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    "replicaId": replicaId,
    "sequence": sequence,
  };

  @override
  int compareTo(OperationId other) {
    final bySequence = sequence.compareTo(other.sequence);
    return bySequence != 0 ? bySequence : replicaId.compareTo(other.replicaId);
  }

  @override
  bool operator ==(Object other) =>
      other is OperationId &&
      other.replicaId == replicaId &&
      other.sequence == sequence;

  @override
  int get hashCode => Object.hash(replicaId, sequence);

  @override
  String toString() => "$replicaId:$sequence";
}

/// Stable identity of one CRDT text atom.
///
/// [operationSequence] is zero only for deterministic XML checkpoint seed
/// atoms. Locally inserted atoms use the operation sequence that created them.
final class TextAtomId implements Comparable<TextAtomId> {
  final String replicaId;
  final int operationSequence;
  final int atomIndex;

  const TextAtomId({
    required this.replicaId,
    required this.operationSequence,
    required this.atomIndex,
  });

  factory TextAtomId.fromJson(Map<String, Object?> json) {
    _expectExactKeys(json, const <String>{
      "replicaId",
      "operationSequence",
      "atomIndex",
    });
    final operationSequence = json["operationSequence"];
    final atomIndex = json["atomIndex"];
    if (operationSequence is! int || operationSequence < 0) {
      throw const FormatException("CRDT atom operationSequence 無效。");
    }
    if (atomIndex is! int || atomIndex < 0) {
      throw const FormatException("CRDT atom atomIndex 無效。");
    }
    return TextAtomId(
      replicaId: _requiredId(json, "replicaId"),
      operationSequence: operationSequence,
      atomIndex: atomIndex,
    );
  }

  factory TextAtomId.seed(String documentId, int atomIndex) {
    if (documentId.trim().isEmpty || atomIndex < 0) {
      throw ArgumentError("CRDT seed document/id 無效。");
    }
    return TextAtomId(
      replicaId: "checkpoint:${documentId.trim()}",
      operationSequence: 0,
      atomIndex: atomIndex,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    "replicaId": replicaId,
    "operationSequence": operationSequence,
    "atomIndex": atomIndex,
  };

  @override
  int compareTo(TextAtomId other) {
    final bySequence = operationSequence.compareTo(other.operationSequence);
    if (bySequence != 0) return bySequence;
    final byReplica = replicaId.compareTo(other.replicaId);
    return byReplica != 0 ? byReplica : atomIndex.compareTo(other.atomIndex);
  }

  @override
  bool operator ==(Object other) =>
      other is TextAtomId &&
      other.replicaId == replicaId &&
      other.operationSequence == operationSequence &&
      other.atomIndex == atomIndex;

  @override
  int get hashCode => Object.hash(replicaId, operationSequence, atomIndex);

  @override
  String toString() => "$replicaId:$operationSequence:$atomIndex";
}

final class TextAtom {
  final TextAtomId id;
  final TextAtomId? parentId;
  final String value;

  const TextAtom({
    required this.id,
    required this.parentId,
    required this.value,
  });

  factory TextAtom.fromJson(Map<String, Object?> json) {
    _expectExactKeys(json, const <String>{"id", "parentId", "value"});
    final rawId = json["id"];
    final rawParentId = json["parentId"];
    final value = json["value"];
    if (rawId is! Map || value is! String || value.isEmpty) {
      throw const FormatException("CRDT text atom 無效。");
    }
    return TextAtom(
      id: TextAtomId.fromJson(_jsonObject(rawId, "atom.id")),
      parentId: rawParentId == null
          ? null
          : TextAtomId.fromJson(_jsonObject(rawParentId, "atom.parentId")),
      value: value,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    "id": id.toJson(),
    "parentId": parentId?.toJson(),
    "value": value,
  };
}

enum ProjectRecordKind {
  baseInfo,
  chapterFolder,
  chapterMetadata,
  outlineStoryline,
  outlineEvent,
  outlineScene,
  foreshadow,
  updatePlan,
  worldNode,
  character,
  characterState,
  characterStateBaseline,
  characterStateChange,
  timelineGrid,
  timelineTrack,
  timelinePlacement,
  outlineChapterLink,
}

enum ProjectRecordMutation { put, remove, move }

/// A typed ProjectData record operation.
///
/// Unlike JSON Patch, the target kind and mutation are closed enums and every
/// record has a stable id. [fields] is the versioned wire representation of
/// that specific record kind; the application codec validates its schema
/// before applying it to ProjectData.
final class ProjectRecordOperation {
  final ProjectRecordKind recordKind;
  final ProjectRecordMutation mutation;
  final String recordId;
  final String? parentId;
  final String? afterRecordId;
  final Map<String, Object?> fields;

  ProjectRecordOperation({
    required this.recordKind,
    required this.mutation,
    required this.recordId,
    this.parentId,
    this.afterRecordId,
    Map<String, Object?> fields = const <String, Object?>{},
  }) : fields = UnmodifiableMapView<String, Object?>(
         Map<String, Object?>.from(fields),
       ) {
    if (recordId.trim().isEmpty) {
      throw ArgumentError.value(recordId, "recordId", "不可為空");
    }
    if (mutation == ProjectRecordMutation.put && fields.isEmpty) {
      throw ArgumentError("put operation 必須包含 typed record fields。");
    }
    if (mutation == ProjectRecordMutation.remove && fields.isNotEmpty) {
      throw ArgumentError("remove operation 不可攜帶 record fields。");
    }
  }

  factory ProjectRecordOperation.fromJson(Map<String, Object?> json) {
    _expectExactKeys(json, const <String>{
      "recordKind",
      "mutation",
      "recordId",
      "parentId",
      "afterRecordId",
      "fields",
    });
    final rawKind = json["recordKind"];
    final rawMutation = json["mutation"];
    final rawFields = json["fields"];
    if (rawKind is! String || rawMutation is! String || rawFields is! Map) {
      throw const FormatException("typed ProjectData operation 無效。");
    }
    return ProjectRecordOperation(
      recordKind: _enumByName(ProjectRecordKind.values, rawKind, "recordKind"),
      mutation: _enumByName(
        ProjectRecordMutation.values,
        rawMutation,
        "mutation",
      ),
      recordId: _requiredId(json, "recordId"),
      parentId: _optionalId(json, "parentId"),
      afterRecordId: _optionalId(json, "afterRecordId"),
      fields: _jsonObject(rawFields, "fields"),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    "recordKind": recordKind.name,
    "mutation": mutation.name,
    "recordId": recordId,
    "parentId": parentId,
    "afterRecordId": afterRecordId,
    "fields": fields,
  };
}

sealed class CollaborationOperation {
  final OperationId id;
  final int lamport;

  const CollaborationOperation({required this.id, required this.lamport});

  String? get textDocumentId => null;

  Map<String, Object?> toJson();

  factory CollaborationOperation.fromJson(Map<String, Object?> json) {
    final type = json["type"];
    if (type is! String) {
      throw const FormatException("collaboration operation type 無效。");
    }
    return switch (type) {
      "textInsert" => TextInsertOperation.fromJson(json),
      "textDelete" => TextDeleteOperation.fromJson(json),
      "projectRecord" => ProjectDataRecordOperation.fromJson(json),
      _ => throw FormatException("未知 collaboration operation type: $type"),
    };
  }
}

final class TextInsertOperation extends CollaborationOperation {
  @override
  final String textDocumentId;
  final List<TextAtom> atoms;

  TextInsertOperation({
    required super.id,
    required super.lamport,
    required this.textDocumentId,
    required Iterable<TextAtom> atoms,
  }) : atoms = List<TextAtom>.unmodifiable(atoms) {
    _validateCommonOperation(id, lamport, textDocumentId);
    if (this.atoms.isEmpty) {
      throw ArgumentError("CRDT insert operation 不可為空。");
    }
    for (var index = 0; index < this.atoms.length; index += 1) {
      final atom = this.atoms[index];
      if (atom.id.replicaId != id.replicaId ||
          atom.id.operationSequence != id.sequence ||
          atom.id.atomIndex != index) {
        throw ArgumentError("CRDT insert atom id 未綁定 operation id。");
      }
      if (index > 0 && atom.parentId != this.atoms[index - 1].id) {
        throw ArgumentError("CRDT insert atom chain 不連續。");
      }
    }
  }

  factory TextInsertOperation.fromJson(Map<String, Object?> json) {
    _expectExactKeys(json, const <String>{
      "type",
      "id",
      "lamport",
      "documentId",
      "parentId",
      "text",
    });
    final id = _operationId(json);
    final rawParentId = json["parentId"];
    final text = json["text"];
    if (text is! String ||
        text.isEmpty ||
        utf8.encode(text).length >
            CollaborationSchema.maximumInsertedTextBytes) {
      throw const FormatException("CRDT insert text 無效或過大。");
    }
    TextAtomId? parentId = rawParentId == null
        ? null
        : TextAtomId.fromJson(_jsonObject(rawParentId, "insert.parentId"));
    final atoms = <TextAtom>[];
    var atomIndex = 0;
    for (final grapheme in text.characters) {
      final atomId = TextAtomId(
        replicaId: id.replicaId,
        operationSequence: id.sequence,
        atomIndex: atomIndex++,
      );
      atoms.add(TextAtom(id: atomId, parentId: parentId, value: grapheme));
      parentId = atomId;
    }
    return TextInsertOperation(
      id: id,
      lamport: _requiredPositiveInt(json, "lamport"),
      textDocumentId: _requiredId(json, "documentId"),
      atoms: atoms,
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    "type": "textInsert",
    "id": id.toJson(),
    "lamport": lamport,
    "documentId": textDocumentId,
    "parentId": atoms.first.parentId?.toJson(),
    "text": atoms.map((atom) => atom.value).join(),
  };
}

final class TextDeleteOperation extends CollaborationOperation {
  @override
  final String textDocumentId;
  final List<TextAtomId> atomIds;

  TextDeleteOperation({
    required super.id,
    required super.lamport,
    required this.textDocumentId,
    required Iterable<TextAtomId> atomIds,
  }) : atomIds = List<TextAtomId>.unmodifiable(atomIds) {
    _validateCommonOperation(id, lamport, textDocumentId);
    if (this.atomIds.isEmpty) {
      throw ArgumentError("CRDT delete operation 不可為空。");
    }
    if (this.atomIds.length >
        CollaborationSchema.maximumDeletedAtomsPerOperation) {
      throw ArgumentError("CRDT delete operation atom 數量超過上限。");
    }
  }

  factory TextDeleteOperation.fromJson(Map<String, Object?> json) {
    _expectExactKeys(json, const <String>{
      "type",
      "id",
      "lamport",
      "documentId",
      "atomSpans",
    });
    final rawSpans = json["atomSpans"];
    if (rawSpans is! List || rawSpans.isEmpty) {
      throw const FormatException("CRDT delete atomSpans 無效。");
    }
    final atomIds = <TextAtomId>[];
    for (final rawSpan in rawSpans) {
      final span = _jsonObject(rawSpan, "delete atom span");
      _expectExactKeys(span, const <String>{
        "replicaId",
        "operationSequence",
        "startAtomIndex",
        "endAtomIndex",
      });
      final replicaId = _requiredId(span, "replicaId");
      final operationSequence = span["operationSequence"];
      final startAtomIndex = span["startAtomIndex"];
      final endAtomIndex = span["endAtomIndex"];
      if (operationSequence is! int ||
          operationSequence < 0 ||
          startAtomIndex is! int ||
          startAtomIndex < 0 ||
          endAtomIndex is! int ||
          endAtomIndex < startAtomIndex ||
          endAtomIndex - startAtomIndex >=
              CollaborationSchema.maximumDeletedAtomsPerOperation) {
        throw const FormatException("CRDT delete atom span 範圍無效。");
      }
      final spanLength = endAtomIndex - startAtomIndex + 1;
      if (atomIds.length + spanLength >
          CollaborationSchema.maximumDeletedAtomsPerOperation) {
        throw const FormatException("CRDT delete atom 總數超過上限。");
      }
      for (
        var atomIndex = startAtomIndex;
        atomIndex <= endAtomIndex;
        atomIndex += 1
      ) {
        atomIds.add(
          TextAtomId(
            replicaId: replicaId,
            operationSequence: operationSequence,
            atomIndex: atomIndex,
          ),
        );
      }
    }
    return TextDeleteOperation(
      id: _operationId(json),
      lamport: _requiredPositiveInt(json, "lamport"),
      textDocumentId: _requiredId(json, "documentId"),
      atomIds: atomIds,
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    "type": "textDelete",
    "id": id.toJson(),
    "lamport": lamport,
    "documentId": textDocumentId,
    "atomSpans": _compactAtomIdSpans(atomIds),
  };
}

List<Map<String, Object?>> _compactAtomIdSpans(List<TextAtomId> atomIds) {
  final spans = <Map<String, Object?>>[];
  for (final atomId in atomIds) {
    final previous = spans.isEmpty ? null : spans.last;
    final canExtend =
        previous != null &&
        previous["replicaId"] == atomId.replicaId &&
        previous["operationSequence"] == atomId.operationSequence &&
        previous["endAtomIndex"] == atomId.atomIndex - 1;
    if (canExtend) {
      previous["endAtomIndex"] = atomId.atomIndex;
    } else {
      spans.add(<String, Object?>{
        "replicaId": atomId.replicaId,
        "operationSequence": atomId.operationSequence,
        "startAtomIndex": atomId.atomIndex,
        "endAtomIndex": atomId.atomIndex,
      });
    }
  }
  return spans;
}

final class ProjectDataRecordOperation extends CollaborationOperation {
  static const String projectWideChannel = "@project";

  final ProjectRecordOperation record;

  const ProjectDataRecordOperation({
    required super.id,
    required super.lamport,
    required this.record,
  });

  factory ProjectDataRecordOperation.fromJson(Map<String, Object?> json) {
    _expectExactKeys(json, const <String>{"type", "id", "lamport", "record"});
    return ProjectDataRecordOperation(
      id: _operationId(json),
      lamport: _requiredPositiveInt(json, "lamport"),
      record: ProjectRecordOperation.fromJson(
        _jsonObject(json["record"], "project record"),
      ),
    );
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    "type": "projectRecord",
    "id": id.toJson(),
    "lamport": lamport,
    "record": record.toJson(),
  };
}

void _validateCommonOperation(
  OperationId operationId,
  int lamport,
  String documentId,
) {
  if (operationId.replicaId.trim().isEmpty || operationId.sequence < 1) {
    throw ArgumentError("collaboration operation id 無效。");
  }
  if (lamport < 1 || documentId.trim().isEmpty) {
    throw ArgumentError("collaboration operation clock/document 無效。");
  }
}

OperationId _operationId(Map<String, Object?> json) =>
    OperationId.fromJson(_jsonObject(json["id"], "operation.id"));

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
    throw const FormatException("collaboration JSON schema 欄位不符。");
  }
}

String _requiredId(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty || value.length > 256) {
    throw FormatException("$key 無效。");
  }
  return value.trim();
}

String? _optionalId(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty || value.length > 256) {
    throw FormatException("$key 無效。");
  }
  return value.trim();
}

int _requiredPositiveInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int || value < 1) throw FormatException("$key 無效。");
  return value;
}

T _enumByName<T extends Enum>(List<T> values, String name, String label) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException("$label 無效。");
}
