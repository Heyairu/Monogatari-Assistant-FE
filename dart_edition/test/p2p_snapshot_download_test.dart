import "dart:async";
import "dart:convert";
import "dart:io";

import "package:cryptography/cryptography.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/data/p2p/p2p_snapshot_download.dart";
import "package:monogatari_assistant/data/p2p/p2p_snapshot_quarantine.dart";
import "package:monogatari_assistant/domain/models/p2p_snapshot_models.dart";

void main() {
  const projectUuid = "123e4567-e89b-12d3-a456-426614174000";
  final revisionId = List<String>.filled(64, "a").join();

  test(
    "download resumes only missing chunks after a transient failure",
    () async {
      final fixture = await _fixture(projectUuid, revisionId);
      final gateway = _FakeChunkGateway(fixture.chunks)
        ..remainingTransientFailures[1] = 1;
      final storage = _MemoryQuarantineStorage();
      final coordinator = P2pSnapshotDownloadCoordinator(
        gateway: gateway,
        quarantineStorage: storage,
        maxAttemptsPerChunk: 1,
        retryDelay: (_) async {},
      );

      await expectLater(
        coordinator.download(fixture.manifest),
        throwsA(isA<P2pSnapshotChunkTransportException>()),
      );
      expect(coordinator.status, P2pSnapshotDownloadStatus.paused);
      expect(coordinator.receivedChunkIndexes, <int>{0});

      final verified = await coordinator.download(fixture.manifest);

      expect(verified.xmlContent, utf8.decode(fixture.payload));
      expect(gateway.requestedIndexes, <int>[0, 1, 1]);
      expect(coordinator.status, P2pSnapshotDownloadStatus.verified);
    },
  );

  test("a new coordinator resumes committed chunks after disposal", () async {
    final fixture = await _fixture(projectUuid, revisionId);
    final gateway = _FakeChunkGateway(fixture.chunks)
      ..remainingTransientFailures[1] = 1;
    final storage = _MemoryQuarantineStorage();
    final firstCoordinator = P2pSnapshotDownloadCoordinator(
      gateway: gateway,
      quarantineStorage: storage,
      maxAttemptsPerChunk: 1,
      retryDelay: (_) async {},
    );

    await expectLater(
      firstCoordinator.download(fixture.manifest),
      throwsA(isA<P2pSnapshotChunkTransportException>()),
    );
    expect(firstCoordinator.receivedChunkIndexes, <int>{0});
    await firstCoordinator.dispose();
    expect(storage.transferCount, 1);

    final restartedCoordinator = P2pSnapshotDownloadCoordinator(
      gateway: gateway,
      quarantineStorage: storage,
      maxAttemptsPerChunk: 1,
      retryDelay: (_) async {},
    );
    final verified = await restartedCoordinator.download(fixture.manifest);

    expect(verified.xmlContent, utf8.decode(fixture.payload));
    expect(gateway.requestedIndexes, <int>[0, 1, 1]);
    expect(storage.transferCount, 0);
  });

  test("download retries bounded transient failures automatically", () async {
    final fixture = await _fixture(projectUuid, revisionId, small: true);
    final gateway = _FakeChunkGateway(fixture.chunks)
      ..remainingTransientFailures[0] = 2;
    final coordinator = P2pSnapshotDownloadCoordinator(
      gateway: gateway,
      quarantineStorage: _MemoryQuarantineStorage(),
      retryDelay: (_) async {},
    );

    await coordinator.download(fixture.manifest);

    expect(gateway.requestedIndexes, <int>[0, 0, 0]);
    expect(coordinator.progress, 1);
  });

  test("quarantine capacity failure stops before requesting chunks", () async {
    final fixture = await _fixture(projectUuid, revisionId);
    final gateway = _FakeChunkGateway(fixture.chunks);
    final temporaryRoot = await Directory.systemTemp.createTemp(
      "monogatari-p2p-download-capacity-test-",
    );
    addTearDown(() async {
      if (await temporaryRoot.exists()) {
        await temporaryRoot.delete(recursive: true);
      }
    });
    final coordinator = P2pSnapshotDownloadCoordinator(
      gateway: gateway,
      quarantineStorage: FileSystemP2pSnapshotQuarantineStorage(
        baseDirectory: () async => temporaryRoot,
        maxRetainedBytes: P2pSnapshotManifest.chunkSizeBytes,
      ),
      retryDelay: (_) async {},
    );

    await expectLater(
      coordinator.download(fixture.manifest),
      throwsA(isA<P2pSnapshotQuarantineCapacityException>()),
    );
    expect(coordinator.status, P2pSnapshotDownloadStatus.failed);
    expect(gateway.requestedIndexes, isEmpty);
  });

  test("invalid chunk fails closed and clears quarantine", () async {
    final fixture = await _fixture(projectUuid, revisionId, small: true);
    final valid = fixture.chunks.single;
    final invalid = P2pSnapshotChunk(
      projectUuid: valid.projectUuid,
      revisionId: List<String>.filled(64, "b").join(),
      chunkIndex: valid.chunkIndex,
      chunkCount: valid.chunkCount,
      bytes: valid.bytes,
    );
    final gateway = _FakeChunkGateway(<P2pSnapshotChunk>[invalid]);
    final storage = _MemoryQuarantineStorage();
    final coordinator = P2pSnapshotDownloadCoordinator(
      gateway: gateway,
      quarantineStorage: storage,
      retryDelay: (_) async {},
    );

    await expectLater(
      coordinator.download(fixture.manifest),
      throwsFormatException,
    );

    expect(coordinator.status, P2pSnapshotDownloadStatus.failed);
    expect(storage.transferCount, 0);
    await expectLater(coordinator.download(fixture.manifest), throwsStateError);
  });

  test("non-transient gateway failure clears partial data", () async {
    final fixture = await _fixture(projectUuid, revisionId);
    final gateway = _FakeChunkGateway(fixture.chunks)
      ..permanentFailureIndex = 1;
    final storage = _MemoryQuarantineStorage();
    final coordinator = P2pSnapshotDownloadCoordinator(
      gateway: gateway,
      quarantineStorage: storage,
      retryDelay: (_) async {},
    );

    await expectLater(
      coordinator.download(fixture.manifest),
      throwsA(isA<P2pSnapshotChunkTransportException>()),
    );

    expect(coordinator.status, P2pSnapshotDownloadStatus.failed);
    expect(storage.transferCount, 0);
  });

  test("cancellation discards an in-flight response and quarantine", () async {
    final fixture = await _fixture(projectUuid, revisionId, small: true);
    final pending = Completer<P2pSnapshotChunk>();
    final gateway = _FakeChunkGateway(fixture.chunks)..pending = pending;
    final storage = _MemoryQuarantineStorage();
    final coordinator = P2pSnapshotDownloadCoordinator(
      gateway: gateway,
      quarantineStorage: storage,
      retryDelay: (_) async {},
    );

    final download = coordinator.download(fixture.manifest);
    await pumpEventQueue();
    await coordinator.cancel();
    pending.complete(fixture.chunks.single);

    await expectLater(
      download,
      throwsA(isA<P2pSnapshotDownloadCancelledException>()),
    );
    expect(coordinator.status, P2pSnapshotDownloadStatus.cancelled);
    expect(storage.transferCount, 0);
  });

  test("concurrent calls for the same manifest share one operation", () async {
    final fixture = await _fixture(projectUuid, revisionId, small: true);
    final pending = Completer<P2pSnapshotChunk>();
    final gateway = _FakeChunkGateway(fixture.chunks)..pending = pending;
    final coordinator = P2pSnapshotDownloadCoordinator(
      gateway: gateway,
      quarantineStorage: _MemoryQuarantineStorage(),
      retryDelay: (_) async {},
    );

    final first = coordinator.download(fixture.manifest);
    final second = coordinator.download(fixture.manifest);
    expect(identical(first, second), isTrue);
    pending.complete(fixture.chunks.single);
    await first;
    expect(gateway.requestedIndexes, <int>[0]);
  });
}

