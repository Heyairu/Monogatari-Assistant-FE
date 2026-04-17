import "dart:math";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:integration_test/integration_test.dart";
import "package:monogatari_assistant/bin/content.dart";
import "package:monogatari_assistant/main.dart";

void main() {
  final binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized()
          as IntegrationTestWidgetsFlutterBinding;

  testWidgets("Phase 4 profile: rapid typing and cursor movement", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MainApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final Finder editableFinder = find.descendant(
      of: find.byType(EditorTextBox),
      matching: find.byType(EditableText),
    );
    expect(editableFinder, findsOneWidget);

    await tester.tap(editableFinder);
    await tester.pumpAndSettle(const Duration(milliseconds: 250));

    const int inputSteps = 120;
    const int cursorSteps = 120;
    final Stopwatch stopwatch = Stopwatch()..start();

    await binding.watchPerformance(() async {
      String text = "";
      for (int i = 0; i < inputSteps; i++) {
        final EditableText editable = tester.widget<EditableText>(editableFinder);
        text = "$text${i % 10}";
        editable.controller.value = editable.controller.value.copyWith(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
          composing: TextRange.empty,
        );
        await tester.pump(const Duration(milliseconds: 8));
      }

      for (int i = 0; i < cursorSteps; i++) {
        final EditableText editable = tester.widget<EditableText>(editableFinder);
        final int textLength = editable.controller.text.length;
        final int nextOffset = max(textLength - i - 1, 0).clamp(0, textLength);
        editable.controller.value = editable.controller.value.copyWith(
          selection: TextSelection.collapsed(offset: nextOffset),
          composing: TextRange.empty,
        );
        await tester.pump(const Duration(milliseconds: 4));
      }

      await tester.pumpAndSettle(const Duration(milliseconds: 300));
    }, reportKey: "phase4_editor_typing_cursor");

    stopwatch.stop();

    final Map<String, dynamic>? reportData = binding.reportData;
    final dynamic perfResult = reportData?["phase4_editor_typing_cursor"];

    expect(perfResult, isNotNull);

    final int finalTextLength =
        tester.widget<EditableText>(editableFinder).controller.text.length;
    expect(finalTextLength, equals(inputSteps));

    final int totalOps = inputSteps + cursorSteps;
    final double avgLatencyMs = stopwatch.elapsedMilliseconds / max(totalOps, 1);

    debugPrint(
      "[Phase4Profile] totalMs=${stopwatch.elapsedMilliseconds}, avgMsPerOp=${avgLatencyMs.toStringAsFixed(2)}",
    );
    debugPrint("[Phase4Profile] report=$perfResult");
  });
}
