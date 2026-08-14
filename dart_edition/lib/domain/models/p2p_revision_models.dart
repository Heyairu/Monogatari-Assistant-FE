import "dart:collection";
import "dart:convert";

import "p2p_sync_models.dart";

enum P2pVersionVectorRelation { equal, dominates, dominatedBy, concurrent }

enum P2pRevisionSummaryRelation { equal, localAhead, remoteAhead, concurrent }

class P2pVersionVector {
  final Map<String, int> counters;

  P2pVersionVector(Map<String, int> counters)
    : counters = UnmodifiableMapView(_normalizeCounters(counters));

  P2pVersionVector.empty() : counters = const <String, int>{};

  factory P2pVersionVector.fromJson(Map<String, Object?> json) {
    final counters = <String, int>{};
    for (final entry in json.entries) {
      final value = entry.value;
      if (value is! int) {
        throw const FormatException("P2P version vector counter 必須是整數。");
      }
      counters[entry.key] = value;
    }
    return P2pVersionVector(counters);
  }

  int counterFor(String deviceId) => counters[deviceId.toLowerCase()] ?? 0;

  P2pVersionVector increment(String deviceId) {
    final normalized = _normalizeDeviceId(deviceId);
    return P2pVersionVector(<String, int>{
      ...counters,
      normalized: counterFor(normalized) + 1,
    });
  }

  P2pVersionVector merge(P2pVersionVector other) {
    final keys = <String>{...counters.keys, ...other.counters.keys};
    return P2pVersionVector(<String, int>{
      for (final key in keys)
        key: counterFor(key) > other.counterFor(key)
            ? counterFor(key)
            : other.counterFor(key),
    });
  }

  P2pVersionVectorRelation compare(P2pVersionVector other) {
    var hasGreater = false;
    var hasLower = false;
    for (final key in <String>{...counters.keys, ...other.counters.keys}) {
      final local = counterFor(key);
      final remote = other.counterFor(key);
      if (local > remote) hasGreater = true;
      if (local < remote) hasLower = true;
    }
    if (!hasGreater && !hasLower) return P2pVersionVectorRelation.equal;
    if (hasGreater && !hasLower) return P2pVersionVectorRelation.dominates;
    if (!hasGreater && hasLower) {
      return P2pVersionVectorRelation.dominatedBy;
    }
    return P2pVersionVectorRelation.concurrent;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    for (final entry in counters.entries) entry.key: entry.value,
  };

  String get displayLabel {
    if (counters.isEmpty) return "∅";
    return counters.entries
        .map((entry) => "${entry.key.substring(0, 8)}:${entry.value}")
        .join(", ");
  }

  static SplayTreeMap<String, int> _normalizeCounters(Map<String, int> source) {
    final result = SplayTreeMap<String, int>();
    for (final entry in source.entries) {
      final deviceId = _normalizeDeviceId(entry.key);
      if (entry.value < 1) {
        throw const FormatException("P2P version vector counter 必須是大於零的整數。");
      }
      result[deviceId] = entry.value;
    }
    return result;
  }

  static String _normalizeDeviceId(String value) {
    final normalized = value.trim().toLowerCase();
    if (!P2pProjectStatus.isValidProjectUuid(normalized)) {
      throw const FormatException("P2P version vector device ID 無效。");
    }
    return normalized;
  }

  @override
  bool operator ==(Object other) {
    if (other is! P2pVersionVector ||
        counters.length != other.counters.length) {
      return false;
    }
    return counters.entries.every(
      (entry) => other.counters[entry.key] == entry.value,
    );
  }

  @override
  int get hashCode => Object.hashAll(
    counters.entries.map((entry) => Object.hash(entry.key, entry.value)),
  );
}

class P2pRevisionMetadata {
  static final RegExp _sha256Pattern = RegExp(r"^[0-9a-f]{64}$");

  final String revisionId;
  final String projectUuid;
  final List<String> parents;
  final P2pVersionVector clock;
  final String authorDeviceId;
  final int createdAtEpochSeconds;
  final String contentSha256;
  final String formatVersion;

