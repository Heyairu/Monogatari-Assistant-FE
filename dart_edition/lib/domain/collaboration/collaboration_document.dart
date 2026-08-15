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
  final Map<OperationId, CollaborationOperation> _operations;
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
    required Map<OperationId, CollaborationOperation> operations,
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
      operations: <OperationId, CollaborationOperation>{},
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
  }) {
    final current = _texts[documentId];
    if (current == null) {
      throw StateError("文字 $documentId 尚未建立 CRDT document。");
    }
    final edit = current.createLocalEdit(nextText: nextText, clock: _clock);
    if (edit.operations.isEmpty) return this;
    var next = _copy(
      texts: <String, CollaborativeText>{..._texts, documentId: edit.document},
    );
    for (final operation in edit.operations) {
      next = next._recordApplied(operation);
    }
    return next;
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
    var next = this;
    final changedTextDocumentIds = <String>{};
    final appliedProjectOperations = <ProjectDataRecordOperation>[];
    for (final operation in batch.operations) {
      if (next._hasSeen(operation.id)) continue;
      next._clock.observe(operation);
      switch (operation) {
        case final TextInsertOperation insert:
          final document =
              next._texts[insert.textDocumentId] ??
              CollaborativeText.seeded(
                documentId: insert.textDocumentId,
                text: "",
              );
          final updated = document.apply(insert);
          final isProjectText = insert.textDocumentId.startsWith(
            CollaborationSchema.projectTextDocumentPrefix,
          );
          next = next._copy(
            texts: <String, CollaborativeText>{
              ...next._texts,
              insert.textDocumentId: updated,
            },
            chapterIds: isProjectText
                ? null
                : <String>{...next._chapterIds, insert.textDocumentId},
            projectTextIds: isProjectText
                ? <String>{...next._projectTextIds, insert.textDocumentId}
                : null,
          );
          changedTextDocumentIds.add(insert.textDocumentId);
        case final TextDeleteOperation delete:
          final document =
              next._texts[delete.textDocumentId] ??
              CollaborativeText.seeded(
                documentId: delete.textDocumentId,
                text: "",
              );
          final updated = document.apply(delete);
          final isProjectText = delete.textDocumentId.startsWith(
            CollaborationSchema.projectTextDocumentPrefix,
          );
          next = next._copy(
            texts: <String, CollaborativeText>{
              ...next._texts,
              delete.textDocumentId: updated,
            },
            chapterIds: isProjectText
                ? null
                : <String>{...next._chapterIds, delete.textDocumentId},
            projectTextIds: isProjectText
                ? <String>{...next._projectTextIds, delete.textDocumentId}
                : null,
          );
          changedTextDocumentIds.add(delete.textDocumentId);
        case final ProjectDataRecordOperation projectOperation:
          appliedProjectOperations.add(projectOperation);
      }
      next = next._recordApplied(operation);
    }
    return CollaborationApplyResult(
      document: next,
      changedTextDocumentIds: changedTextDocumentIds,
      appliedProjectOperations: appliedProjectOperations,
    );
  }

  List<CollaborationOperation> operationsAfter(
    Map<String, int> remoteAcknowledgedSequences, {
    int limit = CollaborationSchema.maximumOperationsPerBatch,
  }) {
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
    return List<CollaborationOperation>.unmodifiable(pending.take(limit));
  }

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
    if (_operations.containsKey(operation.id)) return this;
    var log = projectOperationLog;
    if (operation is ProjectDataRecordOperation) {
      log = log.apply(operation);
    }
    final next = _copy(
      operations: <OperationId, CollaborationOperation>{
        ..._operations,
        operation.id: operation,
      },
      projectOperationLog: log,
    );
    next._observeSequence(operation.id);
    return next;
  }

  bool _hasSeen(OperationId operationId) {
    final contiguous = _contiguousSequences[operationId.replicaId] ?? 0;
    return operationId.sequence <= contiguous ||
        (_pendingSequences[operationId.replicaId]?.contains(
              operationId.sequence,
            ) ??
            false) ||
        _operations.containsKey(operationId);
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
    Map<OperationId, CollaborationOperation>? operations,
    TypedProjectOperationLog? projectOperationLog,
  }) {
    return CollaborationDocument._(
      projectUuid: projectUuid,
      replicaId: replicaId,
      clock: _clock,
      texts: texts ?? Map<String, CollaborativeText>.from(_texts),
      chapterIds: chapterIds ?? Set<String>.from(_chapterIds),
      projectTextIds: projectTextIds ?? Set<String>.from(_projectTextIds),
      operations:
          operations ??
          Map<OperationId, CollaborationOperation>.from(_operations),
      contiguousSequences: Map<String, int>.from(_contiguousSequences),
      pendingSequences: _pendingSequences.map(
        (replica, values) => MapEntry(replica, Set<int>.from(values)),
      ),
      projectOperationLog: projectOperationLog ?? this.projectOperationLog,
    );
  }
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
