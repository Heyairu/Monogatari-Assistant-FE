import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/ui_library/alias_terms.dart";

void main() {
  testWidgets("alias chips support editing, adding and deleting", (
    tester,
  ) async {
    var values = ["小艾"];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AliasTerms(
              values: values,
              onChanged: (next) => setState(() => values = next),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text("小艾"));
    await tester.pump();
    await tester.enterText(find.byType(TextField), "艾莉");
    await tester.tap(find.byTooltip("儲存"));
    await tester.pump();
    expect(values, ["艾莉"]);
    await tester.tap(find.text("新增別名"));
    await tester.pump();
    await tester.enterText(find.byType(TextField), "小莉");
    await tester.tap(find.byTooltip("儲存"));
    await tester.pump();
    expect(values, ["艾莉", "小莉"]);
    final chip = tester.widget<InputChip>(find.widgetWithText(InputChip, "小莉"));
    chip.onDeleted!();
    await tester.pump();
    expect(values, ["艾莉"]);
  });
}
