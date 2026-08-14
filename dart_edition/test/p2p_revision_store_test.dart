import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/data/p2p/p2p_revision_store.dart";
import "package:monogatari_assistant/data/p2p/p2p_snapshot_content_store.dart";
import "package:monogatari_assistant/domain/models/p2p_resolution_models.dart";
import "package:monogatari_assistant/domain/models/p2p_snapshot_models.dart";

const String _projectId = "123e4567-e89b-12d3-a456-426614174000";
const String _deviceId = "223e4567-e89b-12d3-a456-426614174000";
const String _remoteDeviceId = "323e4567-e89b-12d3-a456-426614174000";

class _MemoryRevisionStorage implements P2pRevisionKeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _MemorySnapshotContentStore implements P2pSnapshotContentStore {
  final Map<String, List<int>> snapshots = <String, List<int>>{};

  @override
  Future<void> writeSnapshot(
    P2pSnapshotManifest manifest,
    List<int> bytes,
  ) async {
    snapshots[manifest.revisionId] = List<int>.unmodifiable(bytes);
  }

  @override
  Future<bool> containsVerifiedSnapshot(P2pSnapshotManifest manifest) async {
    return snapshots[manifest.revisionId]?.length == manifest.contentLength;
  }

  @override
  Future<P2pSnapshotChunk> readChunk(
    P2pSnapshotManifest manifest,
    int chunkIndex,
  ) async {
    final bytes = snapshots[manifest.revisionId];
    if (bytes == null) throw StateError("snapshot missing");
    final start = chunkIndex * manifest.chunkSize;
    final end = (start + manifest.chunkSize) < bytes.length
        ? start + manifest.chunkSize
        : bytes.length;
    return P2pSnapshotChunk(
      projectUuid: manifest.projectUuid,
      revisionId: manifest.revisionId,
      chunkIndex: chunkIndex,
      chunkCount: manifest.chunkCount,
      bytes: bytes.sublist(start, end),
    );
  }
}

class _FailingSnapshotContentStore extends _MemorySnapshotContentStore {
  @override
  Future<void> writeSnapshot(P2pSnapshotManifest manifest, List<int> bytes) {
    return Future<void>.error(StateError("snapshot storage unavailable"));
  }
}

P2pRevisionStore _store(
  P2pRevisionKeyValueStore storage, {
  P2pSnapshotContentStore? contentStore,
}) {
  return P2pRevisionStore(
    storage: storage,
    contentStore: contentStore ?? _MemorySnapshotContentStore(),
  );
}

