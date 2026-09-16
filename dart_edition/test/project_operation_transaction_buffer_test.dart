import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/domain/collaboration/collaboration_operation.dart";
import "package:monogatari_assistant/domain/collaboration/project_operation_transaction_buffer.dart";

ProjectRecordOperation _record(int index) => ProjectRecordOperation(
  recordKind: ProjectRecordKind.itemInstance,
  mutation: ProjectRecordMutation.put,
  recordId: "item-$index",
  fields: {"name": "物品 $index"},
);

ProjectDataRecordOperation _wire(ProjectRecordOperation record, int sequence) =>
    ProjectDataRecordOperation(
      id: OperationId(replicaId: "remote", sequence: sequence),
      lamport: sequence,
      record: record,
    );

void main() {
  test(
    "transaction metadata round-trips while legacy records stay compatible",
    () {
      final legacy = _record(0);
      final transactional = legacy.inTransaction(id: "tx-1", index: 0, size: 2);

      expect(
        ProjectRecordOperation.fromJson(legacy.toJson()).transactionId,
        isNull,
      );
      final decoded = ProjectRecordOperation.fromJson(
        Map<String, Object?>.from(
          jsonDecode(jsonEncode(transactional.toJson())) as Map,
        ),
      );
      expect(decoded.transactionId, "tx-1");
      expect(decoded.transactionIndex, 0);
      expect(decoded.transactionSize, 2);
    },
  );

  test("item records are indexed as one transaction", () {
    final grouped = groupProjectRecordTransaction(
      operations: [
        _record(0),
        ProjectRecordOperation(
          recordKind: ProjectRecordKind.outlineEvent,
          mutation: ProjectRecordMutation.put,
          recordId: "event",
          fields: const {"name": "事件"},
        ),
        _record(1),
      ],
      transactionId: "item-transaction",
      include: (operation) =>
          operation.recordKind == ProjectRecordKind.itemInstance,
    );

    expect(grouped[0].transactionIndex, 0);
    expect(grouped[0].transactionSize, 2);
    expect(grouped[1].transactionId, isNull);
    expect(grouped[2].transactionIndex, 1);
    expect(grouped[2].transactionSize, 2);
  });

  test("forty out-of-order fragments wait across transport batches", () {
    final records = List.generate(40, _record);
    final grouped = groupProjectRecordTransaction(
      operations: records,
      transactionId: "large-item-transaction",
      include: (_) => true,
    );
    final wired = [
      for (var index = 0; index < grouped.length; index++)
        _wire(grouped[index], index + 1),
    ];
    final firstBatch = [...wired.sublist(8, 40)];
    final secondBatch = [...wired.sublist(0, 8).reversed];
    final buffer = ProjectOperationTransactionBuffer();

    expect(buffer.accept(firstBatch), isEmpty);
    expect(buffer.pendingTransactionCount, 1);
    final completed = buffer.accept(secondBatch);
    expect(completed, hasLength(40));
    expect(
      completed.map((operation) => operation.record.transactionIndex),
      orderedEquals(List.generate(40, (index) => index)),
    );
    expect(buffer.pendingTransactionCount, 0);
    expect(
      buffer.accept(wired),
      isEmpty,
      reason: "completed retry is idempotent",
    );
  });

  test("non-transactional records pass while a transaction is pending", () {
    final grouped = groupProjectRecordTransaction(
      operations: [_record(0), _record(1)],
      transactionId: "pending",
      include: (_) => true,
    );
    final buffer = ProjectOperationTransactionBuffer();
    expect(buffer.accept([_wire(grouped.first, 1)]), isEmpty);
    final ordinary = _wire(_record(9), 9);
    expect(buffer.accept([ordinary]), [ordinary]);
    expect(buffer.pendingOperations, hasLength(1));
  });

  test("inconsistent or conflicting fragments are rejected", () {
    final buffer = ProjectOperationTransactionBuffer();
    final first = _record(0).inTransaction(id: "conflict", index: 0, size: 2);
    final wrongSize = _record(
      1,
    ).inTransaction(id: "conflict", index: 1, size: 3);
    buffer.accept([_wire(first, 1)]);
    expect(() => buffer.accept([_wire(wrongSize, 2)]), throwsFormatException);

    final collisionBuffer = ProjectOperationTransactionBuffer();
    collisionBuffer.accept([_wire(first, 1)]);
    expect(
      () => collisionBuffer.accept([_wire(first, 2)]),
      throwsFormatException,
    );
  });
}
