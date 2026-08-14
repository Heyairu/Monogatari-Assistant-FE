import "dart:async";
import "dart:convert";

import "package:cryptography/cryptography.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../../domain/models/p2p_revision_models.dart";
import "../../domain/models/p2p_resolution_models.dart";
import "../../domain/models/p2p_snapshot_models.dart";
import "p2p_snapshot_content_store.dart";

abstract class P2pRevisionKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

class SharedPreferencesP2pRevisionKeyValueStore
    implements P2pRevisionKeyValueStore {
  const SharedPreferencesP2pRevisionKeyValueStore();

  @override
  Future<String?> read(String key) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(key);
  }

  @override
  Future<void> write(String key, String value) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(key, value)) {
      throw StateError("無法保存 P2P revision metadata。");
    }
  }
}

class P2pRevisionStore {
  static const String _storagePrefix = "p2p.revision_graph.v1.";
  static const String _corruptStoragePrefix = "p2p.revision_graph.corrupt.v1.";
  static const String _manifestStoragePrefix = "p2p.snapshot_manifest.v1.";
  static const String _resolutionAckStoragePrefix = "p2p.resolution_ack.v1.";

  final P2pRevisionKeyValueStore _storage;
  final P2pSnapshotContentStore _contentStore;
  final Sha256 _sha256;
  Future<void> _operationTail = Future<void>.value();

  P2pRevisionStore({
    P2pRevisionKeyValueStore? storage,
    P2pSnapshotContentStore? contentStore,
    Sha256? sha256,
  }) : _storage = storage ?? const SharedPreferencesP2pRevisionKeyValueStore(),
       _contentStore = contentStore ?? FileSystemP2pSnapshotContentStore(),
       _sha256 = sha256 ?? Sha256();

  Future<P2pRevisionGraph> loadGraph(String projectUuid) {
    return _serialize(() => _loadGraph(projectUuid));
  }

  Future<P2pResolutionAck?> loadResolutionAck(String projectUuid) {
    return _serialize(() async {
      final graph = await _loadGraph(projectUuid);
      final stored = await _storage.read(_resolutionAckKey(graph.projectUuid));
      if (stored == null) return null;
      final decoded = jsonDecode(stored);
      if (decoded is! Map) {
        throw const FormatException("已保存的 P2P resolution ACK 不是 JSON object。");
      }
      final mapped = <String, Object?>{};
      for (final entry in decoded.entries) {
        if (entry.key is! String) {
          throw const FormatException("已保存的 P2P resolution ACK key 無效。");
        }
        mapped[entry.key as String] = entry.value;
      }
      final ack = P2pResolutionAck.fromJson(mapped);
      final revision = graph.revisions[ack.resolutionRevisionId];
      if (revision == null || !ack.matchesRevision(revision)) {
        throw const FormatException("P2P resolution ACK 與 revision graph 不符。");
      }
      return ack;
    });
  }

  Future<void> saveResolutionAck(P2pResolutionAck ack) {
    return _serialize(() async {
      final graph = await _loadGraph(ack.projectUuid);
      final revision = graph.revisions[ack.resolutionRevisionId];
      if (revision == null || !ack.matchesRevision(revision)) {
        throw const FormatException("不得保存未對應雙 parent revision 的 ACK。");
      }
      await _storage.write(
        _resolutionAckKey(ack.projectUuid),
        jsonEncode(ack.toJson()),
      );
    });
  }