  P2pRevisionMetadata({
    required String revisionId,
    required String projectUuid,
    required Iterable<String> parents,
    required this.clock,
    required String authorDeviceId,
    required this.createdAtEpochSeconds,
    required String contentSha256,
    required String formatVersion,
  }) : revisionId = _normalizeHash(revisionId, "revision ID"),
       projectUuid = _normalizeUuid(projectUuid, "project UUID"),
       parents = List.unmodifiable(_normalizeParents(parents)),
       authorDeviceId = _normalizeUuid(authorDeviceId, "author device ID"),
       contentSha256 = _normalizeHash(contentSha256, "content SHA-256"),
       formatVersion = _normalizeFormatVersion(formatVersion) {
    if (createdAtEpochSeconds < 0) {
      throw const FormatException("P2P revision createdAt 無效。");
    }
    if (clock.counterFor(this.authorDeviceId) < 1) {
      throw const FormatException("P2P revision clock 缺少作者 counter。");
    }
    if (this.parents.contains(this.revisionId)) {
      throw const FormatException("P2P revision 不可將自己列為 parent。");
    }
  }

  factory P2pRevisionMetadata.fromJson(Map<String, Object?> json) {
    final revisionId = json["revisionId"];
    final projectUuid = json["projectUuid"];
    final parents = json["parents"];
    final clock = json["clock"];
    final authorDeviceId = json["authorDeviceId"];
    final createdAt = json["createdAt"];
    final contentSha256 = json["contentSha256"];
    final formatVersion = json["formatVersion"];
    if (revisionId is! String ||
        projectUuid is! String ||
        parents is! List ||
        clock is! Map ||
        authorDeviceId is! String ||
        createdAt is! int ||
        contentSha256 is! String ||
        formatVersion is! String) {
      throw const FormatException("P2P revision metadata 欄位不完整。");
    }
    final parentIds = <String>[];
    for (final parent in parents) {
      if (parent is! String) {
        throw const FormatException("P2P revision parent 格式無效。");
      }
      parentIds.add(parent);
    }
    final clockJson = <String, Object?>{};
    for (final entry in clock.entries) {
      if (entry.key is! String) {
        throw const FormatException("P2P revision clock key 無效。");
      }
      clockJson[entry.key as String] = entry.value;
    }
    return P2pRevisionMetadata(
      revisionId: revisionId,
      projectUuid: projectUuid,
      parents: parentIds,
      clock: P2pVersionVector.fromJson(clockJson),
      authorDeviceId: authorDeviceId,
      createdAtEpochSeconds: createdAt,
      contentSha256: contentSha256,
      formatVersion: formatVersion,
    );
  }

  Map<String, Object?> get canonicalMetadata => <String, Object?>{
    "projectUuid": projectUuid,
    "parents": parents,
    "clock": clock.toJson(),
    "authorDeviceId": authorDeviceId,
    "createdAt": createdAtEpochSeconds,
    "contentSha256": contentSha256,
    "formatVersion": formatVersion,
  };

  String get canonicalPayload =>
      "MONOGATARI_P2P_REVISION/1|${jsonEncode(canonicalMetadata)}";

  Map<String, Object?> toJson() => <String, Object?>{
    "revisionId": revisionId,
    ...canonicalMetadata,
  };

  String get shortRevisionId => revisionId.substring(0, 12);

  static String _normalizeUuid(String value, String label) {
    final normalized = value.trim().toLowerCase();
    if (!P2pProjectStatus.isValidProjectUuid(normalized)) {
      throw FormatException("P2P revision $label 無效。");
    }
    return normalized;
  }

  static String _normalizeHash(String value, String label) {
    final normalized = value.trim().toLowerCase();
    if (!_sha256Pattern.hasMatch(normalized)) {
      throw FormatException("P2P revision $label 無效。");
    }
    return normalized;
  }

  static List<String> _normalizeParents(Iterable<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final normalized = _normalizeHash(value, "parent ID");
      if (!seen.add(normalized)) {
        throw const FormatException("P2P revision parents 不可重複。");
      }
      result.add(normalized);
    }
    result.sort();
    if (result.length > 16) {
      throw const FormatException("P2P revision parents 超過限制。");
    }
    return result;
  }

  static String _normalizeFormatVersion(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length > 32) {
      throw const FormatException("P2P revision format version 無效。");
    }
    return normalized;
  }
}

class P2pRevisionGraph {
  static const int maxRevisionCount = 4096;

  final String projectUuid;
  final Map<String, P2pRevisionMetadata> revisions;
  final Set<String> headIds;

