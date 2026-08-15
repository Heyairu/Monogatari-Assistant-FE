import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/domain/collaboration/collaboration_document.dart";
import "package:monogatari_assistant/domain/collaboration/collaboration_operation.dart";
import "package:monogatari_assistant/domain/collaboration/collaboration_protocol.dart";
import "package:monogatari_assistant/domain/collaboration/collaborative_text.dart";
import "package:monogatari_assistant/domain/collaboration/typed_operation_log.dart";

const _projectUuid = "22222222-2222-4222-8222-222222222222";

void main() {
  test("wire batch round-trips operations, ACKs, and cursor presence", () {
    final document = CollaborationDocument.seeded(
      projectUuid: _projectUuid,
      replicaId: "replica-a",
      chapterTexts: const <String, String>{"chapter-1": "hello"},
    ).createLocalTextEdit(documentId: "chapter-1", nextText: "hello!");
    final chapter = document.chapter("chapter-1")!;
    final batch = document.buildBatch(
      remoteAcknowledgedSequences: const <String, int>{},
      presence: CollaboratorPresence(
        replicaId: "replica-a",
        ipAddress: "192.168.1.20",
        target: ChapterTextCursorTarget(
          chapterId: "chapter-1",
          anchor: chapter.anchorAtOffset(6),
          focus: chapter.anchorAtOffset(6),
        ),
        presenceSequence: 1,
        sentAtEpochMs: 1000,
      ),
    );

    final encoded = jsonEncode(batch.toJson());
    final decoded = CollaborationSyncBatch.fromJson(
      (jsonDecode(encoded) as Map).map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );

    expect(decoded.projectUuid, _projectUuid);
    expect(decoded.operations, hasLength(1));
    expect(decoded.presence?.cursorLabel, "192.168.1.20");
    expect(encoded, isNot(contains("<Project")));
    expect(encoded, isNot(contains("xmlContent")));
    expect(encoded, isNot(contains('"atoms"')));
  });

  test(
    "compact text wire format keeps a large bootstrap operation bounded",
    () {
      final text = List<String>.filled(3000, "\"\\\n").join();
      final source = CollaborationDocument.operationBacked(
        projectUuid: _projectUuid,
        replicaId: "replica-a",
        chapterTexts: <String, String>{"chapter-1": text},
      );
      final operations = source.operationsAfter(const <String, int>{});

      expect(operations.length, greaterThan(1));
      expect(source.chapterText("chapter-1"), text);
      for (final operation in operations) {
        final batch = CollaborationSyncBatch(
          projectUuid: _projectUuid,
          senderReplicaId: "replica-a",
          operations: <CollaborationOperation>[operation],
        );
        final encoded = utf8.encode(jsonEncode(batch.toJson()));
        final decoded = CollaborationSyncBatch.fromJson(
          (jsonDecode(utf8.decode(encoded)) as Map).map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        );

        expect(encoded.length, lessThan(30 * 1024));
        expect(decoded.operations.single, isA<TextInsertOperation>());
      }
    },
  );

  test("compact delete spans round-trip all tombstones", () {
    final edited = CollaborationDocument.seeded(
      projectUuid: _projectUuid,
      replicaId: "replica-a",
      chapterTexts: const <String, String>{"chapter-1": "abcdef"},
    ).createLocalTextEdit(documentId: "chapter-1", nextText: "af");
    final operation = edited.operationsAfter(const <String, int>{}).single;
    final decoded = CollaborationOperation.fromJson(
      (jsonDecode(jsonEncode(operation.toJson())) as Map).map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );

    expect(decoded, isA<TextDeleteOperation>());
    expect((decoded as TextDeleteOperation).atomIds, hasLength(4));
  });

  test("transport-observed IP replaces the self-reported cursor label", () {
    final batch = CollaborationSyncBatch(
      projectUuid: _projectUuid,
      senderReplicaId: "replica-a",
      presence: const CollaboratorPresence(
        replicaId: "replica-a",
        ipAddress: "192.168.1.99",
        target: ChapterTextCursorTarget(
          chapterId: "chapter-1",
          anchor: TextCursorAnchor(atomId: null, fallbackOffset: 0),
          focus: TextCursorAnchor(atomId: null, fallbackOffset: 0),
        ),
        presenceSequence: 1,
        sentAtEpochMs: 1000,
      ),
    );

    final observed = batch.withObservedIpAddress("192.168.1.20");

    expect(observed.presence?.ipAddress, "192.168.1.20");
  });

  test("project field cursor target round-trips independently of CRDT", () {
    const presence = CollaboratorPresence(
      replicaId: "replica-a",
      ipAddress: "192.168.1.20",
      target: ProjectFieldCursorTarget(
        fieldId: "baseInfo.toRecap",
        anchorOffset: 7,
        focusOffset: 7,
      ),
      presenceSequence: 2,
      sentAtEpochMs: 2000,
    );

    final decoded = CollaboratorPresence.fromJson(presence.toJson());

    expect(decoded.target, isA<ProjectFieldCursorTarget>());
    final target = decoded.target as ProjectFieldCursorTarget;
    expect(target.fieldId, "baseInfo.toRecap");
    expect(target.focusOffset, 7);
  });

  test("project text cursor target round-trips with CRDT anchors", () {
    const documentId = "projectText:character:character-1:notes";
    const presence = CollaboratorPresence(
      replicaId: "replica-a",
      ipAddress: "192.168.1.20",
      target: ProjectTextCursorTarget(
        documentId: documentId,
        anchor: TextCursorAnchor(atomId: null, fallbackOffset: 3),
        focus: TextCursorAnchor(atomId: null, fallbackOffset: 3),
      ),
      presenceSequence: 3,
      sentAtEpochMs: 3000,
    );

    final decoded = CollaboratorPresence.fromJson(presence.toJson());

    expect(decoded.target, isA<ProjectTextCursorTarget>());
    expect((decoded.target as ProjectTextCursorTarget).documentId, documentId);
  });

  test(
    "typed record log converges with Lamport and operation-id tie break",
    () {
      ProjectDataRecordOperation operation({
        required String replica,
        required String title,
      }) {
        return ProjectDataRecordOperation(
          id: OperationId(replicaId: replica, sequence: 1),
          lamport: 5,
          record: ProjectRecordOperation(
            recordKind: ProjectRecordKind.foreshadow,
            mutation: ProjectRecordMutation.put,
            recordId: "foreshadow-1",
            fields: <String, Object?>{
              "schemaVersion": 1,
              "title": title,
              "note": "",
              "isRevealed": false,
            },
          ),
        );
      }

      final a = operation(replica: "replica-a", title: "A");
      final b = operation(replica: "replica-b", title: "B");
      final logAB = TypedProjectOperationLog.empty().apply(a).apply(b);
      final logBA = TypedProjectOperationLog.empty().apply(b).apply(a);

      expect(
        logAB
            .lookup(ProjectRecordKind.foreshadow, "foreshadow-1")
            ?.operation
            .fields,
        logBA
            .lookup(ProjectRecordKind.foreshadow, "foreshadow-1")
            ?.operation
            .fields,
      );
      expect(
        logAB
            .lookup(ProjectRecordKind.foreshadow, "foreshadow-1")
            ?.operation
            .fields["title"],
        "B",
      );
    },
  );

  test("protocol rejects extra fields and non-IP cursor labels", () {
    expect(
      () => CollaboratorPresence.fromJson(<String, Object?>{
        "replicaId": "replica-a",
        "ipAddress": "writer.example",
        "target": const ChapterTextCursorTarget(
          chapterId: "chapter-1",
          anchor: TextCursorAnchor(atomId: null, fallbackOffset: 0),
          focus: TextCursorAnchor(atomId: null, fallbackOffset: 0),
        ).toJson(),
        "presenceSequence": 1,
        "sentAtEpochMs": 1,
      }),
      throwsFormatException,
    );
  });
}
