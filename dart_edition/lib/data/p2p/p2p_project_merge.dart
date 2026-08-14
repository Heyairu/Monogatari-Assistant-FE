import "../../domain/models/p2p_revision_models.dart";
import "../../domain/models/p2p_sync_models.dart";
import "../../models/base_info_data.dart";
import "../../models/character_data.dart";
import "../../models/project_data.dart";

class P2pProjectRemainderSignatures {
  final String base;
  final String local;
  final String remote;

  const P2pProjectRemainderSignatures({
    required this.base,
    required this.local,
    required this.remote,
  });
}

class P2pProjectMergePlan {
  final String sessionId;
  final P2pRevisionMetadata? baseRevision;
  final P2pRevisionMetadata localRevision;
  final P2pRevisionMetadata remoteRevision;
  final ProjectData localProject;
  final _P2pProjectRemainderChoice _remainderChoice;
  final P2pKeyedTableMergeResult baseInfoMerge;
  final List<_P2pCharacterMergeEntry> _characterEntries;
  final List<P2pFieldConflictItem> conflicts;

  P2pProjectMergePlan._({
    required this.sessionId,
    required this.baseRevision,
    required this.localRevision,
    required this.remoteRevision,
    required this.localProject,
    required _P2pProjectRemainderChoice remainderChoice,
    required this.baseInfoMerge,
    required List<_P2pCharacterMergeEntry> characterEntries,
    required List<P2pFieldConflictItem> conflicts,
  }) : _remainderChoice = remainderChoice,
       _characterEntries = List.unmodifiable(characterEntries),
       conflicts = List.unmodifiable(conflicts);

  bool matchesHeads({
    required String activeSessionId,
    required Iterable<String> headRevisionIds,
  }) {
    final heads = headRevisionIds.toSet();
    return activeSessionId == sessionId &&
        heads.length == 2 &&
        heads.contains(localRevision.revisionId) &&
        heads.contains(remoteRevision.revisionId);
  }

  ProjectData apply(P2pConflictResolutionResult resolutions) {
    for (final conflict in conflicts) {
      resolutions.sideFor(conflict);
    }
    final baseInfoValues = P2pThreeWayMerge.applyResolutions(
      baseInfoMerge,
      resolutions,
    );
    final charactersById = <String, CharacterEntryData>{};
    for (final entry in _characterEntries) {
      final character = entry.resolve(resolutions);
      if (character != null) charactersById[character.characterId] = character;
    }
    final characters = <String, CharacterEntryData>{};
    for (final entry
        in charactersById.values.toList()
          ..sort((a, b) => a.characterId.compareTo(b.characterId))) {
      var key = entry.displayName.trim();
      if (key.isEmpty || characters.containsKey(key)) key = entry.characterId;
      characters[key] = entry;
    }
    final remainder = _remainderChoice.resolve(resolutions);
    return ProjectData(
      projectUUID: localProject.projectUUID,
      baseInfoData: _baseInfoFromMap(baseInfoValues),
      segmentsData: remainder.segmentsData,
      outlineData: remainder.outlineData,
      foreshadowData: remainder.foreshadowData,
      updatePlanData: remainder.updatePlanData,
      worldSettingsData: remainder.worldSettingsData,
      characterData: characters,
      characterStates: remainder.characterStates,
      characterStateBaselines: remainder.characterStateBaselines,
      characterStateChanges: remainder.characterStateChanges,
      timelineDocument: remainder.timelineDocument,
      outlineChapterLinks: remainder.outlineChapterLinks,
      totalWords: remainder.totalWords,
      contentText: remainder.contentText,
      isDirty: true,
    );
  }
}

class P2pProjectMergeEngine {
  // Production session IDs contain a device UUID and two SHA-256 revision IDs:
  // 36 + 1 + 64 + 1 + 64 = 166 characters. Keep the value bounded while
  // allowing that canonical representation and future version prefixes.
  static const int maxSessionIdLength = 256;

  const P2pProjectMergeEngine();

