import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/application/items/legacy_character_possession_conversion.dart";
import "package:monogatari_assistant/models/character_data.dart";
import "package:monogatari_assistant/models/character_snapshot_data.dart";
import "package:monogatari_assistant/models/item_data.dart";
import "package:monogatari_assistant/models/item_snapshot_data.dart";

void main() {
  const characterId = "character-lia";
  const legacy = CharacterPossessionEntry(
    name: "懷錶",
    quantity: "1",
    description: "母親遺物",
  );

  test(
    "instance conversion removes anchored text and mirrors Scene presence",
    () {
      final itemClass = ItemClassData(
        classId: "class-watch",
        name: "懷錶",
        mode: ItemMode.dedicated,
      );
      final instance = ItemInstanceData(
        instanceId: "watch-1",
        classId: itemClass.classId,
        name: "懷錶",
      );
      final result = const LegacyCharacterPossessionConverter().convert(
        characterId: characterId,
        legacy: legacy,
        characterData: const <String, CharacterEntryData>{
          characterId: CharacterEntryData(
            characterId: characterId,
            displayName: "莉亞",
            possessions: <CharacterPossessionEntry>[legacy],
          ),
        },
        baselines: <String, CharacterStateBaseline>{
          characterId: CharacterStateBaseline(
            characterId: characterId,
            patch: CharacterStatePatch(
              possessions: const <CharacterPossessionEntry>[legacy],
            ),
          ),
        },
        characterChanges: <CharacterStateChange>[
          CharacterStateChange(
            stateChangeId: "has-watch",
            characterId: characterId,
            sceneUUID: "scene-a",
            fallbackTick: 1,
            patch: CharacterStatePatch(
              possessions: const <CharacterPossessionEntry>[legacy],
            ),
          ),
          CharacterStateChange(
            stateChangeId: "lost-watch",
            characterId: characterId,
            sceneUUID: "scene-b",
            fallbackTick: 2,
            patch: CharacterStatePatch(
              possessions: const <CharacterPossessionEntry>[],
            ),
          ),
        ],
        legacyStates: const <CharacterState>[
          CharacterState(
            characterId: characterId,
            storyTimePointId: "legacy-tick",
            possessions: <String>["懷錶"],
          ),
        ],
        itemClasses: <String, ItemClassData>{itemClass.classId: itemClass},
        itemInstances: <String, ItemInstanceData>{
          instance.instanceId: instance,
        },
        itemRelations: const <ItemRelationData>[],
        itemClassStateChanges: const <ItemClassStateChange>[],
        itemInstanceStateChanges: const <ItemInstanceStateChange>[],
        itemKind: ItemReferenceKind.instance,
        itemId: instance.instanceId,
        conversionId: "conversion-watch",
      );

      expect(result.characterData[characterId]!.possessions, isEmpty);
      expect(result.baselines[characterId]!.patch.possessions, isEmpty);
      expect(
        result.characterChanges.expand((change) => change.patch.possessions!),
        isEmpty,
      );
      expect(result.convertedDefaultOccurrences, 2);
      expect(result.convertedSceneOccurrences, 1);
      expect(result.preservedUnanchoredOccurrences, 1);
      expect(
        result
            .itemInstances[instance.instanceId]!
            .defaultState
            .holderCharacterId!
            .value,
        characterId,
      );
      expect(result.itemInstanceStateChanges, hasLength(2));
      expect(
        result.itemInstanceStateChanges.first.patch.holderCharacterId!.value,
        characterId,
      );
      expect(
        result.itemInstanceStateChanges.last.patch.holderCharacterId!.value,
        isNull,
      );
      expect(result.itemRelations.single.note, contains("數量：1"));
      expect(result.itemRelations.single.note, contains("母親遺物"));
    },
  );

  test(
    "generic conversion carries numeric quantity into allocation history",
    () {
      final itemClass = ItemClassData(
        classId: "class-coins",
        name: "銀幣",
        mode: ItemMode.generic,
      );
      const coins = CharacterPossessionEntry(name: "銀幣", quantity: "12");
      final result = const LegacyCharacterPossessionConverter().convert(
        characterId: characterId,
        legacy: coins,
        characterData: const <String, CharacterEntryData>{
          characterId: CharacterEntryData(
            characterId: characterId,
            possessions: <CharacterPossessionEntry>[coins],
          ),
        },
        baselines: const <String, CharacterStateBaseline>{},
        characterChanges: <CharacterStateChange>[
          CharacterStateChange(
            stateChangeId: "coins-scene",
            characterId: characterId,
            sceneUUID: "scene-market",
            fallbackTick: 3,
            patch: CharacterStatePatch(
              possessions: const <CharacterPossessionEntry>[coins],
            ),
          ),
        ],
        legacyStates: const <CharacterState>[],
        itemClasses: <String, ItemClassData>{itemClass.classId: itemClass},
        itemInstances: const <String, ItemInstanceData>{},
        itemRelations: const <ItemRelationData>[],
        itemClassStateChanges: const <ItemClassStateChange>[],
        itemInstanceStateChanges: const <ItemInstanceStateChange>[],
        itemKind: ItemReferenceKind.itemClass,
        itemId: itemClass.classId,
        conversionId: "conversion-coins",
      );

      final allocation = result
          .itemClasses[itemClass.classId]!
          .defaultState
          .allocations
          .single;
      expect(allocation.holderCharacterId, characterId);
      expect(allocation.quantity, 12);
      expect(
        result
            .itemClassStateChanges
            .single
            .patch
            .allocations!
            .value!
            .single
            .quantity,
        12,
      );
    },
  );

  test("non-generic Class cannot receive aggregate legacy ownership", () {
    final itemClass = ItemClassData(
      classId: "class-watch",
      name: "懷錶",
      mode: ItemMode.dedicated,
    );
    expect(
      () => const LegacyCharacterPossessionConverter().convert(
        characterId: characterId,
        legacy: legacy,
        characterData: const <String, CharacterEntryData>{
          characterId: CharacterEntryData(
            characterId: characterId,
            possessions: <CharacterPossessionEntry>[legacy],
          ),
        },
        baselines: const <String, CharacterStateBaseline>{},
        characterChanges: const <CharacterStateChange>[],
        legacyStates: const <CharacterState>[],
        itemClasses: <String, ItemClassData>{itemClass.classId: itemClass},
        itemInstances: const <String, ItemInstanceData>{},
        itemRelations: const <ItemRelationData>[],
        itemClassStateChanges: const <ItemClassStateChange>[],
        itemInstanceStateChanges: const <ItemInstanceStateChange>[],
        itemKind: ItemReferenceKind.itemClass,
        itemId: itemClass.classId,
      ),
      throwsStateError,
    );
  });
}
