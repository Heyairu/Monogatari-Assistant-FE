import "dart:async";
import "dart:convert";
import "dart:io";

import "package:cryptography/cryptography.dart";
import "package:monogatari_assistant/domain/models/p2p_snapshot_models.dart";
import "package:path/path.dart" as path;
import "package:path_provider/path_provider.dart";
import "package:uuid/uuid.dart";
import "package:xml/xml.dart";

enum P2pSnapshotQuarantineStatus {
  receiving,
  verifying,
  verified,
  failed,
  cancelled,
}

class P2pVerifiedSnapshot {
  final P2pSnapshotManifest manifest;
  final String xmlContent;

  const P2pVerifiedSnapshot({required this.manifest, required this.xmlContent});
}

abstract class P2pSnapshotQuarantineStorage {
  Future<P2pStoredQuarantineTransfer> openTransfer(
    P2pSnapshotManifest manifest,
  );

  Future<void> writeChunk(String transferId, int chunkIndex, List<int> bytes);

  Future<List<int>> readChunk(String transferId, int chunkIndex);

  Stream<List<int>> readChunksInOrder(String transferId, int chunkCount);

  Future<void> deleteTransfer(String transferId);

  Future<void> dispose();
}

class P2pStoredQuarantineTransfer {
  final String transferId;
  final P2pSnapshotManifest manifest;
  final Set<int> receivedChunkIndexes;

  P2pStoredQuarantineTransfer({
    required this.transferId,
    required this.manifest,
    required Set<int> receivedChunkIndexes,
  }) : receivedChunkIndexes = Set<int>.unmodifiable(receivedChunkIndexes) {
    if (transferId.isEmpty || transferId.length > 64) {
      throw const FormatException("P2P quarantine transfer ID 無效。");
    }
    if (receivedChunkIndexes.any(
      (index) => index < 0 || index >= manifest.chunkCount,
    )) {
      throw const FormatException("P2P quarantine 已接收 chunk index 無效。");
    }
  }
}

class P2pSnapshotQuarantineCapacityException implements Exception {
  final String message;

  const P2pSnapshotQuarantineCapacityException(this.message);

  @override
  String toString() => message;
}

