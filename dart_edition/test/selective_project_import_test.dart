import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/application/project_import/selective_project_import.dart";
import "package:monogatari_assistant/models/item_data.dart";
import "package:monogatari_assistant/models/project_data.dart";

void main() {
  test("manifest detects declared and legacy module sections", () {
    final manifest = SelectiveProjectImportManifest.fromXml("""
<Project UUID="11111111-1111-4111-8111-111111111111">
  <ver>1.18</ver>
  <SelectiveExport><Module>Items</Module><Module>Characters</Module></SelectiveExport>
  <Type><Name>ItemClasses</Name></Type>
  <Type><Name>LocationStateChanges</Name></Type>
</Project>
""");

    expect(
      manifest.declaredModules,
      containsAll(<SelectiveProjectModule>{
        SelectiveProjectModule.items,
        SelectiveProjectModule.characters,
      }),
    );
    expect(
      manifest.availableModules,
      containsAll(<SelectiveProjectModule>{
        SelectiveProjectModule.items,
        SelectiveProjectModule.characters,
        SelectiveProjectModule.worldSettings,
      }),
    );
  });

  test("declared item import replaces the complete module atomically", () {
    const currentUuid = "11111111-1111-4111-8111-111111111111";
    final current = ProjectData.empty(projectUUID: currentUuid)
      ..itemClasses = <String, ItemClassData>{
        "old-class": ItemClassData(classId: "old-class", name: "舊物品"),
      }
      ..itemInstances = <String, ItemInstanceData>{
        "old-instance": ItemInstanceData(
          instanceId: "old-instance",
          classId: "old-class",
        ),
      };
    final originalLocations = current.worldSettingsData;
    final source =
        ProjectData.empty(projectUUID: "22222222-2222-4222-8222-222222222222")
          ..itemClasses = <String, ItemClassData>{
            "new-class": ItemClassData(
              classId: "new-class",
              name: "新物品",
              mode: ItemMode.generic,
            ),
          }
          ..itemInstances = const <String, ItemInstanceData>{}
          ..itemRelations = <ItemRelationData>[
            ItemRelationData(
              relationId: "dangling-relation",
              itemId: "new-class",
              itemKind: ItemReferenceKind.itemClass,
              targetId: "missing-character",
              targetKind: ItemRelationTargetKind.character,
            ),
          ];
    final manifest = SelectiveProjectImportManifest.fromXml("""
<Project UUID="${source.projectUUID}">
  <ver>1.18</ver>
  <SelectiveExport><Module>Items</Module></SelectiveExport>
  <Type><Name>ItemClasses</Name></Type>
  <Type><Name>ItemRelations</Name></Type>
</Project>
""");

    final result = const SelectiveProjectImporter().apply(
      current: current,
      source: source,
      manifest: manifest,
      selectedModules: const <SelectiveProjectModule>{
        SelectiveProjectModule.items,
      },
    );

    expect(result.data.projectUUID, currentUuid);
    expect(result.data.itemClasses.keys, <String>["new-class"]);
    expect(result.data.itemInstances, isEmpty);
    expect(result.data.worldSettingsData, originalLocations);
    expect(result.data.isDirty, isTrue);
    expect(result.warnings, hasLength(1));
    expect(result.warnings.single.code, "missing-target:dangling-relation");
    expect(result.warnings.single.message, contains("已保留 ID"));
  });

  test("legacy partial item XML replaces only sections actually present", () {
    final current = ProjectData.empty()
      ..itemInstances = <String, ItemInstanceData>{
        "kept-instance": ItemInstanceData(
          instanceId: "kept-instance",
          classId: "new-class",
        ),
      };
    final source = ProjectData.empty()
      ..itemClasses = <String, ItemClassData>{
        "new-class": ItemClassData(classId: "new-class", name: "新 Class"),
      };
    final manifest = SelectiveProjectImportManifest.fromXml("""
<Project UUID="${source.projectUUID}">
  <ver>1.18</ver>
  <Type><Name>ItemClasses</Name></Type>
</Project>
""");

    final result = const SelectiveProjectImporter().apply(
      current: current,
      source: source,
      manifest: manifest,
      selectedModules: const <SelectiveProjectModule>{
        SelectiveProjectModule.items,
      },
    );

    expect(result.data.itemClasses.keys, <String>["new-class"]);
    expect(result.data.itemInstances.keys, <String>["kept-instance"]);
    expect(result.warnings, isEmpty);
  });

  test("unavailable or empty selection is rejected before mutation", () {
    final project = ProjectData.empty();
    final manifest = SelectiveProjectImportManifest.fromXml("""
<Project UUID="${project.projectUUID}"><ver>1.18</ver><Type><Name>ItemClasses</Name></Type></Project>
""");
    const importer = SelectiveProjectImporter();

    expect(
      () => importer.apply(
        current: project,
        source: project,
        manifest: manifest,
        selectedModules: const <SelectiveProjectModule>{},
      ),
      throwsFormatException,
    );
    expect(
      () => importer.apply(
        current: project,
        source: project,
        manifest: manifest,
        selectedModules: const <SelectiveProjectModule>{
          SelectiveProjectModule.characters,
        },
      ),
      throwsFormatException,
    );
  });
}
