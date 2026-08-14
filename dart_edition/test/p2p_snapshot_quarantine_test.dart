import "dart:async";
import "dart:convert";
import "dart:io";

import "package:cryptography/cryptography.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/data/p2p/p2p_snapshot_quarantine.dart";
import "package:monogatari_assistant/domain/models/p2p_snapshot_models.dart";

void main() {
  const projectUuid = "123e4567-e89b-12d3-a456-426614174000";
  const otherProjectUuid = "123e4567-e89b-12d3-a456-426614174001";
  final revisionId = List<String>.filled(64, "a").join();

  test(
    "quarantine accepts out-of-order chunks and verifies the snapshot",
    () async {
      final payload = utf8.encode(
        '<Project UUID="$projectUuid"><ver>1.0</ver><Data>'
        '${List<String>.filled(25000, "x").join()}'
        "</Data></Project>",
      );
      final manifest = await _manifestFor(
        payload,
        projectUuid: projectUuid,
        revisionId: revisionId,
      );
      final storage = _MemoryQuarantineStorage();
      final session = await P2pSnapshotQuarantineSession.open(
        manifest: manifest,
        storage: storage,
      );
      final chunks = _chunksFor(manifest, payload);

      await session.addChunk(chunks.last);
      await session.addChunk(chunks.first);
      await session.addChunk(chunks.first);
      final verified = await session.finalize();

      expect(verified.xmlContent, utf8.decode(payload));
      expect(session.status, P2pSnapshotQuarantineStatus.verified);
      expect(session.progress, 1);
      await session.cancel();
      expect(storage.transferCount, 0);
    },
  );

  test("missing chunks can be resumed before final verification", () async {
    final payload = utf8.encode(
      '<Project UUID="$projectUuid"><ver>1.0</ver><Data>'
      '${List<String>.filled(25000, "y").join()}'
      "</Data></Project>",
    );
    final manifest = await _manifestFor(
      payload,
      projectUuid: projectUuid,
      revisionId: revisionId,
    );
    final session = await P2pSnapshotQuarantineSession.open(
      manifest: manifest,
      storage: _MemoryQuarantineStorage(),
    );
    final chunks = _chunksFor(manifest, payload);

    await session.addChunk(chunks.first);
    await expectLater(session.finalize(), throwsStateError);
    expect(session.status, P2pSnapshotQuarantineStatus.receiving);
    await session.addChunk(chunks.last);
    expect((await session.finalize()).xmlContent, utf8.decode(payload));
  });

  test(
    "conflicting duplicate chunk fails closed and clears quarantine",
    () async {
      final payload = utf8.encode(
        '<Project UUID="$projectUuid"><ver>1.0</ver></Project>',
      );
      final manifest = await _manifestFor(
        payload,
        projectUuid: projectUuid,
        revisionId: revisionId,
      );
      final storage = _MemoryQuarantineStorage();
      final session = await P2pSnapshotQuarantineSession.open(
        manifest: manifest,
        storage: storage,
      );
      final chunk = _chunksFor(manifest, payload).single;
      final changedBytes = List<int>.of(chunk.bytes);
      changedBytes[0] ^= 1;

      await session.addChunk(chunk);
      await expectLater(
        session.addChunk(
          P2pSnapshotChunk(
            projectUuid: projectUuid,
            revisionId: revisionId,
            chunkIndex: 0,
            chunkCount: 1,
            bytes: changedBytes,
          ),
        ),
        throwsFormatException,
      );
      expect(session.status, P2pSnapshotQuarantineStatus.failed);
      expect(storage.transferCount, 0);
    },
  );

  test("hash mismatch fails closed and clears quarantine", () async {
    final payload = utf8.encode(
      '<Project UUID="$projectUuid"><ver>1.0</ver></Project>',
    );
    final manifest = P2pSnapshotManifest(
      projectUuid: projectUuid,
      revisionId: revisionId,
      contentSha256: List<String>.filled(64, "f").join(),
      contentLength: payload.length,
      formatVersion: "1.0",
    );
    final storage = _MemoryQuarantineStorage();
    final session = await P2pSnapshotQuarantineSession.open(
      manifest: manifest,
      storage: storage,
    );

    await session.addChunk(_chunksFor(manifest, payload).single);
    await expectLater(session.finalize(), throwsFormatException);
    expect(session.status, P2pSnapshotQuarantineStatus.failed);
    expect(storage.transferCount, 0);
  });

  test("verified bytes must contain the manifest project and version", () async {
    for (final xml in <String>[
      '<Project UUID="$otherProjectUuid"><ver>1.0</ver></Project>',
      '<Project UUID="$projectUuid"><ver>2.0</ver></Project>',
      '<!DOCTYPE Project><Project UUID="$projectUuid"><ver>1.0</ver></Project>',
      '<p:Project xmlns:p="urn:fake" UUID="$projectUuid"><ver>1.0</ver></p:Project>',
      '<Project UUID="$projectUuid"><ver><x>1.0</x></ver></Project>',
    ]) {
      final payload = utf8.encode(xml);
      final manifest = await _manifestFor(
        payload,
        projectUuid: projectUuid,
        revisionId: revisionId,
      );
      final session = await P2pSnapshotQuarantineSession.open(
        manifest: manifest,
        storage: _MemoryQuarantineStorage(),
      );

      await session.addChunk(_chunksFor(manifest, payload).single);
      await expectLater(session.finalize(), throwsFormatException);
      expect(session.status, P2pSnapshotQuarantineStatus.failed);
    }
  });

  test("malformed UTF-8 is rejected and cancellation is terminal", () async {
    final prefix = utf8.encode('<Project UUID="$projectUuid"><ver>1.0</ver>');
    final payload = <int>[...prefix, 0xff, ...utf8.encode("</Project>")];
    final manifest = await _manifestFor(
      payload,
      projectUuid: projectUuid,
      revisionId: revisionId,
    );
    final storage = _MemoryQuarantineStorage();
    final session = await P2pSnapshotQuarantineSession.open(
      manifest: manifest,
      storage: storage,
    );

    await session.cancel();
    expect(session.status, P2pSnapshotQuarantineStatus.cancelled);
    expect(storage.transferCount, 0);
    await expectLater(
      session.addChunk(_chunksFor(manifest, payload).single),
      throwsStateError,
    );

    final malformedSession = await P2pSnapshotQuarantineSession.open(
      manifest: manifest,
      storage: storage,
    );
    await malformedSession.addChunk(_chunksFor(manifest, payload).single);
    await expectLater(malformedSession.finalize(), throwsFormatException);
    expect(malformedSession.status, P2pSnapshotQuarantineStatus.failed);
    expect(storage.transferCount, 0);
  });

  test("file storage resumes committed chunks after an App restart", () async {
    final temporaryRoot = await Directory.systemTemp.createTemp(
      "monogatari-p2p-quarantine-test-",
    );
    addTearDown(() async {
      if (await temporaryRoot.exists()) {
        await temporaryRoot.delete(recursive: true);
      }
    });
    final firstStorage = FileSystemP2pSnapshotQuarantineStorage(
      baseDirectory: () async => temporaryRoot,
    );
    final payload = utf8.encode(
      '<Project UUID="$projectUuid"><ver>1.0</ver><Data>'
      '${List<String>.filled(25000, "z").join()}'
      "</Data></Project>",
    );
    final manifest = await _manifestFor(
      payload,
      projectUuid: projectUuid,
      revisionId: revisionId,
    );
    final session = await P2pSnapshotQuarantineSession.open(
      manifest: manifest,
      storage: firstStorage,
    );
    final chunks = _chunksFor(manifest, payload);
    await session.addChunk(chunks.first);

    await firstStorage.dispose();

    final quarantineRoot = Directory(
      "${temporaryRoot.path}${Platform.pathSeparator}"
      "monogatari_p2p_quarantine",
    );
    expect(await quarantineRoot.list().isEmpty, isFalse);

    final restartedStorage = FileSystemP2pSnapshotQuarantineStorage(
      baseDirectory: () async => temporaryRoot,
    );
    final resumed = await P2pSnapshotQuarantineSession.open(
      manifest: manifest,
      storage: restartedStorage,
    );
    expect(resumed.receivedChunkIndexes, <int>{0});
    await resumed.addChunk(chunks.last);
    expect((await resumed.finalize()).xmlContent, utf8.decode(payload));
    expect(await quarantineRoot.list().isEmpty, isTrue);
    await restartedStorage.dispose();
  });

  test("corrupted persisted chunk is discarded instead of resumed", () async {
    final temporaryRoot = await Directory.systemTemp.createTemp(
      "monogatari-p2p-quarantine-corruption-test-",
    );
    addTearDown(() async {
      if (await temporaryRoot.exists()) {
        await temporaryRoot.delete(recursive: true);
      }
    });
    final payload = utf8.encode(
      '<Project UUID="$projectUuid"><ver>1.0</ver></Project>',
    );
    final manifest = await _manifestFor(
      payload,
      projectUuid: projectUuid,
      revisionId: revisionId,
    );
    final firstStorage = FileSystemP2pSnapshotQuarantineStorage(
      baseDirectory: () async => temporaryRoot,
    );
    final firstSession = await P2pSnapshotQuarantineSession.open(
      manifest: manifest,
      storage: firstStorage,
    );
    await firstSession.addChunk(_chunksFor(manifest, payload).single);
    await firstStorage.dispose();

    final quarantineRoot = Directory(
      "${temporaryRoot.path}${Platform.pathSeparator}"
      "monogatari_p2p_quarantine",
    );
    final transferDirectory = await quarantineRoot
        .list()
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .single;
    final chunkFile = File(
      "${transferDirectory.path}${Platform.pathSeparator}0.chunk",
    );
    final corrupted = await chunkFile.readAsBytes();
    corrupted[0] ^= 1;
    await chunkFile.writeAsBytes(corrupted, flush: true);

    final restartedStorage = FileSystemP2pSnapshotQuarantineStorage(
      baseDirectory: () async => temporaryRoot,
    );
    final restartedSession = await P2pSnapshotQuarantineSession.open(
      manifest: manifest,
      storage: restartedStorage,
    );
    expect(restartedSession.receivedChunkIndexes, isEmpty);
    await restartedSession.cancel();
    expect(await quarantineRoot.list().isEmpty, isTrue);
  });

  test("expired persisted transfer is discarded before resume", () async {
    final temporaryRoot = await Directory.systemTemp.createTemp(
      "monogatari-p2p-quarantine-expiry-test-",
    );
    addTearDown(() async {
      if (await temporaryRoot.exists()) {
        await temporaryRoot.delete(recursive: true);
      }
    });
    var currentTime = DateTime.utc(2026, 1, 1);
    final payload = utf8.encode(
      '<Project UUID="$projectUuid"><ver>1.0</ver></Project>',
    );
    final manifest = await _manifestFor(
      payload,
      projectUuid: projectUuid,
      revisionId: revisionId,
    );
    final firstStorage = FileSystemP2pSnapshotQuarantineStorage(
      baseDirectory: () async => temporaryRoot,
      retention: const Duration(days: 7),
      now: () => currentTime,
    );
    final firstSession = await P2pSnapshotQuarantineSession.open(
      manifest: manifest,
      storage: firstStorage,
    );
    await firstSession.addChunk(_chunksFor(manifest, payload).single);
    await firstStorage.dispose();

    currentTime = currentTime.add(const Duration(days: 8));
    final restartedStorage = FileSystemP2pSnapshotQuarantineStorage(
      baseDirectory: () async => temporaryRoot,
      retention: const Duration(days: 7),
      now: () => currentTime,
    );
    final restartedSession = await P2pSnapshotQuarantineSession.open(
      manifest: manifest,
      storage: restartedStorage,
    );

    expect(restartedSession.receivedChunkIndexes, isEmpty);
    await restartedSession.cancel();
  });

  test("legacy v1 quarantine metadata remains resumable", () async {
    final temporaryRoot = await Directory.systemTemp.createTemp(
      "monogatari-p2p-quarantine-v1-test-",
    );
    addTearDown(() async {
      if (await temporaryRoot.exists()) {
        await temporaryRoot.delete(recursive: true);
      }
    });
    final payload = utf8.encode(
      '<Project UUID="$projectUuid"><ver>1.0</ver></Project>',
    );
    final manifest = await _manifestFor(
      payload,
      projectUuid: projectUuid,
      revisionId: revisionId,
    );
    final firstStorage = FileSystemP2pSnapshotQuarantineStorage(
      baseDirectory: () async => temporaryRoot,
    );
    final firstSession = await P2pSnapshotQuarantineSession.open(
      manifest: manifest,
      storage: firstStorage,
    );
    await firstSession.addChunk(_chunksFor(manifest, payload).single);
    await firstStorage.dispose();

    final quarantineRoot = Directory(
      "${temporaryRoot.path}${Platform.pathSeparator}"
      "monogatari_p2p_quarantine",
    );
    final transferDirectory = await quarantineRoot
        .list()
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .single;
    for (final fileName in <String>["manifest.json", "0.received"]) {
      final file = File(
        "${transferDirectory.path}${Platform.pathSeparator}$fileName",
      );
      final metadata = Map<String, Object?>.from(
        jsonDecode(await file.readAsString()) as Map,
      )..["version"] = 1;
      metadata.remove(
        fileName == "manifest.json" ? "createdAtEpochMs" : "committedAtEpochMs",
      );
      await file.writeAsString(jsonEncode(metadata), flush: true);
    }

    final restartedStorage = FileSystemP2pSnapshotQuarantineStorage(
      baseDirectory: () async => temporaryRoot,
    );
    final resumed = await P2pSnapshotQuarantineSession.open(
      manifest: manifest,
      storage: restartedStorage,
    );
    expect(resumed.receivedChunkIndexes, <int>{0});
    await resumed.cancel();
  });

  test("retained transfer count evicts the least recently active", () async {
    final temporaryRoot = await Directory.systemTemp.createTemp(
      "monogatari-p2p-quarantine-count-test-",
    );
    addTearDown(() async {
      if (await temporaryRoot.exists()) {
        await temporaryRoot.delete(recursive: true);
      }
    });
    var currentTime = DateTime.utc(2026, 1, 1);
    final manifests = <P2pSnapshotManifest>[];
    final chunks = <P2pSnapshotChunk>[];
    for (final marker in <String>["a", "b", "c"]) {
      final payload = utf8.encode(
        '<Project UUID="$projectUuid"><ver>1.0</ver><Data>$marker</Data></Project>',
      );
      final manifest = await _manifestFor(
        payload,
        projectUuid: projectUuid,
        revisionId: List<String>.filled(64, marker).join(),
      );
      manifests.add(manifest);
      chunks.add(_chunksFor(manifest, payload).single);
    }

    for (var index = 0; index < manifests.length; index += 1) {
      final storage = FileSystemP2pSnapshotQuarantineStorage(
        baseDirectory: () async => temporaryRoot,
        maxRetainedTransfers: 2,
        now: () => currentTime,
      );
      final session = await P2pSnapshotQuarantineSession.open(
        manifest: manifests[index],
        storage: storage,
      );
      await session.addChunk(chunks[index]);
      await storage.dispose();
      currentTime = currentTime.add(const Duration(minutes: 1));
    }

    final quarantineRoot = Directory(
      "${temporaryRoot.path}${Platform.pathSeparator}"
      "monogatari_p2p_quarantine",
    );
    expect(
      await quarantineRoot.list().where((entity) => entity is Directory).length,
      2,
    );
    final reopenedStorage = FileSystemP2pSnapshotQuarantineStorage(
      baseDirectory: () async => temporaryRoot,
      maxRetainedTransfers: 2,
      now: () => currentTime,
    );
    final reopenedOldest = await P2pSnapshotQuarantineSession.open(
      manifest: manifests.first,
      storage: reopenedStorage,
    );
    expect(reopenedOldest.receivedChunkIndexes, isEmpty);
    await reopenedOldest.cancel();
  });

  test("retained byte capacity evicts older partial payloads", () async {
    final temporaryRoot = await Directory.systemTemp.createTemp(
      "monogatari-p2p-quarantine-byte-limit-test-",
    );
    addTearDown(() async {
      if (await temporaryRoot.exists()) {
        await temporaryRoot.delete(recursive: true);
      }
    });
    var currentTime = DateTime.utc(2026, 1, 1);
    final manifests = <P2pSnapshotManifest>[];
    final chunks = <P2pSnapshotChunk>[];
    for (final marker in <String>["d", "e", "f"]) {
      final payload = utf8.encode(
        '<Project UUID="$projectUuid"><ver>1.0</ver><Data>'
        '${List<String>.filled(9000, marker).join()}'
        "</Data></Project>",
      );
      final manifest = await _manifestFor(
        payload,
        projectUuid: projectUuid,
        revisionId: List<String>.filled(64, marker).join(),
      );
      manifests.add(manifest);
      chunks.add(_chunksFor(manifest, payload).single);
    }

    for (var index = 0; index < manifests.length; index += 1) {
      final storage = FileSystemP2pSnapshotQuarantineStorage(
        baseDirectory: () async => temporaryRoot,
        maxRetainedBytes: P2pSnapshotManifest.chunkSizeBytes,
        now: () => currentTime,
      );
      final session = await P2pSnapshotQuarantineSession.open(
        manifest: manifests[index],
        storage: storage,
      );
      if (index < 2) await session.addChunk(chunks[index]);
      await storage.dispose();
      currentTime = currentTime.add(const Duration(minutes: 1));
    }

    final reopenedStorage = FileSystemP2pSnapshotQuarantineStorage(
      baseDirectory: () async => temporaryRoot,
      maxRetainedBytes: P2pSnapshotManifest.chunkSizeBytes,
      now: () => currentTime,
    );
    final reopenedOldest = await P2pSnapshotQuarantineSession.open(
      manifest: manifests.first,
      storage: reopenedStorage,
    );
    expect(reopenedOldest.receivedChunkIndexes, isEmpty);
    await reopenedOldest.cancel();
  });

  test("manifest larger than quarantine capacity is rejected", () async {
    final temporaryRoot = await Directory.systemTemp.createTemp(
      "monogatari-p2p-quarantine-capacity-test-",
    );
    addTearDown(() async {
      if (await temporaryRoot.exists()) {
        await temporaryRoot.delete(recursive: true);
      }
    });
    final payload = utf8.encode(
      '<Project UUID="$projectUuid"><ver>1.0</ver><Data>'
      '${List<String>.filled(25000, "x").join()}'
      "</Data></Project>",
    );
    final manifest = await _manifestFor(
      payload,
      projectUuid: projectUuid,
      revisionId: revisionId,
    );
    final storage = FileSystemP2pSnapshotQuarantineStorage(
      baseDirectory: () async => temporaryRoot,
      maxRetainedBytes: P2pSnapshotManifest.chunkSizeBytes,
    );

    await expectLater(
      P2pSnapshotQuarantineSession.open(manifest: manifest, storage: storage),
      throwsA(isA<P2pSnapshotQuarantineCapacityException>()),
    );
  });
}