  P2pProjectMergePlan createPlan({
    required String sessionId,
    required P2pRevisionMetadata baseRevision,
    required P2pRevisionMetadata localRevision,
    required P2pRevisionMetadata remoteRevision,
    required ProjectData base,
    required ProjectData local,
    required ProjectData remote,
    P2pProjectRemainderSignatures? remainderSignatures,
  }) {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty ||
        normalizedSessionId.length > maxSessionIdLength) {
      throw const FormatException("P2P merge session ID 無效。");
    }
    final projectUuid = local.projectUUID.trim().toLowerCase();
    if (base.projectUUID.trim().toLowerCase() != projectUuid ||
        remote.projectUUID.trim().toLowerCase() != projectUuid ||
        baseRevision.projectUuid != projectUuid ||
        localRevision.projectUuid != projectUuid ||
        remoteRevision.projectUuid != projectUuid) {
      throw const FormatException("三方合併的 project UUID 必須一致。");
    }
    if (localRevision.parents.contains(remoteRevision.revisionId) ||
        remoteRevision.parents.contains(localRevision.revisionId)) {
      throw const FormatException(
        "已有 ancestor 關係的 revisions 不應進入 conflict merge。",
      );
    }

    final baseInfoMerge = P2pThreeWayMerge.mergeKeyedTable(
      groupId: projectUuid,
      groupType: "project",
      groupLabel: "作品資訊",
      fieldPrefix: "作品資訊",
      base: _baseInfoToMap(base.baseInfoData),
      local: _baseInfoToMap(local.baseInfoData),
      remote: _baseInfoToMap(remote.baseInfoData),
    );
    final remainderChoice = _P2pProjectRemainderChoice.evaluate(
      projectUuid: projectUuid,
      local: local,
      remote: remote,
      signatures: remainderSignatures,
    );
    final baseCharacters = _charactersByStableId(base.characterData.values);
    final localCharacters = _charactersByStableId(local.characterData.values);
    final remoteCharacters = _charactersByStableId(remote.characterData.values);
    final characterEntries = <_P2pCharacterMergeEntry>[];
    final conflicts = <P2pFieldConflictItem>[
      ...baseInfoMerge.conflicts,
      if (remainderChoice.conflict != null) remainderChoice.conflict!,
    ];
    final ids = <String>{
      ...baseCharacters.keys,
      ...localCharacters.keys,
      ...remoteCharacters.keys,
    }.toList()..sort();
    for (final id in ids) {
      final entry = _mergeCharacter(
        id: id,
        base: baseCharacters[id],
        local: localCharacters[id],
        remote: remoteCharacters[id],
      );
      characterEntries.add(entry);
      conflicts.addAll(entry.conflicts);
    }
    return P2pProjectMergePlan._(
      sessionId: normalizedSessionId,
      baseRevision: baseRevision,
      localRevision: localRevision,
      remoteRevision: remoteRevision,
      localProject: local,
      remainderChoice: remainderChoice,
      baseInfoMerge: baseInfoMerge,
      characterEntries: characterEntries,
      conflicts: conflicts,
    );
  }

  P2pProjectMergePlan createPlanWithoutCommonAncestor({
    required String sessionId,
    required P2pRevisionMetadata localRevision,
    required P2pRevisionMetadata remoteRevision,
    required ProjectData local,
    required ProjectData remote,
    required String localRemainderSignature,
    required String remoteRemainderSignature,
  }) {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty ||
        normalizedSessionId.length > maxSessionIdLength) {
      throw const FormatException("P2P merge session ID 無效。");
    }
    final projectUuid = local.projectUUID.trim().toLowerCase();
    if (remote.projectUUID.trim().toLowerCase() != projectUuid ||
        localRevision.projectUuid != projectUuid ||
        remoteRevision.projectUuid != projectUuid) {
      throw const FormatException("無共同祖先合併的 project UUID 必須一致。");
    }
    final baseInfoMerge = P2pThreeWayMerge.mergeKeyedTableWithoutBase(
      groupId: projectUuid,
      groupType: "project",
      groupLabel: "作品資訊",
      fieldPrefix: "作品資訊",
      local: _baseInfoToMap(local.baseInfoData),
      remote: _baseInfoToMap(remote.baseInfoData),
    );
    final remainderChoice = _P2pProjectRemainderChoice.evaluateWithoutBase(
      projectUuid: projectUuid,
      local: local,
      remote: remote,
      localSignature: localRemainderSignature,
      remoteSignature: remoteRemainderSignature,
    );
    final localCharacters = _charactersByStableId(local.characterData.values);
    final remoteCharacters = _charactersByStableId(remote.characterData.values);
    final characterEntries = <_P2pCharacterMergeEntry>[];
    final conflicts = <P2pFieldConflictItem>[
      ...baseInfoMerge.conflicts,
      if (remainderChoice.conflict != null) remainderChoice.conflict!,
    ];
    final ids = <String>{
      ...localCharacters.keys,
      ...remoteCharacters.keys,
    }.toList()..sort();
    for (final id in ids) {
      final entry = _mergeCharacterWithoutBase(
        id: id,
        local: localCharacters[id],
        remote: remoteCharacters[id],
      );
      characterEntries.add(entry);
      conflicts.addAll(entry.conflicts);
    }
    return P2pProjectMergePlan._(
      sessionId: normalizedSessionId,
      baseRevision: null,
      localRevision: localRevision,
      remoteRevision: remoteRevision,
      localProject: local,
      remainderChoice: remainderChoice,
      baseInfoMerge: baseInfoMerge,
      characterEntries: characterEntries,
      conflicts: conflicts,
    );
  }

  _P2pCharacterMergeEntry _mergeCharacter({
    required String id,
    required CharacterEntryData? base,
    required CharacterEntryData? local,
    required CharacterEntryData? remote,
  }) {
    final baseMap = base == null ? null : _characterToMap(base);
    final localMap = local == null ? null : _characterToMap(local);
    final remoteMap = remote == null ? null : _characterToMap(remote);
    if (P2pThreeWayMerge.deepEquals(localMap, remoteMap)) {
      return _P2pCharacterMergeEntry.resolved(id, localMap);
    }
    if (P2pThreeWayMerge.deepEquals(localMap, baseMap)) {
      return _P2pCharacterMergeEntry.resolved(id, remoteMap);
    }
    if (P2pThreeWayMerge.deepEquals(remoteMap, baseMap)) {
      return _P2pCharacterMergeEntry.resolved(id, localMap);
    }
    final label = local?.displayName.trim().isNotEmpty == true
        ? local!.displayName.trim()
        : remote?.displayName.trim().isNotEmpty == true
        ? remote!.displayName.trim()
        : base?.displayName.trim().isNotEmpty == true
        ? base!.displayName.trim()
        : id;
    if (localMap != null && remoteMap != null) {
      final merge = P2pThreeWayMerge.mergeKeyedTable(
        groupId: id,
        groupType: "character",
        groupLabel: "角色：$label",
        fieldPrefix: "衝突欄位",
        base: baseMap ?? const <String, Object?>{},
        local: localMap,
        remote: remoteMap,
      );
      return _P2pCharacterMergeEntry.merged(id, merge);
    }
    final conflict = P2pFieldConflictItem(
      groupId: id,
      groupType: "character",
      groupLabel: "角色：$label",
      fieldPathSegments: const <String>["角色"],
      base: baseMap == null
          ? const P2pFieldValue.absent()
          : P2pFieldValue.present(baseMap),
      local: localMap == null
          ? const P2pFieldValue.absent()
          : P2pFieldValue.present(localMap),
      remote: remoteMap == null
          ? const P2pFieldValue.absent()
          : P2pFieldValue.present(remoteMap),
    );
    return _P2pCharacterMergeEntry.conflicted(id, conflict);
  }

  _P2pCharacterMergeEntry _mergeCharacterWithoutBase({
    required String id,
    required CharacterEntryData? local,
    required CharacterEntryData? remote,
  }) {
    final localMap = local == null ? null : _characterToMap(local);
    final remoteMap = remote == null ? null : _characterToMap(remote);
    if (P2pThreeWayMerge.deepEquals(localMap, remoteMap)) {
      return _P2pCharacterMergeEntry.resolved(id, localMap);
    }
    if (localMap == null) {
      return _P2pCharacterMergeEntry.resolved(id, remoteMap);
    }
    if (remoteMap == null) {
      return _P2pCharacterMergeEntry.resolved(id, localMap);
    }
    final localCharacter = local!;
    final remoteCharacter = remote!;
    final label = localCharacter.displayName.trim().isNotEmpty
        ? localCharacter.displayName.trim()
        : remoteCharacter.displayName.trim().isNotEmpty
        ? remoteCharacter.displayName.trim()
        : id;
    final merge = P2pThreeWayMerge.mergeKeyedTableWithoutBase(
      groupId: id,
      groupType: "character",
      groupLabel: "角色：$label",
      fieldPrefix: "衝突欄位",
      local: localMap,
      remote: remoteMap,
    );
    return _P2pCharacterMergeEntry.merged(id, merge);
  }
}

