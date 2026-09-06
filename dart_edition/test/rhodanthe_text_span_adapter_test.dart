import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_protocol.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_text_span_adapter.dart";
import "package:monogatari_assistant/infrastructure/rhodanthe/rhodanthe_theme.dart";

void main() {
  const adapter = RhodantheTextSpanAdapter();

  test("builds semantic spans on UTF-16 boundaries", () {
    const text = "😀test!";
    final theme = RhodantheTheme.light();
    final result = adapter.build(
      text: text,
      currentRevision: 3,
      theme: theme,
      renderPlan: _renderPlan(
        revision: 3,
        textLength: text.length,
        runs: const <RhodantheRenderRun>[
          RhodantheRenderRun(
            range: RhodantheRange(2, 6),
            styleTokenSetId: 0,
            annotationIds: <String>["search:3:0"],
          ),
        ],
        tokenSets: const <RhodantheStyleTokenSet>[
          RhodantheStyleTokenSet(
            foreground: "search.current.foreground",
            background: "search.current.background",
            weight: "semibold",
            interaction: "activateSearchMatch",
          ),
        ],
      ),
    );

    expect(result.status, RhodantheSpanBuildStatus.applied);
    expect(result.span.toPlainText(), text);
    expect(result.span.children, hasLength(3));
    final highlighted = result.span.children![1] as TextSpan;
    expect(highlighted.text, "test");
    expect(
      highlighted.style!.color,
      theme.resolveColor("search.current.foreground"),
    );
    expect(
      highlighted.style!.backgroundColor,
      theme.resolveColor("search.current.background"),
    );
    expect(highlighted.style!.fontWeight, FontWeight.w600);
    expect(highlighted.semanticsIdentifier, "activateSearchMatch");
    expect(result.metadata.single.range.start, 2);
    expect(result.metadata.single.annotationIds, <String>["search:3:0"]);
    expect(result.metadata.single.interaction, "activateSearchMatch");
  });

  test("merges composing underline with an existing decoration", () {
    final result = adapter.build(
      text: "abcdef",
      currentRevision: 1,
      renderPlan: _renderPlan(
        revision: 1,
        textLength: 6,
        runs: const <RhodantheRenderRun>[
          RhodantheRenderRun(
            range: RhodantheRange(1, 5),
            styleTokenSetId: 0,
            annotationIds: <String>["diagnostic:0"],
          ),
        ],
        tokenSets: const <RhodantheStyleTokenSet>[
          RhodantheStyleTokenSet(
            decoration: RhodantheDecoration(
              lines: <String>["overline"],
              style: "dotted",
              color: "diagnostic.decoration",
              thickness: 2,
            ),
          ),
        ],
      ),
      theme: RhodantheTheme.light(),
      composing: const TextRange(start: 2, end: 4),
    );

    expect(result.span.children, hasLength(5));
    final composing = result.span.children![2] as TextSpan;
    expect(composing.text, "cd");
    expect(
      composing.style!.decoration!.contains(TextDecoration.overline),
      isTrue,
    );
    expect(
      composing.style!.decoration!.contains(TextDecoration.underline),
      isTrue,
    );
    expect(composing.style!.decorationStyle, TextDecorationStyle.dotted);
  });

  test("maps font and decoration tokens and clamps thickness", () {
    final result = adapter.build(
      text: "word",
      currentRevision: 2,
      renderPlan: _renderPlan(
        revision: 2,
        textLength: 4,
        runs: const <RhodantheRenderRun>[
          RhodantheRenderRun(
            range: RhodantheRange(0, 4),
            styleTokenSetId: 0,
            annotationIds: <String>[],
          ),
        ],
        tokenSets: const <RhodantheStyleTokenSet>[
          RhodantheStyleTokenSet(
            weight: "bold",
            slant: "italic",
            decoration: RhodantheDecoration(
              lines: <String>["underline", "lineThrough"],
              style: "wavy",
              color: "filler.decoration",
              thickness: 9,
            ),
          ),
        ],
      ),
      theme: RhodantheTheme.dark(),
    );

    final style = (result.span.children!.single as TextSpan).style!;
    expect(style.fontWeight, FontWeight.w700);
    expect(style.fontStyle, FontStyle.italic);
    expect(style.decorationStyle, TextDecorationStyle.wavy);
    expect(style.decorationThickness, 3);
    expect(style.decoration!.contains(TextDecoration.underline), isTrue);
    expect(style.decoration!.contains(TextDecoration.lineThrough), isTrue);
  });

  test("rejects stale revisions with a plain-text fallback", () {
    final result = adapter.build(
      text: "draft",
      currentRevision: 8,
      renderPlan: _renderPlan(revision: 7, textLength: 5),
      theme: RhodantheTheme.light(),
      baseStyle: const TextStyle(fontSize: 17),
    );

    expect(result.status, RhodantheSpanBuildStatus.staleRevision);
    expect(result.applied, isFalse);
    expect(result.span.text, "draft");
    expect(result.span.style!.fontSize, 17);
    expect(result.metadata, isEmpty);
    expect(result.failure, isNotNull);
  });

  test("rejects a mismatched text length or contract", () {
    final wrongLength = adapter.build(
      text: "draft",
      currentRevision: 1,
      renderPlan: _renderPlan(revision: 1, textLength: 4),
      theme: RhodantheTheme.light(),
    );
    final wrongContract = adapter.build(
      text: "draft",
      currentRevision: 1,
      renderPlan: _renderPlan(revision: 1, textLength: 5, contractVersion: 99),
      theme: RhodantheTheme.light(),
    );

    expect(wrongLength.status, RhodantheSpanBuildStatus.textLengthMismatch);
    expect(wrongContract.status, RhodantheSpanBuildStatus.invalidContract);
  });

  test("rejects runs that split a surrogate pair", () {
    const text = "😀x";
    final result = adapter.build(
      text: text,
      currentRevision: 1,
      renderPlan: _renderPlan(
        revision: 1,
        textLength: text.length,
        runs: const <RhodantheRenderRun>[
          RhodantheRenderRun(
            range: RhodantheRange(1, 2),
            styleTokenSetId: 0,
            annotationIds: <String>[],
          ),
        ],
        tokenSets: const <RhodantheStyleTokenSet>[
          RhodantheStyleTokenSet(background: "search.match.background"),
        ],
      ),
      theme: RhodantheTheme.light(),
    );

    expect(result.status, RhodantheSpanBuildStatus.invalidPlan);
    expect(result.span.text, text);
  });

  test("rejects overlapping runs and unknown style-token references", () {
    final overlap = adapter.build(
      text: "abcdef",
      currentRevision: 1,
      renderPlan: _renderPlan(
        revision: 1,
        textLength: 6,
        runs: const <RhodantheRenderRun>[
          RhodantheRenderRun(
            range: RhodantheRange(0, 4),
            styleTokenSetId: 0,
            annotationIds: <String>[],
          ),
          RhodantheRenderRun(
            range: RhodantheRange(3, 6),
            styleTokenSetId: 0,
            annotationIds: <String>[],
          ),
        ],
        tokenSets: const <RhodantheStyleTokenSet>[
          RhodantheStyleTokenSet(background: "search.match.background"),
        ],
      ),
      theme: RhodantheTheme.light(),
    );
    final unknownReference = adapter.build(
      text: "abcdef",
      currentRevision: 1,
      renderPlan: _renderPlan(
        revision: 1,
        textLength: 6,
        runs: const <RhodantheRenderRun>[
          RhodantheRenderRun(
            range: RhodantheRange(0, 6),
            styleTokenSetId: 1,
            annotationIds: <String>[],
          ),
        ],
        tokenSets: const <RhodantheStyleTokenSet>[
          RhodantheStyleTokenSet(background: "search.match.background"),
        ],
      ),
      theme: RhodantheTheme.light(),
    );

    expect(overlap.status, RhodantheSpanBuildStatus.invalidPlan);
    expect(unknownReference.status, RhodantheSpanBuildStatus.invalidPlan);
  });

  test("rejects unknown semantic colors", () {
    final result = adapter.build(
      text: "word",
      currentRevision: 1,
      renderPlan: _renderPlan(
        revision: 1,
        textLength: 4,
        runs: const <RhodantheRenderRun>[
          RhodantheRenderRun(
            range: RhodantheRange(0, 4),
            styleTokenSetId: 0,
            annotationIds: <String>[],
          ),
        ],
        tokenSets: const <RhodantheStyleTokenSet>[
          RhodantheStyleTokenSet(foreground: "future.unsupported.color"),
        ],
      ),
      theme: RhodantheTheme.light(),
    );

    expect(result.status, RhodantheSpanBuildStatus.invalidThemeToken);
  });

  test("ignores invalid composing ranges instead of splitting text", () {
    final result = adapter.build(
      text: "😀x",
      currentRevision: 1,
      renderPlan: _renderPlan(revision: 1, textLength: 3),
      theme: RhodantheTheme.light(),
      composing: const TextRange(start: 1, end: 2),
    );

    expect(result.status, RhodantheSpanBuildStatus.applied);
    expect(result.span.children, hasLength(1));
    expect((result.span.children!.single as TextSpan).text, "😀x");
  });

  testWidgets("resolves configured and automatic high-contrast themes", (
    tester,
  ) async {
    final custom = RhodantheTheme(
      colors: const <String, Color>{"custom": Color(0xFF123456)},
    );
    late RhodantheTheme configured;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: <ThemeExtension<dynamic>>[custom]),
        home: Builder(
          builder: (context) {
            configured = RhodantheTheme.resolve(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(configured.resolveColor("custom"), const Color(0xFF123456));

    late RhodantheTheme automatic;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(highContrast: true),
        child: MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: Builder(
            builder: (context) {
              automatic = RhodantheTheme.resolve(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(
      automatic.resolveColor("search.current.background"),
      const Color(0xFF000000),
    );
  });
}

RhodantheVersionedRenderPlan _renderPlan({
  required int revision,
  required int textLength,
  int contractVersion = rhodantheContractVersion,
  List<RhodantheRenderRun> runs = const <RhodantheRenderRun>[],
  List<RhodantheStyleTokenSet> tokenSets = const <RhodantheStyleTokenSet>[],
}) {
  return RhodantheVersionedRenderPlan(
    documentId: "document",
    revision: revision,
    plan: RhodantheRenderPlan(
      contractVersion: contractVersion,
      textLenUtf16: textLength,
      runs: runs,
      tokenSets: tokenSets,
    ),
  );
}