class FileSystemP2pSnapshotQuarantineStorage
    implements P2pSnapshotQuarantineStorage {
  static const int _metadataVersion = 2;
  static const int _legacyMetadataVersion = 1;
  static const Duration defaultRetention = Duration(days: 7);
  static const int defaultMaxRetainedTransfers = 4;
  static const int defaultMaxRetainedBytes = 128 * 1024 * 1024;
  static const String _manifestFileName = "manifest.json";
  static final RegExp _transferIdPattern = RegExp(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
  );
  static final RegExp _receiptFilePattern = RegExp(r"^(\d+)\.received$");

  final Future<Directory> Function() _baseDirectory;
  final Uuid _uuid;
  final Sha256 _sha256;
  final Duration _retention;
  final int _maxRetainedTransfers;
  final int _maxRetainedBytes;
  final DateTime Function() _now;
  final Map<String, _FileSystemQuarantineTransfer> _activeTransfers =
      <String, _FileSystemQuarantineTransfer>{};

  FileSystemP2pSnapshotQuarantineStorage({
    Future<Directory> Function()? baseDirectory,
    Uuid uuid = const Uuid(),
    Sha256? sha256,
    Duration retention = defaultRetention,
    int maxRetainedTransfers = defaultMaxRetainedTransfers,
    int maxRetainedBytes = defaultMaxRetainedBytes,
    DateTime Function()? now,
  }) : _baseDirectory = baseDirectory ?? getApplicationSupportDirectory,
       _uuid = uuid,
       _sha256 = sha256 ?? Sha256(),
       _retention = retention,
       _maxRetainedTransfers = maxRetainedTransfers,
       _maxRetainedBytes = maxRetainedBytes,
       _now = now ?? DateTime.now {
    if (retention <= Duration.zero || retention > const Duration(days: 30)) {
      throw ArgumentError.value(retention, "retention", "必須大於零且不超過 30 天。");
    }
    if (maxRetainedTransfers < 1 || maxRetainedTransfers > 16) {
      throw ArgumentError.value(
        maxRetainedTransfers,
        "maxRetainedTransfers",
        "必須介於 1 與 16。",
      );
    }
    if (maxRetainedBytes < P2pSnapshotManifest.chunkSizeBytes ||
        maxRetainedBytes > 512 * 1024 * 1024) {
      throw ArgumentError.value(
        maxRetainedBytes,
        "maxRetainedBytes",
        "必須介於 24 KiB 與 512 MiB。",
      );
    }
  }

  @override
  Future<P2pStoredQuarantineTransfer> openTransfer(
    P2pSnapshotManifest manifest,
  ) async {
    for (final active in _activeTransfers.values) {
      if (active.manifest == manifest) return active.snapshot;
      throw StateError("同一個 quarantine storage 不可同時開啟不同 transfer。");
    }
    if (manifest.contentLength > _maxRetainedBytes) {
      throw P2pSnapshotQuarantineCapacityException(
        "snapshot 大小超過 quarantine 容量上限 $_maxRetainedBytes bytes。",
      );
    }

    final baseDirectory = await _baseDirectory();
    final quarantineRoot = Directory(
      path.join(baseDirectory.path, "monogatari_p2p_quarantine"),
    );
    await quarantineRoot.create(recursive: true);

    final currentTime = _now().toUtc();
    final candidates = <_FileSystemQuarantineTransfer>[];
    await for (final entity in quarantineRoot.list(followLinks: false)) {
      if (entity is! Directory) {
        await entity.delete(recursive: false);
        continue;
      }
      try {
        final restored = await _restoreTransfer(entity);
        if (restored.lastActivityAt.isAfter(currentTime)) {
          restored.lastActivityAt = currentTime;
        }
        final age = currentTime.difference(restored.lastActivityAt);
        if (!age.isNegative && age > _retention) {
          await _deleteDirectory(entity);
        } else {
          candidates.add(restored);
        }
      } on FormatException {
        await _deleteDirectory(entity);
      } on FileSystemException {
        await _deleteDirectory(entity);
      }
    }
    final matching = candidates
        .where((candidate) => candidate.manifest == manifest)
        .toList(growable: false);
    _FileSystemQuarantineTransfer? selected;
    if (matching.isNotEmpty) {
      matching.sort((first, second) {
        final byProgress = second.receivedChunkIndexes.length.compareTo(
          first.receivedChunkIndexes.length,
        );
        return byProgress != 0
            ? byProgress
            : second.lastActivityAt.compareTo(first.lastActivityAt);
      });
      selected = matching.first;
      for (final duplicate in matching.skip(1)) {
        await _deleteDirectory(duplicate.directory);
      }
    }

    final otherCandidates =
        candidates
            .where((candidate) => candidate.manifest != manifest)
            .toList(growable: false)
          ..sort(
            (first, second) =>
                second.lastActivityAt.compareTo(first.lastActivityAt),
          );
    var retainedCount = 1;
    var reservedBytes = manifest.contentLength;
    for (final candidate in otherCandidates) {
      final canRetain =
          retainedCount < _maxRetainedTransfers &&
          reservedBytes + candidate.committedBytes <= _maxRetainedBytes;
      if (canRetain) {
        retainedCount += 1;
        reservedBytes += candidate.committedBytes;
      } else {
        await _deleteDirectory(candidate.directory);
      }
    }
    if (selected != null) {
      _activeTransfers[selected.transferId] = selected;
      return selected.snapshot;
    }

    final transferId = _uuid.v4().toLowerCase();
    final directory = Directory(path.join(quarantineRoot.path, transferId));
    await directory.create();
    final transfer = _FileSystemQuarantineTransfer(
      transferId: transferId,
      directory: directory,
      manifest: manifest,
      receivedChunkIndexes: <int>{},
      createdAt: currentTime,
      lastActivityAt: currentTime,
    );
    try {
      await _writeManifest(transfer);
    } on FileSystemException {
      await _deleteDirectory(directory);
      rethrow;
    }
    _activeTransfers[transferId] = transfer;
    return transfer.snapshot;
  }

  @override
  Future<void> writeChunk(
    String transferId,
    int chunkIndex,
    List<int> bytes,
  ) async {
    final transfer = _transferFor(transferId);
    if (chunkIndex < 0 || chunkIndex >= transfer.manifest.chunkCount) {
      throw const FormatException("P2P quarantine chunk index 無效。");
    }
    final expectedLength = _expectedChunkLength(transfer.manifest, chunkIndex);
    if (bytes.length != expectedLength) {
      throw const FormatException("P2P quarantine chunk 長度不符。");
    }
    final target = File(
      path.join(transfer.directory.path, "$chunkIndex.chunk"),
    );
    final receipt = File(
      path.join(transfer.directory.path, "$chunkIndex.received"),
    );
    final temporary = File("${target.path}.${_uuid.v4().toLowerCase()}.tmp");
    final temporaryReceipt = File(
      "${receipt.path}.${_uuid.v4().toLowerCase()}.tmp",
    );
    await temporary.writeAsBytes(bytes, flush: true);
    try {
      if (await target.exists()) await target.delete();
      await temporary.rename(target.path);
      final digest = _hex((await _sha256.hash(bytes)).bytes);
      final committedAt = _now().toUtc();
      await temporaryReceipt.writeAsString(
        jsonEncode(<String, Object?>{
          "version": _metadataVersion,
          "chunkIndex": chunkIndex,
          "length": bytes.length,
          "sha256": digest,
          "committedAtEpochMs": committedAt.millisecondsSinceEpoch,
        }),
        flush: true,
      );
      if (await receipt.exists()) await receipt.delete();
      await temporaryReceipt.rename(receipt.path);
      transfer.receivedChunkIndexes.add(chunkIndex);
      transfer.lastActivityAt = committedAt;
    } on FileSystemException {
      if (await temporary.exists()) await temporary.delete();
      if (await temporaryReceipt.exists()) await temporaryReceipt.delete();
      if (await target.exists()) await target.delete();
      if (await receipt.exists()) await receipt.delete();
      transfer.receivedChunkIndexes.remove(chunkIndex);
      rethrow;
    }
  }

  @override
  Future<List<int>> readChunk(String transferId, int chunkIndex) {
    return File(
      path.join(_transferFor(transferId).directory.path, "$chunkIndex.chunk"),
    ).readAsBytes();
  }

  @override
  Stream<List<int>> readChunksInOrder(
    String transferId,
    int chunkCount,
  ) async* {
    final directory = _transferFor(transferId).directory;
    for (var index = 0; index < chunkCount; index++) {
      yield await File(path.join(directory.path, "$index.chunk")).readAsBytes();
    }
  }

  @override
  Future<void> deleteTransfer(String transferId) async {
    final transfer = _activeTransfers.remove(transferId);
    if (transfer != null) {
      await _deleteDirectory(transfer.directory);
    }
  }

  @override
  Future<void> dispose() async {
    // Partial transfers intentionally survive object/App disposal. Explicit
    // cancel, verification success, and validation failure remove their data.
    _activeTransfers.clear();
  }

  _FileSystemQuarantineTransfer _transferFor(String transferId) {
    final transfer = _activeTransfers[transferId];
    if (transfer == null) {
      throw StateError("P2P quarantine transfer 不存在或已清除。");
    }
    return transfer;
  }

  Future<_FileSystemQuarantineTransfer> _restoreTransfer(
    Directory directory,
  ) async {
    final transferId = path.basename(directory.path).toLowerCase();
    if (!_transferIdPattern.hasMatch(transferId)) {
      throw const FormatException("P2P quarantine transfer 目錄名稱無效。");
    }
    final manifestFile = File(path.join(directory.path, _manifestFileName));
    final decoded = jsonDecode(await manifestFile.readAsString());
    if (decoded is! Map || decoded["manifest"] is! Map) {
      throw const FormatException("P2P quarantine manifest metadata 無效。");
    }
    final metadataVersion = decoded["version"];
    late final DateTime createdAt;
    if (metadataVersion == _metadataVersion &&
        decoded.length == 3 &&
        decoded["createdAtEpochMs"] is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(
        _validatedEpochMilliseconds(decoded["createdAtEpochMs"]),
        isUtc: true,
      );
    } else if (metadataVersion == _legacyMetadataVersion &&
        decoded.length == 2) {
      createdAt = (await manifestFile.stat()).modified.toUtc();
    } else {
      throw const FormatException("P2P quarantine manifest metadata 版本無效。");
    }
    final rawManifest = decoded["manifest"]! as Map;
    final manifest = P2pSnapshotManifest.fromJson(
      rawManifest.map((key, value) => MapEntry(key.toString(), value)),
    );
    final received = <int>{};
    final allowedNames = <String>{_manifestFileName};
    var lastActivityAt = createdAt;

    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) {
        throw const FormatException("P2P quarantine 含有非預期項目。");
      }
      final name = path.basename(entity.path);
      if (name == _manifestFileName) continue;
      final receiptMatch = _receiptFilePattern.firstMatch(name);
      if (receiptMatch == null) continue;
      final index = int.tryParse(receiptMatch.group(1)!);
      if (index == null || index < 0 || index >= manifest.chunkCount) {
        throw const FormatException("P2P quarantine receipt index 無效。");
      }
      final chunkName = "$index.chunk";
      final chunk = File(path.join(directory.path, chunkName));
      final committedAt = await _validateReceipt(
        receipt: entity,
        chunk: chunk,
        manifest: manifest,
        chunkIndex: index,
      );
      if (committedAt.isAfter(lastActivityAt)) lastActivityAt = committedAt;
      if (!received.add(index)) {
        throw const FormatException("P2P quarantine receipt index 重複。");
      }
      allowedNames
        ..add(name)
        ..add(chunkName);
    }

    await for (final entity in directory.list(followLinks: false)) {
      final name = path.basename(entity.path);
      if (!allowedNames.contains(name)) {
        // A chunk without its committed receipt or a torn temporary file is
        // never considered resumable.
        await entity.delete(recursive: entity is Directory);
      }
    }
    return _FileSystemQuarantineTransfer(
      transferId: transferId,
      directory: directory,
      manifest: manifest,
      receivedChunkIndexes: received,
      createdAt: createdAt,
      lastActivityAt: lastActivityAt,
    );
  }

  Future<DateTime> _validateReceipt({
    required File receipt,
    required File chunk,
    required P2pSnapshotManifest manifest,
    required int chunkIndex,
  }) async {
    final decoded = jsonDecode(await receipt.readAsString());
    if (decoded is! Map ||
        decoded["chunkIndex"] != chunkIndex ||
        decoded["length"] != _expectedChunkLength(manifest, chunkIndex) ||
        decoded["sha256"] is! String ||
        !await chunk.exists()) {
      throw const FormatException("P2P quarantine chunk receipt 無效。");
    }
    final metadataVersion = decoded["version"];
    late final DateTime committedAt;
    if (metadataVersion == _metadataVersion &&
        decoded.length == 5 &&
        decoded["committedAtEpochMs"] is int) {
      committedAt = DateTime.fromMillisecondsSinceEpoch(
        _validatedEpochMilliseconds(decoded["committedAtEpochMs"]),
        isUtc: true,
      );
    } else if (metadataVersion == _legacyMetadataVersion &&
        decoded.length == 4) {
      committedAt = (await receipt.stat()).modified.toUtc();
    } else {
      throw const FormatException("P2P quarantine chunk receipt 版本無效。");
    }
    final bytes = await chunk.readAsBytes();
    final expectedHash = decoded["sha256"]! as String;
    final actualHash = _hex((await _sha256.hash(bytes)).bytes);
    if (bytes.length != _expectedChunkLength(manifest, chunkIndex) ||
        !RegExp(r"^[0-9a-f]{64}$").hasMatch(expectedHash) ||
        actualHash != expectedHash) {
      throw const FormatException("P2P quarantine 已保存 chunk 驗證失敗。");
    }
    return committedAt;
  }

  Future<void> _writeManifest(_FileSystemQuarantineTransfer transfer) async {
    final target = File(path.join(transfer.directory.path, _manifestFileName));
    final temporary = File("${target.path}.${_uuid.v4().toLowerCase()}.tmp");
    await temporary.writeAsString(
      jsonEncode(<String, Object?>{
        "version": _metadataVersion,
        "manifest": transfer.manifest.toJson(),
        "createdAtEpochMs": transfer.createdAt.millisecondsSinceEpoch,
      }),
      flush: true,
    );
    try {
      await temporary.rename(target.path);
    } on FileSystemException {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  int _expectedChunkLength(P2pSnapshotManifest manifest, int chunkIndex) {
    final start = chunkIndex * manifest.chunkSize;
    final remaining = manifest.contentLength - start;
    return remaining < manifest.chunkSize ? remaining : manifest.chunkSize;
  }

  Future<void> _deleteDirectory(Directory directory) async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  int _validatedEpochMilliseconds(Object? value) {
    // DateTime's supported range extends further, but quarantine metadata has
    // no valid reason to refer beyond year 9999 or before the Unix epoch.
    if (value is! int || value < 0 || value > 253402300799999) {
      throw const FormatException("P2P quarantine metadata 時間無效。");
    }
    return value;
  }

  String _hex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, "0")).join();
}

