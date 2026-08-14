import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/domain/models/p2p_snapshot_models.dart";

void main() {
  const projectUuid = "123e4567-e89b-12d3-a456-426614174000";
  final revisionId = List<String>.filled(64, "a").join();
  final contentHash = List<String>.filled(64, "b").join();

  test("snapshot manifest derives a bounded deterministic chunk count", () {
    final manifest = P2pSnapshotManifest(
      projectUuid: projectUuid,
      revisionId: revisionId,
      contentSha256: contentHash,
      contentLength: P2pSnapshotManifest.chunkSizeBytes + 1,
      formatVersion: "1.0",
    );

    expect(manifest.chunkCount, 2);
    expect(P2pSnapshotManifest.fromJson(manifest.toJson()), manifest);
  });

  test("snapshot manifest rejects forged chunk metadata and oversize data", () {
    final valid = P2pSnapshotManifest(
      projectUuid: projectUuid,
      revisionId: revisionId,
      contentSha256: contentHash,
      contentLength: 100,
      formatVersion: "1.0",
    ).toJson();

    expect(
      () => P2pSnapshotManifest.fromJson(<String, Object?>{
        ...valid,
        "chunkCount": 2,
      }),
      throwsFormatException,
    );
    expect(
      () => P2pSnapshotManifest.fromJson(<String, Object?>{
        ...valid,
        "chunkSize": 0,
      }),
      throwsFormatException,
    );
    expect(
      () => P2pSnapshotManifest.fromJson(<String, Object?>{
        ...valid,
        "unexpected": true,
      }),
      throwsFormatException,
    );
    expect(
      () => P2pSnapshotManifest(
        projectUuid: projectUuid,
        revisionId: revisionId,
        contentSha256: contentHash,
        contentLength: P2pSnapshotManifest.maxSnapshotBytes + 1,
        formatVersion: "1.0",
      ),
      throwsFormatException,
    );
  });

  test("snapshot sync request is bounded and bound to one manifest", () {
    final manifest = P2pSnapshotManifest(
      projectUuid: projectUuid,
      revisionId: revisionId,
      contentSha256: contentHash,
      contentLength: 100,
      formatVersion: "1.0",
    );
    final request = P2pSnapshotSyncRequest(
      requestId: "snapshot-sync-request-0001",
      projectUuid: projectUuid,
      revisionId: revisionId,
      contentSha256: contentHash,
    );

    expect(P2pSnapshotSyncRequest.fromJson(request.toJson()), request);
    expect(request.matches(manifest), isTrue);
    expect(
      () => P2pSnapshotSyncRequest.fromJson(<String, Object?>{
        ...request.toJson(),
        "unexpected": true,
      }),
      throwsFormatException,
    );
    expect(
      () => P2pSnapshotSyncRequest(
        requestId: "short",
        projectUuid: projectUuid,
        revisionId: revisionId,
        contentSha256: contentHash,
      ),
      throwsFormatException,
    );
  });

  test("snapshot chunk round-trips and validates its exact final size", () {
    final manifest = P2pSnapshotManifest(
      projectUuid: projectUuid,
      revisionId: revisionId,
      contentSha256: contentHash,
      contentLength: P2pSnapshotManifest.chunkSizeBytes + 3,
      formatVersion: "1.0",
    );
    final chunk = P2pSnapshotChunk(
      projectUuid: projectUuid,
      revisionId: revisionId,
      chunkIndex: 1,
      chunkCount: 2,
      bytes: const <int>[1, 2, 3],
    );

    final decoded = P2pSnapshotChunk.fromJson(chunk.toJson());
    expect(decoded.bytes, <int>[1, 2, 3]);
    expect(() => decoded.validateAgainst(manifest), returnsNormally);
    expect(
      () => P2pSnapshotChunk(
        projectUuid: projectUuid,
        revisionId: revisionId,
        chunkIndex: 1,
        chunkCount: 2,
        bytes: const <int>[1, 2],
      ).validateAgainst(manifest),
      throwsFormatException,
    );
  });

  test("snapshot chunk rejects forged metadata and oversized payloads", () {
    final chunk = P2pSnapshotChunk(
      projectUuid: projectUuid,
      revisionId: revisionId,
      chunkIndex: 0,
      chunkCount: 1,
      bytes: const <int>[1],
    ).toJson();

    expect(
      () => P2pSnapshotChunk.fromJson(<String, Object?>{
        ...chunk,
        "chunkIndex": 1,
      }),
      throwsFormatException,
    );
    expect(
      () => P2pSnapshotChunk(
        projectUuid: projectUuid,
        revisionId: revisionId,
        chunkIndex: 0,
        chunkCount: 1,
        bytes: List<int>.filled(P2pSnapshotManifest.chunkSizeBytes + 1, 0),
      ),
      throwsFormatException,
    );
  });

  test("chunk request and ACK bind the complete manifest identity", () {
    final manifest = P2pSnapshotManifest(
      projectUuid: projectUuid,
      revisionId: revisionId,
      contentSha256: contentHash,
      contentLength: P2pSnapshotManifest.chunkSizeBytes + 1,
      formatVersion: "1.0",
    );
    final request = P2pSnapshotChunkRequest(manifest: manifest, chunkIndex: 1);
    final ack = P2pSnapshotChunkAck(
      projectUuid: manifest.projectUuid,
      revisionId: manifest.revisionId,
      contentSha256: manifest.contentSha256,
      chunkIndex: request.chunkIndex,
    );

    final decodedRequest = P2pSnapshotChunkRequest.fromJson(request.toJson());
    final decodedAck = P2pSnapshotChunkAck.fromJson(ack.toJson());
    expect(decodedRequest.manifest, manifest);
    expect(decodedRequest.chunkIndex, 1);
    expect(decodedAck.matches(manifest, request.chunkIndex), isTrue);
    expect(decodedAck.matches(manifest, 0), isFalse);
  });

  test("chunk request and ACK reject extra or forged fields", () {
    final manifest = P2pSnapshotManifest(
      projectUuid: projectUuid,
      revisionId: revisionId,
      contentSha256: contentHash,
      contentLength: 1,
      formatVersion: "1.0",
    );
    final request = P2pSnapshotChunkRequest(manifest: manifest, chunkIndex: 0);
    final ack = P2pSnapshotChunkAck(
      projectUuid: manifest.projectUuid,
      revisionId: manifest.revisionId,
      contentSha256: manifest.contentSha256,
      chunkIndex: 0,
    );

    expect(
      () => P2pSnapshotChunkRequest.fromJson(<String, Object?>{
        ...request.toJson(),
        "unexpected": true,
      }),
      throwsFormatException,
    );
    expect(
      () => P2pSnapshotChunkAck.fromJson(<String, Object?>{
        ...ack.toJson(),
        "contentSha256": List<String>.filled(64, "z").join(),
      }),
      throwsFormatException,
    );
  });
}
