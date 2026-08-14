import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/domain/models/p2p_sync_models.dart";
import "package:monogatari_assistant/presentation/widgets/p2p_conflict_resolution_dialog.dart";

P2pFieldConflictItem _conflict(
  String field, {
  required Object? local,
  required Object? remote,
}) {
  return P2pFieldConflictItem(
    groupId: "character-lia",
    groupType: "角色",
    groupLabel: "莉亞",
    fieldPathSegments: <String>[field],
    base: const P2pFieldValue.present("原始"),
    local: P2pFieldValue.present(local),
    remote: P2pFieldValue.present(remote),
  );
}

void main() {
  testWidgets(
    "conflict dialog resolves fields through group default and override",
    (WidgetTester tester) async {
      final personality = _conflict("性格", local: "謹慎", remote: "果斷");
      final note = _conflict("備註", local: "本機備註", remote: "對方備註");
      P2pConflictResolutionResult? applied;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: P2pConflictResolutionDialog(
              conflicts: <P2pFieldConflictItem>[personality, note],
              onApply: (result) => applied = result,
              onCancel: () {},
            ),
          ),
        ),
      );

      FilledButton applyButton = tester.widget(
        find.byKey(const Key("p2p-conflict-apply")),
      );
      expect(applyButton.onPressed, isNull);
      expect(find.text("尚有 2 個衝突欄位未決定"), findsOneWidget);

      final groupKey =
          "${"角色".length}:角色/${"character-lia".length}:character-lia";
      await tester.tap(find.byKey(Key("p2p-conflict-group-$groupKey")));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key("p2p-group-remote-$groupKey")));
      await tester.pump();

      applyButton = tester.widget(find.byKey(const Key("p2p-conflict-apply")));
      expect(applyButton.onPressed, isNotNull);
      expect(find.text("所有 2 個衝突欄位皆已決定"), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(Key("p2p-field-${note.conflictId}")),
      );
      await tester.tap(find.byKey(Key("p2p-field-${note.conflictId}")));
      await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(Key("p2p-field-local-${note.conflictId}")),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key("p2p-field-local-${note.conflictId}")));
      await tester.pump();
      await tester.tap(find.byKey(const Key("p2p-conflict-apply")));

      expect(applied, isNotNull);
      expect(applied!.sideFor(personality), P2pConflictSide.remote);
      expect(applied!.sideFor(note), P2pConflictSide.local);
    },
  );

  testWidgets("cancel does not produce a resolution", (
    WidgetTester tester,
  ) async {
    final conflict = _conflict("性格", local: "謹慎", remote: "果斷");
    var cancelled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: P2pConflictResolutionDialog(
            conflicts: <P2pFieldConflictItem>[conflict],
            onApply: (_) => fail("resolution must not be produced"),
            onCancel: () => cancelled = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key("p2p-conflict-cancel")));
    expect(cancelled, isTrue);
  });
}