class _FileSystemQuarantineTransfer {
  final String transferId;
  final Directory directory;
  final P2pSnapshotManifest manifest;
  final Set<int> receivedChunkIndexes;
  final DateTime createdAt;
  DateTime lastActivityAt;

  _FileSystemQuarantineTransfer({
    required this.transferId,
    required this.directory,
    required this.manifest,
    required this.receivedChunkIndexes,
    required this.createdAt,
    required this.lastActivityAt,
  });

  int get committedBytes {
    var total = 0;
    for (final index in receivedChunkIndexes) {
      final start = index * manifest.chunkSize;
      final remaining = manifest.contentLength - start;
      total += remaining < manifest.chunkSize ? remaining : manifest.chunkSize;
    }
    return total;
  }

  P2pStoredQuarantineTransfer get snapshot => P2pStoredQuarantineTransfer(
    transferId: transferId,
    manifest: manifest,
    receivedChunkIndexes: receivedChunkIndexes,
  );
}

class P2pSnapshotQuarantineSession {
  final P2pSnapshotManifest manifest;
  final P2pSnapshotQuarantineStorage _storage;
  final Sha256 _sha256;
  final String _transferId;
  final Set<int> _receivedChunkIndexes = <int>{};
  Future<void> _operationTail = Future<void>.value();
  P2pSnapshotQuarantineStatus _status = P2pSnapshotQuarantineStatus.receiving;
  P2pVerifiedSnapshot? _verifiedSnapshot;