  P2pRevisionGraph({
    required String projectUuid,
    required Map<String, P2pRevisionMetadata> revisions,
    required Set<String> headIds,
  }) : projectUuid = _normalizeProjectUuid(projectUuid),
       revisions = UnmodifiableMapView(Map.of(revisions)),
       headIds = UnmodifiableSetView(Set.of(headIds)) {
    if (this.revisions.length > maxRevisionCount) {
      throw const FormatException("P2P revision graph 超過 revision 數量限制。");
    }
    for (final entry in this.revisions.entries) {
      if (entry.key != entry.value.revisionId ||
          entry.value.projectUuid != this.projectUuid) {
        throw const FormatException("P2P revision graph revision 對應無效。");
      }
      for (final parent in entry.value.parents) {
        if (!this.revisions.containsKey(parent)) {
          throw const FormatException("P2P revision graph 缺少 parent。");
        }
      }
    }
    if (!this.headIds.every(this.revisions.containsKey)) {
      throw const FormatException("P2P revision graph head 不存在。");
    }
    if (this.revisions.isEmpty != this.headIds.isEmpty) {
      throw const FormatException("P2P revision graph heads 無效。");
    }
    _validateAcyclic(this.revisions);
  }

  P2pRevisionGraph.empty(String projectUuid)
    : this(projectUuid: projectUuid, revisions: const {}, headIds: const {});

  factory P2pRevisionGraph.fromJson(Map<String, Object?> json) {
    final projectUuid = json["projectUuid"];
    final revisions = json["revisions"];
    final heads = json["heads"];
    if (projectUuid is! String || revisions is! List || heads is! List) {
      throw const FormatException("P2P revision graph 欄位不完整。");
    }
    final revisionMap = <String, P2pRevisionMetadata>{};
    for (final value in revisions) {
      if (value is! Map) {
        throw const FormatException("P2P revision graph entry 無效。");
      }
      final mapped = <String, Object?>{};
      for (final entry in value.entries) {
        if (entry.key is! String) {
          throw const FormatException("P2P revision graph JSON key 無效。");
        }
        mapped[entry.key as String] = entry.value;
      }
      final revision = P2pRevisionMetadata.fromJson(mapped);
      if (revisionMap.containsKey(revision.revisionId)) {
        throw const FormatException("P2P revision graph 有重複 revision。");
      }
      revisionMap[revision.revisionId] = revision;
    }
    final headIds = <String>{};
    for (final value in heads) {
      if (value is! String || !headIds.add(value.toLowerCase())) {
        throw const FormatException("P2P revision graph head 無效或重複。");
      }
    }
    return P2pRevisionGraph(
      projectUuid: projectUuid,
      revisions: revisionMap,
      headIds: headIds,
    );
  }

  List<P2pRevisionMetadata> get heads {
    final result = headIds.map((id) => revisions[id]!).toList()
      ..sort((a, b) => a.revisionId.compareTo(b.revisionId));
    return List.unmodifiable(result);
  }

  P2pRevisionMetadata? get singleHead =>
      headIds.length == 1 ? revisions[headIds.single] : null;

  bool get hasConflict => headIds.length > 1;

  List<P2pRevisionMetadata> get topologicallySortedRevisions {
    final result = <P2pRevisionMetadata>[];
    final visited = <String>{};

    void visit(String revisionId) {
      if (!visited.add(revisionId)) return;
      final revision = revisions[revisionId]!;
      for (final parent in revision.parents) {
        visit(parent);
      }
      result.add(revision);
    }

    final sortedHeads = headIds.toList()..sort();
    for (final headId in sortedHeads) {
      visit(headId);
    }
    return List<P2pRevisionMetadata>.unmodifiable(result);
  }

