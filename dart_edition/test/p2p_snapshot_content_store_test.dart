import "dart:convert";
import "dart:io";

import "package:cryptography/cryptography.dart";
import "package:flutter_test/flutter_test.dart";
import "package:monogatari_assistant/data/p2p/p2p_snapshot_content_store.dart";
import "package:monogatari_assistant/domain/models/p2p_snapshot_models.dart";

void main() {
  const projectUuid = "123e4567-e89b-12d3-a456-426614174000";
  final revisionId = List<String>.filled(64, "a").join();

  test("content store writes immutable bytes and reads exact chunks", () async {
    final root = await Directory.systemTemp.createTemp(
      "monogatari-p2p-content-test-",
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
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
    final store = FileSystemP2pSnapshotContentStore(
      applicationSupportDirectory: () async => root,
    );

    await store.writeSnapshot(manifest, payload);
    await store.writeSnapshot(manifest, payload);

    expect(await store.containsVerifiedSnapshot(manifest), isTrue);
    final first = await store.readChunk(manifest, 0);
    final last = await store.readChunk(manifest, 1);
    expect(<int>[...first.bytes, ...last.bytes], payload);
    expect(first.bytes, hasLength(P2pSnapshotManifest.chunkSizeBytes));
    expect(last.bytes, hasLength(payload.length - manifest.chunkSize));
  });

  test("content store rejects bytes that do not match the manifest", () async {
    final root = await Directory.systemTemp.createTemp(
      "monogatari-p2p-content-invalid-test-",
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final payload = utf8.encode(
      '<Project UUID="$projectUuid"><ver>1.0</ver></Project>',
    );
    final manifest = await _manifestFor(
      payload,
      projectUuid: projectUuid,
      revisionId: revisionId,
    );
    final store = FileSystemP2pSnapshotContentStore(
      applicationSupportDirectory: () async => root,
    );

    final changed = List<int>.of(payload)..[0] ^= 1;
    await expectLater(
      store.writeSnapshot(manifest, changed),
      throwsFormatException,
    );
    expect(await store.containsVerifiedSnapshot(manifest), isFalse);
  });

  test(
    "content store never overwrites a corrupted immutable revision",
    () async {
      final root = await Directory.systemTemp.createTemp(
        "monogatari-p2p-content-corrupt-test-",
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final payload = utf8.encode(
        '<Project UUID="$projectUuid"><ver>1.0</ver></Project>',
      );
      final manifest = await _manifestFor(
        payload,
        projectUuid: projectUuid,
        revisionId: revisionId,
      );
      final store = FileSystemP2pSnapshotContentStore(
        applicationSupportDirectory: () async => root,
      );
      await store.writeSnapshot(manifest, payload);
      final snapshot = File(
        "${root.path}${Platform.pathSeparator}monogatari_p2p_snapshots"
        "${Platform.pathSeparator}$projectUuid"
        "${Platform.pathSeparator}$revisionId.snapshot",
      );
      await snapshot.writeAsBytes(
        List<int>.filled(payload.length, 0),
        flush: true,
      );

      expect(await store.containsVerifiedSnapshot(manifest), isFalse);
      await expectLater(store.readChunk(manifest, 0), throwsStateError);
      await expectLater(
        store.writeSnapshot(manifest, payload),
        throwsStateError,
      );
      expect(await snapshot.readAsBytes(), List<int>.filled(payload.length, 0));
    },
  );

  test("content store rejects out-of-range chunk indexes", () async {
    final root = await Directory.systemTemp.createTemp(
      "monogatari-p2p-content-index-test-",
    );
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final payload = utf8.encode(
      '<Project UUID="$projectUuid"><ver>1.0</ver></Project>',
    );
    final manifest = await _manifestFor(
      payload,
      projectUuid: projectUuid,
      revisionId: revisionId,
    );
    final store = FileSystemP2pSnapshotContentStore(
      applicationSupportDirectory: () async => root,
    );
    await store.writeSnapshot(manifest, payload);

    await expectLater(store.readChunk(manifest, -1), throwsFormatException);
    await expectLater(
      store.readChunk(manifest, manifest.chunkCount),
      throwsFormatException,
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

String _hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, "0")).join();
