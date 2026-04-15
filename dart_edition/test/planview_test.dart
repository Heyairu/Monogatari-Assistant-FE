import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:monogatari_assistant/bin/ui_library.dart";
import "package:monogatari_assistant/modules/planview.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("PlanView adds foreshadow and syncs provider", (tester) async {
    final container = ProviderContainer();

    await tester.pumpWidget(
      ProviderScope(
        parent: container,
        child: const MaterialApp(
          home: Scaffold(
            body: PlanView(),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    final addInputs = find.byType(AddItemInput);
    expect(addInputs, findsWidgets);

    final foreshadowInput = find.descendant(
      of: addInputs.first,
      matching: find.byType(TextField),
    );
    expect(foreshadowInput, findsOneWidget);

    await tester.enterText(foreshadowInput, "伏筆A");
    await tester.pump();

    final foreshadowAddButton = find.descendant(
      of: addInputs.first,
      matching: find.byIcon(Icons.add_circle),
    );
    await tester.tap(foreshadowAddButton);
    await tester.pump(const Duration(milliseconds: 300));

    final foreshadows = container.read(foreshadowDataProvider);
    expect(foreshadows, isNotEmpty);
    expect(foreshadows.first.title, "伏筆A");
  });
}
