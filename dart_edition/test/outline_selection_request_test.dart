import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/presentation/providers/timeline_providers.dart";

void main() {
  test("outline selection request accepts every outline hierarchy UUID", () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(outlineSelectionRequestProvider.notifier);

    notifier.requestTarget("storyline-id");
    expect(container.read(outlineSelectionRequestProvider).requestId, 1);
    expect(
      container.read(outlineSelectionRequestProvider).targetUUID,
      "storyline-id",
    );
    expect(container.read(outlineSelectionRequestProvider).sceneUUID, isNull);

    notifier.requestScene("scene-id");
    expect(container.read(outlineSelectionRequestProvider).requestId, 2);
    expect(
      container.read(outlineSelectionRequestProvider).sceneUUID,
      "scene-id",
    );
    expect(
      container.read(outlineSelectionRequestProvider).targetUUID,
      "scene-id",
    );
  });
}
