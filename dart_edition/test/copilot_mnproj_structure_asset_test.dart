import "dart:convert";

import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/features/copilot/domain/copilot_models.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("bundled mnproj reference documents every persisted module", () async {
    final content = await rootBundle.loadString(
      CopilotPromptPolicy.mnprojStructureAsset,
    );

    expect(
      utf8.encode(content).length,
      lessThanOrEqualTo(CopilotPromptPolicy.maxMnprojStructureBytes),
    );
    expect(content, contains("根節點：`Project`"));
    for (final module in <String>[
      "BaseInfo",
      "ChapterSelection",
      "Outline",
      "Timeline",
      "PlanSettings",
      "WorldSettings",
      "Characters",
      "CharacterStates",
      "CharacterStateBaselines",
      "CharacterStateChanges",
      "ItemClasses",
      "ItemInstances",
      "ItemRelations",
      "ItemClassStateChanges",
      "ItemInstanceStateChanges",
      "LocationStateChanges",
    ]) {
      expect(
        content,
        contains("| `$module` |"),
        reason: "$module is missing from the structure mapping",
      );
    }
  });
}
