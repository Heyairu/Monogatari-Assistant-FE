import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:xml/xml.dart" as xml;
import "package:monogatari_assistant/models/character_snapshot_data.dart";
import "package:monogatari_assistant/models/codecs/character_snapshot_codec.dart";
import "package:monogatari_assistant/modules/characterview.dart";
import "package:monogatari_assistant/modules/character_relationship_graph_mapper.dart";
import "package:monogatari_assistant/modules/character_relationship_graph_view.dart";
import "package:monogatari_assistant/modules/character_relationship_operations.dart";
import "package:monogatari_assistant/presentation/providers/project_state_providers.dart";
import "package:monogatari_assistant/bin/ui_library.dart";

const relationship = CharacterRelationship(
  person: "Bob",
  relationship: "同事",
  internalRelationship: "嫉妒",
);

Map<String, CharacterEntryData> characters() => const {
  "alice": CharacterEntryData(
    characterId: "alice",
    displayName: "Alice",
    legacyFields: {"nanoId": "ALICE001"},
    relationships: [relationship],
  ),
  "bob": CharacterEntryData(
    characterId: "bob",
    displayName: "Bob",
    legacyFields: {"nanoId": "BOB00001"},
  ),
};

void main() {
  test(
    "character XML preserves layers and reads old descriptions as external",
    () {
      final encoded = CharacterCodec.saveXML(characters())!;
      expect(
        CharacterCodec.loadXML(encoded)!["alice"]!.relationships.single,
        relationship,
      );
      final document = xml.XmlDocument.parse(encoded);
      for (final node
          in document.findAllElements("InternalRelationship").toList()) {
        node.parent!.children.remove(node);
      }
      final old = CharacterCodec.loadXML(
        document.toXmlString(),
      )!["alice"]!.relationships.single;
      expect(old.relationship, "同事");
      expect(old.internalRelationship, isEmpty);
    },
  );

  test("snapshot XML preserves both relationship layers", () {
    final source = {
      "alice": CharacterStateBaseline(
        characterId: "alice",
        patch: CharacterStatePatch(relationships: const [relationship]),
      ),
    };
    final encoded = CharacterSnapshotCodec.saveBaselines(source)!;
    final restored = CharacterSnapshotCodec.loadBaselines(
      xml.XmlDocument.parse(encoded).rootElement,
    )!;
    expect(restored["alice"]!.patch.relationships!.single, relationship);
  });

  test("duplicates merge each layer independently", () {
    final merged = mergeDuplicateCharacterRelationships(const [
      relationship,
      CharacterRelationship(
        person: "Bob",
        relationship: "同事",
        internalRelationship: "崇拜",
      ),
    ]);
    expect(merged.single.relationship, "同事");
    expect(merged.single.internalRelationship, "嫉妒、崇拜");
    final updated = upsertCharacterRelationship(
      relationships: merged,
      person: "Bob",
      description: "朋友",
      internalRelationship: "信任",
      editingIndex: 0,
    );
    expect(updated.single.relationship, "朋友");
    expect(updated.single.internalRelationship, "信任");
  });

  test("graph filters labels without losing editable relationship data", () {
    const mapper = CharacterRelationshipGraphMapper();
    expect(mapper.map(characters()).edges.single.description, "同事");
    final internal = mapper.map(
      characters(),
      displayMode: CharacterRelationshipDisplayMode.internal,
    );
    expect(internal.edges.single.description, "嫉妒");
    expect(internal.edges.single.externalRelationship, "同事");
    final both = mapper.map(
      characters(),
      displayMode: CharacterRelationshipDisplayMode.both,
    );
    expect(both.edges.map((e) => e.description), containsAll(["同事", "嫉妒"]));
    expect(both.edges, hasLength(2));
    final externalOnly = Map<String, CharacterEntryData>.of(characters());
    externalOnly["alice"] = externalOnly["alice"]!.copyWith(
      relationships: const [
        CharacterRelationship(person: "Bob", relationship: "同事"),
      ],
    );
    expect(
      mapper
          .map(
            externalOnly,
            displayMode: CharacterRelationshipDisplayMode.internal,
          )
          .edges,
      isEmpty,
    );
  });

  test("opposite relationships with distinct feelings remain directional", () {
    final source = Map<String, CharacterEntryData>.of(characters());
    source["bob"] = source["bob"]!.copyWith(
      relationships: const [
        CharacterRelationship(
          person: "Alice",
          relationship: "同事",
          internalRelationship: "信任",
        ),
      ],
    );
    final graph = const CharacterRelationshipGraphMapper().map(source);
    expect(graph.edges, hasLength(1));
    expect(graph.edges.single.isBidirectional, isTrue);
  });

  testWidgets("graph selector switches layers and editing preserves both", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(characterDataProvider.notifier)
        .setCharacterData(characters());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: CharacterRelationshipGraphView()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final selector = find.byKey(
      const ValueKey("relationship-display-selector"),
    );
    expect(find.text("外在：同事"), findsNothing); // overview hides labels
    tester
        .widget<GestureDetector>(
          find
              .descendant(
                of: find.byKey(const ValueKey("relationship-node-alice")),
                matching: find.byType(GestureDetector),
              )
              .first,
        )
        .onTap!();
    await tester.pumpAndSettle();
    expect(find.text("外在：同事"), findsNWidgets(2));
    tester
        .widget<AppDropdownField<CharacterRelationshipDisplayMode>>(selector)
        .onChanged!(CharacterRelationshipDisplayMode.internal);
    await tester.pumpAndSettle();
    expect(find.text("內在：嫉妒"), findsNWidgets(2));
    tester
        .widget<AppDropdownField<CharacterRelationshipDisplayMode>>(selector)
        .onChanged!(CharacterRelationshipDisplayMode.both);
    await tester.pumpAndSettle();
    tester
        .widget<ListTile>(
          find.byKey(
            const ValueKey("relationship-neighbor-alice::0::bob::internal"),
          ),
        )
        .onTap!();
    await tester.pumpAndSettle();
    final edit = find.byKey(const ValueKey("relationship-edit-alice-internal"));
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      "信任",
    );
    await tester.tap(find.text("儲存"));
    await tester.pumpAndSettle();
    final saved = container
        .read(characterDataProvider)["alice"]!
        .relationships
        .single;
    expect(saved.relationship, "同事");
    expect(saved.internalRelationship, "信任");
    expect(tester.takeException(), isNull);
  });

  testWidgets("character table displays three editable columns", (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(characterDataProvider.notifier)
        .setCharacterData(characters());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: CharacterView())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text("Alice").first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text("人物關係描述"));
    await tester.tap(find.text("人物關係描述"));
    await tester.pumpAndSettle();
    final table = tester.widget<AppThreeColumnTable>(
      find.byKey(const ValueKey("character-relationships-table")),
    );
    expect(
      [table.firstHeader, table.secondHeader, table.thirdHeader],
      ["人物", "外在關係", "內在關係"],
    );
    final cell = tester.widget<AppEditableTableCell>(
      find.byKey(const ValueKey("relationship-internal-0")),
    );
    cell.onSubmitted("信任");
    await tester.pumpAndSettle();
    CharacterDraftSessionCoordinator.instance.flush(0);
    expect(
      container
          .read(characterDataProvider)["alice"]!
          .relationships
          .single
          .internalRelationship,
      "信任",
    );
    expect(
      container
          .read(characterDataProvider)["alice"]!
          .relationships
          .single
          .relationship,
      "同事",
    );
    expect(tester.takeException(), isNull);
  });
}