class _P2pProjectRemainderChoice {
  final ProjectData local;
  final ProjectData remote;
  final bool useRemote;
  final P2pFieldConflictItem? conflict;

  const _P2pProjectRemainderChoice._({
    required this.local,
    required this.remote,
    required this.useRemote,
    this.conflict,
  });

  factory _P2pProjectRemainderChoice.evaluate({
    required String projectUuid,
    required ProjectData local,
    required ProjectData remote,
    required P2pProjectRemainderSignatures? signatures,
  }) {
    if (signatures == null || signatures.local == signatures.remote) {
      return _P2pProjectRemainderChoice._(
        local: local,
        remote: remote,
        useRemote: false,
      );
    }
    if (signatures.local == signatures.base) {
      return _P2pProjectRemainderChoice._(
        local: local,
        remote: remote,
        useRemote: true,
      );
    }
    if (signatures.remote == signatures.base) {
      return _P2pProjectRemainderChoice._(
        local: local,
        remote: remote,
        useRemote: false,
      );
    }
    return _P2pProjectRemainderChoice._(
      local: local,
      remote: remote,
      useRemote: false,
      conflict: P2pFieldConflictItem(
        groupId: projectUuid,
        groupType: "projectRemainder",
        groupLabel: "章節、大綱、世界觀、計畫與時間軸",
        fieldPathSegments: const <String>["專案區段", "整體版本"],
        base: const P2pFieldValue.present("共同祖先版本"),
        local: const P2pFieldValue.present("本機版本（保留本機區段內容）"),
        remote: const P2pFieldValue.present("對方版本（採用對方區段內容）"),
      ),
    );
  }