  bool isAncestorOf(String ancestorId, String descendantId) {
    final normalizedAncestor = ancestorId.trim().toLowerCase();
    final normalizedDescendant = descendantId.trim().toLowerCase();
    if (!revisions.containsKey(normalizedAncestor) ||
        !revisions.containsKey(normalizedDescendant)) {
      return false;
    }
    final pending = <String>[normalizedDescendant];
    final visited = <String>{};
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      if (!visited.add(current)) continue;
      if (current == normalizedAncestor) return true;
      pending.addAll(revisions[current]!.parents);
    }
    return false;
  }

  Set<String> commonAncestorIds(P2pRevisionGraph other) {
    if (projectUuid != other.projectUuid) {
      throw const FormatException("不可比較不同 project 的 revision graph。");
    }
    final common = revisions.keys.toSet()..retainAll(other.revisions.keys);
    final maximal = <String>{...common};
    for (final candidate in common) {
      if (common.any(
        (otherId) =>
            otherId != candidate &&
            isAncestorOf(candidate, otherId) &&
            other.isAncestorOf(candidate, otherId),
      )) {
        maximal.remove(candidate);
      }
    }
    return UnmodifiableSetView(SplayTreeSet<String>.of(maximal));
  }

  P2pRevisionGraph mergedWith(P2pRevisionGraph other) {
    if (projectUuid != other.projectUuid) {
      throw const FormatException("不可合併不同 project 的 revision graph。");
    }
    final merged = <String, P2pRevisionMetadata>{...revisions};
    for (final entry in other.revisions.entries) {
      final existing = merged[entry.key];
      if (existing != null &&
          jsonEncode(existing.toJson()) != jsonEncode(entry.value.toJson())) {
        throw const FormatException("相同 revision ID 對應到不同 metadata。");
      }
      merged[entry.key] = entry.value;
    }
    final parentIds = <String>{
      for (final revision in merged.values) ...revision.parents,
    };
    final heads = merged.keys.toSet()..removeAll(parentIds);
    return P2pRevisionGraph(
      projectUuid: projectUuid,
      revisions: merged,
      headIds: heads,
    );
  }

  P2pRevisionGraph append(P2pRevisionMetadata revision) {
    if (revision.projectUuid != projectUuid) {
      throw const FormatException("不可將其他 project 的 revision 加入 graph。");
    }
    final existing = revisions[revision.revisionId];
    if (existing != null) {
      if (jsonEncode(existing.toJson()) != jsonEncode(revision.toJson())) {
        throw const FormatException("相同 revision ID 對應到不同 metadata。");
      }
      return this;
    }
    if (!revision.parents.every(revisions.containsKey)) {
      throw const FormatException("新增 revision 的 parent 尚未存在。");
    }
    final nextRevisions = <String, P2pRevisionMetadata>{
      ...revisions,
      revision.revisionId: revision,
    };
    final nextHeads = <String>{...headIds}
      ..removeAll(revision.parents)
      ..add(revision.revisionId);
    return P2pRevisionGraph(
      projectUuid: projectUuid,
      revisions: nextRevisions,
      headIds: nextHeads,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    "projectUuid": projectUuid,
    "revisions": revisions.values.map((value) => value.toJson()).toList()
      ..sort(
        (a, b) =>
            (a["revisionId"] as String).compareTo(b["revisionId"] as String),
      ),
    "heads": headIds.toList()..sort(),
  };

  static String _normalizeProjectUuid(String value) {
    final normalized = value.trim().toLowerCase();
    if (!P2pProjectStatus.isValidProjectUuid(normalized)) {
      throw const FormatException("P2P revision graph project UUID 無效。");
    }
    return normalized;
  }

  static void _validateAcyclic(Map<String, P2pRevisionMetadata> revisions) {
    final visiting = <String>{};
    final visited = <String>{};

    bool visit(String revisionId) {
      if (visited.contains(revisionId)) return true;
      if (!visiting.add(revisionId)) return false;
      for (final parent in revisions[revisionId]!.parents) {
        if (!visit(parent)) return false;
      }
      visiting.remove(revisionId);
      visited.add(revisionId);
      return true;
    }

    if (!revisions.keys.every(visit)) {
      throw const FormatException("P2P revision graph 不可包含 cycle。");
    }
  }
}

class P2pRevisionGraphPage {
  static const int maxRevisionsPerPage = 32;
  static const int maxEncodedLength = 32 * 1024;
  static final RegExp _sha256Pattern = RegExp(r"^[0-9a-f]{64}$");

  final String projectUuid;
  final String transferId;
  final int pageIndex;
  final int pageCount;
  final int totalRevisionCount;
  final List<P2pRevisionMetadata> revisions;
  final Set<String> headIds;

  P2pRevisionGraphPage({
    required String projectUuid,
    required String transferId,
    required this.pageIndex,
    required this.pageCount,
    required this.totalRevisionCount,
    required Iterable<P2pRevisionMetadata> revisions,
    required Iterable<String> headIds,
  }) : projectUuid = projectUuid.trim().toLowerCase(),
       transferId = transferId.trim().toLowerCase(),
       revisions = List<P2pRevisionMetadata>.unmodifiable(revisions),
       headIds = UnmodifiableSetView(SplayTreeSet<String>.of(headIds)) {
    if (!P2pProjectStatus.isValidProjectUuid(this.projectUuid) ||
        !_sha256Pattern.hasMatch(this.transferId) ||
        pageCount < 1 ||
        pageIndex < 0 ||
        pageIndex >= pageCount ||
        totalRevisionCount < 0 ||
        totalRevisionCount > P2pRevisionGraph.maxRevisionCount ||
        this.revisions.length > maxRevisionsPerPage ||
        this.revisions.any(
          (revision) => revision.projectUuid != this.projectUuid,
        ) ||
        this.headIds.length > P2pRevisionSummary.maxHeadCount) {
      throw const FormatException("P2P revision graph page 無效。");
    }
  }