  Future<P2pRevisionGraph> recordPersistedSnapshot({
    required String projectUuid,
    required String authorDeviceId,
    required String xmlContent,
    required String formatVersion,
    String? preferredParentRevisionId,
    DateTime? now,
  }) {
    return _serialize(() async {
      final contentBytes = utf8.encode(xmlContent);
      if (contentBytes.isEmpty ||
          contentBytes.length > P2pSnapshotManifest.maxSnapshotBytes) {
        throw const FormatException(
          "P2P revision snapshot 必須介於 1 byte 與 64 MiB。",
        );
      }
      final graph = await _loadGraphForRecording(projectUuid);
      final contentHash = _hex((await _sha256.hash(contentBytes)).bytes);
      final normalizedFormatVersion = formatVersion.trim();
      final matchingHeads = graph.heads
          .where(
            (revision) =>
                revision.contentSha256 == contentHash &&
                revision.formatVersion == normalizedFormatVersion,
          )
          .toList(growable: false);
      final existing = matchingHeads.length == 1 ? matchingHeads.single : null;
      if (existing != null &&
          existing.contentSha256 == contentHash &&
          existing.formatVersion == normalizedFormatVersion) {
        final manifest = P2pSnapshotManifest(
          projectUuid: existing.projectUuid,
          revisionId: existing.revisionId,
          contentSha256: existing.contentSha256,
          contentLength: contentBytes.length,
          formatVersion: existing.formatVersion,
        );
        await _contentStore.writeSnapshot(manifest, contentBytes);
        await _writeManifest(manifest);
        return graph;
      }

      var parentIds = graph.headIds;
      if (graph.hasConflict) {
        final preferredParent = preferredParentRevisionId?.trim().toLowerCase();
        if (preferredParent == null ||
            !graph.headIds.contains(preferredParent)) {
          throw StateError("目前 revision graph 有多個 heads，且無法識別本機工作分支；請先完成衝突合併。");
        }
        // A normal save may advance only the known local working branch. It
        // must never use every concurrent head as parents, because that would
        // silently manufacture a resolve revision without field resolution.
        parentIds = <String>{preferredParent};
      }

      var clock = P2pVersionVector.empty();
      for (final parentId in parentIds) {
        clock = clock.merge(graph.revisions[parentId]!.clock);
      }
      clock = clock.increment(authorDeviceId);
      final createdAt = (now ?? DateTime.now()).toUtc();
      final unsigned = P2pRevisionMetadata(
        revisionId: List<String>.filled(64, "0").join(),
        projectUuid: projectUuid,
        parents: parentIds,
        clock: clock,
        authorDeviceId: authorDeviceId,
        createdAtEpochSeconds: createdAt.millisecondsSinceEpoch ~/ 1000,
        contentSha256: contentHash,
        formatVersion: formatVersion,
      );
      final revisionId = _hex(
        (await _sha256.hash(utf8.encode(unsigned.canonicalPayload))).bytes,
      );
      final revision = P2pRevisionMetadata(
        revisionId: revisionId,
        projectUuid: unsigned.projectUuid,
        parents: unsigned.parents,
        clock: unsigned.clock,
        authorDeviceId: unsigned.authorDeviceId,
        createdAtEpochSeconds: unsigned.createdAtEpochSeconds,
        contentSha256: unsigned.contentSha256,
        formatVersion: unsigned.formatVersion,
      );
      final next = graph.append(revision);
      final manifest = P2pSnapshotManifest(
        projectUuid: revision.projectUuid,
        revisionId: revision.revisionId,
        contentSha256: revision.contentSha256,
        contentLength: contentBytes.length,
        formatVersion: revision.formatVersion,
      );
      await _contentStore.writeSnapshot(manifest, contentBytes);
      await _writeManifest(manifest);
      await _writeGraph(next);
      return next;
    });
  }

  Future<P2pSnapshotChunk?> loadSnapshotChunk({
    required String projectUuid,
    required String revisionId,
    required int chunkIndex,
  }) {
    return _serialize(() async {
      final manifest = await _loadSnapshotManifest(
        projectUuid: projectUuid,
        revisionId: revisionId,
      );
      if (manifest == null) return null;
      return _contentStore.readChunk(manifest, chunkIndex);
    });
  }

  Future<String?> loadSnapshotXml({
    required String projectUuid,
    required String revisionId,
  }) {
    return _serialize(() async {
      final manifest = await _loadSnapshotManifest(
        projectUuid: projectUuid,
        revisionId: revisionId,
      );
      if (manifest == null ||
          !await _contentStore.containsVerifiedSnapshot(manifest)) {
        return null;
      }
      final bytes = <int>[];
      for (var index = 0; index < manifest.chunkCount; index++) {
        final chunk = await _contentStore.readChunk(manifest, index);
        chunk.validateAgainst(manifest);
        bytes.addAll(chunk.bytes);
      }
      final digest = _hex((await _sha256.hash(bytes)).bytes);
      if (bytes.length != manifest.contentLength ||
          digest != manifest.contentSha256) {
        throw const FormatException("已保存的 snapshot 內容驗證失敗。");
      }
      return utf8.decode(bytes, allowMalformed: false);
    });
  }

  Future<P2pSnapshotManifest?> loadSnapshotManifest({
    required String projectUuid,
    required String revisionId,
  }) {
    return _serialize(
      () => _loadSnapshotManifest(
        projectUuid: projectUuid,
        revisionId: revisionId,
      ),
    );
  }

  Future<void> installVerifiedGraph(P2pRevisionGraph graph) {
    return _serialize(() => _writeGraph(graph));
  }

  Future<P2pRevisionGraph> mergeVerifiedRemoteGraph(
    P2pRevisionGraph remoteGraph,
  ) {
    return _serialize(() async {
      await _verifyRevisionIds(remoteGraph);
      final localGraph = await _loadGraph(remoteGraph.projectUuid);
      final merged = localGraph.mergedWith(remoteGraph);
      await _verifyRevisionIds(merged);
      await _writeGraph(merged);
      return merged;
    });
  }

