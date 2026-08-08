import "package:xml/xml.dart" as xml;

import "../character_data.dart";
import "../character_snapshot_data.dart";
import "xml_text_codec.dart";

class CharacterSnapshotCodec {
  static String? saveBaselines(Map<String, CharacterStateBaseline> baselines) {
    if (baselines.isEmpty) return null;
    final builder = xml.XmlBuilder();
    builder.element(
      "Type",
      nest: () {
        builder.element("Name", nest: "CharacterStateBaselines");
        final entries = baselines.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        for (final entry in entries) {
          builder.element(
            "Baseline",
            attributes: {"CharacterId": entry.key},
            nest: () {
              _writePatch(builder, entry.value.patch);
              XmlTextCodec.writeTextElement(builder, "Note", entry.value.note);
            },
          );
        }
      },
    );
    return builder.buildDocument().toXmlString(pretty: true, indent: "  ");
  }

  static String? saveChanges(List<CharacterStateChange> changes) {
    if (changes.isEmpty) return null;
    final builder = xml.XmlBuilder();
    builder.element(
      "Type",
      nest: () {
        builder.element("Name", nest: "CharacterStateChanges");
        for (final change in changes) {
          builder.element(
            "Change",
            attributes: {
              "Id": change.stateChangeId,
              "CharacterId": change.characterId,
              "SceneId": change.sceneUUID,
              if (change.sourcePlacementUUID?.isNotEmpty == true)
                "SourcePlacementId": change.sourcePlacementUUID!,
              "FallbackTick": change.fallbackTick.toString(),
              "Sequence": change.sequence.toString(),
            },
            nest: () {
              _writePatch(builder, change.patch);
              XmlTextCodec.writeTextElement(builder, "Note", change.note);
            },
          );
        }
      },
    );
    return builder.buildDocument().toXmlString(pretty: true, indent: "  ");
  }

  static Map<String, CharacterStateBaseline>? loadBaselines(
    xml.XmlElement typeElement,
  ) {
    final name = typeElement.findElements("Name").firstOrNull?.innerText;
    if (name != "CharacterStateBaselines") return null;
    final result = <String, CharacterStateBaseline>{};
    for (final node in typeElement.findElements("Baseline")) {
      final characterId = node.getAttribute("CharacterId")?.trim() ?? "";
      if (characterId.isEmpty) continue;
      result[characterId] = CharacterStateBaseline(
        characterId: characterId,
        patch: _readPatch(node),
        note: XmlTextCodec.readElementText(
          node.findElements("Note").firstOrNull,
        ),
      );
    }
    return Map<String, CharacterStateBaseline>.unmodifiable(result);
  }

  static List<CharacterStateChange>? loadChanges(xml.XmlElement typeElement) {
    final name = typeElement.findElements("Name").firstOrNull?.innerText;
    if (name != "CharacterStateChanges") return null;
    return List<CharacterStateChange>.unmodifiable(
      typeElement.findElements("Change").map((node) {
        final characterId = node.getAttribute("CharacterId")?.trim() ?? "";
        final sceneUUID = node.getAttribute("SceneId")?.trim() ?? "";
        if (characterId.isEmpty || sceneUUID.isEmpty) return null;
        return CharacterStateChange(
          stateChangeId: node.getAttribute("Id"),
          characterId: characterId,
          sceneUUID: sceneUUID,
          sourcePlacementUUID: node.getAttribute("SourcePlacementId"),
          fallbackTick:
              int.tryParse(node.getAttribute("FallbackTick") ?? "") ?? 0,
          sequence: int.tryParse(node.getAttribute("Sequence") ?? "") ?? 0,
          patch: _readPatch(node),
          note: XmlTextCodec.readElementText(
            node.findElements("Note").firstOrNull,
          ),
        );
      }).whereType<CharacterStateChange>(),
    );
  }