  P2pSnapshotQuarantineSession._({
    required this.manifest,
    required P2pSnapshotQuarantineStorage storage,
    required Sha256 sha256,
    required String transferId,
    required Set<int> receivedChunkIndexes,
  }) : _storage = storage,
       _sha256 = sha256,
       _transferId = transferId {
    _receivedChunkIndexes.addAll(receivedChunkIndexes);
  }

  static Future<P2pSnapshotQuarantineSession> open({
    required P2pSnapshotManifest manifest,
    P2pSnapshotQuarantineStorage? storage,
    Sha256? sha256,
  }) async {
    final resolvedStorage = storage ?? FileSystemP2pSnapshotQuarantineStorage();
    final transfer = await resolvedStorage.openTransfer(manifest);
    if (transfer.manifest != manifest) {
      throw const FormatException("P2P quarantine 恢復的 manifest 不一致。");
    }
    return P2pSnapshotQuarantineSession._(
      manifest: manifest,
      storage: resolvedStorage,
      sha256: sha256 ?? Sha256(),
      transferId: transfer.transferId,
      receivedChunkIndexes: transfer.receivedChunkIndexes,
    );
  }

  P2pSnapshotQuarantineStatus get status => _status;

  Set<int> get receivedChunkIndexes =>
      Set<int>.unmodifiable(_receivedChunkIndexes);