  Future<void> verifyRemoteGraphTransfer({
    required P2pRevisionGraph graph,
    required String transferId,
  }) {
    return _serialize(() async {
      await _verifyRevisionIds(graph);
      final expected = _hex(
        (await _sha256.hash(utf8.encode(jsonEncode(graph.toJson())))).bytes,
      );
      if (expected != transferId.trim().toLowerCase()) {
        throw const FormatException("P2P revision graph transfer digest 不符。");
      }
    });
  }

  Future<void> installVerifiedRemoteSnapshot({
    required P2pRevisionGraph remoteGraph,
    required P2pSnapshotManifest manifest,
    required String xmlContent,
  }) {
    return _serialize(() async {
      await _verifyRevisionIds(remoteGraph);
      final revision = remoteGraph.revisions[manifest.revisionId];
      final bytes = utf8.encode(xmlContent);
      final contentHash = _hex((await _sha256.hash(bytes)).bytes);
      if (revision == null ||
          manifest.projectUuid != remoteGraph.projectUuid ||
          !manifest.matchesRevision(
            revisionProjectUuid: revision.projectUuid,
            revisionId: revision.revisionId,
            revisionContentSha256: revision.contentSha256,
            revisionFormatVersion: revision.formatVersion,
          ) ||
          manifest.contentLength != bytes.length ||
          manifest.contentSha256 != contentHash) {
        throw const FormatException(
          "遠端 snapshot、manifest 與 revision graph 不一致。",
        );
      }
      final localGraph = await _loadGraph(remoteGraph.projectUuid);
      final merged = localGraph.mergedWith(remoteGraph);
      await _contentStore.writeSnapshot(manifest, bytes);
      await _writeManifest(manifest);
      await _writeGraph(merged);
    });
  }

  Future<P2pRevisionGraph> recordResolvedSnapshot({
    required String projectUuid,
    required String authorDeviceId,
    required Iterable<String> parentRevisionIds,
    required String xmlContent,
    required String formatVersion,
    DateTime? now,
  }) {
    return _serialize(() async {
      final graph = await _loadGraph(projectUuid);
      final parents = parentRevisionIds
          .map((value) => value.trim().toLowerCase())
          .toSet();
      if (parents.length < 2 ||
          !graph.headIds.containsAll(parents) ||
          !parents.containsAll(graph.headIds)) {
        throw const FormatException(
          "Resolve revision 必須以目前所有 concurrent heads 為 parents。",
        );
      }
      final contentBytes = utf8.encode(xmlContent);
      if (contentBytes.isEmpty ||
          contentBytes.length > P2pSnapshotManifest.maxSnapshotBytes) {
        throw const FormatException("Resolve snapshot 必須介於 1 byte 與 64 MiB。");
      }
      var clock = P2pVersionVector.empty();
      for (final parentId in parents) {
        clock = clock.merge(graph.revisions[parentId]!.clock);
      }
      clock = clock.increment(authorDeviceId);
      final contentHash = _hex((await _sha256.hash(contentBytes)).bytes);
      final createdAt = (now ?? DateTime.now()).toUtc();
      final unsigned = P2pRevisionMetadata(
        revisionId: List<String>.filled(64, "0").join(),
        projectUuid: projectUuid,
        parents: parents,
        clock: clock,
        authorDeviceId: authorDeviceId,
        createdAtEpochSeconds: createdAt.millisecondsSinceEpoch ~/ 1000,
        contentSha256: contentHash,
        formatVersion: formatVersion,
      );
      final revisionId = _hex(
        (await _sha256.hash(utf8.encode(unsigned.canonicalPayload))).bytes,
      );
      final revision = P2pRevisionMetadata(
        revisionId: revisionId,
        projectUuid: unsigned.projectUuid,
        parents: unsigned.parents,
        clock: unsigned.clock,
        authorDeviceId: unsigned.authorDeviceId,
        createdAtEpochSeconds: unsigned.createdAtEpochSeconds,
        contentSha256: unsigned.contentSha256,
        formatVersion: unsigned.formatVersion,
      );
      final next = graph.append(revision);
      final manifest = P2pSnapshotManifest(
        projectUuid: revision.projectUuid,
        revisionId: revision.revisionId,
        contentSha256: revision.contentSha256,
        contentLength: contentBytes.length,
        formatVersion: revision.formatVersion,
      );
      await _contentStore.writeSnapshot(manifest, contentBytes);
      await _writeManifest(manifest);
      await _writeGraph(next);
      return next;
    });
  }

