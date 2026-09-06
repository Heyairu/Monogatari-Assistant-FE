import "dart:collection";
import "dart:convert";

import "package:characters/characters.dart";

import "collaboration_operation.dart";
import "collaboration_protocol.dart";
import "collaborative_text.dart";
import "typed_operation_log.dart";

final class CollaborationApplyResult {
  final CollaborationDocument document;
  final Set<String> changedTextDocumentIds;
  final List<ProjectDataRecordOperation> appliedProjectOperations;

  CollaborationApplyResult({
    required this.document,
    Iterable<String> changedTextDocumentIds = const <String>{},
    Iterable<ProjectDataRecordOperation> appliedProjectOperations =
        const <ProjectDataRecordOperation>[],
  }) : changedTextDocumentIds = Set<String>.unmodifiable(
         changedTextDocumentIds,
       ),
       appliedProjectOperations = List<ProjectDataRecordOperation>.unmodifiable(
         appliedProjectOperations,
       );
}

final class CollaborationDocument {
  final String projectUuid;
  final String replicaId;
  final ReplicaClock _clock;
  final Map<String, CollaborativeText> _texts;
  final Set<String> _chapterIds;
  final Set<String> _projectTextIds;
  final _PersistentOperationLog _operations;
  final Map<String, int> _contiguousSequences;
  final Map<String, Set<int>> _pendingSequences;
  final TypedProjectOperationLog projectOperationLog;

  CollaborationDocument._({
    required this.projectUuid,
    required this.replicaId,
    required ReplicaClock clock,
    required Map<String, CollaborativeText> texts,
    required Set<String> chapterIds,
    required Set<String> projectTextIds,
    required _PersistentOperationLog operations,
    required Map<String, int> contiguousSequences,
    required Map<String, Set<int>> pendingSequences,
    required this.projectOperationLog,
  }) : _clock = clock,
       _texts = texts,
       _chapterIds = chapterIds,
       _projectTextIds = projectTextIds,
       _operations = operations,
       _contiguousSequences = contiguousSequences,
       _pendingSequences = pendingSequences;

  factory CollaborationDocument.seeded({
    required String projectUuid,
    required String replicaId,
    required Map<String, String> chapterTexts,
    Map<String, String> projectTexts = const <String, String>{},
  }) {
    final normalizedProjectUuid = projectUuid.trim().toLowerCase();
    if (normalizedProjectUuid.isEmpty || replicaId.trim().isEmpty) {
      throw ArgumentError("collaboration project/replica id 不可為空。");
    }
    return CollaborationDocument._(
      projectUuid: normalizedProjectUuid,
      replicaId: replicaId.trim(),
      clock: ReplicaClock(replicaId: replicaId.trim()),
      texts: <String, CollaborativeText>{
        for (final entry in <String, String>{
          ...chapterTexts,
          ...projectTexts,
        }.entries)
          entry.key: CollaborativeText.seeded(
            documentId: entry.key,
            text: entry.value,
          ),
      },
      chapterIds: chapterTexts.keys.toSet(),
      projectTextIds: projectTexts.keys.toSet(),
      operations: _PersistentOperationLog.empty(),
      contiguousSequences: <String, int>{},
      pendingSequences: <String, Set<int>>{},
      projectOperationLog: TypedProjectOperationLog.empty(),
    );
  }

  /// Builds a complete in-memory project as replayable CRDT/typed operations.
  ///
  /// This is used when a peer has no local project checkpoint. The receiver can
  /// start from an empty document and reconstruct the project without XML or a
  /// prior filesystem save. Existing same-checkpoint peers continue to use
  /// [seeded], so opening the same persisted project on both devices does not
  /// duplicate its baseline text.
  factory CollaborationDocument.operationBacked({
    required String projectUuid,
    required String replicaId,
    required Map<String, String> chapterTexts,
    Map<String, String> projectTexts = const <String, String>{},
    Iterable<ProjectRecordOperation> projectRecords =
        const <ProjectRecordOperation>[],
  }) {
    var document = CollaborationDocument.seeded(
      projectUuid: projectUuid,
      replicaId: replicaId,
      chapterTexts: const <String, String>{},
    );
    for (final entry in chapterTexts.entries) {
      document = document.ensureChapter(chapterId: entry.key);
      document = _appendReplayableText(document, entry.key, entry.value);
    }
    for (final entry in projectTexts.entries) {
      document = document.ensureProjectText(documentId: entry.key);
      document = _appendReplayableText(document, entry.key, entry.value);
    }
    for (final record in projectRecords) {
      document = document.createLocalProjectOperation(record);
    }
    return document;
  }

  Map<String, CollaborativeText> get textDocuments =>
      UnmodifiableMapView<String, CollaborativeText>(_texts);

