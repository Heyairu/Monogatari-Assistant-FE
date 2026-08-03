import "../models/character_data.dart";

enum CharacterRelationshipResolutionKind { resolved, ambiguous, unresolved }

class CharacterRelationshipResolution {
  final CharacterRelationshipResolutionKind kind;
  final String rawPerson;
  final String? characterId;
  final List<String> candidateCharacterIds;

  const CharacterRelationshipResolution({
    required this.kind,
    required this.rawPerson,
    this.characterId,
    this.candidateCharacterIds = const [],
  });

  bool get isResolved =>
      kind == CharacterRelationshipResolutionKind.resolved &&
      characterId != null;
}

class CharacterRelationshipResolver {
  static final RegExp _nanoIdSuffix = RegExp(
    r"^(.*?)\s*\(([0-9A-Za-z_-]{8})\)\s*$",
  );

  final Map<String, CharacterEntryData> characters;

  const CharacterRelationshipResolver(this.characters);

  CharacterRelationshipResolution resolve(String person) {
    final raw = person.trim();
    if (raw.isEmpty) {
      return CharacterRelationshipResolution(
        kind: CharacterRelationshipResolutionKind.unresolved,
        rawPerson: raw,
      );
    }

    final suffixMatch = _nanoIdSuffix.firstMatch(raw);
    final requestedName = (suffixMatch?.group(1) ?? raw).trim().toLowerCase();
    final requestedNanoId = suffixMatch?.group(2)?.toLowerCase();
    final matches = characters.entries
        .where((entry) {
          final displayName = _displayName(entry.value).trim().toLowerCase();
          if (displayName != requestedName) return false;
          return requestedNanoId == null ||
              entry.value.nanoId.toLowerCase() == requestedNanoId;
        })
        .toList(growable: false);

    if (matches.length == 1) {
      return CharacterRelationshipResolution(
        kind: CharacterRelationshipResolutionKind.resolved,
        rawPerson: raw,
        characterId: matches.single.key,
        candidateCharacterIds: [matches.single.key],
      );
    }
    if (matches.length > 1) {
      return CharacterRelationshipResolution(
        kind: CharacterRelationshipResolutionKind.ambiguous,
        rawPerson: raw,
        candidateCharacterIds: matches.map((entry) => entry.key).toList(),
      );
    }
    return CharacterRelationshipResolution(
      kind: CharacterRelationshipResolutionKind.unresolved,
      rawPerson: raw,
    );
  }

  static String displayLabel(
    String characterId,
    Map<String, CharacterEntryData> characters,
  ) {
    final entry = characters[characterId];
    if (entry == null) return characterId;
    final name = _displayName(entry).trim();
    final duplicateCount = characters.values
        .where(
          (candidate) =>
              _displayName(candidate).trim().toLowerCase() ==
              name.toLowerCase(),
        )
        .length;
    return duplicateCount > 1 ? "$name (${entry.nanoId})" : name;
  }

  static String _displayName(CharacterEntryData entry) {
    return entry.displayName.isEmpty
        ? entry.textFields["name"] ?? entry.characterId
        : entry.displayName;
  }
}
