import "dart:collection";

import "collaboration_operation.dart";

List<ProjectRecordOperation> groupProjectRecordTransaction({
  required Iterable<ProjectRecordOperation> operations,
  required String transactionId,
  required bool Function(ProjectRecordOperation operation) include,
}) {
  final source = operations.toList(growable: false);
  final size = source.where(include).length;
  if (size < 2) return source;
  var index = 0;
  return source
      .map(
        (operation) => include(operation)
            ? operation.inTransaction(
                id: transactionId,
                index: index++,
                size: size,
              )
            : operation,
      )
      .toList(growable: false);
}

/// Holds transactional typed records until every indexed fragment arrives.
/// Non-transactional records pass through immediately.
final class ProjectOperationTransactionBuffer {
  static const int _maximumRememberedTransactions = 1024;

  final Map<String, _PendingProjectTransaction> _pending = {};
  final Set<String> _completed = {};
  final Queue<String> _completedOrder = Queue<String>();

  int get pendingTransactionCount => _pending.length;

  List<ProjectDataRecordOperation> get pendingOperations => List.unmodifiable(
    _pending.values.expand((transaction) => transaction.operations.values),
  );

  List<ProjectDataRecordOperation> accept(
    Iterable<ProjectDataRecordOperation> operations,
  ) {
    final ready = <ProjectDataRecordOperation>[];
    for (final operation in operations) {
      final record = operation.record;
      final transactionId = record.transactionId;
      if (transactionId == null) {
        ready.add(operation);
        continue;
      }
      if (_completed.contains(transactionId)) continue;
      final transaction = _pending.putIfAbsent(
        transactionId,
        () => _PendingProjectTransaction(record.transactionSize!),
      );
      if (transaction.size != record.transactionSize) {
        throw FormatException("交易 $transactionId 的總筆數不一致。");
      }
      final index = record.transactionIndex!;
      final previous = transaction.operations[index];
      if (previous != null && previous.id != operation.id) {
        throw FormatException("交易 $transactionId 的第 $index 筆內容衝突。");
      }
      transaction.operations[index] = operation;
      if (transaction.operations.length != transaction.size) continue;
      for (var expected = 0; expected < transaction.size; expected++) {
        if (!transaction.operations.containsKey(expected)) {
          throw FormatException("交易 $transactionId 的索引不連續。");
        }
      }
      ready.addAll(
        List<ProjectDataRecordOperation>.generate(
          transaction.size,
          (index) => transaction.operations[index]!,
          growable: false,
        ),
      );
      _pending.remove(transactionId);
      _rememberCompleted(transactionId);
    }
    return List.unmodifiable(ready);
  }

  void clear() {
    _pending.clear();
    _completed.clear();
    _completedOrder.clear();
  }

  void _rememberCompleted(String transactionId) {
    _completed.add(transactionId);
    _completedOrder.addLast(transactionId);
    while (_completedOrder.length > _maximumRememberedTransactions) {
      _completed.remove(_completedOrder.removeFirst());
    }
  }
}

final class _PendingProjectTransaction {
  final int size;
  final Map<int, ProjectDataRecordOperation> operations = {};

  _PendingProjectTransaction(this.size);
}