  double get progress => _receivedChunkIndexes.length / manifest.chunkCount;

  Future<void> addChunk(P2pSnapshotChunk chunk) {
    return _serialize(() async {
      _ensureReceiving();
      try {
        chunk.validateAgainst(manifest);
        if (_receivedChunkIndexes.contains(chunk.chunkIndex)) {
          final existing = await _storage.readChunk(
            _transferId,
            chunk.chunkIndex,
          );
          if (!_sameBytes(existing, chunk.bytes)) {
            throw const FormatException("P2P quarantine 收到內容不同的重複 chunk。");
          }
          return;
        }
        await _storage.writeChunk(_transferId, chunk.chunkIndex, chunk.bytes);
        _receivedChunkIndexes.add(chunk.chunkIndex);
      } on FormatException {
        await _markFailed();
        rethrow;
      } on FileSystemException {
        await _markFailed();
        rethrow;
      } on P2pSnapshotQuarantineCapacityException {
        await _markFailed();
        rethrow;
      }
    });
  }

  Future<P2pVerifiedSnapshot> finalize() {
    return _serialize(() async {
      final existing = _verifiedSnapshot;
      if (existing != null) return existing;
      _ensureReceiving();
      if (_receivedChunkIndexes.length != manifest.chunkCount) {
        throw StateError("P2P quarantine 尚未收到所有 chunks。");
      }
      _status = P2pSnapshotQuarantineStatus.verifying;
      try {
        final hashSink = _sha256.newHashSink();
        await for (final bytes in _storage.readChunksInOrder(
          _transferId,
          manifest.chunkCount,
        )) {
          hashSink.add(bytes);
        }
        hashSink.close();
        final contentHash = _hex((await hashSink.hash()).bytes);
        if (contentHash != manifest.contentSha256) {
          throw const FormatException("P2P quarantine snapshot SHA-256 不符。");
        }

        final xmlContent = await utf8.decoder
            .bind(_storage.readChunksInOrder(_transferId, manifest.chunkCount))
            .join();
        _validateXml(xmlContent);
        final verified = P2pVerifiedSnapshot(
          manifest: manifest,
          xmlContent: xmlContent,
        );
        await _storage.deleteTransfer(_transferId);
        _verifiedSnapshot = verified;
        _status = P2pSnapshotQuarantineStatus.verified;
        return verified;
      } on FormatException {
        await _markFailed();
        rethrow;
      } on XmlException catch (error) {
        await _markFailed();
        throw FormatException("P2P quarantine XML 無法解析：${error.message}");
      } on FileSystemException {
        await _markFailed();
        rethrow;
      }
    });
  }