  Future<P2pRevisionGraph> _loadGraph(String projectUuid) async {
    final empty = P2pRevisionGraph.empty(projectUuid);
    final stored = await _storage.read(_storageKey(empty.projectUuid));
    if (stored == null) return empty;
    final decoded = jsonDecode(stored);
    if (decoded is! Map) {
      throw const FormatException("已保存的 P2P revision graph 不是 JSON object。");
    }
    final mapped = <String, Object?>{};
    for (final entry in decoded.entries) {
      if (entry.key is! String) {
        throw const FormatException("已保存的 P2P revision graph key 無效。");
      }
      mapped[entry.key as String] = entry.value;
    }
    final graph = P2pRevisionGraph.fromJson(mapped);
    if (graph.projectUuid != empty.projectUuid) {
      throw const FormatException("已保存的 P2P revision graph project UUID 不符。");
    }
    await _verifyRevisionIds(graph);
    return graph;
  }

  /// Loads the current graph for a new local revision.
  ///
  /// Development builds before the revision schema stabilized used the same
  /// preferences key. Those records cannot be trusted when their canonical
  /// digest or shape no longer validates, but permanently rejecting every
  /// later save also leaves the project unable to establish a fresh baseline.
  /// Preserve the invalid payload for diagnostics and rebuild only from the
  /// caller-provided, already-persisted XML. A valid graph (including a valid
  /// multi-head conflict) is never reset by this recovery path.
  Future<P2pRevisionGraph> _loadGraphForRecording(String projectUuid) async {
    final empty = P2pRevisionGraph.empty(projectUuid);
    try {
      return await _loadGraph(empty.projectUuid);
    } on FormatException catch (error) {
      final key = _storageKey(empty.projectUuid);
      final stored = await _storage.read(key);
      if (stored != null) {
        final recoveredAt = DateTime.now().toUtc().millisecondsSinceEpoch;
        try {
          await _storage.write(
            "$_corruptStoragePrefix${empty.projectUuid}.$recoveredAt",
            jsonEncode(<String, Object?>{
              "projectUuid": empty.projectUuid,
              "recoveredAt": recoveredAt,
              "reason": error.message,
              "rawGraph": stored,
            }),
          );
        } catch (_) {
          // A diagnostic backup must not keep a valid persisted project from
          // recovering when the platform preferences backend is constrained.
        }
      }
      return empty;
    }
  }

  Future<P2pSnapshotManifest?> _loadSnapshotManifest({
    required String projectUuid,
    required String revisionId,
  }) async {
    final graph = await _loadGraph(projectUuid);
    final normalizedRevisionId = revisionId.trim().toLowerCase();
    final revision = graph.revisions[normalizedRevisionId];
    if (revision == null) return null;
    final stored = await _storage.read(
      _manifestStorageKey(graph.projectUuid, normalizedRevisionId),
    );
    if (stored == null) return null;
    final decoded = jsonDecode(stored);
    if (decoded is! Map) {
      throw const FormatException("已保存的 P2P snapshot manifest 不是 JSON object。");
    }
    final mapped = <String, Object?>{};
    for (final entry in decoded.entries) {
      if (entry.key is! String) {
        throw const FormatException("已保存的 P2P snapshot manifest key 無效。");
      }
      mapped[entry.key as String] = entry.value;
    }
    final manifest = P2pSnapshotManifest.fromJson(mapped);
    if (!manifest.matchesRevision(
      revisionProjectUuid: revision.projectUuid,
      revisionId: revision.revisionId,
      revisionContentSha256: revision.contentSha256,
      revisionFormatVersion: revision.formatVersion,
    )) {
      throw const FormatException(
        "P2P snapshot manifest 與 revision metadata 不符。",
      );
    }
    return manifest;
  }

  Future<void> _writeGraph(P2pRevisionGraph graph) async {
    await _verifyRevisionIds(graph);
    await _storage.write(
      _storageKey(graph.projectUuid),
      jsonEncode(graph.toJson()),
    );
  }

  Future<void> _writeManifest(P2pSnapshotManifest manifest) {
    return _storage.write(
      _manifestStorageKey(manifest.projectUuid, manifest.revisionId),
      jsonEncode(manifest.toJson()),
    );
  }

  Future<void> _verifyRevisionIds(P2pRevisionGraph graph) async {
    for (final revision in graph.revisions.values) {
      final expected = _hex(
        (await _sha256.hash(utf8.encode(revision.canonicalPayload))).bytes,
      );
      if (expected != revision.revisionId) {
        throw const FormatException("P2P revision ID 與 canonical metadata 不符。");
      }
    }
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _operationTail = _operationTail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  String _storageKey(String projectUuid) => "$_storagePrefix$projectUuid";

  String _manifestStorageKey(String projectUuid, String revisionId) =>
      "$_manifestStoragePrefix$projectUuid.$revisionId";

  String _resolutionAckKey(String projectUuid) =>
      "$_resolutionAckStoragePrefix$projectUuid";

  String _hex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, "0")).join();
}
