import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/application/items/world_item_migration.dart";
import "package:monogatari_assistant/models/item_data.dart";
import "package:monogatari_assistant/models/world_settings_data.dart";

void main() {
  test(
    "world items become dedicated instances and retain non-item children",
    () {
      var id = 0;
      final result = migrateWorldItems(
        worldNodes: [
          LocationData(
            id: "city",
            localName: "城鎮",
            child: [
              LocationData(
                id: "watch",
                localName: "懷錶",
                localType: "紀念物",
                nodeType: WorldNodeType.item,
                note: "祖父留下",
                customVal: [
                  LocationCustomize(id: "a", key: "材質", val: "銀"),
                  LocationCustomize(id: "b", key: "材質", val: "玻璃"),
                ],
                child: [
                  LocationData(id: "room", localName: "密室"),
                  LocationData(
                    id: "key",
                    localName: "發條鑰匙",
                    nodeType: WorldNodeType.item,
                  ),
                ],
              ),
            ],
          ),
        ],
        createClassId: () => "class-${id++}",
      );

      expect(result.migratedCount, 2);
      expect(result.itemInstances.keys, containsAll(["watch", "key"]));
      expect(
        result.itemClasses.values.every((v) => v.mode == ItemMode.dedicated),
        isTrue,
      );
      final watchClass = result.itemClasses["class-1"]!;
      expect(watchClass.category, "紀念物");
      expect(watchClass.description, "祖父留下");
      expect(watchClass.defaultState.properties, {"材質": "銀", "材質 (2)": "玻璃"});
      expect(watchClass.conversionSource?.sourcePath, "城鎮 / 懷錶");
      expect(
        result.itemInstances["watch"]!.defaultState.locationId?.value,
        "city",
      );
      expect(
        result.itemInstances["key"]!.defaultState.locationId?.value,
        "city",
      );
      expect(result.worldNodes.single.child.single.id, "room");
      expect(result.warnings, hasLength(1));
    },
  );

  test("migration keeps existing instance and can be run again safely", () {
    final first = migrateWorldItems(
      worldNodes: [
        LocationData(
          id: "watch",
          localName: "懷錶",
          nodeType: WorldNodeType.item,
        ),
      ],
      createClassId: () => "class",
    );
    final second = migrateWorldItems(
      worldNodes: first.worldNodes,
      existingClasses: first.itemClasses,
      existingInstances: first.itemInstances,
      createClassId: () => "unused",
    );

    expect(second.migratedCount, 0);
    expect(second.itemClasses, first.itemClasses);
    expect(second.itemInstances, first.itemInstances);
    expect(second.worldNodes, isEmpty);
  });
}
