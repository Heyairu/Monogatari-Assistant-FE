import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

import "package:monogatari_assistant/modules/outlineview.dart";
import "package:monogatari_assistant/presentation/providers/editor_coordinator_provider.dart";

void main() {
  testWidgets("outline controller hydration does not mark project dirty", (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(editorCoordinatorProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OutlineAdjustView()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(container.read(editorCoordinatorProvider).hasUnsavedChanges, false);
  });
}
