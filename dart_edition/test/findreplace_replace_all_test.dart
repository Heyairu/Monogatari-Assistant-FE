import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

import "package:monogatari_assistant/bin/findreplace.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("replaceAllTextAsync", () {
    test(
      "streams plain-text matches without returning match objects",
      () async {
        final ReplaceAllResult result = await replaceAllTextAsync(
          "Foo, foo FOO",
          "foo",
          "x",
          FindReplaceOptions(matchCase: false),
        );

        expect(result.succeeded, isTrue);
        expect(result.replacementCount, 3);
        expect(result.newText, "x, x x");
      },
    );

    test("preserves regular-expression capture replacements", () async {
      final ReplaceAllResult result = await replaceAllTextAsync(
        "a1 b22",
        r"([a-z])(\d+)",
        r"$2-\1",
        FindReplaceOptions(useRegexp: true),
      );

      expect(result.succeeded, isTrue);
      expect(result.replacementCount, 2);
      expect(result.newText, "1-a 22-b");
    });

    test("ignores zero-width regular-expression matches", () async {
      final ReplaceAllResult result = await replaceAllTextAsync(
        "abc",
        r"^|$",
        "x",
        FindReplaceOptions(useRegexp: true),
      );

      expect(result.succeeded, isTrue);
      expect(result.hasReplacements, isFalse);
      expect(result.newText, isNull);
    });

    test("ignores zero-width branches beside real regex matches", () async {
      final ReplaceAllResult result = await replaceAllTextAsync(
        "a",
        r"a|$",
        "x",
        FindReplaceOptions(useRegexp: true),
      );

      expect(result.succeeded, isTrue);
      expect(result.replacementCount, 1);
      expect(result.newText, "x");
    });

    test("enforces match count without returning partial output", () async {
      final ReplaceAllResult result = await replaceAllTextAsync(
        "aaaa",
        "a",
        "b",
        FindReplaceOptions(),
        maxMatches: 3,
      );

      expect(result.failureReason, ReplaceAllFailureReason.matchLimitExceeded);
      expect(result.replacementCount, 3);
      expect(result.newText, isNull);
    });

    test("allows exact match and output limits", () async {
      final ReplaceAllResult result = await replaceAllTextAsync(
        "aaa",
        "a",
        "bb",
        FindReplaceOptions(),
        maxMatches: 3,
        maxOutputCodeUnits: 6,
      );

      expect(result.succeeded, isTrue);
      expect(result.replacementCount, 3);
      expect(result.newText, "bbbbbb");
    });

    test("enforces the output code-unit budget", () async {
      final ReplaceAllResult result = await replaceAllTextAsync(
        "aa",
        "a",
        "1234",
        FindReplaceOptions(),
        maxOutputCodeUnits: 7,
      );

      expect(result.failureReason, ReplaceAllFailureReason.outputLimitExceeded);
      expect(result.newText, isNull);
    });

    test("enforces the worker time budget", () async {
      final ReplaceAllResult result = await replaceAllTextAsync(
        "abc",
        "a",
        "x",
        FindReplaceOptions(),
        maxDuration: Duration.zero,
      );

      expect(result.failureReason, ReplaceAllFailureReason.timeLimitExceeded);
    });

    test("snapshots mutable options before starting the worker", () async {
      final FindReplaceOptions options = FindReplaceOptions(matchCase: false);
      final Future<ReplaceAllResult> future = replaceAllTextAsync(
        "A",
        "a",
        "x",
        options,
      );
      options.matchCase = true;

      final ReplaceAllResult result = await future;
      expect(result.succeeded, isTrue);
      expect(result.newText, "x");
    });

    test("ignored-only patterns are a no-op", () async {
      final ReplaceAllResult punctuation = await replaceAllTextAsync(
        "a---b",
        "---",
        "x",
        FindReplaceOptions(ignorePunctuation: true),
      );
      final ReplaceAllResult whitespace = await replaceAllTextAsync(
        "a   b",
        "   ",
        "x",
        FindReplaceOptions(ignoreWhitespace: true),
      );

      expect(punctuation.hasReplacements, isFalse);
      expect(whitespace.hasReplacements, isFalse);
    });

    test("skips long ignored prefixes without quadratic rescans", () async {
      final String input = "${" " * 100000}b";
      final Stopwatch stopwatch = Stopwatch()..start();
      final ReplaceAllResult result = await replaceAllTextAsync(
        input,
        "a",
        "x",
        FindReplaceOptions(ignoreWhitespace: true),
        maxDuration: const Duration(seconds: 5),
      );
      stopwatch.stop();

      expect(result.succeeded, isTrue);
      expect(result.hasReplacements, isFalse);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
    });

    test("aggregates many tiny writes into bounded chunks", () async {
      final String input = "a" * 70000;
      final ReplaceAllResult result = await replaceAllTextAsync(
        input,
        "A",
        "bb",
        FindReplaceOptions(matchCase: false),
      );

      expect(result.succeeded, isTrue);
      expect(result.replacementCount, input.length);
      expect(result.newText, "bb" * input.length);
    });

    test(
      "handles a 10 MiB repeated-character document without match lists",
      () async {
        final String input = "a" * (10 * 1024 * 1024);
        final ReplaceAllResult result = await replaceAllTextAsync(
          input,
          "a",
          "bb",
          FindReplaceOptions(),
        );

        expect(result.succeeded, isTrue);
        expect(result.replacementCount, input.length);
        expect(result.newText?.length, input.length * 2);
        expect(result.newText?.startsWith("bbbb"), isTrue);
        expect(result.newText?.endsWith("bbbb"), isTrue);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });

  testWidgets("performReplaceAll discards a stale editor result", (
    WidgetTester tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext buildContext) {
            context = buildContext;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final HighlightTextEditingController controller =
        HighlightTextEditingController(text: "a" * 100000);
    bool textCallbackCalled = false;
    bool stateCallbackCalled = false;

    final Future<void> replaceFuture = performReplaceAll(
      context,
      controller,
      "a",
      "b",
      FindReplaceOptions(),
      (List<TextSelection> _, int _) {
        stateCallbackCalled = true;
      },
      (String _) {
        textCallbackCalled = true;
      },
    );

    controller.text = "new editor content";
    await replaceFuture;

    expect(controller.text, "new editor content");
    expect(textCallbackCalled, isFalse);
    expect(stateCallbackCalled, isFalse);
    controller.dispose();
  });

  testWidgets("performReplaceAll can be cancelled atomically", (
    WidgetTester tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext buildContext) {
              context = buildContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    final HighlightTextEditingController controller =
        HighlightTextEditingController(text: "a" * 1000000);
    controller.selection = const TextSelection.collapsed(offset: 17);
    bool textCallbackCalled = false;
    bool stateCallbackCalled = false;

    final Future<void> replaceFuture = performReplaceAll(
      context,
      controller,
      "a",
      "bb",
      FindReplaceOptions(),
      (List<TextSelection> _, int _) {
        stateCallbackCalled = true;
      },
      (String _) {
        textCallbackCalled = true;
      },
    );
    cancelReplaceAll(controller);
    await replaceFuture;

    expect(controller.text, "a" * 1000000);
    expect(controller.selection, const TextSelection.collapsed(offset: 17));
    expect(textCallbackCalled, isFalse);
    expect(stateCallbackCalled, isFalse);
    controller.dispose();
  });

  testWidgets("limit failure leaves editor state untouched", (
    WidgetTester tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext buildContext) {
              context = buildContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    final HighlightTextEditingController controller =
        HighlightTextEditingController(text: "aaaa");
    controller.selection = const TextSelection.collapsed(offset: 2);
    controller.updateSearchHighlights(
      matches: const [TextSelection(baseOffset: 0, extentOffset: 1)],
      currentIndex: 0,
    );
    bool textCallbackCalled = false;
    bool stateCallbackCalled = false;

    await performReplaceAll(
      context,
      controller,
      "a",
      "b",
      FindReplaceOptions(),
      (List<TextSelection> _, int _) {
        stateCallbackCalled = true;
      },
      (String _) {
        textCallbackCalled = true;
      },
      maxMatches: 3,
    );

    expect(controller.text, "aaaa");
    expect(controller.selection, const TextSelection.collapsed(offset: 2));
    expect(controller.searchMatches, hasLength(1));
    expect(textCallbackCalled, isFalse);
    expect(stateCallbackCalled, isFalse);
    controller.dispose();
  });
}