  factory P2pRevisionGraphPage.fromJson(Map<String, Object?> json) {
    const expectedKeys = <String>{
      "projectUuid",
      "transferId",
      "pageIndex",
      "pageCount",
      "totalRevisionCount",
      "revisions",
      "headIds",
    };
    if (json.length != expectedKeys.length ||
        !json.keys.every(expectedKeys.contains)) {
      throw const FormatException("P2P revision graph page 欄位集合無效。");
    }
    final projectUuid = json["projectUuid"];
    final transferId = json["transferId"];
    final pageIndex = json["pageIndex"];
    final pageCount = json["pageCount"];
    final totalRevisionCount = json["totalRevisionCount"];
    final revisionsJson = json["revisions"];
    final headIdsJson = json["headIds"];
    if (projectUuid is! String ||
        transferId is! String ||
        pageIndex is! int ||
        pageCount is! int ||
        totalRevisionCount is! int ||
        revisionsJson is! List ||
        headIdsJson is! List) {
      throw const FormatException("P2P revision graph page 欄位不完整。");
    }
    final revisions = <P2pRevisionMetadata>[];
    for (final value in revisionsJson) {
      if (value is! Map) {
        throw const FormatException("P2P revision graph page revision 無效。");
      }
      revisions.add(P2pRevisionMetadata.fromJson(_stringMap(value)));
    }
    final headIds = <String>[];
    for (final value in headIdsJson) {
      if (value is! String) {
        throw const FormatException("P2P revision graph page head 無效。");
      }
      headIds.add(value.toLowerCase());
    }
    final page = P2pRevisionGraphPage(
      projectUuid: projectUuid,
      transferId: transferId,
      pageIndex: pageIndex,
      pageCount: pageCount,
      totalRevisionCount: totalRevisionCount,
      revisions: revisions,
      headIds: headIds,
    );
    if (jsonEncode(page.toJson()).length > maxEncodedLength) {
      throw const FormatException("P2P revision graph page 超過大小限制。");
    }
    return page;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    "projectUuid": projectUuid,
    "transferId": transferId,
    "pageIndex": pageIndex,
    "pageCount": pageCount,
    "totalRevisionCount": totalRevisionCount,
    "revisions": revisions.map((revision) => revision.toJson()).toList(),
    "headIds": headIds.toList(),
  };

  static Map<String, Object?> _stringMap(Map<dynamic, dynamic> source) {
    final result = <String, Object?>{};
    for (final entry in source.entries) {
      if (entry.key is! String) {
        throw const FormatException("P2P revision graph page key 無效。");
      }
      result[entry.key as String] = entry.value;
    }
    return result;
  }
}

class P2pRevisionGraphAssembler {
  final Map<int, P2pRevisionGraphPage> _pages = <int, P2pRevisionGraphPage>{};
  String? _projectUuid;
  String? _transferId;
  int? _pageCount;
  int? _totalRevisionCount;

  bool get isComplete => _pageCount != null && _pages.length == _pageCount;

  Set<int> get missingPageIndexes {
    final pageCount = _pageCount;
    if (pageCount == null) return const <int>{0};
    return UnmodifiableSetView(
      SplayTreeSet<int>.of(<int>{
        for (var index = 0; index < pageCount; index++)
          if (!_pages.containsKey(index)) index,
      }),
    );
  }

  void add(P2pRevisionGraphPage page) {
    _projectUuid ??= page.projectUuid;
    _transferId ??= page.transferId;
    _pageCount ??= page.pageCount;
    _totalRevisionCount ??= page.totalRevisionCount;
    if (_projectUuid != page.projectUuid ||
        _transferId != page.transferId ||
        _pageCount != page.pageCount ||
        _totalRevisionCount != page.totalRevisionCount) {
      throw const FormatException("P2P revision graph pages 不屬於同一 transfer。");
    }
    final existing = _pages[page.pageIndex];
    if (existing != null &&
        jsonEncode(existing.toJson()) != jsonEncode(page.toJson())) {
      throw const FormatException("P2P revision graph page 重送內容不一致。");
    }
    _pages[page.pageIndex] = page;
  }

