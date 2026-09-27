import "../models/character_data.dart";
import "character_relationship_graph_mapper.dart";

/// Returns null when a referenced row changed while a dialog was open.
/// One channel update preserves all opposite-layer values and reverse rows.
Map<String, CharacterEntryData>? updateCharacterRelationshipChannel(
  Map<String, CharacterEntryData> characters, {
  required List<CharacterRelationshipSource> sources,
  required CharacterRelationshipLayer layer,
  required String description,
  bool deleteDirection = false,
  String? targetPerson,
}) {
  if (sources.isEmpty) return null;
  final sourceId = sources.first.characterId;
  final source = characters[sourceId];
  if (source == null) return null;
  for (final ref in sources) {
    if (ref.characterId != sourceId ||
        ref.index < 0 ||
        ref.index >= source.relationships.length ||
        source.relationships[ref.index] != ref.value) {
      return null;
    }
  }
  final rows = source.relationships.toList();
  if (deleteDirection) {
    final indexes = sources.map((r) => r.index).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    for (final index in indexes) {
      rows.removeAt(index);
    }
  } else {
    for (var i = 0; i < sources.length; i++) {
      final index = sources[i].index;
      final text = i == 0 ? description.trim() : "";
      rows[index] = targetPerson != null
          ? rows[index].copyWith(person: targetPerson.trim())
          : layer == CharacterRelationshipLayer.external
          ? rows[index].copyWith(relationship: text)
          : rows[index].copyWith(internalRelationship: text);
    }
  }
  return Map<String, CharacterEntryData>.of(characters)
    ..[sourceId] = source.copyWith(relationships: rows);
}
