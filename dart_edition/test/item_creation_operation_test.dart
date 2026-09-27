import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/application/items/item_operations.dart";
import "package:monogatari_assistant/models/item_data.dart";

void main() {
  test("createDedicatedItem creates a Class and its initial instance", () {
    final result = createDedicatedItem(
      request: const DedicatedItemCreationRequest(
        classId: "class-short-sword",
        instanceId: "instance-short-sword",
        name: " 短劍 ",
      ),
    );

    expect(result.itemClass.classId, "class-short-sword");
    expect(result.itemClass.name, "短劍");
    expect(result.itemClass.mode, ItemMode.dedicated);
    expect(result.itemClass.defaultState.name, "短劍");
    expect(result.instance.instanceId, "instance-short-sword");
    expect(result.instance.classId, result.itemClass.classId);
    expect(result.instance.name, result.itemClass.name);
  });

  test("createDedicatedItem rejects incomplete or ambiguous identifiers", () {
    expect(
      () => createDedicatedItem(
        request: const DedicatedItemCreationRequest(
          classId: "",
          instanceId: "instance",
          name: "短劍",
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => createDedicatedItem(
        request: const DedicatedItemCreationRequest(
          classId: "same",
          instanceId: "same",
          name: "短劍",
        ),
      ),
      throwsArgumentError,
    );
  });
}
