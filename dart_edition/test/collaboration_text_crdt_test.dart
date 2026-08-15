import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/domain/collaboration/collaboration_document.dart";
import "package:monogatari_assistant/domain/collaboration/collaboration_operation.dart";
import "package:monogatari_assistant/domain/collaboration/collaboration_protocol.dart";
import "package:monogatari_assistant/domain/collaboration/collaborative_text.dart";

const _projectUuid = "11111111-1111-4111-8111-111111111111";

CollaborationDocument _document(String replicaId, {String text = "ac"}) {
  return CollaborationDocument.seeded(
    projectUuid: _projectUuid,
    replicaId: replicaId,
    chapterTexts: <String, String>{"chapter-1": text},
  );
}

CollaborationSyncBatch _batch(
  String sender,
  Iterable<CollaborationOperation> operations,
) {
  return CollaborationSyncBatch(
    projectUuid: _projectUuid,
    senderReplicaId: sender,
    operations: operations,
  );
}

void main() {
  test("concurrent inserts converge without whole-document replacement", () {
    final initialA = _document("replica-a");
    final initialB = _document("replica-b");
    final editedA = initialA.createLocalTextEdit(
      documentId: "chapter-1",
      nextText: "abc",
    );
    final editedB = initialB.createLocalTextEdit(
      documentId: "chapter-1",
      nextText: "axc",
    );

    final operationsA = editedA.operationsAfter(const <String, int>{});
    final operationsB = editedB.operationsAfter(const <String, int>{});
    final mergedA = editedA
        .applyBatch(_batch("replica-b", operationsB))
        .document;
    final mergedB = editedB
        .applyBatch(_batch("replica-a", operationsA.reversed))
        .document;

    expect(mergedA.chapterText("chapter-1"), mergedB.chapterText("chapter-1"));
    expect(mergedA.chapterText("chapter-1"), contains("b"));
    expect(mergedA.chapterText("chapter-1"), contains("x"));
  });

  test("delete tombstone and concurrent insertion converge", () {
    final editedA = _document(
      "replica-a",
      text: "abc",
    ).createLocalTextEdit(documentId: "chapter-1", nextText: "ac");
    final editedB = _document(
      "replica-b",
      text: "abc",
    ).createLocalTextEdit(documentId: "chapter-1", nextText: "abXc");

    final mergedA = editedA
        .applyBatch(
          _batch("replica-b", editedB.operationsAfter(const <String, int>{})),
        )
        .document;
    final mergedB = editedB
        .applyBatch(
          _batch("replica-a", editedA.operationsAfter(const <String, int>{})),
        )
        .document;

    expect(mergedA.chapterText("chapter-1"), "aXc");
    expect(mergedB.chapterText("chapter-1"), "aXc");
  });

  test("out-of-order dependent inserts remain pending then apply", () {
    final first = _document(
      "replica-a",
      text: "a",
    ).createLocalTextEdit(documentId: "chapter-1", nextText: "ab");
    final second = first.createLocalTextEdit(
      documentId: "chapter-1",
      nextText: "abc",
    );
    final operations = second.operationsAfter(const <String, int>{});
    expect(operations, hasLength(2));

    var receiver = _document("replica-b", text: "a")
        .applyBatch(
          _batch("replica-a", <CollaborationOperation>[operations[1]]),
        )
        .document;
    expect(receiver.chapterText("chapter-1"), "a");
    expect(receiver.acknowledgedSequences["replica-a"] ?? 0, 0);

    receiver = receiver
        .applyBatch(
          _batch("replica-a", <CollaborationOperation>[operations[0]]),
        )
        .document;
    expect(receiver.chapterText("chapter-1"), "abc");
    expect(receiver.acknowledgedSequences["replica-a"], 2);
  });

  test("duplicate operations are idempotent", () {
    final edited = _document(
      "replica-a",
    ).createLocalTextEdit(documentId: "chapter-1", nextText: "abc");
    final operation = edited.operationsAfter(const <String, int>{}).single;
    final batch = _batch("replica-a", <CollaborationOperation>[operation]);
    final once = _document("replica-b").applyBatch(batch).document;
    final twice = once.applyBatch(batch).document;

    expect(twice.chapterText("chapter-1"), "abc");
    expect(
      twice.chapter("chapter-1")?.atomCount,
      once.chapter("chapter-1")?.atomCount,
    );
  });

  test("grapheme edits do not split emoji sequences", () {
    final document = CollaborativeText.seeded(
      documentId: "chapter-emoji",
      text: "A👨‍👩‍👧‍👦B",
    );
    final edit = document.createLocalEdit(
      nextText: "A👨‍👩‍👧‍👦！B",
      clock: ReplicaClock(replicaId: "replica-a"),
    );

    expect(edit.document.text, "A👨‍👩‍👧‍👦！B");
    expect(edit.operations, hasLength(1));
  });

  test("large paste is split into bounded insert operations", () {
    final text = List<String>.filled(6000, "字").join();
    final edited = _document(
      "replica-a",
      text: "",
    ).createLocalTextEdit(documentId: "chapter-1", nextText: text);

    expect(edited.chapterText("chapter-1"), text);
    expect(
      edited.operationsAfter(const <String, int>{}).length,
      greaterThan(1),
    );
  });

  test("cursor anchor rebases after a remote insertion before the caret", () {
    final local = _document("replica-a", text: "abcd");
    final localChapter = local.chapter("chapter-1")!;
    final anchor = localChapter.anchorAtOffset(3);
    final remote = _document(
      "replica-b",
      text: "abcd",
    ).createLocalTextEdit(documentId: "chapter-1", nextText: "Xabcd");

    final merged = local
        .applyBatch(
          _batch("replica-b", remote.operationsAfter(const <String, int>{})),
        )
        .document;

    expect(merged.chapterText("chapter-1"), "Xabcd");
    expect(merged.chapter("chapter-1")!.resolveAnchor(anchor), 4);
  });

  test("ProjectData text documents converge with the same CRDT", () {
    const documentId = "projectText:outlineStoryline:storyline-1:memo";
    CollaborationDocument projectDocument(String replicaId) =>
        CollaborationDocument.seeded(
          projectUuid: _projectUuid,
          replicaId: replicaId,
          chapterTexts: const <String, String>{},
          projectTexts: const <String, String>{documentId: "ac"},
        );
    final editedA = projectDocument(
      "replica-a",
    ).createLocalTextEdit(documentId: documentId, nextText: "abc");
    final editedB = projectDocument(
      "replica-b",
    ).createLocalTextEdit(documentId: documentId, nextText: "axc");

    final mergedA = editedA
        .applyBatch(
          _batch("replica-b", editedB.operationsAfter(const <String, int>{})),
        )
        .document;
    final mergedB = editedB
        .applyBatch(
          _batch("replica-a", editedA.operationsAfter(const <String, int>{})),
        )
        .document;

    expect(mergedA.text(documentId), mergedB.text(documentId));
    expect(mergedA.text(documentId), contains("b"));
    expect(mergedA.text(documentId), contains("x"));
  });

  test("an empty peer reconstructs an unsaved project from operations", () {
    final source = CollaborationDocument.operationBacked(
      projectUuid: _projectUuid,
      replicaId: "replica-a",
      chapterTexts: const <String, String>{"chapter-1": "尚未儲存的章節"},
      projectTexts: const <String, String>{
        "projectText:outlineStoryline:storyline-1:memo": "記憶體大綱",
      },
      projectRecords: <ProjectRecordOperation>[
        ProjectRecordOperation(
          recordKind: ProjectRecordKind.foreshadow,
          mutation: ProjectRecordMutation.put,
          recordId: "foreshadow-1",
          fields: const <String, Object?>{
            "schemaVersion": 1,
            "title": "伏筆",
            "note": "",
            "isRevealed": false,
          },
        ),
      ],
    );
    var receiver = CollaborationDocument.seeded(
      projectUuid: _projectUuid,
      replicaId: "replica-b",
      chapterTexts: const <String, String>{},
    );
    receiver = receiver
        .applyBatch(
          _batch("replica-a", source.operationsAfter(const <String, int>{})),
        )
        .document;

    expect(receiver.chapterText("chapter-1"), "尚未儲存的章節");
    expect(
      receiver.text("projectText:outlineStoryline:storyline-1:memo"),
      "記憶體大綱",
    );
    expect(
      receiver.projectOperationLog
          .lookup(ProjectRecordKind.foreshadow, "foreshadow-1")
          ?.operation
          .fields["title"],
      "伏筆",
    );
  });
}