  factory _P2pProjectRemainderChoice.evaluateWithoutBase({
    required String projectUuid,
    required ProjectData local,
    required ProjectData remote,
    required String localSignature,
    required String remoteSignature,
  }) {
    if (localSignature == remoteSignature) {
      return _P2pProjectRemainderChoice._(
        local: local,
        remote: remote,
        useRemote: false,
      );
    }
    return _P2pProjectRemainderChoice._(
      local: local,
      remote: remote,
      useRemote: false,
      conflict: P2pFieldConflictItem(
        groupId: projectUuid,
        groupType: "projectRemainder",
        groupLabel: "章節、大綱、世界觀、計畫與時間軸",
        fieldPathSegments: const <String>["專案區段", "整體版本"],
        base: const P2pFieldValue.absent(),
        local: const P2pFieldValue.present("本機獨立歷史（保留本機區段內容）"),
        remote: const P2pFieldValue.present("對方獨立歷史（採用對方區段內容）"),
      ),
    );
  }

  ProjectData resolve(P2pConflictResolutionResult resolutions) {
    final item = conflict;
    if (item == null) return useRemote ? remote : local;
    return resolutions.sideFor(item) == P2pConflictSide.remote ? remote : local;
  }
}

class _P2pCharacterMergeEntry {
  final String id;
  final Map<String, Object?>? resolvedValues;
  final P2pKeyedTableMergeResult? merge;
  final P2pFieldConflictItem? entityConflict;

  const _P2pCharacterMergeEntry._(
    this.id, {
    this.resolvedValues,
    this.merge,
    this.entityConflict,
  });

  factory _P2pCharacterMergeEntry.resolved(
    String id,
    Map<String, Object?>? values,
  ) => _P2pCharacterMergeEntry._(id, resolvedValues: values);

