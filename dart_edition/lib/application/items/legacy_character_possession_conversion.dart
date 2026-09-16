import "package:uuid/uuid.dart";

import "../../models/character_data.dart";
import "../../models/character_snapshot_data.dart";
import "../../models/item_data.dart";
import "../../models/item_snapshot_data.dart";

class LegacyCharacterPossessionConversionResult {
  final Map<String, CharacterEntryData> characterData;
  final Map<String, CharacterStateBaseline> baselines;
  final List<CharacterStateChange> characterChanges;
  final Map<String, ItemClassData> itemClasses;
  final Map<String, ItemInstanceData> itemInstances;
  final List<ItemRelationData> itemRelations;
  final List<ItemClassStateChange> itemClassStateChanges;
  final List<ItemInstanceStateChange> itemInstanceStateChanges;
  final int convertedDefaultOccurrences;
  final int convertedSceneOccurrences;
  final int preservedUnanchoredOccurrences;

  const LegacyCharacterPossessionConversionResult({
    required this.characterData,
    required this.baselines,
    required this.characterChanges,
    required this.itemClasses,
    required this.itemInstances,
    required this.itemRelations,
    required this.itemClassStateChanges,
    required this.itemInstanceStateChanges,
    required this.convertedDefaultOccurrences,
    required this.convertedSceneOccurrences,
    required this.preservedUnanchoredOccurrences,
  });
}

class LegacyCharacterPossessionConverter {
  const LegacyCharacterPossessionConverter();