  Map<String, CollaborativeText> get chapters =>
      UnmodifiableMapView<String, CollaborativeText>(
        <String, CollaborativeText>{
          for (final id in _chapterIds)
            if (_texts[id] case final value?) id: value,
        },
      );

  Map<String, CollaborativeText> get projectTexts =>
      UnmodifiableMapView<String, CollaborativeText>(
        <String, CollaborativeText>{
          for (final id in _projectTextIds)
            if (_texts[id] case final value?) id: value,
        },
      );

  Map<String, int> get acknowledgedSequences =>
      UnmodifiableMapView<String, int>(_contiguousSequences);

  String? text(String documentId) => _texts[documentId]?.text;

  String? chapterText(String chapterId) => _texts[chapterId]?.text;

  CollaborativeText? textDocument(String documentId) => _texts[documentId];

  CollaborativeText? chapter(String chapterId) =>
      _chapterIds.contains(chapterId) ? _texts[chapterId] : null;

  int get operationCount => _operations.length;

  int get atomCount =>
      _texts.values.fold(0, (total, document) => total + document.atomCount);

  int get tombstoneCount => _texts.values.fold(
    0,
    (total, document) => total + document.tombstoneCount,
  );

  CollaborationDocument ensureChapter({
    required String chapterId,
    String initialText = "",
  }) {
    if (_chapterIds.contains(chapterId)) return this;
    var next = ensureTextDocument(
      documentId: chapterId,
      initialText: initialText,
      isChapter: true,
    );
    return next;
  }

  CollaborationDocument ensureProjectText({
    required String documentId,
    String initialText = "",
  }) => ensureTextDocument(
    documentId: documentId,
    initialText: initialText,
    isChapter: false,
  );

  CollaborationDocument ensureTextDocument({
    required String documentId,
    String initialText = "",
    required bool isChapter,
  }) {
    if (_texts.containsKey(documentId)) return this;
    var next = _copy(
      texts: <String, CollaborativeText>{
        ..._texts,
        documentId: CollaborativeText.seeded(documentId: documentId, text: ""),
      },
      chapterIds: isChapter ? <String>{..._chapterIds, documentId} : null,
      projectTextIds: isChapter
          ? null
          : <String>{..._projectTextIds, documentId},
    );
    if (initialText.isNotEmpty) {
      next = next.createLocalTextEdit(
        documentId: documentId,
        nextText: initialText,
      );
    }
    return next;
  }

  CollaborationDocument createLocalTextEdit({
    required String documentId,
    required String nextText,
  }) => createLocalTextDelta(
    documentId: documentId,
    delta: CollaborativeTextDelta.between(
      _texts[documentId]?.text ?? "",
      nextText,
    ),
  );

  CollaborationDocument createLocalTextDelta({
    required String documentId,
    required CollaborativeTextDelta delta,
  }) {
    final current = _texts[documentId];
    if (current == null) {
      throw StateError("文字 $documentId 尚未建立 CRDT document。");
    }
    final edit = current.createLocalDelta(delta: delta, clock: _clock);
    if (edit.operations.isEmpty) return this;
    var next = _copy(
      texts: <String, CollaborativeText>{..._texts, documentId: edit.document},
    );
    return next._recordAppliedAll(edit.operations);
  }

  CollaborationDocument createLocalProjectOperation(
    ProjectRecordOperation record,
  ) {
    final stamp = _clock.nextOperation();
    final operation = ProjectDataRecordOperation(
      id: stamp.id,
      lamport: stamp.lamport,
      record: record,
    );
    return _recordApplied(operation);
  }

  CollaborationApplyResult applyBatch(CollaborationSyncBatch batch) {
    if (batch.projectUuid != projectUuid) {
      throw const FormatException("collaboration batch project UUID 不一致。");
    }
    final changedTextDocumentIds = <String>{};
    final appliedProjectOperations = <ProjectDataRecordOperation>[];
    final acceptedOperations = <CollaborationOperation>[];
    final acceptedIds = <OperationId>{};
    final textOperations = <String, List<CollaborationOperation>>{};
    for (final operation in batch.operations) {
      if (_hasSeen(operation.id) || !acceptedIds.add(operation.id)) continue;
      _clock.observe(operation);
      acceptedOperations.add(operation);
      switch (operation) {
        case final TextInsertOperation insert:
          textOperations
              .putIfAbsent(
                insert.textDocumentId,
                () => <CollaborationOperation>[],
              )
              .add(insert);
          changedTextDocumentIds.add(insert.textDocumentId);
        case final TextDeleteOperation delete:
          textOperations
              .putIfAbsent(
                delete.textDocumentId,
                () => <CollaborationOperation>[],
              )
              .add(delete);
          changedTextDocumentIds.add(delete.textDocumentId);
        case final ProjectDataRecordOperation projectOperation:
          appliedProjectOperations.add(projectOperation);
      }
    }
    if (acceptedOperations.isEmpty) {
      return CollaborationApplyResult(document: this);
    }
    final nextTexts = <String, CollaborativeText>{..._texts};
    var nextChapterIds = _chapterIds;
    var nextProjectTextIds = _projectTextIds;
    for (final entry in textOperations.entries) {
      final document =
          nextTexts[entry.key] ??
          CollaborativeText.seeded(documentId: entry.key, text: "");
      nextTexts[entry.key] = document.applyAll(entry.value);
      final isProjectText = entry.key.startsWith(
        CollaborationSchema.projectTextDocumentPrefix,
      );
      if (isProjectText && !nextProjectTextIds.contains(entry.key)) {
        nextProjectTextIds = <String>{...nextProjectTextIds, entry.key};
      } else if (!isProjectText && !nextChapterIds.contains(entry.key)) {
        nextChapterIds = <String>{...nextChapterIds, entry.key};
      }
    }
    final next = _copy(
      texts: nextTexts,
      chapterIds: nextChapterIds,
      projectTextIds: nextProjectTextIds,
    )._recordAppliedAll(acceptedOperations);
    return CollaborationApplyResult(
      document: next,
      changedTextDocumentIds: changedTextDocumentIds,
      appliedProjectOperations: appliedProjectOperations,
    );
  }