  factory _P2pCharacterMergeEntry.merged(
    String id,
    P2pKeyedTableMergeResult merge,
  ) => _P2pCharacterMergeEntry._(id, merge: merge);

  factory _P2pCharacterMergeEntry.conflicted(
    String id,
    P2pFieldConflictItem conflict,
  ) => _P2pCharacterMergeEntry._(id, entityConflict: conflict);

  Iterable<P2pFieldConflictItem> get conflicts sync* {
    if (entityConflict != null) yield entityConflict!;
    if (merge != null) yield* merge!.conflicts;
  }

  CharacterEntryData? resolve(P2pConflictResolutionResult resolutions) {
    Map<String, Object?>? values;
    if (entityConflict != null) {
      final conflict = entityConflict!;
      final chosen = resolutions.sideFor(conflict) == P2pConflictSide.local
          ? conflict.local
          : conflict.remote;
      if (!chosen.exists) return null;
      values = Map<String, Object?>.from(chosen.value! as Map);
    } else if (merge != null) {
      values = P2pThreeWayMerge.applyResolutions(merge!, resolutions);
    } else {
      values = resolvedValues;
    }
    return values == null ? null : _characterFromMap(id, values);
  }
}

Map<String, CharacterEntryData> _charactersByStableId(
  Iterable<CharacterEntryData> source,
) {
  final result = <String, CharacterEntryData>{};
  for (final character in source) {
    final id = character.characterId.trim();
    if (id.isEmpty || result.containsKey(id)) {
      throw const FormatException("角色同步需要不重複且非空的 character ID。");
    }
    result[id] = character;
  }
  return result;
}

Map<String, Object?> _baseInfoToMap(BaseInfoData value) => <String, Object?>{
  "書名": value.bookName,
  "作者": value.author,
  "創作目的": value.purpose,
  "回顧": value.toRecap,
  "故事類型": value.storyType,
  "簡介": value.intro,
  "標籤": List<String>.from(value.tags),
};

BaseInfoData _baseInfoFromMap(Map<String, Object?> value) => BaseInfoData(
  bookName: value["書名"]! as String,
  author: value["作者"]! as String,
  purpose: value["創作目的"]! as String,
  toRecap: value["回顧"]! as String,
  storyType: value["故事類型"]! as String,
  intro: value["簡介"]! as String,
  tags: List<String>.from(value["標籤"]! as List),
);

