import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:monogatari_assistant/presentation/providers/collaboration_providers.dart";
import "package:monogatari_assistant/presentation/widgets/remote_text_cursor_overlay.dart";

void main() {
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
}