  LegacyCharacterPossessionConversionResult convert({
    required String characterId,
    required CharacterPossessionEntry legacy,
    required Map<String, CharacterEntryData> characterData,
    required Map<String, CharacterStateBaseline> baselines,
    required List<CharacterStateChange> characterChanges,
    required List<CharacterState> legacyStates,
    required Map<String, ItemClassData> itemClasses,
    required Map<String, ItemInstanceData> itemInstances,
    required List<ItemRelationData> itemRelations,
    required List<ItemClassStateChange> itemClassStateChanges,
    required List<ItemInstanceStateChange> itemInstanceStateChanges,
    required ItemReferenceKind itemKind,
    required String itemId,
    ItemClassData? newClass,
    ItemInstanceData? newInstance,
    String? conversionId,
  }) {
    final normalizedCharacterId = characterId.trim();
    final normalizedName = legacy.name.trim();
    if (normalizedCharacterId.isEmpty || normalizedName.isEmpty) {
      throw const FormatException("角色 ID 與舊持有物名稱不可為空。");
    }
    final originalCharacter = characterData[normalizedCharacterId];
    if (originalCharacter == null) {
      throw StateError("角色已不存在，請重新開啟轉換流程。");
    }
    final resolvedConversionId = conversionId ?? const Uuid().v4();
    final classes = Map<String, ItemClassData>.of(itemClasses);
    final instances = Map<String, ItemInstanceData>.of(itemInstances);
    if (newClass != null) {
      if (classes.containsKey(newClass.classId)) {
        throw StateError("新物品 Class ID 已存在，請重試。");
      }
      classes[newClass.classId] = newClass;
    }
    if (newInstance != null) {
      if (instances.containsKey(newInstance.instanceId)) {
        throw StateError("新物品 ID 已存在，請重試。");
      }
      instances[newInstance.instanceId] = newInstance;
    }
    final instance = itemKind == ItemReferenceKind.instance
        ? instances[itemId]
        : null;
    final itemClass = itemKind == ItemReferenceKind.itemClass
        ? classes[itemId]
        : instance == null
        ? null
        : classes[instance.classId];
    if (itemClass == null) {
      throw StateError("選取的正式物品已不存在，請重新選擇。");
    }
    if (itemKind == ItemReferenceKind.itemClass &&
        itemClass.mode != ItemMode.generic) {
      throw StateError("只有非專用 Class 可直接承接有數量的舊持有物。");
    }
    if (itemKind == ItemReferenceKind.itemClass &&
        newClass == null &&
        (itemClass.defaultState.allocations.isNotEmpty ||
            itemClassStateChanges.any(
              (change) => change.classId == itemClass.classId,
            ))) {
      throw StateError("既有非專用 Class 已有分配歷史，請建立新物品以免覆寫其他庫存。");
    }
    if (itemKind == ItemReferenceKind.instance && instance == null) {
      throw StateError("選取的單件物品已不存在，請重新選擇。");
    }
    if (itemKind == ItemReferenceKind.instance &&
        newInstance == null &&
        instance != null &&
        ((instance.defaultState.holderCharacterId?.value != null &&
                instance.defaultState.holderCharacterId!.value !=
                    normalizedCharacterId) ||
            itemInstanceStateChanges.any(
              (change) => change.instanceId == instance.instanceId,
            ))) {
      throw StateError("既有單件物品已有持有或 Scene 歷史，請建立新物品以免覆寫原狀態。");
    }

    bool sameName(CharacterPossessionEntry value) =>
        value.name.trim() == normalizedName;
    final baseMatches = originalCharacter.possessions.where(sameName).length;
    final nextCharacter = originalCharacter.copyWith(
      possessions: originalCharacter.possessions
          .where((item) => !sameName(item))
          .toList(growable: false),
    );
    final nextCharacters = Map<String, CharacterEntryData>.of(characterData)
      ..[normalizedCharacterId] = nextCharacter;

    var baselineMatches = 0;
    final nextBaselines = Map<String, CharacterStateBaseline>.of(baselines);
    final baseline = baselines[normalizedCharacterId];
    if (baseline?.patch.possessions != null) {
      baselineMatches = baseline!.patch.possessions!.where(sameName).length;
      nextBaselines[normalizedCharacterId] = baseline.copyWith(
        patch: _copyCharacterPatch(
          baseline.patch,
          possessions: baseline.patch.possessions!
              .where((item) => !sameName(item))
              .toList(growable: false),
        ),
      );
    }

    var sceneMatches = 0;
    final nextCharacterChanges = <CharacterStateChange>[];
    final newItemClassChanges = <ItemClassStateChange>[];
    final newItemInstanceChanges = <ItemInstanceStateChange>[];
    final allocationId = "legacy-$resolvedConversionId";
    for (final change in characterChanges) {
      if (change.characterId != normalizedCharacterId ||
          change.patch.possessions == null) {
        nextCharacterChanges.add(change);
        continue;
      }
      final contains = change.patch.possessions!.any(sameName);
      sceneMatches += change.patch.possessions!.where(sameName).length;
      nextCharacterChanges.add(
        change.copyWith(
          patch: _copyCharacterPatch(
            change.patch,
            possessions: change.patch.possessions!
                .where((item) => !sameName(item))
                .toList(growable: false),
          ),
        ),
      );
      if (itemKind == ItemReferenceKind.instance) {
        newItemInstanceChanges.add(
          ItemInstanceStateChange(
            stateChangeId: "$resolvedConversionId:${change.stateChangeId}",
            instanceId: itemId,
            sceneUUID: change.sceneUUID,
            sourcePlacementUUID: change.sourcePlacementUUID,
            fallbackTick: change.fallbackTick,
            sequence: change.sequence,
            patch: ItemStatePatch(
              holderCharacterId: StateValue<String?>.set(
                contains ? normalizedCharacterId : null,
              ),
            ),
            note: "由角色舊持有物「$normalizedName」轉換",
          ),
        );
      } else {
        newItemClassChanges.add(
          ItemClassStateChange(
            stateChangeId: "$resolvedConversionId:${change.stateChangeId}",
            classId: itemId,
            sceneUUID: change.sceneUUID,
            sourcePlacementUUID: change.sourcePlacementUUID,
            fallbackTick: change.fallbackTick,
            sequence: change.sequence,
            patch: ItemStatePatch(
              allocations: StateValue<List<ItemAllocationData>>.set(
                contains
                    ? <ItemAllocationData>[
                        ItemAllocationData(
                          allocationId: allocationId,
                          holderCharacterId: normalizedCharacterId,
                          quantity: _parseQuantity(legacy.quantity),
                          note: legacy.description,
                        ),
                      ]
                    : const <ItemAllocationData>[],
              ),
            ),
            note: "由角色舊持有物「$normalizedName」轉換",
          ),
        );
      }
    }

    final defaultPresent = baseMatches + baselineMatches > 0;
    if (defaultPresent) {
      if (itemKind == ItemReferenceKind.instance) {
        instances[itemId] = instance!.copyWith(
          defaultState: instance.defaultState.merge(
            ItemStatePatch(
              holderCharacterId: StateValue<String?>.set(normalizedCharacterId),
            ),
          ),
        );
      } else {
        classes[itemId] = itemClass.copyWith(
          defaultState: itemClass.defaultState.copyWith(
            allocations: <ItemAllocationData>[
              ...itemClass.defaultState.allocations.where(
                (item) => item.allocationId != allocationId,
              ),
              ItemAllocationData(
                allocationId: allocationId,
                holderCharacterId: normalizedCharacterId,
                quantity: _parseQuantity(legacy.quantity),
                note: legacy.description,
              ),
            ],
          ),
        );
      }
    }

    final duplicateRelation = itemRelations.any(
      (relation) =>
          relation.itemId == itemId &&
          relation.itemKind == itemKind &&
          relation.targetKind == ItemRelationTargetKind.character &&
          relation.targetId == normalizedCharacterId &&
          relation.role == "舊持有物來源",
    );
    final relations = <ItemRelationData>[
      ...itemRelations,
      if (!duplicateRelation)
        ItemRelationData(
          relationId: resolvedConversionId,
          itemId: itemId,
          itemKind: itemKind,
          targetId: normalizedCharacterId,
          targetKind: ItemRelationTargetKind.character,
          role: "舊持有物來源",
          note: [
            if (legacy.quantity.trim().isNotEmpty)
              "數量：${legacy.quantity.trim()}",
            if (legacy.description.trim().isNotEmpty)
              "說明：${legacy.description.trim()}",
          ].join("；"),
        ),
    ];
    final preserved = legacyStates
        .where((state) => state.characterId == normalizedCharacterId)
        .expand((state) => state.possessions)
        .where((name) => name.trim() == normalizedName)
        .length;
    if (baseMatches + baselineMatches + sceneMatches == 0) {
      throw StateError("原持有物資料已變更，請重新開啟轉換流程。");
    }
    return LegacyCharacterPossessionConversionResult(
      characterData: Map.unmodifiable(nextCharacters),
      baselines: Map.unmodifiable(nextBaselines),
      characterChanges: List.unmodifiable(nextCharacterChanges),
      itemClasses: Map.unmodifiable(classes),
      itemInstances: Map.unmodifiable(instances),
      itemRelations: List.unmodifiable(relations),
      itemClassStateChanges: List.unmodifiable(<ItemClassStateChange>[
        ...itemClassStateChanges,
        ...newItemClassChanges,
      ]),
      itemInstanceStateChanges: List.unmodifiable(<ItemInstanceStateChange>[
        ...itemInstanceStateChanges,
        ...newItemInstanceChanges,
      ]),
      convertedDefaultOccurrences: baseMatches + baselineMatches,
      convertedSceneOccurrences: sceneMatches,
      preservedUnanchoredOccurrences: preserved,
    );
  }
}

CharacterStatePatch _copyCharacterPatch(
  CharacterStatePatch source, {
  required List<CharacterPossessionEntry> possessions,
}) => CharacterStatePatch(
  conflicts: source.conflicts,
  relationships: source.relationships,
  organizations: source.organizations,
  statusEntries: source.statusEntries,
  possessions: possessions,
  customFields: source.customFields,
);

int? _parseQuantity(String source) {
  final value = int.tryParse(source.trim());
  return value != null && value >= 0 ? value : null;
}