Map<String, Object?> _characterToMap(CharacterEntryData value) {
  return <String, Object?>{
    "姓名": value.displayName,
    "別名": value.aliases
        .map((item) => <String, Object?>{"類型": item.type, "值": item.values})
        .toList(growable: false),
    "職業或角色": value.roleOrOccupation,
    "年齡": value.age,
    "性別": value.gender,
    "外觀": value.appearanceSummary,
    "性格": value.personalitySummary,
    "說話方式": value.speechStyle,
    "動機": value.motivation,
    "目標": value.goal,
    "內在衝突": value.conflicts
        .map(
          (item) => <String, Object?>{
            "阻礙": item.obstacle,
            "解決": item.resolution,
          },
        )
        .toList(growable: false),
    "價值觀": value.valuesAndBeliefs,
    "恐懼": value.fear,
    "關係摘要": value.relationshipSummary,
    "人物關係": _indexRows(
      value.relationships,
      keyOf: (item) => item.person.trim().toLowerCase(),
      rowOf: (item) => <String, Object?>{
        "人物": item.person,
        "關係": item.relationship,
      },
      tableLabel: "人物關係",
    ),
    "角色類型": value.characterType,
    "組織": _profileRows(value.organizations, "組織"),
    "擁有物品": _indexRows(
      value.possessions,
      keyOf: (item) => item.name.trim().toLowerCase(),
      rowOf: (item) => <String, Object?>{
        "名稱": item.name,
        "數量": item.quantity,
        "描述": item.description,
      },
      tableLabel: "擁有物品",
    ),
    "狀態": _profileRows(value.statusEntries, "狀態"),
    "備註": value.notes,
    "陣營": value.alignment,
    "自訂欄位": <String, Object?>{
      for (final entry in value.customFields.entries)
        entry.key: <String, Object?>{
          "類型": entry.value.type.name,
          "值": entry.value.rawValue,
        },
    },
    "文字欄位": Map<String, Object?>.from(value.textFields),
    "舊版欄位": Map<String, Object?>.from(value.legacyFields),
    "進階能力": <String, Object?>{
      "常用能力": Map<String, Object?>.from(value.advanced.commonAbilities),
      "社交特質": Map<String, Object?>.from(value.advanced.socialTraits),
      "處事方式": Map<String, Object?>.from(value.advanced.approaches),
      "人格特質": Map<String, Object?>.from(value.advanced.personalityTraits),
    },
    "阻礙事件": value.hinderEvents
        .map((item) => <String, Object?>{"事件": item.event, "解法": item.solve})
        .toList(growable: false),
    "喜歡做": List<String>.from(value.loveToDoList),
    "討厭做": List<String>.from(value.hateToDoList),
    "想做": List<String>.from(value.wantToDoList),
    "害怕做": List<String>.from(value.fearToDoList),
    "擅長做": List<String>.from(value.proficientToDoList),
    "不擅長做": List<String>.from(value.unProficientToDoList),
    "常用能力值": List<double>.from(value.commonAbilityValues),
    "表達愛": Map<String, Object?>.from(value.howToShowLove),
    "表達好感": Map<String, Object?>.from(value.howToShowGoodwill),
    "處理厭惡": Map<String, Object?>.from(value.handleHatePeople),
    "社交值": List<double>.from(value.socialItemValues),
    "關係": value.relationship,
    "尋找新戀情": value.isFindNewLove,
    "後宮": value.isHarem,
    "處事值": List<double>.from(value.approachValues),
    "特質值": List<double>.from(value.traitsValues),
    "喜歡項目": List<String>.from(value.likeItemList),
    "崇拜項目": List<String>.from(value.admireItemList),
    "討厭項目": List<String>.from(value.hateItemList),
    "害怕項目": List<String>.from(value.fearItemList),
    "熟悉項目": List<String>.from(value.familiarItemList),
  };
}

Map<String, Object?> _profileRows(
  Iterable<CharacterProfileTableEntry> source,
  String label,
) => _indexRows(
  source,
  keyOf: (item) => item.name.trim().toLowerCase(),
  rowOf: (item) => <String, Object?>{"名稱": item.name, "描述": item.description},
  tableLabel: label,
);

Map<String, Object?> _indexRows<T>(
  Iterable<T> source, {
  required String Function(T value) keyOf,
  required Map<String, Object?> Function(T value) rowOf,
  required String tableLabel,
}) {
  final result = <String, Object?>{};
  for (final value in source) {
    final key = keyOf(value);
    if (key.isEmpty || result.containsKey(key)) {
      throw FormatException("$tableLabel 含空白或正規化後重複的 key。");
    }
    result[key] = rowOf(value);
  }
  return result;
}