  P2pRevisionGraph assemble() {
    if (!isComplete) throw StateError("P2P revision graph pages 尚未完整。");
    final orderedPages = _pages.values.toList()
      ..sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
    final revisions = <String, P2pRevisionMetadata>{};
    final headIds = <String>{};
    for (final page in orderedPages) {
      headIds.addAll(page.headIds);
      for (final revision in page.revisions) {
        if (revisions.containsKey(revision.revisionId)) {
          throw const FormatException("P2P revision graph page 有重複 revision。");
        }
        revisions[revision.revisionId] = revision;
      }
    }
    if (revisions.length != _totalRevisionCount) {
      throw const FormatException("P2P revision graph revision 數量不符。");
    }
    return P2pRevisionGraph(
      projectUuid: _projectUuid!,
      revisions: revisions,
      headIds: headIds,
    );
  }
}

class P2pRevisionSummary {
  static const int maxHeadCount = 16;

  final String projectUuid;
  final List<P2pRevisionMetadata> heads;

  P2pRevisionSummary({
    required String projectUuid,
    required Iterable<P2pRevisionMetadata> heads,
  }) : projectUuid = projectUuid.trim().toLowerCase(),
       heads = List.unmodifiable(
         heads.toList()..sort(
           (first, second) => first.revisionId.compareTo(second.revisionId),
         ),
       ) {
    if (!P2pProjectStatus.isValidProjectUuid(this.projectUuid) ||
        this.heads.length > maxHeadCount ||
        !this.heads.every((head) => head.projectUuid == this.projectUuid) ||
        this.heads.map((head) => head.revisionId).toSet().length !=
            this.heads.length) {
      throw const FormatException("P2P revision summary 無效。");
    }
  }

  factory P2pRevisionSummary.fromGraph(P2pRevisionGraph graph) =>
      P2pRevisionSummary(projectUuid: graph.projectUuid, heads: graph.heads);

  factory P2pRevisionSummary.fromJson(Map<String, Object?> json) {
    final projectUuid = json["projectUuid"];
    final heads = json["heads"];
    if (projectUuid is! String || heads is! List) {
      throw const FormatException("P2P revision summary 欄位不完整。");
    }
    if (heads.length > maxHeadCount) {
      throw const FormatException("P2P revision summary heads 超過限制。");
    }
    final metadata = <P2pRevisionMetadata>[];
    for (final value in heads) {
      if (value is! Map) {
        throw const FormatException("P2P revision summary head 無效。");
      }
      final headJson = <String, Object?>{};
      for (final entry in value.entries) {
        if (entry.key is! String) {
          throw const FormatException("P2P revision summary head key 無效。");
        }
        headJson[entry.key as String] = entry.value;
      }
      metadata.add(P2pRevisionMetadata.fromJson(headJson));
    }
    return P2pRevisionSummary(projectUuid: projectUuid, heads: metadata);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    "projectUuid": projectUuid,
    "heads": heads.map((head) => head.toJson()).toList(growable: false),
  };

  P2pRevisionSummaryRelation compare(P2pRevisionSummary remote) {
    if (projectUuid != remote.projectUuid) {
      throw const FormatException("不可比較不同 project 的 revision summary。");
    }
    final localIds = heads.map((head) => head.revisionId).toSet();
    final remoteIds = remote.heads.map((head) => head.revisionId).toSet();
    if (localIds.length == remoteIds.length &&
        localIds.containsAll(remoteIds)) {
      return P2pRevisionSummaryRelation.equal;
    }
    final localCoversRemote = _covers(heads, remote.heads);
    final remoteCoversLocal = _covers(remote.heads, heads);
    if (localCoversRemote && !remoteCoversLocal) {
      return P2pRevisionSummaryRelation.localAhead;
    }
    if (remoteCoversLocal && !localCoversRemote) {
      return P2pRevisionSummaryRelation.remoteAhead;
    }
    return P2pRevisionSummaryRelation.concurrent;
  }

  static bool _covers(
    List<P2pRevisionMetadata> candidates,
    List<P2pRevisionMetadata> covered,
  ) {
    if (covered.isEmpty) return true;
    if (candidates.isEmpty) return false;
    return covered.every(
      (target) => candidates.any((candidate) {
        final relation = candidate.clock.compare(target.clock);
        return relation == P2pVersionVectorRelation.equal ||
            relation == P2pVersionVectorRelation.dominates;
      }),
    );
  }
}
