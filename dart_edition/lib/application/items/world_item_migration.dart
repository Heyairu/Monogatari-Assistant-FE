import "package:uuid/uuid.dart";

import "../../models/item_data.dart";
import "../../models/item_snapshot_data.dart";
import "../../models/world_settings_data.dart";

class WorldItemMigrationResult {
  final List<LocationData> worldNodes;
  final Map<String, ItemClassData> itemClasses;
  final Map<String, ItemInstanceData> itemInstances;
  final List<String> warnings;
  final int migratedCount;

  const WorldItemMigrationResult({
    required this.worldNodes,
    required this.itemClasses,
    required this.itemInstances,
    required this.warnings,
    required this.migratedCount,
  });
}

WorldItemMigrationResult migrateWorldItems({
  required Iterable<LocationData> worldNodes,
  Map<String, ItemClassData> existingClasses = const {},
  Map<String, ItemInstanceData> existingInstances = const {},
  String Function()? createClassId,
}) {
  const uuid = Uuid();
  final nextClasses = Map<String, ItemClassData>.from(existingClasses);
  final nextInstances = Map<String, ItemInstanceData>.from(existingInstances);
  final warnings = <String>[];
  var migratedCount = 0;

  Map<String, String> propertiesOf(LocationData node) {
    final result = <String, String>{};
    for (final field in node.customVal) {
      final base = field.key.trim().isEmpty ? "自訂屬性" : field.key.trim();
      var key = base;
      var suffix = 2;
      while (result.containsKey(key)) {
        key = "$base ($suffix)";
        suffix += 1;
      }
      result[key] = field.val;
    }
    return result;
  }

  List<LocationData> visit(Iterable<LocationData> nodes, List<String> path) {
    final retained = <LocationData>[];
    for (final node in nodes) {
      final nodePath = [...path, node.localName].where((v) => v.isNotEmpty);
      final children = visit(node.child, nodePath.toList(growable: false));
      if (node.nodeType != WorldNodeType.item) {
        retained.add(node.copyWith(child: children));
        continue;
      }

      if (nextInstances.containsKey(node.id)) {
        warnings.add("物品 ${node.localName} 的 ID 已存在，保留既有實例。");
      } else {
        var classId = (createClassId ?? uuid.v4)();
        while (nextClasses.containsKey(classId)) {
          classId = (createClassId ?? uuid.v4)();
        }
        final properties = propertiesOf(node);
        final source = ItemConversionSourceData(
          conversionId: "world-item-migration",
          sourcePath: nodePath.join(" / "),
        );
        nextClasses[classId] = ItemClassData(
          classId: classId,
          name: node.localName,
          category: node.localType,
          description: node.note,
          mode: ItemMode.dedicated,
          defaultState: ItemSnapshotState(
            name: node.localName,
            description: node.note,
            properties: properties,
          ),
          conversionSource: source,
        );
        nextInstances[node.id] = ItemInstanceData(
          instanceId: node.id,
          classId: classId,
          name: node.localName,
          defaultState: ItemStatePatch(
            name: StateValue.set(node.localName),
            description: StateValue.set(node.note),
            properties: StateValue.set(properties),
          ),
          conversionSource: source,
        );
        migratedCount += 1;
      }

      if (children.isNotEmpty) {
        warnings.add("物品 ${node.localName} 的 ${children.length} 個非物品子節點已提升一層。");
        retained.addAll(children);
      }
    }
    return retained;
  }

  return WorldItemMigrationResult(
    worldNodes: List.unmodifiable(visit(worldNodes, const [])),
    itemClasses: Map.unmodifiable(nextClasses),
    itemInstances: Map.unmodifiable(nextInstances),
    warnings: List.unmodifiable(warnings),
    migratedCount: migratedCount,
  );
}

int countWorldItemNodes(Iterable<LocationData> nodes) {
  var count = 0;
  for (final node in nodes) {
    if (node.nodeType == WorldNodeType.item) count += 1;
    count += countWorldItemNodes(node.child);
  }
  return count;
}
