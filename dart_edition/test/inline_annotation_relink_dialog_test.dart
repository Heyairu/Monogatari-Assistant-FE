import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation_relink_dialog.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation_target_resolver.dart";

void main() {
  testWidgets("relink dialog filters and returns the selected target", (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (buildContext) {
            context = buildContext;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    const alice = InlineAnnotationTargetInfo(
      id: "4e251fc2-1e2b-4f78-93da-91f8c76d9a92",
      primaryName: "艾莉絲",
      displayName: "艾莉絲",
      displayNameIsAlias: false,
      path: "人物 › 主角",
    );
    const bob = InlineAnnotationTargetInfo(
      id: "65388495-7eb2-4a2c-9258-3af82aa27791",
      primaryName: "鮑伯",
      displayName: "鮑伯",
      displayNameIsAlias: false,
    );

    final resultFuture = InlineAnnotationRelinkDialog.show(
      context: context,
      candidates: const [alice, bob],
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey("inline-annotation-relink-search")),
      "主角",
    );
    await tester.pump();

    expect(
      find.byKey(ValueKey("inline-annotation-relink-${alice.id}")),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey("inline-annotation-relink-${bob.id}")),
      findsNothing,
    );
    await tester.tap(
      find.byKey(ValueKey("inline-annotation-relink-${alice.id}")),
    );
    await tester.pumpAndSettle();

    expect(await resultFuture, same(alice));
  });
}