Future<P2pSnapshotManifest> _manifestFor(
  List<int> payload, {
  required String projectUuid,
  required String revisionId,
}) async {
  final digest = await Sha256().hash(payload);
  return P2pSnapshotManifest(
    projectUuid: projectUuid,
    revisionId: revisionId,
    contentSha256: _hex(digest.bytes),
    contentLength: payload.length,
    formatVersion: "1.0",
  );
}

List<P2pSnapshotChunk> _chunksFor(
  P2pSnapshotManifest manifest,
  List<int> payload,
) {
  return <P2pSnapshotChunk>[
    for (var index = 0; index < manifest.chunkCount; index++)
      P2pSnapshotChunk(
        projectUuid: manifest.projectUuid,
        revisionId: manifest.revisionId,
        chunkIndex: index,
        chunkCount: manifest.chunkCount,
        bytes: payload.sublist(
          index * manifest.chunkSize,
          ((index + 1) * manifest.chunkSize).clamp(0, payload.length),
        ),
      ),
  ];
}

String _hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, "0")).join();

class _MemoryQuarantineStorage implements P2pSnapshotQuarantineStorage {
  final Map<String, Map<int, List<int>>> _transfers =
      <String, Map<int, List<int>>>{};
  final Map<String, P2pSnapshotManifest> _manifests =
      <String, P2pSnapshotManifest>{};
  var _nextId = 0;