void main() {
  test("revision store persists an immutable linear history", () async {
    final storage = _MemoryRevisionStorage();
    final contentStore = _MemorySnapshotContentStore();
    final store = _store(storage, contentStore: contentStore);
    final first = await store.recordPersistedSnapshot(
      projectUuid: _projectId,
      authorDeviceId: _deviceId,
      xmlContent: "<Project UUID=\"$_projectId\" />",
      formatVersion: "1.0",
      now: DateTime.utc(2026, 8, 10, 12),
    );
    final firstHead = first.singleHead!;
    expect(firstHead.parents, isEmpty);
    expect(firstHead.clock.counterFor(_deviceId), 1);

    final second = await store.recordPersistedSnapshot(
      projectUuid: _projectId,
      authorDeviceId: _deviceId,
      xmlContent: "<Project UUID=\"$_projectId\"><Title>A</Title></Project>",
      formatVersion: "1.0",
      now: DateTime.utc(2026, 8, 10, 12, 1),
    );
    expect(second.revisions, hasLength(2));
    expect(second.singleHead!.parents, <String>[firstHead.revisionId]);
    expect(second.singleHead!.clock.counterFor(_deviceId), 2);

    final reloaded = await _store(
      storage,
      contentStore: contentStore,
    ).loadGraph(_projectId);
    expect(reloaded.singleHead!.revisionId, second.singleHead!.revisionId);
    final manifest = await store.loadSnapshotManifest(
      projectUuid: _projectId,
      revisionId: second.singleHead!.revisionId,
    );
    expect(manifest, isNotNull);
    expect(manifest?.contentSha256, second.singleHead?.contentSha256);
    expect(
      manifest?.contentLength,
      utf8
          .encode("<Project UUID=\"$_projectId\"><Title>A</Title></Project>")
          .length,
    );
    final chunk = await store.loadSnapshotChunk(
      projectUuid: _projectId,
      revisionId: second.singleHead!.revisionId,
      chunkIndex: 0,
    );
    expect(utf8.decode(chunk!.bytes), contains("<Title>A</Title>"));
  });

  test("saving identical XML does not create a duplicate revision", () async {
    final store = _store(_MemoryRevisionStorage());
    final first = await store.recordPersistedSnapshot(
      projectUuid: _projectId,
      authorDeviceId: _deviceId,
      xmlContent: "<Project />",
      formatVersion: "1.0",
    );
    final repeated = await store.recordPersistedSnapshot(
      projectUuid: _projectId,
      authorDeviceId: _deviceId,
      xmlContent: "<Project />",
      formatVersion: "1.0",
    );

    expect(repeated.revisions, hasLength(1));
    expect(repeated.singleHead!.revisionId, first.singleHead!.revisionId);
  });

  test("tampered persisted metadata is rejected on load", () async {
    final storage = _MemoryRevisionStorage();
    final contentStore = _MemorySnapshotContentStore();
    final store = _store(storage, contentStore: contentStore);
    await store.recordPersistedSnapshot(
      projectUuid: _projectId,
      authorDeviceId: _deviceId,
      xmlContent: "<Project />",
      formatVersion: "1.0",
    );
    final key = storage.values.keys.singleWhere(
      (value) => value.contains("revision_graph"),
    );
    final json = jsonDecode(storage.values[key]!) as Map<String, dynamic>;
    final revisions = json["revisions"] as List<dynamic>;
    (revisions.single as Map<String, dynamic>)["contentSha256"] =
        List<String>.filled(64, "f").join();
    storage.values[key] = jsonEncode(json);

    expect(
      () => _store(storage, contentStore: contentStore).loadGraph(_projectId),
      throwsFormatException,
    );
  });

  test(
    "a persisted save quarantines invalid legacy metadata and rebuilds a baseline",
    () async {
      final storage = _MemoryRevisionStorage();
      final contentStore = _MemorySnapshotContentStore();
      final store = _store(storage, contentStore: contentStore);
      await store.recordPersistedSnapshot(
        projectUuid: _projectId,
        authorDeviceId: _deviceId,
        xmlContent: "<Project />",
        formatVersion: "1.0",
      );
      final graphKey = storage.values.keys.singleWhere(
        (value) => value.contains("revision_graph.v1"),
      );
      final graphJson =
          jsonDecode(storage.values[graphKey]!) as Map<String, dynamic>;
      final revisions = graphJson["revisions"] as List<dynamic>;
      (revisions.single as Map<String, dynamic>)["contentSha256"] =
          List<String>.filled(64, "f").join();
      storage.values[graphKey] = jsonEncode(graphJson);

      const recoveredXml = "<Project><Title>Recovered</Title></Project>";
      final recovered = await store.recordPersistedSnapshot(
        projectUuid: _projectId,
        authorDeviceId: _deviceId,
        xmlContent: recoveredXml,
        formatVersion: "1.0",
      );

      expect(recovered.revisions, hasLength(1));
      expect(recovered.singleHead?.parents, isEmpty);
      expect(
        await store.loadSnapshotXml(
          projectUuid: _projectId,
          revisionId: recovered.singleHead!.revisionId,
        ),
        recoveredXml,
      );
      final quarantineKey = storage.values.keys.singleWhere(
        (value) => value.contains("revision_graph.corrupt.v1"),
      );
      final quarantine =
          jsonDecode(storage.values[quarantineKey]!) as Map<String, dynamic>;
      expect(quarantine["projectUuid"], _projectId);
      expect(quarantine["rawGraph"], isNotEmpty);
    },
  );

  test("tampered snapshot manifest is rejected against its revision", () async {
    final storage = _MemoryRevisionStorage();
    final store = _store(storage);
    final graph = await store.recordPersistedSnapshot(
      projectUuid: _projectId,
      authorDeviceId: _deviceId,
      xmlContent: "<Project />",
      formatVersion: "1.0",
    );
    final manifestKey = storage.values.keys.singleWhere(
      (value) => value.contains("snapshot_manifest"),
    );
    final manifestJson =
        jsonDecode(storage.values[manifestKey]!) as Map<String, dynamic>;
    manifestJson["contentSha256"] = List<String>.filled(64, "f").join();
    storage.values[manifestKey] = jsonEncode(manifestJson);

    expect(
      () => store.loadSnapshotManifest(
        projectUuid: _projectId,
        revisionId: graph.singleHead!.revisionId,
      ),
      throwsFormatException,
    );
  });

  test(
    "content failure does not commit manifest or revision metadata",
    () async {
      final storage = _MemoryRevisionStorage();
      final store = _store(
        storage,
        contentStore: _FailingSnapshotContentStore(),
      );

      await expectLater(
        store.recordPersistedSnapshot(
          projectUuid: _projectId,
          authorDeviceId: _deviceId,
          xmlContent: "<Project />",
          formatVersion: "1.0",
        ),
        throwsStateError,
      );

      expect(storage.values, isEmpty);
      expect((await store.loadGraph(_projectId)).revisions, isEmpty);
    },
  );

  test(
    "remote DAG history resolves with two parents and persists ACK",
    () async {
      final baseStore = _store(_MemoryRevisionStorage());
      final baseGraph = await baseStore.recordPersistedSnapshot(
        projectUuid: _projectId,
        authorDeviceId: _deviceId,
        xmlContent: '<Project UUID="$_projectId"><Title>Base</Title></Project>',
        formatVersion: "1.0",
        now: DateTime.utc(2026, 8, 12, 1),
      );

      final localStorage = _MemoryRevisionStorage();
      final localContent = _MemorySnapshotContentStore();
      final localStore = _store(localStorage, contentStore: localContent);
      await localStore.installVerifiedGraph(baseGraph);
      final localGraph = await localStore.recordPersistedSnapshot(
        projectUuid: _projectId,
        authorDeviceId: _deviceId,
        xmlContent:
            '<Project UUID="$_projectId"><Title>Local</Title></Project>',
        formatVersion: "1.0",
        now: DateTime.utc(2026, 8, 12, 2),
      );

      final remoteStorage = _MemoryRevisionStorage();
      final remoteContent = _MemorySnapshotContentStore();
      final remoteStore = _store(remoteStorage, contentStore: remoteContent);
      await remoteStore.installVerifiedGraph(baseGraph);
      const remoteXml =
          '<Project UUID="$_projectId"><Title>Remote</Title></Project>';
      final remoteGraph = await remoteStore.recordPersistedSnapshot(
        projectUuid: _projectId,
        authorDeviceId: _remoteDeviceId,
        xmlContent: remoteXml,
        formatVersion: "1.0",
        now: DateTime.utc(2026, 8, 12, 3),
      );
      expect(localGraph.commonAncestorIds(remoteGraph), <String>{
        baseGraph.singleHead!.revisionId,
      });
      final remoteManifest = await remoteStore.loadSnapshotManifest(
        projectUuid: _projectId,
        revisionId: remoteGraph.singleHead!.revisionId,
      );
      await localStore.installVerifiedRemoteSnapshot(
        remoteGraph: remoteGraph,
        manifest: remoteManifest!,
        xmlContent: remoteXml,
      );
      final concurrent = await localStore.loadGraph(_projectId);
      expect(concurrent.headIds, hasLength(2));

      const savedLocalXml =
          '<Project UUID="$_projectId"><Title>Local saved</Title></Project>';
      final advancedLocal = await localStore.recordPersistedSnapshot(
        projectUuid: _projectId,
        authorDeviceId: _deviceId,
        xmlContent: savedLocalXml,
        formatVersion: "1.0",
        preferredParentRevisionId: localGraph.singleHead!.revisionId,
        now: DateTime.utc(2026, 8, 12, 3, 30),
      );
      expect(advancedLocal.headIds, hasLength(2));
      final advancedLocalHead = advancedLocal.heads.singleWhere(
        (revision) =>
            revision.parents.length == 1 &&
            revision.parents.single == localGraph.singleHead!.revisionId,
      );
      expect(advancedLocalHead.parents, <String>[
        localGraph.singleHead!.revisionId,
      ]);
      expect(
        advancedLocal.headIds,
        contains(remoteGraph.singleHead!.revisionId),
      );

      final repeatedSave = await localStore.recordPersistedSnapshot(
        projectUuid: _projectId,
        authorDeviceId: _deviceId,
        xmlContent: savedLocalXml,
        formatVersion: "1.0",
      );
      expect(repeatedSave.headIds, advancedLocal.headIds);

      const resolvedXml =
          '<Project UUID="$_projectId"><Title>Resolved</Title></Project>';
      final resolved = await localStore.recordResolvedSnapshot(
        projectUuid: _projectId,
        authorDeviceId: _deviceId,
        parentRevisionIds: advancedLocal.headIds,
        xmlContent: resolvedXml,
        formatVersion: "1.0",
        now: DateTime.utc(2026, 8, 12, 4),
      );
      expect(resolved.singleHead!.parents.toSet(), advancedLocal.headIds);
      expect(resolved.headIds, hasLength(1));
      expect(
        await localStore.loadSnapshotXml(
          projectUuid: _projectId,
          revisionId: resolved.singleHead!.revisionId,
        ),
        resolvedXml,
      );

      final ack = P2pResolutionAck(
        projectUuid: _projectId,
        resolutionRevisionId: resolved.singleHead!.revisionId,
        contentSha256: resolved.singleHead!.contentSha256,
        acceptedByDeviceId: _remoteDeviceId,
        acceptedAtEpochSeconds: 1,
      );
      await localStore.saveResolutionAck(ack);
      final reloadedAck = await _store(
        localStorage,
        contentStore: localContent,
      ).loadResolutionAck(_projectId);
      expect(reloadedAck?.resolutionRevisionId, ack.resolutionRevisionId);
      expect(reloadedAck?.acceptedByDeviceId, _remoteDeviceId);
    },
  );
}