Future<
  ({
    P2pSnapshotManifest manifest,
    List<int> payload,
    List<P2pSnapshotChunk> chunks,
  })
>
_fixture(String projectUuid, String revisionId, {bool small = false}) async {
  final payload = utf8.encode(
    '<Project UUID="$projectUuid"><ver>1.0</ver><Data>'
    '${List<String>.filled(small ? 10 : 25000, "x").join()}'
    "</Data></Project>",
  );
  final digest = await Sha256().hash(payload);
  final manifest = P2pSnapshotManifest(
    projectUuid: projectUuid,
    revisionId: revisionId,
    contentSha256: _hex(digest.bytes),
    contentLength: payload.length,
    formatVersion: "1.0",
  );
  return (
    manifest: manifest,
    payload: payload,
    chunks: <P2pSnapshotChunk>[
      for (var index = 0; index < manifest.chunkCount; index++)
        P2pSnapshotChunk(
          projectUuid: manifest.projectUuid,
          revisionId: manifest.revisionId,
          chunkIndex: index,
          chunkCount: manifest.chunkCount,
          bytes: payload.sublist(
            index * manifest.chunkSize,
            (index + 1) * manifest.chunkSize < payload.length
                ? (index + 1) * manifest.chunkSize
                : payload.length,
          ),
        ),
    ],
  );
}

String _hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, "0")).join();

class _FakeChunkGateway implements P2pSnapshotChunkGateway {
  final List<P2pSnapshotChunk> chunks;
  final Map<int, int> remainingTransientFailures = <int, int>{};
  final List<int> requestedIndexes = <int>[];
  int? permanentFailureIndex;
  Completer<P2pSnapshotChunk>? pending;

  _FakeChunkGateway(this.chunks);

  @override
  Future<P2pSnapshotChunk> requestChunk(
    P2pSnapshotManifest manifest,
    int chunkIndex,
  ) async {
    requestedIndexes.add(chunkIndex);
    final pendingRequest = pending;
    if (pendingRequest != null) {
      pending = null;
      return pendingRequest.future;
    }
    if (permanentFailureIndex == chunkIndex) {
      throw const P2pSnapshotChunkTransportException(
        "protocol mismatch",
        isTransient: false,
      );
    }
    final remaining = remainingTransientFailures[chunkIndex] ?? 0;
    if (remaining > 0) {
      remainingTransientFailures[chunkIndex] = remaining - 1;
      throw const P2pSnapshotChunkTransportException(
        "temporary timeout",
        isTransient: true,
      );
    }
    return chunks[chunkIndex];
  }
}

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
