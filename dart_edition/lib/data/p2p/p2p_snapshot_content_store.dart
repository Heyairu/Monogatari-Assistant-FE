import "dart:io";

import "package:cryptography/cryptography.dart";
import "package:monogatari_assistant/domain/models/p2p_snapshot_models.dart";
import "package:path/path.dart" as path;
import "package:path_provider/path_provider.dart";
import "package:uuid/uuid.dart";

abstract class P2pSnapshotContentStore {
  Future<void> writeSnapshot(P2pSnapshotManifest manifest, List<int> bytes);

  Future<bool> containsVerifiedSnapshot(P2pSnapshotManifest manifest);

  Future<P2pSnapshotChunk> readChunk(
    P2pSnapshotManifest manifest,
    int chunkIndex,
  );
}

/// Immutable, app-private storage for snapshots that this device may provide.
///
/// Files are never resolved from peer-provided paths. Project and revision
/// identifiers have already passed the strict manifest validators and are used
/// only below the application support directory.
class FileSystemP2pSnapshotContentStore implements P2pSnapshotContentStore {
  final Future<Directory> Function() _applicationSupportDirectory;
  final Sha256 _sha256;
  final Uuid _uuid;
  final Map<String, ({int length, int modifiedMicros, String contentSha256})>
  _verifiedFiles =
      <String, ({int length, int modifiedMicros, String contentSha256})>{};

  FileSystemP2pSnapshotContentStore({
    Future<Directory> Function()? applicationSupportDirectory,
    Sha256? sha256,
    Uuid uuid = const Uuid(),
  }) : _applicationSupportDirectory =
           applicationSupportDirectory ?? getApplicationSupportDirectory,
       _sha256 = sha256 ?? Sha256(),
       _uuid = uuid;

  @override
  Future<void> writeSnapshot(
    P2pSnapshotManifest manifest,
    List<int> bytes,
  ) async {
    await _validateBytes(manifest, bytes);
    final target = await _fileFor(manifest);
    if (await target.exists()) {
      if (await _matchesManifest(target, manifest)) return;
      throw StateError("既有 P2P snapshot 與相同 revision ID 的 manifest 不符。");
    }

    await target.parent.create(recursive: true);
    final temporary = File("${target.path}.${_uuid.v4().toLowerCase()}.tmp");
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(target.path);
    } on FileSystemException {
      if (await target.exists() && await _matchesManifest(target, manifest)) {
        return;
      }
      rethrow;
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  @override
  Future<bool> containsVerifiedSnapshot(P2pSnapshotManifest manifest) async {
    final file = await _fileFor(manifest);
    if (!await file.exists()) return false;
    final stat = await file.stat();
    final cached = _verifiedFiles[file.path];
    if (cached != null &&
        cached.length == stat.size &&
        cached.modifiedMicros == stat.modified.microsecondsSinceEpoch &&
        cached.contentSha256 == manifest.contentSha256) {
      return true;
    }
    if (!await _matchesManifest(file, manifest)) {
      _verifiedFiles.remove(file.path);
      return false;
    }
    _verifiedFiles[file.path] = (
      length: stat.size,
      modifiedMicros: stat.modified.microsecondsSinceEpoch,
      contentSha256: manifest.contentSha256,
    );
    return true;
  }

  @override
  Future<P2pSnapshotChunk> readChunk(
    P2pSnapshotManifest manifest,
    int chunkIndex,
  ) async {
    if (chunkIndex < 0 || chunkIndex >= manifest.chunkCount) {
      throw const FormatException("P2P snapshot chunk index 無效。");
    }
    final file = await _fileFor(manifest);
    if (!await containsVerifiedSnapshot(manifest)) {
      throw StateError("P2P snapshot 內容不存在或驗證失敗。");
    }
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file ||
        stat.size != manifest.contentLength) {
      throw StateError("P2P snapshot 內容不存在或長度不符。");
    }
    final offset = chunkIndex * manifest.chunkSize;
    final expectedLength = chunkIndex == manifest.chunkCount - 1
        ? manifest.contentLength - offset
        : manifest.chunkSize;
    final handle = await file.open();
    try {
      await handle.setPosition(offset);
      final bytes = await handle.read(expectedLength);
      if (bytes.length != expectedLength) {
        throw StateError("P2P snapshot chunk 讀取不完整。");
      }
      return P2pSnapshotChunk(
        projectUuid: manifest.projectUuid,
        revisionId: manifest.revisionId,
        chunkIndex: chunkIndex,
        chunkCount: manifest.chunkCount,
        bytes: bytes,
      );
    } finally {
      await handle.close();
    }
  }

  Future<File> _fileFor(P2pSnapshotManifest manifest) async {
    final root = await _applicationSupportDirectory();
    return File(
      path.join(
        root.path,
        "monogatari_p2p_snapshots",
        manifest.projectUuid,
        "${manifest.revisionId}.snapshot",
      ),
    );
  }

  Future<void> _validateBytes(
    P2pSnapshotManifest manifest,
    List<int> bytes,
  ) async {
    if (bytes.length != manifest.contentLength ||
        bytes.any((byte) => byte < 0 || byte > 255) ||
        _hex((await _sha256.hash(bytes)).bytes) != manifest.contentSha256) {
      throw const FormatException("P2P snapshot bytes 與 manifest 不符。");
    }
  }

  Future<bool> _matchesManifest(File file, P2pSnapshotManifest manifest) async {
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file ||
        stat.size != manifest.contentLength) {
      return false;
    }
    final sink = _sha256.newHashSink();
    await for (final bytes in file.openRead()) {
      sink.add(bytes);
    }
    sink.close();
    return _hex((await sink.hash()).bytes) == manifest.contentSha256;
  }

  String _hex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, "0")).join();
}