  static void _writePatch(xml.XmlBuilder builder, CharacterStatePatch patch) {
    builder.element(
      "Patch",
      nest: () {
        if (patch.conflicts != null) {
          builder.element(
            "Conflicts",
            nest: () {
              for (final item in patch.conflicts!) {
                builder.element(
                  "Conflict",
                  nest: () {
                    XmlTextCodec.writeTextElement(
                      builder,
                      "Obstacle",
                      item.obstacle,
                    );
                    XmlTextCodec.writeTextElement(
                      builder,
                      "Resolution",
                      item.resolution,
                    );
                  },
                );
              }
            },
          );
        }
        if (patch.relationships != null) {
          builder.element(
            "Relationships",
            nest: () {
              for (final item in patch.relationships!) {
                builder.element(
                  "Relationship",
                  nest: () {
                    XmlTextCodec.writeTextElement(
                      builder,
                      "Person",
                      item.person,
                    );
                    XmlTextCodec.writeTextElement(
                      builder,
                      "Description",
                      item.relationship,
                    );
                  },
                );
              }
            },
          );
        }
        _writeProfileEntries(builder, "Organizations", patch.organizations);
        _writeProfileEntries(builder, "StatusEntries", patch.statusEntries);
        if (patch.possessions != null) {
          builder.element(
            "Possessions",
            nest: () {
              for (final item in patch.possessions!) {
                builder.element(
                  "Possession",
                  nest: () {
                    XmlTextCodec.writeTextElement(builder, "Name", item.name);
                    XmlTextCodec.writeTextElement(
                      builder,
                      "Quantity",
                      item.quantity,
                    );
                    XmlTextCodec.writeTextElement(
                      builder,
                      "Description",
                      item.description,
                    );
                  },
                );
              }
            },
          );
        }
        if (patch.customFields != null) {
          final fields = patch.customFields!.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));
          builder.element(
            "CustomFields",
            nest: () {
              for (final field in fields) {
                builder.element(
                  "Field",
                  attributes: {"Key": field.key, "Type": field.value.type.name},
                  nest: field.value.rawValue,
                );
              }
            },
          );
        }
      },
    );
  }

  static void _writeProfileEntries(
    xml.XmlBuilder builder,
    String name,
    List<CharacterProfileTableEntry>? entries,
  ) {
    if (entries == null) return;
    builder.element(
      name,
      nest: () {
        for (final item in entries) {
          builder.element(
            "Entry",
            nest: () {
              XmlTextCodec.writeTextElement(builder, "Name", item.name);
              XmlTextCodec.writeTextElement(
                builder,
                "Description",
                item.description,
              );
            },
          );
        }
      },
    );
  }

  static CharacterStatePatch _readPatch(xml.XmlElement parent) {
    final patchNode = parent.findElements("Patch").firstOrNull;
    if (patchNode == null) return CharacterStatePatch();

    List<CharacterProfileTableEntry>? readProfileEntries(String name) {
      final container = patchNode.findElements(name).firstOrNull;
      if (container == null) return null;
      return container
          .findElements("Entry")
          .map(
            (node) => CharacterProfileTableEntry(
              name: XmlTextCodec.readElementText(
                node.findElements("Name").firstOrNull,
              ),
              description: XmlTextCodec.readElementText(
                node.findElements("Description").firstOrNull,
              ),
            ),
          )
          .toList(growable: false);
    }

    List<CharacterConflict>? conflicts;
    final conflictsNode = patchNode.findElements("Conflicts").firstOrNull;
    if (conflictsNode != null) {
      conflicts = conflictsNode
          .findElements("Conflict")
          .map(
            (node) => CharacterConflict(
              obstacle: XmlTextCodec.readElementText(
                node.findElements("Obstacle").firstOrNull,
              ),
              resolution: XmlTextCodec.readElementText(
                node.findElements("Resolution").firstOrNull,
              ),
            ),
          )
          .toList(growable: false);
    }

    List<CharacterRelationship>? relationships;
    final relationshipsNode = patchNode
        .findElements("Relationships")
        .firstOrNull;
    if (relationshipsNode != null) {
      relationships = relationshipsNode
          .findElements("Relationship")
          .map(
            (node) => CharacterRelationship(
              person: XmlTextCodec.readElementText(
                node.findElements("Person").firstOrNull,
              ),
              relationship: XmlTextCodec.readElementText(
                node.findElements("Description").firstOrNull,
              ),
            ),
          )
          .toList(growable: false);
    }

    List<CharacterPossessionEntry>? possessions;
    final possessionsNode = patchNode.findElements("Possessions").firstOrNull;
    if (possessionsNode != null) {
      final newEntries = possessionsNode.findElements("Possession").toList();
      possessions = newEntries.isNotEmpty
          ? newEntries
                .map(
                  (node) => CharacterPossessionEntry(
                    name: XmlTextCodec.readElementText(
                      node.findElements("Name").firstOrNull,
                    ),
                    quantity: XmlTextCodec.readElementText(
                      node.findElements("Quantity").firstOrNull,
                    ),
                    description: XmlTextCodec.readElementText(
                      node.findElements("Description").firstOrNull,
                    ),
                  ),
                )
                .toList(growable: false)
          : possessionsNode
                .findElements("Item")
                .map(
                  (node) => CharacterPossessionEntry(
                    name: XmlTextCodec.readElementText(node),
                  ),
                )
                .toList(growable: false);
    }

    Map<String, CustomFieldValue>? customFields;
    final customFieldsNode = patchNode.findElements("CustomFields").firstOrNull;
    if (customFieldsNode != null) {
      customFields = <String, CustomFieldValue>{};
      for (final node in customFieldsNode.findElements("Field")) {
        final key = node.getAttribute("Key")?.trim() ?? "";
        if (key.isEmpty) continue;
        final typeName = node.getAttribute("Type") ?? "text";
        final type = CustomFieldType.values.firstWhere(
          (value) => value.name == typeName,
          orElse: () => CustomFieldType.text,
        );
        customFields[key] = CustomFieldValue(
          type: type,
          rawValue: XmlTextCodec.readElementText(node),
        );
      }
    }

    final legacyStatuses = <CharacterProfileTableEntry>[];
    for (final mapping in const <String, String>{
      "Location": "所在地",
      "HealthStatus": "健康狀態",
      "Emotion": "情緒",
      "Alignment": "陣營",
    }.entries) {
      final node = patchNode.findElements(mapping.key).firstOrNull;
      if (node == null || node.getAttribute("Operation") == "clear") continue;
      final value = XmlTextCodec.readElementText(node);
      if (value.isNotEmpty) {
        legacyStatuses.add(
          CharacterProfileTableEntry(name: mapping.value, description: value),
        );
      }
    }
    final legacyCustomFields = <String, CustomFieldValue>{};
    for (final node in patchNode.findElements("CustomStatus")) {
      final key = node.getAttribute("Key")?.trim() ?? "";
      if (key.isEmpty || node.getAttribute("Operation") == "clear") continue;
      legacyCustomFields[key] = CustomFieldValue(
        rawValue: XmlTextCodec.readElementText(node),
      );
    }
    return CharacterStatePatch(
      conflicts: conflicts,
      relationships: relationships,
      organizations: readProfileEntries("Organizations"),
      statusEntries:
          readProfileEntries("StatusEntries") ??
          (legacyStatuses.isEmpty ? null : legacyStatuses),
      possessions: possessions,
      customFields:
          customFields ??
          (legacyCustomFields.isEmpty ? null : legacyCustomFields),
    );
  }
}
