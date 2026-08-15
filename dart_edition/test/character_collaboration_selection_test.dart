import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/application/collaboration/project_collaborative_text_codec.dart";
import "package:monogatari_assistant/modules/characterview.dart";
import "package:monogatari_assistant/presentation/providers/collaboration_providers.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";

void main() {
  testWidgets(
    "switching a focused character does not publish its name to the old CRDT owner",
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 2400);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final recorder = _RecordingCollaborationNotifier();
      final container = ProviderContainer(
        overrides: [collaborationProvider.overrideWith(() => recorder)],
      );
      addTearDown(container.dispose);
      container.read(characterDataProvider.notifier).setCharacterData(
        const <String, CharacterEntryData>{
          "character-1": CharacterEntryData(
            characterId: "character-1",
            displayName: "First Character",
            legacyFields: <String, String>{"nanoId": "First_01"},
            textFields: <String, String>{"name": "First Character"},
          ),
          "character-2": CharacterEntryData(
            characterId: "character-2",
            displayName: "Second Character",
            legacyFields: <String, String>{"nanoId": "Second02"},
            textFields: <String, String>{"name": "Second Character"},
          ),
        },
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: CharacterView())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text("Second Character"));
      await tester.pumpAndSettle();
      final nameField = _findTextFieldByLabel(tester, "姓名（必填）：");
      await tester.tap(nameField);
      await tester.pump();
      expect(tester.widget<TextField>(nameField).focusNode?.hasFocus, isTrue);
      recorder.edits.clear();

      await tester.tap(find.text("First Character"));
      await tester.pumpAndSettle();

      final firstDocumentId = ProjectCollaborativeTextCodec.characterFieldId(
        "character-1",
        "name",
      );
      final secondDocumentId = ProjectCollaborativeTextCodec.characterFieldId(
        "character-2",
        "name",
      );
      expect(recorder.edits[secondDocumentId], isNull);
      expect(recorder.edits[firstDocumentId], "First Character");
      expect(
        container.read(characterDataProvider)["character-2"]?.displayName,
        "Second Character",
      );
    },
  );
}

final class _RecordingCollaborationNotifier extends CollaborationNotifier {
  final Map<String, String> edits = <String, String>{};

  @override
  CollaborationState build() => const CollaborationState();

  @override
  void recordLocalProjectTextEdit({
    required String documentId,
    required String nextText,
    required int anchorOffset,
    required int focusOffset,
  }) {
    edits[documentId] = nextText;
  }
}

Finder _findTextFieldByLabel(WidgetTester tester, String label) {
  final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
  final index = fields.indexWhere(
    (field) => field.decoration?.labelText == label,
  );
  expect(index, isNonNegative, reason: "找不到欄位：$label");
  return find.byType(TextField).at(index);
}