CharacterEntryData _characterFromMap(String id, Map<String, Object?> value) {
  final advanced = Map<String, Object?>.from(value["進階能力"]! as Map);
  return CharacterEntryData(
    characterId: id,
    displayName: value["姓名"]! as String,
    aliases: (value["別名"]! as List)
        .map((raw) {
          final row = Map<String, Object?>.from(raw as Map);
          return CharacterAlias(
            type: row["類型"]! as String,
            values: List<String>.from(row["值"]! as List),
          );
        })
        .toList(growable: false),
    roleOrOccupation: value["職業或角色"]! as String,
    age: value["年齡"]! as String,
    gender: value["性別"]! as String,
    appearanceSummary: value["外觀"]! as String,
    personalitySummary: value["性格"]! as String,
    speechStyle: value["說話方式"]! as String,
    motivation: value["動機"]! as String,
    goal: value["目標"]! as String,
    conflicts: (value["內在衝突"]! as List)
        .map((raw) {
          final row = Map<String, Object?>.from(raw as Map);
          return CharacterConflict(
            obstacle: row["阻礙"]! as String,
            resolution: row["解決"]! as String,
          );
        })
        .toList(growable: false),
    valuesAndBeliefs: value["價值觀"]! as String,
    fear: value["恐懼"]! as String,
    relationshipSummary: value["關係摘要"]! as String,
    relationships: _rows(value["人物關係"])
        .map(
          (row) => CharacterRelationship(
            person: row["人物"]! as String,
            relationship: row["關係"]! as String,
          ),
        )
        .toList(growable: false),
    characterType: value["角色類型"]! as String,
    organizations: _profileRowsFromMap(value["組織"]),
    possessions: _rows(value["擁有物品"])
        .map(
          (row) => CharacterPossessionEntry(
            name: row["名稱"]! as String,
            quantity: row["數量"]! as String,
            description: row["描述"]! as String,
          ),
        )
        .toList(growable: false),
    statusEntries: _profileRowsFromMap(value["狀態"]),
    notes: value["備註"]! as String,
    alignment: value["陣營"] as String?,
    customFields: <String, CustomFieldValue>{
      for (final entry in Map<String, Object?>.from(
        value["自訂欄位"]! as Map,
      ).entries)
        entry.key: _customFieldFromMap(entry.value),
    },
    textFields: Map<String, String>.from(value["文字欄位"]! as Map),
    legacyFields: Map<String, String>.from(value["舊版欄位"]! as Map),
    advanced: CharacterAdvancedProfile(
      commonAbilities: Map<String, double>.from(advanced["常用能力"]! as Map),
      socialTraits: Map<String, double>.from(advanced["社交特質"]! as Map),
      approaches: Map<String, double>.from(advanced["處事方式"]! as Map),
      personalityTraits: Map<String, double>.from(advanced["人格特質"]! as Map),
    ),
    hinderEvents: (value["阻礙事件"]! as List)
        .map((raw) {
          final row = Map<String, Object?>.from(raw as Map);
          return CharacterHinderEvent(
            event: row["事件"]! as String,
            solve: row["解法"]! as String,
          );
        })
        .toList(growable: false),
    loveToDoList: List<String>.from(value["喜歡做"]! as List),
    hateToDoList: List<String>.from(value["討厭做"]! as List),
    wantToDoList: List<String>.from(value["想做"]! as List),
    fearToDoList: List<String>.from(value["害怕做"]! as List),
    proficientToDoList: List<String>.from(value["擅長做"]! as List),
    unProficientToDoList: List<String>.from(value["不擅長做"]! as List),
    commonAbilityValues: List<double>.from(value["常用能力值"]! as List),
    howToShowLove: Map<String, bool>.from(value["表達愛"]! as Map),
    howToShowGoodwill: Map<String, bool>.from(value["表達好感"]! as Map),
    handleHatePeople: Map<String, bool>.from(value["處理厭惡"]! as Map),
    socialItemValues: List<double>.from(value["社交值"]! as List),
    relationship: value["關係"] as String?,
    isFindNewLove: value["尋找新戀情"]! as bool,
    isHarem: value["後宮"]! as bool,
    approachValues: List<double>.from(value["處事值"]! as List),
    traitsValues: List<double>.from(value["特質值"]! as List),
    likeItemList: List<String>.from(value["喜歡項目"]! as List),
    admireItemList: List<String>.from(value["崇拜項目"]! as List),
    hateItemList: List<String>.from(value["討厭項目"]! as List),
    fearItemList: List<String>.from(value["害怕項目"]! as List),
    familiarItemList: List<String>.from(value["熟悉項目"]! as List),
  );
}

Iterable<Map<String, Object?>> _rows(Object? source) sync* {
  final rows = Map<String, Object?>.from(source! as Map).entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  for (final row in rows) {
    yield Map<String, Object?>.from(row.value! as Map);
  }
}

List<CharacterProfileTableEntry> _profileRowsFromMap(Object? source) =>
    _rows(source)
        .map(
          (row) => CharacterProfileTableEntry(
            name: row["名稱"]! as String,
            description: row["描述"]! as String,
          ),
        )
        .toList(growable: false);

CustomFieldValue _customFieldFromMap(Object? source) {
  final row = Map<String, Object?>.from(source! as Map);
  final typeName = row["類型"]! as String;
  return CustomFieldValue(
    type: CustomFieldType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => throw FormatException("未知的角色自訂欄位類型：$typeName"),
    ),
    rawValue: row["值"]! as String,
  );
}