  List<CollaborationOperation> operationsAfter(
    Map<String, int> remoteAcknowledgedSequences, {
    int limit = CollaborationSchema.maximumOperationsPerBatch,
  }) => _operations.after(remoteAcknowledgedSequences, limit: limit);

  CollaborationSyncBatch buildBatch({
    required Map<String, int> remoteAcknowledgedSequences,
    CollaboratorPresence? presence,
  }) {
    return CollaborationSyncBatch(
      projectUuid: projectUuid,
      senderReplicaId: replicaId,
      acknowledgedSequences: acknowledgedSequences,
      operations: operationsAfter(remoteAcknowledgedSequences),
      presence: presence,
    );
  }

  CollaborationDocument _recordApplied(CollaborationOperation operation) {
    if (_hasSeen(operation.id)) return this;
    return _recordAppliedAll(<CollaborationOperation>[operation]);
  }

  CollaborationDocument _recordAppliedAll(
    Iterable<CollaborationOperation> operations,
  ) {
    final additions = operations.toList(growable: false);
    if (additions.isEmpty) return this;
    var log = projectOperationLog;
    for (final operation in additions) {
      if (operation is ProjectDataRecordOperation) {
        log = log.apply(operation);
      }
    }
    final next = _copy(
      operations: _operations.append(additions),
      projectOperationLog: log,
    );
    for (final operation in additions) {
      next._observeSequence(operation.id);
    }
    return next;
  }

  bool _hasSeen(OperationId operationId) {
    final contiguous = _contiguousSequences[operationId.replicaId] ?? 0;
    return operationId.sequence <= contiguous ||
        (_pendingSequences[operationId.replicaId]?.contains(
              operationId.sequence,
            ) ??
            false);
  }

  void _observeSequence(OperationId operationId) {
    final replica = operationId.replicaId;
    var contiguous = _contiguousSequences[replica] ?? 0;
    if (operationId.sequence <= contiguous) return;
    final pending = _pendingSequences.putIfAbsent(replica, () => <int>{});
    pending.add(operationId.sequence);
    while (pending.remove(contiguous + 1)) {
      contiguous += 1;
    }
    _contiguousSequences[replica] = contiguous;
    if (pending.isEmpty) _pendingSequences.remove(replica);
  }

  CollaborationDocument _copy({
    Map<String, CollaborativeText>? texts,
    Set<String>? chapterIds,
    Set<String>? projectTextIds,
    _PersistentOperationLog? operations,
    TypedProjectOperationLog? projectOperationLog,
  }) {
    return CollaborationDocument._(
      projectUuid: projectUuid,
      replicaId: replicaId,
      clock: _clock,
      texts: texts ?? _texts,
      chapterIds: chapterIds ?? _chapterIds,
      projectTextIds: projectTextIds ?? _projectTextIds,
      operations: operations ?? _operations,
      contiguousSequences: Map<String, int>.from(_contiguousSequences),
      pendingSequences: _pendingSequences.map(
        (replica, values) => MapEntry(replica, Set<int>.from(values)),
      ),
      projectOperationLog: projectOperationLog ?? this.projectOperationLog,
    );
  }
}

/// Append-only persistent chunks keep document snapshots immutable without
/// copying the complete operation map for every keystroke.
final class _PersistentOperationLog {
  final _PersistentOperationLog? previous;
  final List<CollaborationOperation> tail;
  final int length;
  final _OperationIndex _index;

  _PersistentOperationLog.empty()
    : previous = null,
      tail = const <CollaborationOperation>[],
      length = 0,
      _index = _OperationIndex();

