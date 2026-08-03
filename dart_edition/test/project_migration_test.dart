import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/bin/file.dart";
import "package:monogatari_assistant/modules/characterview.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("1.06 migrates duplicate characters without losing unresolved text", () {
    const legacyXml = """
<?xml version="1.0" encoding="UTF-8"?>
<Project>
  <ver>1.06</ver>
  <Type>
    <Name>Characters</Name>
    <Character Name="Alice &amp; Co">
      <BasicInfo><name>Alice &amp; Co</name><nickname>A &lt;One&gt;</nickname></BasicInfo>
      <Personality><personality>Calm &amp; kind</personality><alignment></alignment></Personality>
      <Social>
        <impression>Dependable</impression>
        <family>Mother &amp; daughter</family>
        <relationship>戀愛中/準備戀愛</relationship>
      </Social>
      <Other>
        <likeItemList><item>Bob</item></likeItemList>
        <admireItemList><item>Carol</item></admireItemList>
        <hateItemList><item>Dave</item></hateItemList>
        <fearItemList><item>Eve</item></fearItemList>
        <otherText>Keep &lt;all&gt; &amp; notes</otherText>
      </Other>
    </Character>
    <Character Name="Alice &amp; Co">
      <BasicInfo><name>Alice &amp; Co</name><occupation>Double</occupation></BasicInfo>
    </Character>
    <Character Name="Bob">
      <BasicInfo><name>Bob</name><age></age></BasicInfo>
    </Character>
  </Type>
  <Type>
    <Name>Outline</Name>
    <Storyline Name="Line" Type="Main" UUID="old-line-id">
      <People><Person>Alice &amp; Co</Person><Person>Bob</Person><Person>Ghost</Person></People>
      <Event Name="Event" UUID="old-event-id">
        <Scene Name="Scene" UUID="old-scene-id">
          <Time>2026-08-01T12:30:00+08:00</Time>
          <People><Person>Bob</Person></People>
        </Scene>
      </Event>
    </Storyline>
  </Type>
</Project>
""";

    final result = FileService.parseProjectXMLWithMetadata(legacyXml);

    expect(result.projectVersion, "1.06");
    expect(result.wasMigrated, isTrue);
    expect(result.data.characterData, hasLength(3));
    expect(result.data.characterStates, isEmpty);
    expect(result.data.characterData.keys.every(_isUuidV4), isTrue);

    final alices = result.data.characterData.values
        .where((character) => character.displayName == "Alice & Co")
        .toList();
    expect(alices, hasLength(2));
    expect(
      alices.any((character) => character.notes == "Keep <all> & notes"),
      isTrue,
    );
    expect(
      alices.any(
        (character) =>
            character.aliases.any((alias) => alias.values.contains("A <One>")),
      ),
      isTrue,
    );
    final aliceWithRelationships = alices.singleWhere(
      (character) => character.relationships.isNotEmpty,
    );
    expect(
      aliceWithRelationships.relationships,
      equals([
        const CharacterRelationship(person: "Bob", relationship: "喜歡"),
        const CharacterRelationship(person: "Carol", relationship: "憧憬"),
        const CharacterRelationship(person: "Dave", relationship: "討厭"),
        const CharacterRelationship(person: "Eve", relationship: "害怕"),
      ]),
    );
    expect(aliceWithRelationships.textFields["impression"], "Dependable");
    expect(aliceWithRelationships.textFields["family"], "Mother & daughter");
    expect(aliceWithRelationships.relationshipSummary, "Mother & daughter");
    expect(aliceWithRelationships.relationship, "戀愛中/準備戀愛");
    expect(aliceWithRelationships.likeItemList, isEmpty);
    expect(aliceWithRelationships.admireItemList, isEmpty);
    expect(aliceWithRelationships.hateItemList, isEmpty);
    expect(aliceWithRelationships.fearItemList, isEmpty);

    final bob = result.data.characterData.entries.singleWhere(
      (entry) => entry.value.displayName == "Bob",
    );
    final storyline = result.data.outlineData.single;
    expect(storyline.chapterUUID, "old-line-id");
    expect(storyline.people, ["Alice & Co", bob.key, "Ghost"]);
    expect(storyline.scenes.single.storyEventUUID, "old-event-id");
    expect(storyline.scenes.single.scenes.single.sceneUUID, "old-scene-id");
    expect(storyline.scenes.single.scenes.single.people, [bob.key]);
    expect(storyline.scenes.single.scenes.single.timePointIso8601, isNotEmpty);
    expect(
      result.migrationWarnings.map((warning) => warning.code),
      containsAll([
        "ambiguous-character-reference",
        "character-reference-not-found",
      ]),
    );

    final savedXml = FileService.generateProjectXML(result.data);
    expect(savedXml, contains("<ver>1.08</ver>"));
    expect(savedXml, contains("Name=\"Alice &amp; Co\""));
    expect(savedXml, isNot(contains("DisplayName=")));
    expect(savedXml, contains("Id=\"${bob.key}\""));

    final reopened = FileService.parseProjectXMLWithMetadata(savedXml);
    expect(reopened.wasMigrated, isFalse);
    expect(reopened.data.characterData.keys, result.data.characterData.keys);
    expect(
      reopened.data.outlineData.single.people,
      result.data.outlineData.single.people,
    );
    expect(
      reopened.data.characterData.values.any(
        (character) => character.notes == "Keep <all> & notes",
      ),
      isTrue,
    );
    expect(
      reopened
          .data
          .characterData[aliceWithRelationships.characterId]!
          .relationships,
      aliceWithRelationships.relationships,
    );
    expect(
      reopened
          .data
          .characterData[aliceWithRelationships.characterId]!
          .likeItemList,
      isEmpty,
    );
    expect(
      reopened
          .data
          .characterData[aliceWithRelationships.characterId]!
          .textFields["impression"],
      "Dependable",
    );
    expect(
      reopened
          .data
          .characterData[aliceWithRelationships.characterId]!
          .relationship,
      "戀愛中/準備戀愛",
    );
    expect(
      reopened
          .data
          .characterData[aliceWithRelationships.characterId]!
          .relationshipSummary,
      "Mother & daughter",
    );
  });

  test("1.08 keeps item-only lists even when a Profile block is absent", () {
    const xml = """
<?xml version="1.0" encoding="UTF-8"?>
<Project>
  <ver>1.08</ver>
  <Type>
    <Name>Characters</Name>
    <Character Id="123e4567-e89b-42d3-a456-426614174000" Name="Alice">
      <BasicInfo><name>Alice</name></BasicInfo>
      <Other><likeItemList><item>Tea</item></likeItemList></Other>
    </Character>
  </Type>
</Project>
""";

    final result = FileService.parseProjectXMLWithMetadata(xml);
    final character = result.data.characterData.values.single;
    expect(result.wasMigrated, isFalse);
    expect(character.likeItemList, ["Tea"]);
    expect(character.relationships, isEmpty);
  });

  test("1.08 restores transitional summary rows to text fields", () {
    const xml = """
<?xml version="1.0" encoding="UTF-8"?>
<Project>
  <ver>1.08</ver>
  <Type>
    <Name>Characters</Name>
    <Character Id="123e4567-e89b-42d3-a456-426614174000" Name="Alice">
      <BasicInfo><name>Alice</name></BasicInfo>
      <Social>
        <impression>Dependable</impression>
        <family>Old friend</family>
        <relationship>單身</relationship>
      </Social>
      <Profile>
        <relationshipSummary></relationshipSummary>
        <Relationships>
          <Relationship><Person>家庭／重要背景</Person><Description>Old friend</Description></Relationship>
          <Relationship><Person>他人印象</Person><Description>Dependable</Description></Relationship>
          <Relationship><Person>感情狀態</Person><Description>單身</Description></Relationship>
          <Relationship><Person>Bob</Person><Description>喜歡</Description></Relationship>
        </Relationships>
      </Profile>
    </Character>
  </Type>
</Project>
""";

    final character = FileService.parseProjectXMLWithMetadata(
      xml,
    ).data.characterData.values.single;
    expect(character.relationshipSummary, "Old friend");
    expect(character.textFields["impression"], "Dependable");
    expect(character.relationship, "單身");
    expect(character.relationships, [
      const CharacterRelationship(person: "Bob", relationship: "喜歡"),
    ]);
  });

  test("new character and outline IDs are collision resistant and stable", () {
    final characters = List.generate(
      1000,
      (index) => CharacterEntryData.withName("Character $index"),
    );
    final ids = characters.map((character) => character.characterId).toSet();
    expect(ids, hasLength(characters.length));
    expect(ids.every(_isUuidV4), isTrue);

    final original = characters.first;
    final renamed = original.withDisplayName("Renamed");
    expect(renamed.characterId, original.characterId);
  });

  test("project version gates legacy person-item migration", () {
    const transitionalLegacyXml = """
<Project>
  <ver>1.06</ver>
  <Type>
    <Name>Characters</Name>
    <Character Name="Alice">
      <BasicInfo><name>Alice</name></BasicInfo>
      <Other><likeItemList><item>Bob</item></likeItemList></Other>
      <Profile><notes>Legacy profile marker</notes></Profile>
    </Character>
  </Type>
</Project>
""";
    final migrated = FileService.parseProjectXMLWithMetadata(
      transitionalLegacyXml,
    );
    final legacyCharacter = migrated.data.characterData.values.single;
    expect(migrated.wasMigrated, isTrue);
    expect(legacyCharacter.likeItemList, isEmpty);
    expect(legacyCharacter.relationships, const [
      CharacterRelationship(person: "Bob", relationship: "喜歡"),
    ]);

    const currentWithoutProfileXml = """
<Project>
  <ver>1.08</ver>
  <Type>
    <Name>Characters</Name>
    <Character Id="123e4567-e89b-42d3-a456-426614174000" Name="Alice">
      <BasicInfo><name>Alice</name></BasicInfo>
      <Other><likeItemList><item>Tea</item></likeItemList></Other>
    </Character>
  </Type>
</Project>
""";
    final current = FileService.parseProjectXMLWithMetadata(
      currentWithoutProfileXml,
    );
    final currentCharacter = current.data.characterData.values.single;
    expect(current.wasMigrated, isFalse);
    expect(currentCharacter.characterType, defaultCharacterType);
    expect(currentCharacter.likeItemList, ["Tea"]);
    expect(currentCharacter.relationships, isEmpty);
  });

  test("1.08 uses slider IDs and round-trips character states", () {
    const characterId = "123e4567-e89b-42d3-a456-426614174000";
    const characterXml =
        """
<Type>
  <Name>Characters</Name>
  <Character Id="$characterId" DisplayName="Alice" Name="Alice">
    <BasicInfo><name>Alice</name></BasicInfo>
    <Ability>
      <commonAbilitySliders>
        <slider Id="cleaning" Title="cleaning">20.0</slider>
        <slider Id="cooking" Title="cooking">10.0</slider>
      </commonAbilitySliders>
    </Ability>
  </Character>
</Type>
""";

    final loaded = CharacterCodec.loadXML(characterXml)!;
    expect(loaded.values.single.characterId, characterId);
    expect(loaded.values.single.commonAbilityValues.take(2), [10.0, 20.0]);

    final legacyPossessionData = CharacterEntryData.fromLegacyMap({
      "name": "Legacy",
      "possessions": [
        {"name": "Old key", "description": "Legacy description"},
      ],
    });
    expect(legacyPossessionData.possessions, const [
      CharacterPossessionEntry(
        name: "Old key",
        quantity: "",
        description: "Legacy description",
      ),
    ]);

    final customized = loaded.values.single.copyWith(
      aliases: const [
        CharacterAlias(type: "nickname", values: ["A", "Ally"]),
      ],
      relationships: const [
        CharacterRelationship(person: "Bob", relationship: "Friend"),
        CharacterRelationship(person: "Carol", relationship: "Rival"),
      ],
      characterType: "主角",
      organizations: const [
        CharacterProfileTableEntry(name: "調查局", description: "探員"),
      ],
      possessions: const [
        CharacterPossessionEntry(
          name: "懷錶",
          quantity: "1 個",
          description: "父親遺物",
        ),
      ],
      statusEntries: const [
        CharacterProfileTableEntry(name: "受傷", description: "左臂包紮中"),
      ],
      likeItemList: const ["Tea"],
      admireItemList: const ["Antique clocks"],
      customFields: const {
        "luck": CustomFieldValue(
          type: CustomFieldType.number,
          rawValue: "88.5",
        ),
        "tags": CustomFieldValue(
          type: CustomFieldType.list,
          rawValue: "hero\nfriend",
        ),
      },
    );
    final project = ProjectData.empty()
      ..characterData = {characterId: customized}
      ..characterStates = const [
        CharacterState(
          characterId: characterId,
          storyTimePointId: "scene-time-1",
          location: "Home & Office",
          possessions: ["Key <1>"],
        ),
      ];
    final saved = FileService.generateProjectXML(project);
    final reopened = FileService.parseProjectXMLWithMetadata(saved).data;
    expect(reopened.characterStates, hasLength(1));
    expect(reopened.characterStates.single.characterId, characterId);
    expect(reopened.characterStates.single.location, "Home & Office");
    expect(reopened.characterStates.single.possessions, ["Key <1>"]);
    expect(
      reopened.characterData[characterId]!.customFields["luck"]!.type,
      CustomFieldType.number,
    );
    expect(
      reopened.characterData[characterId]!.customFields["tags"]!.displayValue,
      "hero、friend",
    );
    expect(reopened.characterData[characterId]!.aliases.single.values, [
      "A",
      "Ally",
    ]);
    expect(
      reopened.characterData[characterId]!.relationships,
      customized.relationships,
    );
    expect(reopened.characterData[characterId]!.characterType, "主角");
    expect(
      reopened.characterData[characterId]!.organizations,
      customized.organizations,
    );
    expect(
      reopened.characterData[characterId]!.possessions,
      customized.possessions,
    );
    expect(
      reopened.characterData[characterId]!.statusEntries,
      customized.statusEntries,
    );
    expect(reopened.characterData[characterId]!.likeItemList, ["Tea"]);
    expect(reopened.characterData[characterId]!.admireItemList, [
      "Antique clocks",
    ]);
  });
}

bool _isUuidV4(String value) {
  return RegExp(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
  ).hasMatch(value);
}
