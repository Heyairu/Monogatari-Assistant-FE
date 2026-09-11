import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation_target_resolver.dart";
import "package:monogatari_assistant/features/inline_annotations/mosaic_editing_controller.dart";
import "package:monogatari_assistant/features/inline_annotations/inline_annotation_projection.dart";
import "package:monogatari_assistant/features/poppin/poppin.dart";
import "package:monogatari_assistant/models/character_data.dart";
import "package:monogatari_assistant/models/outline_data.dart";
import "package:monogatari_assistant/models/plan_data.dart";
import "package:monogatari_assistant/models/world_settings_data.dart";

void main() {
  const uuid = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";
  const engine = MosaicIntelliSenseEngine();

  test("less-than trigger filters compatible target candidates", () {
    final session = engine.build(
      rawText: "她看見 //@<艾",
      rawCaret: "她看見 //@<艾".length,
      loadTargets: (kind) {
        expect(kind, InlineAnnotationKind.character);
        return const [
          InlineAnnotationTargetInfo(
            id: uuid,
            primaryName: "艾莉絲",
            displayName: "艾莉絲",
            displayNameIsAlias: false,
          ),
          InlineAnnotationTargetInfo(
            id: "65388495-7eb2-4a2c-9258-3af82aa27791",
            primaryName: "鮑伯",
            displayName: "鮑伯",
            displayNameIsAlias: false,
          ),
        ];
      },
    );

    expect(session?.kind, MosaicCompletionKind.target);
    expect(session?.candidates, hasLength(1));
    expect(session?.candidates.single.label, "艾莉絲");
    expect(session?.candidates.single.insertText, "//@<$uuid|艾莉絲>//");
  });

  test("characters expose primary names and aliases in a submenu", () {
    final targets = const InlineAnnotationTargetResolver().candidates(
      kind: InlineAnnotationKind.character,
      characters: const {
        uuid: CharacterEntryData(
          characterId: uuid,
          displayName: "艾莉絲",
          aliases: [
            CharacterAlias(values: ["小艾", "愛麗絲"]),
          ],
        ),
      },
    );
    final filtered = engine.build(
      rawText: "//@<小",
      rawCaret: "//@<小".length,
      loadTargets: (_) => targets,
    );
    final expanded = engine.build(
      rawText: "//@<",
      rawCaret: "//@<".length,
      loadTargets: (_) => targets,
    );

    expect(filtered?.candidates, hasLength(1));
    expect(filtered?.candidates.single.label, "小艾");
    expect(filtered?.candidates.single.insertText, "//@<$uuid|小艾>//");
    expect(expanded?.candidates, hasLength(2));
    final alice = expanded?.candidates.firstWhere(
      (candidate) => candidate.id == uuid,
    );
    expect(alice?.label, "艾莉絲");
    expect(alice?.children.map((candidate) => candidate.label), [
      "艾莉絲",
      "小艾",
      "愛麗絲",
    ]);
    expect(alice?.insertText, "//@<$uuid|艾莉絲>//");
  });

  test("events browse outline levels and search matches stay flat", () {
    const outlineId = "b2a65ea0-40fe-4e31-8dd8-da8dff633410";
    const eventId = "3837044f-9a59-47f4-a917-d80765577861";
    const sceneId = "d862b9da-dac2-4a71-b342-10e86bdc474d";
    final targets = const InlineAnnotationTargetResolver().candidates(
      kind: InlineAnnotationKind.event,
      outline: [
        StorylineData(
          chapterUUID: outlineId,
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
    final browsing = engine.build(
      rawText: "正文#",
      rawCaret: 3,
      loadTargets: (_) => targets,
    );
    final searching = engine.build(
      rawText: "//#<城門",
      rawCaret: "//#<城門".length,
      loadTargets: (_) => targets,
    );

    final outline = browsing?.candidates.firstWhere(
      (candidate) => candidate.id == outlineId,
    );
    expect(outline?.label, "第一卷");
    final event = outline?.children.firstWhere(
      (candidate) => candidate.id == eventId,
    );
    expect(event?.label, "王都篇");
    final scene = event?.children.firstWhere(
      (candidate) => candidate.id == sceneId,
    );
    expect(scene?.label, "城門衝突");
    expect(outline?.detail, contains("大箱"));
    expect(event?.detail, contains("中箱"));
    expect(scene?.detail, contains("小箱"));
    expect(outline?.insertText, "//#<$outlineId|第一卷>//");
    expect(event?.insertText, "//#<$eventId|王都篇>//");
    expect(scene?.insertText, "//#<$sceneId|城門衝突>//");
    expect(outline?.children.last.label, "新增事件…");
    expect(event?.children.last.label, "新增場景…");
    expect(searching?.candidates, hasLength(1));
    expect(searching?.candidates.single.label, "城門衝突");
    expect(searching?.candidates.single.children, isEmpty);
    expect(searching?.candidates.single.detail, contains("第一卷 › 王都篇"));
  });

  test("locations browse parent and child levels", () {
    const cityId = "da268faa-95d6-477d-b2c9-6a4d6c1cb06d";
    const districtId = "a01b5796-9e39-4357-8817-5cf38cce2eb8";
    const churchId = "ef13f2a7-1907-401b-bd69-a73b4aeedc21";
    final targets = const InlineAnnotationTargetResolver().candidates(
      kind: InlineAnnotationKind.location,
      locations: [
        LocationData(
          id: cityId,
          localName: "王都",
          child: [
            LocationData(
              id: districtId,
              localName: "舊城區",
              child: [LocationData(id: churchId, localName: "教堂")],
            ),
          ],
        ),
      ],
    );
    final session = engine.build(
      rawText: "正文!",
      rawCaret: 3,
      loadTargets: (_) => targets,
    );

    final city = session?.candidates.firstWhere(
      (candidate) => candidate.id == cityId,
    );
    expect(city?.label, "王都");
    final district = city?.children.firstWhere(
      (candidate) => candidate.id == districtId,
    );
    expect(district?.label, "舊城區");
    expect(
      district?.children
          .firstWhere((candidate) => candidate.id == churchId)
          .label,
      "教堂",
    );
    expect(city?.children.last.label, "新增子地點…");
    expect(district?.children.last.label, "新增子地點…");
  });

  test("accepting a target replaces the draft in one raw update", () {
    final controller = MosaicEditingController(rawText: "前//@<");
    addTearDown(controller.dispose);
    final session = engine.build(
      rawText: controller.rawText,
      rawCaret: controller.rawText.length,
      loadTargets: (_) => const [
        InlineAnnotationTargetInfo(
          id: uuid,
          primaryName: "艾莉絲",
          displayName: "艾莉絲",
          displayNameIsAlias: false,
        ),
      ],
    )!;
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.replaceRawRange(
      session.rawReplacementRange,
      session.candidates
          .firstWhere((candidate) => candidate.createTargetKind == null)
          .insertText,
    );

    expect(controller.rawText, "前//@<$uuid|艾莉絲>//");
    expect(controller.displayText, "前$inlineAnnotationPlaceholder艾莉絲");
    expect(notifications, 1);
  });

  test("target lists end with a create action", () {
    final session = engine.build(
      rawText: "正文@",
      rawCaret: 3,
      loadTargets: (_) => const [],
    );

    expect(session?.candidates, hasLength(1));
    expect(session?.candidates.single.id, "create-character");
    expect(
      session?.candidates.single.createTargetKind,
      InlineAnnotationKind.character,
    );
    expect(session?.candidates.single.label, "新增人物…");
  });

  test("large target levels are capped before candidate trees are built", () {
    final targets = [
      for (var index = 149; index >= 0; index--)
        InlineAnnotationTargetInfo(
          id: "00000000-0000-4000-8000-${index.toString().padLeft(12, "0")}",
          primaryName: "人物${index.toString().padLeft(3, "0")}",
          displayName: "人物$index",
          displayNameIsAlias: false,
        ),
    ];

    final session = engine.build(
      rawText: "正文@",
      rawCaret: 3,
      loadTargets: (_) => targets,
    );

    expect(
      session?.candidates,
      hasLength(MosaicIntelliSenseEngine.maxCandidatesPerLevel),
    );
    expect(session?.candidates.first.label, "人物000");
    expect(session?.candidates[98].label, "人物098");
    expect(session?.candidates.last.id, "create-character");
  });

  test("large hierarchy levels retain their create action", () {
    const rootId = "da268faa-95d6-477d-b2c9-6a4d6c1cb06d";
    final root = InlineAnnotationTargetInfo(
      id: rootId,
      primaryName: "王都",
      displayName: "王都",
      displayNameIsAlias: false,
      children: [
        for (var index = 0; index < 150; index++)
          InlineAnnotationTargetInfo(
            id: "10000000-0000-4000-8000-${index.toString().padLeft(12, "0")}",
            primaryName: "區域$index",
            displayName: "區域$index",
            displayNameIsAlias: false,
          ),
      ],
    );

    final session = engine.build(
      rawText: "正文!",
      rawCaret: 3,
      loadTargets: (_) => [root, ...root.children],
    );
    final rootCandidate = session?.candidates.firstWhere(
      (candidate) => candidate.id == rootId,
    );

    expect(
      rootCandidate?.children,
      hasLength(MosaicIntelliSenseEngine.maxCandidatesPerLevel),
    );
    expect(rootCandidate?.children.last.label, "新增子地點…");
  });

  test("foreshadow and plan candidates expose their current status", () {
    const hiddenId = "326feff7-0a30-4bce-a47f-2f0036887cf0";
    const revealedId = "956c67e0-90d8-4794-8aa8-76dc1385a749";
    const activeId = "2a25b8cc-20fc-4fc7-807b-5cb08d2bf36b";
    const doneId = "da4b3f25-d7ea-4583-9b4a-a20d08d11886";
    const resolver = InlineAnnotationTargetResolver();
    final foreshadows = resolver.candidates(
      kind: InlineAnnotationKind.foreshadowing,
      foreshadows: [
        ForeshadowItem(id: hiddenId, title: "懷錶"),
        ForeshadowItem(id: revealedId, title: "信件", isRevealed: true),
      ],
    );
    final plans = resolver.candidates(
      kind: InlineAnnotationKind.plan,
      plans: [
        UpdatePlanItem(id: activeId, title: "修訂序章"),
        UpdatePlanItem(id: doneId, title: "補完設定", isDone: true),
      ],
    );

    final foreshadowSession = engine.build(
      rawText: "正文?",
      rawCaret: 3,
      loadTargets: (_) => foreshadows,
    );
    final planSession = engine.build(
      rawText: "正文&",
      rawCaret: 3,
      loadTargets: (_) => plans,
    );

    expect(
      foreshadowSession?.candidates
          .firstWhere((candidate) => candidate.id == hiddenId)
          .detail,
      "伏筆 · 未回收",
    );
    expect(
      foreshadowSession?.candidates
          .firstWhere((candidate) => candidate.id == revealedId)
          .detail,
      "伏筆 · 已回收",
    );
    expect(
      planSession?.candidates
          .firstWhere((candidate) => candidate.id == activeId)
          .detail,
      "計畫 · 進行中",
    );
    expect(
      planSession?.candidates
          .firstWhere((candidate) => candidate.id == doneId)
          .detail,
      "計畫 · 已完成",
    );
  });

  test("color and manual triggers provide templates and safe literals", () {
    final color = engine.build(
      rawText: "//^",
      rawCaret: 3,
      loadTargets: (_) => const [],
    );
    final slash = engine.build(
      rawText: "文字/",
      rawCaret: 3,
      loadTargets: (kind) => kind == InlineAnnotationKind.character
          ? const [
              InlineAnnotationTargetInfo(
                id: uuid,
                primaryName: "艾莉絲",
                displayName: "艾莉絲",
                displayNameIsAlias: false,
              ),
            ]
          : const [],
    );
    final backslash = engine.build(
      rawText: "文字\\",
      rawCaret: 3,
      loadTargets: (_) => const [],
    );

    expect(color?.kind, MosaicCompletionKind.color);
    expect(color?.candidates.map((item) => item.id), contains("color-C"));
    final pinkBackground = color?.candidates.firstWhere(
      (item) => item.id == "color-C",
    );
    expect(
      pinkBackground?.children
          .firstWhere((item) => item.id == "color-C-foreground-E")
          .insertText,
      "CE",
    );
    const expectedManualLabels = [
      "@",
      "!",
      "#",
      "?",
      "&",
      "^",
      "@<>",
      "!<>",
      "#<>",
      "?<>",
      "&<>",
      "^<>",
    ];
    expect(
      slash?.candidates.take(12).map((item) => item.label),
      expectedManualLabels,
    );
    expect(
      backslash?.candidates.take(12).map((item) => item.label),
      expectedManualLabels,
    );
    expect(
      slash?.candidates
          .firstWhere((item) => item.id == "literal-slash")
          .insertText,
      r"\/",
    );
    expect(
      backslash?.candidates
          .firstWhere((item) => item.id == "literal-backslash")
          .insertText,
      r"\\",
    );
    expect(
      slash?.candidates
          .firstWhere((item) => item.id == "template-character")
          .insertText,
      "//@<",
    );
    expect(
      slash?.candidates
          .firstWhere((item) => item.id == "manual-character")
          .children
          .firstWhere((item) => item.id == uuid)
          .insertText,
      "//@<$uuid|艾莉絲>//",
    );
    expect(
      slash?.candidates
          .firstWhere((item) => item.id == "manual-character")
          .submenuOnly,
      isTrue,
    );
    expect(
      slash?.candidates
          .firstWhere((item) => item.id == "manual-highlight")
          .children
          .map((item) => item.id),
      contains("highlight-C"),
    );
  });

  test("manual triggers respect escaped and continued literal input", () {
    MosaicCompletionSession? build(String rawText) => engine.build(
      rawText: rawText,
      rawCaret: rawText.length,
      loadTargets: (_) => const [],
    );

    expect(build(r"\/"), isNull);
    expect(build(r"\\"), isNull);
    expect(build("/x"), isNull);
    expect(build("/@"), isNull);
    expect(build("/#"), isNull);
    expect(build("/^"), isNull);
    expect(build(r"/\"), isNull);

    final thirdBackslash = build(r"\\\");
    expect(
      thirdBackslash?.rawReplacementRange,
      const TextRange(start: 2, end: 3),
    );
    final slashAfterEscapedBackslash = build(r"\\/");
    expect(slashAfterEscapedBackslash, isNull);

    final escapedDelimiter = build(r"\//");
    expect(escapedDelimiter, isNotNull);
    expect(
      escapedDelimiter!.rawReplacementRange,
      const TextRange(start: 0, end: 3),
    );
    expect(escapedDelimiter.candidates.first.label, "@");
  });

  test("external less-than opens typed object submenus", () {
    final loadedKinds = <InlineAnnotationKind>[];
    final session = engine.build(
      rawText: "正文<",
      rawCaret: 3,
      loadTargets: (kind) {
        loadedKinds.add(kind);
        return kind == InlineAnnotationKind.character
            ? const [
                InlineAnnotationTargetInfo(
                  id: uuid,
                  primaryName: "艾莉絲",
                  displayName: "艾莉絲",
                  displayNameIsAlias: false,
                ),
              ]
            : const [];
      },
    );

    expect(session?.kind, MosaicCompletionKind.target);
    expect(session?.rawReplacementRange, const TextRange(start: 2, end: 3));
    expect(session?.candidates.map((candidate) => candidate.label), [
      "@ 人物",
      "! 地點",
      "# 事件",
      "? 伏筆",
      "& 計畫",
    ]);
    expect(loadedKinds, InlineAnnotationKind.values.take(5));
    final characters = session?.candidates.first;
    expect(characters?.submenuOnly, isTrue);
    expect(characters?.children.first.id, uuid);
  });

  test("half-width category symbols directly select their target kind", () {
    const expectedKinds = <String, InlineAnnotationKind>{
      "@": InlineAnnotationKind.character,
      "!": InlineAnnotationKind.location,
      "#": InlineAnnotationKind.event,
      "?": InlineAnnotationKind.foreshadowing,
      "&": InlineAnnotationKind.plan,
    };

    for (final entry in expectedKinds.entries) {
      InlineAnnotationKind? loadedKind;
      final session = engine.build(
        rawText: "正文${entry.key}",
        rawCaret: 3,
        loadTargets: (kind) {
          loadedKind = kind;
          return const [
            InlineAnnotationTargetInfo(
              id: uuid,
              primaryName: "候選",
              displayName: "候選",
              displayNameIsAlias: false,
            ),
          ];
        },
      );

      expect(loadedKind, entry.value, reason: entry.key);
      expect(session?.kind, MosaicCompletionKind.target, reason: entry.key);
      expect(
        session?.rawReplacementRange,
        const TextRange(start: 2, end: 3),
        reason: entry.key,
      );
    }
  });

  test("direct category triggers keep filtering while the query is typed", () {
    const aliceId = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";
    const bobId = "65388495-7eb2-4a2c-9258-3af82aa27791";
    final session = engine.build(
      rawText: "正文@艾",
      rawCaret: 4,
      loadTargets: (_) => const [
        InlineAnnotationTargetInfo(
          id: aliceId,
          primaryName: "艾莉絲",
          displayName: "艾莉絲",
          displayNameIsAlias: false,
        ),
        InlineAnnotationTargetInfo(
          id: bobId,
          primaryName: "鮑伯",
          displayName: "鮑伯",
          displayNameIsAlias: false,
        ),
      ],
    );

    expect(session?.kind, MosaicCompletionKind.target);
    expect(session?.rawReplacementRange, const TextRange(start: 2, end: 4));
    expect(session?.candidates, hasLength(1));
    expect(session?.candidates.single.id, aliceId);
    expect(session?.candidates.single.insertText, "//@<$aliceId|艾莉絲>//");
  });

  test("direct category queries preserve start and end states", () {
    const aliceId = "4e251fc2-1e2b-4f78-93da-91f8c76d9a92";
    const target = InlineAnnotationTargetInfo(
      id: aliceId,
      primaryName: "艾莉絲",
      displayName: "艾莉絲",
      displayNameIsAlias: false,
    );

    for (final entry in const {"+": "+", "-": "-"}.entries) {
      final rawText = "正文@${entry.key}艾";
      final session = engine.build(
        rawText: rawText,
        rawCaret: rawText.length,
        loadTargets: (_) => const [target],
      );

      expect(
        session?.rawReplacementRange,
        TextRange(start: 2, end: rawText.length),
      );
      expect(
        session?.candidates.single.insertText,
        "//@${entry.value}<$aliceId|艾莉絲>//",
      );
    }
  });

  test("state markers are only accepted immediately after the category", () {
    final session = engine.build(
      rawText: "正文@艾+",
      rawCaret: 5,
      loadTargets: (_) => const [],
    );

    expect(session, isNull);
  });

  test("direct target query closes at prose boundaries", () {
    for (final text in const ["正文@艾 ", "正文@艾。", "正文@艾/", "正文@艾^"]) {
      final session = engine.build(
        rawText: text,
        rawCaret: text.length,
        loadTargets: (_) => const [],
      );
      if (text.endsWith("/") || text.endsWith("^")) {
        expect(session?.kind, isNot(MosaicCompletionKind.target), reason: text);
      } else {
        expect(session, isNull, reason: text);
      }
    }
  });

  test("half-width caret maps directly to highlight colors", () {
    final session = engine.build(
      rawText: "正文^",
      rawCaret: 3,
      loadTargets: (_) => fail("highlight must not load object targets"),
    );

    expect(session?.kind, MosaicCompletionKind.color);
    expect(session?.candidates.map((item) => item.id), contains("highlight-B"));
    expect(
      session?.candidates
          .firstWhere((item) => item.id == "highlight-B")
          .insertText,
      "//^<",
    );
    final pinkBackground = session?.candidates.firstWhere(
      (item) => item.id == "highlight-C",
    );
    expect(pinkBackground?.insertText, "//^C<");
    expect(
      pinkBackground?.children
          .firstWhere((item) => item.id == "highlight-C-foreground-E")
          .insertText,
      "//^CE<",
    );
  });

  test("full-width category symbols do not trigger IntelliSense", () {
    for (final symbol in const ["＠", "！", "＃", "？", "＆", "＾"]) {
      final session = engine.build(
        rawText: "正文$symbol",
        rawCaret: 3,
        loadTargets: (_) => const [],
      );
      expect(session, isNull, reason: symbol);
    }
  });
}
