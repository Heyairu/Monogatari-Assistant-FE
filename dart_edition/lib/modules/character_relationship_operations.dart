import "../models/character_data.dart";

String appendRelationshipDescription(String existing, String incoming) {
  final current = existing.trim();
  final addition = incoming.trim();
  if (current.isEmpty) return addition;
  if (addition.isEmpty) return current;
  if (current.split("、").map((value) => value.trim()).contains(addition)) {
    return current;
  }
  return "$current、$addition";
}

List<CharacterRelationship> mergeDuplicateCharacterRelationships(
  Iterable<CharacterRelationship> relationships,
) {
  final merged = <CharacterRelationship>[];
  final indexes = <String, int>{};
  for (final relationship in relationships) {
    final person = relationship.person.trim();
    if (person.isEmpty) {
      merged.add(relationship.copyWith());
      continue;
    }
    final key = person.toLowerCase();
    final existingIndex = indexes[key];
    if (existingIndex == null) {
      indexes[key] = merged.length;
      merged.add(
        relationship.copyWith(
          person: person,
          relationship: relationship.relationship.trim(),
        ),
      );
      continue;
    }
    final existing = merged[existingIndex];
    merged[existingIndex] = existing.copyWith(
      relationship: appendRelationshipDescription(
        existing.relationship,
        relationship.relationship,
      ),
    );
  }
  return merged;
}

List<CharacterRelationship> upsertCharacterRelationship({
  required Iterable<CharacterRelationship> relationships,
  required String person,
  required String description,
  int? editingIndex,
}) {
  final next = relationships.map((item) => item.copyWith()).toList();
  final normalizedPerson = person.trim();
  if (normalizedPerson.isEmpty) return next;

  final value = CharacterRelationship(
    person: normalizedPerson,
    relationship: description.trim(),
  );
  var duplicateIndex = -1;
  for (var index = 0; index < next.length; index++) {
    if (index == editingIndex) continue;
    if (next[index].person.trim().toLowerCase() ==
        normalizedPerson.toLowerCase()) {
      duplicateIndex = index;
      break;
    }
  }
  if (duplicateIndex >= 0) {
    final existing = next[duplicateIndex];
    next[duplicateIndex] = existing.copyWith(
      relationship: appendRelationshipDescription(
        existing.relationship,
        value.relationship,
      ),
    );
    if (editingIndex != null &&
        editingIndex >= 0 &&
        editingIndex < next.length) {
      next.removeAt(editingIndex);
    }
  } else if (editingIndex != null &&
      editingIndex >= 0 &&
      editingIndex < next.length) {
    next[editingIndex] = value;
  } else {
    next.add(value);
  }
  return mergeDuplicateCharacterRelationships(next);
}
