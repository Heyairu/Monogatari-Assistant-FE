import "package:code_text_field/code_text_field.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:monogatari_assistant/domain/collaboration/collaboration_document.dart";
import "package:monogatari_assistant/domain/collaboration/collaborative_text.dart";
import "package:monogatari_assistant/features/inline_annotations/mosaic_editing_controller.dart";
import "package:monogatari_assistant/presentation/providers/collaboration_providers.dart";
import "package:monogatari_assistant/presentation/widgets/remote_text_cursor_overlay.dart";

void main() {
  testWidgets("Mosaic remote cursors avoid hidden UUID and note syntax", (
    tester,
  ) async {
    const uuid = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";
    const raw = "A//@<$uuid|艾莉絲>{主角}//Z";
    final controller = MosaicEditingController(rawText: raw);
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    final entry = controller.projection.projectedAnnotations.single;
    final cursors = <RemoteChapterCursorState>[
      RemoteChapterCursorState(
        replicaId: "remote-uuid",
        ipAddress: "192.168.1.30",
        chapterId: "chapter-1",
        anchorOffset: raw.indexOf(uuid) + 5,
        focusOffset: raw.indexOf(uuid) + 5,
        presenceSequence: 1,
        observedAt: DateTime(2026),
      ),
      RemoteChapterCursorState(
        replicaId: "remote-note",
        ipAddress: "192.168.1.31",
        chapterId: "chapter-1",
        anchorOffset: raw.indexOf("主角") + 1,
        focusOffset: raw.indexOf("主角") + 1,
        presenceSequence: 1,
        observedAt: DateTime(2026),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 200,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CodeField(
                    controller: controller,
                    focusNode: focusNode,
                    lineNumbers: false,
                    wrap: true,
                  ),
                ),
                Positioned.fill(
                  child: RemoteTextCursorOverlay(
                    controller: controller,
                    cursors: cursors,
                    offsetMapper: controller.projection.rawOffsetToDisplay,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    Offset expectedCaret(int displayOffset) =>
        editable.renderEditable.localToGlobal(
          editable.renderEditable
              .getLocalRectForCaret(TextPosition(offset: displayOffset))
              .topLeft,
        );

    final expectedUuid = expectedCaret(entry.labelRange.start);
    final expectedNote = expectedCaret(entry.labelRange.end);
    final actualUuid = tester.getTopLeft(
      find.byKey(const ValueKey<String>("remote-caret-remote-uuid")),
    );
    final actualNote = tester.getTopLeft(
      find.byKey(const ValueKey<String>("remote-caret-remote-note")),
    );
    expect(actualUuid.dx, closeTo(expectedUuid.dx, 0.01));
    expect(actualUuid.dy, closeTo(expectedUuid.dy, 0.01));
    expect(actualNote.dx, closeTo(expectedNote.dx, 0.01));
    expect(actualNote.dy, closeTo(expectedNote.dy, 0.01));
  });

  testWidgets("project field displays observed-IP cursor at exact caret rect", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const fieldId = "baseInfo.toRecap";
    final controller = TextEditingController(text: "abcdef")
      ..selection = const TextSelection.collapsed(offset: 3);
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    final cursors = <RemoteProjectFieldCursorState>[
      RemoteProjectFieldCursorState(
        replicaId: "remote-a",
        ipAddress: "192.168.1.20",
        fieldId: fieldId,
        anchorOffset: 3,
        focusOffset: 3,
        presenceSequence: 1,
        observedAt: DateTime(2026),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectFieldRemoteCursorsProvider(fieldId).overrideWithValue(cursors),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: CollaborativeProjectTextFieldRegion(
                  fieldId: fieldId,
                  controller: controller,
                  focusNode: focusNode,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text("192.168.1.20"), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r"192\.168\.1\.20 的游標")),
      findsOneWidget,
    );
    final editableState = tester.state<EditableTextState>(
      find.byType(EditableText),
    );
    final expectedCaret = editableState.renderEditable.localToGlobal(
      editableState.renderEditable
          .getLocalRectForCaret(const TextPosition(offset: 3))
          .topLeft,
    );
    final actualCaret = tester.getTopLeft(
      find.byKey(const ValueKey<String>("remote-caret-remote-a")),
    );
    expect(actualCaret.dx, closeTo(expectedCaret.dx, 0.01));
    expect(actualCaret.dy, closeTo(expectedCaret.dy, 0.01));
    semantics.dispose();
  });

  testWidgets("CRDT ProjectData field displays anchored remote cursor", (
    tester,
  ) async {
    const documentId = "projectText:worldNode:world-1:note";
    final controller = TextEditingController(text: "abcdef");
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    final cursors = <RemoteProjectTextCursorState>[
      RemoteProjectTextCursorState(
        replicaId: "remote-project-text",
        ipAddress: "192.168.1.21",
        documentId: documentId,
        anchorOffset: 4,
        focusOffset: 4,
        presenceSequence: 1,
        observedAt: DateTime(2026),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectTextRemoteCursorsProvider(
            documentId,
          ).overrideWithValue(cursors),
          collaborativeTextValueProvider(
            documentId,
          ).overrideWithValue("abcdef"),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: CollaborativeProjectTextFieldRegion(
                fieldId: documentId,
                crdtDocumentId: documentId,
                controller: controller,
                focusNode: focusNode,
                child: TextField(controller: controller, focusNode: focusNode),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text("192.168.1.21"), findsOneWidget);
    final editableState = tester.state<EditableTextState>(
      find.byType(EditableText),
    );
    final expectedCaret = editableState.renderEditable.localToGlobal(
      editableState.renderEditable
          .getLocalRectForCaret(const TextPosition(offset: 4))
          .topLeft,
    );
    final actualCaret = tester.getTopLeft(
      find.byKey(const ValueKey<String>("remote-caret-remote-project-text")),
    );
    expect(actualCaret.dx, closeTo(expectedCaret.dx, 0.01));
    expect(actualCaret.dy, closeTo(expectedCaret.dy, 0.01));
  });

  testWidgets("chapter badge exposes collaborator IP for another chapter", (
    tester,
  ) async {
    const chapterId = "chapter-2";
    final cursors = <RemoteChapterCursorState>[
      RemoteChapterCursorState(
        replicaId: "remote-chapter",
        ipAddress: "192.168.1.22",
        chapterId: chapterId,
        anchorOffset: 1,
        focusOffset: 1,
        presenceSequence: 1,
        observedAt: DateTime(2026),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chapterRemoteCursorsProvider(chapterId).overrideWithValue(cursors),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ChapterRemotePresenceBadges(chapterId: chapterId),
          ),
        ),
      ),
    );

    expect(find.text("192.168.1.22"), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>("chapter-presence-chapter-2-remote-chapter"),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    "moving a project text cursor does not edit CRDT or emit document state",
    (tester) async {
      const documentId = "projectText:worldNode:world-1:note";
      final notifier = _CursorOnlyCollaborationNotifier(documentId);
      final container = ProviderContainer(
        overrides: [collaborationProvider.overrideWith(() => notifier)],
      );
      addTearDown(container.dispose);
      var emissions = 0;
      final subscription = container.listen<CollaborationState>(
        collaborationProvider,
        (_, _) => emissions += 1,
      );
      addTearDown(subscription.close);
      final controller = TextEditingController(text: "abcdef");
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ProviderScope(
            overrides: [
              projectTextRemoteCursorsProvider(
                documentId,
              ).overrideWithValue(const <RemoteProjectTextCursorState>[]),
              collaborativeTextValueProvider(
                documentId,
              ).overrideWithValue("abcdef"),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: CollaborativeProjectTextFieldRegion(
                  fieldId: documentId,
                  crdtDocumentId: documentId,
                  controller: controller,
                  focusNode: focusNode,
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();
      emissions = 0;
      notifier.cursorUpdates = 0;

      for (var index = 0; index < 1000; index += 1) {
        controller.selection = TextSelection.collapsed(
          offset: index.isEven ? 1 : 2,
        );
      }

      expect(notifier.editCount, 0);
      expect(notifier.cursorUpdates, 1000);
      expect(emissions, 0);
    },
  );
}

final class _CursorOnlyCollaborationNotifier extends CollaborationNotifier {
  final String documentId;
  var editCount = 0;
  var cursorUpdates = 0;

  _CursorOnlyCollaborationNotifier(this.documentId);

  @override
  CollaborationState build() => CollaborationState(
    document: CollaborationDocument.seeded(
      projectUuid: "11111111-1111-4111-8111-111111111111",
      replicaId: "local",
      chapterTexts: const <String, String>{},
      projectTexts: <String, String>{documentId: "abcdef"},
    ),
  );

  @override
  void recordLocalProjectTextEdit({
    required String documentId,
    required CollaborativeTextDelta delta,
    required int anchorOffset,
    required int focusOffset,
  }) {
    editCount += 1;
  }

  @override
  void updateLocalProjectTextCursor({
    required String documentId,
    required int anchorOffset,
    required int focusOffset,
  }) {
    cursorUpdates += 1;
  }

  @override
  void clearLocalProjectTextCursor(String documentId) {}
}
