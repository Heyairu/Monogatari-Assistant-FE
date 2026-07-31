import "package:flutter_test/flutter_test.dart";

import "package:monogatari_assistant/bin/findreplace.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    "new find request cancels and invalidates the previous request",
    () async {
      final controller = HighlightTextEditingController(
        text: "${List<String>.filled(750000, "a").join()}tail",
      );
      final options = FindReplaceOptions();

      final first = findAllMatchesLatest(
        controller,
        "not-present",
        options,
        maxResults: 1000,
      );
      final second = findAllMatchesLatest(
        controller,
        "tail",
        options,
        maxResults: 1000,
      );

      expect(await first, isNull);
      final result = await second;
      expect(result, isNotNull);
      expect(result!.matches, hasLength(1));
      expect(
        result.isCurrent(controller, "tail", options, maxResults: 1000),
        isTrue,
      );

      controller.dispose();
    },
  );

  test("editor revision invalidates an in-flight find request", () async {
    final controller = HighlightTextEditingController(
      text: List<String>.filled(500000, "a").join(),
    );
    final pending = findAllMatchesLatest(
      controller,
      "not-present",
      FindReplaceOptions(),
    );

    controller.text = "changed";

    expect(await pending, isNull);
    controller.dispose();
  });

  test("unsafe nested regex is rejected before worker execution", () async {
    final controller = HighlightTextEditingController(
      text: List<String>.filled(1000, "a").join(),
    );
    final options = FindReplaceOptions(useRegexp: true);

    final result = await findAllMatchesLatest(controller, r"(a+)+$", options);

    expect(result, isNotNull);
    expect(result!.matches, isEmpty);
    expect(result.limitReason, FindSearchLimitReason.unsafeRegularExpression);
    controller.dispose();
  });
}