  Future<void> cancel() {
    return _serialize(() async {
      if (_status == P2pSnapshotQuarantineStatus.cancelled) return;
      await _storage.deleteTransfer(_transferId);
      _receivedChunkIndexes.clear();
      _verifiedSnapshot = null;
      _status = P2pSnapshotQuarantineStatus.cancelled;
    });
  }

  void _validateXml(String xmlContent) {
    if (RegExp(r"<!DOCTYPE", caseSensitive: false).hasMatch(xmlContent)) {
      throw const FormatException("P2P quarantine XML 不允許 DOCTYPE。");
    }
    final document = XmlDocument.parse(xmlContent);
    final root = document.rootElement;
    if (root.name.qualified != "Project" ||
        root.getAttribute("UUID")?.trim().toLowerCase() !=
            manifest.projectUuid) {
      throw const FormatException("P2P quarantine XML Project UUID 不符。");
    }
    final versions = root.findElements("ver").toList(growable: false);
    if (versions.length != 1 ||
        versions.single.children.any((node) => node is XmlElement) ||
        versions.single.innerText.trim() != manifest.formatVersion) {
      throw const FormatException("P2P quarantine XML format version 不符。");
    }
  }

  Future<void> _markFailed() async {
    _verifiedSnapshot = null;
    _status = P2pSnapshotQuarantineStatus.failed;
    await _storage.deleteTransfer(_transferId);
  }

  void _ensureReceiving() {
    if (_status != P2pSnapshotQuarantineStatus.receiving) {
      throw StateError("P2P quarantine session 目前不可接收或驗證。");
    }
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _operationTail = _operationTail.then((_) {
      return Future<T>.sync(operation).then<void>(
        completer.complete,
        onError: (Object error, StackTrace stackTrace) {
          completer.completeError(error, stackTrace);
        },
      );
    });
    return completer.future;
  }

  bool _sameBytes(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  String _hex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, "0")).join();
}
