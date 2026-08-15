import "dart:collection";

import "collaboration_operation.dart";

final class ProjectRecordKey {
  final ProjectRecordKind kind;
  final String recordId;

  const ProjectRecordKey({required this.kind, required this.recordId});

  @override
  bool operator ==(Object other) =>
      other is ProjectRecordKey &&
      other.kind == kind &&
      other.recordId == recordId;

  @override
  int get hashCode => Object.hash(kind, recordId);
}

final class ProjectRecordState {
  final ProjectRecordOperation operation;
  final int lamport;
  final OperationId operationId;

  const ProjectRecordState({
    required this.operation,
    required this.lamport,
    required this.operationId,
  });

  bool get isRemoved => operation.mutation == ProjectRecordMutation.remove;
}

/// Deterministic LWW reducer for non-text ProjectData records.
///
/// The log keeps typed operations, not serialized ProjectData or XML. Lamport
/// time is the primary order and operation id is the deterministic tie-breaker.
final class TypedProjectOperationLog {
  final Map<ProjectRecordKey, ProjectRecordState> _records;
  final Map<OperationId, ProjectDataRecordOperation> _operations;
  final Map<String, int> _acknowledgedSequences;

  TypedProjectOperationLog._({
    required Map<ProjectRecordKey, ProjectRecordState> records,
    required Map<OperationId, ProjectDataRecordOperation> operations,
    required Map<String, int> acknowledgedSequences,
  }) : _records = records,
       _operations = operations,
       _acknowledgedSequences = acknowledgedSequences;

  factory TypedProjectOperationLog.empty() => TypedProjectOperationLog._(
    records: <ProjectRecordKey, ProjectRecordState>{},
    operations: <OperationId, ProjectDataRecordOperation>{},
    acknowledgedSequences: <String, int>{},
  );

  TypedProjectOperationLog copy() => TypedProjectOperationLog._(
    records: Map<ProjectRecordKey, ProjectRecordState>.from(_records),
    operations: Map<OperationId, ProjectDataRecordOperation>.from(_operations),
    acknowledgedSequences: Map<String, int>.from(_acknowledgedSequences),
  );

  Map<String, int> get acknowledgedSequences =>
      UnmodifiableMapView<String, int>(_acknowledgedSequences);

  Iterable<ProjectRecordState> get activeRecords =>
      _records.values.where((record) => !record.isRemoved);

  ProjectRecordState? lookup(ProjectRecordKind kind, String recordId) =>
      _records[ProjectRecordKey(kind: kind, recordId: recordId)];

  TypedProjectOperationLog apply(ProjectDataRecordOperation operation) {
    if (_operations.containsKey(operation.id)) return this;
    final next = copy();
    next._operations[operation.id] = operation;
    final previousSequence =
        next._acknowledgedSequences[operation.id.replicaId];
    if (previousSequence == null || operation.id.sequence > previousSequence) {
      next._acknowledgedSequences[operation.id.replicaId] =
          operation.id.sequence;
    }

    final key = ProjectRecordKey(
      kind: operation.record.recordKind,
      recordId: operation.record.recordId,
    );
    final current = next._records[key];
    if (current == null || _isNewer(operation, current)) {
      next._records[key] = ProjectRecordState(
        operation: operation.record,
        lamport: operation.lamport,
        operationId: operation.id,
      );
    }
    return next;
  }

  List<ProjectDataRecordOperation> operationsAfter(
    Map<String, int> remoteAcknowledgedSequences, {
    int limit = CollaborationSchema.maximumOperationsPerBatch,
  }) {
    if (limit < 1 || limit > CollaborationSchema.maximumOperationsPerBatch) {
      throw RangeError.range(
        limit,
        1,
        CollaborationSchema.maximumOperationsPerBatch,
        "limit",
      );
    }
    final pending =
        _operations.values
            .where((operation) {
              final acknowledged =
                  remoteAcknowledgedSequences[operation.id.replicaId] ?? 0;
              return operation.id.sequence > acknowledged;
            })
            .toList(growable: false)
          ..sort((left, right) {
            final byLamport = left.lamport.compareTo(right.lamport);
            return byLamport != 0 ? byLamport : left.id.compareTo(right.id);
          });
    return List<ProjectDataRecordOperation>.unmodifiable(pending.take(limit));
  }

  static bool _isNewer(
    ProjectDataRecordOperation incoming,
    ProjectRecordState current,
  ) {
    final byLamport = incoming.lamport.compareTo(current.lamport);
    return byLamport > 0 ||
        (byLamport == 0 && incoming.id.compareTo(current.operationId) > 0);
  }
}
