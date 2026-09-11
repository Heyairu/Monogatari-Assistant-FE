import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation_edit_dialog.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation_parser.dart";

void main() {
  const uuid = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";

  testWidgets("structured editor returns validated canonical syntax", (
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
    final annotation = const InlineAnnotationParser()
        .parse("//@<$uuid|小艾>{主角}//")
        .single;

    final resultFuture = InlineAnnotationEditDialog.show(
      context: context,
      annotation: annotation,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey("inline-annotation-display-text")),
      "艾/莉絲",
    );
    await tester.enterText(
      find.byKey(const ValueKey("inline-annotation-note")),
      "目前名稱",
    );
    await tester.tap(find.byKey(const ValueKey("inline-annotation-save")));
    await tester.pumpAndSettle();

    expect(await resultFuture, "//@<$uuid|艾\\/莉絲>{目前名稱}//");
  });

  testWidgets("structured editor keeps invalid UUID visible for correction", (
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
    final annotation = const InlineAnnotationParser()
        .parse("//@<$uuid|艾莉絲>//")
        .single;

    InlineAnnotationEditDialog.show(context: context, annotation: annotation);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey("inline-annotation-target")),
      "not-a-uuid",
    );
    await tester.tap(find.byKey(const ValueKey("inline-annotation-save")));
    await tester.pump();

    expect(
      find.byKey(const ValueKey("inline-annotation-edit-error")),
      findsOneWidget,
    );
    expect(find.text("編輯標記"), findsOneWidget);
  });

  testWidgets("structured editor restores an empty display text", (
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
    final annotation = const InlineAnnotationParser()
        .parse("//@<$uuid|艾莉絲>//")
        .single;
    final resultFuture = InlineAnnotationEditDialog.show(
      context: context,
      annotation: annotation,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey("inline-annotation-display-text")),
      "   ",
    );
    await tester.tap(find.byKey(const ValueKey("inline-annotation-save")));
    await tester.pumpAndSettle();

    expect(await resultFuture, "//@<$uuid|艾莉絲>//");
  });

  testWidgets("raw syntax editing is available in the full editor", (
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
    final annotation = const InlineAnnotationParser()
        .parse("//@<$uuid|艾莉絲>//")
        .single;
    final resultFuture = InlineAnnotationEditDialog.show(
      context: context,
      annotation: annotation,
      rawSyntax: "//@<$uuid|艾莉絲>//",
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey("inline-annotation-raw-syntax-editor")),
      "//@+^CE<$uuid|小艾>{主角}//",
    );
    await tester.tap(find.byKey(const ValueKey("inline-annotation-save")));
    await tester.pumpAndSettle();

    expect(await resultFuture, "//@+^CE<$uuid|小艾>{主角}//");
  });
}