  _PersistentOperationLog._(this.previous, List<CollaborationOperation> tail)
    : tail = List<CollaborationOperation>.unmodifiable(tail),
      length = previous!.length + tail.length,
      _index = previous._index {
    _index.addAll(tail, firstOrdinal: previous!.length + 1);
  }

  _PersistentOperationLog append(List<CollaborationOperation> operations) =>
      operations.isEmpty ? this : _PersistentOperationLog._(this, operations);

  List<CollaborationOperation> after(
    Map<String, int> acknowledgedSequences, {
    required int limit,
  }) =>
      _index.after(acknowledgedSequences, maximumOrdinal: length, limit: limit);
}

final class _IndexedOperation {
  final CollaborationOperation operation;
  final int ordinal;

  const _IndexedOperation(this.operation, this.ordinal);
}

final class _OperationCursor {
  final List<_IndexedOperation> operations;
  int index;
  final int maximumOrdinal;

  _OperationCursor({
    required this.operations,
    required this.index,
    required this.maximumOrdinal,
  });

  CollaborationOperation? get current {
    while (index < operations.length &&
        operations[index].ordinal > maximumOrdinal) {
      index += 1;
    }
    return index < operations.length ? operations[index].operation : null;
  }

  void advance() {
    index += 1;
  }
}

final class _OperationIndex {
  final Map<String, List<_IndexedOperation>> _byReplica =
      <String, List<_IndexedOperation>>{};

  void addAll(
    List<CollaborationOperation> operations, {
    required int firstOrdinal,
  }) {
    for (var index = 0; index < operations.length; index += 1) {
      final operation = operations[index];
      final replicaOperations = _byReplica.putIfAbsent(
        operation.id.replicaId,
        () => <_IndexedOperation>[],
      );
      final insertionIndex = _lowerOperationSequence(
        replicaOperations,
        operation.id.sequence,
      );
      replicaOperations.insert(
        insertionIndex,
        _IndexedOperation(operation, firstOrdinal + index),
      );
    }
  }

  List<CollaborationOperation> after(
    Map<String, int> acknowledgedSequences, {
    required int maximumOrdinal,
    required int limit,
  }) {
    final cursors = <_OperationCursor>[];
    for (final entry in _byReplica.entries) {
      final acknowledged = acknowledgedSequences[entry.key] ?? 0;
      final cursor = _OperationCursor(
        operations: entry.value,
        index: _lowerOperationSequence(entry.value, acknowledged + 1),
        maximumOrdinal: maximumOrdinal,
      );
      if (cursor.current != null) cursors.add(cursor);
    }

    final pending = <CollaborationOperation>[];
    while (pending.length < limit) {
      _OperationCursor? selected;
      CollaborationOperation? selectedOperation;
      for (final cursor in cursors) {
        final operation = cursor.current;
        if (operation == null) continue;
        if (selectedOperation == null ||
            _compareOperations(operation, selectedOperation) < 0) {
          selected = cursor;
          selectedOperation = operation;
        }
      }
      if (selected == null || selectedOperation == null) break;
      pending.add(selectedOperation);
      selected.advance();
    }
    return List<CollaborationOperation>.unmodifiable(pending);
  }
}

int _lowerOperationSequence(List<_IndexedOperation> values, int sequence) {
  var low = 0;
  var high = values.length;
  while (low < high) {
    final middle = low + ((high - low) >> 1);
    if (values[middle].operation.id.sequence < sequence) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  return low;
}

int _compareOperations(
  CollaborationOperation left,
  CollaborationOperation right,
) {
  final byLamport = left.lamport.compareTo(right.lamport);
  return byLamport != 0 ? byLamport : left.id.compareTo(right.id);
}

CollaborationDocument _appendReplayableText(
  CollaborationDocument document,
  String documentId,
  String text,
) {
  var materialized = "";
  for (final chunk in _textOperationChunks(text)) {
    materialized += chunk;
    document = document.createLocalTextEdit(
      documentId: documentId,
      nextText: materialized,
    );
  }
  return document;
}

Iterable<String> _textOperationChunks(String text) sync* {
  var buffer = StringBuffer();
  var byteLength = 0;
  for (final grapheme in text.characters) {
    final graphemeBytes = utf8.encode(grapheme).length;
    if (graphemeBytes > CollaborationSchema.maximumInsertedTextBytes) {
      throw const FormatException("單一 grapheme 超過 CRDT operation 上限。");
    }
    if (byteLength > 0 &&
        byteLength + graphemeBytes >
            CollaborationSchema.preferredInsertedTextChunkBytes) {
      yield buffer.toString();
      buffer = StringBuffer();
      byteLength = 0;
    }
    buffer.write(grapheme);
    byteLength += graphemeBytes;
  }
  if (byteLength > 0) yield buffer.toString();
}