  int get transferCount => _transfers.length;

  @override
  Future<P2pStoredQuarantineTransfer> openTransfer(
    P2pSnapshotManifest manifest,
  ) async {
    for (final entry in _manifests.entries) {
      if (entry.value == manifest) {
        return P2pStoredQuarantineTransfer(
          transferId: entry.key,
          manifest: manifest,
          receivedChunkIndexes: _transfer(entry.key).keys.toSet(),
        );
      }
    }
    final id = "transfer-${_nextId++}";
    _transfers[id] = <int, List<int>>{};
    _manifests[id] = manifest;
    return P2pStoredQuarantineTransfer(
      transferId: id,
      manifest: manifest,
      receivedChunkIndexes: const <int>{},
    );
  }

  @override
  Future<void> writeChunk(
    String transferId,
    int chunkIndex,
    List<int> bytes,
  ) async {
    _transfer(transferId)[chunkIndex] = List<int>.of(bytes);
  }

  @override
  Future<List<int>> readChunk(String transferId, int chunkIndex) async {
    final bytes = _transfer(transferId)[chunkIndex];
    if (bytes == null) throw StateError("chunk missing");
    return List<int>.of(bytes);
  }

  @override
  Stream<List<int>> readChunksInOrder(
    String transferId,
    int chunkCount,
  ) async* {
    final transfer = _transfer(transferId);
    for (var index = 0; index < chunkCount; index++) {
      final bytes = transfer[index];
      if (bytes == null) throw StateError("chunk missing");
      yield List<int>.of(bytes);
    }
  }

  @override
  Future<void> deleteTransfer(String transferId) async {
    _transfers.remove(transferId);
    _manifests.remove(transferId);
  }

  @override
  Future<void> dispose() async {}

  Map<int, List<int>> _transfer(String transferId) {
    final transfer = _transfers[transferId];
    if (transfer == null) throw StateError("transfer missing");
    return transfer;
  }
}
