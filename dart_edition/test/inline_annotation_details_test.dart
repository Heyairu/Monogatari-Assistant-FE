import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation_details_dialog.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation_parser.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation_projection.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation_target_resolver.dart";
import "package:monogatari_assistant/features/inline_annotations/mosaic_editing_controller.dart";
import "package:monogatari_assistant/models/character_data.dart";
import "package:monogatari_assistant/models/outline_data.dart";
import "package:monogatari_assistant/models/world_settings_data.dart";

void main() {
  const uuid = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";

  testWidgets(
    "quick note edits are escaped and preserve an empty display fallback",
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      const raw = "//@<$uuid|小艾>{主角}//";
      final resultFuture = InlineAnnotationDetailsDialog.show(
        context: context,
        annotation: const InlineAnnotationParser().parse(raw).single,
        rawSyntax: raw,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey("inline-annotation-quick-display-text")),
        "",
      );
      await tester.enterText(
        find.byKey(const ValueKey("inline-annotation-note")),
        "新{備註}/",
      );
      await tester.tap(
        find.byKey(const ValueKey("inline-annotation-quick-apply")),
      );
      await tester.pumpAndSettle();
      final result = await resultFuture;
      expect(result?.action, InlineAnnotationDetailsAction.applySyntax);
      final parsed = const InlineAnnotationParser()
          .parse(result!.rawSyntax!)
          .single;
      expect(parsed.displayText, "小艾");
      expect(parsed.targetId, uuid);
      expect(parsed.note, "新{備註}/");
    },
  );

  test("target resolver recognizes a character alias", () {
    final annotation = const InlineAnnotationParser()
        .parse("//@<$uuid|小艾>//")
        .single;
    final target = const InlineAnnotationTargetResolver().resolve(
      annotation: annotation,
      characters: {
        uuid: const CharacterEntryData(
          characterId: uuid,
          displayName: "艾莉絲",
          aliases: [
            CharacterAlias(values: ["小艾"]),
          ],
        ),
      },
    );

    expect(target?.primaryName, "艾莉絲");
    expect(target?.displayName, "小艾");
    expect(target?.displayNameIsAlias, isTrue);
  });

  test("target resolver returns nested event and location paths", () {
    const eventId = "65388495-7eb2-4a2c-9258-3af82aa27791";
    const sceneId = "74a62f13-dc81-4d5d-9293-7a0e43e235a2";
    const locationId = "1dc6bab9-352b-47d6-b66e-00bc9d894750";
    final eventAnnotation = const InlineAnnotationParser()
        .parse("//#<$sceneId|衝突>//")
        .single;
    final locationAnnotation = const InlineAnnotationParser()
        .parse("//!<$locationId|城門>//")
        .single;
    final resolver = const InlineAnnotationTargetResolver();

    final event = resolver.resolve(
      annotation: eventAnnotation,
      outline: [
        StorylineData(
          storylineName: "第一卷",
          scenes: [
            StoryEventData(
              storyEventUUID: eventId,
              storyEvent: "王都篇",
              scenes: [SceneData(sceneUUID: sceneId, sceneName: "城門衝突")],
            ),
          ],
        ),
      ],
    );
    final location = resolver.resolve(
      annotation: locationAnnotation,
      locations: [
        LocationData(
          localName: "王都",
          child: [LocationData(id: locationId, localName: "城門")],
        ),
      ],
    );

    expect(event?.primaryName, "城門衝突");
    expect(event?.path, "第一卷 › 王都篇 › 城門衝突");
    expect(location?.path, "王都 › 城門");
  });

  test("annotation detail operations preserve or remove raw metadata", () {
    const raw = "前//@<$uuid|小艾>{主角}//後";
    final controller = MosaicEditingController(rawText: raw);
    addTearDown(controller.dispose);
    final sourceStart = controller.annotations.single.sourceRange.start;

    expect(
      controller.rawSyntaxAtSourceStart(sourceStart),
      "//@<$uuid|小艾>{主角}//",
    );
    expect(controller.updateAnnotationDisplayText(sourceStart, "艾/莉絲"), isTrue);
    expect(controller.displayText, "前$inlineAnnotationPlaceholder艾/莉絲後");
    expect(controller.rawText, "前//@<$uuid|艾\\/莉絲>{主角}//後");

    final updatedStart = controller.annotations.single.sourceRange.start;
    expect(controller.removeAnnotationKeepText(updatedStart), isTrue);
    expect(controller.rawText, "前艾/莉絲後");
    expect(controller.annotations, isEmpty);
    expect(controller.selection, const TextSelection.collapsed(offset: 5));
  });

  test("empty display update keeps the existing display text", () {
    final controller = MosaicEditingController(rawText: "//@<$uuid|小艾>//");
    addTearDown(controller.dispose);

    expect(controller.updateAnnotationDisplayText(0, "   "), isTrue);
    expect(controller.rawText, "//@<$uuid|小艾>//");
    expect(controller.displayText, "$inlineAnnotationPlaceholder小艾");
  });

  testWidgets("click popup only edits display text and stays by its anchor", (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (buildContext) {
            context = buildContext;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    final annotation = const InlineAnnotationParser()
        .parse("//@<$uuid|小艾>{主角}//")
        .single;
    final resultFuture = InlineAnnotationDetailsDialog.show(
      context: context,
      annotation: annotation,
      rawSyntax: "//@<$uuid|小艾>{主角}//",
      target: const InlineAnnotationTargetInfo(
        id: uuid,
        primaryName: "艾莉絲",
        displayName: "小艾",
        displayNameIsAlias: true,
      ),
      anchor: const Rect.fromLTWH(100, 120, 2, 2),
    );
    await tester.pumpAndSettle();

    final popup = find.byKey(const ValueKey("inline-annotation-quick-editor"));
    expect(popup, findsOneWidget);
    expect(tester.getTopLeft(popup).dx, greaterThanOrEqualTo(108));
    expect(tester.getSize(popup).width, lessThanOrEqualTo(320));
    expect(find.text("//@<$uuid|小艾>{主角}//"), findsOneWidget);
    expect(
      find.byKey(const ValueKey("inline-annotation-open-target")),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey("inline-annotation-basic-info")),
      findsOneWidget,
    );
    expect(find.text("UUID"), findsOneWidget);
    final syntaxTop = tester.getTopLeft(
      find.byKey(const ValueKey("inline-annotation-quick-syntax")),
    );
    final infoTop = tester.getTopLeft(
      find.byKey(const ValueKey("inline-annotation-basic-info")),
    );
    final displayTop = tester.getTopLeft(
      find.byKey(const ValueKey("inline-annotation-quick-display-text")),
    );
    expect(infoTop.dy, greaterThan(displayTop.dy));
    expect(syntaxTop.dy, greaterThan(infoTop.dy));
    final syntaxField = tester.widget<TextField>(
      find.byKey(const ValueKey("inline-annotation-quick-syntax")),
    );
    expect(syntaxField.maxLines, 1);
    await tester.enterText(
      find.byKey(const ValueKey("inline-annotation-quick-display-text")),
      "   ",
    );
    await tester.tap(
      find.byKey(const ValueKey("inline-annotation-quick-apply")),
    );
    await tester.pumpAndSettle();

    final result = await resultFuture;
    expect(result?.action, InlineAnnotationDetailsAction.applyDisplayText);
    expect(result?.displayText, "小艾");
  });

  testWidgets("first-level popup validates and applies edited raw syntax", (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (buildContext) {
            context = buildContext;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    final annotation = const InlineAnnotationParser()
        .parse("//@<$uuid|小艾>//")
        .single;
    final resultFuture = InlineAnnotationDetailsDialog.show(
      context: context,
      annotation: annotation,
      rawSyntax: "//@<$uuid|小艾>//",
      anchor: const Rect.fromLTWH(100, 120, 2, 2),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey("inline-annotation-quick-syntax")),
      "//!+^CE<$uuid|王都>{新備註}//",
    );
    await tester.tap(
      find.byKey(const ValueKey("inline-annotation-quick-apply")),
    );
    await tester.pumpAndSettle();

    final result = await resultFuture;
    expect(result?.action, InlineAnnotationDetailsAction.applySyntax);
    expect(result?.rawSyntax, "//!+^CE<$uuid|王都>{新備註}//");
  });

  testWidgets("first-level popup opens its resolved target node", (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (buildContext) {
            context = buildContext;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    final annotation = const InlineAnnotationParser()
        .parse("//@<$uuid|小艾>//")
        .single;
    final resultFuture = InlineAnnotationDetailsDialog.show(
      context: context,
      annotation: annotation,
      rawSyntax: "//@<$uuid|小艾>//",
      target: const InlineAnnotationTargetInfo(
        id: uuid,
        primaryName: "艾莉絲",
        displayName: "小艾",
        displayNameIsAlias: true,
      ),
      anchor: const Rect.fromLTWH(100, 120, 2, 2),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey("inline-annotation-open-target")),
    );
    await tester.pumpAndSettle();

    final result = await resultFuture;
    expect(result?.action, InlineAnnotationDetailsAction.navigateToTarget);
  });

  testWidgets("missing target offers relink from the compact actions menu", (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (buildContext) {
            context = buildContext;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    final annotation = const InlineAnnotationParser()
        .parse("//@<$uuid|幽靈>//")
        .single;
    final resultFuture = InlineAnnotationDetailsDialog.show(
      context: context,
      annotation: annotation,
      rawSyntax: "//@<$uuid|幽靈>//",
      anchor: const Rect.fromLTWH(100, 120, 2, 2),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey("inline-annotation-open-target")),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey("inline-annotation-more")));
    await tester.pumpAndSettle();
    expect(find.text("重新連結遺失對象"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey("inline-annotation-relink")));
    await tester.pumpAndSettle();

    final result = await resultFuture;
    expect(result?.action, InlineAnnotationDetailsAction.relinkTarget);
  });

  testWidgets("resolved stale name can update or remove the annotation", (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (buildContext) {
            context = buildContext;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    final annotation = const InlineAnnotationParser()
        .parse("//@<$uuid|小艾>//")
        .single;
    final resultFuture = InlineAnnotationDetailsDialog.show(
      context: context,
      annotation: annotation,
      rawSyntax: "//@<$uuid|小艾>//",
      target: const InlineAnnotationTargetInfo(
        id: uuid,
        primaryName: "艾莉絲",
        displayName: "小艾",
        displayNameIsAlias: true,
      ),
      anchor: const Rect.fromLTWH(100, 120, 2, 2),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey("inline-annotation-more")));
    await tester.pumpAndSettle();
    expect(find.text("更新為目前名稱"), findsOneWidget);
    expect(find.text("移除標記但保留文字"), findsOneWidget);
    expect(find.text("重新連結遺失對象"), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey("inline-annotation-update-name")),
    );
    await tester.pumpAndSettle();

    final result = await resultFuture;
    expect(result?.action, InlineAnnotationDetailsAction.updateToPrimaryName);
  });

  test("full syntax replacement updates all annotation fields atomically", () {
    const raw = "前//@<$uuid|小艾>{主角}//後";
    final controller = MosaicEditingController(rawText: raw);
    addTearDown(controller.dispose);
    final sourceStart = controller.annotations.single.sourceRange.start;

    expect(
      controller.replaceAnnotationSyntax(
        sourceStart,
        "//!+^CE<$uuid|王都>{新備註}//",
      ),
      isTrue,
    );

    final annotation = controller.annotations.single;
    expect(annotation.kind.name, "location");
    expect(annotation.state.name, "start");
    expect(annotation.colors.value, "CE");
    expect(annotation.displayText, "王都");
    expect(annotation.note, "新備註");
    expect(controller.displayText, "前$inlineAnnotationPlaceholder王都後");
  });

  test("full syntax replacement rejects malformed or trailing text", () {
    final controller = MosaicEditingController(rawText: "//@<$uuid|小艾>//");
    addTearDown(controller.dispose);

    expect(controller.replaceAnnotationSyntax(0, "//@<broken>//"), isFalse);
    expect(
      controller.replaceAnnotationSyntax(0, "//@<$uuid|艾莉絲>//尾巴"),
      isFalse,
    );
    expect(controller.rawText, "//@<$uuid|小艾>//");
  });

  test("full syntax replacement restores an emptied display label", () {
    final controller = MosaicEditingController(
      rawText: "//@+^CE<$uuid|小艾>{原備註}//",
    );
    addTearDown(controller.dispose);

    expect(
      controller.replaceAnnotationSyntax(0, "//!-^AF<$uuid|   >{新備註}//"),
      isTrue,
    );

    expect(controller.rawText, "//!-^AF<$uuid|小艾>{新備註}//");
    final annotation = controller.annotations.single;
    expect(annotation.displayText, "小艾");
    expect(annotation.kind, InlineAnnotationKind.location);
    expect(annotation.state, InlineAnnotationState.end);
    expect(annotation.colors.value, "AF");
    expect(annotation.note, "新備註");
  });

  test("missing target resolves to null", () {
    final annotation = const InlineAnnotationParser()
        .parse("//@<$uuid|幽靈>//")
        .single;

    expect(
      const InlineAnnotationTargetResolver().resolve(annotation: annotation),
      isNull,
    );
  });

  test("relink candidates stay within the requested type", () {
    const secondUuid = "65388495-7eb2-4a2c-9258-3af82aa27791";
    final resolver = const InlineAnnotationTargetResolver();
    final characters = resolver.candidates(
      kind: InlineAnnotationKind.character,
      characters: {
        uuid: const CharacterEntryData(characterId: uuid, displayName: "艾莉絲"),
      },
      locations: [LocationData(id: secondUuid, localName: "王都")],
    );

    expect(characters, hasLength(1));
    expect(characters.single.id, uuid);
    expect(characters.single.primaryName, "艾莉絲");
  });

  test("relink updates UUID and name while preserving annotation metadata", () {
    const replacementUuid = "65388495-7eb2-4a2c-9258-3af82aa27791";
    final controller = MosaicEditingController(
      rawText: "//@+^CE<$uuid|舊名稱>{主角}//",
    );
    addTearDown(controller.dispose);

    expect(
      controller.relinkAnnotationTarget(
        sourceStart: 0,
        targetId: replacementUuid,
        displayText: "艾莉絲",
      ),
      isTrue,
    );

    final annotation = controller.annotations.single;
    expect(annotation.targetId, replacementUuid);
    expect(annotation.displayText, "艾莉絲");
    expect(annotation.state.name, "start");
    expect(annotation.colors.value, "CE");
    expect(annotation.note, "主角");
  });
}
